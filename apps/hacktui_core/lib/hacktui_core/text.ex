defmodule HacktuiCore.Text do
  @moduledoc """
  The boundary that untrusted text crosses on its way in, and the per-sink encoders it
  crosses on its way out.

  Sensor collectors read attacker-influenced bytes: tshark's `dns.qry.name`,
  `tls.handshake.extensions_server_name`, `http.host`, `http.request.uri` and
  `_ws.col.Info`, plus whole journald lines. Before this module those bytes reached the
  analyst's terminal through `String.trim/1` and `String.slice/3`, so anyone on a
  monitored segment could emit `\\e]52;c;<base64>\\a` (OSC 52) and write the analyst's
  clipboard, or `\\r` and overwrite a rendered row.

  ## Why four functions and not one `safe/1`

  The same text has four sinks with four different escaping rules: a terminal needs
  control sequences removed; HEEx already escapes markup, and escaping here would
  double-escape and corrupt the terminal view; `Jason` handles JSON; and a model needs
  delimiting and provenance, not character removal — no character filter stops
  "ignore previous instructions". So `ingest/2` removes what is dangerous in *every*
  sink, and the `for_*` functions add what one sink needs.

  ## Malformed input is scrubbed, not rejected

  Dropping a field because it contains one bad byte hands an attacker an off-switch:
  `classify_traffic/5` raises severity when a field contains "password"/"login"/"admin",
  so returning `nil` for the whole field lets one trailing `0xFF` downgrade an alert to
  `:low`. Invalid bytes are therefore dropped and the rest of the text is kept, and
  `scrubbed?/1` reports whether anything was removed so a caller can record it.

  ## Ordering

  Clamp, strip, *then* normalise. Normalising first is wrong: stripping ZWJ afterwards
  removes a character that was blocking composition, leaving decomposed output, so two
  visually identical values keep different bytes — the fingerprint-dedup defeat this
  module exists to close.
  """

  @default_max_bytes 1024
  @max_combining_run 8

  # Headroom for the pre-clamp. Stripping only removes and NFC only composes, so a
  # prefix this size always yields at least `max_bytes` of output when the input had it.
  @clamp_factor 4

  # An escape sequence is short. If no terminator arrives within these bounds the
  # introducer is a stray, not a sequence, and only the introducer is dropped.
  #
  # This is the fix for a real evasion: `skip_to_st/1` previously consumed to
  # end-of-input, so the two bytes "\e]" prefixed to a field emptied it entirely.
  # `classify_traffic/5` raises severity on "password"/"login"/"admin" in that field, so
  # two bytes downgraded the attacker's own alert from :high to :low -- and two bytes on
  # a journald line made it vanish. Rejecting a field on malformed input is an
  # attacker-operated off-switch however it is reached.
  @max_csi_scan 64
  @max_st_scan 512

  defguardp is_c0(cp) when cp < 0x20
  defguardp is_c1(cp) when cp >= 0x80 and cp <= 0x9F
  defguardp is_space_like(cp) when cp in [?\t, ?\n, ?\r]
  # Zero-width and invisible formatting characters. Beyond the obvious joiners this
  # covers LRM/RLM/ALM (directional marks that are not overrides), the invisible
  # mathematical operators, MONGOLIAN VOWEL SEPARATOR, and the interlinear annotation
  # marks. U+2028/2029 are line/paragraph separators, which Elixir's own compiler
  # rejects in source for the same reason.
  defguardp is_zero_width(cp)
            when cp in [
                   0x200B,
                   0x200C,
                   0x200D,
                   0x200E,
                   0x200F,
                   0x061C,
                   0x180E,
                   0x2028,
                   0x2029,
                   0x2060,
                   0xFEFF
                 ] or (cp >= 0x2061 and cp <= 0x2064) or (cp >= 0xFFF9 and cp <= 0xFFFB)

  defguardp is_bidi(cp)
            when (cp >= 0x202A and cp <= 0x202E) or (cp >= 0x2066 and cp <= 0x2069)

  # Combining marks, as guards rather than `Enum.any?` over ranges: the naive form cost
  # 465us per 400 characters on the collector hot path, 57% of total ingest time.
  defguardp is_combining(cp)
            when (cp >= 0x0300 and cp <= 0x036F) or (cp >= 0x0483 and cp <= 0x0489) or
                   (cp >= 0x0591 and cp <= 0x05BD) or (cp >= 0x064B and cp <= 0x065F) or
                   (cp >= 0x0610 and cp <= 0x061A) or (cp >= 0x06D6 and cp <= 0x06DC) or
                   (cp >= 0x0E31 and cp <= 0x0E3A) or (cp >= 0x1AB0 and cp <= 0x1AFF) or
                   (cp >= 0x1DC0 and cp <= 0x1DFF) or (cp >= 0x20D0 and cp <= 0x20FF) or
                   (cp >= 0xFE00 and cp <= 0xFE0F) or (cp >= 0xFE20 and cp <= 0xFE2F)

  @type reason :: :empty | :not_text

  @doc """
  Normalises untrusted text for storage and every downstream sink.

  Returns `{:error, :empty}` when nothing survives, so a field that was *only* hostile
  control characters is treated the same as a missing field.

  ## Options

    * `:max_bytes` — byte cap, default `#{@default_max_bytes}`
  """
  @spec ingest(term(), keyword()) :: {:ok, binary()} | {:error, reason()}
  def ingest(value, opts \\ [])

  def ingest(nil, _opts), do: {:error, :empty}

  def ingest(value, opts) when is_binary(value) do
    max_bytes = Keyword.get(opts, :max_bytes, @default_max_bytes)

    value
    |> clamp_raw(max_bytes * @clamp_factor)
    |> drop_escape_sequences()
    |> strip_dangerous()
    |> normalize_nfc()
    |> String.trim()
    |> truncate_bytes(max_bytes)
    |> case do
      "" -> {:error, :empty}
      cleaned -> {:ok, cleaned}
    end
  end

  def ingest(value, opts) when is_integer(value) or is_float(value) or is_atom(value),
    do: ingest(to_string(value), opts)

  def ingest(_value, _opts), do: {:error, :not_text}

  @doc "`ingest/2`, returning `nil` instead of an error tuple."
  @spec ingest_or_nil(term(), keyword()) :: binary() | nil
  def ingest_or_nil(value, opts \\ []) do
    case ingest(value, opts) do
      {:ok, cleaned} -> cleaned
      {:error, _reason} -> nil
    end
  end

  @doc """
  True when `value` contains a character `ingest/2` would strip.

  A direct single-pass scan, not a re-run of `ingest/2`. Two reasons that matters:

    * cost — this is called per field on the capture hot path
    * correctness — `ingest/2` also rewrites `\t` to a space, so comparing its output to
      the input reports *every* tab-separated line as modified. Using that as an
      injection signal made `injection_attempt?` true for every benign tshark line and
      turned the collector into an alert generator.

  Whitespace is deliberately not suspicious. Control sequences, C1, bidi overrides and
  zero-width characters are.
  """
  @spec suspicious?(term()) :: boolean()
  def suspicious?(value) when is_binary(value), do: scan_suspicious(value)
  def suspicious?(_value), do: false

  defp scan_suspicious(<<>>), do: false
  defp scan_suspicious(<<0x1B, _rest::binary>>), do: true
  defp scan_suspicious(<<0xC2, byte, _rest::binary>>) when byte >= 0x80 and byte <= 0x9F, do: true

  defp scan_suspicious(<<byte, rest::binary>>) when byte < 0x20 or byte == 0x7F do
    if byte in [?\t, ?\n, ?\r], do: scan_suspicious(rest), else: true
  end

  defp scan_suspicious(<<codepoint::utf8, rest::binary>>) do
    if is_zero_width(codepoint) or is_bidi(codepoint),
      do: true,
      else: scan_suspicious(rest)
  end

  defp scan_suspicious(<<_byte, rest::binary>>), do: scan_suspicious(rest)

  @doc """
  True when `ingest/2` would remove something — malformed bytes, controls, or overflow.

  Lets a collector count and log what it dropped, so a scrub is an observable event
  rather than a silent gap.
  """
  @spec scrubbed?(term(), keyword()) :: boolean()
  def scrubbed?(value, opts \\ []) when is_binary(value) do
    case ingest(value, opts) do
      {:ok, cleaned} -> cleaned != String.trim(value)
      {:error, _reason} -> true
    end
  end

  @doc """
  Final guard before a terminal write.

  `ingest/2` already removed these; this is the renderer keeping its own guarantee
  rather than trusting that every upstream path remembered to.
  """
  @spec for_terminal(term()) :: binary()
  def for_terminal(value),
    do: value |> to_string() |> drop_escape_sequences() |> strip_dangerous()

  @doc """
  Wraps untrusted text for a model's context.

  The delimiter carries a per-call random nonce, so text containing a closing delimiter
  cannot forge the end of the span. Delimiting is weak alone and is not claimed as an
  injection defense; it composes with egress projections and lets a prompt state which
  spans are data.
  """
  @spec for_model(binary(), keyword()) :: binary()
  def for_model(text, opts \\ []) when is_binary(text) do
    origin = Keyword.get(opts, :origin, :untrusted)
    nonce = 9 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

    "[untrusted:#{nonce} origin=#{origin}]\n#{text}\n[/untrusted:#{nonce}]"
  end

  @doc "Digest of the bytes as received, so sanitised text stays linkable to evidence."
  @spec original_sha256(binary()) :: binary()
  def original_sha256(value) when is_binary(value),
    do: :sha256 |> :crypto.hash(value) |> Base.encode16(case: :lower)

  @doc "The byte cap applied when no `:max_bytes` option is given."
  @spec default_max_bytes() :: pos_integer()
  def default_max_bytes, do: @default_max_bytes

  # Bounds work to the cap before any per-character pass. Without this, ingest cost is
  # O(input) rather than O(cap), and the port buffers are attacker-sized: an 8MB line
  # took 4.2s and blocked the collector.
  defp clamp_raw(value, limit) when byte_size(value) <= limit, do: value
  defp clamp_raw(value, limit), do: binary_part(value, 0, limit)

  # NFC is a no-op for ASCII, and the check is far cheaper than the conversion.
  defp normalize_nfc(text) do
    if ascii?(text) do
      text
    else
      case :unicode.characters_to_nfc_binary(text) do
        result when is_binary(result) -> result
        _other -> text
      end
    end
  end

  defp ascii?(<<>>), do: true
  defp ascii?(<<byte, rest::binary>>) when byte < 0x80, do: ascii?(rest)
  defp ascii?(_text), do: false

  # Removes complete escape sequences -- introducer, parameters and terminator.
  #
  # Stripping only the ESC byte leaves the payload as visible text, so
  # "\\e]52;c;cHduZWQ=\\a" would become the literal "]52;c;cHduZWQ=": inert, but still
  # attacker-chosen text in an alert title. Both the ESC-introduced (7-bit) and C1
  # (8-bit) forms are handled, because U+009B *is* CSI and contains no ESC byte at all.
  # The byte fallback also drops malformed UTF-8, which is why validation is not a
  # separate rejecting pass.
  defp drop_escape_sequences(text), do: drop_sequences(text, [])

  defp drop_sequences(<<>>, acc), do: acc |> Enum.reverse() |> List.to_string()

  defp drop_sequences(<<0x1B, ?[, rest::binary>>, acc), do: drop_sequences(skip_csi(rest), acc)
  defp drop_sequences(<<0xC2, 0x9B, rest::binary>>, acc), do: drop_sequences(skip_csi(rest), acc)

  defp drop_sequences(<<0x1B, introducer, rest::binary>>, acc) when introducer in ~c"]PX^_",
    do: drop_sequences(skip_string_payload(rest), acc)

  defp drop_sequences(<<0xC2, introducer, rest::binary>>, acc)
       when introducer in [0x90, 0x98, 0x9D, 0x9E, 0x9F],
       do: drop_sequences(skip_string_payload(rest), acc)

  defp drop_sequences(<<0x1B, _byte, rest::binary>>, acc), do: drop_sequences(rest, acc)
  defp drop_sequences(<<0x1B>>, acc), do: drop_sequences(<<>>, acc)

  defp drop_sequences(<<codepoint::utf8, rest::binary>>, acc),
    do: drop_sequences(rest, [codepoint | acc])

  defp drop_sequences(<<_invalid_byte, rest::binary>>, acc), do: drop_sequences(rest, acc)

  defp skip_csi(rest) do
    case find_csi_final(rest, 0) do
      {:ok, tail} -> tail
      :not_found -> rest
    end
  end

  defp find_csi_final(<<>>, _scanned), do: :not_found
  defp find_csi_final(_binary, scanned) when scanned > @max_csi_scan, do: :not_found

  defp find_csi_final(<<final, rest::binary>>, _scanned) when final >= 0x40 and final <= 0x7E,
    do: {:ok, rest}

  defp find_csi_final(<<_byte, rest::binary>>, scanned), do: find_csi_final(rest, scanned + 1)

  defp skip_string_payload(rest) do
    case find_st(rest, 0) do
      {:ok, tail} -> tail
      :not_found -> rest
    end
  end

  defp find_st(<<>>, _scanned), do: :not_found
  defp find_st(_binary, scanned) when scanned > @max_st_scan, do: :not_found
  defp find_st(<<0x07, rest::binary>>, _scanned), do: {:ok, rest}
  defp find_st(<<0x1B, ?\\, rest::binary>>, _scanned), do: {:ok, rest}
  defp find_st(<<0xC2, 0x9C, rest::binary>>, _scanned), do: {:ok, rest}
  defp find_st(<<_byte, rest::binary>>, scanned), do: find_st(rest, scanned + 1)

  # One pass, guard-dispatched, also bounding combining-mark runs so a single grapheme
  # cannot span hundreds of terminal cells.
  defp strip_dangerous(text), do: text |> String.to_charlist() |> strip([], 0)

  defp strip([], acc, _run), do: acc |> Enum.reverse() |> List.to_string()

  defp strip([cp | rest], acc, _run) when is_space_like(cp), do: strip(rest, [?\s | acc], 0)
  defp strip([cp | rest], acc, run) when is_c0(cp), do: strip(rest, acc, run)
  defp strip([0x7F | rest], acc, run), do: strip(rest, acc, run)
  defp strip([cp | rest], acc, run) when is_c1(cp), do: strip(rest, acc, run)
  defp strip([cp | rest], acc, run) when is_zero_width(cp), do: strip(rest, acc, run)
  defp strip([cp | rest], acc, run) when is_bidi(cp), do: strip(rest, acc, run)

  defp strip([cp | rest], acc, run) when is_combining(cp) do
    if run < @max_combining_run,
      do: strip(rest, [cp | acc], run + 1),
      else: strip(rest, acc, run)
  end

  defp strip([cp | rest], acc, _run), do: strip(rest, [cp | acc], 0)

  # Cuts on a grapheme boundary, so the result is never invalid UTF-8 or a split cluster.
  defp truncate_bytes(text, max_bytes) when byte_size(text) <= max_bytes, do: text

  defp truncate_bytes(text, max_bytes) do
    text
    |> String.graphemes()
    |> Enum.reduce_while({[], 0}, fn grapheme, {acc, size} ->
      next = size + byte_size(grapheme)
      if next > max_bytes, do: {:halt, {acc, size}}, else: {:cont, {[grapheme | acc], next}}
    end)
    |> elem(0)
    |> Enum.reverse()
    |> Enum.join()
  end
end

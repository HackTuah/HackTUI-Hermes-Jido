defmodule HacktuiSensor.Collectors.NetworkHostileTest do
  @moduledoc """
  Adversarial input for the network collector, which had no tests at all despite
  being 658 lines that parse attacker-influenced bytes.

  `handle_info({port, {:data, _}}, state)` is the real seam -- it is what the tshark
  port calls -- so these drive it directly rather than mocking a port.
  """
  use ExUnit.Case, async: false

  alias HacktuiHub.IngestService
  alias HacktuiSensor.Collectors.Network

  @osc52 "\e]52;c;cHduZWQ=\a"
  # No tabs (they are field separators) and no newline (line separator).
  @hostile "\e]52;c;cHduZWQ=\a" <> "\e[2J" <> <<0xC2, 0x9B>> <> "2J" <> "\r" <> "\u202Eevil"

  setup_all do
    {:ok, _started} = Application.ensure_all_started(:hacktui_sensor)
    :ok
  end

  defp state do
    %{
      enabled?: true,
      interface: "any",
      host_identity: "test-host",
      source_node: "nonode@nohost",
      port: nil,
      buffer: "",
      tshark_path: "/usr/bin/tshark",
      last_error: nil,
      consecutive_failures: 0,
      started_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  defp feed(line), do: Network.handle_info({:port_stub, {:data, line <> "\n"}}, state())

  # A well-formed 15-field tshark line, hostile bytes in the attacker-chosen columns.
  defp tshark_line(payload) do
    Enum.join(
      [
        "10.0.0.4",
        "93.184.216.34",
        "",
        "",
        "51000",
        "443",
        "",
        "",
        payload,
        payload,
        payload,
        "GET",
        "/x?q=" <> payload,
        "TCP",
        "creds password " <> payload
      ],
      "\t"
    )
  end

  # tshark_line/1 deliberately seeds "password" into the info column so the keyword
  # classifier fires; a benign control needs a line without it.
  defp benign_line(payload) do
    Enum.join(
      [
        "10.0.0.4",
        "93.184.216.34",
        "",
        "",
        "51000",
        "443",
        "",
        "",
        "example.com",
        "example.com",
        "example.com",
        "GET",
        "/index.html",
        "TCP",
        payload
      ],
      "\t"
    )
  end

  defp emitted_observations do
    Enum.flat_map(IngestService.recent_observations(), fn obs ->
      obs |> Map.take([:payload, :summary, :raw_message, :metadata]) |> binaries()
    end)
  end

  # Collect the RAW binaries from the observation. inspect/1 must not be used here:
  # it escapes control characters into printable text ("\\e"), so a control-byte scan
  # over inspected output can never fail -- the assertion would be vacuous.
  defp binaries(value) when is_binary(value), do: [value]
  defp binaries(value) when is_map(value), do: value |> Map.values() |> Enum.flat_map(&binaries/1)
  defp binaries(value) when is_list(value), do: Enum.flat_map(value, &binaries/1)
  defp binaries(_value), do: []

  # Ingest stringifies metadata keys and values, so read both forms rather than assume.
  defp injection_flags do
    IngestService.recent_observations()
    |> Enum.filter(&(to_string(Map.get(&1, :kind)) == "network.flow"))
    |> Enum.map(fn obs ->
      metadata = Map.get(obs, :metadata, %{})

      value =
        Map.get(metadata, :injection_attempt?) ||
          Map.get(metadata, "injection_attempt?") ||
          false

      to_string(value) == "true"
    end)
  end

  defp flow_severities do
    IngestService.recent_observations()
    |> Enum.filter(&(to_string(Map.get(&1, :kind)) == "network.flow"))
    |> Enum.map(&(&1 |> Map.get(:payload, %{}) |> Map.get("severity") |> to_string()))
  end

  # ObservationAccepted has no :summary field -- only payload["summary"] exists. Reading
  # obs.summary returned nil, so `byte_size(nil || "") <= 255` passed with the cap
  # deleted. The assertion has to read the key the value actually lives under.
  defp payload_summaries do
    IngestService.recent_observations()
    |> Enum.map(&(&1 |> Map.get(:payload, %{}) |> Map.get("summary")))
    |> Enum.filter(&is_binary/1)
  end

  defp assert_no_control_bytes(text, label) do
    bad =
      text
      |> :binary.bin_to_list()
      |> Enum.chunk_every(2, 1, [0])
      |> Enum.filter(fn
        [0xC2, next] -> next >= 0x80 and next <= 0x9F
        [byte, _next] -> byte < 0x20 or byte == 0x7F
      end)

    assert bad == [], "#{label} carried control bytes: #{inspect(Enum.map(bad, &hd/1))}"
  end

  describe "an unparsed line never has its bytes inlined" do
    test "the report describes the line's shape, not its content" do
      {:noreply, next} = feed(@osc52 <> "pwned")

      # Before: emit_error_observation("unparsed tshark output: " <> raw) put these
      # bytes into raw_message at severity "high", auto-promoted to an alert title.
      refute next.last_error =~ "\e"
      refute next.last_error =~ "52;c;"
    end

    test "last_error carries no escape sequence" do
      {:noreply, next} = feed("\e[2J\e[Hforged")

      refute next.last_error =~ "\e"
      assert is_binary(next.last_error)
    end

    test "a C1-encoded control is stripped from retained state" do
      {:noreply, next} = feed(<<0xC2, 0x9B>> <> "2Jhostile")

      refute String.contains?(next.last_error, <<0xC2, 0x9B>>)
    end
  end

  describe "the parsed-field path -- DNS name, SNI, HTTP host, URI, column info" do
    setup do
      IngestService.reset_recent_observations()
      :ok
    end

    test "hostile field content never reaches the emitted observation" do
      {:noreply, _state} = feed(tshark_line(@hostile))

      observations = emitted_observations()
      assert observations != [], "expected the parsed line to emit an observation"

      for rendered <- observations do
        assert_no_control_bytes(rendered, "emitted observation")
        refute rendered =~ "\u202E"
      end
    end

    test "an oversized field cannot produce a summary that overflows the title column" do
      {:noreply, _state} = feed(tshark_line(String.duplicate("A", 4_000)))

      summaries = payload_summaries()
      assert summaries != [], "expected an emitted observation to assert on"

      for summary <- summaries do
        assert byte_size(summary) <= 255,
               "summary #{byte_size(summary)} bytes exceeds varchar(255)"
      end
    end

    test "invalid UTF-8 in a field cannot downgrade the severity classification" do
      # Scrubbing rather than rejecting: if one bad byte nulled the field, "password"
      # would vanish from `info` and classify_traffic/5 would drop the alert to :low.
      {:noreply, _state} = feed(tshark_line(<<"admin", 0xFF>>))

      assert Enum.any?(emitted_observations(), &(&1 =~ "admin"))
    end
  end

  describe "escape sequences cannot be used to steer classification" do
    setup do
      IngestService.reset_recent_observations()
      :ok
    end

    test "a stray introducer does not downgrade severity" do
      {:noreply, _s} = feed(tshark_line("\e]admin password"))

      refute "low" in flow_severities(),
             "a stray OSC introducer must not empty the field and drop severity"
    end

    test "a line carrying control sequences is recorded, not silently normal" do
      # Same line as the benign control, differing only by an escape sequence.
      {:noreply, _s} = feed(benign_line("\e[2Jbenign looking"))

      assert "medium" in flow_severities(),
             "telemetry containing terminal control sequences is not normal traffic"

      assert Enum.any?(injection_flags()), "the attempt must stay queryable in metadata"
    end

    test "a BENIGN flow is not escalated -- the detector must carry information" do
      # scrubbed?/2 on the tab-joined line reported every flow as an injection attempt,
      # because the sanitiser rewrites \t to a space and tshark's separator is tab.
      # Every benign flow was floored to "high": a 100%-false-positive detector.
      {:noreply, _s} = feed(benign_line("GET /index.html HTTP/1.1"))

      assert flow_severities() == ["low"]
      refute Enum.any?(injection_flags())
    end
  end

  describe "the error path is bounded like every other path" do
    setup do
      IngestService.reset_recent_observations()
      :ok
    end

    test "an error line cannot produce an oversized title" do
      # likely_error_line?/1 matches on the whole line and runs BEFORE field parsing,
      # so it bypassed the summary cap and produced a 527-byte title.
      {:noreply, _s} = feed("permission denied " <> String.duplicate("A", 4_000))

      summaries = payload_summaries()
      assert summaries != [], "expected an emitted observation to assert on"

      for summary <- summaries do
        assert byte_size(summary) <= 255
      end
    end
  end

  describe "the bounds are real, not decorative" do
    setup do
      IngestService.reset_recent_observations()
      :ok
    end

    test "a field is capped, not merely sanitised" do
      {:noreply, _s} = feed(tshark_line(String.duplicate("B", 4_000)))

      # Assert against the field cap itself. The previous bound was 1_024 while the
      # message said 512, so raising @max_field_bytes to 1_000 changed nothing.
      values = emitted_observations()
      assert values != [], "expected an emitted observation to assert on"

      for value <- values do
        assert byte_size(value) <= 512 + 64,
               "a value reached #{byte_size(value)} bytes; @max_field_bytes is 512"
      end
    end

    test "the network port buffer is bounded, like the journald one" do
      # FINDINGS claimed both were bounded; only journald had a test.
      state = %{state() | buffer: ""}

      {:noreply, next} =
        Network.handle_info({:port_stub, {:data, String.duplicate("A", 500_000)}}, state)

      assert byte_size(next.buffer) <= 64 * 1024,
             "buffer grew to #{byte_size(next.buffer)} bytes with no newline"
    end
  end

  describe "the emitted observation, not just retained state" do
    setup do
      IngestService.reset_recent_observations()
      :ok
    end

    test "an unparsed hostile line does not put raw bytes into the observation" do
      {:noreply, _state} = feed(@hostile <> "pwned")

      rendered_all = emitted_observations()
      assert rendered_all != [], "expected an emitted observation to assert on"

      for rendered <- rendered_all do
        assert_no_control_bytes(rendered, "error observation")
        refute rendered =~ "52;c;"
      end
    end
  end

  describe "an error line is sanitised before it is retained" do
    test "tshark stderr containing an escape sequence" do
      {:noreply, next} = feed("tshark: permission denied " <> @osc52)

      refute next.last_error =~ "\e"
      assert next.last_error =~ "permission denied"
    end
  end

  test "an oversized line cannot be retained unbounded" do
    {:noreply, next} = feed(String.duplicate("A", 20_000))

    assert byte_size(next.last_error) < 2_000
  end
end

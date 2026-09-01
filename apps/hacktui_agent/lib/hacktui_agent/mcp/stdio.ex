defmodule HacktuiAgent.MCP.Stdio do
  @moduledoc false

  alias HacktuiAgent.MCP.Server

  @spec run(keyword()) :: :ok
  def run(opts \\ []) do
    loop(Server.new(opts))
  end

  defp loop(state) do
    case read_message() do
      :eof ->
        :ok

      {:ok, message} ->
        {next_state, response} = Server.handle_message(state, message)

        if response do
          write_message(response)
        end

        if Server.shutdown?(next_state) do
          :ok
        else
          loop(next_state)
        end

      {:error, reason} ->
        write_message(%{
          "jsonrpc" => "2.0",
          "id" => nil,
          "error" => %{"code" => -32_700, "message" => "Parse error", "data" => inspect(reason)}
        })

        loop(state)
    end
  end

  # MCP stdio framing is newline-delimited JSON-RPC. The spec at 2024-11-05 -- the
  # revision this server advertises -- and every revision since:
  #
  #   "Messages are delimited by newlines, and MUST NOT contain embedded newlines."
  #
  # This previously implemented LSP framing (Content-Length headers), so no conformant
  # MCP client could complete a handshake. Content-Length is still accepted on read so
  # existing callers keep working, but responses are always newline-delimited.
  @max_line_bytes 1_048_576
  @max_body_bytes 1_048_576

  defp read_message do
    case read_line_bounded() do
      :eof ->
        :eof

      {:error, reason} ->
        {:error, reason}

      {:ok_line, line} ->
        trimmed = String.trim_trailing(line, "\r")

        cond do
          trimmed == "" -> read_message()
          content_length_header?(trimmed) -> read_legacy_framed(trimmed)
          true -> decode(trimmed)
        end
    end
  end

  # Reads one newline-terminated line, refusing to allocate past @max_line_bytes.
  # The cap has to bound the read, not merely inspect its result.
  defp read_line_bounded(acc \\ [], size \\ 0)

  defp read_line_bounded(_acc, size) when size >= @max_line_bytes,
    do: {:error, :frame_too_large}

  defp read_line_bounded(acc, size) do
    case IO.binread(:stdio, 1) do
      :eof when acc == [] -> :eof
      :eof -> {:ok_line, acc |> Enum.reverse() |> IO.iodata_to_binary()}
      {:error, reason} -> {:error, reason}
      "\n" -> {:ok_line, acc |> Enum.reverse() |> IO.iodata_to_binary()}
      byte -> read_line_bounded([byte | acc], size + 1)
    end
  end

  defp decode(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} = error -> error
    end
  end

  defp content_length_header?(line) do
    line |> String.downcase() |> String.starts_with?("content-length:")
  end

  # Legacy LSP-style framing, retained for callers written against the old behaviour.
  defp read_legacy_framed(first_line) do
    with {:ok, length} <- parse_content_length(first_line),
         :ok <- skip_remaining_headers(),
         {:ok, body} <- read_body(length) do
      decode(body)
    else
      {:error, :unexpected_eof} -> :eof
      {:error, _} = error -> error
    end
  end

  defp skip_remaining_headers do
    case IO.binread(:stdio, :line) do
      :eof -> :ok
      {:error, reason} -> {:error, reason}
      line -> if String.trim(line) == "", do: :ok, else: skip_remaining_headers()
    end
  end

  defp parse_content_length(line) do
    case String.split(line, ":", parts: 2) do
      [_name, value] ->
        case Integer.parse(String.trim(value)) do
          {length, ""} when length >= 0 and length <= @max_body_bytes -> {:ok, length}
          {length, ""} when length > @max_body_bytes -> {:error, :frame_too_large}
          _ -> {:error, :invalid_content_length}
        end

      _ ->
        {:error, :missing_content_length}
    end
  end

  defp read_body(length) when is_integer(length) and length >= 0 do
    case IO.binread(:stdio, length) do
      :eof -> {:error, :unexpected_eof}
      {:error, reason} -> {:error, reason}
      body -> {:ok, body}
    end
  end

  # Always newline-delimited, per the MCP stdio binding. Jason never emits a raw
  # newline inside a JSON scalar, so the "MUST NOT contain embedded newlines"
  # requirement holds.
  defp write_message(message) do
    IO.binwrite(:stdio, [Jason.encode!(message), "\n"])
  end
end

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

  defp read_message do
    case read_headers("") do
      :eof ->
        :eof

      {:ok, headers} ->
        with {:ok, content_length} <- parse_content_length(headers),
             {:ok, body} <- read_body(content_length),
             {:ok, decoded} <- Jason.decode(body) do
          {:ok, decoded}
        else
          {:error, :unexpected_eof} -> :eof
          {:error, _} = error -> error
        end
    end
  end

  defp read_headers(buffer) do
    case IO.binread(:stdio, 1) do
      :eof when buffer == "" -> :eof
      :eof -> {:error, :unexpected_eof}
      {:error, reason} -> {:error, reason}
      byte ->
        next = buffer <> byte

        if String.ends_with?(next, "\r\n\r\n") do
          {:ok, next}
        else
          read_headers(next)
        end
    end
  end

  defp parse_content_length(headers) do
    headers
    |> String.split("\r\n", trim: true)
    |> Enum.find_value(fn line ->
      case String.split(line, ":", parts: 2) do
        [name, value] ->
          if String.downcase(String.trim(name)) == "content-length" do
            case Integer.parse(String.trim(value)) do
              {length, ""} when length >= 0 -> {:ok, length}
              _ -> {:error, :invalid_content_length}
            end
          else
            nil
          end

        _ ->
          nil
      end
    end)
    |> case do
      nil -> {:error, :missing_content_length}
      result -> result
    end
  end

  defp read_body(length) when is_integer(length) and length >= 0 do
    case IO.binread(:stdio, length) do
      :eof -> {:error, :unexpected_eof}
      {:error, reason} -> {:error, reason}
      body -> {:ok, body}
    end
  end

  defp write_message(message) do
    payload = Jason.encode!(message)

    IO.binwrite(:stdio, [
      "Content-Length: ",
      Integer.to_string(byte_size(payload)),
      "\r\nContent-Type: application/json\r\n\r\n",
      payload
    ])
  end
end

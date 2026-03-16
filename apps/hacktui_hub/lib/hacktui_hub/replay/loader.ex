defmodule HacktuiHub.Replay.Loader do
  @moduledoc false

  alias HacktuiCore.Observation.Envelope

  @spec load_fixture!(Path.t()) :: [Envelope.t()]
  def load_fixture!(path) do
    path
    |> resolve_path()
    |> File.stream!([], :line)
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Enum.map(&parse_line!/1)
  end

  defp resolve_path(path) do
    cond do
      Path.type(path) == :absolute ->
        path

      File.exists?(Path.expand(path, File.cwd!())) ->
        Path.expand(path, File.cwd!())

      true ->
        Path.expand(Path.join(["..", "..", "..", "..", "..", path]), __DIR__)
    end
  end

  defp parse_line!(line) do
    attrs = Jason.decode!(line)

    envelope = Envelope.new(attrs["source"], attrs["kind"], attrs["payload"] || %{})

    %Envelope{
      envelope
      | received_at: parse_received_at(attrs["received_at"]),
        metadata: attrs["metadata"] || %{}
    }
  end

  defp parse_received_at(nil), do: nil

  defp parse_received_at(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, reason} -> raise ArgumentError, "invalid received_at #{inspect(value)}: #{inspect(reason)}"
    end
  end
end

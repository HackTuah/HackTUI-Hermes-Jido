defmodule HacktuiSensor.Collectors.JournaldHostileTest do
  @moduledoc """
  The journald path had no sanitiser at all before this slice -- it assigned
  `raw_message: line` straight from the port -- and it had no test either, so deleting
  the fix was invisible to the suite. Any local process able to write to the journal
  chooses these bytes.
  """
  use ExUnit.Case, async: false

  alias HacktuiHub.IngestService
  alias HacktuiSensor.Collectors.Journald

  @hostile "\e]52;c;cHduZWQ=\a" <> "\e[2J" <> <<0xC2, 0x9B>> <> "2J" <> "\r" <> "\u202Eevil"

  setup_all do
    {:ok, _started} = Application.ensure_all_started(:hacktui_sensor)
    :ok
  end

  setup do
    IngestService.reset_recent_observations()
    :ok
  end

  defp state do
    %{
      enabled?: true,
      lines: 20,
      host_identity: "test-host",
      source_node: "nonode@nohost",
      port: nil,
      buffer: ""
    }
  end

  defp feed(line), do: Journald.handle_info({:port_stub, {:data, line <> "\n"}}, state())

  defp emitted do
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

  # ObservationAccepted has no :summary field -- only payload["summary"] exists. Reading
  # obs.summary returned nil, so `byte_size(nil || "") <= 255` passed with the cap
  # deleted. The assertion has to read the key the value actually lives under.
  defp payload_summaries do
    IngestService.recent_observations()
    |> Enum.map(&(&1 |> Map.get(:payload, %{}) |> Map.get("summary")))
    |> Enum.filter(&is_binary/1)
  end

  defp control_bytes(text) do
    text
    |> :binary.bin_to_list()
    |> Enum.chunk_every(2, 1, [0])
    |> Enum.filter(fn
      [0xC2, next] -> next >= 0x80 and next <= 0x9F
      [byte, _next] -> byte < 0x20 or byte == 0x7F
    end)
    |> Enum.map(&hd/1)
  end

  test "a hostile journal line reaches the observation with no control bytes" do
    {:noreply, _next} = feed("sshd[42]: Failed password for root " <> @hostile)

    observations = emitted()
    assert observations != [], "expected the journal line to emit an observation"

    for rendered <- observations do
      assert control_bytes(rendered) == []
      refute rendered =~ "\u202E"
      refute rendered =~ "52;c;"
    end
  end

  test "classification still sees the text after sanitising" do
    # The line is sanitised before classify_line/1 runs, so what drives the severity
    # decision is the same text that gets stored. A hostile suffix must not change it.
    {:noreply, _next} = feed("sshd[42]: Failed password for root" <> @hostile)

    assert Enum.any?(emitted(), &(&1 =~ "Failed password"))
  end

  test "invalid UTF-8 does not discard the line" do
    {:noreply, _next} = feed(<<"sshd[42]: Failed password for root", 0xFF, 0xFE>>)

    assert Enum.any?(emitted(), &(&1 =~ "Failed password"))
  end

  test "a multi-byte line cannot overflow the title column" do
    # classify_line/1 falls back to shorten(line, 120), which counts CHARACTERS. 120
    # multi-byte characters is ~360 bytes -- still over varchar(255). The byte cap is
    # what actually bounds it, and only a multi-byte fixture can tell the two apart.
    {:noreply, _next} = feed("kernel: " <> String.duplicate("\u6F22", 400))

    summaries = payload_summaries()
    assert summaries != [], "expected an emitted observation to assert on"

    for summary <- summaries do
      assert byte_size(summary) <= 255,
             "summary #{byte_size(summary)} bytes exceeds varchar(255)"
    end
  end

  test "an oversized journal line cannot overflow the title column" do
    {:noreply, _next} = feed("kernel: " <> String.duplicate("A", 8_000))

    summaries = payload_summaries()
    assert summaries != [], "expected an emitted observation to assert on"

    for summary <- summaries do
      assert byte_size(summary) <= 255
    end
  end

  test "an unterminated line does not grow the buffer without bound" do
    huge = String.duplicate("A", 200_000)
    {:noreply, next} = Journald.handle_info({:port_stub, {:data, huge}}, state())

    assert byte_size(next.buffer) <= 64 * 1024
  end
end

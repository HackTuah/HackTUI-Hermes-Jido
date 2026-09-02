defmodule HacktuiTui.TerminalSinkTest do
  @moduledoc """
  Asserts at the sink, not at the sanitiser.

  Testing `Text.ingest/1` in isolation proves the sanitiser works; it does not prove
  the terminal is safe, because a renderer can reintroduce or pass through escapes on
  a path that never called it. `take_visible/3` did exactly that -- it preserved CSI
  and had no clause for OSC at all. So these tests drive hostile values through the
  real `render/3` and inspect the bytes that reach `IO.write`.
  """
  use ExUnit.Case, async: true

  alias HacktuiTui.LiveDashboardView

  # OSC 52 writes the operator's clipboard; CSI 2J clears their screen. C1 CSI is the
  # same control encoded as UTF-8, carrying no ESC byte at all.
  @osc52 "\e]52;c;cHduZWQ=\a"
  @clear "\e[2J\e[H"
  @c1_csi <<0xC2, 0x9B>> <> "2J"
  @bidi "\u202Etxt.exe"
  @cr "ZQA\rZQB"

  defp ui_state do
    %{
      mode: :normal,
      query: "",
      pending_query: "",
      focused_pane: :observations,
      selected_pane: :observations,
      selected_index: 0,
      selections: %{alerts: 0, cases: 0, observations: 0},
      panes: [:alerts, :cases, :observations]
    }
  end

  # Renders at three widths, because wide/medium/narrow layouts use different
  # renderers and only some of them go through truncate_plain. The flows panel reaches
  # take_visible via truncate_rendered, which the first version of this test never
  # exercised -- so it only ever proved the path that was already safe.
  defp render(hostile), do: Enum.map_join([160, 120, 90], "\n", &render_at(hostile, &1))

  defp render_at(hostile, width) do
    LiveDashboardView.render(
      %{
        health: %{summary: "ok"},
        refreshed_at: "now",
        status_line: "ready",
        alerts: [%{severity: "high", title: hostile, metadata: %{}}],
        cases: [],
        observations: [
          %{
            kind: "network.flow",
            accepted_at: ~U[2026-03-14 00:00:00Z],
            metadata: %{},
            payload: %{
              "src" => "10.0.0.4",
              "dst" => hostile,
              "site" => hostile,
              "service" => hostile,
              "proto" => "TCP",
              summary: hostile,
              raw_message: hostile
            }
          }
        ]
      },
      ui_state(),
      width: width,
      height: 60
    )
  end

  # Everything this module legitimately emits is SGR ("\e[" digits/semicolons "m") plus
  # newline. Strip those and inspect what is left BYTE BY BYTE.
  #
  # The first version of this helper split on "\e" and was therefore blind, by
  # construction, to CR, BEL, BS and C1 -- none of which contain an ESC byte, and any
  # of which forges console content. CR alone re-homes the cursor and overwrites the
  # row already rendered.
  defp control_bytes(output) do
    output
    |> String.replace(~r/\e\[[0-9;]*m/, "")
    |> :binary.bin_to_list()
    |> Enum.chunk_every(2, 1, [0])
    |> Enum.filter(fn
      [0xC2, next] -> next >= 0x80 and next <= 0x9F
      [byte, _next] -> (byte < 0x20 and byte != ?\n) or byte == 0x7F
    end)
    |> Enum.map(&hd/1)
  end

  describe "no escape sequence from untrusted content reaches the terminal" do
    test "OSC 52 clipboard write" do
      assert control_bytes(render(@osc52)) == []
    end

    test "CSI screen clear and cursor home" do
      assert control_bytes(render(@clear)) == []
    end

    test "C1 CSI encoded as UTF-8" do
      output = render(@c1_csi)
      assert control_bytes(output) == []
      refute String.contains?(output, <<0xC2, 0x9B>>)
    end

    test "carriage return, which forges a row with no escape sequence at all" do
      assert control_bytes(render(@cr)) == []
    end

    test "bidi override" do
      refute String.contains?(render(@bidi), "\u202E")
    end

    test "all of them at once, in one value" do
      assert control_bytes(render(@osc52 <> @clear <> @c1_csi <> @bidi <> @cr)) == []
    end

    test "no injected row: hostile content cannot add lines to the frame" do
      baseline = render_at("benign", 160) |> String.split("\n") |> length()
      hostile = render_at(@cr <> @clear <> @c1_csi, 160) |> String.split("\n") |> length()

      assert hostile == baseline
    end
  end

  test "invalid UTF-8 after an escape introducer does not kill the render loop" do
    # take_ansi_sequence/2 had no byte fallback, so this raised FunctionClauseError --
    # and render/3 is called straight from HacktuiTui.loop/3, so the console died. A
    # renderer that crashes on the input class it exists to sanitise is not a defense.
    for payload <- [<<"\e[", 0xFF, "m">>, <<0xC2, 0x9B, 0xFF, "m">>, <<"\e]", 0xFF>>] do
      assert is_binary(render_at(payload, 160))
    end
  end

  test "wide characters cannot widen a row past its budget, at every width" do
    # Cells, not graphemes: a CJK ideograph or emoji is two columns, so a row budgeted
    # at 160 rendered 201 cells, wrapped, and shifted every following row. Each width is
    # checked against its own budget -- rendering all three and asserting <= 160 never
    # tested the 120 and 90 layouts at all.
    # The first version of this test used only U+6F22 and U+1F525 -- both inside the
    # implementation's original two emoji blocks -- while its own oracle used a wider
    # range. ROCKET, BLACK LARGE SQUARE, WATCH and Hangul Jamo Extended-A all overflowed
    # to 241 cells in a 160-column frame and this test did not see it.
    wide = [0x6F22, 0x1F525, 0x1F680, 0x1F6A8, 0x1F7E5, 0x2B1B, 0x231A, 0x1FA79, 0xA960]

    for codepoint <- wide,
        payload = String.duplicate(<<codepoint::utf8>>, 300),
        width <- [160, 121, 91] do
      assert max_cells(render_at(payload, width)) <= width,
             "width #{width} overflowed for U+#{Integer.to_string(codepoint, 16)}"
    end
  end

  test "attacker-supplied SGR does not reach the terminal" do
    # \e[8m is conceal: it hides everything up to the next reset, so untrusted text
    # could blank the remainder of a row on a security console. control_bytes/1 strips
    # SGR before scanning and is blind to this by construction, so it is asserted
    # directly. Our own styling is applied after truncation, so the untrusted leaves can
    # be stripped without losing it.
    output = render_at("\e[8mCONCEALED\e[7mREVERSED", 160)

    refute output =~ "\e[8m"
    refute output =~ "\e[7m"
    assert output =~ "CONCEALED", "the text itself must still render"
  end

  defp clean?(text), do: control_bytes(text) == [] and not (text =~ "\e")

  defp max_cells(output) do
    output
    |> String.split("\n")
    |> Enum.map(fn line ->
      line
      |> String.replace(~r/\e\[[0-9;]*m/, "")
      |> String.to_charlist()
      |> Enum.reduce(0, fn char, total -> total + cell_width(char) end)
    end)
    |> Enum.max()
  end

  # Mirrors the implementation's table. Kept in the test so a narrowing of the real
  # table shows up as a failure rather than as a silently weaker oracle.
  @wide_ranges [
    0x1100..0x115F,
    0x2300..0x23FF,
    0x25A0..0x27BF,
    0x2B00..0x2BFF,
    0x2E80..0xA4CF,
    0xA960..0xA97F,
    0xAC00..0xD7A3,
    0xF900..0xFAFF,
    0xFF00..0xFF60,
    0x16FE0..0x1B2FB,
    0x1F000..0x1FAFF,
    0x20000..0x3FFFD
  ]

  defp cell_width(char) do
    if Enum.any?(@wide_ranges, &(char in &1)), do: 2, else: 1
  end

  describe "the renderer's own guarantee, tested directly" do
    # render/3 sanitises untrusted leaves before they reach truncate_rendered, so these
    # clauses are a redundant second layer that render/3 cannot exercise. That is
    # exactly why they need direct coverage: a defense nothing reaches is a defense
    # nothing verifies, and the next renderer that forgets a leaf depends on it.
    # One named test per class. A single loop over all classes meant a mutant deleting
    # the bidi clause failed the same test as one deleting the ESC clause -- the failure
    # did not name what broke.
    test "ESC-introduced CSI" do
      assert LiveDashboardView.__clip_rendered__("\e[2J\e[HTAIL", 40) == "TAIL"
    end

    test "ESC-introduced string sequences (OSC, DCS, APC, SOS, PM)" do
      for introducer <- ["]", "P", "X", "^", "_"] do
        payload = "\e" <> introducer <> "52;c;cHduZWQ=" <> <<7>> <> "TAIL"

        assert LiveDashboardView.__clip_rendered__(payload, 40) == "TAIL",
               "ESC #{introducer} payload survived"
      end
    end

    test "8-bit C1 CSI (U+009B)" do
      # Assert the PAYLOAD is gone, not merely that no control byte survives. Dropping
      # the two introducer bytes alone leaves "2J" rendering as visible attacker text,
      # and a control-byte scan cannot tell that apart from a working clause.
      assert LiveDashboardView.__clip_rendered__(<<0xC2, 0x9B>> <> "2JTAIL", 40) == "TAIL"
    end

    test "8-bit C1 string introducers (DCS, SOS, OSC, PM, APC)" do
      # These carry a payload to a string terminator. Dropping only the two introducer
      # bytes left "52;c;cHduZWQ=" rendering as visible text.
      for introducer <- [0x90, 0x98, 0x9D, 0x9E, 0x9F] do
        payload = <<0xC2, introducer>> <> "52;c;cHduZWQ=" <> <<7>> <> "TAIL"

        assert LiveDashboardView.__clip_rendered__(payload, 40) == "TAIL",
               "C1 0x#{Integer.to_string(introducer, 16)} payload survived"
      end
    end

    test "C0 controls, including CR" do
      for byte <- 0x00..0x1F, byte != 0x1B do
        assert clean?(LiveDashboardView.__clip_rendered__(<<?a, byte, ?b>>, 40)),
               "C0 0x#{Integer.to_string(byte, 16)} survived"
      end
    end

    test "DEL" do
      assert LiveDashboardView.__clip_rendered__(<<?a, 0x7F, ?b>>, 40) == "ab"
    end

    test "bidi overrides" do
      for cp <- [0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069] do
        clipped = LiveDashboardView.__clip_rendered__("a" <> <<cp::utf8>> <> "b", 40)

        assert clipped == "ab", "U+#{Integer.to_string(cp, 16)} survived"
      end
    end

    test "zero-width and invisible formatting characters" do
      for cp <- [0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x061C, 0x2060, 0xFEFF, 0x2028] do
        clipped = LiveDashboardView.__clip_rendered__("a" <> <<cp::utf8>> <> "b", 40)

        assert clipped == "ab", "U+#{Integer.to_string(cp, 16)} survived"
      end
    end

    test "drops the sequence payload, not merely the ESC byte" do
      # Dropping only ESC leaves "]52;c;cHduZWQ=" as visible attacker-chosen text. The
      # C0 clause removes the ESC on its own, so "no control bytes" cannot distinguish
      # a working OSC clause from a missing one.
      assert LiveDashboardView.__clip_rendered__("\e]52;c;cHduZWQ=\aTAIL", 40) == "TAIL"
      assert LiveDashboardView.__clip_rendered__("\e[2JTAIL", 40) == "TAIL"
    end

    test "a normal-length CSI is consumed entirely" do
      # Pins @max_csi_scan: shrinking it stops ordinary sequences being recognised, so
      # their parameters leak through as text.
      assert LiveDashboardView.__clip_rendered__("\e[38;5;196mRED", 40) == "\e[38;5;196mRED"
      assert LiveDashboardView.__clip_rendered__("\e[1;2;3;4;5HX", 40) == "X"
    end

    test "the SGR allowlist is exactly these eleven sequences" do
      # Enumerated deliberately. The list lives in live_dashboard_view.ex's @emitted_sgr;
      # duplicating it here means adding a twelfth sequence to the renderer requires a
      # deliberate change to this test, rather than silently widening what untrusted text
      # may emit.
      emitted = [
        "\e[0m",
        "\e[1m",
        "\e[38;5;141m",
        "\e[38;5;196m",
        "\e[38;5;220m",
        "\e[38;5;48m",
        "\e[38;5;45m",
        "\e[38;5;250m",
        "\e[38;5;255m",
        "\e[38;5;242m",
        "\e[48;5;236m"
      ]

      # Plausible SGR an attacker would reach for, plus every allowed sequence. Only the
      # allowed ones may survive.
      candidates =
        emitted ++
          ["\e[7m", "\e[8m", "\e[9m", "\e[2m", "\e[5m", "\e[30m", "\e[107m", "\e[38;5;9m"]

      survivors =
        Enum.filter(candidates, fn sgr ->
          LiveDashboardView.__clip_rendered__(sgr <> "X", 10) =~ "\e"
        end)

      assert Enum.sort(survivors) == Enum.sort(emitted)
      assert length(emitted) == 11
    end

    test "drops attacker SGR while keeping our own" do
      assert LiveDashboardView.__clip_rendered__("\e[8mhidden", 40) == "hidden"
      assert LiveDashboardView.__clip_rendered__("\e[38;5;196mred", 40) =~ "\e[38;5;196m"
    end

    test "budgets in cells, so wide characters cannot exceed the width" do
      for codepoint <- [0x6F22, 0x1F680, 0x2B1B, 0x231A, 0xA960] do
        clipped =
          LiveDashboardView.__clip_rendered__(String.duplicate(<<codepoint::utf8>>, 50), 20)

        cells = clipped |> String.to_charlist() |> Enum.reduce(0, &(&2 + cell_width(&1)))

        assert cells <= 20, "U+#{Integer.to_string(codepoint, 16)} rendered #{cells} cells"
      end
    end
  end

  test "our own styling still renders" do
    output = render("ordinary traffic")

    assert output =~ ~r/\e\[[0-9;]*m/, "SGR styling must survive"
    assert output =~ "ordinary traffic"
  end

  test "a long hostile value cannot overflow the row it is rendered into" do
    output = render(String.duplicate("A", 10_000))

    for line <- String.split(output, "\n") do
      visible = String.replace(line, ~r/\e\[[0-9;]*m/, "")
      assert String.length(visible) <= 160
    end
  end
end

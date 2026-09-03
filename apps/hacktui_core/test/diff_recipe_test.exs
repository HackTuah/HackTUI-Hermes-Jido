defmodule HacktuiCore.DiffRecipeTest do
  use ExUnit.Case, async: true

  # The reviewable-diff recipe decides what a commit's attestation covers. It has ONE
  # definition, in tools/gate.sh (`DIFF_RECIPE` and `DIFF_SCOPE`), read by `derive_diff_hash`
  # for the attestation gate and by `staged_diff_hash` for .githooks/pre-commit and
  # tools/signoff.sh.
  #
  # .githooks/commit-msg still carries a second copy. It runs in a context where sourcing
  # tools/gate.sh is a behaviour change, so removing that copy is slice 17's work. Until then
  # the two are held together HERE rather than on faith: if they drift, the trailer a commit
  # writes stops matching the hash the gate derives, and `Gate - attestation` goes red on main
  # for a reason nobody would connect to an edit in a hook.
  #
  # One copy is the goal. Two copies with an equality gate is the acceptable interim. Two
  # copies on faith is the defect class this repository keeps re-finding -- and a grep COUNT
  # is not proof, because two byte-identical copies pass a count. This test compares the token
  # sequences, so a change to either side fails it.
  @root Path.expand("../../..", __DIR__)
  @gate Path.join(@root, "tools/gate.sh")
  @commit_msg Path.join(@root, ".githooks/commit-msg")
  @pre_commit Path.join(@root, ".githooks/pre-commit")

  defp tokens(s), do: s |> String.split(~r/\s+/, trim: true)

  # `DIFF_RECIPE=(-c diff.noprefix=false ...)` -> the tokens between the parentheses.
  # `^` alone was blind to an indented duplicate -- and bash executes an indented assignment
  # exactly like a column-0 one, so `  DIFF_RECIPE=(-c diff.context=9)` inserted before
  # DIFF_SCOPE changed the hash the gate produces while this test still reported 3 tests, 0
  # failures. A canary that a real duplicate walks past is not a canary. `^[ \t]*` counts them.
  defp array(src, name) do
    case Regex.run(~r/^[ \t]*#{name}=\((.*)\)\s*$/m, src, capture: :all_but_first) do
      [body] -> tokens(body)
      _ -> flunk("#{name}=(...) not found in tools/gate.sh, or spans more than one line")
    end
  end

  # Comment lines are stripped, then assignments are counted. The forms this matcher is known to
  # count and known not to count are listed in the test below; it is a matcher, not a bash parser.
  defp non_comment(src) do
    src
    |> String.split("\n")
    |> Enum.reject(&Regex.match?(~r/^\s*#/, &1))
    |> Enum.join("\n")
  end

  # `NAME=(`, `NAME+=(` and `NAME[i]=` are all assignments bash executes. Counting only `=(`
  # was the THIRD form-blindness in this one construct: `^` missed an indented duplicate,
  # `^[ \t]*` missed `;`/`then`/`eval`, and this missed `+=` and `[i]=` — each time while the
  # duplicate measurably moved the hash the gate produces and the canary reported one
  # definition. The forms are now covered by a test rather than by the next reviewer.
  # An ASSIGNMENT, not a use: the bracket form must close and be followed by `=`, and `$`/`{` are
  # excluded from the lookbehind, so `"${NAME[@]}"` does not count. Measured: without that, this
  # test reported 3 definitions of a variable defined once, counting the two array expansions in
  # derive_diff_hash and staged_diff_hash.
  defp count_defs(src, name) do
    length(Regex.scan(~r/(?<![A-Za-z0-9_${])#{name}(\+?=\(|\[[^\]]*\]\+?=)/, non_comment(src)))
  end

  test "tools/gate.sh defines the recipe exactly once" do
    src = File.read!(@gate)

    for name <- ["DIFF_RECIPE", "DIFF_SCOPE"] do
      count = count_defs(src, name)

      assert count == 1,
             "tools/gate.sh has #{count} definitions of #{name}; exactly one is the point. " <>
               "Two byte-identical copies pass a grep count, so the only honest test is a " <>
               "mutation, and a mutation needs exactly one thing to mutate."
    end
  end

  # Nine forms, measured: six that bash executes and the counter counts, three inert ones it does
  # not. Regression locks for forms this file has been bitten by. Asserted against synthetic
  # source rather than by mutating the real file, so they run in the ordinary suite.
  test "nine known assignment forms: six counted, three not" do
    base = "DIFF_RECIPE=(-c diff.context=3)\n"

    live = [
      {"plain second definition", "DIFF_RECIPE=(-c diff.context=9)"},
      {"indented", "  DIFF_RECIPE=(-c diff.context=9)"},
      {"after a semicolon", "true; DIFF_RECIPE=(-c diff.context=9)"},
      {"after then", "if true; then DIFF_RECIPE=(-c diff.context=9); fi"},
      {"append with +=", "DIFF_RECIPE+=(-c diff.context=9)"},
      {"element assignment", "DIFF_RECIPE[1]=--patience"}
    ]

    for {label, form} <- live do
      assert count_defs(base <> form <> "\n", "DIFF_RECIPE") == 2,
             "the counter does not see a duplicate #{label} (#{inspect(form)}), " <>
               "which bash executes."
    end

    # Three inert forms. A counter that matched everything would fail these.
    assert count_defs(base <> "#  DIFF_RECIPE=(-c diff.context=9)\n", "DIFF_RECIPE") == 1,
           "a duplicate quoted inside a comment is inert and must not count"

    assert count_defs(base <> "MY_DIFF_RECIPE=(-c diff.context=9)\n", "DIFF_RECIPE") == 1,
           "a longer variable name that merely ends in DIFF_RECIPE must not count"

    assert count_defs(base <> ~S|  git "${DIFF_RECIPE[@]}" diff --cached| <> "\n", "DIFF_RECIPE") ==
             1,
           "an array EXPANSION is a use, not a definition, and must not count"
  end

  test ".githooks/pre-commit holds no copy of the recipe" do
    refute File.read!(@pre_commit) =~ "diff.noprefix",
           ".githooks/pre-commit carries its own copy of the diff recipe again. It should call " <>
             "`./tools/gate.sh staged-diff-hash` instead."
  end

  test ".githooks/commit-msg's recipe is token-identical to the one in tools/gate.sh" do
    gate = File.read!(@gate)
    recipe = array(gate, "DIFF_RECIPE")
    scope = array(gate, "DIFF_SCOPE")

    # The commit-msg invocation runs from `git ` to the pipe into sha256sum, across
    # backslash-continued lines. Join continuations, then compare token sequences -- not a
    # substring match, which is what fails on line-wrapped text (slice 16b, three times).
    src = File.read!(@commit_msg)

    invocation =
      case Regex.run(~r/(git\s+-c\s+diff\.noprefix.*?)\|\s*sha256sum/s, src,
             capture: :all_but_first
           ) do
        [inv] -> inv |> String.replace("\\\n", " ") |> tokens()
        _ -> flunk(".githooks/commit-msg: could not find the `git ... | sha256sum` invocation")
      end

    expected = ["git"] ++ recipe ++ ["diff", "--cached"] ++ scope

    assert invocation == expected, """
    .githooks/commit-msg and tools/gate.sh disagree about the reviewable-diff recipe.

      commit-msg: #{Enum.join(invocation, " ")}
      gate.sh:    #{Enum.join(expected, " ")}

    These two must produce byte-identical diffs: commit-msg writes the Reviewed-diff trailer
    and tools/gate.sh derives the value CI compares it against. A drift here turns every new
    commit red on `Gate - attestation`. Change both, or finish removing the copy (slice 17).
    """
  end
end

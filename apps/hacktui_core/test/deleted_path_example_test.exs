defmodule HacktuiCore.DeletedPathExampleTest do
  use ExUnit.Case, async: true

  # The deleted-path gate's justification comment carries one concrete example. An example in a
  # justification is a CLAIM, and this repository's standing rule is that a claim in a tracked
  # file is true of the tree it ships in — so the example gets the same gate as any other claim.
  #
  # This exists because it was already wrong once. The comment named `assets/images/UI.png`
  # "cited by HANDOFF.md": true only after the contracts commit lands, while `git grep` for it in
  # the tree that shipped the comment returned rc=1. A reviewer caught it by running the grep.
  # A reviewer catching it is the thing this test replaces.
  @root Path.expand("../../..", __DIR__)
  @hook Path.join(@root, ".githooks/pre-commit")

  defp example_path do
    src = File.read!(@hook)

    case Regex.run(~r/^#\s*EXAMPLE-PATH:\s*(\S+)\s*$/m, src, capture: :all_but_first) do
      [path] ->
        path

      _ ->
        flunk("""
        .githooks/pre-commit carries no `# EXAMPLE-PATH: <path>` line.

        The deleted-path gate's comment must name its example on a machine-readable line, so
        that the example can be checked rather than trusted. If the example was removed, remove
        this test in the same commit and say so; do not leave an unchecked example behind.
        """)
    end
  end

  defp tracked_md do
    {out, 0} = System.cmd("git", ["ls-files", "-z", "--", "*.md"], cd: @root)
    out |> String.split(<<0>>, trim: true)
  end

  test "the gate's example path is tracked" do
    path = example_path()

    {_, status} =
      System.cmd("git", ["ls-files", "--error-unmatch", "--", path],
        cd: @root,
        stderr_to_stdout: true
      )

    assert status == 0,
           "the deleted-path gate's example is `#{path}`, which is not tracked. " <>
             "The gate only ever sees tracked paths, so an untracked example illustrates " <>
             "nothing it can do."
  end

  test "a tracked .md cites the gate's example path, at a line this test can name" do
    path = example_path()

    citations =
      for file <- tracked_md(),
          {line, n} <- Enum.with_index(String.split(File.read!(Path.join(@root, file)), "\n"), 1),
          String.contains?(line, path),
          do: "#{file}:#{n}"

    refute citations == [],
           """
           the deleted-path gate's comment names `#{path}` as its example, but no tracked .md
           cites that path in this tree.

           That is the exact defect this test exists to catch: the comment's previous example
           named a path whose only citation lived in an unlanded commit, so the justification
           was true of a future tree and false of the shipping one.

           Either point EXAMPLE-PATH at a path a tracked .md actually cites, or drop the example.
           """

    # Named, not just counted: the failure message above is only useful if a passing run can say
    # where the citation is. A test that proves existence without locating it makes the next
    # person re-derive what this one already knew.
    assert is_binary(hd(citations))
  end
end

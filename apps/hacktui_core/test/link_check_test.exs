defmodule HacktuiCore.LinkCheckTest do
  @moduledoc """
  Every relative markdown link in `README.md` and `docs/` resolves to a file that exists.

  A link check that has not been seen fail is a check that can only pass. Slice 16c is the
  precedent: `Path.wildcard/1` does not match dot-prefixed names, so an unpinned dotfile was
  invisible and the gate reported zero failures while the hole was open.

  So `dead_links/2` takes its root and its source list as arguments, and the probes drive the
  *same* function the real test calls, over fixtures. A control that computes its expected
  value with the function under test asserts `f(x) == f(x)` and proves nothing.
  """
  use ExUnit.Case, async: true

  import ExUnit.Callbacks, only: [on_exit: 1]

  @root Path.expand("../../..", __DIR__)

  @doc false
  def dead_links(root, sources) do
    for src <- sources,
        target <- relative_links(File.read!(Path.join(root, src))),
        not File.exists?(resolve(root, src, target)),
        do: {src, target}
  end

  @doc false
  def sources(root) do
    ["README.md"]
    |> Enum.concat(Path.wildcard(Path.join(root, "docs/**/*.md"), match_dot: true))
    |> Enum.map(&Path.relative_to(&1, root))
    |> Enum.filter(&File.regular?(Path.join(root, &1)))
    |> Enum.sort()
  end

  # A markdown inline link whose target is relative: not a URL scheme, not a bare anchor.
  defp relative_links(body) do
    ~r/\[[^\]]*\]\(([^)\s]+)\)/
    |> Regex.scan(body)
    |> Enum.map(fn [_full, target] -> target end)
    |> Enum.reject(&(&1 =~ ~r{^(https?://|mailto:|#)}))
  end

  # Anchors are stripped: `guide.md#section` is a link to `guide.md`.
  defp resolve(root, src, target) do
    file = target |> String.split("#") |> hd()
    Path.expand(Path.join([root, Path.dirname(src), file]))
  end

  defp fixture(files) do
    dir = Path.join(System.tmp_dir!(), "linkcheck-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    Enum.each(files, fn {path, body} ->
      full = Path.join(dir, path)
      File.mkdir_p!(Path.dirname(full))
      File.write!(full, body)
    end)

    dir
  end

  test "probe 1: a deliberately dead relative link is detected" do
    dir = fixture(%{"README.md" => "see [the missing page](does_not_exist.md) for more\n"})

    assert [{"README.md", "does_not_exist.md"}] == dead_links(dir, ["README.md"])
  end

  test "probe 2: a link into a nested directory resolves, and is not skipped" do
    dir =
      fixture(%{
        "README.md" => "see [the deep page](docs/guides/deep.md)\n",
        "docs/guides/deep.md" => "# deep\n"
      })

    assert [] == dead_links(dir, ["README.md"])

    # and the checker is genuinely looking: break only the target and it goes red
    File.rm!(Path.join(dir, "docs/guides/deep.md"))
    assert [{"README.md", "docs/guides/deep.md"}] == dead_links(dir, ["README.md"])
  end

  test "probe 3: a link to a dot-named file resolves, and is not skipped" do
    dir =
      fixture(%{
        "README.md" => "see [the workflow](.github/workflows/ci.yml)\n",
        ".github/workflows/ci.yml" => "name: ci\n"
      })

    assert [] == dead_links(dir, ["README.md"])

    # Path.wildcard/1 skips dot-prefixed names. A checker that enumerated candidate targets
    # by wildcard would report this live link as dead; one that resolves the path does not.
    File.rm!(Path.join(dir, ".github/workflows/ci.yml"))
    assert [{"README.md", ".github/workflows/ci.yml"}] == dead_links(dir, ["README.md"])
  end

  test "probe 4: the tracked tree carries no dead relative links" do
    sources = sources(@root)

    assert sources != [], "no markdown sources found; the check would pass vacuously"
    assert [] == dead_links(@root, sources)
  end
end

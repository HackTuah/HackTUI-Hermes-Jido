# Slice NN — FINDINGS

CLAUDE.md §5: every claim cites file path, line number(s), observed vs expected, and the
verification command **with its output**. "I think" / "should work" is not a finding.

## F1 — <short title>
- **Location:** `path/to/file.ex:LINE`
- **Observed:** what the code does now.
- **Expected:** what it should do, and per which requirement.
- **Verification:**
  ```bash
  $ <command>
  <actual output, pasted>
  ```
- **Status:** open | fixed in <commit> | deferred to BACKLOG

## Gate baseline
| Gate | Command | Result |
|---|---|---|

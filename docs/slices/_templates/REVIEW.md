# Slice NN — REVIEW

Reviewers run **read-only** against the raw staged diff (CLAUDE.md §8). Reviewers MUST
NOT edit code; a wanted change is reported as a finding and fixed by the implementer in
a new commit within the same slice, then re-reviewed.

**Diff reviewed:** `git diff <base>..<head>` — record the exact SHAs.

## Reviewer: correctness
Verdict: PASS | FAIL — findings with `file:line`.

## Reviewer: security
Verdict: PASS | FAIL

## Reviewer: OTP / supervision
Verdict: PASS | FAIL

## Reviewer: tests
Verdict: PASS | FAIL

## Overall verdict
PASS | FAIL. A PASS here is what `REVIEW.signoff` records. The implementer's own summary
is not evidence (§0).

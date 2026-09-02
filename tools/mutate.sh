#!/usr/bin/env bash
#
# Mutation harness.
#
# Reintroduces a known defect, asserts a named test fails, restores the file. A surviving
# mutant means the protection is claimed but not verified.
#
# Two failure modes this exists to prevent, both observed during slice 12:
#
#   1. A mutation that never applied, reported as a survivor. Three regex-based mutations
#      silently failed to match and were recorded as "0 failures" -- measuring unmutated
#      code. Patterns here are LITERAL (grep -F, python str.replace); never regex.
#   2. A campaign scoped to defects already fixed, reported as a perfect kill rate. That
#      is a measurement of nothing. Add mutants you expect to survive.
#
# Every mutant carries three proofs of application:
#   pattern occurs exactly once pre-edit; sha256 changes post-edit; sha256 is restored.
#
# Row 1 of every TSV must be the CANARY: a pattern that is deliberately absent. If the
# harness does not hard-abort on it, the harness itself is broken and no result it
# produces is evidence.
#
# Usage: tools/mutate.sh tools/mutants/c5.tsv

set -uo pipefail

TSV="${1:?usage: tools/mutate.sh <mutants.tsv>}"
[ -f "$TSV" ] || { echo "no such file: $TSV" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

survivors=()
killed=0
canary_seen=0

sha() { sha256sum "$1" | cut -d' ' -f1; }

while IFS=$'\t' read -r id file pattern replacement test_path; do
  case "$id" in ''|'#'*) continue ;; esac

  # Counted in python, not grep: patterns may span lines (stored \n-escaped in the TSV),
  # and grep -F cannot match those. Literal string count, never regex.
  found=$(python3 -c '
import sys
path, pattern = sys.argv[1], sys.argv[2].replace("\\n", "\n")
try:
    print(open(path, encoding="utf-8").read().count(pattern))
except FileNotFoundError:
    print(0)
' "$file" "$pattern")

  # --- self-check -----------------------------------------------------------
  if [ "$id" = "CANARY" ]; then
    canary_seen=1
    if [ "$found" -ne 0 ]; then
      echo "FATAL: CANARY pattern was FOUND in $file. The canary must be absent;" >&2
      echo "       either the file changed or the harness is matching wrongly." >&2
      exit 3
    fi
    echo "  canary   ok        pattern correctly absent; 'must apply' check is live"
    continue
  fi

  [ "$canary_seen" -eq 1 ] || { echo "FATAL: first row of $TSV must be CANARY" >&2; exit 3; }

  # --- proof 1: the pattern occurs exactly once -----------------------------
  if [ "$found" -ne 1 ]; then
    echo "FATAL: mutant '$id' pattern occurs $found times in $file (need exactly 1)." >&2
    echo "       A mutant that cannot be applied is not a survivor -- it is a broken row." >&2
    exit 3
  fi

  cp "$file" "$WORK/orig"
  before="$(sha "$file")"

  python3 - "$file" "$pattern" "$replacement" <<'PYEOF'
import sys
path = sys.argv[1]
pattern = sys.argv[2].replace("\\n", "\n")
replacement = sys.argv[3].replace("\\n", "\n")
s = open(path, encoding="utf-8").read()
assert s.count(pattern) == 1, "pattern count changed between check and apply"
open(path, "w", encoding="utf-8").write(s.replace(pattern, replacement, 1))
PYEOF

  # --- proof 2: the file actually changed -----------------------------------
  after="$(sha "$file")"
  if [ "$before" = "$after" ]; then
    cp "$WORK/orig" "$file"
    echo "FATAL: mutant '$id' left $file byte-identical. Not applied." >&2
    exit 3
  fi

  out="$(mix test $test_path 2>&1)"
  fails="$(printf '%s' "$out" \
    | grep -oE '[0-9]+ tests?, [0-9]+ failures?' \
    | awk -F'[ ,]' '{f+=$4} END{print f+0}')"

  cp "$WORK/orig" "$file"

  # --- proof 3: the file was restored ---------------------------------------
  if [ "$(sha "$file")" != "$before" ]; then
    echo "FATAL: could not restore $file after mutant '$id'." >&2
    exit 3
  fi

  if [ "${fails:-0}" -gt 0 ]; then
    printf '  %-24s KILLED    (%s failures)\n' "$id" "$fails"
    killed=$((killed + 1))
  else
    printf '  %-24s SURVIVED  <-- protection claimed but unverified\n' "$id"
    survivors+=("$id")
  fi
done < "$TSV"

echo
echo "  killed: $killed   survivors: ${#survivors[@]}"
if [ "${#survivors[@]}" -gt 0 ]; then
  printf '  survivor: %s\n' "${survivors[@]}"
  exit 1
fi

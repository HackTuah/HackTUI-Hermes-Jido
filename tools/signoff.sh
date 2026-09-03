#!/usr/bin/env bash
#
# Writes internal/slices/<slice>/REVIEW.signoff, and refuses unless the index is still the
# tree the reviewers actually read.
#
# Why this exists: the attestation covers INDEX bytes while the drift test hashes WORKTREE
# bytes, so a signoff computed after a mid-review edit attests a diff that no longer exists.
# That happened -- three of six staged files changed on disk during slice 16c's round 2, and
# the reviewer reported "the diff I reviewed and hashed is not the diff on disk". The edits
# were legitimate; doing the right work at the wrong moment silently invalidated a review in
# flight. The protocol said "hold edits during review" and had nothing behind it but the
# author's attention, which is the third rule this session to fail that way.
#
# So the binding is mechanical: reviewers read a checkout of the INDEX, each writes the tree
# hash it read to logs/round<N>.r<M>.tree, and this script refuses to write unless
# `git write-tree` still equals both of them.
#
# EXACTLY TWO tree files are required for the round. "All equal" over a single file is
# vacuous -- it compares a value to itself.
#
# The two-per-round count is THIS SLICE'S rule, recorded in CLAUDE.md section 6. It is not in
# section 8, which this comment used to cite: section 8 says to spawn independent reviewer
# subagents, plural, and names no number. A tracked file that hard-fails a round on the
# authority of a section that does not carry the rule is the founding defect of
# internal/REVIEWER-PROTOCOL.md -- a claim about a governing file's contents that the file does
# not contain -- so the citation is corrected rather than left to be inherited.
#
# NOT in scope: proving a review happened, or who performed it. This records WHICH tree was
# read and WHICH diff is being certified. The hash is still written by the party it
# certifies. See CLAUDE.md section 0.
#
# A single bounded record-lane read is deliberately NOT expressible here. It is not a round,
# and a slice closing on one writes its signoff by hand with that stated in the header.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

die() { echo "SIGNOFF REFUSED -- $*" >&2; exit 1; }

slice_dir="${1:-}"
[ -n "$slice_dir" ] || die "usage: tools/signoff.sh <slice-dir> [--replace]"
slice_dir="${slice_dir%/}"
[ -d "$slice_dir" ] || die "$slice_dir/ does not exist"
replace="${2:-}"

logs="$slice_dir/logs"
[ -d "$logs" ] || die "$logs/ does not exist; reviewers write their tree hash there"

# ---------- find the highest round that has tree files ----------
# Fail closed on every branch: a round that cannot be identified is not round 0.
round=""
for f in "$logs"/round*.r*.tree; do
  [ -f "$f" ] || continue
  n=${f##*/round}; n=${n%%.r*}
  # Three shapes, all found by review, all of which defeated the naive check:
  #   - non-numeric        -> `[ "$n" -gt ... ]` errors and the `if` silently takes the false
  #                           branch, so the file is SKIPPED rather than refused;
  #   - 99999999999999999999 -> same, because it is numeric but outside intmax;
  #   - round01 vs round1  -> two globs for ONE logical round, so three reviewer files split
  #                           into 2 + 1 and the "exactly two" invariant passed over a subset.
  # A round is 1-4 digits with no leading zero. Anything else is refused, not skipped.
  case "$n" in
    0*|''|*[!0-9]*) die "malformed round number in $f (expected round<N>.r<M>.tree, N a 1-4 digit number with no leading zero)" ;;
  esac
  [ "${#n}" -le 4 ] || die "implausible round number in $f: $n"
  if [ -z "$round" ] || [ "$n" -gt "$round" ]; then round="$n"; fi
done
[ -n "$round" ] || die "no logs/round<N>.r<M>.tree files in $logs/ -- nothing to check is not a pass"

# ---------- exactly two, one per reviewer ----------
# The suffix must be r<digits> and the two must DIFFER. Unvalidated, "exactly two files" was
# not "two reviewers": round1.r1.tree + round1.r1b.tree, or + round1.rZZZ.tree, both satisfied
# the count from one party -- which is the whole property the count exists to enforce.
files=()
suffixes=""
for f in "$logs"/round"$round".r*.tree; do
  [ -f "$f" ] || continue
  s=${f##*.r}; s=${s%.tree}
  case "$s" in ''|*[!0-9]*) die "malformed reviewer suffix in $f (expected round<N>.r<M>.tree, M a number)" ;; esac
  case " $suffixes " in *" $s "*) die "two tree files for round $round carry the same reviewer number r$s" ;; esac
  suffixes="$suffixes $s"
  files+=("$f")
done
found=${#files[@]}
[ "$found" -eq 2 ] || die "round $round has $found tree file(s); exactly 2 are required, one per reviewer"

# ---------- read them ----------
# There WAS a `read $read_ok of $found; refusing on a partial read` assertion here, modelled on
# the slice-16b row-count check. It was removed rather than kept, because it could not fail:
# every failure inside this loop calls `die`, which exits, so the counter always equalled the
# total by the time it was compared. A check that can only pass is worse than no check, because
# it reads as coverage -- this file's own CRITERIA say a row that cannot fail is not a
# criterion, and reviewer 1 applied that to the code rather than to the table.
#
# The real guarantee is structural and is stated instead of asserted: the loop is fail-closed
# at every step -- an unreadable file or a non-40-hex body exits non-zero and no signoff is
# written. `found` is separately pinned at exactly 2 above.
trees=()
for f in "${files[@]}"; do
  t=$(tr -d '[:space:]' < "$f") || die "cannot read $f"
  printf '%s' "$t" | grep -qE '^[0-9a-f]{40}$' \
    || die "$f does not contain a 40-hex tree hash (got: '${t:0:60}')"
  trees+=("$t")
done
# There is deliberately NO count assertion here. The first one could not fail; its replacement
# could not fail either, for the identical reason -- `found` is pinned at 2 above and every
# in-loop failure exits -- and it was written three lines under a comment explaining that a
# check which can only pass is worse than none. Twice in one file is a pattern, not a slip, so
# the property is stated instead: this loop is fail-closed at every step, and `found` is the
# one place the count is actually enforced.

[ "${trees[0]}" = "${trees[1]}" ] || {
  echo "  reviewer A: ${trees[0]}" >&2
  echo "  reviewer B: ${trees[1]}" >&2
  die "the two reviewers of round $round read DIFFERENT trees"
}
reviewed="${trees[0]}"

# ---------- the index must still be that tree ----------
# 40-hex assumes a SHA-1 object format. In a SHA-256 repository every hash here is 64 and this
# script dies on all of them -- fail-closed, and recorded rather than handled, because this
# repository is SHA-1 and a widened pattern would accept a 40-hex hash from a 64-hex repo.
current=$(git write-tree) || die "git write-tree failed; refusing to sign an unmeasured index"
printf '%s' "$current" | grep -qE '^[0-9a-f]{40}$' || die "git write-tree did not return a tree hash"

if [ "$current" != "$reviewed" ]; then
  echo "  reviewed: $reviewed" >&2
  echo "  index is: $current" >&2
  die "the index has moved since round $round was reviewed; re-review the delta, do not sign"
fi

# ---------- the diff being certified ----------
# One definition of the recipe, in tools/gate.sh. This script deliberately holds no copy.
# LOGDIR is passed so gate.sh does not mktemp -d a directory it never cleans up; it has no
# EXIT trap, so every unpassed call leaked one.
tmp_logs=$(mktemp -d "${TMPDIR:-/tmp}/hacktui-signoff.XXXXXXXX") || die "cannot create a temp dir"
trap 'rm -rf "$tmp_logs"' EXIT
diff_hash=$(LOGDIR="$tmp_logs" ./tools/gate.sh staged-diff-hash) \
  || die "could not derive the staged-diff hash (unmeasurable, or the reviewable diff is empty)"
if [ "$diff_hash" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]; then
  die "the staged diff is empty; an empty-diff hash must never read as a signed review"
fi

out="$slice_dir/REVIEW.signoff"
if [ -f "$out" ] && [ "$replace" != "--replace" ]; then
  if grep -qF -- "$diff_hash" "$out" && grep -qF -- "Reviewed-tree: $reviewed" "$out"; then
    echo "signoff already records this tree and diff; nothing to do."
    exit 0
  fi
  die "$out exists and records something else; pass --replace if that is intended"
fi

{
  echo "# Slice: $slice_dir"
  echo "#"
  echo "# Round $round, two independent reviewers, both on a checkout of this index."
  echo "# Written by tools/signoff.sh, which refused until \`git write-tree\` equalled the tree"
  echo "# both reviewers printed. It records WHICH tree was read and WHICH diff is certified."
  echo "# It does not prove a review happened -- the hash is written by the party it certifies."
  echo "# See CLAUDE.md section 0 and .githooks/pre-commit."
  echo "#"
  echo "# Reviewer tree files:"
  for f in "${files[@]}"; do echo "#   $f"; done
  echo ""
  echo "Reviewed-tree: $reviewed"
  echo ""
  echo "$diff_hash"
} > "$out"

echo "signoff written: $out"
echo "  reviewed-tree: $reviewed"
echo "  staged-diff:   $diff_hash"

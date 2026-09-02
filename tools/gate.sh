#!/usr/bin/env bash
#
# One implementation of every commit gate, called by BOTH .githooks/pre-commit and
# .github/workflows/ci.yml.
#
# Why this file exists: the hook and the workflow used to carry separate copies of the
# same logic, and the workflow's copy ran under GitHub's default `shell: bash -e`. Under
# -e a bare `mix test` that exits non-zero aborts the step before the comparison runs, so
# thirteen consecutive CI runs reported a failure without ever measuring one -- while the
# hook, which uses `set -uo pipefail` and no -e, passed the identical logic locally. The
# workflow's comment said "Must match .githooks/pre-commit"; it matched in logic and
# diverged in shell invocation, which is exactly the kind of difference a comment cannot
# hold. One script removes the class of defect, not just the instance.
#
# `set +e` is explicit and load-bearing. `set -uo pipefail` alone does NOT clear an -e
# inherited from the caller, so `bash -e tools/gate.sh test` would still abort at the first
# failing command -- reproducing the exact defect this script exists to remove. A gate must
# observe an exit status and score it, never abort on it, regardless of how it is invoked.
set +e
set -uo pipefail

BASELINE="${BASELINE:-.claude/gate-baseline.json}"
LOGDIR="${LOGDIR:-$(mktemp -d)}"
# Create it. `mktemp -d` made the directory as a side effect, so setting LOGDIR to a path
# that does not exist yet -- which is exactly what pointing it at the CI workspace does --
# broke every redirect. Four gates went red on run 33586534853 for this reason. They failed
# CLOSED, refusing to report a pass they could not measure, which is the behaviour the
# class-1 rule requires; but a gate that cannot write its log is a broken gate, not a
# finding about the code under test.
mkdir -p "$LOGDIR" || { echo "gate: cannot create LOGDIR=$LOGDIR" >&2; exit 1; }

note() { printf '  %-24s %s\n' "$1" "$2"; }
is_uint() { case "${1:-}" in ''|*[!0-9]*) return 1;; *) return 0;; esac; }

baseline_of() {
  local k
  k=$(jq -r ".$1 // empty" "$BASELINE" 2>/dev/null) || return 1
  is_uint "$k" || return 1
  printf '%s' "$k"
}

# ExUnit exits 0 (all passed) or 2 (tests failed). Anything else -- a CompileError in a
# later app's test/, a timeout, OOM, SIGINT -- means the run did not measure every app,
# and a partial log summing to fewer failures would otherwise read as an improvement.
count_test_failures() {
  case "${TEST_STATUS:-1}" in 0|2) ;; *) return 1 ;; esac
  local want got
  want=$(ls -d apps/*/test 2>/dev/null | wc -l)
  got=$(grep -cE '[0-9]+ tests?, [0-9]+ failures?' "$1")
  [ "$got" -ge "$want" ] || return 1
  # `invalid` is counted: a raising setup_all reports "N tests, 0 failures, N invalid",
  # which must not read as an improvement. `excluded` is deliberately NOT counted -- the
  # 18 integration-tagged tests are excluded by design in this job. The consequence is
  # recorded honestly: adding @tag :skip shrinks the measured surface without moving the
  # ratchet, which is why the test-identity manifest is still open work.
  local fails invalid
  fails=$(grep -oE '[0-9]+ failures?' "$1" | grep -oE '^[0-9]+' | paste -sd+ | bc)
  invalid=$(grep -oE '[0-9]+ invalid' "$1" | grep -oE '^[0-9]+' | paste -sd+ | bc)
  printf '%s' "$(( ${fails:-0} + ${invalid:-0} ))"
}

# A clean run prints "found no issues" and no category totals -- that is 0, not a
# measurement failure. Without this the gate becomes unsatisfiable the day it passes.
count_credo() {
  grep -qE '^[0-9]+ mods/funs, found no issues' "$1" && { printf 0; return 0; }
  grep -qE '[0-9]+ (warning|refactoring opportunit|code readability issue|software design suggestion|consistency issue)' "$1" || return 1
  grep -oE '[0-9]+ (warnings?|refactoring opportunit(y|ies)|code readability issues?|software design suggestions?|consistency issues?)' "$1" \
    | grep -oE '^[0-9]+' | paste -sd+ | bc
}

count_dialyzer() {
  grep -qE '^done \(passed successfully\)' "$1" && { printf 0; return 0; }
  grep -oE 'Total errors: [0-9]+' "$1" | grep -oE '[0-9]+$' | head -1
}

ratchet() {
  local label="$1" key="$2" fn="$3" log="$4" base now
  base=$(baseline_of "$key") || { note "$label" "FAIL -- no single integer \"$key\" in $BASELINE"; return 1; }
  now=$("$fn" "$log")        || { note "$label" "FAIL -- gate produced no parseable result (see $log)"; return 1; }
  is_uint "$now"             || { note "$label" "FAIL -- non-numeric result '$now'; refusing to treat as a pass"; return 1; }
  if   [ "$now" -gt "$base" ]; then note "$label" "REGRESSION: $now > baseline $base"; return 1
  elif [ "$now" -lt "$base" ]; then note "$label" "improved to $now (baseline $base) -- lower the baseline to $now"; return 1
  else                              note "$label" "held at $now"; return 0
  fi
}


# ---------------------------------------------------------------------------
# baseline: values may only DECREASE, unless a matching _corrections entry
# ships in the same reviewed diff.
#
# Takes the git ref holding the PREVIOUS baseline. The hook passes HEAD. CI passes
# github.event.before, NOT HEAD~1: GitHub creates one run per push, at the tip, so
# comparing HEAD~1 checks only the last commit. Pushing commit A (which raises a
# baseline) followed by commit B compares B against A, prints "90 -> 90", and exits 0 --
# A's raise is never compared, and no later run revisits it. On a slice branch a
# multi-commit push is the normal case, so that hole is the common path, not the corner.
#
# Fails closed on zero comparisons. Previously the PR path could exit 0 having compared
# nothing and printed nothing, because `git show` had no failure branch and an empty
# `old` made every key skip.
# ---------------------------------------------------------------------------
baseline_gate() {
  local ref="${1:-}" prev="$LOGDIR/base.prev" compared=0 raised=0

  [ -r "$BASELINE" ] || { note baseline "FAIL -- $BASELINE missing or unreadable"; return 1; }

  if [ -z "$ref" ] || [ "$ref" = "0000000000000000000000000000000000000000" ]; then
    note baseline "no previous ref (new branch); nothing to compare"
    return 0
  fi

  if ! git cat-file -e "$ref:$BASELINE" 2>/dev/null; then
    note baseline "FAIL -- $BASELINE absent at $ref; refusing to pass unmeasured"
    return 1
  fi

  git show "$ref:$BASELINE" > "$prev" 2>/dev/null || {
    note baseline "FAIL -- could not read $BASELINE at $ref"; return 1; }

  local k o n blk
  for k in test_failures credo_issues dialyzer_warnings; do
    o=$(grep -oE "\"$k\"[[:space:]]*:[[:space:]]*[0-9]+" "$prev"     | grep -oE '[0-9]+$' | head -1)
    n=$(grep -oE "\"$k\"[[:space:]]*:[[:space:]]*[0-9]+" "$BASELINE" | grep -oE '[0-9]+$' | head -1)
    is_uint "$o" && is_uint "$n" || continue
    compared=$((compared + 1))
    if [ "$n" -gt "$o" ]; then
      # An increase is permitted ONLY with a matching, reviewable entry in _corrections.
      # An audit record, not a bypass: the reason ships in the reviewed diff. CI used to
      # reject every raise unconditionally while the hook honoured corrections, so a
      # sanctioned correction passed locally and reddened CI. One implementation now.
      blk=$(grep -A6 "\"key\"[[:space:]]*:[[:space:]]*\"$k\"" "$BASELINE" 2>/dev/null)
      if printf '%s' "$blk" | grep -qE "\"from\"[[:space:]]*:[[:space:]]*$o[^0-9]" \
         && printf '%s' "$blk" | grep -qE "\"to\"[[:space:]]*:[[:space:]]*$n[^0-9]"; then
        note baseline "$k raised $o -> $n with a recorded correction (see _corrections)"
        raised=$((raised + 1))
      else
        note baseline "FAIL -- $k raised $o -> $n with no _corrections entry"
        return 1
      fi
    else
      note baseline "$k: $o -> $n"
    fi
  done

  [ "$compared" -gt 0 ] || {
    note baseline "FAIL -- compared 0 keys; a gate that measures nothing is not a pass"
    return 1; }
  return 0
}


# ---------------------------------------------------------------------------
# attestation: the gate DERIVES the diff hash and compares it to the commit's claim.
#
# The old signoff gate read a number the author wrote into a file and checked that the
# same number was there. With nothing staged that number is the sha256 of the empty
# string, and the gate reported "matches staged diff" for a diff that did not exist.
#
# The structural problem is not the empty hash: it is that the attested party supplied the
# value the gate checked. Same shape as joint invariant J8 -- the party accountable for
# observing a plane must be a different privilege domain from the party accountable for its
# behaviour -- applied to this repo's own review record. So the author now supplies a
# CLAIM, in a commit trailer, and the gate independently derives the FACT and compares.
#
# Checked per commit, not per range: a push carries several commits and each must attest to
# its own diff, for the same reason the baseline gate compares github.event.before rather
# than HEAD~1.
#
# NOT in scope here: proving WHO produced the claim. That needs a signature verified
# against a tracked allowed-signers file. This slice removes the author's ability to hand
# the gate its own answer; it does not yet make the attester a different party.
# ---------------------------------------------------------------------------
derive_diff_hash() {
  git -c diff.noprefix=false -c diff.context=3 -c diff.algorithm=myers -c core.abbrev=40 \
    diff "$1" "$2" --binary --no-ext-diff --no-textconv -- . ':(exclude)internal/**' \
    | sha256sum | cut -d' ' -f1
}

attestation_gate() {
  local range="${1:-}" commits c parent derived claimed n=0 bad=0

  [ -n "$range" ] || { note attestation "FAIL -- no commit range given"; return 1; }

  commits=$(git rev-list --no-merges "$range" 2>/dev/null) || {
    note attestation "FAIL -- cannot enumerate $range"; return 1; }

  [ -n "$commits" ] && [ "$commits" != "" ] || {
    note attestation "no commits in $range; nothing to check"; return 0; }

  for c in $commits; do
    n=$((n + 1))
    parent=$(git rev-parse "$c^" 2>/dev/null) || parent=$(git hash-object -t tree /dev/null)
    derived=$(derive_diff_hash "$parent" "$c")

    # An empty diff can never be a match. This is the defect this slice closes: the sha256
    # of the empty string is a real hash, and a signoff containing it used to pass.
    if [ "$derived" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]; then
      note attestation "NOTHING TO ATTEST -- ${c:0:8} has an empty reviewable diff"
      bad=1
      continue
    fi

    claimed=$(git log -1 --format=%B "$c" | sed -n 's/^Reviewed-diff:[[:space:]]*sha256:[[:space:]]*\([0-9a-f]\{64\}\).*/\1/p' | head -1)

    if [ -z "$claimed" ]; then
      note attestation "FAIL -- ${c:0:8} carries no Reviewed-diff trailer"
      bad=1
    elif [ "$claimed" != "$derived" ]; then
      note attestation "FAIL -- ${c:0:8} claim does not match its diff"
      printf '      claimed:  %s\n      derived:  %s\n' "$claimed" "$derived"
      bad=1
    else
      note attestation "${c:0:8} attests to its own diff (${derived:0:16}...)"
    fi
  done

  [ "$bad" -eq 0 ] || return 1
  return 0
}

case "${1:?usage: tools/gate.sh <format|compile|secret-scan|test|credo|dialyzer|mutation|baseline|attestation|advisories>}" in

  format)
    mix format --check-formatted >/dev/null 2>&1 \
      && { note format "pass"; exit 0; } || { note format "FAIL -- run: mix format"; exit 1; }
    ;;

  compile)
    mix compile --warnings-as-errors >/dev/null 2>&1 \
      && { note compile "pass"; exit 0; } || { note compile "FAIL (--warnings-as-errors)"; exit 1; }
    ;;

  secret-scan)
    # Anchored deliberately: an unanchored 'env' matched .../envelope.ex on every run, so
    # the gate could never pass and would have been learned as noise.
    secrets=$(git ls-files | grep -Ei '(^|/)\.env$|\.(key|pem|pcap|pcapng|p12)$')
    [ -z "$secrets" ] && { note "tracked-secret-files" "pass"; exit 0; }
    note "tracked-secret-files" "FAIL -- tracked secret-shaped files:"; printf '%s\n' "$secrets" | sed 's/^/      /'; exit 1
    ;;

  test)
    mix test > "$LOGDIR/test.log" 2>&1; export TEST_STATUS=$?
    ratchet "test (ratchet)" test_failures count_test_failures "$LOGDIR/test.log"
    ;;

  credo)
    MIX_ENV=dev mix credo --strict > "$LOGDIR/credo.log" 2>&1
    ratchet "credo (ratchet)" credo_issues count_credo "$LOGDIR/credo.log"
    ;;

  dialyzer)
    MIX_ENV=dev mix dialyzer --format raw > "$LOGDIR/dz.log" 2>&1
    ratchet "dialyzer (ratchet)" dialyzer_warnings count_dialyzer "$LOGDIR/dz.log"
    ;;

  baseline)
    baseline_gate "${2:-}"
    ;;

  attestation)
    attestation_gate "${2:-}"
    ;;

  mutation)
    ./tools/mutate.sh tools/mutants/c5.tsv
    ;;

  advisories)
    # Advisory only: recorded, never blocking. Promotion to a ratchet is slice 16.
    mix do deps.loadpaths + deps.audit 2>&1 | tail -3
    mix hex.audit 2>&1 | tail -3
    note advisories "recorded (not blocking until slice 16)"
    ;;

  *) echo "unknown gate: $1" >&2; exit 2 ;;
esac

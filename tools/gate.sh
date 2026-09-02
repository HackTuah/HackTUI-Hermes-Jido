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
  # Must be a top-level NUMBER, and this must agree exactly with baseline_gate's reader.
  # `jq -r ".k // empty"` stringifies, so a JSON *string* "200" passed is_uint and became a
  # baseline of 200 -- while baseline_gate's stricter reader saw the same key as absent and
  # licensed a "retirement" for it. Two readers disagreeing about what a baseline IS let a
  # real credo regression (76 -> 200) pass both gates with no _corrections entry, and made
  # the gate print "retired at 76" about a key that was still present and still enforced.
  # One definition, used by both.
  k=$(jq -r --arg k "$1" 'if (has($k) and (.[$k] | type == "number")) then .[$k] else empty end' \
      "$BASELINE" 2>/dev/null) || return 1
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
  # The summing tool is not the point; `${fails:-0}` was. With `paste | bc` and bc absent the
  # sum came back EMPTY and that default turned it into a clean 0, so a log with twelve real
  # failures scored as a pass. Measured, not assumed: bc IS present on the GitHub runner
  # today (a CI run reported `credo held at 76`, which count_credo could not have produced
  # without it), so this was a latent fail-open rather than an active one -- but it sat under
  # the gate that is now the hard barrier, and it depended on a tool staying installed.
  #
  # awk replaces bc because it is in every base image, and the DEFAULT IS GONE: a
  # non-numeric sum now fails closed. Swapping one unguarded tool for another would have
  # relocated the hole, not closed it -- awk missing produced the identical false pass.
  fails=$(grep -oE '[0-9]+ failures?' "$1" | grep -oE '^[0-9]+' | awk '{s+=$1} END {print s+0}')
  invalid=$(grep -oE '[0-9]+ invalid' "$1" | grep -oE '^[0-9]+' | awk '{s+=$1} END {print s+0}')
  is_uint "$fails" && is_uint "$invalid" || return 1
  printf '%s' "$(( fails + invalid ))"
}

# A clean run prints "found no issues" and no category totals -- that is 0, not a
# measurement failure. Without this the gate becomes unsatisfiable the day it passes.
count_credo() {
  grep -qE '^[0-9]+ mods/funs, found no issues' "$1" && { printf 0; return 0; }
  grep -qE '[0-9]+ (warning|refactoring opportunit|code readability issue|software design suggestion|consistency issue)' "$1" || return 1
  # awk for the same reason as count_test_failures: bc may be absent, and an empty result
  # here reaches `ratchet` as a non-numeric value. That one fails closed rather than open --
  # `is_uint` rejects it -- but relying on a downstream guard for an avoidable empty string
  # is the difference between failing closed by design and by luck.
  grep -oE '[0-9]+ (warnings?|refactoring opportunit(y|ies)|code readability issues?|software design suggestions?|consistency issues?)' "$1" \
    | grep -oE '^[0-9]+' | awk '{s+=$1} END {print s+0}'
}

count_dialyzer() {
  grep -qE '^done \(passed successfully\)' "$1" && { printf 0; return 0; }
  grep -oE 'Total errors: [0-9]+' "$1" | grep -oE '[0-9]+$' | head -1
}

# A gate whose baseline reached zero and was retired. Same measurement function as the
# ratchet used, same fail-closed contract -- an unparseable log, a partial run, or a
# non-numeric result is a failure, never a pass -- but the only passing value is 0.
#
# Deliberately NOT implemented as `ratchet` against a hardcoded 0: the ratchet's contract
# includes "improved to N -- lower the baseline", which is meaningless once there is no
# baseline to lower.
hard_zero() {
  local label="$1" fn="$2" log="$3" now
  now=$("$fn" "$log") || { note "$label" "FAIL -- gate produced no parseable result (see $log)"; return 1; }
  is_uint "$now"      || { note "$label" "FAIL -- non-numeric result '$now'; refusing to treat as a pass"; return 1; }
  if [ "$now" -eq 0 ]; then note "$label" "pass (0 failures)"; return 0; fi
  note "$label" "FAIL -- $now failing test(s); this gate is hard-blocking, there is no baseline"
  return 1
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

  # jq, not grep, for everything below. A `grep '"credo_issues": [0-9]+'` matches the key
  # ANYWHERE in the file, so a nested occurrence -- inside _targets, _corrections, or a prose
  # "reason" -- reads as the top-level baseline. Four holes were demonstrated against the
  # grep implementation before it shipped: deleting a top-level key while leaving a nested
  # decoy made the gate print "credo_issues: 76 -> 76", a comparison it never performed
  # against a key that no longer existed; a bare top-level "retired_key" licensed a deletion
  # with no _retired array present at all; and the same string smuggled into an existing
  # _corrections object did too. jq scopes every read to the structure it means.
  command -v jq >/dev/null 2>&1 || {
    note baseline "FAIL -- jq not available; refusing to compare baselines unparsed"; return 1; }
  jq -e . "$BASELINE" >/dev/null 2>&1 || {
    note baseline "FAIL -- $BASELINE is not valid JSON"; return 1; }

  # Top-level, numeric, nothing else. A stringified "76" is not a baseline.
  top_uint() {
    jq -r --arg k "$2" 'if (has($k) and (.[$k] | type == "number")) then .[$k] else empty end' \
      "$1" 2>/dev/null
  }
  # Scoped to _retired and to an object member named retired_key. A stray
  # "retired_key" elsewhere in the file is not a declaration.
  declared_retired() {
    jq -e --arg k "$2" '[._retired[]? | select(.retired_key == $k)] | length > 0' \
      "$1" >/dev/null 2>&1
  }

  local k o n
  for k in test_failures credo_issues dialyzer_warnings; do
    o=$(top_uint "$prev" "$k")
    n=$(top_uint "$BASELINE" "$k")

    # PRESENT BUT NOT A NUMBER. Neither a baseline nor a retirement. Treating it as absent is
    # exactly what let a stringified "200" read as a deletion while baseline_of still enforced
    # it as a number. Refuse to guess which one the author meant.
    if jq -e --arg k "$k" 'has($k)' "$BASELINE" >/dev/null 2>&1 && ! is_uint "$n"; then
      note baseline "FAIL -- $k is present in $BASELINE but is not a number"
      return 1
    fi

    # RETIREMENT RECORDS ARE APPEND-ONLY, and checking only the current file was not enough:
    # one commit could delete the _retired entry AND re-add the key, and the loop reported
    # nothing at all, because the key was absent at the previous ref and present now.
    if declared_retired "$prev" "$k"; then
      if ! declared_retired "$BASELINE" "$k"; then
        note baseline "FAIL -- $k's _retired entry was removed; retirement records are append-only"
        return 1
      fi
      if is_uint "$n"; then
        note baseline "FAIL -- $k is declared retired but present again in $BASELINE"
        return 1
      fi
      continue
    fi

    # RE-INTRODUCTION within a single diff: declared retired here and present here.
    if is_uint "$n" && declared_retired "$BASELINE" "$k"; then
      note baseline "FAIL -- $k is declared retired in _retired but present again in $BASELINE"
      return 1
    fi

    # RETIREMENT. A key present at the previous ref and absent now is how a clean gate
    # graduates to hard-blocking. It is also the one genuinely silent way to escape a
    # ratchet: delete the key AND change or remove its `ratchet` call in the same diff, which
    # is exactly this commit's own move. (Deleting the key alone is NOT silent -- the
    # corresponding gate then fails with `no single integer "<key>"`. The earlier claim that
    # it "reports nothing at all" was too strong and is corrected here.)
    #
    # So a disappearance must be declared, and the declaration must ship WITH the deletion:
    # otherwise one commit parks a licence and a later commit quietly spends it, with a
    # reviewable diff of a single deleted line.
    if is_uint "$o" && ! is_uint "$n"; then
      if ! declared_retired "$BASELINE" "$k"; then
        note baseline "FAIL -- $k present at $ref, absent now, with no _retired entry"
        return 1
      fi
      # retired_at, when present, must be the value actually being retired. Otherwise the
      # durable JSON record says one thing and the deletion does another, and only the
      # gate's transient stdout carries the truth.
      local at
      at=$(jq -r --arg k "$k" 'first(._retired[]? | select(.retired_key == $k) | .retired_at // empty)' \
             "$BASELINE" 2>/dev/null)
      if [ -n "$at" ] && [ "$at" != "$o" ]; then
        note baseline "FAIL -- $k's _retired entry records retired_at=$at but the value is $o"
        return 1
      fi
      # Deliberately NOT counted toward `compared`: retiring every key would otherwise
      # satisfy the fail-closed "compared 0 keys" check while comparing nothing.
      note baseline "$k retired at $o with a recorded _retired entry (its gate must now be hard)"
      continue
    fi

    is_uint "$o" && is_uint "$n" || continue
    compared=$((compared + 1))
    if [ "$n" -gt "$o" ]; then
      # An increase is permitted ONLY with a matching, reviewable entry in _corrections.
      # An audit record, not a bypass: the reason ships in the reviewed diff. CI used to
      # reject every raise unconditionally while the hook honoured corrections, so a
      # sanctioned correction passed locally and reddened CI. One implementation now.
      #
      # Scoped to the _corrections array for the same reason as _retired: the previous
      # `grep -A6` matched any "key"/"from"/"to" trio within six lines, anywhere.
      if jq -e --arg k "$k" --argjson o "$o" --argjson n "$n" \
           '[._corrections[]? | select(.key == $k and .from == $o and .to == $n)] | length > 0' \
           "$BASELINE" >/dev/null 2>&1; then
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
    # HARD gate since slice 16. The baseline reached 0 in slice 13 and its entry was retired,
    # as .claude/gate-baseline.json's own _comment requires. The CI job keeps the name
    # "Gate - test ratchet" because that string is a required status check in the branch
    # ruleset and renaming it would leave a required context that never reports, blocking
    # every PR (CLAUDE.md 4c). The rename is owner work, tracked in BACKLOG.md.
    mix test > "$LOGDIR/test.log" 2>&1; export TEST_STATUS=$?
    hard_zero "test (hard)" count_test_failures "$LOGDIR/test.log"
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
    # Advisory only: recorded, never blocking. Promotion to a ratchet is slice 18.
    mix do deps.loadpaths + deps.audit 2>&1 | tail -3
    mix hex.audit 2>&1 | tail -3
    note advisories "recorded (not blocking until slice 18)"
    ;;

  *) echo "unknown gate: $1" >&2; exit 2 ;;
esac

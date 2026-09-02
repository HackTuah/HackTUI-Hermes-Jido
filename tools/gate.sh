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
  # `invalid` and `excluded` are counted too: a raising setup_all reports
  # "N tests, 0 failures, N invalid", which must not read as an improvement.
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

case "${1:?usage: tools/gate.sh <format|compile|secret-scan|test|credo|dialyzer|mutation|advisories>}" in

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
    [ -z "$secrets" ] && { note "secret scan" "pass"; exit 0; }
    note "secret scan" "FAIL -- tracked secret-shaped files:"; printf '%s\n' "$secrets" | sed 's/^/      /'; exit 1
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

#!/usr/bin/env bash
# Run the tests that need a Firestore emulator.
#
# These four tests were written when the store was built and had never run once, because
# `npm test` skips them unless FIRESTORE_EMULATOR_HOST is set and nothing set it. That is the
# worst shape a test can have: it reports a passing suite while covering nothing, and there is
# no way to tell it apart from a suite that ran.
#
# Two environment facts stood in the way, neither of them written down anywhere:
#
#   1. The globally installed firebase-tools crashes on Node 26. It reads
#      `SlowBuffer.prototype`, and SlowBuffer was removed. The failure looks nothing like a
#      version problem:
#          TypeError: Cannot read properties of undefined (reading 'prototype')
#      So this script pins a version through npx rather than using whatever is on PATH.
#
#   2. Current firebase-tools requires Java 21 or newer, and `java` on this machine is 17.
#      Java 23 was already installed through Homebrew, just not the default. This script
#      finds a new-enough JDK instead of asking anyone to change their system default.
#
# Usage:  ./scripts/test-emulator.sh          all emulator tests
#         ./scripts/test-emulator.sh <path>   one file
# FALSIFIED 2026-08-19, in both directions, which took two goes.
#
# Skip case: ran the suite without the emulator, the exact state that hid four unrun tests for
# months. It printed
#     Tests  10 skipped (10)
#     CHECKED 0 emulator tests executed, 10 skipped
#     ::error::Ran 0 emulator tests. Zero is a broken run, not a pass...
# and exited 1, where the same command without this guard exits 0.
#
# False-positive case, found by CI rather than by me: the first version FAILED A RUN WHOSE TEN
# TESTS ALL PASSED, because vitest colours its summary when it has a terminal and Actions is
# one. Both counters are now checked against the literal coloured line Actions produced:
#     coloured "10 passed"  -> passed=10 skipped=0
#     coloured "10 skipped" -> passed=0  skipped=10
#
# Third case, 2026-08-19: a run with a genuine failure printed
#     Tests  1 failed | 11 passed (12)
# which the pattern could not read, so it reported "CHECKED 0 emulator tests executed" and
# blamed the emulator for a run where twelve tests ran and one caught a real bug. Counting by
# the word after each number reports 12 executed (11 passed, 1 failed).
set -euo pipefail

cd "$(dirname "$0")/.."

# --- find a JDK at 21 or newer -------------------------------------------------------------
pick_java() {
  for candidate in \
      "${JAVA_HOME:-}" \
      /opt/homebrew/opt/openjdk \
      /opt/homebrew/opt/openjdk@23 \
      /opt/homebrew/opt/openjdk@21 \
      /usr/local/opt/openjdk \
      /usr/local/opt/openjdk@23 \
      /usr/local/opt/openjdk@21; do
    [ -n "$candidate" ] && [ -x "$candidate/bin/java" ] || continue
    version=$("$candidate/bin/java" -version 2>&1 | head -1 | sed -E 's/.*"([0-9]+).*/\1/')
    if [ "${version:-0}" -ge 21 ] 2>/dev/null; then
      echo "$candidate"
      return 0
    fi
  done
  # Fall back to whatever is on PATH, and let the version check below report it.
  command -v java >/dev/null && dirname "$(dirname "$(command -v java)")" || true
}

JDK="$(pick_java)"
if [ -z "$JDK" ]; then
  echo "::error::No Java found. The Firestore emulator needs a JDK at version 21 or newer."
  exit 1
fi
JAVA_VERSION=$("$JDK/bin/java" -version 2>&1 | head -1)
echo "CHECKED java: $JAVA_VERSION  ($JDK)"
if ! echo "$JAVA_VERSION" | sed -E 's/.*"([0-9]+).*/\1/' | awk '{exit !($1 >= 21)}'; then
  echo "::error::The Firestore emulator needs Java 21 or newer. Found: $JAVA_VERSION"
  echo "  brew install openjdk"
  exit 1
fi

TARGET="${1:-src/lib/firebase/}"
echo "CHECKED target: $TARGET"

LOG=$(mktemp)
set +e
JAVA_HOME="$JDK" PATH="$JDK/bin:$PATH" \
  npx --yes firebase-tools@15 emulators:exec --only firestore --project knight-life-test \
  "cd web && npx vitest run $TARGET" 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
set -e

# THE POINT OF THIS SCRIPT, and the reason it is not just a one-liner.
#
# These tests skip themselves when FIRESTORE_EMULATOR_HOST is unset, and a skipped suite exits
# 0. That is how four of them went from written to never-run without anybody noticing: the
# command succeeded and reported nothing. If the emulator ever stops starting, or the env var
# stops being passed through, this must go red rather than quietly cover nothing again.
# Strip ANSI escapes before matching. vitest colours its summary when it thinks it has a
# terminal, and GitHub Actions is one, so in CI the line reads
#     ESC[2m      Tests ESC[22m ESC[1mESC[32m10 passedESC[39m
# and a pattern like 'Tests +[0-9]+ passed' matches nothing. That made this guard FAIL A RUN
# WHOSE TESTS ALL PASSED, which is the opposite failure and the more corrosive one: a check
# that cries wolf is a check somebody deletes.
CLEAN=$(sed -E $'s/\033\[[0-9;]*[a-zA-Z]//g' "$LOG")
# The summary line takes several shapes, and reading only the happy one is how this reported
# "CHECKED 0 emulator tests executed" for a run where twelve tests ran and one failed:
#     Tests  10 passed (10)
#     Tests  1 failed | 11 passed (12)
#     Tests  10 skipped (10)
# So count each number by the word that follows it, wherever it appears on the summary line,
# rather than assuming it comes straight after "Tests".
SUMMARY=$(printf '%s' "$CLEAN" | grep -E '^ *Tests +[0-9]' | tail -1)
PASSED=$(printf '%s'  "$SUMMARY" | grep -oE '[0-9]+ passed'  | grep -oE '[0-9]+' || echo 0)
FAILED=$(printf '%s'  "$SUMMARY" | grep -oE '[0-9]+ failed'  | grep -oE '[0-9]+' || echo 0)
SKIPPED=$(printf '%s' "$SUMMARY" | grep -oE '[0-9]+ skipped' | grep -oE '[0-9]+' || echo 0)
EXECUTED=$(( ${PASSED:-0} + ${FAILED:-0} ))
echo "CHECKED $EXECUTED emulator tests executed ($PASSED passed, $FAILED failed), $SKIPPED skipped"

if [ "${EXECUTED:-0}" -lt 1 ]; then
  echo "::error::Ran $PASSED emulator tests. Zero is a broken run, not a pass: the suite skips itself when FIRESTORE_EMULATOR_HOST is unset."
  rm -f "$LOG"
  exit 1
fi
if [ "${SKIPPED:-0}" -gt 0 ]; then
  echo "::error::$SKIPPED emulator test(s) skipped. They are meant to run here; a skip means the emulator was not reachable."
  rm -f "$LOG"
  exit 1
fi

rm -f "$LOG"
exit "$STATUS"

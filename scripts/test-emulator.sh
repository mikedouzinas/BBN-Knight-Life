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
# FALSIFIED 2026-08-19: ran the suite without the emulator, which is exactly the state that
# hid four unrun tests for months. It printed
#     Tests  10 skipped (10)
#     CHECKED 0 emulator tests executed, 10 skipped
#     ::error::Ran 0 emulator tests. Zero is a broken run, not a pass...
# and exited 1, where the same command without this guard exits 0.
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
PASSED=$(grep -oE 'Tests +[0-9]+ passed' "$LOG" | tail -1 | grep -oE '[0-9]+' || echo 0)
SKIPPED=$(grep -oE '[0-9]+ skipped' "$LOG" | tail -1 | grep -oE '[0-9]+' || echo 0)
echo "CHECKED $PASSED emulator tests executed, $SKIPPED skipped"

if [ "${PASSED:-0}" -lt 1 ]; then
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

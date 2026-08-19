#!/usr/bin/env bash
# Every input resolveDay reads must be written somewhere.
#
# This exists because of a regression that shipped to main and was invisible.
#
# HQ-640 added `LoginVC.term` and the Firestore read that fills it. Recreating a later branch,
# I restored AuthVC.swift wholesale from a snapshot taken before HQ-640 merged, which deleted
# that read. `LoginVC.term` stayed declared, `resolveDay` kept reading it, and it was always
# nil. So the feature was on main, compiled, passed 20 tests, and did nothing.
#
# It did nothing SAFELY, because the rule fails open: a nil term leaves the old behaviour in
# place. That is the design working, and it is also why nobody would have noticed.
#
# Unit tests cannot catch this. They set LoginVC.term directly, which is exactly the point:
# they prove the resolver, not the wiring. So this checks the wiring.
# FALSIFIED 2026-08-19 against the real regression, not an invented one: run with main's
# AuthVC.swift in place, it printed
#     FAIL  LoginVC.term is read by resolveDay but NOTHING assigns it.
#     ::error::1 resolver input(s) are read but never written.
# and exited 1.
set -euo pipefail
cd "$(dirname "$0")/.."

STATE_DIR="BBNDaily"
FAILURES=0
CHECKED=0

# Each entry: the static resolveDay depends on, and a pattern proving something assigns it.
check() {
  local name="$1" assign_pattern="$2"
  CHECKED=$((CHECKED + 1))

  if ! grep -rq "LoginVC\.$name" --include='*.swift' "$STATE_DIR/Other/Extensions.swift"; then
    echo "  skip  LoginVC.$name is no longer read by the resolver"
    return
  fi
  local writers
  writers=$(grep -rl "$assign_pattern" --include='*.swift' "$STATE_DIR" || true)
  if [ -z "$writers" ]; then
    echo "  FAIL  LoginVC.$name is read by resolveDay but NOTHING assigns it."
    echo "        The feature is compiled, silent, and always falls back."
    FAILURES=$((FAILURES + 1))
  else
    echo "  ok    LoginVC.$name <- $(echo "$writers" | tr '\n' ' ')"
  fi
}

echo "Checking that every resolver input is actually loaded:"
check "term"        "LoginVC\.term *= *Term("
check "breaks"      "LoginVC\.breaks *="
check "specialDays" "LoginVC\.specialDays *="

echo "CHECKED $CHECKED resolver inputs"
if [ "$CHECKED" -lt 1 ]; then
  echo "::error::Checked 0 inputs. That is a broken check, not a pass."
  exit 1
fi
if [ "$FAILURES" -gt 0 ]; then
  echo "::error::$FAILURES resolver input(s) are read but never written."
  exit 1
fi
echo "RESULT: every resolver input has a writer"

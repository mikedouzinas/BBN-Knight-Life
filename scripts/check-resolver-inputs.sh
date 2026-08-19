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
# FALSIFIED 2026-08-19 against the REAL regressions, not invented ones. Run with main's
# AuthVC.swift in place it catches both silent reverts, by name and line number:
#     FAIL  LoginVC.term is read by resolveDay but NOTHING assigns it.
#     FAIL  forced casts in the Firestore load path:
#           115: let data = value as! [String: Any]
#           117: var oneBreak = Break(reason: (data["reason"] as! String), ...)
#     ::error::2 check(s) failed.
# and exits 1.
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

# --- and the loaders must not force-cast ------------------------------------------------
#
# The same file restore that deleted the term read ALSO reverted HQ-640's hardening of the
# break loader, putting `value as! [String: Any]`, `data["reason"] as! String` and an
# unchecked `dates[1]` back on main. Live data is clean, so nothing crashed and nothing
# showed. Two silent reverts from one careless restore, which is the argument for checking
# the property rather than trusting the diff.
#
# Firestore documents are edited by hand in a console. A forced cast over one is a launch
# crash for every student, waiting on somebody's typo.
LOADER_FILE="$STATE_DIR/Login/AuthVC.swift"
CHECKED=$((CHECKED + 1))
# Strip // comments before matching. The file documents the traps it used to contain, and a
# comment naming `as!` is not a force cast.
FORCED=$(sed 's://.*::' "$LOADER_FILE" | grep -nE 'as! |\]! ' || true)
if [ -n "$FORCED" ]; then
  echo "  FAIL  forced casts in the Firestore load path ($LOADER_FILE):"
  printf '%s\n' "$FORCED" | sed 's/^/        /'
  echo "        A hand-edited document is a launch crash for everyone. Use guard let."
  FAILURES=$((FAILURES + 1))
else
  echo "  ok    no forced casts in $LOADER_FILE"
fi

echo "CHECKED $CHECKED checks"
if [ "$CHECKED" -lt 1 ]; then
  echo "::error::Checked 0 inputs. That is a broken check, not a pass."
  exit 1
fi
if [ "$FAILURES" -gt 0 ]; then
  echo "::error::$FAILURES check(s) failed. A resolver input has no writer, or a loader force-casts."
  exit 1
fi
echo "RESULT: every resolver input has a writer, and no loader force-casts"

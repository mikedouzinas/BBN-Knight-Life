#!/usr/bin/env bash
# Every mikeveson.com URL the iOS app builds must use the canonical `www.` host.
#
# WHY THIS EXISTS
#
# `mikeveson.com` answers with a 308 to `www.mikeveson.com`. A redirect to a different host
# makes URLSession (and curl, and every spec-compliant client) DROP the `Authorization`
# header. The request then arrives with no token and the server answers "Sign in with Google
# first." - which reads exactly like being signed out, so the search starts on the account
# and the session instead of on the hostname.
#
# That happened on 2026-09-03 with the HQ-656 schedule scan and cost a full round of device
# testing. The bug is one missing `www.` and it is invisible in code review, because
# `https://mikeveson.com/...` looks completely correct.
#
# FALSIFIED 2026-09-03: removed the `www.` from ScheduleScanVC's scanEndpoint and re-ran.
#     ::error::BBNDaily/Tabs/Settings/SettingsDetail/ScheduleScanVC.swift: uses https://mikeveson.com (no www)
#     CHECKED 1 Swift file(s) containing a mikeveson.com URL
#   exit 1
# With the www restored it prints the CHECKED line and exits 0.
set -euo pipefail
cd "$(dirname "$0")/.."

# Only files that actually contain such a URL are candidates. An empty candidate list is a
# broken discovery step, not a pass - a checker that examined nothing must never print a tick.
# `mapfile` is bash 4+; macOS ships bash 3.2, so this stays portable on purpose - a checker
# that only runs in CI is a checker nobody runs before pushing.
files=$(grep -rl "mikeveson\.com" --include="*.swift" BBNDaily BBNDailyWidget 2>/dev/null || true)
count=$(printf '%s' "$files" | grep -c . || true)

if [ "${count:-0}" -eq 0 ]; then
  echo "::error::Found no Swift file containing a mikeveson.com URL. That is a broken discovery step, not a pass."
  exit 1
fi

bad=0
for f in $files; do
  # Match the scheme immediately followed by the bare apex domain.
  if grep -qE 'https?://mikeveson\.com' "$f"; then
    echo "::error::$f: uses https://mikeveson.com (no www). A cross-host 308 drops the Authorization header - use https://www.mikeveson.com"
    bad=1
  fi
done

echo "CHECKED $count Swift file(s) containing a mikeveson.com URL"
exit "$bad"

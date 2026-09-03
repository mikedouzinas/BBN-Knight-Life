#!/usr/bin/env bash
# Settings' table sections must be addressed through `SettingsSection`, never by a bare integer.
#
# WHY THIS EXISTS
#
# Settings has six sections and their ORDER CHANGED: HQ-656 inserted "Manage Schedule" as the
# second one. Sixteen `indexPath.section == <int>` comparisons were converted to the named enum at
# the time - and two `reloadSections(IndexSet(integer: 1))` calls were missed, because the sweep
# looked for comparisons and these are repaints.
#
# The result was invisible in review and wrong on a device: "Clear My Classes" wiped the classes
# correctly, then repainted section 1, which is now Manage Schedule. The seven block rows kept
# showing the classes that had just been deleted, and only corrected when the student opened a
# block and came back, because that redraws the table for an unrelated reason. It reads as a
# delete that did not work.
#
# A bare integer here is not a style problem. It is a row wired to the wrong section, and the
# next person to reorder the sections has no way to find these by reading the diff.
#
# FALSIFIED 2026-09-03: put `IndexSet(integer: 1)` back into reloadBlockRows and re-ran.
#     ::error::BBNDaily/Tabs/Settings/Settings.swift:487: addresses a table section by bare
#     integer. Use SettingsSection.<case>.rawValue - section numbers here have changed once
#     already and a stale one silently repaints the wrong rows.
#     CHECKED 1 file(s), 11 SettingsSection reference(s)
#   exit 1
# With the named form restored: `CHECKED 1 file(s), 12 SettingsSection reference(s)`, exit 0.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="BBNDaily/Tabs/Settings/Settings.swift"

if [ ! -f "$TARGET" ]; then
  echo "::error::$TARGET does not exist. That is a broken discovery step, not a pass - if Settings moved, move this check with it."
  exit 1
fi

# The enum must exist, or every "no bare integers" result below is vacuously true: a file with no
# sections at all would pass this check while being entirely unguarded.
if ! grep -q "enum SettingsSection" "$TARGET"; then
  echo "::error::$TARGET has no SettingsSection enum, so there is nothing for section indices to be named after."
  exit 1
fi

named=$(grep -c "SettingsSection\." "$TARGET" || true)
if [ "${named:-0}" -eq 0 ]; then
  echo "::error::$TARGET never references SettingsSection. Either the enum is unused or this check is looking at the wrong file."
  exit 1
fi

bad=0

# Both shapes that name a section by number. `IndexSet(integer:)` is the one the HQ-656 sweep
# missed; the comparison forms are what it did catch, kept here so they cannot come back.
while IFS= read -r hit; do
  # file:line, so the annotation lands on the offending line in a PR rather than on the file.
  # `${hit%%:*}` would stop at the filename and drop the number the message promises.
  echo "::error::$(echo "$hit" | cut -d: -f1,2): addresses a table section by bare integer. Use SettingsSection.<case>.rawValue - section numbers here have changed once already and a stale one silently repaints the wrong rows."
  bad=1
done < <(grep -nE 'IndexSet\(integer: *[0-9]+\)|(indexPath\.)?section *[=!]= *[0-9]+' "$TARGET" | sed "s|^|$TARGET:|" || true)

echo "CHECKED 1 file(s), $named SettingsSection reference(s)"
exit "$bad"

#!/usr/bin/env bash
# release.sh -- bump, archive, export, check and upload a Knight Life build to App Store Connect.
#
#   scripts/release.sh 2.6.1               bump to 2.6.1 (build number +1), build, check, upload
#   scripts/release.sh 2.6.1 --no-upload   everything except the upload, to check the build
#
# Signing and the upload use the Apple ID signed into Xcode (Settings > Accounts), so no key or
# password is ever needed in this repo. To run with no Xcode login (a headless agent), set all
# three of ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID to an App Store Connect API key you made
# for yourself; they are passed straight to xcodebuild and never written anywhere.
#
# What it refuses: a dirty tree, a branch behind origin/main, a version that does not go up, and
# an exported build whose push entitlement is not production (that build would silently break
# notifications for every student). After the upload, docs/RELEASING.md step 4 onward is the rest.
set -euo pipefail

VERSION="${1:-}"
UPLOAD=1
[[ "${2:-}" == "--no-upload" ]] && UPLOAD=0
if ! [[ "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "usage: scripts/release.sh X.Y.Z [--no-upload]" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PBX=BBNDaily.xcodeproj/project.pbxproj
OUT="${TMPDIR:-/tmp}/knightlife-release-$VERSION"

[[ -z "$(git status --porcelain -- . ':!Pods')" ]] || { echo "refused: the working tree has changes; commit or stash them first" >&2; exit 1; }
git fetch -q origin main
git merge-base --is-ancestor origin/main HEAD || { echo "refused: this branch is behind origin/main; pull first" >&2; exit 1; }
[[ -d Pods ]] || { echo "refused: no Pods/ here; run pod install (or symlink Pods in a worktree)" >&2; exit 1; }

CUR_VERSION=$(grep -m1 -o 'MARKETING_VERSION = [0-9.]*' "$PBX" | awk '{print $3}')
CUR_BUILD=$(grep -m1 -o 'CURRENT_PROJECT_VERSION = [0-9]*' "$PBX" | awk '{print $3}')
NEW_BUILD=$((CUR_BUILD + 1))
newest=$(printf '%s\n%s\n' "$CUR_VERSION" "$VERSION" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
[[ "$VERSION" != "$CUR_VERSION" && "$newest" == "$VERSION" ]] || { echo "refused: $VERSION does not go up from $CUR_VERSION" >&2; exit 1; }

AUTH=()
if [[ -n "${ASC_KEY_PATH:-}${ASC_KEY_ID:-}${ASC_ISSUER_ID:-}" ]]; then
  [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]] || { echo "refused: set all three of ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID, or none" >&2; exit 1; }
  AUTH=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

echo "== $CUR_VERSION ($CUR_BUILD) -> $VERSION ($NEW_BUILD)"
sed -i '' "s/MARKETING_VERSION = $CUR_VERSION;/MARKETING_VERSION = $VERSION;/g; s/CURRENT_PROJECT_VERSION = $CUR_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PBX"
[[ $(grep -c "MARKETING_VERSION = $VERSION;" "$PBX") -ge 2 && $(grep -c "CURRENT_PROJECT_VERSION = $NEW_BUILD;" "$PBX") -ge 2 ]] \
  || { echo "refused: the bump did not land in both build configurations" >&2; git checkout -- "$PBX"; exit 1; }

rm -rf "$OUT" && mkdir -p "$OUT"
options() {
  /usr/libexec/PlistBuddy -c "Add :method string app-store-connect" -c "Add :teamID string JZUXQ9JH9H" \
    -c "Add :uploadSymbols bool true" -c "Add :destination string $1" "$OUT/ExportOptions-$1.plist" >/dev/null
}
options export
options upload

echo "== archive (several minutes)"
xcodebuild -quiet -workspace BBNDaily.xcworkspace -scheme BBNDaily -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/kl.xcarchive" -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} archive

echo "== export"
xcodebuild -quiet -exportArchive -archivePath "$OUT/kl.xcarchive" -exportOptionsPlist "$OUT/ExportOptions-export.plist" \
  -exportPath "$OUT/export" -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"}

echo "== check the exported build"
unzip -q -o "$OUT/export/BBNDaily.ipa" -d "$OUT/ipa"
APP=$(find "$OUT/ipa/Payload" -maxdepth 1 -name '*.app' | head -1)
ENT=$(codesign -d --entitlements - --xml "$APP" 2>/dev/null | plutil -convert xml1 -o - -)
APS=$(echo "$ENT" | grep -A1 aps-environment | tail -1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/')
GTA=$(echo "$ENT" | grep -A1 get-task-allow | tail -1 | grep -o 'true\|false')
V=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Info.plist")
B=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Info.plist")
echo "   aps-environment=$APS get-task-allow=$GTA version=$V build=$B"
[[ "$APS" == production && "$GTA" == false && "$V" == "$VERSION" && "$B" == "$NEW_BUILD" ]] \
  || { echo "refused: this is not a correct App Store build; nothing was uploaded" >&2; exit 1; }

if [[ $UPLOAD -eq 0 ]]; then
  echo "== --no-upload: build checked and left at $OUT/export. The version bump is in $PBX, uncommitted."
  exit 0
fi

echo "== upload"
xcodebuild -quiet -exportArchive -archivePath "$OUT/kl.xcarchive" -exportOptionsPlist "$OUT/ExportOptions-upload.plist" \
  -exportPath "$OUT/upload" -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"}

echo "== uploaded $VERSION ($NEW_BUILD). Next:"
echo "   1. commit the bump on a branch and open a pull request (it changes only $PBX)"
echo "   2. docs/RELEASING.md step 4 onward: TestFlight, then the App Store version and review"

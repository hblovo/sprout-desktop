#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
if [[ "${1:-}" != "--skip-build" ]]; then
    bash scripts/build.sh release
fi

TASK_APP="$TASK_ROOT/dist/芽伴.app"
TASK_ARCH="$(uname -m)"
TASK_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$TASK_APP/Contents/Info.plist")"
TASK_NAME="Sprout-$TASK_VERSION-macos-$TASK_ARCH"
test -x "$TASK_APP/Contents/MacOS/Sprout"
lipo "$TASK_APP/Contents/MacOS/Sprout" -verify_arch "$TASK_ARCH"
test -x "$TASK_APP/Contents/Helpers/SproutHook"
lipo "$TASK_APP/Contents/Helpers/SproutHook" -verify_arch "$TASK_ARCH"
codesign --verify --strict "$TASK_APP/Contents/Helpers/SproutHook"
codesign --verify --deep --strict "$TASK_APP"

ditto -c -k --sequesterRsrc --keepParent "$TASK_APP" "$TASK_ROOT/dist/$TASK_NAME.zip"
mkdir -p "$TASK_ROOT/.build"
TASK_STAGE="$(mktemp -d "$TASK_ROOT/.build/dmg.XXXXXX")"
trap 'rm -rf "$TASK_STAGE"' EXIT
ditto "$TASK_APP" "$TASK_STAGE/芽伴.app"
ln -s /Applications "$TASK_STAGE/Applications"
hdiutil create -volname "芽伴 Sprout" -srcfolder "$TASK_STAGE" -ov -format UDZO "$TASK_ROOT/dist/$TASK_NAME.dmg"
hdiutil verify "$TASK_ROOT/dist/$TASK_NAME.dmg"
unzip -tq "$TASK_ROOT/dist/$TASK_NAME.zip"
(
    cd "$TASK_ROOT/dist"
    shasum -a 256 "$TASK_NAME.zip" "$TASK_NAME.dmg" > SHA256SUMS.txt
)
printf 'Packages ready: %s/dist/%s.{zip,dmg}\n' "$TASK_ROOT" "$TASK_NAME"

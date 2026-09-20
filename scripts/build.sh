#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
export CLANG_MODULE_CACHE_PATH="$TASK_ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$TASK_ROOT/.build/ModuleCache"
BUILD_MODE="${1:-release}"
swift build -c "$BUILD_MODE" --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security
TASK_APP="$TASK_ROOT/dist/芽伴.app"
mkdir -p "$TASK_APP/Contents/MacOS" "$TASK_APP/Contents/Resources"
cp ".build/$BUILD_MODE/Sprout" "$TASK_APP/Contents/MacOS/Sprout.next"
mv -f "$TASK_APP/Contents/MacOS/Sprout.next" "$TASK_APP/Contents/MacOS/Sprout"
cp "$TASK_ROOT/Info.plist" "$TASK_APP/Contents/Info.plist"
swift "$TASK_ROOT/scripts/make-icon.swift" "$TASK_ROOT/.build/Sprout.iconset" "$TASK_APP/Contents/Resources/Sprout.icns"
codesign --force --sign - "$TASK_APP"
codesign --verify --deep --strict "$TASK_APP"
printf 'Built: %s\n' "$TASK_APP"

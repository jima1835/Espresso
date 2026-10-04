#!/bin/bash
# 构建 NoSleep.app 并安装到 ~/Applications
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/NoSleep.app"

# 已在运行就先退出,避免覆盖正在使用的二进制
pkill -x NoSleep 2>/dev/null || true

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -parse-as-library \
    -target "$(uname -m)-apple-macosx13.0" \
    -o "$APP/Contents/MacOS/NoSleep" \
    "$SRC_DIR/NoSleepApp.swift"

cp "$SRC_DIR/Info.plist" "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp "$SRC_DIR/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# ad-hoc 签名(本机自用足够)
codesign --force --sign - "$APP" >/dev/null

echo "built: $APP"

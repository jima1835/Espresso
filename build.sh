#!/bin/bash
# 构建 Espresso.app 并安装到 ~/Applications
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/Espresso.app"

# 已在运行就先退出,避免覆盖正在使用的二进制
pkill -x Espresso 2>/dev/null || true

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -parse-as-library \
    -target "$(uname -m)-apple-macosx13.0" \
    -o "$APP/Contents/MacOS/Espresso" \
    "$SRC_DIR/EspressoApp.swift"

cp "$SRC_DIR/Info.plist" "$APP/Contents/Info.plist"
cp "$SRC_DIR/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# ad-hoc 签名(本机自用足够)
codesign --force --sign - "$APP" >/dev/null

echo "built: $APP"

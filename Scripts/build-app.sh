#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
build_directory="$(swift build -c release "$@" --show-bin-path)"
swift build -c release "$@"

app="dist/MyDic.app"
mkdir -p "$app/Contents/MacOS"
install -m 755 "$build_directory/MyDic" "$app/Contents/MacOS/MyDic"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MyDic</string>
    <key>CFBundleExecutable</key>
    <string>MyDic</string>
    <key>CFBundleIdentifier</key>
    <string>local.mydic.app</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 redinboo (redinboo@gmail.com)</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "$app/Contents/Info.plist"
codesign --force --sign - "$app"
echo "$PWD/$app"

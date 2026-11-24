#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
universal=false
if [[ "${1:-}" == "--universal" ]]; then
    universal=true
    shift
fi

app="dist/MyDic.app"
mkdir -p "$app/Contents/MacOS"
executable="$app/Contents/MacOS/MyDic"

if $universal; then
    binaries=()
    for arch in arm64 x86_64; do
        build_args=(--arch "$arch" --scratch-path ".build/$arch" "$@")
        swift build -c release "${build_args[@]}"
        build_directory="$(swift build -c release "${build_args[@]}" --show-bin-path)"
        binaries+=("$build_directory/MyDic")
    done
    lipo -create "${binaries[@]}" -output "$executable"
    chmod 755 "$executable"
else
    swift build -c release "$@"
    build_directory="$(swift build -c release "$@" --show-bin-path)"
    install -m 755 "$build_directory/MyDic" "$executable"
fi

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
    <string>0.8</string>
    <key>CFBundleVersion</key>
    <string>8</string>
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

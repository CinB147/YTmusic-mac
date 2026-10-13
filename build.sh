#!/bin/bash
# Builds build/YTMusic.app. Usage: ./build.sh [run|install]  (install copies it to /Applications)
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP="build/YTMusic.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/YTMusic" "$APP/Contents/MacOS/YTMusic"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>YTMusic</string>
    <key>CFBundleDisplayName</key><string>YTMusic</string>
    <key>CFBundleIdentifier</key><string>com.alicew.ytmusic</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleExecutable</key><string>YTMusic</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# App icon from the logo in Sources/YTMusic/img
LOGO="Sources/YTMusic/img/images.png"
if [ -f "$LOGO" ]; then
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z $size $size "$LOGO" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        sips -z $((size * 2)) $((size * 2)) "$LOGO" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

xattr -cr "$APP"  # synced folders add attributes codesign rejects
codesign --force --sign - "$APP" 2>/dev/null
echo "Built $APP"
case "${1:-}" in
    run) open "$APP" ;;
    install)
        osascript -e 'quit app "YTMusic"' 2>/dev/null || true
        rm -rf /Applications/YTMusic.app
        cp -R "$APP" /Applications/YTMusic.app
        touch /Applications/YTMusic.app
        echo "Installed /Applications/YTMusic.app"
        open /Applications/YTMusic.app ;;
esac

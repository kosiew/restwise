#!/usr/bin/env bash
# Builds Restwise.app into ./build. Usage: scripts/build-app.sh [--install]
set -euo pipefail

cd "$(dirname "$0")/.."
APP=build/Restwise.app
VERSION=${VERSION:-0.1.0}

swift build -c release --product Restwise
BIN="$(swift build -c release --show-bin-path)/Restwise"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Restwise"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Restwise</string>
    <key>CFBundleDisplayName</key><string>Restwise</string>
    <key>CFBundleIdentifier</key><string>dev.restwise.Restwise</string>
    <key>CFBundleExecutable</key><string>Restwise</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.healthcare-fitness</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x Restwise || true
    rm -rf /Applications/Restwise.app
    cp -R "$APP" /Applications/
    open /Applications/Restwise.app
    echo "Installed to /Applications"
fi

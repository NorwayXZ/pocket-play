#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/build/Pocket Play.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
clang -dynamiclib -framework AppKit -o "$APP/Contents/Resources/libPocketPlayDock.dylib" dock-agent.m
swiftc -O -framework AVFoundation -framework AppKit -o "$APP/Contents/MacOS/PocketPlay" MenuBar/main.swift
cp pocket-play.sh size-presets.sh "$APP/Contents/Resources/"
chmod +x "$APP/Contents/MacOS/PocketPlay" "$APP/Contents/Resources/pocket-play.sh" "$APP/Contents/Resources/size-presets.sh"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Pocket Play</string>
  <key>CFBundleDisplayName</key><string>Pocket Play</string>
  <key>CFBundleIdentifier</key><string>local.pocketplay.menubar</string>
  <key>CFBundleExecutable</key><string>PocketPlay</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.2.0</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSCameraUsageDescription</key><string>将 Mac 摄像头用于 Android 模拟器的前置摄像头。</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
plutil -lint "$APP/Contents/Info.plist"
# Ad-hoc sign the locally built binary so macOS recognizes this as an app.
codesign --force --deep --sign - "$APP"
echo "$APP"

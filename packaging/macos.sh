#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ARCH="${ARCH:-$(uname -m)}" ./build-app.sh
APP="$PWD/build/Pocket Play.app"
JARCH=aarch64; [[ "${ARCH:-$(uname -m)}" == arm64 ]] || JARCH=x64
python3 packaging/fetch-runtime.py mac "$JARCH" "$APP/Contents/Resources/runtime"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
mkdir -p dist build/dmg
# Staging only contains the application and drag-to-install shortcut.
ditto "$APP" 'build/dmg/Pocket Play.app'
[[ -L build/dmg/Applications ]] || ln -s /Applications build/dmg/Applications
hdiutil create -volname 'Pocket Play' -srcfolder build/dmg -ov -format UDZO "dist/PocketPlay-macOS-${ARCH:-$(uname -m)}.dmg"

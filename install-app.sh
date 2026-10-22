#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
./build-app.sh
app='/Applications/Pocket Play.app'
old='/Applications/Pocket Play.previous.app'
if [[ -d "$app" ]]; then
  pkill -f '^/Applications/Pocket Play.app/Contents/MacOS/PocketPlay$' 2>/dev/null || true
  if [[ -e "$old" ]]; then echo "Please move $old before installing." >&2; exit 1; fi
  mv "$app" "$old"
fi
if ditto 'build/Pocket Play.app' "$app" && codesign --verify --deep --strict "$app"; then
  open "$app"
  echo "Installed: $app"
else
  if [[ -d "$old" ]]; then mv "$old" "$app"; fi
  exit 1
fi

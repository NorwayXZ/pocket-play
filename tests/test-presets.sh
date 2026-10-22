#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1])" "$TMP"' EXIT
mkdir -p "$TMP/sdk/platform-tools" "$TMP/avd/Test.avd" "$TMP/scripts"
printf '#!/bin/bash\nexit 0\n' > "$TMP/sdk/platform-tools/adb"
printf '#!/bin/bash\necho Stopped.\n' > "$TMP/scripts/pocket-play.sh"
chmod +x "$TMP/sdk/platform-tools/adb" "$TMP/scripts/pocket-play.sh"
cp "$HERE/size-presets.sh" "$TMP/scripts/"
export ANDROID_SDK_ROOT="$TMP/sdk" ANDROID_AVD_HOME="$TMP/avd" POCKET_PLAY_AVD=Test
CONFIG="$TMP/avd/Test.avd/config.ini"
printf 'hw.lcd.width=1080\nhw.lcd.width=999\nhw.lcd.height=2400\nhw.lcd.density=420\nkeep.setting=yes\n' > "$CONFIG"
for preset in smooth phone tablet wide reset; do
 bash "$TMP/scripts/size-presets.sh" "$preset"
 test "$(grep -c '^hw.lcd.width=' "$CONFIG")" = 1
 grep -q '^keep.setting=yes$' "$CONFIG"
 case "$preset" in smooth) w=720;; phone|reset) w=1080;; tablet) w=2560;; wide) w=1920;; esac
 grep -q "^hw.lcd.width=$w$" "$CONFIG"
done
before="$(cksum "$CONFIG")"
bash "$TMP/scripts/size-presets.sh" reset
test "$before" = "$(cksum "$CONFIG")"
if bash "$TMP/scripts/size-presets.sh" invalid; then exit 1; fi
echo 'PASS: five presets, deduplication, unrelated settings, idempotence, invalid input'

#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
LAUNCHER="$HERE/pocket-play.sh"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ADB="$SDK/platform-tools/adb"
AVD="${POCKET_PLAY_AVD:-PocketPlay_API35}"
CONFIG="${ANDROID_AVD_HOME:-$HOME/.android/avd}/$AVD.avd/config.ini"

usage() { echo "Usage: $0 {smooth|phone|tablet|wide|reset|status}" >&2; exit 2; }
[[ -x "$ADB" ]] || { echo "Missing ADB: $ADB" >&2; exit 1; }
[[ -f "$CONFIG" ]] || { echo "Missing AVD: $CONFIG" >&2; exit 1; }

case "${1:-}" in
  smooth) width=720; height=1600; density=280; label=smooth ;;
  phone|reset) width=1080; height=2400; density=420; label=phone ;;
  tablet) width=2560; height=1600; density=320; label=tablet ;;
  wide) width=1920; height=1080; density=240; label=wide ;;
  status)
    grep -E '^hw.lcd.(width|height|density)=' "$CONFIG"
    exit 0 ;;
  *) usage ;;
esac

current_width="$(sed -n 's/^hw.lcd.width=//p' "$CONFIG" | tail -1)"
current_height="$(sed -n 's/^hw.lcd.height=//p' "$CONFIG" | tail -1)"
current_density="$(sed -n 's/^hw.lcd.density=//p' "$CONFIG" | tail -1)"
if [[ "$current_width:$current_height:$current_density" == "$width:$height:$density" ]]; then
  echo "Already $label (${width}x${height} @ ${density}dpi)."
  exit 0
fi

# Runtime 'wm size' does NOT resize the host Qt window. Clear old overrides,
# shut down cleanly, change the AVD's physical display, then boot it again.
was_running=0
if "$LAUNCHER" status | grep -E '^Device:|^Emulator process running'; then
  was_running=1
  for device in $("$ADB" devices | awk '/^emulator-[0-9]+[[:space:]]+device$/ {print $1}'); do
    name="$("$ADB" -s "$device" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
    if [[ "$name" == "$AVD" ]]; then
      "$ADB" -s "$device" shell wm size reset >/dev/null
      "$ADB" -s "$device" shell wm density reset >/dev/null
      break
    fi
  done
  "$LAUNCHER" stop
fi

# Preserve other device settings and write the three keys in one replacement.
temp="$(mktemp "${CONFIG}.XXXXXX")"
trap '[[ ! -f "$temp" ]] || unlink "$temp"' EXIT
awk -v w="$width" -v h="$height" -v d="$density" '
  !/^hw\.lcd\.(width|height|density)=/ {print}
  END {print "hw.lcd.width=" w; print "hw.lcd.height=" h; print "hw.lcd.density=" d}
' "$CONFIG" > "$temp"
chmod 600 "$temp"
mv "$temp" "$CONFIG"

if ((was_running)); then
  if [[ "${POCKET_PLAY_APP_MANAGED:-0}" == 1 ]]; then
    echo "Switched to $label (${width}x${height} @ ${density}dpi). Restart from Pocket Play."
    exit 0
  fi
  "$LAUNCHER" start
  echo "Switched to $label (${width}x${height} @ ${density}dpi). Waiting for Android…"
  for ((i=0; i<90; i++)); do
    if "$LAUNCHER" status | grep 'boot: complete'; then
      echo 'Android ready. The emulator window now matches the new aspect ratio.'
      exit 0
    fi
    sleep 2
  done
  echo 'Boot is taking longer than expected. Check Pocket Play status/logs.' >&2
  exit 1
fi
echo "Set $label (${width}x${height} @ ${density}dpi). Start the emulator to apply it."

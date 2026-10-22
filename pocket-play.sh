#!/usr/bin/env bash
set -euo pipefail

# A lightweight launcher around the official Android Emulator + Google Play image.
AVD_NAME="${POCKET_PLAY_AVD:-PocketPlay_API35}"
HOST_ARCH="$(uname -m)"
ABI=arm64-v8a
QEMU_ARCH=aarch64
if [[ "$HOST_ARCH" == x86_64 ]]; then ABI=x86_64; QEMU_ARCH=x86_64; fi
IMAGE="system-images;android-35;google_apis_playstore;$ABI"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/pocket-play"
LOG_FILE="$STATE/emulator.log"
DOCK_AGENT="$(cd "$(dirname "$0")" && pwd)/libPocketPlayDock.dylib"
if [[ ! -f "$DOCK_AGENT" && -f '/Applications/Pocket Play.app/Contents/Resources/libPocketPlayDock.dylib' ]]; then
  DOCK_AGENT='/Applications/Pocket Play.app/Contents/Resources/libPocketPlayDock.dylib'
fi
LABEL="local.pocket-play.${AVD_NAME}"
PLIST="$STATE/$LABEL.plist"
DOMAIN="gui/$(id -u)"
export ANDROID_SDK_ROOT="$SDK" ANDROID_HOME="$SDK"
mkdir -p "$STATE"

usage() {
  cat <<USAGE
Pocket Play — Android emulator with Google Play (Apple Silicon/macOS)
Usage: $(basename "$0") {install|start|stop|status|logs|help}
  install  Install official SDK components and create the Play Store AVD
  start    Start the existing AVD, using Quick Boot on subsequent launches
  stop     Close cleanly so Quick Boot can save its snapshot
  status   Check emulator boot and Google Play installation
  logs     Follow emulator logs (Ctrl-C to exit)
USAGE
}

require_macos() {
  if [[ "$(uname -s)" != Darwin ]]; then
    echo 'This launcher requires macOS.' >&2
    exit 1
  fi
}

sdkmanager_bin() {
  if command -v sdkmanager >/dev/null 2>&1; then command -v sdkmanager
  elif [[ -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]]; then echo "$SDK/cmdline-tools/latest/bin/sdkmanager"
  else echo 'Missing sdkmanager. Install: brew install --cask android-commandlinetools' >&2; return 1
  fi
}

avdmanager_bin() {
  if [[ -x "$SDK/cmdline-tools/latest/bin/avdmanager" ]]; then echo "$SDK/cmdline-tools/latest/bin/avdmanager"
  elif command -v avdmanager >/dev/null 2>&1; then command -v avdmanager
  else echo 'Missing avdmanager. Install Android SDK command-line tools.' >&2; return 1
  fi
}

emulator_bin() { echo "$SDK/emulator/emulator"; }
adb_bin() { echo "$SDK/platform-tools/adb"; }
avd_config() { echo "$AVD_HOME/$AVD_NAME.avd/config.ini"; }

remove_pixel_cutout() {
  local device="$1" overlays
  # The Pixel 6 resource overlays paint a punch-hole on the Android display.
  # They are independent of the virtual camera hardware and must be disabled
  # separately for the framework and System UI. Overlay state persists in the
  # AVD userdata, so only make changes when an overlay is enabled.
  overlays="$("$(adb_bin)" -s "$device" shell cmd overlay list 2>/dev/null | tr -d '\r')" || return 0
  if grep -Fq '[x] com.android.internal.emulation.pixel_6' <<< "$overlays"; then
    "$(adb_bin)" -s "$device" shell cmd overlay disable --user 0 \
      com.android.internal.emulation.pixel_6 >/dev/null 2>&1 || true
  fi
  if grep -Fq '[x] com.android.systemui.emulation.pixel_6' <<< "$overlays"; then
    "$(adb_bin)" -s "$device" shell cmd overlay disable --user 0 \
      com.android.systemui.emulation.pixel_6 >/dev/null 2>&1 || true
  fi
}

is_running() {
  if launchctl print "$DOMAIN/$LABEL" 2>/dev/null | grep -q 'state = running'; then return 0; fi
  pgrep -f "^$SDK/emulator/qemu/darwin-$QEMU_ARCH/qemu-system-$QEMU_ARCH -avd $AVD_NAME( |$)" >/dev/null
}

serial() {
  # Search by AVD name; avoids controlling another running Android device.
  local adb="$(adb_bin)" line device name
  [[ -x "$adb" ]] || return 1
  while read -r line; do
    device="${line%%[[:space:]]*}"
    [[ "$device" == emulator-* ]] || continue
    name="$($adb -s "$device" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
    if [[ "$name" == "$AVD_NAME" ]]; then echo "$device"; return 0; fi
  done < <("$adb" devices | tail -n +2)
  return 1
}

install_avd() {
  require_macos
  local manager avd_manager config
  manager="$(sdkmanager_bin)"
  avd_manager="$(avdmanager_bin)"
  echo 'Installing Android Emulator, platform-tools, and the official Google Play ARM64 image…'
  "$manager" --sdk_root="$SDK" emulator platform-tools 'platforms;android-35' "$IMAGE"
  # Homebrew's avdmanager infers its SDK root from its own installation path.
  # Keep a real copy inside SDK (a symlink resolves back to Homebrew and fails).
  if [[ ! -x "$SDK/cmdline-tools/latest/bin/avdmanager" ]]; then
    local tools_dir
    tools_dir="$(cd "$(dirname "$(command -v avdmanager)")/.." && pwd -P)"
    mkdir -p "$SDK/cmdline-tools"
    cp -R "$tools_dir" "$SDK/cmdline-tools/latest"
  fi
  avd_manager="$(avdmanager_bin)"
  if [[ ! -f "$(avd_config)" ]]; then
    echo 'Creating virtual phone…'
    echo 'no' | "$avd_manager" create avd -n "$AVD_NAME" -k "$IMAGE" -d pixel_6 --force
  fi
  config="$(avd_config)"
  [[ -f "$config" ]] || { echo "AVD config not created: $config" >&2; exit 1; }
  # avdmanager may default PlayStore.enabled=no even on a Play image.
  # Replace selected keys in place (rather than appending duplicate keys).
  local setting key value
  for setting in 'PlayStore.enabled=yes' 'hw.ramSize=4096' 'hw.cpu.ncore=4' 'hw.keyboard=yes' 'showDeviceFrame=no'; do
    key="${setting%%=*}"; value="${setting#*=}"
    if grep -q "^${key}=" "$config"; then
      sed -i '' "s/^${key}=.*/${key}=${value}/" "$config"
    else
      printf '%s\n' "$setting" >> "$config"
    fi
  done
  echo "Ready: $AVD_NAME. Run: $0 start"
}

start_avd() {
  require_macos
  local emulator
  emulator="$(emulator_bin)"
  [[ -x "$emulator" ]] || { echo "Emulator missing: $emulator — run '$0 install'" >&2; exit 1; }
  [[ -f "$(avd_config)" ]] || { echo "AVD missing: $AVD_NAME — run '$0 install'" >&2; exit 1; }
  if is_running || serial >/dev/null 2>&1; then echo "$AVD_NAME is already running."; return; fi
  # Default snapshot behavior = load on launch, save on clean exit.
  # A non-restarting launchd job survives the launcher's Terminal closing and
  # lets the emulator finish saving its snapshot before unloading the job.
  cat >"$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$LABEL</string>
<key>ProgramArguments</key><array>
<string>$emulator</string><string>-avd</string><string>$AVD_NAME</string>
<string>-gpu</string><string>host</string><string>-no-boot-anim</string><string>-netfast</string>
</array>
<key>RunAtLoad</key><true/>
<key>StandardOutPath</key><string>$LOG_FILE</string>
<key>StandardErrorPath</key><string>$LOG_FILE</string>
</dict></plist>
PLIST
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
  # Qt's foreground transform normally creates a Dock icon. Disable that
  # transform and set accessory policy from inside the emulator process.
  if [[ -f "$DOCK_AGENT" ]]; then
    /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables dict" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:QT_MAC_DISABLE_FOREGROUND_APPLICATION_TRANSFORM string 1" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:DYLD_INSERT_LIBRARIES string $DOCK_AGENT" "$PLIST"
  fi
  : >"$LOG_FILE"
  launchctl bootstrap "$DOMAIN" "$PLIST"
  sleep 2
  if ! is_running; then
    echo "Emulator exited unexpectedly. See $LOG_FILE" >&2
    tail -30 "$LOG_FILE" >&2
    exit 1
  fi
  echo "Starting $AVD_NAME. First boot may take a few minutes; later boots use Quick Boot."
  echo "Logs: $LOG_FILE"
}

stop_avd() {
  local device
  if device="$(serial)"; then
    "$(adb_bin)" -s "$device" emu kill >/dev/null
    echo "Closing $device cleanly; waiting for Quick Boot snapshot…"
    local i
    for ((i=0; i<60; i++)); do
      if ! is_running; then break; fi
      sleep 1
    done
    if is_running; then
      echo "Still saving; leave the emulator open until it finishes. Log: $LOG_FILE" >&2
      return 1
    fi
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    echo 'Stopped.'
  elif is_running; then
    echo 'Android is still connecting. Close the emulator window to save its snapshot.' >&2
    return 1
  else
    echo 'Emulator is not running.'
  fi
}

status_avd() {
  local device boot play
  echo "AVD: $AVD_NAME"
  if device="$(serial)"; then
    boot="$("$(adb_bin)" -s "$device" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    play="$("$(adb_bin)" -s "$device" shell pm path com.android.vending 2>/dev/null | tr -d '\r')"
    if [[ "$boot" == 1 ]]; then remove_pixel_cutout "$device"; fi
    echo "Device: $device; boot: $([[ "$boot" == 1 ]] && echo complete || echo in-progress)"
    echo "Google Play: $([[ "$play" == package:* ]] && echo installed || echo not-detected)"
  elif is_running; then
    echo 'Emulator process running; Android is still connecting.'
  elif "$(adb_bin)" devices 2>/dev/null | grep -q '^emulator-.*offline'; then
    echo 'Emulator is booting; ADB is offline for now.'
  else
    echo 'Stopped.'
  fi
}

case "${1:-help}" in
  install) install_avd ;;
  start) start_avd ;;
  stop) stop_avd ;;
  status) status_avd ;;
  logs) touch "$LOG_FILE"; tail -f "$LOG_FILE" ;;
  help|-h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac

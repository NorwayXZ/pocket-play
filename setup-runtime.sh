#!/bin/bash
# Runtime is bundled in release packages; the multi-GB Android image is installed per user.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
export ANDROID_SDK_ROOT="$SDK" ANDROID_HOME="$SDK"
JDK="$HERE/runtime/java/Contents/Home"
[[ -d "$JDK" ]] || JDK="$HERE/runtime/java"
if [[ -x "$JDK/bin/java" ]]; then export JAVA_HOME="$JDK"; export PATH="$JAVA_HOME/bin:$PATH"; fi
mkdir -p "$SDK/cmdline-tools"
if [[ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]]; then
  [[ -d "$HERE/runtime/cmdline-tools" ]] || { echo 'Runtime missing. Download the DMG from GitHub Releases, or install Android command-line tools and JDK 17+.'; exit 1; }
  ditto "$HERE/runtime/cmdline-tools" "$SDK/cmdline-tools/latest"
fi
# Consent was explicitly requested in the GUI before entering this script.
# Avoid pipefail on yes receiving SIGPIPE when sdkmanager finishes.
set +o pipefail
yes | "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" --licenses
result=${PIPESTATUS[1]}
set -o pipefail
[[ "$result" == 0 ]] || exit "$result"
exec /bin/bash "$HERE/pocket-play.sh" install

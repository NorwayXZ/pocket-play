# Pocket Play

<p align="center"><strong>macOS 菜单栏 Android 模拟器 · Google Play · Apple Silicon</strong></p>

A lightweight macOS menu-bar app that wraps the **official Android Emulator** with the **Google Play ARM64 system image** (Android 15 / API 35). Not an independently implemented VM — this is a clean launcher around Google's own emulator with quality-of-life improvements for daily use.

## Features

- 📱 **Google Play Store** — sign in with your Google account, install apps normally
- 🖥️ **Menu-bar app** — no Dock icon; closing the window hides Android (keeps running); right-click menu to quit
- 📐 **Display presets** — switch between Phone (1080×2400), Tablet (2560×1600), Widescreen (1920×1080), and reset
- 📷 **Mac webcam passthrough** — maps your Mac camera (e.g. Studio Display) as the Android front camera for face verification, video calls, etc.
- ⚡ **Quick Boot** — first boot takes a few minutes; subsequent launches restore from snapshot in seconds
- 🔒 **No Dock clutter** — emulator window has no Dock icon; close button hides window instead of killing the VM

## Requirements

- macOS on **Apple Silicon** (M1/M2/M3/M4)
- [Homebrew](https://brew.sh/)
- Java (JDK 17+) — `brew install openjdk@17`
- Android command-line tools — `brew install --cask android-commandlinetools`

## Quick Start

```bash
# 1. Install SDK components and create the AVD (one-time, downloads ~GBs)
./pocket-play.sh install

# 2. Build and install the menu-bar app
./install-app.sh

# 3. Launch from the menu bar, or:
./pocket-play.sh start     # or double-click 启动模拟器.command
./pocket-play.sh status    # check Android boot and Google Play
./pocket-play.sh stop      # or double-click 关闭模拟器.command
```

On the first launch, complete Android setup and sign in to Google Play. Subsequent launches use Quick Boot snapshots.

## Menu-Bar App

Run `./install-app.sh` to build and install `/Applications/Pocket Play.app`.

| Menu Item | Action |
|---|---|
| 启动模拟器 | Start the emulator (requests camera permission on first run) |
| 显示模拟器窗口 | Restore hidden emulator window |
| 关闭模拟器（保存快照） | Gracefully stop with Quick Boot snapshot |
| 显示比例 → | Switch between Phone / Tablet / Widescreen / Reset |
| 打开日志 | Open `~/.local/state/pocket-play/emulator.log` |
| 彻底退出 | Stop Android + exit menu-bar app |

The app uses `LSUIElement` — no Dock icon, lives only in the menu bar. Closing the emulator window hides it; the VM keeps running. Use **彻底退出** to fully quit.

## Camera Passthrough

The app maps your Mac's webcam (e.g. Studio Display camera) to the Android front camera via `-camera-front webcam0`. On first launch, macOS will prompt for camera permission. The app requests TCC authorization before starting the emulator to ensure the webcam session is established cleanly.

> **Note:** If the camera shows a black screen, stop and restart the emulator from the menu. Some face-verification apps may also detect the emulator environment independently.

## Display Presets

Presets modify `hw.lcd.width`, `hw.lcd.height`, and `hw.lcd.density` in the AVD config and restart the emulator. This resizes both the Android display and the macOS window.

| Preset | Resolution | Density |
|---|---|---|
| 手机 | 1080 × 2400 | 420 |
| 平板 | 2560 × 1600 | 320 |
| 宽屏 | 1920 × 1080 | 240 |
| 恢复原始 | 1080 × 2400 | 420 |

Userdata and Google account persist across size changes.

## Project Structure

```
pocket-play/
├── MenuBar/main.swift       # Swift menu-bar app (NSStatusItem, AVFoundation camera, emulator lifecycle)
├── dock-agent.m             # Injected ObjC dylib — hides Dock icon, intercepts close button
├── pocket-play.sh           # CLI launcher (install / start / stop / status / logs)
├── size-presets.sh           # Display preset switcher
├── build-app.sh             # Build script → build/Pocket Play.app
├── install-app.sh           # Build + install to /Applications
├── 启动模拟器.command         # Double-click launcher
└── 关闭模拟器.command         # Double-click stopper
```

## How It Works

- Uses the official Google Play ARM64 system image (`google_apis_playstore;arm64-v8a`)
- Emulator is managed via `launchd` (CLI) or `Process` (menu-bar app)
- `QT_MAC_DISABLE_FOREGROUND_APPLICATION_TRANSFORM=1` prevents the emulator's own Dock icon
- `dock-agent.m` is compiled as a dylib and injected via `DYLD_INSERT_LIBRARIES` to set `NSApplicationActivationPolicyAccessory` and redirect the close button to hide instead of quit
- Pixel 6 punch-hole overlays are automatically disabled after boot

## Acknowledgements

Inspired by [MiniSim](https://github.com/okwasniewski/MiniSim), [Simulators](https://github.com/rialdana/simulators), and [AndroMac](https://github.com/sabbirmohammad/AndroMac). Pocket Play is independent code and does not bundle those projects.

## License

[MIT](LICENSE)

## Download installers (v0.3.0 Preview)

Download from **[GitHub Releases](https://github.com/NorwayXZ/pocket-play/releases/latest)**
(or [all releases](https://github.com/NorwayXZ/pocket-play/releases) for Preview builds).

| Platform | Download |
|---|---|
| macOS 13+ Apple Silicon | `PocketPlay-macOS-arm64.dmg` |
| macOS 13+ Intel | `PocketPlay-macOS-x86_64.dmg` |
| Windows 10/11 x64 (Intel/AMD) | `PocketPlay-Windows-x64-Setup.exe` |

Mac: open the DMG, drag Pocket Play to Applications, then launch it and use the
menu-bar **启动模拟器** item. Windows: run Setup, then right-click the Pocket Play
tray icon → **启动 / 安装 Android**. The installers include a Temurin Java 17 JRE
and Google's command-line tools. **Homebrew, Java installation, Python, and a
compiler are not needed by end users.** First run asks for Android SDK license
consent before downloading the emulator and multi-GB Play Store image. Allow
at least 15 GB free disk space and access to Google's download servers. SDK
packages and user accounts are not bundled in the installer.

Windows requires hardware virtualization enabled in BIOS/UEFI and **Windows
Hypervisor Platform** enabled in Windows Features, followed by a reboot.
Windows ARM is not supported. The Windows app currently reserves emulator port
5554; close other Android emulators before launching it. On Windows, use
**隐藏到托盘** to hide the window; the native window close action is disabled to
prevent accidental shutdown (not yet the same close-to-hide behavior as Mac).

These are **Preview builds**. macOS has only an ad-hoc signature (not Apple
Developer ID signed or notarized), and Windows is not Authenticode signed;
the OS may require an explicit approval to launch or block it under enterprise
policy. No signing certificates are included. Apple Silicon camera/lifecycle
was tested locally; Intel/Windows installers are compiled in CI but emulator,
camera and GPU behavior still require tests on those physical platforms.
Camera passthrough does not guarantee that any app's face verification accepts
an emulator. Current Mac front camera uses `webcam0`; permission denial currently
prevents startup until camera access is granted. Windows camera availability
also depends on system camera permissions.

### Release build

Tag `v*` to trigger `.github/workflows/release.yml`. CI builds two Mac DMGs and a
self-contained .NET 8 Windows installer, verifies downloaded runtime checksums,
and publishes a GitHub prerelease with `SHA256SUMS.txt` only after every build
succeeds. macOS packages are separate architectures rather than a universal VM:
ARM hosts use the ARM64 Android image; Intel/Windows use the x86_64 image.

The MIT license covers Pocket Play source. Bundled Google SDK tools and Temurin
runtime retain their upstream licenses (included in runtime directories); Android
SDK licenses must be accepted separately. Build inputs are fetched from official
metadata and verified against upstream checksums; `latest` can change between
builds, so these builds are not bit-for-bit reproducible.

## Bug investigation / performance

The menu now includes **流畅手机 · 720×1600（低负载）**, preserving the phone
aspect ratio at lower pixel load. It restarts Android without clearing userdata.
This is an opt-in performance mode, not a guarantee of 60 FPS or third-party app
compatibility. See [investigation status](docs/BUGS.md) and
[pinned GitHub source references](docs/REFERENCES.md). Xianyu session loss is
currently unresolved; do not treat the preview release as production-ready.

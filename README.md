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

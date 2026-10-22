import AppKit
import AVFoundation
import Foundation
import Darwin

@MainActor
final class PocketPlayApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let statusLine = NSMenuItem(title: "正在检查…", action: nil, keyEquivalent: "")
    private let startItem = NSMenuItem(title: "启动模拟器", action: #selector(start), keyEquivalent: "s")
    private let showItem = NSMenuItem(title: "显示模拟器窗口", action: #selector(showEmulator), keyEquivalent: "o")
    private let stopItem = NSMenuItem(title: "关闭模拟器（保存快照）", action: #selector(stop), keyEquivalent: "")
    private var timer: Timer?
    private var busy = false
    private var refreshing = false
    private var emulatorProcess: Process?

    private var script: String {
        Bundle.main.resourceURL!.appendingPathComponent("pocket-play.sh").path
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // No Dock icon for this launcher.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "iphone", accessibilityDescription: "Pocket Play")
            button.toolTip = "Pocket Play — Android / Google Play"
        }
        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        startItem.target = self; showItem.target = self; stopItem.target = self
        menu.addItem(startItem)
        menu.addItem(showItem)
        menu.addItem(stopItem)
        let sizeMenu = NSMenu()
        for (title, value) in [("流畅手机 · 720×1600（低负载）", "smooth"), ("手机 · 1080×2400", "phone"), ("平板 · 横向 2560×1600", "tablet"), ("宽屏 · 1920×1080", "wide"), ("恢复原始尺寸", "reset")] {
            let item = NSMenuItem(title: title, action: #selector(changeSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "显示比例", action: nil, keyEquivalent: "")
        menu.setSubmenu(sizeMenu, for: sizeItem)
        menu.addItem(sizeItem)
        menu.addItem(.separator())
        let logs = NSMenuItem(title: "打开日志", action: #selector(openLogs), keyEquivalent: "")
        logs.target = self; menu.addItem(logs)
        let quit = NSMenuItem(title: "彻底退出（关闭模拟器与菜单栏）", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        statusItem.menu = menu
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(start), name: Notification.Name("local.pocketplay.start-emulator"), object: nil)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }


    private func run(_ command: String, argument: String? = nil, completion: @escaping @MainActor (Int32, String) -> Void) {
        let path = command == "setup" ? Bundle.main.resourceURL!.appendingPathComponent("setup-runtime.sh").path :
            (argument == nil ? script : Bundle.main.resourceURL!.appendingPathComponent("size-presets.sh").path)
        let args = argument.map { [$0] } ?? [command]
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [path] + args
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            if argument != nil { env["POCKET_PLAY_APP_MANAGED"] = "1" }
            task.environment = env
            // A private file avoids pipe EOF hangs from inherited ADB daemon handles
            // and bounds RAM use during a multi-GB SDK installation.
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
            defer { try? FileManager.default.removeItem(at: outputURL) }
            do {
                let outputHandle = try FileHandle(forUpdating: outputURL)
                defer { try? outputHandle.close() }
                task.standardInput = FileHandle.nullDevice
                task.standardOutput = outputHandle
                task.standardError = outputHandle
                try task.run()
                let limit: TimeInterval = command == "setup" ? 3600 : (command == "status" ? 12 : 240)
                let deadline = Date().addingTimeInterval(limit)
                while task.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
                let timedOut = task.isRunning
                if timedOut {
                    task.terminate()
                    Thread.sleep(forTimeInterval: 0.3)
                    if task.isRunning { Darwin.kill(task.processIdentifier, SIGKILL) }
                }
                task.waitUntilExit()
                let size = try outputHandle.seekToEnd()
                try outputHandle.seek(toOffset: size > 65536 ? size - 65536 : 0)
                let data = outputHandle.readDataToEndOfFile()
                let output = String(decoding: data, as: UTF8.self) + (timedOut ? "\n操作超时，请检查 ADB / 模拟器状态。" : "")
                let code: Int32 = timedOut ? 124 : task.terminationStatus
                Task { @MainActor in completion(code, output) }
            } catch {
                Task { @MainActor in completion(1, error.localizedDescription) }
            }
        }
    }

    private func refresh() {
        guard !busy, !refreshing else { return }
        refreshing = true
        run("status") { [weak self] code, output in
            guard let self else { return }
            self.refreshing = false
            // An older refresh must not overwrite a newer operation's UI.
            guard !self.busy else { return }
            guard code == 0 else {
                self.statusLine.title = "状态检查失败 · 请查看日志"
                return
            }
            let running = output.contains("Device: ") || output.contains("process running") || output.contains("booting")
            self.statusLine.title = output.contains("boot: complete") ? "Android 已就绪 · Google Play" :
                running ? "Android 启动中…" : "Android 已关闭"
            self.startItem.isEnabled = !running
            self.stopItem.isEnabled = running
            self.showItem.isEnabled = running
        }
    }

    private func operation(_ command: String, label: String) {
        guard !busy else { return }
        busy = true
        statusLine.title = label
        startItem.isEnabled = false; stopItem.isEnabled = false
        run(command) { [weak self] code, output in
            guard let self else { return }
            self.busy = false
            self.refresh()
            if code != 0 { self.alert("操作失败", output) }
        }
    }

    private func launchEmulator() {
        guard !busy else { return }
        let sdk = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Android/sdk")
        let config = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".android/avd/PocketPlay_API35.avd/config.ini")
        if !FileManager.default.fileExists(atPath: sdk.appendingPathComponent("emulator/emulator").path) || !FileManager.default.fileExists(atPath: config.path) {
            let prompt = NSAlert()
            prompt.messageText = "首次安装 Android 环境"
            prompt.informativeText = "将从 Google 下载官方 Android 15 / Google Play 镜像（数 GB），需要网络及至少 15 GB 可用空间。继续表示同意 Android SDK 许可。下载期间请勿退出。许可：https://developer.android.com/studio/terms"
            prompt.addButton(withTitle: "同意并安装")
            prompt.addButton(withTitle: "取消")
            guard prompt.runModal() == .alertFirstButtonReturn else { return }
            busy = true
            statusLine.title = "正在下载 Android 环境…"
            run("setup") { code, output in
                self.busy = false
                if code == 0 { self.launchEmulator() }
                else { self.alert("Android 安装失败", output); self.refresh() }
            }
            return
        }
        // macOS grants camera access to the app process, not the Android guest.
        // Start the emulator only after TCC has resolved the app's permission;
        // otherwise its webcam session can remain black until a full restart.
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { self.launchEmulator() }
                    else { self.cameraPermissionAlert() }
                }
            }
            return
        case .denied, .restricted:
            cameraPermissionAlert()
            return
        default:
            break
        }
        busy = true
        statusLine.title = "正在启动…"
        run("status") { [weak self] _, output in
            guard let self else { return }
            if output.contains("Device: ") || output.contains("process running") || output.contains("booting") {
                self.busy = false; self.refresh(); return
            }
            let home = FileManager.default.homeDirectoryForCurrentUser
            let sdk = home.appendingPathComponent("Library/Android/sdk")
            let emulator = sdk.appendingPathComponent("emulator/emulator")
            let log = home.appendingPathComponent(".local/state/pocket-play/emulator.log")
            try? FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: log.path) { FileManager.default.createFile(atPath: log.path, contents: nil) }
            let process = Process()
            process.executableURL = emulator
            process.arguments = ["-avd", "PocketPlay_API35", "-gpu", "host", "-no-boot-anim", "-netfast", "-camera-front", "webcam0"]
            var env = ProcessInfo.processInfo.environment
            env["ANDROID_SDK_ROOT"] = sdk.path
            env["ANDROID_HOME"] = sdk.path
            env["QT_MAC_DISABLE_FOREGROUND_APPLICATION_TRANSFORM"] = "1"
            env["DYLD_INSERT_LIBRARIES"] = Bundle.main.resourceURL!.appendingPathComponent("libPocketPlayDock.dylib").path
            process.environment = env
            do {
                let handle = try FileHandle(forWritingTo: log)
                try handle.truncate(atOffset: 0)
                process.standardOutput = handle
                process.standardError = handle
                try process.run()
                self.emulatorProcess = process
                self.busy = false
                self.refresh()
            } catch {
                self.busy = false
                self.alert("无法启动模拟器", error.localizedDescription)
                self.refresh()
            }
        }
    }

    private func cameraPermissionAlert() {
        alert("摄像头未获授权", "在系统设置 → 隐私与安全性 → 摄像头中允许 Pocket Play，然后重新启动模拟器。")
    }

    private func alert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message.isEmpty ? "请检查模拟器日志。" : String(message.suffix(3000))
        alert.alertStyle = .warning
        alert.runModal()
    }

    @objc private func changeSize(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        guard !busy else { return }
        busy = true
        statusLine.title = "正在切换设备屏幕…"
        startItem.isEnabled = false; stopItem.isEnabled = false
        run("size", argument: value) { [weak self] code, output in
            guard let self else { return }
            self.busy = false
            if code != 0 { self.alert("尺寸切换失败", output); self.refresh() }
            else if output.contains("Restart from Pocket Play") { self.launchEmulator() }
            else { self.refresh() }
        }
    }

    @objc private func start() { launchEmulator() }
    @objc private func stop() { operation("stop", label: "正在保存快照并关闭…") }

    @objc private func showEmulator() {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("local.pocketplay.show-emulator"), object: nil)
    }

    @objc private func openLogs() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let log = home.appendingPathComponent(".local/state/pocket-play/emulator.log")
        NSWorkspace.shared.open(log)
    }

    @objc private func quitApp() {
        guard !busy else { return }
        busy = true
        statusLine.title = "正在关闭…"
        run("stop") { [weak self] code, output in
            guard let self else { return }
            self.busy = false
            if code == 0 { self.timer?.invalidate(); NSApp.terminate(nil) }
            else { self.alert("关闭失败", output); self.refresh() }
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = PocketPlayApp()
    app.delegate = delegate
    app.run()
}

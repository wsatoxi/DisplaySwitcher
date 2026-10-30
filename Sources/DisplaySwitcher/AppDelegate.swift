import AppKit
import ServiceManagement

let showPickerNotification = Notification.Name("io.github.satoxiw-k.DisplaySwitcher.showPicker")
let switchModeNotification = Notification.Name("io.github.satoxiw-k.DisplaySwitcher.switchMode")

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let picker = PickerController()
    private let recorder = ShortcutRecorder()
    private var menuModes: [DisplayMode] = []
    private var termSource: DispatchSourceSignal?

    private let pickerHotKeyID: UInt32 = 1
    private let emergencyHotKeyID: UInt32 = 2

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "Display Switcher")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        Switcher.shared.start()
        registerHotKeys()
        syncLoginItem()

        DistributedNotificationCenter.default().addObserver(self, selector: #selector(pickerPressed),
                                                            name: showPickerNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(switchFromCLI(_:)),
                                                            name: switchModeNotification, object: nil)

        // pkill などで終了させられたときも、ディスプレイを戻してから終わる
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        termSource = source
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        picker.close()
        Switcher.shared.restoreBeforeQuit()
        return .terminateNow
    }

    // MARK: - ショートカット

    private func registerHotKeys() {
        let hotKey = Store.shared.hotKey
        let ok = HotKeyCenter.shared.register(id: pickerHotKeyID, hotKey) { [weak self] in self?.pickerPressed() }
        if !ok {
            Toast.show(L("%@ is in use by another app and could not be registered", hotKey.label), symbol: "exclamationmark.triangle")
        }
        HotKeyCenter.shared.register(id: emergencyHotKeyID, .emergency) { [weak self] in
            self?.picker.close()
            Switcher.shared.restoreAll(message: L("All displays restored"))
        }
    }

    @objc private func pickerPressed() {
        if Switcher.shared.isBusy {
            NSSound.beep()
            return
        }
        picker.hotKeyPressed(Store.shared.hotKey)
    }

    @objc private func switchFromCLI(_ notification: Notification) {
        guard let arg = notification.object as? String else { return }
        let modes = DisplayManager.shared.modes(for: DisplayManager.shared.displays())
        let mode = Int(arg).flatMap { modes.indices.contains($0 - 1) ? modes[$0 - 1] : nil } ?? modes.first { $0.id == arg }
        if let mode { Switcher.shared.switchTo(mode) }
    }

    // MARK: - メニューバー

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let manager = DisplayManager.shared
        let displays = manager.displays()
        menuModes = manager.modes(for: displays)
        let current = manager.currentModeID(displays, menuModes)

        if menuModes.isEmpty {
            let item = NSMenuItem(title: L("Only one display is connected"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        for (i, mode) in menuModes.enumerated() {
            let item = NSMenuItem(title: mode.title, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            item.state = mode.id == current ? .on : .off
            item.image = NSImage(systemSymbolName: mode.symbol, accessibilityDescription: nil)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let restore = NSMenuItem(title: L("Show All Displays"), action: #selector(restoreAll), keyEquivalent: "p")
        restore.keyEquivalentModifierMask = [.control, .option, .command]
        restore.target = self
        menu.addItem(restore)

        let shortcut = NSMenuItem(title: L("Change Shortcut (%@)…", Store.shared.hotKey.label),
                                  action: #selector(changeShortcut), keyEquivalent: "")
        shortcut.target = self
        menu.addItem(shortcut)

        let login = NSMenuItem(title: L("Open at Login"), action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("Quit Display Switcher"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard menuModes.indices.contains(sender.tag) else { return }
        Switcher.shared.switchTo(menuModes[sender.tag])
    }

    @objc private func restoreAll() {
        Switcher.shared.restoreAll(message: L("All displays restored"))
    }

    @objc private func changeShortcut() {
        picker.close()
        HotKeyCenter.shared.unregister(id: pickerHotKeyID)
        recorder.begin(current: Store.shared.hotKey) { [weak self] hotKey in
            if let hotKey {
                Store.shared.hotKey = hotKey
                Toast.show(L("Shortcut changed to %@", hotKey.label), symbol: "keyboard")
            }
            self?.registerHotKeys()
        }
    }

    // MARK: - ログイン時に起動

    @objc private func toggleLoginItem() {
        let enabled = SMAppService.mainApp.status != .enabled
        Store.shared.launchAtLogin = enabled
        setLoginItem(enabled)
    }

    /// 起動するたびに、希望どおり登録されているかを確かめる。
    /// アプリの移動・名前の変更・ビルドし直しで登録が外れても、ここで登録し直す
    private func syncLoginItem() {
        guard Store.shared.launchAtLogin, Bundle.main.bundleURL.pathExtension == "app" else { return }
        // システム設定で OFF にされた場合（要承認）は、ユーザーの操作を優先して触らない
        switch SMAppService.mainApp.status {
        case .notRegistered, .notFound:
            try? SMAppService.mainApp.register()
        default:
            break
        }
    }

    private func setLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Toast.show(L("Could not change the login item (%@)", error.localizedDescription), symbol: "exclamationmark.triangle")
        }
    }
}

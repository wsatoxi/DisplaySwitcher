import AppKit

/// 切り替えの実行と安全装置（確認・自動復帰）をまとめる
final class Switcher {
    static let shared = Switcher()

    private let manager = DisplayManager.shared
    private let store = Store.shared
    private let queue = DispatchQueue(label: "io.github.satoxiw-k.DisplaySwitcher.apply")
    private var busyCount = 0
    private var lastKeys: Set<String> = []
    private var quietUntil = Date.distantPast
    private var pendingCheck: DispatchWorkItem?
    private var confirm: ConfirmPanel?

    var isBusy: Bool { busyCount > 0 }

    func start() {
        CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
            guard !flags.contains(.beginConfigurationFlag) else { return }
            DispatchQueue.main.async { Switcher.shared.scheduleCheck(after: 1.5) }
        }, nil)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                                                          object: nil, queue: .main) { _ in
            Switcher.shared.scheduleCheck(after: 3)
        }

        // クラッシュなどで無効なディスプレイが残っていたら戻す
        if !store.disabled.isEmpty {
            restoreAll(message: L("Turned back on displays that were left off"))
        } else {
            let displays = manager.displays()
            lastKeys = Set(displays.map(\.key))
            manager.rememberLayoutIfExtended(displays)
        }
    }

    func switchTo(_ mode: DisplayMode, confirmIfNew: Bool = true) {
        guard !isBusy else { NSSound.beep(); return }
        let before = manager.displays()
        let set = manager.setKey(before)
        let beforeModes = manager.modes(for: before)
        let previousID = manager.currentModeID(before, beforeModes)
        let previous = beforeModes.first { $0.id == previousID }
        dismissConfirm()

        busyCount += 1
        queue.async {
            var failure: Error?
            do {
                try self.manager.apply(mode)
            } catch {
                failure = error
                self.manager.restoreAll()
            }
            DispatchQueue.main.async {
                self.finishBusy()
                if let failure {
                    Toast.show(L("All displays restored (%@)", failure.localizedDescription), symbol: "exclamationmark.triangle")
                    return
                }
                let confirmKey = "\(set)|\(mode.id)"
                if confirmIfNew, mode.id != "extend", !self.store.isConfirmed(confirmKey) {
                    self.askToKeep(mode, confirmKey: confirmKey, previous: previous)
                } else {
                    Toast.show(mode.title, symbol: mode.symbol)
                }
            }
        }
    }

    /// すべてのディスプレイを有効にして拡張に戻す（緊急用ショートカットからも呼ばれる）
    func restoreAll(message: String?) {
        dismissConfirm()
        busyCount += 1
        queue.async {
            self.manager.restoreAll()
            DispatchQueue.main.async {
                self.finishBusy()
                if let message { Toast.show(message, symbol: "checkmark.circle") }
            }
        }
    }

    /// アプリ終了時。拡張でなければ戻してから終わる
    func restoreBeforeQuit() {
        dismissConfirm()
        let displays = manager.displays()
        guard !store.disabled.isEmpty || !manager.isExtendedAll(displays) else { return }
        queue.sync { self.manager.restoreAll() }
    }

    private func askToKeep(_ mode: DisplayMode, confirmKey: String, previous: DisplayMode?) {
        confirm = ConfirmPanel.show(title: L("Keep “%@”?", mode.title), seconds: 15, onKeep: { [weak self] in
            self?.confirm = nil
            self?.store.markConfirmed(confirmKey)
            Toast.show(mode.title, symbol: mode.symbol)
        }, onRevert: { [weak self] in
            guard let self else { return }
            self.confirm = nil
            if let previous {
                self.switchTo(previous, confirmIfNew: false)
            } else {
                self.restoreAll(message: L("All displays restored"))
            }
        })
    }

    private func dismissConfirm() {
        confirm?.dismiss()
        confirm = nil
    }

    private func finishBusy() {
        busyCount -= 1
        quietUntil = Date().addingTimeInterval(2)
        let displays = manager.displays()
        lastKeys = Set(displays.map(\.key))
        manager.rememberLayoutIfExtended(displays)
    }

    // MARK: - 構成の変化（抜き差し・蓋の開け閉め・スリープ復帰）

    func scheduleCheck(after delay: TimeInterval) {
        pendingCheck?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.check() }
        pendingCheck = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func check() {
        // 自分の切り替えによる変化は無視する
        if isBusy { scheduleCheck(after: 1); return }
        let wait = quietUntil.timeIntervalSinceNow
        if wait > 0 { scheduleCheck(after: wait + 0.1); return }

        let displays = manager.displays()
        let keys = Set(displays.map(\.key))
        let changed = keys != lastKeys
        lastKeys = keys
        if !store.disabled.isEmpty, changed || !displays.contains(where: \.isEnabled) {
            restoreAll(message: L("The display setup changed, so all displays were restored"))
            return
        }
        // システム設定で解像度や配置を変えたら、それを覚える
        manager.rememberModes(displays)
        manager.rememberLayoutIfExtended(displays)
    }
}

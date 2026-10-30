import AppKit
import Carbon.HIToolbox

/// 「ショートカットを変更…」の入力ウインドウ
final class ShortcutRecorder: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var monitor: Any?
    private var message: NSTextField?
    private var completion: ((HotKey?) -> Void)?

    func begin(current: HotKey, completion: @escaping (HotKey?) -> Void) {
        finish(nil)
        self.completion = completion

        let title = makeLabel(L("Press the new shortcut"), size: 14, weight: .semibold)
        let message = makeLabel(L("Current: %@  (Esc to cancel)", current.label), size: 12, color: .secondaryLabelColor)
        self.message = message
        let stack = NSStackView(views: [title, message])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 110),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L("Change Shortcut")
        window.contentView = stack
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.delegate = self
        window.center()
        self.window = window

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return nil
        }
    }

    private func handle(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if Int(event.keyCode) == kVK_Escape, mods.isEmpty {
            finish(nil)
            return
        }
        guard !mods.intersection([.command, .control, .option]).isEmpty else {
            message?.stringValue = L("Include ⌘, ⌃, or ⌥")
            return
        }
        let hotKey = HotKey(event: event)
        if hotKey.matches(.emergency) {
            message?.stringValue = L("%@ is reserved for the emergency shortcut", hotKey.label)
            return
        }
        finish(hotKey)
    }

    func windowWillClose(_ notification: Notification) {
        finish(nil)
    }

    private func finish(_ result: HotKey?) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if let window {
            window.delegate = nil
            window.close()
        }
        window = nil
        let completion = self.completion
        self.completion = nil
        completion?(result)
    }
}

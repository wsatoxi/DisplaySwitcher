import AppKit
import Carbon.HIToolbox

/// 画面右上に出る「表示先」の選択パネル
final class PickerController {
    private var panel: KeyPanel?
    private var rows: [PickerRow] = []
    private var modes: [DisplayMode] = []
    private var currentID: String?
    private var index = 0
    private var pressCount = 0
    /// 開いてから修飾キーを押し続けているか（離したら確定する ⌘Tab 型の操作）
    private var holding = false
    private var requiredFlags: CGEventFlags = []
    private var pollTimer: Timer?
    private var idleTimer: Timer?

    var isOpen: Bool { panel != nil }

    func hotKeyPressed(_ hotKey: HotKey) {
        if isOpen {
            pressCount += 1
            move(by: 1)
        } else {
            open(hotKey)
        }
        restartIdleTimer()
    }

    func close() {
        guard let panel else { return }
        self.panel = nil
        pollTimer?.invalidate()
        idleTimer?.invalidate()
        panel.orderOut(nil)
        rows = []
    }

    private func open(_ hotKey: HotKey) {
        let manager = DisplayManager.shared
        let displays = manager.displays()
        modes = manager.modes(for: displays)
        currentID = manager.currentModeID(displays, modes)
        index = modes.firstIndex { $0.id == currentID } ?? 0
        pressCount = 1
        holding = true
        requiredFlags = hotKey.cgFlags

        let panel = makeHUDPanel(content: buildContent(hotKey))
        panel.onKeyDown = { [weak self] event in self?.handleKey(event) ?? false }
        panel.onResignKey = { [weak self] in self?.close() }
        if let screen = mouseScreen() {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - panel.frame.width - 12, y: frame.maxY - panel.frame.height - 12))
        }
        self.panel = panel
        updateSelection()
        panel.makeKeyAndOrderFront(nil)

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            self?.pollModifiers()
        }
    }

    private func buildContent(_ hotKey: HotKey) -> NSView {
        var views: [NSView] = [makeLabel(L("Display Mode"), size: 12, weight: .semibold, color: .secondaryLabelColor)]
        rows = modes.enumerated().map { i, mode in
            let row = PickerRow(mode: mode, isCurrent: mode.id == currentID)
            row.onHover = { [weak self] in self?.select(i) }
            row.onClick = { [weak self] in self?.commit(i) }
            return row
        }
        if rows.isEmpty {
            views.append(makeLabel(L("Only one display is connected"), size: 13))
        }
        views += rows
        let hint = rows.isEmpty ? L("Esc to close") : L("%@ or ↑↓ to select · Return to apply · Esc to close", hotKey.label)
        let hintLabel = makeLabel(hint, size: 10.5, color: .tertiaryLabelColor)
        views.append(hintLabel)

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.setCustomSpacing(8, after: views[0])
        if let last = rows.last { stack.setCustomSpacing(8, after: last) }
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 8, bottom: 10, right: 8)
        stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        // 言語によって説明が長くなるので、右にも余白を残してパネルを広げる
        hintLabel.trailingAnchor.constraint(lessThanOrEqualTo: stack.trailingAnchor, constant: -10).isActive = true
        for row in rows {
            row.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -16).isActive = true
        }
        return stack
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case kVK_DownArrow: move(by: 1)
        case kVK_UpArrow: move(by: -1)
        case kVK_Return, kVK_ANSI_KeypadEnter: commit()
        case kVK_Escape: close()
        default: return false
        }
        restartIdleTimer()
        return true
    }

    private func pollModifiers() {
        guard holding else { pollTimer?.invalidate(); return }
        let flags = CGEventSource.flagsState(.combinedSessionState)
        if !flags.contains(requiredFlags) {
            holding = false
            // 1 回押して離しただけならパネルは開いたまま
            if pressCount >= 2 { commit() }
        }
    }

    private func move(by delta: Int) {
        guard !modes.isEmpty else { return }
        index = (index + delta + modes.count) % modes.count
        updateSelection()
    }

    private func select(_ i: Int) {
        index = i
        updateSelection()
        restartIdleTimer()
    }

    private func updateSelection() {
        for (i, row) in rows.enumerated() { row.isSelected = i == index }
    }

    private func commit(_ i: Int? = nil) {
        guard isOpen else { return }
        if let i { index = i }
        let mode = modes.indices.contains(index) ? modes[index] : nil
        close()
        if let mode, mode.id != currentID { Switcher.shared.switchTo(mode) }
    }

    private func restartIdleTimer() {
        idleTimer?.invalidate()
        guard isOpen else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in self?.close() }
    }
}

final class PickerRow: NSView {
    var onHover: (() -> Void)?
    var onClick: (() -> Void)?
    var isSelected = false { didSet { updateColors() } }

    private let icon: NSImageView
    private let title: NSTextField
    private let badge: NSTextField?

    init(mode: DisplayMode, isCurrent: Bool) {
        icon = NSImageView(image: NSImage(systemSymbolName: mode.symbol, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 15, weight: .regular)
        title = makeLabel(mode.title, size: 13)
        badge = isCurrent ? makeLabel(L("✓ Current"), size: 11) : nil
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 6
        translatesAutoresizingMaskIntoConstraints = false
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [icon, title] + (badge.map { [$0] } ?? []))
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 32),
            icon.widthAnchor.constraint(equalToConstant: 22),
        ])
        updateColors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseEntered(with event: NSEvent) { onHover?() }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) { onClick?() }

    private func updateColors() {
        layer?.backgroundColor = isSelected ? NSColor.controlAccentColor.cgColor : NSColor.clear.cgColor
        let text: NSColor = isSelected ? .white : .labelColor
        title.textColor = text
        icon.contentTintColor = text
        badge?.textColor = isSelected ? NSColor.white.withAlphaComponent(0.85) : .secondaryLabelColor
    }
}

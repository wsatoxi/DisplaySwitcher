import AppKit

func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
    NSScreen.screens.first {
        ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
    }
}

/// メニューバーがあるディスプレイ
func menuBarScreen() -> NSScreen? {
    screen(for: CGMainDisplayID()) ?? NSScreen.screens.first
}

/// マウスカーソルがあるディスプレイ
func mouseScreen() -> NSScreen? {
    let point = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? menuBarScreen()
}

func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular,
               color: NSColor = .labelColor) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: size, weight: weight)
    label.textColor = color
    label.lineBreakMode = .byTruncatingTail
    return label
}

/// アプリをアクティブにしなくてもキー入力を受け取れるパネル
final class KeyPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?
    var onResignKey: (() -> Void)?

    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        appearance = NSAppearance(named: .darkAqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true { super.keyDown(with: event) }
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

/// 半透明・角丸の背景にコンテンツを載せたパネルを作る
func makeHUDPanel(content: NSView, radius: CGFloat = 12) -> KeyPanel {
    content.translatesAutoresizingMaskIntoConstraints = false
    let size = content.fittingSize
    let panel = KeyPanel(size: size)

    let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
    background.material = .hudWindow
    background.blendingMode = .behindWindow
    background.state = .active
    background.maskImage = NSImage(size: size, flipped: false) { rect in
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        return true
    }
    background.addSubview(content)
    NSLayoutConstraint.activate([
        content.leadingAnchor.constraint(equalTo: background.leadingAnchor),
        content.trailingAnchor.constraint(equalTo: background.trailingAnchor),
        content.topAnchor.constraint(equalTo: background.topAnchor),
        content.bottomAnchor.constraint(equalTo: background.bottomAnchor),
    ])
    panel.contentView = background
    return panel
}

/// 切り替え結果を短く知らせる
enum Toast {
    private static var current: NSPanel?

    static func show(_ text: String, symbol: String?) {
        current?.orderOut(nil)
        guard let screen = menuBarScreen() else { return }

        var views: [NSView] = []
        if let symbol, let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let icon = NSImageView(image: image)
            icon.symbolConfiguration = .init(pointSize: 16, weight: .medium)
            icon.contentTintColor = .labelColor
            views.append(icon)
        }
        views.append(makeLabel(text, size: 14, weight: .medium))
        let stack = NSStackView(views: views)
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 18, bottom: 12, right: 18)

        let panel = makeHUDPanel(content: stack)
        panel.ignoresMouseEvents = true
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.maxY - panel.frame.height - 48))
        panel.orderFrontRegardless()
        current = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
                if current === panel { current = nil }
            })
        }
    }
}

/// 「この表示を維持しますか？」パネル。時間内に維持を選ばなければ元に戻す
final class ConfirmPanel: NSObject {
    private let panel: KeyPanel
    private let detail: NSTextField
    private var remaining: Int
    private var timer: Timer?
    private var finished = false
    private let onKeep: () -> Void
    private let onRevert: () -> Void

    static func show(title: String, seconds: Int, onKeep: @escaping () -> Void,
                     onRevert: @escaping () -> Void) -> ConfirmPanel {
        let confirm = ConfirmPanel(title: title, seconds: seconds, onKeep: onKeep, onRevert: onRevert)
        confirm.present()
        return confirm
    }

    private init(title: String, seconds: Int, onKeep: @escaping () -> Void, onRevert: @escaping () -> Void) {
        remaining = seconds
        self.onKeep = onKeep
        self.onRevert = onRevert

        let titleLabel = makeLabel(title, size: 15, weight: .semibold)
        detail = makeLabel("", size: 12, color: .secondaryLabelColor)
        let revert = NSButton(title: L("Revert"), target: nil, action: nil)
        revert.keyEquivalent = "\u{1b}"
        let keep = NSButton(title: L("Keep"), target: nil, action: nil)
        keep.keyEquivalent = "\r"
        let buttons = NSStackView(views: [revert, keep])
        buttons.spacing = 12

        let stack = NSStackView(views: [titleLabel, detail, buttons])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(16, after: detail)
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 18, right: 24)
        stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 340).isActive = true
        panel = makeHUDPanel(content: stack, radius: 14)
        super.init()

        revert.target = self
        revert.action = #selector(revertPressed)
        keep.target = self
        keep.action = #selector(keepPressed)
        updateDetail()
    }

    private func present() {
        if let screen = menuBarScreen() {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2,
                                         y: frame.midY - panel.frame.height / 2 + frame.height * 0.15))
        }
        panel.makeKeyAndOrderFront(nil)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.remaining -= 1
            if self.remaining <= 0 { self.revertPressed() } else { self.updateDetail() }
        }
    }

    private func updateDetail() {
        detail.stringValue = L("Reverting in %ld seconds", remaining)
    }

    @objc private func keepPressed() {
        guard finish() else { return }
        onKeep()
    }

    @objc private func revertPressed() {
        guard finish() else { return }
        onRevert()
    }

    /// 何もせずに閉じる
    func dismiss() {
        finish()
    }

    @discardableResult
    private func finish() -> Bool {
        guard !finished else { return false }
        finished = true
        timer?.invalidate()
        panel.orderOut(nil)
        return true
    }
}

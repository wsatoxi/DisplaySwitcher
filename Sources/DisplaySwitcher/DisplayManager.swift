import AppKit
import CoreGraphics

struct DisplayInfo {
    let id: CGDirectDisplayID
    let key: String
    let name: String
    let isBuiltin: Bool
    /// false = このアプリが無効にしている
    let isEnabled: Bool
}

struct DisplayMode {
    let id: String
    let title: String
    let symbol: String
    /// 有効にするディスプレイ。先頭がメイン
    let enabledKeys: [String]
    let mirror: Bool
}

enum DisplayError: LocalizedError {
    case unsupported
    case cg(String, CGError)
    case timeout(String)
    case missingDisplay

    var errorDescription: String? {
        switch self {
        case .unsupported: return L("Displays can't be turned off on this version of macOS")
        case let .cg(step, err): return L("%@ failed (CGError %d)", L(step), err.rawValue)
        case let .timeout(step): return L("%@ did not finish in time", L(step))
        case .missingDisplay: return L("The display could not be found")
        }
    }
}

final class DisplayManager {
    static let shared = DisplayManager()

    private typealias EnableFn = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError

    /// 非公開 API。macOS のアップデートで消えることがあるので、実行時に探す
    private let enableFn: EnableFn? = {
        guard let handle = dlopen(nil, RTLD_NOW),
              let sym = dlsym(handle, "CGSConfigureDisplayEnabled") else { return nil }
        return unsafeBitCast(sym, to: EnableFn.self)
    }()

    private let store = Store.shared

    // MARK: - 一覧

    static func key(of id: CGDirectDisplayID) -> String {
        if CGDisplayIsBuiltin(id) != 0 { return "builtin" }
        return "\(CGDisplayVendorNumber(id))-\(CGDisplayModelNumber(id))-\(CGDisplaySerialNumber(id))"
    }

    func onlineIDs() -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    /// 接続中のディスプレイ（このアプリが無効にしたものを含む）
    func displays() -> [DisplayInfo] {
        if Thread.isMainThread { refreshNames() }
        let online = onlineIDs()
        var result = online.map { id -> DisplayInfo in
            let key = Self.key(of: id)
            let builtin = CGDisplayIsBuiltin(id) != 0
            return DisplayInfo(id: id, key: key, name: name(for: key, builtin: builtin), isBuiltin: builtin, isEnabled: true)
        }

        // 別の手段で有効に戻ったものは記録から外す
        var disabled = store.disabled
        let onlineKeys = Set(result.map(\.key))
        let stale = disabled.filter { online.contains($0.key) || onlineKeys.contains($0.value) }.map(\.key)
        if !stale.isEmpty {
            stale.forEach { disabled[$0] = nil }
            store.disabled = disabled
        }

        for (id, key) in disabled.sorted(by: { $0.key < $1.key }) {
            let builtin = key == "builtin"
            result.append(DisplayInfo(id: id, key: key, name: name(for: key, builtin: builtin), isBuiltin: builtin, isEnabled: false))
        }
        return result
    }

    private func refreshNames() {
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            store.setName(screen.localizedName, for: Self.key(of: number.uint32Value))
        }
    }

    private func name(for key: String, builtin: Bool) -> String {
        store.name(for: key) ?? (builtin ? L("Built-in Display") : L("External Display"))
    }

    // MARK: - 構成とモード

    func setKey(_ displays: [DisplayInfo]) -> String {
        setKey(displays.map(\.key))
    }

    private func setKey(_ keys: [String]) -> String {
        keys.sorted().joined(separator: ",")
    }

    func isMirrored(_ display: DisplayInfo) -> Bool {
        display.isEnabled && CGDisplayIsInMirrorSet(display.id) != 0
    }

    /// すべて有効で、複製もしていない
    func isExtendedAll(_ displays: [DisplayInfo]) -> Bool {
        displays.allSatisfy(\.isEnabled) && !displays.contains(where: isMirrored)
    }

    /// 拡張モードでメニューバーがあるディスプレイ
    func mainKey(_ displays: [DisplayInfo]) -> String {
        if let key = store.mainKey(for: setKey(displays)), displays.contains(where: { $0.key == key }) { return key }
        if isExtendedAll(displays) { return Self.key(of: CGMainDisplayID()) }
        return displays.first(where: \.isBuiltin)?.key ?? displays[0].key
    }

    func modes(for displays: [DisplayInfo]) -> [DisplayMode] {
        guard displays.count >= 2 else { return [] }
        let main = mainKey(displays)
        let arrangement = store.arrangement(for: setKey(displays)) ?? [:]
        let others = displays.filter { $0.key != main }.sorted {
            (arrangement[$0.key]?.x ?? 0, $0.key) < (arrangement[$1.key]?.x ?? 0, $1.key)
        }
        let ordered = displays.filter { $0.key == main } + others
        let all = ordered.map(\.key)
        let three = displays.count >= 3

        var externals = ordered.filter { !$0.isBuiltin }
        // 外部だけの構成（クラムシェル）で覚えたメインを優先する
        if let key = store.mainKey(for: setKey(externals.map(\.key))),
           let i = externals.firstIndex(where: { $0.key == key }) {
            externals.insert(externals.remove(at: i), at: 0)
        }

        var modes = [DisplayMode(id: "extend", title: three ? L("Extend All") : L("Extend"),
                                 symbol: three ? "rectangle.split.3x1" : "rectangle.split.2x1",
                                 enabledKeys: all, mirror: false)]
        if three, displays.contains(where: \.isBuiltin), externals.count >= 2 {
            modes.append(DisplayMode(id: "externals", title: L("External Displays Only"), symbol: "display.2",
                                     enabledKeys: externals.map(\.key), mirror: false))
        }
        // 3 台以上なら、外部ディスプレイを 1 台だけ消すモード（そのディスプレイだけ PC などに渡す）
        if three {
            for d in externals {
                var rest = ordered.filter { $0.key != d.key }
                // 残りの組み合わせで覚えたメインを優先する
                if let key = store.mainKey(for: setKey(rest.map(\.key))), let i = rest.firstIndex(where: { $0.key == key }) {
                    rest.insert(rest.remove(at: i), at: 0)
                }
                modes.append(DisplayMode(id: "off:\(d.key)", title: L("Turn Off %@", d.name), symbol: "rectangle.split.2x1",
                                         enabledKeys: rest.map(\.key), mirror: false))
            }
        }
        let singles = three ? ordered.filter(\.isBuiltin) + externals : ordered
        for d in singles {
            modes.append(DisplayMode(id: "only:\(d.key)", title: L("%@ Only", d.name),
                                     symbol: d.isBuiltin ? "laptopcomputer" : "display",
                                     enabledKeys: [d.key], mirror: false))
        }
        modes.append(DisplayMode(id: "mirror", title: three ? L("Mirror All") : L("Mirror"), symbol: "rectangle.on.rectangle",
                                 enabledKeys: all, mirror: true))
        return modes
    }

    func currentModeID(_ displays: [DisplayInfo], _ modes: [DisplayMode]) -> String? {
        let enabled = Set(displays.filter(\.isEnabled).map(\.key))
        let mirrored = displays.contains(where: isMirrored)
        return modes.first { Set($0.enabledKeys) == enabled && $0.mirror == mirrored }?.id
    }

    /// 今の解像度を覚える。複製中は解像度が変わっているので覚えない
    func rememberModes(_ displays: [DisplayInfo]) {
        for d in displays where d.isEnabled && !isMirrored(d) {
            guard let mode = CGDisplayCopyDisplayMode(d.id) else { continue }
            store.setDisplayMode(SavedDisplayMode(mode), for: d.key)
        }
    }

    /// すべて拡張の状態なら、メインと配置を覚える（拡張に戻すときに使う）
    func rememberLayoutIfExtended(_ displays: [DisplayInfo]) {
        guard displays.count >= 2, isExtendedAll(displays) else { return }
        rememberModes(displays)
        let set = setKey(displays)
        store.setMainKey(Self.key(of: CGMainDisplayID()), for: set)
        let origins = Dictionary(displays.map { ($0.key, CGDisplayBounds($0.id).origin) }, uniquingKeysWith: { a, _ in a })
        store.setArrangement(origins, for: set)
    }

    // MARK: - 切り替え

    /// モードを適用する。数秒かかるのでメインスレッド以外から呼ぶ
    func apply(_ mode: DisplayMode) throws {
        var displays = self.displays()
        rememberLayoutIfExtended(displays)
        let set = setKey(displays)
        let wanted = Set(mode.enabledKeys)

        // 1. 必要なディスプレイを有効にする
        let toEnable = displays.filter { !$0.isEnabled && wanted.contains($0.key) }
        if !toEnable.isEmpty {
            try configure("Enabling displays") { config in
                for d in toEnable { try setEnabled(config, d.id, true) }
            }
            store.removeDisabled(toEnable.map(\.id))
            guard wait({ toEnable.allSatisfy { self.onlineIDs().contains($0.id) } }) else {
                throw DisplayError.timeout("Enabling displays")
            }
            displays = self.displays()
        }

        // 2. 複製を解除する
        let mirrored = displays.filter(isMirrored)
        if !mirrored.isEmpty {
            try configure("Turning off mirroring") { config in
                for d in mirrored {
                    try check(CGConfigureDisplayMirrorOfDisplay(config, d.id, kCGNullDirectDisplay), "Turning off mirroring")
                }
            }
            _ = wait { !displays.contains(where: self.isMirrored) }
        }

        // 3. 不要なディスプレイを無効にする（必ず 1 台以上は残る）
        let toDisable = displays.filter { $0.isEnabled && !wanted.contains($0.key) }
        guard toDisable.count < displays.filter(\.isEnabled).count else { throw DisplayError.missingDisplay }
        if !toDisable.isEmpty {
            // 途中でアプリが落ちても戻せるよう、先に記録する
            store.addDisabled(toDisable)
            do {
                try configure("Disabling displays") { config in
                    for d in toDisable { try setEnabled(config, d.id, false) }
                }
            } catch {
                store.removeDisabled(toDisable.map(\.id))
                throw error
            }
            guard wait({ toDisable.allSatisfy { !self.onlineIDs().contains($0.id) } }) else {
                throw DisplayError.timeout("Disabling displays")
            }
        }

        // 4. 解像度、配置、または複製
        let targets = mode.enabledKeys.compactMap { key in displays.first { $0.key == key } }
        guard targets.count == mode.enabledKeys.count else { throw DisplayError.missingDisplay }
        if !mode.mirror {
            // 戻せなくても表示はされているので、切り替え自体は続ける
            try? restoreModes(targets)
        }
        if targets.count > 1 {
            let main = targets[0]
            try configure(mode.mirror ? "Mirroring" : "Restoring the arrangement") { config in
                if mode.mirror {
                    for t in targets.dropFirst() {
                        try check(CGConfigureDisplayMirrorOfDisplay(config, t.id, main.id), "Mirroring")
                    }
                } else {
                    let saved = store.arrangement(for: setKey(targets.map(\.key))) ?? store.arrangement(for: set) ?? [:]
                    let base = saved[main.key] ?? CGDisplayBounds(main.id).origin
                    for t in targets {
                        let p = saved[t.key] ?? CGDisplayBounds(t.id).origin
                        try check(CGConfigureDisplayOrigin(config, t.id, Int32(p.x - base.x), Int32(p.y - base.y)), "Restoring the arrangement")
                    }
                }
            }
        }

        // 5. 点くはずのディスプレイが点いているか確かめる
        let ok = wait {
            let online = self.onlineIDs()
            let active = online.filter { CGDisplayIsActive($0) != 0 }
            return !active.isEmpty && targets.allSatisfy { online.contains($0.id) }
                && (!mode.mirror || targets.dropFirst().allSatisfy { CGDisplayMirrorsDisplay($0.id) != kCGNullDirectDisplay })
        }
        guard ok else { throw DisplayError.timeout("Checking the result") }
        Thread.sleep(forTimeInterval: 0.3)
    }

    /// すべてのディスプレイを有効にして拡張に戻す。失敗しても、できるところまで進める
    func restoreAll() {
        let disabled = store.disabled
        if !disabled.isEmpty {
            do {
                try configure("Enabling displays") { config in
                    for id in disabled.keys { try setEnabled(config, id, true) }
                }
            } catch {
                // まとめて失敗したら 1 台ずつ試す（抜かれたディスプレイが混ざっている場合など）
                for id in disabled.keys {
                    try? configure("Enabling displays") { try setEnabled($0, id, true) }
                }
            }
            store.disabled = [:]
            _ = wait { disabled.keys.allSatisfy { self.onlineIDs().contains($0) } }
        }
        let displays = self.displays()
        guard displays.count >= 2, let extend = modes(for: displays).first(where: { $0.id == "extend" }) else { return }
        try? apply(extend)
    }

    /// 覚えておいた解像度に戻す
    private func restoreModes(_ targets: [DisplayInfo]) throws {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        let changes: [(CGDirectDisplayID, CGDisplayMode)] = targets.compactMap { t in
            guard let saved = store.displayMode(for: t.key),
                  let current = CGDisplayCopyDisplayMode(t.id), !saved.matches(current) else { return nil }
            let modes = CGDisplayCopyAllDisplayModes(t.id, options) as? [CGDisplayMode] ?? []
            return modes.first(where: saved.matches).map { (t.id, $0) }
        }
        guard !changes.isEmpty else { return }
        try configure("Restoring the resolution") { config in
            for (id, mode) in changes {
                try check(CGConfigureDisplayWithDisplayMode(config, id, mode, nil), "Restoring the resolution")
            }
        }
        _ = wait {
            changes.allSatisfy { id, mode in
                CGDisplayCopyDisplayMode(id).map { $0.width == mode.width && $0.pixelWidth == mode.pixelWidth } ?? false
            }
        }
    }

    // MARK: - CoreGraphics の補助

    private func configure(_ step: String, _ body: (CGDisplayConfigRef) throws -> Void) throws {
        var ref: CGDisplayConfigRef?
        let begin = CGBeginDisplayConfiguration(&ref)
        guard begin == .success, let config = ref else { throw DisplayError.cg(step, begin) }
        do {
            try body(config)
        } catch {
            CGCancelDisplayConfiguration(config)
            throw error
        }
        // ログアウトで元に戻る設定にする（万一のときの最後の逃げ道）
        let done = CGCompleteDisplayConfiguration(config, .forSession)
        guard done == .success else { throw DisplayError.cg(step, done) }
    }

    private func check(_ err: CGError, _ step: String) throws {
        if err != .success { throw DisplayError.cg(step, err) }
    }

    private func setEnabled(_ config: CGDisplayConfigRef, _ id: CGDirectDisplayID, _ enabled: Bool) throws {
        guard let enableFn else { throw DisplayError.unsupported }
        try check(enableFn(config, id, enabled), enabled ? "Enabling displays" : "Disabling displays")
    }

    private func wait(timeout: TimeInterval = 4, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }
}

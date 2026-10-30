import CoreGraphics
import Foundation

struct SavedDisplayMode {
    let width: Int
    let height: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let refreshRate: Double

    init(width: Int, height: Int, pixelWidth: Int, pixelHeight: Int, refreshRate: Double) {
        self.width = width
        self.height = height
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.refreshRate = refreshRate
    }

    init(_ mode: CGDisplayMode) {
        self.init(width: mode.width, height: mode.height, pixelWidth: mode.pixelWidth,
                  pixelHeight: mode.pixelHeight, refreshRate: mode.refreshRate)
    }

    func matches(_ mode: CGDisplayMode) -> Bool {
        mode.width == width && mode.height == height && mode.pixelWidth == pixelWidth
            && mode.pixelHeight == pixelHeight && abs(mode.refreshRate - refreshRate) < 0.5
    }
}

/// UserDefaults に保存する設定と状態
final class Store {
    static let shared = Store()
    private let defaults = UserDefaults.standard

    // MARK: - 無効化中のディスプレイ（Display ID → ディスプレイのキー）

    /// 無効にしたディスプレイは macOS の一覧から消えるので、戻すために自分で覚えておく
    var disabled: [CGDirectDisplayID: String] {
        get {
            let raw = defaults.dictionary(forKey: "disabledDisplays") as? [String: String] ?? [:]
            return raw.reduce(into: [:]) { result, item in
                if let id = UInt32(item.key) { result[id] = item.value }
            }
        }
        set {
            let raw = Dictionary(uniqueKeysWithValues: newValue.map { (String($0.key), $0.value) })
            defaults.set(raw, forKey: "disabledDisplays")
        }
    }

    func addDisabled(_ displays: [DisplayInfo]) {
        var map = disabled
        for d in displays { map[d.id] = d.key }
        disabled = map
    }

    func removeDisabled(_ ids: [CGDirectDisplayID]) {
        var map = disabled
        for id in ids { map[id] = nil }
        disabled = map
    }

    // MARK: - ディスプレイ名（無効中は macOS から名前を取れないので覚えておく）

    func name(for key: String) -> String? {
        (defaults.dictionary(forKey: "displayNames") as? [String: String])?[key]
    }

    func setName(_ name: String, for key: String) {
        var names = defaults.dictionary(forKey: "displayNames") as? [String: String] ?? [:]
        guard names[key] != name else { return }
        names[key] = name
        defaults.set(names, forKey: "displayNames")
    }

    // MARK: - 構成ごとのメインと配置

    func mainKey(for set: String) -> String? {
        (defaults.dictionary(forKey: "mainDisplays") as? [String: String])?[set]
    }

    func setMainKey(_ key: String, for set: String) {
        var mains = defaults.dictionary(forKey: "mainDisplays") as? [String: String] ?? [:]
        guard mains[set] != key else { return }
        mains[set] = key
        defaults.set(mains, forKey: "mainDisplays")
    }

    func arrangement(for set: String) -> [String: CGPoint]? {
        guard let all = defaults.dictionary(forKey: "arrangements") as? [String: [String: [Double]]],
              let raw = all[set] else { return nil }
        return raw.compactMapValues { $0.count == 2 ? CGPoint(x: $0[0], y: $0[1]) : nil }
    }

    func setArrangement(_ origins: [String: CGPoint], for set: String) {
        var all = defaults.dictionary(forKey: "arrangements") as? [String: [String: [Double]]] ?? [:]
        let raw = origins.mapValues { [Double($0.x), Double($0.y)] }
        guard all[set] != raw else { return }
        all[set] = raw
        defaults.set(all, forKey: "arrangements")
    }

    // MARK: - ディスプレイごとの解像度（無効から戻すと macOS の既定の解像度になるため）

    func displayMode(for key: String) -> SavedDisplayMode? {
        guard let all = defaults.dictionary(forKey: "displayModes") as? [String: [Double]],
              let raw = all[key], raw.count == 5 else { return nil }
        return SavedDisplayMode(width: Int(raw[0]), height: Int(raw[1]), pixelWidth: Int(raw[2]),
                                pixelHeight: Int(raw[3]), refreshRate: raw[4])
    }

    func setDisplayMode(_ mode: SavedDisplayMode, for key: String) {
        var all = defaults.dictionary(forKey: "displayModes") as? [String: [Double]] ?? [:]
        let raw = [Double(mode.width), Double(mode.height), Double(mode.pixelWidth), Double(mode.pixelHeight), mode.refreshRate]
        guard all[key] != raw else { return }
        all[key] = raw
        defaults.set(all, forKey: "displayModes")
    }

    // MARK: - 確認済みのモード（構成|モード）

    func isConfirmed(_ key: String) -> Bool {
        (defaults.stringArray(forKey: "confirmedModes") ?? []).contains(key)
    }

    func markConfirmed(_ key: String) {
        var list = defaults.stringArray(forKey: "confirmedModes") ?? []
        guard !list.contains(key) else { return }
        list.append(key)
        defaults.set(list, forKey: "confirmedModes")
    }

    // MARK: - ショートカット

    var hotKey: HotKey {
        get {
            guard let raw = defaults.dictionary(forKey: "hotKey"),
                  let code = raw["keyCode"] as? Int,
                  let mods = raw["modifiers"] as? Int,
                  let key = raw["key"] as? String else { return .default }
            return HotKey(keyCode: UInt32(code), modifiers: UInt32(mods), key: key)
        }
        set {
            defaults.set(["keyCode": Int(newValue.keyCode), "modifiers": Int(newValue.modifiers), "key": newValue.key],
                         forKey: "hotKey")
        }
    }

    /// ログイン時に起動するか（ユーザーの希望。初期設定は ON）
    var launchAtLogin: Bool {
        get { defaults.object(forKey: "launchAtLogin") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }
}

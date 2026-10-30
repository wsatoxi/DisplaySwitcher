import AppKit

/// 動作確認用のコマンド。アプリ本体と同じ設定を使う
enum CLI {
    static func run(_ args: [String]) -> Int32 {
        _ = NSApplication.shared
        let manager = DisplayManager.shared

        switch args[0] {
        case "list":
            printStatus()
            return 0

        case "apply":
            guard args.count >= 2 else { return usage() }
            let modes = manager.modes(for: manager.displays())
            let mode = Int(args[1]).flatMap { modes.indices.contains($0 - 1) ? modes[$0 - 1] : nil }
                ?? modes.first { $0.id == args[1] }
            guard let mode else {
                print(L("Mode not found: %@", args[1]))
                return 1
            }
            do {
                try manager.apply(mode)
                print(L("Switched to: %@", mode.title) + "\n")
                printStatus()
                return 0
            } catch {
                print(L("Failed: %@. Restoring all displays.", error.localizedDescription))
                manager.restoreAll()
                return 1
            }

        case "restore":
            manager.restoreAll()
            printStatus()
            return 0

        case "show-picker":
            DistributedNotificationCenter.default().postNotificationName(showPickerNotification, object: nil,
                                                                         userInfo: nil, deliverImmediately: true)
            return 0

        case "switch":
            guard args.count >= 2 else { return usage() }
            DistributedNotificationCenter.default().postNotificationName(switchModeNotification, object: args[1],
                                                                         userInfo: nil, deliverImmediately: true)
            return 0

        default:
            return usage()
        }
    }

    private static func printStatus() {
        let manager = DisplayManager.shared
        let displays = manager.displays()
        print(L("Displays:"))
        for d in displays {
            let bounds = CGDisplayBounds(d.id)
            var tags: [String] = []
            if !d.isEnabled { tags.append(L("off")) }
            if d.isEnabled && CGDisplayIsMain(d.id) != 0 { tags.append(L("menu bar")) }
            if manager.isMirrored(d) { tags.append(L("mirrored")) }
            print("  [\(d.id)] \(d.name)  key=\(d.key)  origin=(\(Int(bounds.minX)), \(Int(bounds.minY)))  \(tags.joined(separator: " "))")
        }
        let modes = manager.modes(for: displays)
        let current = manager.currentModeID(displays, modes)
        print(L("Modes:"))
        if modes.isEmpty { print("  " + L("(only one display)")) }
        for (i, mode) in modes.enumerated() {
            print("  \(mode.id == current ? "*" : " ") \(i + 1). \(mode.title)  (\(mode.id))")
        }
    }

    private static func usage() -> Int32 {
        print(L("""
        Usage: DisplaySwitcher <command>
          list                Show displays and available modes
          apply <number|ID>   Switch to a mode
          restore             Show all displays (extend)
          show-picker         Open the picker in the running app
          switch <number|ID>  Switch modes in the running app (with confirmation)
        """))
        return 2
    }
}

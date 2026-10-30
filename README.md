# Display Switcher

[English](README.md) | [日本語](README.ja.md)

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform: macOS 14+](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)

A menu bar app for macOS that switches display modes — **Extend**, **&lt;display&gt; Only**, **Mirror** — from a single keyboard shortcut, much like **Win+P** on Windows.

Press **⌃⌘P** and a panel appears at the top right of the screen. Pick a mode and you're done.

## Features

- **One shortcut, every mode.** Choices are built automatically from the displays that are connected (1–3 displays).
- **Turn off one display.** "Turn Off &lt;display&gt;" disables just that one and extends across the rest — handy when you share a monitor with another PC.
- **Remembers resolutions** per display and restores them after each switch.
- **Hard to lock yourself out.** At least one display always stays on, new modes ask "Keep?" and roll back after 15 seconds, and **⌃⌥⌘P** brings every display back.
- **⌘Tab-style switching.** Hold ⌃⌘, tap P to cycle, release to apply.
- **Localized** in English, Japanese, Simplified Chinese, Traditional Chinese, Korean, German, French and Spanish.
- **Universal binary** for Apple silicon and Intel.

## Requirements

- macOS 14 Sonoma or later
- Apple silicon or Intel Mac

## Installation

1. Download `DisplaySwitcher-<version>.dmg` from [Releases](../../releases/latest).
2. Open the DMG and drag **Display Switcher** onto **Applications**.
3. Open Display Switcher from the Applications folder. "Open at Login" is turned on the first time it runs.

> [!NOTE]
> The app is not notarized by Apple yet, so macOS says it "cannot be opened" the first time.
> Go to **System Settings › Privacy & Security**, scroll down, and click **Open Anyway**.
> The same steps are in `Read Me.txt` inside the DMG.

## Usage

| Action | Result |
|---|---|
| Press and release **⌃⌘P** | Opens the Display Mode panel (it stays open) |
| ⌃⌘P or ↑↓ while the panel is open | Moves the selection |
| Return or click | Switches to that mode |
| Hold ⌃⌘, press P two or more times, release | Switches to the selected mode when you let go |
| Esc, click outside, or wait 10 seconds | Closes without changing anything |
| **⌃⌥⌘P** | Emergency: shows every display again (Extend) |

The menu bar icon (two displays) also lets you switch modes, change the shortcut, toggle "Open at Login", and quit.

### Available modes

| Displays | Modes |
|---|---|
| 1 | None ("Only one display is connected") |
| 2 | Extend / &lt;A&gt; Only / &lt;B&gt; Only / Mirror |
| 3 (lid open + 2 external) | Extend All / External Displays Only / Turn Off &lt;A&gt; / Turn Off &lt;B&gt; / Built-in Display Only / &lt;A&gt; Only / &lt;B&gt; Only / Mirror All |

Display names come from macOS (for example "DELL P2721Q").

"Turn Off &lt;display&gt;" is meant for sharing a monitor with another computer: set the monitor's input to Auto, and it switches to the other computer as soon as the Mac stops sending a signal.

## Safety

- Every mode keeps at least one display on.
- The first time you use a mode, a "Keep?" panel appears. If you don't press **Keep** (Return) within 15 seconds, the previous setup comes back.
- Disabled displays are turned back on automatically when:
  - displays are plugged or unplugged, the lid is opened or closed, or the Mac wakes from sleep
  - the app quits, and the next time it starts
- If a screen still goes dark:
  1. Press **⌃⌥⌘P**.
  2. If that doesn't help, log out or restart. Disabling a display only lasts for the current login session.

## Command line

Mainly for testing.

```bash
"/Applications/Display Switcher.app/Contents/MacOS/DisplaySwitcher" list
```

| Command | Description |
|---|---|
| `list` | Lists displays and available modes (`*` marks the current one) |
| `apply <number\|ID>` | Switches immediately (no confirmation panel) |
| `restore` | Shows every display again (Extend) |
| `show-picker` | Opens the panel in the running app |
| `switch <number\|ID>` | Switches through the running app (with confirmation panel) |

## Uninstall

1. Menu bar icon › turn off **Open at Login**.
2. Menu bar icon › **Quit Display Switcher**.
3. Move Display Switcher from the Applications folder to the Trash.

To remove its settings as well:

```bash
defaults delete io.github.satoxiw-k.DisplaySwitcher
```

## Building from source

Xcode is not required — the Swift toolchain from the Command Line Tools is enough.

```bash
xcode-select --install   # if the Command Line Tools are not installed yet
make install             # build, copy to /Applications, and launch
```

| Command | Description |
|---|---|
| `make install` | Builds, installs to `/Applications`, and launches (replaces a running copy) |
| `make dmg` | Builds the distributable `dist/DisplaySwitcher-<version>.dmg` |
| `make notarize SIGN_IDENTITY="…"` | Signs with a Developer ID and notarizes the DMG |
| `make icon` | Regenerates `Resources/AppIcon.icns` from `scripts/make_icon.swift` |
| `make uninstall` | Quits the app and removes it from `/Applications` |
| `make clean` | Removes build output |

See the [Japanese README](README.ja.md#ビルド開発する人向け) for details on releasing, signing and notarization, and translations.

### Project layout

```
Sources/DisplaySwitcher/   App source (Swift, AppKit)
Resources/                 Info.plist, icon, translations (*.lproj), DMG guides
scripts/                   Icon, DMG background, and DMG build scripts
```

## Caveats

- Disabling a display ("&lt;display&gt; Only", "Turn Off &lt;display&gt;") relies on a private macOS API (`CGSConfigureDisplayEnabled`). A future macOS update may break it. Extend and Mirror use public APIs and will keep working.
- After rebuilding, the code signature changes, so you may need to re-register the login item.

## Contributing

Issues and pull requests are welcome. When you add or change user-facing text, add the same key to every `Resources/<language>.lproj/Localizable.strings`.

## License

[MIT](LICENSE) © 2026 Satoshi Watanabe

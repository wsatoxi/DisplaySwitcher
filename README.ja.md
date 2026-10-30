# Display Switcher

[English](README.md) | [日本語](README.ja.md)

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform: macOS 14+](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)

ショートカット 1 つでディスプレイの表示モード（拡張／〇〇のみ／複製）を切り替える、macOS のメニューバー常駐アプリです。Windows の **Win+P** に近い操作です。

**⌃⌘P** を押すと画面右上に「表示先」パネルが出るので、モードを選ぶだけです。

## 特長

- **ショートカット 1 つで全モード。** 選べるモードは、つないでいるディスプレイ（1〜3 台）から自動で作ります。
- **1 台だけオフ。** 「〇〇をオフ」は、その 1 台だけを消して残りで拡張します。ほかの PC とディスプレイを共有しているときに便利です。
- **解像度を覚える。** ディスプレイごとに解像度を覚えていて、切り替えたあとに戻します。
- **画面が映らなくなりにくい。** 必ず 1 台は表示したまま。初めてのモードは「維持しますか？」で確認し、15 秒で元に戻ります。**⌃⌥⌘P** ですべてのディスプレイを戻せます。
- **⌘Tab 風の切り替え。** ⌃⌘ を押したまま P で選び、離すと切り替わります。
- **8 言語対応。** 英語・日本語・中国語（簡体字／繁体字）・韓国語・ドイツ語・フランス語・スペイン語。Mac の言語設定に合わせて切り替わり、それ以外の言語では英語で表示します。
- **ユニバーサルバイナリ。** Apple シリコンと Intel の両方で動きます。

## 動作環境

- macOS 14 Sonoma 以降
- Apple シリコン / Intel の Mac

## インストール

### Homebrew

```bash
brew install wsatoxi/tap/display-switcher
```

### 手動

1. [Releases](../../releases/latest) から `DisplaySwitcher-<バージョン>.dmg` をダウンロードします。
2. DMG を開き、`Display Switcher` を右の `Applications` にドラッグします。
3. 「アプリケーション」から開きます。初回起動時に「ログイン時に起動」が ON になります。

> [!NOTE]
> 今は Apple の公証を受けていないので、初めて開くときに「開けません」と表示されます。
> その場合は、**システム設定 › プライバシーとセキュリティ** の下の方にある **このまま開く** を押してください。
> 手順は DMG に入っている「はじめにお読みください.txt」にも書いてあります。

## 使い方

| 操作 | 動作 |
|---|---|
| **⌃⌘P**（Control＋Command＋P）を押して離す | 表示先パネルが開く（開いたまま） |
| パネルが開いた状態で ⌃⌘P／↑↓ | 選択を移動 |
| Enter／クリック | 切り替える |
| ⌃⌘ を押したまま P を 2 回以上押して離す | 離した時点で選択中のモードに切り替える（⌘Tab と同じ） |
| Esc／パネルの外をクリック／10 秒放置 | 何もせずに閉じる |
| **⌃⌥⌘P**（Control＋Option＋Command＋P） | 緊急用。すべてのディスプレイを表示（拡張）に戻す |

メニューバーのアイコン（ディスプレイ 2 枚の絵）からも切り替えられます。ショートカットの変更、ログイン時に起動の ON/OFF、終了もここから行います。

システム設定で解像度を変えると、変えたあとの解像度を覚えます。

### 選べるモード

| 台数 | モード |
|---|---|
| 1 台 | なし（「表示先は 1 台だけです」） |
| 2 台 | 拡張／メインのみ／サブのみ／複製 |
| 3 台（蓋を開けて外部 2 台） | すべて拡張／外部ディスプレイのみ／外部 A をオフ／外部 B をオフ／内蔵のみ／外部 A のみ／外部 B のみ／すべて複製 |

「〇〇をオフ」は、ほかの PC とディスプレイを共有しているとき、1 台だけ PC 側に渡す用途向けです（ディスプレイの入力切り替えを Auto にしておくと、Mac の信号が消えた時点で PC 側の表示になります）。

## 安全装置

- どのモードでも、必ず 1 台以上は表示したままにします。
- 初めて使うモードでは「維持しますか？」パネルが出ます。15 秒以内に「維持する」（Enter）を押さないと、元の表示に戻ります。
- 次のときは、無効にしたディスプレイを自動で戻します。
  - ディスプレイの抜き差し、蓋の開け閉め、スリープからの復帰で構成が変わったとき
  - アプリを終了したとき、次に起動したとき
- どうしても画面が映らなくなったら:
  1. **⌃⌥⌘P** を押す
  2. それでもだめなら、ログアウトするか再起動する（無効化はログインしている間だけ有効なので、元に戻ります）

## コマンドライン（動作確認用）

```bash
"/Applications/Display Switcher.app/Contents/MacOS/DisplaySwitcher" list
```

| コマンド | 動作 |
|---|---|
| `list` | ディスプレイと選べるモードを表示（`*` が今のモード） |
| `apply <番号\|ID>` | その場で切り替える（確認パネルなし） |
| `restore` | すべて表示（拡張）に戻す |
| `show-picker` | 起動中のアプリの表示先パネルを開く |
| `switch <番号\|ID>` | 起動中のアプリで切り替える（確認パネルあり） |

## アンインストール

1. メニューバーのアイコン ›「ログイン時に起動」を OFF にする
2. メニューバーのアイコン ›「Display Switcher を終了」
3. 「アプリケーション」から Display Switcher をゴミ箱に入れる（開発中なら `make uninstall` でも可）

設定も消す場合は、次のコマンドを実行してください。

```bash
defaults delete io.github.satoxiw-k.DisplaySwitcher
```

## ビルド（開発する人向け）

Xcode は不要です（Command Line Tools の Swift でビルドします）。

```bash
xcode-select --install   # Command Line Tools が入っていなければ
make install             # ビルドして /Applications に入れ、起動する
```

| コマンド | 動作 |
|---|---|
| `make install` | ビルドして `/Applications` に入れ、起動する（起動中なら入れ替える） |
| `make dmg` | 配布用の `dist/DisplaySwitcher-<バージョン>.dmg` を作る（背景つきの Finder ウインドウ） |
| `make notarize SIGN_IDENTITY="…"` | Developer ID で署名し、DMG を公証する |
| `make icon` | `scripts/make_icon.swift` からアイコン（`Resources/AppIcon.icns`）を作り直す |
| `make uninstall` | アプリを終了して `/Applications` から消す |
| `make clean` | ビルドしたものを消す |

- ビルドすると、Apple シリコンと Intel の両方で動くユニバーサルバイナリになります。
- バージョンは `Resources/Info.plist` の `CFBundleShortVersionString` です。DMG のファイル名にも使います。
- `make dmg` は Finder を操作して、ウインドウの大きさや背景、アイコンの位置を決めます。初回は「Finder を制御する許可」を求められるので、許可してください。背景は `scripts/make_dmg_background.swift` で描き、位置は `scripts/make_dmg.sh` で決めます。

### フォルダ構成

```
Sources/DisplaySwitcher/   アプリのソース（Swift, AppKit）
Resources/                 Info.plist、アイコン、翻訳（*.lproj）、DMG に入れる説明書
scripts/                   アイコン・DMG 背景・DMG を作るスクリプト
```

### 翻訳

画面に出す文言は、英語の文言をキーにして `Resources/<言語>.lproj/Localizable.strings` に訳を置いています（コードでは `L("...")`）。

- 文言を足したり変えたりしたら、すべての言語の `Localizable.strings` に同じキーを足す。訳がないキーは英語のまま出ます。
- 言語を増やすときは、`<言語>.lproj` フォルダを足し、`Resources/Info.plist` の `CFBundleLocalizations` にも足す。
- 別の言語で確かめるには、言語を指定して起動します。

```bash
open "/Applications/Display Switcher.app" --args -AppleLanguages "(en)"
```

### リリースの手順

1. `Resources/Info.plist` のバージョン（`CFBundleShortVersionString` と `CFBundleVersion`）を上げる
2. `make dmg`
3. GitHub の Releases に新しいリリース（タグ `v<バージョン>`）を作り、`dist/` にできた DMG を添付する

### Developer ID で署名・公証する場合

Apple Developer Program の「Developer ID Application」証明書がキーチェーンに入っていれば、署名と公証ができます。公証まで済ませると、受け取った人は「このまま開く」の操作をしなくて済みます。

```bash
xcrun notarytool store-credentials displayswitcher --apple-id <Apple ID> --team-id <チーム ID>
```

```bash
make notarize SIGN_IDENTITY="Developer ID Application: 名前 (チーム ID)"
```

1 つ目は公証用の認証情報をキーチェーンに保存するコマンドで、最初に 1 回だけ実行します。App 用パスワードを聞かれます。

## 注意

- 「〇〇のみ」「〇〇をオフ」でディスプレイを無効にする処理には、macOS の非公開 API（`CGSConfigureDisplayEnabled`）を使っています。今後の macOS アップデートで動かなくなるかもしれません。拡張と複製は公開 API なので、その場合も動きます。
- ビルドし直すと署名が変わるので、ログイン項目を登録し直す必要が出ることがあります。

## コントリビュート

Issue や Pull Request を歓迎します。画面に出す文言を足したり変えたりしたときは、すべての言語の `Localizable.strings` に同じキーを足してください。

## ライセンス

[MIT](LICENSE) © 2026 Satoshi Watanabe

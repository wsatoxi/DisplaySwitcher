APP_NAME    := DisplaySwitcher
BUNDLE      := Display Switcher.app
APP         := build/$(BUNDLE)
INSTALL_DIR := /Applications
VERSION     := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
DMG         := dist/$(APP_NAME)-$(VERSION).dmg
ICON        := Resources/AppIcon.icns
GUIDES      := "Resources/Read Me.txt" "Resources/はじめにお読みください.txt"
DMG_BG      := build/dmg-background.tiff

# 署名。既定は ad-hoc（証明書なし）。Developer ID で署名するときは
#   make dmg SIGN_IDENTITY="Developer ID Application: 名前 (チームID)"
SIGN_IDENTITY ?= -
ifeq ($(SIGN_IDENTITY),-)
  SIGN_FLAGS := --force --sign -
else
  SIGN_FLAGS := --force --sign "$(SIGN_IDENTITY)" --options runtime --timestamp
endif
# 公証に使う notarytool のキーチェーンプロファイル（xcrun notarytool store-credentials で作る）
NOTARY_PROFILE ?= displayswitcher

.PHONY: build app install uninstall dmg notarize icon clean

# Apple シリコンと Intel の両方で動くユニバーサルバイナリを作る
build:
	# アーキテクチャごとに作業フォルダを分ける（同じフォルダだと差分ビルドが壊れる）
	swift build -c release --triple arm64-apple-macosx14.0 --scratch-path .build/arm64
	swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path .build/x86_64
	mkdir -p build
	lipo -create -output build/$(APP_NAME) \
		.build/arm64/arm64-apple-macosx/release/$(APP_NAME) \
		.build/x86_64/x86_64-apple-macosx/release/$(APP_NAME)

app: build $(ICON) $(wildcard Resources/*.lproj/*.strings)
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp build/$(APP_NAME) "$(APP)/Contents/MacOS/"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp $(ICON) "$(APP)/Contents/Resources/"
	cp LICENSE "$(APP)/Contents/Resources/"
	cp -R Resources/*.lproj "$(APP)/Contents/Resources/"
	codesign $(SIGN_FLAGS) "$(APP)"

# アイコンは scripts/make_icon.swift で描く。描き直したら make icon
icon: $(ICON)

$(ICON): scripts/make_icon.swift
	rm -rf build/AppIcon.iconset
	mkdir -p build/AppIcon.iconset
	swift scripts/make_icon.swift build/icon_1024.png
	for s in 16 32 128 256 512; do \
		sips -z $$s $$s build/icon_1024.png --out build/AppIcon.iconset/icon_$${s}x$${s}.png >/dev/null; \
		sips -z $$((s * 2)) $$((s * 2)) build/icon_1024.png --out build/AppIcon.iconset/icon_$${s}x$${s}@2x.png >/dev/null; \
	done
	iconutil -c icns build/AppIcon.iconset -o $@

# 配布用の DMG。開くと背景つきのウインドウに、アプリと Applications が並ぶ
dmg: app $(DMG_BG)
	scripts/make_dmg.sh "$(APP)" $(DMG) "Display Switcher" $(DMG_BG) $(GUIDES)
	if [ "$(SIGN_IDENTITY)" != "-" ]; then codesign --force --sign "$(SIGN_IDENTITY)" --timestamp $(DMG); fi
	@echo "作成しました: $(DMG)"

# DMG の背景（Retina 用の 2 倍の画像も入れる）
$(DMG_BG): scripts/make_dmg_background.swift $(ICON)
	mkdir -p build
	sips -s format png $(ICON) --out build/icon.png >/dev/null
	swift scripts/make_dmg_background.swift build/icon.png build/dmg-background.png 1
	swift scripts/make_dmg_background.swift build/icon.png build/dmg-background@2x.png 2
	tiffutil -cathidpicheck build/dmg-background.png build/dmg-background@2x.png -out $@

# Developer ID で署名した DMG を Apple に公証してもらう
notarize:
	@if [ "$(SIGN_IDENTITY)" = "-" ]; then echo "SIGN_IDENTITY に Developer ID を指定してください"; exit 1; fi
	$(MAKE) dmg SIGN_IDENTITY="$(SIGN_IDENTITY)"
	xcrun notarytool submit $(DMG) --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple $(DMG)

# 開発用。起動中なら終了させ（終了時に全ディスプレイを戻す）、入れ替えて起動する
install: app
	-pkill -x $(APP_NAME) && sleep 2
	rm -rf "$(INSTALL_DIR)/$(BUNDLE)"
	cp -R "$(APP)" $(INSTALL_DIR)/
	open "$(INSTALL_DIR)/$(BUNDLE)"

uninstall:
	-pkill -x $(APP_NAME) && sleep 2
	rm -rf "$(INSTALL_DIR)/$(BUNDLE)"

clean:
	rm -rf .build build dist

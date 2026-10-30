#!/bin/bash
# 配布用の DMG を作る。開くと背景つきの Finder ウインドウに、アプリと Applications が並ぶ。
# 使い方: scripts/make_dmg.sh <アプリ.app> <出力先.dmg> <ボリューム名> <背景.tiff> <説明書…>
# 背景とアイコンの位置は scripts/make_dmg_background.swift と合わせる（640×520 pt）
set -euo pipefail

APP=$1
OUT=$2
VOLNAME=$3
BACKGROUND=$4
shift 4

STAGE=build/dmg
RW=build/dmg-rw.dmg
APP_NAME=$(basename "$APP")

rm -rf "$STAGE" "$RW" "$OUT"
mkdir -p "$STAGE/.background" "$(dirname "$OUT")"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$BACKGROUND" "$STAGE/.background/background.tiff"
for guide in "$@"; do cp "$guide" "$STAGE/"; done

# 同じ名前のボリュームが開いていると Finder が取り違えるので、先に取り外す
if [ -d "/Volumes/$VOLNAME" ]; then
    hdiutil detach "/Volumes/$VOLNAME" -force -quiet || true
fi

# あとからアイコンや .DS_Store を足すので、中身より 10 MB 大きく作る
SIZE=$(( $(du -sm "$STAGE" | cut -f1) + 10 ))m
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -size "$SIZE" -fs HFS+ -format UDRW -ov "$RW" -quiet
MOUNT=$(hdiutil attach "$RW" -readwrite -noverify -noautoopen | grep -o '/Volumes/.*$')
trap 'hdiutil detach "$MOUNT" -force -quiet 2>/dev/null || true' EXIT

# Finder でウインドウの見た目と、アイコンの位置を決める（.DS_Store に保存される）
# 初回は「Finder を制御する許可」を求められるので、許可する
GUIDE_LINES=""
x=250
for guide in "$@"; do
    GUIDE_LINES+="set position of item \"$(basename "$guide")\" of container window to {$x, 432}"$'\n'
    x=$((x + 140))
done
osascript <<EOF
tell application "Finder"
    tell disk "$(basename "$MOUNT")"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- 中身が 640×520 になるように、タイトルバーの 32 pt を足す
        set the bounds of container window to {200, 120, 840, 672}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 96
        set text size of opts to 13
        set background picture of opts to file ".background:background.tiff"
        set position of item "$APP_NAME" of container window to {180, 228}
        set position of item "Applications" of container window to {460, 228}
        $GUIDE_LINES
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# ボリュームのアイコンを、アプリのアイコンにする。Finder の update で消されるので、そのあとに置く
cp "$APP/Contents/Resources/AppIcon.icns" "$MOUNT/.VolumeIcon.icns"
SetFile -a C "$MOUNT"

sync
hdiutil detach "$MOUNT" -quiet
trap - EXIT
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" -quiet
rm -f "$RW"

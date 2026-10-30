// DMG を開いたときの Finder ウインドウの背景を描く。
// 使い方: swift scripts/make_dmg_background.swift <アイコン.png> <出力先.png> <倍率（1 か 2）>
// 640×520 pt。カードの位置は scripts/make_dmg.sh のアイコンの位置と合わせる
import AppKit

let args = CommandLine.arguments
let iconImage = NSImage(contentsOfFile: args[1])!
let output = args[2]
let scale = CGFloat(Double(args[3]) ?? 1)
let width: CGFloat = 640, height: CGFloat = 520

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
// 大きさを pt で指定すると、描画も自動で倍率がかかる
rep.size = NSSize(width: width, height: height)
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Finder の座標（左上が原点）を、描画の座標（左下が原点）に直す
func rect(centerX: CGFloat, centerY: CGFloat, width w: CGFloat, height h: CGFloat) -> NSRect {
    NSRect(x: centerX - w / 2, y: height - centerY - h / 2, width: w, height: h)
}

func glow(at center: NSPoint, radius: CGFloat, _ glowColor: NSColor) {
    NSGradient(colors: [glowColor, glowColor.withAlphaComponent(0)])!
        .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
}

// 背景（アイコンと同じ色合い）
let canvas = NSRect(x: 0, y: 0, width: width, height: height)
NSGradient(colors: [color(0x312E81), color(0x1E1B4B)])!.draw(in: canvas, angle: -90)
glow(at: NSPoint(x: 60, y: height), radius: 420, color(0x7C3AED, 0.45))
glow(at: NSPoint(x: width, y: 120), radius: 380, color(0x0EA5E9, 0.3))

// 見出し: アイコンとアプリ名
let title = NSAttributedString(string: "Display Switcher", attributes: [
    .font: NSFont.systemFont(ofSize: 30, weight: .bold), .foregroundColor: NSColor.white,
])
let iconSize: CGFloat = 52, gap: CGFloat = 12
let groupWidth = iconSize + gap + title.size().width
let groupX = (width - groupWidth) / 2
iconImage.draw(in: NSRect(x: groupX, y: height - 66 - iconSize / 2, width: iconSize, height: iconSize))
title.draw(at: NSPoint(x: groupX + iconSize + gap, y: height - 66 - title.size().height / 2))

// アプリと「Applications」を置く白いカード
let cardShadow = NSShadow()
cardShadow.shadowColor = color(0x000000, 0.3)
cardShadow.shadowBlurRadius = 18
cardShadow.shadowOffset = NSSize(width: 0, height: -6)
for centerX in [CGFloat(180), 460] {
    NSGraphicsContext.saveGraphicsState()
    cardShadow.set()
    color(0xFFFFFF).setFill()
    NSBezierPath(roundedRect: rect(centerX: centerX, centerY: 238, width: 196, height: 196), xRadius: 22, yRadius: 22).fill()
    NSGraphicsContext.restoreGraphicsState()
}

// カードのあいだの矢印
let arrowY = height - 238
color(0xFFFFFF, 0.9).setStroke()
color(0xFFFFFF, 0.9).setFill()
let shaft = NSBezierPath()
shaft.move(to: NSPoint(x: 296, y: arrowY))
shaft.line(to: NSPoint(x: 336, y: arrowY))
shaft.lineWidth = 3
shaft.lineCapStyle = .round
shaft.stroke()
let head = NSBezierPath()
head.move(to: NSPoint(x: 346, y: arrowY))
head.line(to: NSPoint(x: 334, y: arrowY + 8))
head.line(to: NSPoint(x: 334, y: arrowY - 8))
head.close()
head.fill()

// 下の帯（説明書を置く）
let band = NSRect(x: 0, y: 0, width: width, height: 160)
color(0xFFFFFF, 0.94).setFill()
band.fill()
color(0x000000, 0.08).setFill()
NSRect(x: 0, y: band.maxY - 1, width: width, height: 1).fill()

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("wrote \(output)")

// アプリアイコン（1024×1024 の PNG）を描く。使い方: swift scripts/make_icon.swift <出力先.png>
// デザイン: 濃い藍色の背景に、ガラスのような 2 枚の画面が重なる
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// macOS のアイコンの形（角が滑らかにつながる超楕円）
func squircle(_ rect: NSRect, exponent n: CGFloat = 5) -> NSBezierPath {
    let path = NSBezierPath()
    let steps = 720
    for i in 0..<steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let x = rect.midX + rect.width / 2 * (cos(t) < 0 ? -1 : 1) * pow(abs(cos(t)), 2 / n)
        let y = rect.midY + rect.height / 2 * (sin(t) < 0 ? -1 : 1) * pow(abs(sin(t)), 2 / n)
        i == 0 ? path.move(to: NSPoint(x: x, y: y)) : path.line(to: NSPoint(x: x, y: y))
    }
    path.close()
    return path
}

func roundedRect(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func withShadow(y: CGFloat, blur: CGFloat, _ shadowColor: NSColor, _ draw: () -> Void) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: y), blur: blur, color: shadowColor.cgColor)
    draw()
    ctx.restoreGState()
}

func clipped(to path: NSBezierPath, _ draw: () -> Void) {
    ctx.saveGState()
    path.addClip()
    draw()
    ctx.restoreGState()
}

/// 中心から外へ透明になっていく光
func glow(at center: NSPoint, radius: CGFloat, _ glowColor: NSColor) {
    NSGradient(colors: [glowColor, glowColor.withAlphaComponent(0)])!
        .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
}

/// ガラスの縁。上側ほど明るく光らせる
func rim(_ path: NSBezierPath, width: CGFloat, alpha: CGFloat) {
    clipped(to: path) {
        ctx.addPath(path.cgPath)
        ctx.setLineWidth(width * 2)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        NSGradient(colors: [color(0xFFFFFF, alpha), color(0xFFFFFF, alpha * 0.15), color(0xFFFFFF, alpha * 0.35)])!
            .draw(in: path.bounds, angle: -90)
    }
}

// 背景（macOS のアイコングリッド: 824×824）
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = squircle(body)
withShadow(y: -10, blur: 28, color(0x000000, 0.3)) {
    color(0x1E1B4B).setFill()
    bodyPath.fill()
}
clipped(to: bodyPath) {
    NSGradient(colors: [color(0x312E81), color(0x1E1B4B)])!.draw(in: body, angle: -90)
    glow(at: NSPoint(x: 300, y: 900), radius: 620, color(0x7C3AED, 0.55))
    glow(at: NSPoint(x: 820, y: 180), radius: 520, color(0x0EA5E9, 0.45))
}
rim(bodyPath, width: 3, alpha: 0.25)

// 奥の画面（左上）
let back = NSRect(x: 196, y: 452, width: 480, height: 320)
let backPath = roundedRect(back, 56)
withShadow(y: -16, blur: 40, color(0x000000, 0.35)) {
    color(0x22D3EE).setFill()
    backPath.fill()
}
clipped(to: backPath) {
    NSGradient(colors: [color(0x67E8F9), color(0x3B82F6)])!.draw(in: back, angle: -60)
}
rim(backPath, width: 4, alpha: 0.7)

// 手前の画面（右下）。すりガラス越しに奥の画面がにじんで見える
let front = NSRect(x: 340, y: 270, width: 500, height: 334)
let frontPath = roundedRect(front, 58)
withShadow(y: -24, blur: 60, color(0x0B1030, 0.55)) {
    color(0xFFFFFF, 0.01).setFill()
    frontPath.fill()
}
clipped(to: frontPath) {
    color(0x5B5BD6, 0.55).setFill()
    frontPath.fill()
    glow(at: NSPoint(x: back.maxX - 60, y: back.minY + 40), radius: 360, color(0x67E8F9, 0.55))
    NSGradient(colors: [color(0xFFFFFF, 0.42), color(0xFFFFFF, 0.10)])!.draw(in: front, angle: -90)
    // メニューバー
    color(0xFFFFFF, 0.55).setFill()
    roundedRect(NSRect(x: front.minX + 44, y: front.maxY - 62, width: 150, height: 18), 9).fill()
    color(0xFFFFFF, 0.3).setFill()
    roundedRect(NSRect(x: front.minX + 212, y: front.maxY - 62, width: 70, height: 18), 9).fill()
}
rim(frontPath, width: 5, alpha: 0.9)

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("wrote \(output)")

// 生成 Drip 应用图标（线条风格，纯色无渐变）：swift Resources/make_icon.swift <输出 1024px PNG 路径>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "icon_1024.png"

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let paper = color(0xF4ECDF)
let ink = color(0x3A2A22)
let accent = color(0xD9822B)

// 背景：macOS 图标网格（1024 画布内 824 主体，圆角约 185），纯色 + 轻投影
let bg = NSBezierPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: color(0x000000, 0.25).cgColor)
paper.setFill()
bg.fill()
ctx.restoreGState()

// 图案整体略向下，视觉居中（AppKit 坐标原点在左下）
ctx.translateBy(x: 0, y: -25)

func stroke(_ p: NSBezierPath, _ c: NSColor = ink, width: CGFloat = 30, cap: NSBezierPath.LineCapStyle = .round) {
    p.lineWidth = width
    p.lineCapStyle = cap
    p.lineJoinStyle = .round
    c.setStroke()
    p.stroke()
}

// 杯身：上宽下窄，底部圆角
let cup = NSBezierPath()
cup.move(to: CGPoint(x: 300, y: 590))
cup.line(to: CGPoint(x: 660, y: 590))
cup.curve(to: CGPoint(x: 572, y: 340), controlPoint1: CGPoint(x: 660, y: 440), controlPoint2: CGPoint(x: 636, y: 340))
cup.line(to: CGPoint(x: 388, y: 340))
cup.curve(to: CGPoint(x: 300, y: 590), controlPoint1: CGPoint(x: 324, y: 340), controlPoint2: CGPoint(x: 300, y: 440))
cup.close()
stroke(cup)

// 把手
let handle = NSBezierPath()
handle.move(to: CGPoint(x: 658, y: 540))
handle.curve(to: CGPoint(x: 645, y: 422), controlPoint1: CGPoint(x: 770, y: 560), controlPoint2: CGPoint(x: 770, y: 400))
stroke(handle, cap: .butt)  // 平头，避免端点伸进杯内

// 碟子：一条线
let saucer = NSBezierPath()
saucer.move(to: CGPoint(x: 268, y: 290))
saucer.line(to: CGPoint(x: 756, y: 290))
stroke(saucer)

// 杯中咖啡液面
let surface = NSBezierPath()
surface.move(to: CGPoint(x: 350, y: 540))
surface.curve(to: CGPoint(x: 610, y: 540), controlPoint1: CGPoint(x: 430, y: 510), controlPoint2: CGPoint(x: 530, y: 570))
stroke(surface, width: 18)

// 两缕热气
func steam(x: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: CGPoint(x: x, y: 650))
    p.curve(to: CGPoint(x: x, y: 790), controlPoint1: CGPoint(x: x - 40, y: 700), controlPoint2: CGPoint(x: x + 40, y: 740))
    return p
}
stroke(steam(x: 390), width: 22)
stroke(steam(x: 570), width: 22)

// 中间一滴（唯一的强调色）
let w: CGFloat = 92, h = w * 1.5, dx: CGFloat = 480, dy: CGFloat = 650
let drop = NSBezierPath()
drop.move(to: CGPoint(x: dx, y: dy + h))
drop.curve(to: CGPoint(x: dx + w / 2, y: dy + w / 2), controlPoint1: CGPoint(x: dx + w * 0.12, y: dy + h * 0.72),
           controlPoint2: CGPoint(x: dx + w / 2, y: dy + w * 0.9))
drop.appendArc(withCenter: CGPoint(x: dx, y: dy + w / 2), radius: w / 2, startAngle: 0, endAngle: 180, clockwise: true)
drop.curve(to: CGPoint(x: dx, y: dy + h), controlPoint1: CGPoint(x: dx - w / 2, y: dy + w * 0.9),
           controlPoint2: CGPoint(x: dx - w * 0.12, y: dy + h * 0.72))
drop.close()
stroke(drop, accent, width: 22)

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")

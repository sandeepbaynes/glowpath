// Original Glowpath artwork. Run from the project root: swift tools/render_icon.swift
import AppKit
import Foundation
import ImageIO

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func color(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func stroke(_ points: [NSPoint], width: CGFloat, tint: NSColor) {
    let line = NSBezierPath()
    line.move(to: points[0])
    for point in points.dropFirst() { line.line(to: point) }
    line.lineWidth = width
    line.lineCapStyle = .round
    line.lineJoinStyle = .round
    tint.setStroke()
    line.stroke()
}

func renderIcon(_ size: Int, to relativePath: String) throws {
    // RGB output has no alpha channel, as required for iOS App Store icons.
    let context = CGContext(data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: size * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    color(0x101F2B).setFill()
    NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()

    let panel = NSBezierPath(roundedRect: NSRect(x: 92, y: 92, width: 840, height: 840),
                            xRadius: 180, yRadius: 180)
    color(0x1D3542).setFill(); panel.fill()
    color(0x425961).setStroke(); panel.lineWidth = 3; panel.stroke()

    // Keep the meaningful route within the maskable icon's central safe area.
    context.translateBy(x: 51.2, y: 51.2)
    context.scaleBy(x: 0.9, y: 0.9)
    for row in 0..<3 {
        for column in 0..<3 {
            let tile = NSBezierPath(roundedRect: NSRect(
                x: 168 + column * 232, y: 168 + row * 232, width: 224, height: 224),
                xRadius: 42, yRadius: 42)
            color(0x2A4653).setFill(); tile.fill()
        }
    }
    let dim = color(0x59737C)
    stroke([NSPoint(x: 168, y: 280), NSPoint(x: 392, y: 280)], width: 28, tint: dim)
    stroke([NSPoint(x: 280, y: 400), NSPoint(x: 280, y: 512), NSPoint(x: 168, y: 512)], width: 28, tint: dim)
    stroke([NSPoint(x: 744, y: 632), NSPoint(x: 744, y: 856)], width: 28, tint: dim)
    stroke([NSPoint(x: 632, y: 512), NSPoint(x: 744, y: 512), NSPoint(x: 744, y: 400)], width: 28, tint: dim)

    let route = [NSPoint(x: 138, y: 744), NSPoint(x: 512, y: 744),
                 NSPoint(x: 512, y: 280), NSPoint(x: 886, y: 280)]
    context.saveGState()
    context.setShadow(offset: .zero, blur: 28, color: color(0xF3C779).withAlphaComponent(0.7).cgColor)
    stroke(route, width: 42, tint: color(0xF3C779))
    context.restoreGState()
    stroke(route, width: 10, tint: color(0xFFF0BE))

    for center in [NSPoint(x: 280, y: 744), NSPoint(x: 512, y: 512), NSPoint(x: 744, y: 280)] {
        let backing = NSBezierPath(ovalIn: NSRect(x: center.x - 41, y: center.y - 41, width: 82, height: 82))
        color(0x3F514C).setFill(); backing.fill()
        let star = NSBezierPath()
        for index in 0..<10 {
            let radius: CGFloat = index % 2 == 0 ? 38 : 17
            let angle = CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
            let point = NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 { star.move(to: point) } else { star.line(to: point) }
        }
        star.close()
        color(0xFFE3A0).setFill(); star.fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    let destination = root.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    let output = CGImageDestinationCreateWithURL(destination as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(output, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(output) else { fatalError("Could not encode icon") }
}

try renderIcon(1024, to: "assets/branding/glowpath-icon.png")
let catalog = "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
let contents = try Data(contentsOf: root.appendingPathComponent(catalog + "Contents.json"))
let json = try JSONSerialization.jsonObject(with: contents) as! [String: Any]
for entry in json["images"] as! [[String: Any]] {
    guard let filename = entry["filename"] as? String,
          let dimensions = entry["size"] as? String,
          let scaleText = entry["scale"] as? String,
          let base = Double(dimensions.components(separatedBy: "x")[0]),
          let scale = Double(scaleText.replacingOccurrences(of: "x", with: "")) else { continue }
    try renderIcon(Int(base * scale), to: catalog + filename)
}
for (density, size) in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)] {
    try renderIcon(size, to: "android/app/src/main/res/mipmap-\(density)/ic_launcher.png")
}
for size in [192, 512] {
    try renderIcon(size, to: "web/icons/Icon-\(size).png")
    try renderIcon(size, to: "web/icons/Icon-maskable-\(size).png")
}
try renderIcon(32, to: "web/favicon.png")
print("Rendered original RGB launcher icons for iOS, Android, and the web.")

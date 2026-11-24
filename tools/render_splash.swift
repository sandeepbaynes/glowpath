// Original route mark shared by the Flutter, web and native launch screens.
// Run from the project root: swift tools/render_splash.swift
import AppKit
import Foundation
import ImageIO

func tint(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
for scale in 1...3 {
    let size = 128 * scale
    let context = CGContext(data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: size * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    context.translateBy(x: 0, y: 128)
    context.scaleBy(x: 1, y: -1)
    let orbit = CGMutablePath()
    orbit.addArc(center: CGPoint(x: 64, y: 64), radius: 56,
                 startAngle: -0.6, endAngle: -0.6 + .pi * 1.65, clockwise: false)
    context.addPath(orbit)
    context.setStrokeColor(tint(0x79DCCC, 0.28).cgColor)
    context.setLineWidth(1); context.strokePath()
    let route = CGMutablePath()
    route.move(to: CGPoint(x: 26, y: 88)); route.addLine(to: CGPoint(x: 50, y: 88))
    route.addQuadCurve(to: CGPoint(x: 64, y: 74), control: CGPoint(x: 64, y: 88))
    route.addLine(to: CGPoint(x: 64, y: 54))
    route.addQuadCurve(to: CGPoint(x: 78, y: 40), control: CGPoint(x: 64, y: 40))
    route.addLine(to: CGPoint(x: 102, y: 40))
    context.saveGState()
    context.setShadow(offset: .zero, blur: 14, color: tint(0x79DCCC, 0.4).cgColor)
    context.addPath(route); context.setStrokeColor(tint(0x79DCCC).cgColor)
    context.setLineWidth(3); context.setLineCap(.round); context.strokePath()
    context.restoreGState()
    for point in [CGPoint(x: 26, y: 88), CGPoint(x: 64, y: 64), CGPoint(x: 102, y: 40)] {
        context.setFillColor(tint(0x080F20).cgColor)
        context.fillEllipse(in: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
        let star = CGMutablePath()
        for (index, offset) in [CGPoint(x: 0,y: -6), CGPoint(x: 2,y: -2), CGPoint(x: 6,y: 0), CGPoint(x: 2,y: 2), CGPoint(x: 0,y: 6), CGPoint(x: -2,y: 2), CGPoint(x: -6,y: 0), CGPoint(x: -2,y: -2)].enumerated() {
            let vertex = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            if index == 0 { star.move(to: vertex) } else { star.addLine(to: vertex) }
        }
        star.closeSubpath(); context.addPath(star)
        context.setFillColor(tint(0xF4C873).cgColor); context.fillPath()
    }
    context.setFillColor(tint(0xEDF3FF, 0.6).cgColor)
    context.fillEllipse(in: CGRect(x: 108, y: 94, width: 4, height: 4))
    let suffix = scale == 1 ? "" : "@\(scale)x"
    let url = URL(fileURLWithPath: "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage\(suffix).png")
    let output = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(output, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(output) else { fatalError("Could not encode launch image") }
}
print("Rendered native route mark at 1x, 2x and 3x.")

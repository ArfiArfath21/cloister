// Draws the Cloister mark: a quiet arch with a single point of light inside.
//
//   swift Tools/make-icon.swift
//
// Writes Resources/AppIcon.icns and docs/icon.png.
import AppKit

let ink = CGColor(red: 0.051, green: 0.051, blue: 0.059, alpha: 1)
let inkHigh = CGColor(red: 0.115, green: 0.112, blue: 0.122, alpha: 1)
let paper = CGColor(red: 0.925, green: 0.894, blue: 0.835, alpha: 1)

func drawIcon(size: Int) -> CGImage {
    let s = CGFloat(size)
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.scaleBy(x: s / 1024, y: s / 1024)

    // macOS icon grid: an 824pt rounded square centred on a 1024 canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Soft drop shadow under the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: CGColor(gray: 0, alpha: 0.45))
    ctx.addPath(tilePath)
    ctx.setFillColor(ink)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()

    // Vertical ink gradient, lighter at the top.
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let fill = CGGradient(colorsSpace: space, colors: [inkHigh, ink] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(fill, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Warm glow behind the light.
    let light = CGPoint(x: 512, y: 470)
    let glow = CGGradient(
        colorsSpace: space,
        colors: [paper.copy(alpha: 0.16)!, paper.copy(alpha: 0)!] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(glow, startCenter: light, startRadius: 0, endCenter: light, endRadius: 360, options: [])

    // The arch: two straight jambs rising into a semicircle.
    let width: CGFloat = 340
    let left = 512 - width / 2, right = 512 + width / 2
    let base: CGFloat = 268
    let springLine: CGFloat = 560
    let arch = CGMutablePath()
    arch.move(to: CGPoint(x: left, y: base))
    arch.addLine(to: CGPoint(x: left, y: springLine))
    arch.addArc(center: CGPoint(x: 512, y: springLine), radius: width / 2,
                startAngle: .pi, endAngle: 0, clockwise: true)
    arch.addLine(to: CGPoint(x: right, y: base))
    ctx.addPath(arch)
    ctx.setStrokeColor(paper)
    ctx.setLineWidth(20)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    // Threshold: a short, fainter line the arch stands on.
    ctx.setStrokeColor(paper.copy(alpha: 0.28)!)
    ctx.setLineWidth(12)
    ctx.move(to: CGPoint(x: left - 70, y: base))
    ctx.addLine(to: CGPoint(x: right + 70, y: base))
    ctx.strokePath()

    // The point of light, with a halo.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 46, color: paper.copy(alpha: 0.9)!)
    ctx.setFillColor(paper)
    ctx.fillEllipse(in: CGRect(x: light.x - 30, y: light.y - 30, width: 60, height: 60))
    ctx.restoreGState()

    // Hairline highlight around the tile edge.
    ctx.addPath(tilePath)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.08))
    ctx.setLineWidth(3)
    ctx.strokePath()

    ctx.restoreGState()
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().path
let iconset = NSTemporaryDirectory() + "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    writePNG(drawIcon(size: points), to: "\(iconset)/icon_\(points)x\(points).png")
    writePNG(drawIcon(size: points * 2), to: "\(iconset)/icon_\(points)x\(points)@2x.png")
}

try? FileManager.default.createDirectory(atPath: "\(root)/Resources", withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: "\(root)/docs", withIntermediateDirectories: true)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset, "-o", "\(root)/Resources/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()

writePNG(drawIcon(size: 512), to: "\(root)/docs/icon.png")
print("Wrote Resources/AppIcon.icns and docs/icon.png")

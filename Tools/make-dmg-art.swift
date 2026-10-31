// Draws the installer window background: the app on the left, Applications
// on the right, a quiet arrow between them.
//
//   swift Tools/make-dmg-art.swift
//
// Writes Resources/dmg-background.tiff (1x + 2x). Icon centres must match
// the positions build.sh gives Finder: (160, 180) and (480, 180).
import AppKit

let width: CGFloat = 640, height: CGFloat = 400
let ink = NSColor(red: 0.051, green: 0.051, blue: 0.059, alpha: 1)

func draw(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: width, height: height)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    NSGradient(
        starting: NSColor(red: 0.953, green: 0.933, blue: 0.894, alpha: 1),
        ending: NSColor(red: 0.906, green: 0.875, blue: 0.82, alpha: 1)
    )!.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

    // Finder uses a top-left origin; flip y once here.
    func y(_ top: CGFloat) -> CGFloat { height - top }

    // Arrow between the two icons.
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 250, y: y(180)))
    arrow.line(to: NSPoint(x: 390, y: y(180)))
    arrow.move(to: NSPoint(x: 380, y: y(171)))
    arrow.line(to: NSPoint(x: 390, y: y(180)))
    arrow.line(to: NSPoint(x: 380, y: y(189)))
    arrow.lineWidth = 1.5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    ink.withAlphaComponent(0.35).setStroke()
    arrow.stroke()

    func centred(_ text: String, top: CGFloat, size: CGFloat, weight: NSFont.Weight, kern: CGFloat, alpha: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: ink.withAlphaComponent(alpha),
            .kern: kern,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let bounds = string.size()
        string.draw(at: NSPoint(x: (width - bounds.width) / 2, y: y(top) - bounds.height / 2))
    }

    centred("CLOISTER", top: 52, size: 11, weight: .semibold, kern: 5, alpha: 0.45)
    centred("Drag Cloister into Applications to install", top: 330, size: 13, weight: .regular, kern: 0, alpha: 0.5)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().path
let image = NSImage(size: NSSize(width: width, height: height))
image.addRepresentation(draw(scale: 1))
image.addRepresentation(draw(scale: 2))
try! image.tiffRepresentation(using: .lzw, factor: 0)!
    .write(to: URL(fileURLWithPath: "\(root)/Resources/dmg-background.tiff"))
print("Wrote Resources/dmg-background.tiff")

import AppKit
import Foundation

enum IconGeneratorError: Error {
    case invalidArguments
    case contextCreationFailed
    case pngEncodingFailed(String)
}

struct Renderer {
    static func drawYouTube(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: image.size)
        NSColor.clear.setFill()
        rect.fill()

        let badgeRect = rect.insetBy(dx: size * 0.04, dy: size * 0.2)
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: size * 0.18, yRadius: size * 0.18)
        NSColor(calibratedRed: 246 / 255, green: 28 / 255, blue: 13 / 255, alpha: 1).setFill()
        badge.fill()

        let triangle = NSBezierPath()
        triangle.move(to: NSPoint(x: size * 0.42, y: size * 0.35))
        triangle.line(to: NSPoint(x: size * 0.42, y: size * 0.65))
        triangle.line(to: NSPoint(x: size * 0.67, y: size * 0.5))
        triangle.close()
        NSColor.white.setFill()
        triangle.fill()

        image.unlockFocus()
        return image
    }

    static func drawClaudeCode(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: image.size)
        NSColor.clear.setFill()
        rect.fill()

        let scaleX = size / 66
        let scaleY = size / 52
        let accent = NSColor(calibratedRed: 204 / 255, green: 120 / 255, blue: 92 / 255, alpha: 1)

        func fillRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: NSColor) {
            color.setFill()
            let convertedY = size - ((y + height) * scaleY)
            NSBezierPath(rect: NSRect(
                x: x * scaleX,
                y: convertedY,
                width: width * scaleX,
                height: height * scaleY
            )).fill()
        }

        fillRect(x: 0, y: 13, width: 6, height: 13, color: accent)
        fillRect(x: 60, y: 13, width: 6, height: 13, color: accent)
        fillRect(x: 6, y: 39, width: 6, height: 13, color: accent)
        fillRect(x: 18, y: 39, width: 6, height: 13, color: accent)
        fillRect(x: 42, y: 39, width: 6, height: 13, color: accent)
        fillRect(x: 54, y: 39, width: 6, height: 13, color: accent)
        fillRect(x: 6, y: 0, width: 54, height: 39, color: accent)
        fillRect(x: 12, y: 13, width: 6, height: 6.5, color: .black)
        fillRect(x: 48, y: 13, width: 6, height: 6.5, color: .black)

        image.unlockFocus()
        return image
    }

    static func drawYouTubeTemplate(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: image.size)
        NSColor.clear.setFill()
        rect.fill()

        let badgeRect = rect.insetBy(dx: size * 0.04, dy: size * 0.2)
        let compoundPath = NSBezierPath(roundedRect: badgeRect, xRadius: size * 0.18, yRadius: size * 0.18)
        let triangle = NSBezierPath()
        triangle.move(to: NSPoint(x: size * 0.42, y: size * 0.35))
        triangle.line(to: NSPoint(x: size * 0.42, y: size * 0.65))
        triangle.line(to: NSPoint(x: size * 0.67, y: size * 0.5))
        triangle.close()
        compoundPath.append(triangle)
        compoundPath.windingRule = .evenOdd

        NSColor.black.setFill()
        compoundPath.fill()

        image.unlockFocus()
        return image
    }

    static func drawClaudeCodeTemplate(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: image.size)
        NSColor.clear.setFill()
        rect.fill()

        let scaleX = size / 66
        let scaleY = size / 52
        let compoundPath = NSBezierPath()

        func appendRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
            let convertedY = size - ((y + height) * scaleY)
            compoundPath.appendRect(NSRect(
                x: x * scaleX,
                y: convertedY,
                width: width * scaleX,
                height: height * scaleY
            ))
        }

        appendRect(x: 0, y: 13, width: 6, height: 13)
        appendRect(x: 60, y: 13, width: 6, height: 13)
        appendRect(x: 6, y: 39, width: 6, height: 13)
        appendRect(x: 18, y: 39, width: 6, height: 13)
        appendRect(x: 42, y: 39, width: 6, height: 13)
        appendRect(x: 54, y: 39, width: 6, height: 13)
        appendRect(x: 6, y: 0, width: 54, height: 39)
        appendRect(x: 12, y: 13, width: 6, height: 6.5)
        appendRect(x: 48, y: 13, width: 6, height: 6.5)

        compoundPath.windingRule = .evenOdd
        NSColor.black.setFill()
        compoundPath.fill()

        image.unlockFocus()
        return image
    }
}

func pngData(from image: NSImage) -> Data? {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        return nil
    }
    return bitmap.representation(using: .png, properties: [:])
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    throw IconGeneratorError.invalidArguments
}

let iconName = arguments[1]
let outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)

let definitions: [(String, CGFloat)] = [
    ("", 20),
    ("@2x", 40)
]

for (suffix, size) in definitions {
    let image: NSImage
    switch iconName {
    case "youtube":
        image = Renderer.drawYouTube(size: size)
    case "youtube-negative":
        image = Renderer.drawYouTubeTemplate(size: size)
    case "claude-code":
        image = Renderer.drawClaudeCode(size: size)
    case "claude-code-negative":
        image = Renderer.drawClaudeCodeTemplate(size: size)
    default:
        throw IconGeneratorError.invalidArguments
    }

    guard let data = pngData(from: image) else {
        throw IconGeneratorError.pngEncodingFailed(iconName)
    }

    let url = outputDirectory.appendingPathComponent("\(iconName)\(suffix).png")
    try data.write(to: url)
}

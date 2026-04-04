#!/usr/bin/env swift

import AppKit

func renderSVG(at svgPath: String, to outputPath: String, size: NSSize) {
    guard let image = NSImage(contentsOfFile: svgPath) else {
        print("ERROR: Could not load \(svgPath)")
        exit(1)
    }

    let output = NSImage(size: size)
    output.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(origin: .zero, size: size),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy,
               fraction: 1.0)
    output.unlockFocus()

    guard let tiff = output.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("ERROR: Could not render PNG for \(outputPath)")
        exit(1)
    }

    do {
        try png.write(to: URL(fileURLWithPath: outputPath))
        print("Wrote \(outputPath) (\(Int(size.width))x\(Int(size.height)))")
    } catch {
        print("ERROR writing \(outputPath): \(error)")
        exit(1)
    }
}

let projectRoot = CommandLine.arguments[1]
let svgDir = "\(projectRoot)/Courier/Resources/IncomingIcons"
let appIconDir = "\(projectRoot)/Courier/Resources/Assets.xcassets/AppIcon.appiconset"
let menuBarDir = "\(projectRoot)/Courier/Resources/Assets.xcassets/MenuBarIcon.imageset"

let appIconSVG = "\(svgDir)/courier-app-icon-new.svg"
let menuBarSVG = "\(svgDir)/courier-toolbar-icon.svg"

// App icon sizes: filename → pixel dimensions
let appIconSizes: [(String, CGFloat)] = [
    ("icon_16x16.png",      16),
    ("icon_16x16@2x.png",   32),
    ("icon_32x32.png",      32),
    ("icon_32x32@2x.png",   64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png", 1024),
]

for (filename, px) in appIconSizes {
    renderSVG(at: appIconSVG,
              to: "\(appIconDir)/\(filename)",
              size: NSSize(width: px, height: px))
}

// Menu bar icon: 18pt @1x = 18px, @2x = 36px
// SVG is 719x701 — nearly square, render at square target
renderSVG(at: menuBarSVG,
          to: "\(menuBarDir)/menubar-icon.png",
          size: NSSize(width: 18, height: 18))
renderSVG(at: menuBarSVG,
          to: "\(menuBarDir)/menubar-icon@2x.png",
          size: NSSize(width: 36, height: 36))

print("Done.")

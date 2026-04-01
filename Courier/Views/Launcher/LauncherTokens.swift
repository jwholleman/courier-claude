import AppKit
import SwiftUI

enum LauncherTokens {
    enum Layout {
        static let panelWidth: CGFloat = 680
        static let panelOuterPadding: CGFloat = 32
        static let panelCornerRadius: CGFloat = 18
        static let controlCornerRadius: CGFloat = 8
        static let inputHorizontalPadding: CGFloat = 12
        static let inputTopPadding: CGFloat = 8
        static let inputBottomPadding: CGFloat = 2
        static let inputBottomPaddingWarning: CGFloat = 4
        static let warningHorizontalPadding: CGFloat = 16
        static let warningBottomPadding: CGFloat = 8
        static let buttonSize: CGFloat = 44
        static let deliverButtonHeight: CGFloat = 42
        static let iconSize: CGFloat = 29
        static let tooltipOffsetY: CGFloat = 20
        static let deliverHorizontalPadding: CGFloat = 15
        static let deliverVerticalPadding: CGFloat = 8
        static let deliverTopMargin: CGFloat = 1
        static let deliverSpacing: CGFloat = 6
    }

    enum Typography {
        static let querySize: CGFloat = 18
        static let warningSize: CGFloat = 11
        static let shortcutSize: CGFloat = 11
        static let tooltipSize: CGFloat = 10
        static let deliverSize: CGFloat = 18
    }

    enum Motion {
        static let quickEase: Double = 0.1
        static let stateEase: Double = 0.15
    }

    enum Color {
        static let panelTop = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: 0x151619)
                : NSColor(hex: 0xF6F7F9)
        }

        static let panelBottom = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: 0x111214)
                : NSColor(hex: 0xEEF1F4)
        }

        static let inputTop = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: 0x202126)
                : NSColor(hex: 0xFFFFFF)
        }

        static let inputBottom = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: 0x1B1C20)
                : NSColor(hex: 0xF8F9FB)
        }

        static let placeholder = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: 0xC8CAD1)
                : NSColor(hex: 0x6B7280)
        }

        static let kagiSelected = SwiftUI.Color(hex: 0xFFB319)
        static let inputBorder = SwiftUI.Color.white.opacity(0.08)
        static let serviceBackgroundDefault = SwiftUI.Color.white.opacity(0.03)
        static let serviceBackgroundHover = SwiftUI.Color.white.opacity(0.08)
        static let serviceBorderDefault = SwiftUI.Color.white.opacity(0.05)
        static let serviceBorderHover = SwiftUI.Color.white.opacity(0.10)
        static let deliverDisabledBackground = SwiftUI.Color.white.opacity(0.06)
        static let deliverDisabledBorder = SwiftUI.Color.white.opacity(0.05)
        static let deliverEnabledBorder = SwiftUI.Color.white.opacity(0.14)
        static let deliverEnabledBorderHover = SwiftUI.Color.white.opacity(0.22)
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private extension SwiftUI.Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

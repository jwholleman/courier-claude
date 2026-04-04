import AppKit

final class LauncherPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        isMovableByWindowBackground = false
        hasShadow = true
        backgroundColor = .clear
        isOpaque = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    // Required for text input to work in a .nonactivatingPanel
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Accessibility

    override func accessibilityRole() -> NSAccessibility.Role? { .window }
    override func accessibilityLabel() -> String? { "Courier Launcher" }
    override func accessibilityRoleDescription() -> String? { "launcher panel" }
    override func isAccessibilityElement() -> Bool { true }
}

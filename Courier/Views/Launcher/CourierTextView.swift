import AppKit

final class CourierTextView: NSTextView {

    var placeholder: String = "Type your message. Hold ⌘ or type \"/\" to switch destination." {
        didSet { setAccessibilityPlaceholderValue(placeholder) }
    }

    /// Called when the Cmd modifier key is pressed or released.
    var onCmdModeChanged: ((Bool) -> Void)?
    /// Called when Cmd+number (1–9) is pressed.
    var onCmdNumberPressed: ((Int) -> Void)?

    // MARK: - Placeholder

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if string.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: LauncherTokens.Typography.querySize),
                .foregroundColor: LauncherTokens.Color.placeholder,
            ]
            let inset = textContainerInset
            let rect = NSRect(
                x: inset.width + 5,
                y: inset.height,
                width: bounds.width - inset.width * 2 - 10,
                height: bounds.height - inset.height * 2
            )
            placeholder.draw(in: rect, withAttributes: attributes)
        }
    }

    // MARK: - Key handling

    /// Detect Cmd key press/release via flagsChanged. The panel is key (makeKeyAndOrderFront),
    /// so the first responder receives flagsChanged events reliably.
    override func flagsChanged(with event: NSEvent) {
        onCmdModeChanged?(event.modifierFlags.contains(.command))
        super.flagsChanged(with: event)
    }

    /// Intercept Cmd+Return, Shift+Return (→ newline) and Cmd+1–9 (→ service selection)
    /// in keyDown where event.modifierFlags is frozen at press time and always reliable
    /// in a nonactivating panel.
    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+number: select service by position (only Cmd, no other modifiers)
        if modifiers == .command,
           let char = event.charactersIgnoringModifiers,
           let digit = Int(char), digit >= 1, digit <= 9 {
            onCmdNumberPressed?(digit)
            return
        }

        // Cmd+Return / Shift+Return → literal newline
        if event.keyCode == 36 /* kVK_Return */ {
            if modifiers.contains(.command) || modifiers.contains(.shift) {
                insertNewlineIgnoringFieldEditor(nil)
                return
            }
        }
        super.keyDown(with: event)
    }
}

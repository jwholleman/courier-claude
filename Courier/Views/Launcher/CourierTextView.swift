import AppKit

final class CourierTextView: NSTextView {

    var placeholder: String = "Type your message or \"/\" to switch destination"

    // MARK: - Placeholder

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if string.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.placeholderTextColor,
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

    /// intercept Cmd+Return and Shift+Return in keyDown, where event.modifierFlags is
    /// guaranteed to reflect the actual key state at press time — before interpretKeyEvents
    /// strips or loses modifier context.
    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 36 /* kVK_Return */ {
            if modifiers.contains(.command) || modifiers.contains(.shift) {
                insertNewlineIgnoringFieldEditor(nil)
                return
            }
        }
        super.keyDown(with: event)
    }
}

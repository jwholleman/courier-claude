import AppKit

final class CourierTextView: NSTextView {

    var placeholder: String = "Type your message or \"/\" to switch destination"

    // Set by QueryInputView Coordinator after makeNSView
    var onCmdReturn: (() -> Void)?
    var onTabForward: (() -> Void)?
    var onTabBackward: (() -> Void)?

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

    /// Cmd+key combos come through performKeyEquivalent, not doCommandBy:
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 36 /* Return */ && event.modifierFlags.contains(.command) {
            onCmdReturn?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// NSTextView calls insertTab(_:) directly — does not route through delegate doCommandBy:
    override func insertTab(_ sender: Any?) {
        onTabForward?()
    }

    /// Shift+Tab
    override func insertBacktab(_ sender: Any?) {
        onTabBackward?()
    }
}

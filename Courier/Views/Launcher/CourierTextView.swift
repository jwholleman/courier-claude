import AppKit

final class CourierTextView: NSTextView {

    var placeholder: String = "Type your message or \"/\" to switch destination"

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
}

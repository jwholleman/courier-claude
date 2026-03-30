import SwiftUI
import AppKit

struct QueryInputView: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var onSubmit: () -> Void
    var onDismiss: () -> Void
    weak var viewModel: LauncherViewModel?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = CourierTextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isRulerVisible = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.setAccessibilityLabel("Query input")

        context.coordinator.textView = textView
        viewModel?.queryTextView = textView

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CourierTextView else { return }
        if textView.string != text {
            context.coordinator.isUpdatingFromSwiftUI = true
            textView.string = text
            context.coordinator.isUpdatingFromSwiftUI = false
            textView.needsDisplay = true
        }
        // Keep viewModel reference up to date
        context.coordinator.parent = self
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: QueryInputView
        weak var textView: CourierTextView?
        var isUpdatingFromSwiftUI = false
        var isPasting = false
        private var hasSubmitted = false

        init(parent: QueryInputView) {
            self.parent = parent
        }

        func resetSubmitState() {
            hasSubmitted = false
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingFromSwiftUI, let textView else { return }
            parent.text = textView.string
            textView.needsDisplay = true  // Toggle placeholder visibility
            recalculateHeightIfNeeded(textView)
        }

        private var lastLineCount: Int = 0

        private func recalculateHeightIfNeeded(_ textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            // Estimate line count to debounce — only recalc on line count change
            let lineHeight: CGFloat = textView.font?.capHeight ?? 12
            let currentLineCount = max(1, Int(usedRect.height / max(lineHeight, 1)))
            guard currentLineCount != lastLineCount else { return }
            lastLineCount = currentLineCount
            let newHeight = min(max(usedRect.height + 32, 80), 320)
            // Publish via binding so LauncherWindowController's observation fires
            DispatchQueue.main.async { [weak self] in
                self?.parent.height = newHeight
            }
        }

        func textView(_ textView: NSTextView,
                      shouldChangeTextIn range: NSRange,
                      replacementString text: String?) -> Bool {
            // Detect paste: replacement string longer than 1 char
            isPasting = (text?.count ?? 0) > 1
            return true
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                // Plain Return -> submit (debounced, blocked on empty/whitespace)
                // Cmd+Return and Shift+Return are intercepted in CourierTextView.keyDown
                // before they reach doCommandBy:, so they never arrive here.
                guard !hasSubmitted else { return true }
                let trimmed = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return true }
                hasSubmitted = true
                parent.onSubmit()
                return true
            }
            if selector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)) {
                // Option+Return -> literal newline
                textView.insertNewlineIgnoringFieldEditor(nil)
                return true
            }
            if selector == #selector(NSResponder.cancelOperation(_:)) {
                // ESC -> dismiss via callback (routes through LauncherWindowController state machine)
                hasSubmitted = false
                parent.onDismiss()
                return true
            }
            return false
        }
    }
}

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

        init(parent: QueryInputView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingFromSwiftUI, let textView else { return }
            parent.text = textView.string
            textView.needsDisplay = true  // Toggle placeholder visibility
        }

        func textView(_ textView: NSTextView,
                      shouldChangeTextIn range: NSRange,
                      replacementString text: String?) -> Bool {
            // Detect paste: replacement string longer than 1 char
            isPasting = (text?.count ?? 0) > 1
            return true
        }
    }
}

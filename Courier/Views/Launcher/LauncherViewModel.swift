import AppKit
import Observation

@Observable
@MainActor
final class LauncherViewModel {
    var queryText: String = ""
    var contentHeight: CGFloat = 80
    var isSlashMode: Bool = false
    var slashPrefix: String = ""
    var hasSubmitted: Bool = false

    // Set by QueryInputView Coordinator during makeNSView.
    // CRITICAL: @ObservationIgnored is required — @Observable does not support
    // observing weak references and will fail to compile without this annotation.
    @ObservationIgnored weak var queryTextView: NSTextView?

    func clearQuery() {
        queryText = ""
        contentHeight = 80
        isSlashMode = false
        slashPrefix = ""
        hasSubmitted = false
    }
}

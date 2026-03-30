import AppKit
import Observation

@Observable
@MainActor
final class LauncherViewModel {

    var queryText: String = ""
    var contentHeight: CGFloat = 80

    // Weak ref to the NSTextView inside QueryInputView so LauncherWindowController
    // can set first responder. Must be @ObservationIgnored — @Observable does not
    // support observing weak references.
    @ObservationIgnored weak var queryTextView: NSTextView?

    func clearQuery() {
        queryText = ""
        contentHeight = 80
    }
}

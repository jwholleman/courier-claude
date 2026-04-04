import SwiftUI

// @main removed — entry point is in main.swift to allow unit tests to load the binary
// without launching the SwiftUI App lifecycle (which creates a second NSApplication).
struct CourierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // The NSStatusItem is managed entirely by AppDelegate via AppKit for reliable icon sizing.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

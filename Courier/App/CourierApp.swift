import SwiftUI
import AppKit

// @main removed — entry point is in main.swift to allow unit tests to load the binary
// without launching the SwiftUI App lifecycle (which creates a second NSApplication).
struct CourierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appDelegate: appDelegate)
        } label: {
            Image(systemName: "paperplane")
                .accessibilityLabel("Courier")
        }
        .menuBarExtraStyle(.menu)
    }
}

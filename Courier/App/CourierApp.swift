import SwiftUI
import AppKit

@main
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

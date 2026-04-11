import SwiftUI
import AppKit

struct MenuBarView: View {
    let appDelegate: AppDelegate

    var body: some View {
        Button("Show Courier") {
            appDelegate.togglePanel()
        }
        .accessibilityLabel("Show Courier launcher panel")

        Divider()

        Button("Settings...") {
            appDelegate.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
        .accessibilityLabel("Open Courier settings")

        Button("About Courier") {
            var options: [NSApplication.AboutPanelOptionKey: Any] = [
                .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0",
                .credits: NSAttributedString(
                    string: "A universal query launcher for macOS.",
                    attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
                )
            ]
            if let icon = NSImage(named: "AppIcon") {
                options[.applicationIcon] = icon
            }
            NSApp.orderFrontStandardAboutPanel(options: options)
        }
        .accessibilityLabel("Show about Courier panel")

        Button("Help") {
            if let url = URL(string: "https://github.com/jwholleman/courier") {
                NSWorkspace.shared.open(url)
            }
        }
        .accessibilityLabel("Open Courier help in browser")

        Divider()

        Button("Check for Updates...") {
            // Coming in a future version
        }
        .disabled(true)
        .help("Coming in a future version")
        .accessibilityLabel("Check for updates — not yet available")

        Divider()

        Button("Quit Courier") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
        .accessibilityLabel("Quit Courier")
    }
}

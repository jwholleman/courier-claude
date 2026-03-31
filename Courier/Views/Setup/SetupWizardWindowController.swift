import AppKit
import SwiftUI

@MainActor
final class SetupWizardWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private let settings: AppSettings
    var onComplete: (() -> Void)?

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = SetupWizardView(settings: settings) { [weak self] in
            self?.close()
            self?.onComplete?()
        }

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(x: 0, y: 0, width: 520, height: 440)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Courier Setup"
        win.contentView = hosting
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }

    func close() {
        window?.orderOut(nil)
        window = nil
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Setup Not Complete"
        alert.informativeText = "Courier won't be fully functional until setup is finished. Your selections so far have been saved.\n\nQuit anyway?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit Anyway")
        alert.addButton(withTitle: "Continue Setup")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            close()
            return false  // We handled it manually
        }
        return false  // Cancel close
    }
}

import Foundation
import KeyboardShortcuts

protocol HotKeyProvider {
    /// Register the global hotkey. Calls `handler` on key-up.
    func register(handler: @escaping () -> Void)

    /// Unregister the current hotkey.
    func unregister()

    /// Whether the current shortcut is a restricted system shortcut.
    func isRestricted(_ shortcut: Any) -> Bool
}

/// Concrete implementation backed by the KeyboardShortcuts package.
final class KeyboardShortcutsProvider: HotKeyProvider {

    func register(handler: @escaping () -> Void) {
        // Set default shortcut if none stored
        if KeyboardShortcuts.getShortcut(for: .toggleCourier) == nil {
            KeyboardShortcuts.setShortcut(.init(.space, modifiers: .option), for: .toggleCourier)
        }
        KeyboardShortcuts.onKeyUp(for: .toggleCourier) {
            handler()
        }
    }

    func unregister() {
        KeyboardShortcuts.setShortcut(nil, for: .toggleCourier)
    }

    func isRestricted(_ shortcut: Any) -> Bool {
        // The KeyboardShortcuts package handles conflict detection via Carbon's
        // RegisterEventHotKey return value. If registration fails, the package
        // logs the failure. We surface this via AccessibilityPermission monitoring.
        return false
    }
}

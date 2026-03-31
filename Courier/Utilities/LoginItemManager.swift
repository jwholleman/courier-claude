import Foundation
import ServiceManagement

/// Manages launch-at-login registration via SMAppService.
/// Stores user intent in UserDefaults separately from system registration state,
/// so we can re-register if the system state is lost (e.g., app moved/replaced).
@MainActor
final class LoginItemManager {

    static let shared = LoginItemManager()

    private init() {}

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func enable() throws {
        try SMAppService.mainApp.register()
    }

    func disable() throws {
        try SMAppService.mainApp.unregister()
    }

    /// Checks if user intent matches system state and re-registers if needed.
    /// Call at app launch to recover from app replacement in /Applications.
    func syncIfNeeded(userIntent: Bool) {
        guard userIntent else { return }
        if SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
    }
}

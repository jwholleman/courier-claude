import AppKit
import Foundation
import Observation

/// Owns a `ServiceRegistry` and coordinates query dispatch.
/// Runs dispatch asynchronously so the UI remains responsive.
@MainActor
final class ServiceDispatcher {

    private let registry: ServiceRegistry

    nonisolated private static let crashRecoveryKey = "pendingClipboardRestore"

    init(registry: ServiceRegistry) {
        self.registry = registry
    }

    /// Call at launch — if a previous dispatch crashed mid-restore, inform the user.
    func checkCrashRecovery() {
        if UserDefaults.standard.bool(forKey: Self.crashRecoveryKey) {
            UserDefaults.standard.removeObject(forKey: Self.crashRecoveryKey)
            Task { await NotificationHelper.showToast("Courier may not have restored your clipboard from the last session.") }
        }
    }

    /// Dispatches `query` to the provider for `serviceType`.
    func dispatch(query: String, serviceType: ServiceType) async throws {
        guard let provider = registry.provider(for: serviceType) else { return }
        try await provider.dispatch(query: query)
    }

    /// Returns the service type for an exact-match slash command, if any.
    func serviceType(forSlashCommand command: String) -> ServiceType? {
        registry.serviceType(forSlashCommand: command)
    }

    nonisolated static func markClipboardRestorePending() {
        UserDefaults.standard.set(true, forKey: crashRecoveryKey)
    }

    nonisolated static func clearClipboardRestorePending() {
        UserDefaults.standard.removeObject(forKey: crashRecoveryKey)
    }
}

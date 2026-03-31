import AppKit
import Foundation
import Observation

/// Owns a `ServiceRegistry` and coordinates query dispatch.
/// Runs dispatch asynchronously so the UI remains responsive.
@MainActor
final class ServiceDispatcher {

    private let registry: ServiceRegistry

    init(registry: ServiceRegistry) {
        self.registry = registry
    }

    /// Dispatches `query` to the provider for `serviceType`.
    /// On success the caller may update last-used service via `AppSettings`.
    func dispatch(query: String, serviceType: ServiceType) async throws {
        guard let provider = registry.provider(for: serviceType) else { return }
        try await provider.dispatch(query: query)
    }

    /// Returns the service type for an exact-match slash command, if any.
    func serviceType(forSlashCommand command: String) -> ServiceType? {
        registry.serviceType(forSlashCommand: command)
    }
}

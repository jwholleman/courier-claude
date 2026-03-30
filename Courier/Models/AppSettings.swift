import Foundation
import Observation

@Observable
@MainActor
final class AppSettings {

    // MARK: - Settings Version

    private static let currentVersion = 1
    private static let defaults = UserDefaults.standard

    // MARK: - Properties (cached from UserDefaults)

    var lastUsedService: ServiceType {
        didSet { save() }
    }

    var disabledServices: Set<ServiceType> {
        didSet { save() }
    }

    var hotKeyShortcut: String? {
        didSet { save() }
    }

    var launchAtLogin: Bool {
        didSet { save() }
    }

    // MARK: - Derived

    /// The effective selected service — falls back to first enabled if last-used is disabled.
    var effectiveSelectedService: ServiceType {
        if !disabledServices.contains(lastUsedService) {
            return lastUsedService
        }
        // Fall back to first enabled in display order
        return ServiceType.displayOrder.first(where: { !disabledServices.contains($0) }) ?? .claude
    }

    // MARK: - Init

    init() {
        // Migrate settings if needed
        let storedVersion = Self.defaults.integer(forKey: "settingsVersion")
        if storedVersion < Self.currentVersion {
            AppSettings.migrate(from: storedVersion, to: Self.currentVersion)
        }

        // Load cached values
        let rawService = Self.defaults.string(forKey: "lastUsedService") ?? ""
        lastUsedService = ServiceType(rawValue: rawService) ?? .claude

        let rawDisabled = Self.defaults.stringArray(forKey: "disabledServices") ?? []
        disabledServices = Set(rawDisabled.compactMap { ServiceType(rawValue: $0) })

        hotKeyShortcut = Self.defaults.string(forKey: "hotKeyShortcut")
        launchAtLogin = Self.defaults.bool(forKey: "launchAtLogin")
    }

    // MARK: - Persistence

    func save() {
        Self.defaults.set(lastUsedService.rawValue, forKey: "lastUsedService")
        Self.defaults.set(disabledServices.map(\.rawValue), forKey: "disabledServices")
        Self.defaults.set(hotKeyShortcut, forKey: "hotKeyShortcut")
        Self.defaults.set(launchAtLogin, forKey: "launchAtLogin")
        Self.defaults.set(Self.currentVersion, forKey: "settingsVersion")
    }

    // MARK: - Migration

    private static func migrate(from oldVersion: Int, to newVersion: Int) {
        // v0 -> v1: no existing keys, nothing to migrate
        defaults.set(newVersion, forKey: "settingsVersion")
    }
}

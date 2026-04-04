import AppKit
import Foundation
import Observation

enum AppTheme: String, CaseIterable {
    case light, dark, system

    var nsAppearance: NSAppearance? {
        switch self {
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        case .system: return nil
        }
    }

    var displayName: String { rawValue.capitalized }
}

@Observable
@MainActor
final class AppSettings {

    // MARK: - Settings Version

    private static let currentVersion = 2
    private static let defaults = UserDefaults.standard

    // MARK: - Properties (cached from UserDefaults)

    var lastUsedService: ServiceType {
        didSet { save() }
    }

    var disabledServices: Set<ServiceType> {
        didSet {
            normalizeDisabledServices()
            save()
        }
    }

    var serviceOrder: [ServiceType] {
        didSet {
            normalizeServiceOrder()
            save()
        }
    }

    var hotKeyShortcut: String? {
        didSet { save() }
    }

    var launchAtLogin: Bool {
        didSet { save() }
    }

    var hasCompletedSetup: Bool {
        didSet { save() }
    }

    /// User-overridden slash commands keyed by ServiceType.rawValue.
    /// nil entry = use defaults from SlashCommand.all.
    var customSlashCommands: [String: [String]] {
        didSet { save() }
    }

    /// User-overridden keystroke per LLM service. Key = ServiceType.rawValue, value = LLMKeystroke rawValue string.
    var keystrokeOverrides: [String: String] {
        didSet { save() }
    }

    var theme: AppTheme {
        didSet {
            save()
            NSApp.appearance = theme.nsAppearance
        }
    }

    // MARK: - Derived

    /// The effective selected service — falls back to first enabled if last-used is disabled.
    var effectiveSelectedService: ServiceType {
        enabledServices.first(where: { $0 == lastUsedService }) ?? enabledServices.first ?? .claude
    }

    var orderedServices: [ServiceType] {
        serviceOrder
    }

    var enabledServices: [ServiceType] {
        orderedServices.filter { !disabledServices.contains($0) }
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

        let rawOrder = Self.defaults.stringArray(forKey: "serviceOrder") ?? []
        serviceOrder = rawOrder.compactMap { ServiceType(rawValue: $0) }

        hotKeyShortcut = Self.defaults.string(forKey: "hotKeyShortcut")
        launchAtLogin = Self.defaults.bool(forKey: "launchAtLogin")
        hasCompletedSetup = Self.defaults.bool(forKey: "hasCompletedSetup")
        customSlashCommands = (Self.defaults.dictionary(forKey: "customSlashCommands") as? [String: [String]]) ?? [:]
        keystrokeOverrides = (Self.defaults.dictionary(forKey: "keystrokeOverrides") as? [String: String]) ?? [:]
        let rawTheme = Self.defaults.string(forKey: "theme") ?? "system"
        theme = AppTheme(rawValue: rawTheme) ?? .system

        serviceOrder = normalizedServiceOrder(from: serviceOrder)
        disabledServices = disabledServices.intersection(Set(ServiceType.allCases))
        if enabledServices.isEmpty, let fallback = orderedServices.first {
            disabledServices.remove(fallback)
        }
        if disabledServices.contains(lastUsedService) {
            lastUsedService = enabledServices.first ?? .claude
        }
    }

    func applyTheme() {
        NSApp.appearance = theme.nsAppearance
    }

    func moveService(from source: Int, to destination: Int) {
        guard orderedServices.indices.contains(source) else { return }

        var reordered = orderedServices
        let service = reordered.remove(at: source)
        let targetIndex = min(max(destination, 0), reordered.count)
        reordered.insert(service, at: targetIndex)
        serviceOrder = reordered
    }

    // MARK: - Persistence

    func save() {
        Self.defaults.set(lastUsedService.rawValue, forKey: "lastUsedService")
        Self.defaults.set(disabledServices.map(\.rawValue), forKey: "disabledServices")
        Self.defaults.set(orderedServices.map(\.rawValue), forKey: "serviceOrder")
        Self.defaults.set(hotKeyShortcut, forKey: "hotKeyShortcut")
        Self.defaults.set(launchAtLogin, forKey: "launchAtLogin")
        Self.defaults.set(hasCompletedSetup, forKey: "hasCompletedSetup")
        Self.defaults.set(customSlashCommands, forKey: "customSlashCommands")
        Self.defaults.set(keystrokeOverrides, forKey: "keystrokeOverrides")
        Self.defaults.set(theme.rawValue, forKey: "theme")
        Self.defaults.set(Self.currentVersion, forKey: "settingsVersion")
    }

    // MARK: - Migration

    private static func migrate(from oldVersion: Int, to newVersion: Int) {
        if oldVersion < 2 {
            // ChatGPT previously relied on URL routing and some installs persisted "none"
            // as the effective behavior. Migrate those installs to the current expected
            // default of Cmd+N so launcher submissions open a fresh conversation again.
            var overrides = defaults.dictionary(forKey: "keystrokeOverrides") as? [String: String] ?? [:]
            if overrides[ServiceType.chatgpt.rawValue] == LLMKeystroke.none.rawValue {
                overrides[ServiceType.chatgpt.rawValue] = LLMKeystroke.cmdN.rawValue
                defaults.set(overrides, forKey: "keystrokeOverrides")
            }
        }

        defaults.set(newVersion, forKey: "settingsVersion")
    }

    private func normalizeServiceOrder() {
        let normalizedOrder = normalizedServiceOrder(from: serviceOrder)
        if normalizedOrder != serviceOrder {
            serviceOrder = normalizedOrder
            return
        }

        if disabledServices.contains(lastUsedService) {
            lastUsedService = enabledServices.first ?? .claude
        }
    }

    private func normalizeDisabledServices() {
        let validDisabled = disabledServices.intersection(Set(ServiceType.allCases))
        if validDisabled != disabledServices {
            disabledServices = validDisabled
            return
        }

        if enabledServices.isEmpty {
            if let fallback = orderedServices.first {
                disabledServices.remove(fallback)
            }
            return
        }

        if disabledServices.contains(lastUsedService) {
            lastUsedService = enabledServices.first ?? .claude
        }
    }

    private func normalizedServiceOrder(from services: [ServiceType]) -> [ServiceType] {
        var seen = Set<ServiceType>()
        let validServices = services.filter { service in
            ServiceType.allCases.contains(service) && seen.insert(service).inserted
        }

        return validServices + ServiceType.displayOrder.filter { seen.insert($0).inserted }
    }
}

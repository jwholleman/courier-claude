import XCTest
@testable import Courier

@MainActor
final class AppSettingsTests: XCTestCase {

    override func setUp() {
        // Clear UserDefaults for each test to avoid cross-test contamination
        let defaults = UserDefaults.standard
        ["lastUsedService", "disabledServices", "serviceOrder", "hotKeyShortcut", "launchAtLogin", "settingsVersion"]
            .forEach { defaults.removeObject(forKey: $0) }
    }

    func testAlwaysHasSelection() {
        let settings = AppSettings()
        // effectiveSelectedService must never be nil (it's non-optional) and must be enabled
        let service = settings.effectiveSelectedService
        XCTAssertFalse(settings.disabledServices.contains(service))
    }

    func testDisabledServiceFallback() {
        let settings = AppSettings()
        settings.lastUsedService = .claude
        settings.disabledServices = [.claude]
        let effective = settings.effectiveSelectedService
        XCTAssertNotEqual(effective, .claude)
        XCTAssertFalse(settings.disabledServices.contains(effective))
    }

    func testDisablingLastUsedServiceUpdatesFallbackSelection() {
        let settings = AppSettings()
        settings.lastUsedService = .google
        settings.disabledServices = [.google]

        XCTAssertEqual(settings.lastUsedService, .claude)
        XCTAssertEqual(settings.effectiveSelectedService, .claude)
    }

    func testDisablingLastUsedServiceFallsBackToFirstEnabledInCustomOrder() {
        let settings = AppSettings()
        settings.serviceOrder = [.google, .perplexity, .claude, .chatgpt, .gemini, .kagi, .duckduckgo]
        settings.lastUsedService = .google
        settings.disabledServices = [.google]

        XCTAssertEqual(settings.lastUsedService, .perplexity)
        XCTAssertEqual(settings.effectiveSelectedService, .perplexity)
    }

    func testSettingsRoundTrip() {
        let settings = AppSettings()
        settings.lastUsedService = .perplexity
        settings.save()

        let reloaded = AppSettings()
        XCTAssertEqual(reloaded.lastUsedService, .perplexity)
    }

    func testServiceOrderRoundTrip() {
        let settings = AppSettings()
        settings.serviceOrder = [.google, .claude, .chatgpt, .gemini, .perplexity, .kagi, .duckduckgo]
        settings.save()

        let reloaded = AppSettings()
        XCTAssertEqual(reloaded.orderedServices.first, .google)
        XCTAssertEqual(reloaded.orderedServices[1], .claude)
    }

    func testDefaultServiceIsClaude() {
        let settings = AppSettings()
        XCTAssertEqual(settings.lastUsedService, .claude)
    }

    func testDisabledServicesRoundTrip() {
        let settings = AppSettings()
        settings.disabledServices = [.kagi, .google]
        settings.save()

        let reloaded = AppSettings()
        XCTAssertTrue(reloaded.disabledServices.contains(.kagi))
        XCTAssertTrue(reloaded.disabledServices.contains(.google))
        XCTAssertFalse(reloaded.disabledServices.contains(.claude))
    }

    func testAllDisabledFallsBackToClaude() {
        let settings = AppSettings()
        // Disable everything
        settings.disabledServices = Set(ServiceType.allCases)
        // The settings model keeps at least one service enabled.
        XCTAssertEqual(settings.enabledServices, [.claude])
        XCTAssertEqual(settings.effectiveSelectedService, .claude)
    }

    func testAllDisabledFallsBackToFirstServiceInCustomOrder() {
        let settings = AppSettings()
        settings.serviceOrder = [.google, .claude, .chatgpt, .gemini, .perplexity, .kagi, .duckduckgo]
        settings.disabledServices = Set(ServiceType.allCases)

        XCTAssertEqual(settings.enabledServices, [.google])
        XCTAssertEqual(settings.effectiveSelectedService, .google)
    }
}

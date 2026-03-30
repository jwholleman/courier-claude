import XCTest
@testable import Courier

@MainActor
final class AppSettingsTests: XCTestCase {

    override func setUp() {
        // Clear UserDefaults for each test to avoid cross-test contamination
        let defaults = UserDefaults.standard
        ["lastUsedService", "disabledServices", "hotKeyShortcut", "launchAtLogin", "settingsVersion"]
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

    func testSettingsRoundTrip() {
        let settings = AppSettings()
        settings.lastUsedService = .perplexity
        settings.save()

        let reloaded = AppSettings()
        XCTAssertEqual(reloaded.lastUsedService, .perplexity)
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
        // effectiveSelectedService falls back to .claude (first in displayOrder)
        XCTAssertEqual(settings.effectiveSelectedService, .claude)
    }
}

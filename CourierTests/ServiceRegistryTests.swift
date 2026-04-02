import XCTest
@testable import Courier

@MainActor
final class ServiceRegistryTests: XCTestCase {

    var registry: ServiceRegistry!

    override func setUp() {
        registry = ServiceRegistry()
    }

    func testLookupByType() {
        for type in ServiceType.allCases {
            XCTAssertNotNil(registry.provider(for: type), "Missing provider for \(type)")
        }
    }

    func testLookupBySlashCommand_exactMatch() {
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/cl"), .claude)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/claude"), .claude)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/cc"), .claudeCode)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/claudecode"), .claudeCode)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/ch"), .chatgpt)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/chatgpt"), .chatgpt)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/k"), .kagi)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/g"), .google)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/yt"), .youtube)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/youtube"), .youtube)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/d"), .duckduckgo)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/ddg"), .duckduckgo)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/ge"), .gemini)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/p"), .perplexity)
    }

    func testLookupBySlashCommand_partialNoMatch() {
        // "/c" is NOT a valid command — must not match "/cl" or "/claude"
        XCTAssertNil(registry.serviceType(forSlashCommand: "/c"))
        XCTAssertNil(registry.serviceType(forSlashCommand: "/x"))
        XCTAssertNil(registry.serviceType(forSlashCommand: "/goo"))
    }

    func testLookupBySlashCommand_caseInsensitive() {
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/CL"), .claude)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/Claude"), .claude)
    }
}

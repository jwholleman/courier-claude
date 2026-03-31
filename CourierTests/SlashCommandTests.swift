import XCTest
@testable import Courier

@MainActor
final class SlashCommandTests: XCTestCase {

    var registry: ServiceRegistry!

    override func setUp() {
        registry = ServiceRegistry()
    }

    func testAllFourteenCommands() {
        let expected: [(String, ServiceType)] = [
            ("/cl", .claude),       ("/claude", .claude),
            ("/ch", .chatgpt),      ("/chatgpt", .chatgpt),
            ("/ge", .gemini),       ("/gemini", .gemini),
            ("/p", .perplexity),    ("/perplexity", .perplexity),
            ("/k", .kagi),          ("/kagi", .kagi),
            ("/g", .google),        ("/google", .google),
            ("/d", .duckduckgo),    ("/ddg", .duckduckgo),
        ]
        for (command, expectedType) in expected {
            XCTAssertEqual(registry.serviceType(forSlashCommand: command), expectedType,
                           "Command \(command) should map to \(expectedType)")
        }
    }

    func testCaseInsensitive() {
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/CL"), .claude)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/CHATGPT"), .chatgpt)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/Google"), .google)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/DDG"), .duckduckgo)
    }

    func testPartialNoMatch() {
        XCTAssertNil(registry.serviceType(forSlashCommand: "/c"))
        XCTAssertNil(registry.serviceType(forSlashCommand: "/goo"))
        XCTAssertNil(registry.serviceType(forSlashCommand: "/per"))
        XCTAssertNil(registry.serviceType(forSlashCommand: "/x"))
    }

    func testLocaleInsensitiveLowercasing() {
        // Turkish locale maps "I" -> "ı" not "i" — must use Locale("en")
        let candidate = "/CL".lowercased(with: Locale(identifier: "en"))
        XCTAssertEqual(candidate, "/cl")
    }

    func testSlashPrefixMatchesMultiple() {
        // "/c" prefix matches both Claude (/cl) and ChatGPT (/ch) — used for overlay highlighting
        let prefix = "/c"
        let matches = SlashCommand.all.filter { $0.command.hasPrefix(prefix) }.map { $0.serviceType }
        XCTAssertTrue(matches.contains(.claude))
        XCTAssertTrue(matches.contains(.chatgpt))
    }

    func testSlashPrefixNarrows() {
        // "/cl" prefix matches only Claude
        let prefix = "/cl"
        let matches = SlashCommand.all.filter { $0.command.hasPrefix(prefix) }.map { $0.serviceType }
        XCTAssertEqual(Set(matches), Set([ServiceType.claude]))
    }
}

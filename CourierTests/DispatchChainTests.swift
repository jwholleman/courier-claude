import XCTest
@testable import Courier

@MainActor
final class DispatchChainTests: XCTestCase {

    // MARK: - URL construction

    func testGoogleURLStructure() {
        let url = SearchService.buildURL(base: "https://www.google.com/search?q=", query: "swift async")
        XCTAssertNotNil(url)
        let str = url?.absoluteString ?? ""
        XCTAssertTrue(str.hasPrefix("https://www.google.com/search?q="))
        XCTAssertTrue(str.contains("swift"))
        XCTAssertTrue(str.contains("async"))
    }

    func testDuckDuckGoURLStructure() {
        let url = SearchService.buildURL(base: "https://duckduckgo.com/?q=", query: "test query")
        XCTAssertNotNil(url)
        let str = url?.absoluteString ?? ""
        XCTAssertTrue(str.hasPrefix("https://duckduckgo.com/?q="))
    }

    func testKagiURLStructure() {
        let url = SearchService.buildURL(base: "https://kagi.com/search?q=", query: "hello world")
        XCTAssertNotNil(url)
        let str = url?.absoluteString ?? ""
        XCTAssertTrue(str.hasPrefix("https://kagi.com/search?q="))
    }

    func testYouTubeURLStructure() {
        let url = SearchService.buildURL(base: "https://www.youtube.com/results?search_query=", query: "hello world")
        XCTAssertNotNil(url)
        let str = url?.absoluteString ?? ""
        XCTAssertTrue(str.hasPrefix("https://www.youtube.com/results?search_query="))
    }

    func testSpecialCharsInSearchURL() {
        let url = SearchService.buildURL(base: "https://www.google.com/search?q=", query: "C++ programming & design")
        XCTAssertNotNil(url)
        let str = url?.absoluteString ?? ""
        // Raw & and + must not appear after the base param
        let afterQ = str.components(separatedBy: "?q=").dropFirst().first ?? ""
        XCTAssertFalse(afterQ.contains("&"), "& in query must be encoded")
        XCTAssertFalse(afterQ.contains("+"), "+ in query must be encoded")
    }

    // MARK: - ServiceRegistry

    func testRegistryHasAllServices() {
        let registry = ServiceRegistry()
        for service in ServiceType.allCases {
            XCTAssertNotNil(registry.provider(for: service), "Missing provider for \(service.rawValue)")
        }
    }

    func testSlashCommandLookup() {
        let registry = ServiceRegistry()
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/cl"), .claude)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/cc"), .claudeCode)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/g"), .google)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/yt"), .youtube)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/ddg"), .duckduckgo)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/p"), .perplexity)
        XCTAssertNil(registry.serviceType(forSlashCommand: "/unknown"))
    }

    func testSlashCommandCaseInsensitive() {
        let registry = ServiceRegistry()
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/CL"), .claude)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/Google"), .google)
    }

    // MARK: - ServiceType configuration

    func testNewConversationKeystroke() {
        XCTAssertEqual(ServiceType.claude.newConversationKeystroke, .shiftCmdO)  // Verified: Shift+Cmd+O
        XCTAssertEqual(ServiceType.chatgpt.newConversationKeystroke, .cmdN)      // Start a fresh chat before pasting
        XCTAssertEqual(ServiceType.perplexity.newConversationKeystroke, .none)
    }

    func testClipboardRestoreDelayPositive() {
        for service in ServiceType.allCases {
            XCTAssertGreaterThan(service.clipboardRestoreDelay, 0, "Delay for \(service.rawValue) must be positive")
        }
    }

    // MARK: - Clipboard recovery

    func testClipboardSaveRestoreRoundTrip() {
        let pasteboard = NSPasteboard.general
        let original = "Original clipboard \(UUID().uuidString)"
        let replacement = "Replacement clipboard \(UUID().uuidString)"

        pasteboard.clearContents()
        pasteboard.setString(original, forType: .string)

        let saved = AppleScriptHelper.saveClipboardContents(pasteboard)
        XCTAssertNotNil(saved)

        pasteboard.clearContents()
        pasteboard.setString(replacement, forType: .string)
        AppleScriptHelper.restoreClipboardContents(pasteboard, items: saved ?? [])

        XCTAssertEqual(pasteboard.string(forType: .string), original)
    }

    func testCrashRecoveryFlagClearsAfterCheck() {
        ServiceDispatcher.markClipboardRestorePending()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "pendingClipboardRestore"))

        let dispatcher = ServiceDispatcher(registry: ServiceRegistry())
        dispatcher.checkCrashRecovery()

        XCTAssertFalse(UserDefaults.standard.bool(forKey: "pendingClipboardRestore"))
    }

    func testSavingEmptyClipboardReturnsNil() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let saved = AppleScriptHelper.saveClipboardContents(pasteboard)

        XCTAssertNil(saved)
    }
}

import XCTest
@testable import Courier

final class URLEncodingTests: XCTestCase {

    func testAmpersandEncoded() {
        let encoded = SearchService.encodeQuery("a&b")
        XCTAssertFalse(encoded.contains("&"), "& must be percent-encoded")
        XCTAssertTrue(encoded.contains("%26"))
    }

    func testEqualsEncoded() {
        let encoded = SearchService.encodeQuery("a=b")
        XCTAssertFalse(encoded.contains("="), "= must be percent-encoded")
        XCTAssertTrue(encoded.contains("%3D"))
    }

    func testPlusEncoded() {
        let encoded = SearchService.encodeQuery("a+b")
        XCTAssertFalse(encoded.contains("+"), "+ must be percent-encoded")
        XCTAssertTrue(encoded.contains("%2B"))
    }

    func testHashEncoded() {
        let encoded = SearchService.encodeQuery("a#b")
        XCTAssertFalse(encoded.contains("#"), "# must be percent-encoded")
        XCTAssertTrue(encoded.contains("%23"))
    }

    func testSpaceEncoded() {
        let encoded = SearchService.encodeQuery("hello world")
        XCTAssertFalse(encoded.contains(" "), "space must be encoded")
    }

    func testEmojiEncoded() {
        let encoded = SearchService.encodeQuery("test 🔥")
        XCTAssertNotNil(encoded)
        XCTAssertFalse(encoded.isEmpty)
    }

    func testCJKEncoded() {
        let encoded = SearchService.encodeQuery("日本語テスト")
        XCTAssertNotNil(encoded)
        XCTAssertFalse(encoded.isEmpty)
    }

    func testInjectionPrevented() {
        // "test&q=injected" must NOT produce a spurious q= parameter
        let url = SearchService.buildURL(base: "https://google.com/search?q=", query: "test&q=injected")
        XCTAssertNotNil(url)
        guard let url else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let qParams = components?.queryItems?.filter { $0.name == "q" }
        XCTAssertEqual(qParams?.count, 1, "Should have exactly one q= parameter")
    }

    func testPercentEncoding100Percent() {
        let encoded = SearchService.encodeQuery("100% done")
        XCTAssertFalse(encoded.contains(" "), "space must be encoded")
    }
}

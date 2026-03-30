# Phase 4: Slash Commands

> Read `courier-architecture.md` first if you haven't already.

---

## Task 4.1 — Slash command parsing

- Detect "/" as first character -> enter slash mode
- **Only trigger on typed `/`, not pasted text**: If the user pastes text starting with `/cl ` (e.g., a file path like `/clients/data`), it should NOT trigger a service switch. Track whether the `/` was typed via keyboard (monitor `NSTextView` delegate's `shouldChangeText` or `keyDown`) vs. inserted by paste. Only enter slash mode on typed input.
- Parse on spacebar: **exact match only** against registered commands (case-insensitive, using explicit `Locale(identifier: "en")` to avoid Turkish-i and similar locale bugs with `.lowercased()`)
- `/c ` -> no match (stays as typed text). `/cl ` -> matches Claude. `/claude ` -> matches Claude.
- On match: switch selected service (service bar icon updates), remove slash text from input
- On no match: leave text as-is, exit slash mode
- Defaults: /cl, /claude, /ch, /chatgpt, /k, /kagi, /g, /google, /d, /ddg, /ge, /gemini, /p, /perplexity
- Only parsed when slash is the first character in the input (not mid-text)
- Verify: test ALL 14 slash commands for ALL 7 services individually:
  - `/cl ` and `/claude ` -> selects Claude, service bar updates
  - `/ch ` and `/chatgpt ` -> selects ChatGPT, service bar updates
  - `/k ` and `/kagi ` -> selects Kagi, service bar updates
  - `/g ` and `/google ` -> selects Google, service bar updates
  - `/d ` and `/ddg ` -> selects DuckDuckGo, service bar updates
  - `/ge ` and `/gemini ` -> selects Gemini, service bar updates
  - `/p ` and `/perplexity ` -> selects Perplexity, service bar updates
  - `/c ` -> no match, text stays
  - `/x ` -> no match, text stays
  - `/CL ` -> matches Claude (case-insensitive)
  - `hello /cl ` -> no match (slash not at start)
- **Required imports**: No new imports needed — slash command logic lives in existing files. `Locale(identifier:)` requires `import Foundation` (already present in `ServiceRegistry.swift`).
- Files modified: `LauncherViewModel.swift` (slash command detection/parsing), `QueryInputView.swift` (typed vs. pasted detection), `ServiceRegistry.swift` (slash command lookup), `CourierTests/ServiceRegistryTests.swift` (all 14 slash command tests)
- **Commit**: `git commit -m "Phase 4 Task 4.1: Slash command parsing with exact match, typed-only detection"`

---

## Task 4.2 — Slash command overlay UI

- "Switch" state on service buttons: replace the service icon with the **shortest** slash command text for that service (e.g., "/cl" for Claude, "/ch" for ChatGPT, "/k" for Kagi). Display as a label in `.systemFont(ofSize: 11, weight: .medium)` centered within the 36x36pt button. The icon is hidden, replaced by the text. Use `.secondaryLabelColor` for non-matching text and `.labelColor` for matching.
- Activate when "/" mode is active (first char is "/" and no space yet)
- Highlight (visually distinguish) services whose slash commands match the current typed prefix — matching buttons use full opacity + accent background (same as selected state), non-matching buttons dim to 40% opacity
- As user types more characters, non-matching services dim further
- For services with long slash commands (e.g., "/perplexity" at 12 chars), truncate display to the short form ("/p") in the button. The full command is still accepted in the text field.
- Verify: "/" shows text overlays on all buttons (icons hidden), "/c" highlights Claude AND ChatGPT, "/cl" highlights only Claude, VoiceOver announces "Claude matching" / "ChatGPT matching" state changes, long commands display correctly
- Files modified: `ServiceButton.swift` (switch state with slash text overlay), `ServiceBar.swift` (slash mode highlighting), `LauncherViewModel.swift` (isSlashMode, slashPrefix state)
- **Commit**: `git commit -m "Phase 4 Task 4.2: Slash command overlay UI with prefix highlighting"`

---

## Phase 4 Test Skeleton

```swift
// CourierTests/SlashCommandTests.swift
import XCTest
@testable import Courier

final class SlashCommandTests: XCTestCase {

    var registry: ServiceRegistry!

    override func setUp() {
        registry = ServiceRegistry()
    }

    func testAllFourteenCommands() {
        // Test every registered slash command maps to the correct service
        let expected: [(String, ServiceType)] = [
            ("/cl", .claude), ("/claude", .claude),
            ("/ch", .chatgpt), ("/chatgpt", .chatgpt),
            ("/ge", .gemini), ("/gemini", .gemini),
            ("/p", .perplexity), ("/perplexity", .perplexity),
            ("/k", .kagi), ("/kagi", .kagi),
            ("/g", .google), ("/google", .google),
            ("/d", .duckduckgo), ("/ddg", .duckduckgo),
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
    }

    func testPartialNoMatch() {
        XCTAssertNil(registry.serviceType(forSlashCommand: "/c"))
        XCTAssertNil(registry.serviceType(forSlashCommand: "/goo"))
        XCTAssertNil(registry.serviceType(forSlashCommand: "/per"))
    }

    func testMidTextNoMatch() {
        // Slash commands only valid at start of input — this test verifies
        // the ViewModel logic, not the registry (registry just does lookup)
        // ViewModel test: "hello /cl " should NOT trigger slash mode
    }

    func testPastedSlashNoTrigger() {
        // Pasting "/cl " should NOT trigger slash command
        // This is a ViewModel-level test using the isPasting flag
    }
}
```

---

## Phase 4 Build Verification

```bash
xcodebuild -scheme Courier -destination 'platform=macOS' build && xcodebuild -scheme CourierTests -destination 'platform=macOS' test 2>&1 | tail -20
```

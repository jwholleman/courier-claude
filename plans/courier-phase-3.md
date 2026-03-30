# Phase 3: Service Dispatching

> Read `courier-architecture.md` first if you haven't already.

---

## Task 3.1 — Search service dispatch

- `SearchService` implementation: URL-encode query with a **custom `CharacterSet`** — do NOT use `.urlQueryAllowed` directly, as it does not encode `&`, `=`, or `+`. These characters will corrupt URL query parameters (e.g., `test&q=injected` would add a spurious `q` parameter). Create a custom set:
  ```swift
  var allowed = CharacterSet.urlQueryAllowed
  allowed.remove(charactersIn: "&=+#")
  query.addingPercentEncoding(withAllowedCharacters: allowed)
  ```
- Open in default browser via `NSWorkspace.shared.open(url)`
- Test URL encoding with: `hello world`, `a&b`, `a=b`, `a+b`, `emoji 🔥`, `日本語`, `100% done`, `test&q=injected`
- Close panel on submit, focus moves to browser
- **Guard URL construction**: If `URL(string:)` returns `nil` after encoding, copy query to clipboard and show notification. If `NSWorkspace.shared.open()` returns `false`, show notification "Couldn't open browser. Query copied to clipboard."
- **Required imports**: `SearchService.swift` needs `import AppKit` (for `NSWorkspace`) and `import Foundation`.
- Verify: test with all 3 search engines (Google, Kagi, DDG), correct URLs open, special characters encoded correctly, `test&q=injected` does NOT produce a spurious `q` param, browser-fail notification works, URL-nil notification works
- Files created: `SearchService.swift`, `CourierTests/URLEncodingTests.swift`. Files modified: `ServiceRegistry.swift` (register search services), `LauncherViewModel.swift` (wire submit to dispatch)
- **Commit**: `git commit -m "Phase 3 Task 3.1: Search service dispatch with custom URL encoding"`

---

## Task 3.2 — LLM dispatch (browser fallback)

- `LLMService` implementation: check native app via `NSWorkspace`
- If not installed -> open browser URL
- For Perplexity: use `?q=QUERY` param (auto-submits on web). For Claude/ChatGPT/Gemini: open base URL + copy query to clipboard + show notification "Query copied to clipboard — paste into the conversation"
- **Required imports**: `LLMService.swift` needs `import AppKit` and `import Foundation`.
- Verify: with no native apps installed, correct browser URLs open, clipboard contains query, notification shown
- Files created: `LLMService.swift`. Files modified: `ServiceRegistry.swift` (register LLM services)
- **Commit**: `git commit -m "Phase 3 Task 3.2: LLM dispatch with browser fallback"`

---

## Task 3.3 — LLM dispatch (native app + AppleScript) with retry logic

- **Run entire dispatch on a background `DispatchQueue`**: `NSAppleScript` executes synchronously and the retry delays (0.3-1.0s) will freeze the UI if run on the main thread. Marshal UI updates (notifications, panel dismiss) back to `DispatchQueue.main`.
- **Concurrent dispatch protection**: Only one dispatch may be in flight at a time. If the user submits again while a previous dispatch is running (e.g., re-invokes Courier and submits before the first AppleScript completes), the new dispatch cancels the old dispatch's clipboard restore timer. The new dispatch takes ownership of clipboard save/restore. The old AppleScript keystroke sequence may still be running (AppleScript is not easily cancellable), but its clipboard restore is abandoned. Use a serial `DispatchQueue` for dispatch operations to avoid overlapping clipboard manipulation.
- `AppleScriptHelper` with retry mechanism:

  **Step 1 — Save clipboard (deep copy)**:
  `NSPasteboardItem` objects are proxies — they become **invalid** the moment you write new data to the pasteboard. You must read and store the raw data before modifying the clipboard:
  ```swift
  // Deep copy — items are invalidated when pasteboard changes
  let saved: [[(NSPasteboard.PasteboardType, Data)]] = pasteboard.pasteboardItems?.map { item in
      item.types.compactMap { type in
          guard let data = item.data(forType: type) else { return nil }
          return (type, data)
      }
  } ?? []
  ```
  Do NOT simply store `pasteboardItems` references — they will silently return nil after the pasteboard is modified, and clipboard restore will appear to succeed but restore nothing.
  **Size threshold**: If total clipboard data exceeds 50MB (e.g., user copied a large image), skip save/restore and log a warning. Don't hold 50MB+ in memory for a utility app. Check `NSPasteboard.general.changeCount` first — if clipboard is empty, skip save entirely.

  **Step 2 — Copy query to clipboard**

  **Step 3 — Activate target app** — two distinct code paths:
  - **App already running** (`NSRunningApplication.runningApplications(withBundleIdentifier:)` is non-empty): call `runningApp.activate()` on the first result. Do NOT use `NSWorkspace.shared.open(url)` — that opens a URL, not an app by bundle ID.
  - **App not running** (cold launch): use `NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())` where `appURL` comes from the cached `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)`. This launches the app without opening a specific URL.

  These are different APIs with different semantics. `NSWorkspace.open(URL)` is for browser/URL dispatch only (Task 3.1/3.2), not for app activation.

  **Step 4 — Verify frontmost app**: Use `NSWorkspace.didActivateApplicationNotification` (event-driven) rather than polling `frontmostApplication` in a loop. **Timeout: 10s for cold launch, 3s for warm launch.** Detect cold vs. warm: check `NSRunningApplication.runningApplications(withBundleIdentifier:)` — if the app is not in the list, it's a cold launch (Electron apps like ChatGPT/Claude can take 5-10s to cold start).

  **Step 5 — Send keystrokes via AppleScript**: Cmd+N (new conversation) then Cmd+V (paste) via System Events AppleScript. **Never interpolate user query text into AppleScript source code** — always paste from clipboard via keystroke. This prevents AppleScript injection if query contains `"` or `\` characters.

  **Per-app keystroke configuration**:
  ```swift
  enum LLMKeystroke {
      case cmdN      // Claude, ChatGPT: Cmd+N opens new conversation
      case cmdL      // Alternative: some apps use Cmd+L to focus input
      case none      // Skip new-conversation step, just paste
  }
  ```
  Initial values: Claude = `.cmdN`, ChatGPT = `.cmdN`, Perplexity = `.none` (pastes into existing input), Gemini = `.none` (browser-only). **These values must be verified during Human Checkpoint 2** — they cannot be tested without running the app against real targets. Add a short delay (0.3s) between Cmd+N and Cmd+V to let the new conversation UI appear.

  **Important — user-editable in Settings (Phase 6)**: These per-app keystroke values should be stored in `AppSettings` and exposed as editable dropdowns in the Settings window (Task 6.1). Target apps update their keyboard shortcuts across versions (e.g., Claude Desktop could change from Cmd+N to something else). Making this user-configurable avoids shipping hotfixes for every target app update.

  **Step 6 — Restore clipboard**: Wait 1.5s (not 0.5s — some apps like Claude desktop take 1-2s to process large pastes), then restore original clipboard contents. If Courier is re-invoked before restore completes, restore immediately first. **After restoring, zero the saved clipboard data** — use `Data.resetBytes(in:)` for text buffers, release image data references. Don't leave potentially sensitive clipboard contents (passwords, API keys the user copied before invoking Courier) in memory waiting for GC. **The 1.5s delay is a starting value** — it may need to be longer for some apps (Claude desktop with large text) or shorter for snappy apps. Make it a per-service configurable constant in `ServiceType`, not a magic number buried in `AppleScriptHelper`.

- **Permissions — two separate grants required**:
  - **Accessibility** (`AXIsProcessTrusted()`): required for global hotkey and sending keystrokes
  - **Automation** (per-app): macOS will prompt "Courier wants to control [App]" the first time AppleScript targets each app. This is a separate permission from Accessibility. Handle the case where Accessibility is granted but Automation is denied for a specific app — fall back to browser for that app only.
- If all retries fail: show notification "Couldn't paste into [App]. Query copied to clipboard. Opening in browser instead." -> fall back to browser
- If accessibility permission denied: show notification with button to open System Settings -> fall back to browser
- If automation permission denied for a specific app: show notification "Courier needs permission to control [App]. Query copied to clipboard." + open System Settings -> Privacy & Security -> Automation. Fall back to browser.
- **Required imports**: `AppleScriptHelper.swift` needs `import AppKit` and `import Foundation`. `ServiceDispatcher.swift` needs `import AppKit`, `import Foundation`, and `import Observation`. `NotificationHelper.swift` needs `import AppKit` and `import UserNotifications`.
- Verify: with Claude/ChatGPT/Perplexity apps installed, query pastes correctly, clipboard restored to original content, retry handles slow app launch, permission denial shows notification and falls back to browser, UI remains responsive during entire dispatch sequence (no freezing), automation permission prompt appears on first use per app, query containing `"` and `\` characters pastes correctly without AppleScript errors
- Files created: `AppleScriptHelper.swift`, `ServiceDispatcher.swift`, `NotificationHelper.swift`, `CourierTests/ClipboardTests.swift`, `CourierTests/DispatchChainTests.swift`. Files modified: `LLMService.swift` (integrate AppleScriptHelper)
- **Commit**: `git commit -m "Phase 3 Task 3.3: AppleScript dispatch with clipboard save/restore, retry, notifications"`

---

## Task 3.4 — Last-used service memory

- Save selected service on dispatch -> `AppSettings.lastUsedService` (UserDefaults — survives app restarts AND system reboots)
- Pre-select last-used on next launcher open (always a valid selection)
- If last-used service is now disabled: fall back to first enabled service in display order
- Verify: selection persists across invocations, app restarts, AND computer reboots. Disabling last-used service results in valid fallback.
- Files modified: `AppSettings.swift` (add lastUsedService with fallback), `LauncherViewModel.swift` (pre-select last-used on open), `CourierTests/AppSettingsTests.swift` (add persistence tests)
- **Commit**: `git commit -m "Phase 3 Task 3.4: Last-used service persistence with disabled fallback"`

---

## Phase 3 Test Skeletons

```swift
// CourierTests/URLEncodingTests.swift
import XCTest
@testable import Courier

final class URLEncodingTests: XCTestCase {

    func testAmpersandEncoded() {
        // "a&b" -> "a%26b" in the query parameter
        let encoded = SearchService.encodeQuery("a&b")
        XCTAssertFalse(encoded.contains("&"))
    }

    func testEqualsEncoded() {
        let encoded = SearchService.encodeQuery("a=b")
        XCTAssertFalse(encoded.contains("="))
    }

    func testPlusEncoded() {
        let encoded = SearchService.encodeQuery("a+b")
        XCTAssertFalse(encoded.contains("+"))
    }

    func testHashEncoded() {
        let encoded = SearchService.encodeQuery("a#b")
        XCTAssertFalse(encoded.contains("#"))
    }

    func testEmojiEncoded() {
        let encoded = SearchService.encodeQuery("test 🔥")
        XCTAssertNotNil(encoded)
    }

    func testCJKEncoded() {
        let encoded = SearchService.encodeQuery("日本語テスト")
        XCTAssertNotNil(encoded)
    }

    func testInjectionPrevented() {
        // "test&q=injected" must NOT produce a spurious q= parameter
        let url = SearchService.buildURL(base: "https://google.com/search?q=", query: "test&q=injected")
        XCTAssertNotNil(url)
        // The URL should have exactly one "q=" parameter
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let qParams = components?.queryItems?.filter { $0.name == "q" }
        XCTAssertEqual(qParams?.count, 1)
    }
}

// CourierTests/DispatchChainTests.swift
import XCTest
@testable import Courier

final class DispatchChainTests: XCTestCase {

    func testSearchDispatchConstructsCorrectURL() {
        // Verify URL structure for each search engine
    }

    func testLLMDispatchFallsToBrowserWhenNotInstalled() {
        // Mock NSWorkspace.urlForApplication returning nil
        // Verify browser URL is opened instead
    }

    func testClipboardSaveRestoreCycle() {
        // Save clipboard -> modify -> restore -> verify original contents
    }

    func testConcurrentDispatchCancelsFirstRestore() {
        // First dispatch in flight -> second dispatch starts
        // Verify first's restore timer is cancelled
    }

    func testLargeClipboardSkipsSave() {
        // Clipboard > 50MB -> verify save is skipped with warning
    }
}
```

---

## Phase 3 Build Verification

```bash
xcodebuild -scheme Courier -destination 'platform=macOS' build && xcodebuild -scheme CourierTests -destination 'platform=macOS' test 2>&1 | tail -20
```

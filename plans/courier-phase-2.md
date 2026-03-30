# Phase 2: Core Launcher UI

> Read `courier-architecture.md` first if you haven't already.

---

## Task 2.1a — CourierTextView (NSTextView subclass with placeholder)

This is the first of four sub-tasks that build the query input field. Each sub-task produces a compilable increment.

- `CourierTextView: NSTextView` — minimal subclass that adds placeholder text rendering
- **Placeholder text**: `NSTextView` has no built-in placeholder. Override `draw(_:)` to draw placeholder text when `string.isEmpty`. Placeholder text: `"Type your message or \"/\" to switch destination"` in `.placeholderTextColor`.
- **NSTextView styling** (applied in Task 2.1b's `makeNSView`, but documented here for reference):
  - Font: `.systemFont(ofSize: 15)` (matches system body text feel)
  - Text color: `.labelColor` (auto light/dark)
  - Background: `.clear` (panel provides background)
  - No ruler (`isRulerVisible = false`), no rich text (`isRichText = false`)
  - `textContainerInset = NSSize(width: 0, height: 4)` for vertical padding
  - `isAutomaticQuoteSubstitutionEnabled = false` (don't smart-quote in a search/query field)
- **Required imports**: `import AppKit`
- Verify: subclass compiles, placeholder draws when empty, placeholder hidden when text present
- Files created: `Courier/Views/Launcher/CourierTextView.swift`
- **Commit**: `git commit -m "Phase 2 Task 2.1a: CourierTextView with placeholder rendering"`

---

## Task 2.1b — QueryInputView (NSViewRepresentable + Coordinator)

- `QueryInputView` using **`NSTextView` wrapped in `NSViewRepresentable`** — NOT SwiftUI `TextEditor`. SwiftUI's `TextEditor` does not natively support "grow to fit content up to N lines then scroll" on macOS.
- **`Coordinator` as `NSTextViewDelegate`** — the Coordinator handles:
  - `textDidChange(_:)` — forward text content back to SwiftUI `@Binding<String>`. **Critical: binding loop guard** — the Coordinator must have an `isUpdatingFromSwiftUI: Bool` flag:
    ```swift
    // In Coordinator:
    var isUpdatingFromSwiftUI = false
    func textDidChange(_ notification: Notification) {
        guard !isUpdatingFromSwiftUI else { return }
        parent.text = textView.string
    }
    // In updateNSView:
    if textView.string != text {
        context.coordinator.isUpdatingFromSwiftUI = true
        textView.string = text
        context.coordinator.isUpdatingFromSwiftUI = false
    }
    ```
  - `textView(_:shouldChangeTextIn:replacementString:)` — detect paste vs. typed input (paste has `replacementString.count > 1`). Set `isPasting` flag used by slash command detection (Task 4.1).
  - The Coordinator stores a weak reference to its `NSTextView` in `LauncherViewModel.queryTextView` during `makeNSView`.
  - The Coordinator's `textDidChange` calls `setNeedsDisplay` on the text view to toggle placeholder visibility.
- **Required imports**: `import SwiftUI`, `import AppKit`
- **IME / international input support**: `NSTextView` natively supports Input Method Editors (Japanese, Chinese, Korean). Verify that marked text (inline composition) renders correctly. Also test emoji picker (Cmd+Ctrl+Space).
- Grows vertically up to ~10 lines (~320pt max height), then scrolls
- Support standard text editing (Cmd+A, Cmd+Z, Cmd+Shift+Z, Cmd+C/V/X) — built-in to `NSTextView`
- Accessibility: label ("Query input"), keyboard navigable
- Verify: text binding works (type -> binding updates -> no infinite loop), paste detection flag sets correctly, NSTextView creates and displays inside panel, placeholder toggles on text change
- Files created: `Courier/Views/Launcher/QueryInputView.swift`. Files modified: `LauncherView.swift` (embed QueryInputView)
- **Commit**: `git commit -m "Phase 2 Task 2.1b: QueryInputView NSViewRepresentable with Coordinator"`

---

## Task 2.1c — Height calculation + panel resize

- Add `recalculateHeightIfNeeded` to the Coordinator in `QueryInputView`:
  - Calculate `NSLayoutManager.usedRect(for: textContainer).height`, clamp to min 80pt / max 320pt
  - **TextKit 2 note**: This uses `NSLayoutManager` (TextKit 1), which is soft-deprecated on macOS 14+. It works fully and will continue to work. Future migration path: `NSTextLayoutManager.enumerateTextLayoutFragments` (TextKit 2). No action needed for v1.
  - **Debounce**: Only recalculate when the line count changes (track previous line count), not on every character. At 8000 characters, per-keystroke layout recalc can cause lag.
  - Publish height to `LauncherViewModel.contentHeight` via the view model reference
- **Critical — height must update the panel frame**: `LauncherWindowController` must observe `viewModel.contentHeight` and call `panel.setContentSize(NSSize(width: 680, height: newHeight))`. Use `withObservationTracking` in a recursive observation pattern:
  ```swift
  private func observeContentHeight() {
      withObservationTracking {
          _ = viewModel.contentHeight
      } onChange: { [weak self] in
          DispatchQueue.main.async {
              self?.updatePanelHeight()
              self?.observeContentHeight()  // Re-observe
          }
      }
  }
  ```
  Without this, the SwiftUI content grows but the panel window stays the same size.
- Verify: panel resizes as lines are added/removed, height clamps at 80pt min and 320pt max, scrolling activates at 10+ lines, no jitter during resize
- Files modified: `QueryInputView.swift` (add height recalculation to Coordinator), `LauncherViewModel.swift` (add `contentHeight` property), `LauncherWindowController.swift` (add height observation + panel resize)
- **Commit**: `git commit -m "Phase 2 Task 2.1c: Dynamic height calculation and panel resize"`

---

## Task 2.1d — Submit/newline handling + inline warning + first responder

- Add to Coordinator's `textView(_:doCommandBy:)`:
  - `insertNewline:` (Enter -> submit). **Submit uses full text regardless of selection** — read `textView.string` before any mutation. **Debounce submit** — set `hasSubmitted` flag, ignore subsequent `insertNewline:` until panel re-shown.
  - `insertNewlineIgnoringFieldEditor:` (Cmd+Enter / Shift+Enter -> insert literal newline)
  - `cancelOperation:` (Escape -> dismiss panel via `onDismiss` closure)
- Enter key submits (blocked if input empty or whitespace-only — **trim whitespace before checking**, including newline-only input)
- **First responder management**: On panel show, `LauncherWindowController` calls `panel.makeFirstResponder(viewModel.queryTextView)` after `makeKeyAndOrderFront` in `DispatchQueue.main.async`. **Known fragility**: if cursor doesn't appear, try double-async or `asyncAfter(deadline: .now() + 0.05)`. Verify during Human Checkpoint 1.
- **Inline warning if query exceeds 8000 characters**: "Query will be truncated to 8000 characters" — small label (`.systemFont(ofSize: 11)`, `.systemOrange`) between text input and service bar. Appears/disappears with subtle fade.
- Verify: Enter submits, Cmd+Enter adds line, Escape dismisses, empty-enter blocked, whitespace-only blocked, long query warning at 8001 chars, held Enter -> only one submit (debounce), cursor appears on panel show, typing during animation not lost
- Files modified: `QueryInputView.swift` (doCommandBy, onSubmit/onDismiss closures), `LauncherView.swift` (inline warning label), `LauncherWindowController.swift` (first responder wiring)
- **Commit**: `git commit -m "Phase 2 Task 2.1d: Submit/newline handling, first responder, char limit warning"`

---

## Task 2.2 — Service data model

- **Use the exact interface contracts from `courier-architecture.md` → "Full Interface Contracts" section.** Copy `ServiceType`, `ServiceCategory`, and `ServiceProvider` definitions verbatim. This prevents signature drift when other tasks reference these types.
- `ServiceRegistry` with all 7 services registered — a simple dictionary mapping `ServiceType` to concrete `ServiceProvider` implementations (stubs for now — dispatch logic added in Phase 3)
- `AppSettings` observable with UserDefaults persistence
- **Required imports**: `ServiceType.swift` needs `import Foundation`. `AppSettings.swift` needs `import Foundation` and `import Observation`. `ServiceRegistry.swift` needs `import Foundation`.
- **`@Observable` annotation guidance**: `AppSettings` should be `@Observable @MainActor`. Any stored properties that aren't meant to trigger view updates (e.g., internal caches, UserDefaults suite reference) must use `@ObservationIgnored`.
- **Settings versioning**: Include a `settingsVersion` integer in UserDefaults. On launch, check the stored version against the current version and run a migration function if needed.
- **Cache UserDefaults values**: Read all settings into `@Observable` properties at launch. Do NOT read UserDefaults on every keystroke. Only write back on change.
- Default service always set (never nil). If `lastUsedService` has been disabled, fall back to first enabled service in display order.
- Verify: unit tests for:
  - Registry lookups by type and slash command
  - Settings round-trip (save -> quit -> relaunch -> values intact)
  - Always-has-selection invariant
  - Disabled last-used-service fallback
  - Slash command exact-match-only (e.g., "/c" does NOT match "/cl")
  - Settings migration (simulate old version -> verify upgrade preserves values)
- Files created: `ServiceType.swift`, `AppSettings.swift`, `SlashCommand.swift`, `ServiceProtocol.swift`, `ServiceRegistry.swift`, `CourierTests/ServiceRegistryTests.swift`, `CourierTests/AppSettingsTests.swift`
- **Commit**: `git commit -m "Phase 2 Task 2.2: Service data model, registry, settings with versioning"`

### Test Skeleton for Task 2.2

```swift
// CourierTests/ServiceRegistryTests.swift
import XCTest
@testable import Courier

final class ServiceRegistryTests: XCTestCase {

    var registry: ServiceRegistry!

    override func setUp() {
        registry = ServiceRegistry()
    }

    func testLookupByType() {
        // Every ServiceType should resolve to a non-nil provider
        for type in ServiceType.allCases {
            XCTAssertNotNil(registry.provider(for: type), "Missing provider for \(type)")
        }
    }

    func testLookupBySlashCommand_exactMatch() {
        // "/cl" -> Claude, "/ch" -> ChatGPT, etc.
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/cl"), .claude)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/claude"), .claude)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/ch"), .chatgpt)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/chatgpt"), .chatgpt)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/k"), .kagi)
        XCTAssertEqual(registry.serviceType(forSlashCommand: "/g"), .google)
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

// CourierTests/AppSettingsTests.swift
import XCTest
@testable import Courier

final class AppSettingsTests: XCTestCase {

    func testAlwaysHasSelection() {
        // Settings should never return nil for selectedService
        let settings = AppSettings()
        XCTAssertNotNil(settings.lastUsedService)
    }

    func testDisabledServiceFallback() {
        // If last-used service is disabled, fall back to first enabled
        let settings = AppSettings()
        settings.lastUsedService = .claude
        settings.disabledServices = [.claude]
        XCTAssertNotEqual(settings.effectiveSelectedService, .claude)
        XCTAssertFalse(settings.disabledServices.contains(settings.effectiveSelectedService))
    }

    func testSettingsRoundTrip() {
        // Save -> create new instance -> values match
        let settings = AppSettings()
        settings.lastUsedService = .perplexity
        settings.save()

        let reloaded = AppSettings()
        XCTAssertEqual(reloaded.lastUsedService, .perplexity)
    }
}
```

---

## Task 2.3 — Service bar + Deliver button

- `ServiceButton` with 6 states: default, hover, selected, selected+hover, switch, disabled
- **Button dimensions**: 36x36pt touch target, containing a 20x20pt service icon centered. 8pt spacing between buttons. Selected state: 2pt rounded-rect background fill using `.controlAccentColor` at 20% opacity, with the icon at full opacity. Hover state: same background at 10% opacity. These dimensions fit 7 buttons (7x36 + 6x8 = 300pt) + divider (1pt + 8pt padding each side = 17pt) + Deliver button (~100pt) = ~417pt, well within 680pt with 16pt horizontal padding on each side (648pt available).
- Each button has tooltip with service name
- **Display order** (fixed): Claude, ChatGPT, Gemini, Perplexity | Kagi, Google, DuckDuckGo. LLMs on the left, search engines on the right, separated by a subtle vertical divider (1pt, `.separatorColor`). Disabled services are hidden but order is preserved for enabled ones.
- `ServiceBar` as HStack of enabled service buttons (always one selected, disabled services hidden). **Service buttons are icon-only** (no text labels) — text label is reserved for the Deliver button only. This matches Raycast/Alfred patterns and keeps layout clean within 680pt.
- `DeliverButton` with `paperplane.fill` SF Symbol + "Deliver" text, disabled when input empty, with tooltip "Deliver query"
- **Deliver button behavior during dispatch**: Panel dismisses immediately on Enter/click. Dispatch continues on background thread. Errors surface as macOS notifications after the panel is gone. The Deliver button does NOT show a spinner — the interaction model is "fire and forget."
- `LauncherViewModel` managing selection (always has a value)
- **Keyboard navigation**: Arrow left/right cycles through service buttons (wraps circularly — last -> first, first -> last). Tab order: text field -> service bar -> Deliver button -> text field. Shift+Tab reverses. When service bar has focus, arrow keys move selection; Enter/Space activates (same as click).
- Accessibility: all buttons labeled ("Send to Claude", "Send to Google", etc.), keyboard navigable
- Verify: clicking/keyboard selects, all 6 visual states render, disabled services not shown, display order matches spec, divider between LLMs and search, arrow keys wrap at edges, Tab cycles through all controls, a11y audit passes, tooltips appear, panel dismisses immediately on submit
- **Required imports**: `ServiceBar.swift`, `ServiceButton.swift`, `DeliverButton.swift` all need `import SwiftUI`.
- Files created: `ServiceBar.swift`, `ServiceButton.swift`, `DeliverButton.swift`. Files modified: `LauncherView.swift` (add ServiceBar + DeliverButton), `LauncherViewModel.swift` (selectedService, service switching)
- **Commit**: `git commit -m "Phase 2 Task 2.3: Service bar with icon buttons, Deliver button, keyboard nav"`

---

## Task 2.4 — Panel dismiss behavior

- **Primary dismiss mechanism — `windowDidResignKey`**: Make `LauncherWindowController` the panel's delegate and implement `windowDidResignKey(_:)` -> dismiss the panel. This is the single source of truth for dismissal. All other dismiss triggers (ESC, click-outside, hotkey) work by causing the panel to resign key status, which then triggers the dismiss logic. This simplifies the architecture and matches Spotlight's behavior.
- **Escape key**: The `NSTextView` Coordinator intercepts `cancelOperation:` in `doCommandBy:` -> calls an `onDismiss` closure provided by `QueryInputView`, which routes to `LauncherWindowController.hide()`. Do NOT call `panel.resignKey()` (indirect) or `panel.orderOut(nil)` (bypasses state machine) — always go through the controller's `hide()` method.
- **Click outside**: Use `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])`. **Add the monitor once** in `LauncherWindowController.init`, store the return value as `Any?`, and check `panel.isVisible` inside the handler — only dismiss if visible and the click is outside the panel's frame. Do NOT add/remove the monitor on each show/hide cycle — mismatched add/remove leaks monitors. **Clarification on local monitor**: Do NOT use a local monitor to dismiss on clicks inside the panel but outside the text field — those clicks are normal interactions (clicking service buttons, Deliver button). The global monitor + `windowDidResignKey` covers all dismiss cases.
- Pressing the global hotkey again (Option+Space or user-configured shortcut) closes panel if open
- **Panel loses key to system UI**: When Notification Center opens, a system alert appears, or the user clicks the Dock, the panel loses key status via `windowDidResignKey` and dismisses automatically. This matches Spotlight's behavior.
- On dismiss: query text is cleared, `hasSubmitted` flag reset, panel state -> hidden
- Focus returns to the previously active application (see Task 1.2 — `previousApp` weak reference tracked on hotkey press, reactivated on dismiss if not terminated)
- Verify: all dismiss methods work (ESC, click-outside, hotkey re-press, system alert appearing), clicking service buttons does NOT dismiss panel, focus returns to previous app (test: open Safari, press hotkey, press Escape -> Safari is frontmost again), query is cleared on reopen, previous app quit during panel open -> no crash on dismiss, Notification Center opening dismisses panel
- Files modified: `LauncherWindowController.swift` (windowDidResignKey, global click monitor), `QueryInputView.swift` (cancelOperation in Coordinator), `LauncherViewModel.swift` (clearQuery, hasSubmitted reset)
- **Commit**: `git commit -m "Phase 2 Task 2.4: Panel dismiss — windowDidResignKey, ESC, click-outside"`

---

## Skeleton Code

### `Courier/Views/Launcher/CourierTextView.swift`

```swift
import AppKit

final class CourierTextView: NSTextView {

    var placeholder: String = "Type your message or \"/\" to switch destination"

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if string.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.placeholderTextColor,
            ]
            let inset = textContainerInset
            let rect = NSRect(
                x: inset.width + 5,
                y: inset.height,
                width: bounds.width - inset.width * 2 - 10,
                height: bounds.height - inset.height * 2
            )
            placeholder.draw(in: rect, withAttributes: attributes)
        }
    }
}
```

### `Courier/Views/Launcher/QueryInputView.swift`

```swift
import SwiftUI
import AppKit

struct QueryInputView: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var onSubmit: () -> Void
    var onDismiss: () -> Void
    weak var viewModel: LauncherViewModel?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = CourierTextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isRulerVisible = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        context.coordinator.textView = textView
        viewModel?.queryTextView = textView

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CourierTextView else { return }
        if textView.string != text {
            context.coordinator.isUpdatingFromSwiftUI = true
            textView.string = text
            context.coordinator.isUpdatingFromSwiftUI = false
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: QueryInputView
        weak var textView: CourierTextView?
        var isUpdatingFromSwiftUI = false
        var isPasting = false
        private var hasSubmitted = false

        init(parent: QueryInputView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingFromSwiftUI, let textView else { return }
            parent.text = textView.string
            textView.needsDisplay = true  // Toggle placeholder visibility
            recalculateHeightIfNeeded(textView)
        }

        func textView(_ textView: NSTextView,
                       shouldChangeTextIn range: NSRange,
                       replacementString text: String?) -> Bool {
            // Detect paste: replacement longer than 1 char
            isPasting = (text?.count ?? 0) > 1
            return true
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                guard !hasSubmitted else { return true }
                let trimmed = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return true }
                hasSubmitted = true
                parent.onSubmit()
                return true
            }
            if selector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)) {
                // Cmd+Enter / Shift+Enter -> literal newline
                textView.insertNewlineIgnoringFieldEditor(nil)
                return true
            }
            if selector == #selector(NSResponder.cancelOperation(_:)) {
                // ESC -> dismiss panel via callback (not orderOut directly — goes through state machine)
                parent.onDismiss()
                return true
            }
            return false
        }

        func resetSubmitState() {
            hasSubmitted = false
        }

        private func recalculateHeightIfNeeded(_ textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let newHeight = min(max(usedRect.height + 8, 80), 320)
            if abs(newHeight - parent.height) > 1 {
                parent.height = newHeight
                // Notify controller to resize panel
                DispatchQueue.main.async {
                    self.parent.viewModel?.queryTextView?.window?.setContentSize(
                        NSSize(width: 680, height: newHeight)
                    )
                }
            }
        }
    }
}
```

### `Courier/Views/Launcher/LauncherViewModel.swift`

```swift
import AppKit
import Observation

@Observable
@MainActor
final class LauncherViewModel {
    var queryText: String = ""
    var contentHeight: CGFloat = 80  // Panel observes this to resize
    var selectedService: ServiceType = .claude  // Will be loaded from AppSettings
    var isSlashMode: Bool = false
    var slashPrefix: String = ""
    var hasSubmitted: Bool = false

    // Set by QueryInputView Coordinator during makeNSView
    // CRITICAL: @ObservationIgnored is required — weak references are not observable
    // and the @Observable macro will fail to compile without this annotation.
    @ObservationIgnored weak var queryTextView: NSTextView?

    func clearQuery() {
        queryText = ""
        contentHeight = 80
        isSlashMode = false
        slashPrefix = ""
        hasSubmitted = false
    }

    func submit() {
        guard !hasSubmitted else { return }
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hasSubmitted = true
        // TODO: dispatch to selected service via ServiceDispatcher
    }
}
```

**Note**: `LauncherWindowController` must observe `viewModel.contentHeight` and update the panel frame. The Coordinator's `recalculateHeightIfNeeded` calls `window?.setContentSize()` directly — this avoids complex observation patterns since the Coordinator already knows the height and has access to the window via the text view.

---

## Phase 2 Build Verification

```bash
xcodebuild -scheme Courier -destination 'platform=macOS' build && xcodebuild -scheme CourierTests -destination 'platform=macOS' test 2>&1 | tail -20
```

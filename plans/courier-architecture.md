# Courier — Architecture Reference

> This is the shared reference for all phases. Read this first before any phase file.

## Context

Courier is a new macOS utility app that acts as a universal query launcher. The user presses a keyboard shortcut (default: Option+Space), types a query, selects a destination service (Claude, ChatGPT, Gemini, Perplexity, Kagi, Google, DuckDuckGo), and submits. The query is dispatched to the selected service — either via native app (with AppleScript paste fallback) or browser. The app lives in the menu bar with no dock icon, inspired by Spotlight/Raycast.

The repo at `/Users/John Holleman/repos/Courier-claude/Courier-claude/` is empty (just a README). Building from scratch with native Swift/SwiftUI.

**Minimum deployment target: macOS 14 (Sonoma)** — required for `@Observable` (Observation framework), `MenuBarExtra`, and `SMAppService`.

---

## Project Bootstrap

The Xcode project is generated from a `project.yml` file using [XcodeGen](https://github.com/yonaskolb/XcodeGen). Install with `brew install xcodegen`, then run `xcodegen generate` in the repo root to produce `Courier.xcodeproj`. Re-run only when `project.yml` changes.

**XcodeGen version pinning**: Pin to a known-good version to avoid breaking changes. Use `brew install xcodegen` (currently resolves to 2.42.0+). If the build breaks after a Homebrew update, check `xcodegen --version` against the `project.yml` spec version.

### Step 0 — Create project scaffolding files FIRST

Before writing any Swift code, create these files as literal files on disk:
1. `project.yml` (see below)
2. `Courier/App/Info.plist` (see below)
3. `Courier/Courier.entitlements` (see below)
4. All `Contents.json` files in `Courier/Resources/Assets.xcassets/` (see below)
5. An empty `CourierTests/` directory

Then run `xcodegen generate && xcodebuild -scheme Courier -destination 'platform=macOS' build` to verify the empty project compiles before writing any Swift. This catches project configuration issues (signing, entitlements, SPM resolution) before they compound with code errors.

### `project.yml`

```yaml
name: Courier
options:
  bundleIdPrefix: com.courier
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "15.0"
  generateEmptyDirectories: true

packages:
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts
    from: "2.1.0"

settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    CODE_SIGN_ENTITLEMENTS: Courier/Courier.entitlements
    INFOPLIST_FILE: Courier/App/Info.plist
    CODE_SIGN_STYLE: Automatic
    ENABLE_HARDENED_RUNTIME: YES
    PRODUCT_BUNDLE_IDENTIFIER: com.courier.Courier

targets:
  Courier:
    type: application
    platform: macOS
    sources:
      - path: Courier
        excludes:
          - "**/*Tests*"
    dependencies:
      - package: KeyboardShortcuts
    settings:
      base:
        INFOPLIST_FILE: Courier/App/Info.plist
        CODE_SIGN_ENTITLEMENTS: Courier/Courier.entitlements
        LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/../Frameworks"

  CourierTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: CourierTests
    dependencies:
      - target: Courier
    settings:
      base:
        BUNDLE_LOADER: "$(TEST_HOST)"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Courier.app/Contents/MacOS/Courier"
```

### `Courier/App/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIconFile</key>
    <string></string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Courier</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Courier sends your query to AI and search apps.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Courier. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

### `Courier/Courier.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

### Asset Catalog Directory Structure

```
Courier/Resources/Assets.xcassets/
├── Contents.json                          # Root manifest
├── AccentColor.colorset/
│   └── Contents.json
├── AppIcon.appiconset/
│   └── Contents.json
├── MenuBarIcon.imageset/
│   └── Contents.json                      # Template image (16pt + 2x)
└── ServiceIcons/
    ├── Contents.json                      # Namespace folder
    ├── claude.imageset/Contents.json
    ├── chatgpt.imageset/Contents.json
    ├── gemini.imageset/Contents.json
    ├── perplexity.imageset/Contents.json
    ├── kagi.imageset/Contents.json
    ├── google.imageset/Contents.json
    └── duckduckgo.imageset/Contents.json
```

**Root/namespace `Contents.json`**: `{ "info": { "author": "xcode", "version": 1 } }`

**Template image set** (`MenuBarIcon.imageset/Contents.json`):
```json
{
  "images": [
    { "filename": "menubar-icon.png", "idiom": "universal", "scale": "1x" },
    { "filename": "menubar-icon@2x.png", "idiom": "universal", "scale": "2x" }
  ],
  "info": { "author": "xcode", "version": 1 },
  "properties": { "template-rendering-intent": "template" }
}
```

Service icon image sets follow the same pattern with `"template-rendering-intent": "template"` and 1x (20×20pt) + 2x (40×40pt). Generate solid-color placeholder PNGs for initial builds.

### KeyboardShortcuts Package — API Reference

```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleCourier = Self("toggleCourier")
}

KeyboardShortcuts.setShortcut(.init(.space, modifiers: .option), for: .toggleCourier)
let shortcut = KeyboardShortcuts.getShortcut(for: .toggleCourier)
KeyboardShortcuts.onKeyUp(for: .toggleCourier) { /* handler */ }
KeyboardShortcuts.Recorder("Shortcut:", name: .toggleCourier)  // SwiftUI recorder
```

**If the API doesn't compile**, check `Sources/KeyboardShortcuts/` in the resolved package. Do not guess — read the source.

---

## Compliance Requirements

### Apple HIG
- Menu bar icon: 16×16pt template image, 22pt max height
- Standard system shortcuts honored (Cmd+C/V/Q/,) — never overridden
- Buttons have clear visual states: default, hover, pressed, disabled
- Icon-only buttons have tooltips

### Accessibility (WCAG 2.1 AA)
- All interactive elements have `accessibilityLabel`, `accessibilityHint`
- All elements reachable via keyboard (Tab, Shift+Tab, arrows)
- **Contrast**: 4.5:1 minimum for normal text, 3:1 for large text and UI components
- Test with VoiceOver (Cmd+F5) and Xcode Accessibility Inspector

---

## Key Design Rules

- **A service is always selected** — last-used pre-selected, fall back to first enabled if disabled
- **Slash commands are exact-match only** — `/c ` does NOT match `/cl`
- **Enter submits** (disabled until ≥1 non-whitespace char). **Cmd+Enter** / **Shift+Enter** inserts newline.
- **Clipboard save/restore**: save before paste, restore after 1.5s, zero after restore. Skip if >50MB.
- **Panel always starts fresh**: query cleared on dismiss, last-used service pre-selected
- **Disabled services hidden from launcher**, visible as disabled in Settings

---

## Window Dimensions

- **Width**: 680pt | **Min height**: ~80pt | **Max height**: ~320pt
- **Corner radius**: 12pt | **Padding**: 16pt horizontal, 12pt vertical
- **Shadow**: `NSShadow` 0.3 opacity, 8pt blur, 2pt y-offset

---

## Project Structure

```
Courier/
├── App/
│   ├── CourierApp.swift, AppDelegate.swift, Info.plist
├── Models/
│   ├── ServiceType.swift, AppSettings.swift, SlashCommand.swift
├── Services/
│   ├── ServiceProtocol.swift, ServiceRegistry.swift, LLMService.swift
│   ├── SearchService.swift, ServiceDispatcher.swift, AppleScriptHelper.swift
├── HotKey/
│   └── HotKeyProvider.swift
├── Views/
│   ├── Launcher/ (LauncherPanel, LauncherWindowController, LauncherView,
│   │              LauncherViewModel, QueryInputView, CourierTextView,
│   │              ServiceBar, ServiceButton, DeliverButton)
│   ├── Setup/ (SetupWizardView, HotkeySetupStep, SearchProviderStep,
│   │           LLMSelectionStep, SlashCommandStep, LaunchOnStartupStep)
│   ├── Settings/SettingsView.swift
│   └── MenuBar/MenuBarView.swift
├── Utilities/
│   ├── AccessibilityPermission.swift, LoginItemManager.swift
│   ├── NSPanelHosting.swift, NotificationHelper.swift
├── Resources/Assets.xcassets
└── Courier.entitlements
```

---

## Key Architectural Decisions

- **NSPanel (not SwiftUI Window)**: floating/borderless/non-activating. Override `canBecomeKey → true`.
- **Panel state machine**: `hidden → animatingIn → visible → animatingOut → hidden`. Queue toggles during animation.
- **KeyboardShortcuts package** wraps Carbon `RegisterEventHotKey`. Wrapped behind `HotKeyProvider` protocol.
- **No App Sandbox**: AppleScript requires accessibility permissions. Distribute outside Mac App Store.
- **Hardened Runtime + Notarization** for distribution.
- **`SMAppService` for login items**: can silently fail outside `/Applications`.
- **Swift concurrency**: serial `DispatchQueue("com.courier.dispatch")` for AppleScript. `@MainActor` on view models. Pass only primitives to background closures.
- **`LauncherViewModel` owned by `LauncherWindowController`**, injected into SwiftUI via `NSHostingView(rootView: LauncherView(viewModel: viewModel))`.
- **Stage Manager compatibility**: The `.floating` level panel may behave differently in Stage Manager mode (macOS Sonoma+). The panel should NOT be grouped with other app windows. Verify that `collectionBehavior` includes `.canJoinAllSpaces` and `.fullScreenAuxiliary` which should prevent grouping. Stage Manager is a required test case for all phases.
- **Secure Event Input limitation**: When another app (e.g., 1Password, banking apps) enables `EnableSecureEventInput`, Carbon global hotkeys may not fire. This is a system-level limitation. Check `IsSecureEventInputEnabled()` periodically alongside `AXIsProcessTrusted()`. If secure input is active and the hotkey fails, show toast: "A secure input app may be blocking Courier's hotkey." Document this as a known limitation.
- **TextKit 2 migration path**: The height calculation in `QueryInputView` uses `NSLayoutManager.usedRect(for:)` (TextKit 1). This works on macOS 14+ but `NSLayoutManager` is soft-deprecated. Future migration: use `NSTextLayoutManager.enumerateTextLayoutFragments` (TextKit 2). No action needed for v1 — TextKit 1 is fully functional and will be for years.

---

## Service Dispatch Reference

| Service | Bundle ID | Browser URL | Slash Commands |
|---------|-----------|-------------|----------------|
| Claude | `com.anthropic.claudefordesktop` | `https://claude.ai/new` | /cl, /claude |
| ChatGPT | `com.openai.chat` | `https://chatgpt.com/` | /ch, /chatgpt |
| Gemini | `com.google.Gemini` (TBD) | `https://gemini.google.com/app` | /ge, /gemini |
| Perplexity | `ai.perplexity.mac` | `https://www.perplexity.ai/search?q=` | /p, /perplexity |
| Kagi | N/A | `https://kagi.com/search?q=` | /k, /kagi |
| Google | N/A | `https://www.google.com/search?q=` | /g, /google |
| DuckDuckGo | N/A | `https://duckduckgo.com/?q=` | /d, /ddg |

**URL encoding**: Custom `CharacterSet` removing `&=+#` from `.urlQueryAllowed`. Guard `URL(string:)` nil. Max 8000 chars raw input.

**LLM dispatch chain**: Check cached install → activate app → AppleScript paste with retry → fall back to browser on failure.

**App-installed cache**: Cache `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` at launch. Refresh on `didLaunchApplication` / `didTerminateApplication` notifications.

---

## Error Handling & User Feedback

- **Toast** (auto-dismiss 4s): paste failures, browser failures, clipboard status. Pre-created reusable `NSPanel`, `canBecomeKey=false`, `canBecomeMain=false`, `.hudWindow` material, `NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)` level — just above the launcher panel but below system alerts. Do NOT use `.statusBar` level, which overrides system floating panels and is too aggressive for a toast.
- **System notification** (persists): permission denied/revoked. Request notification permission during setup.

| Scenario | Type | Message |
|----------|------|---------|
| AppleScript paste fails | Toast | "Couldn't paste into [App]. Query copied to clipboard." + browser fallback |
| Accessibility denied/revoked | System | "Courier needs/lost Accessibility access." + System Settings link |
| Automation denied (per-app) | System | "Courier needs permission to control [App]." |
| Browser fails to open | Toast | "Couldn't open browser. Query copied to clipboard." |
| Target app cold launch | Toast | "Waiting for [App] to launch..." (3s delay, 10s timeout) |
| Query >8000 chars | Inline | "Query will be truncated to 8000 characters" |
| Clipboard >50MB | Toast | "Clipboard too large to save." |

---

## Implementation Sequencing

**Do not build all 6 phases in one pass.** Stop for human verification between passes. **Commit after each task** (not each phase) to prevent context window overflow and provide natural recovery points.

**Pass 1 — Phases 1 + 2** → 🛑 Human checkpoint: panel appears, text input works, hotkey works, dismiss works, no visual glitches. Commit after: Step 0, 1.1, 1.2, 1.3, 2.1a, 2.1b, 2.1c, 2.1d, 2.2, 2.3, 2.4.

**Pass 2 — Phases 3 + 4** → 🛑 Human checkpoint: search URLs work, native paste works for ≥1 app, clipboard restored, slash commands work, AppleScript timing tuned. Commit after: 3.1, 3.2, 3.3, 3.4, 4.1, 4.2.

**Pass 3 — Phases 5 + 6** → 🛑 Human checkpoint: wizard flow, settings, visual polish, VoiceOver, Reduce Motion/Transparency. Commit after: 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3.

| Claude can verify | Requires human |
|---|---|
| Compiles, unit/integration tests pass | Visual correctness, text input feel, AppleScript timing, hotkey from other apps, multi-monitor, VoiceOver, dark mode |

---

## Privacy, Distribution, Graceful Degradation

- **No network calls** from Courier itself. Query on clipboard for ~1.5s during native dispatch.
- **Hardened Runtime + Notarization**. `.dmg` with drag-to-Applications.
- **Graceful degradation**: No accessibility → browser-only works. No automation for specific app → that app falls back to browser. Not in /Applications → login item may fail.
- **Auto-update (post-v1)**: For a non-App Store DMG-distributed app, [Sparkle](https://sparkle-project.org/) is the standard auto-update framework. V1 ships without Sparkle, but reserve a "Check for Updates..." menu item in the menu bar menu (disabled, tooltip "Coming in a future version") so the UI slot exists. When adding Sparkle later, integrate `SUUpdater` in `AppDelegate`, add the appcast URL to Info.plist, and enable the menu item. No ATS concerns since the app is not sandboxed.

---

---

## File Dependency Graph

Each task lists its input files (prerequisites from prior tasks) and output files. Do not implement a task before its prerequisites exist.

| Task | Requires (from prior tasks) | Produces |
|------|---------------------------|----------|
| Step 0 | — | `project.yml`, `Info.plist`, `Courier.entitlements`, `Assets.xcassets/**` |
| 1.1 | Step 0 | `CourierApp.swift`, `AppDelegate.swift` |
| 1.2 | 1.1 (`AppDelegate.swift`) | `LauncherPanel.swift`, `LauncherWindowController.swift`, `LauncherView.swift` (stub), `LauncherViewModel.swift` (stub) |
| 1.3 | 1.1 (`AppDelegate.swift`), 1.2 (`LauncherWindowController.swift`) | `HotKeyProvider.swift`, `AccessibilityPermission.swift` |
| 2.1a | 1.2 (`LauncherView.swift`) | `CourierTextView.swift` |
| 2.1b | 2.1a (`CourierTextView.swift`), 1.2 (`LauncherViewModel.swift`) | `QueryInputView.swift` |
| 2.1c | 2.1b (`QueryInputView.swift`), 1.2 (`LauncherWindowController.swift`, `LauncherViewModel.swift`) | Modified: `LauncherViewModel.swift`, `LauncherWindowController.swift` |
| 2.1d | 2.1b (`QueryInputView.swift`), 2.1c | Modified: `QueryInputView.swift`, `LauncherView.swift` |
| 2.2 | — (standalone models) | `ServiceType.swift`, `AppSettings.swift`, `SlashCommand.swift`, `ServiceProtocol.swift`, `ServiceRegistry.swift`, test files |
| 2.3 | 2.2 (`ServiceType.swift`, `ServiceRegistry.swift`), 2.1d (`LauncherView.swift`, `LauncherViewModel.swift`) | `ServiceBar.swift`, `ServiceButton.swift`, `DeliverButton.swift` |
| 2.4 | 1.2 (`LauncherWindowController.swift`), 2.1b (`QueryInputView.swift`) | Modified: `LauncherWindowController.swift`, `QueryInputView.swift`, `LauncherViewModel.swift` |
| 3.1 | 2.2 (`ServiceProtocol.swift`, `ServiceRegistry.swift`) | `SearchService.swift`, test files |
| 3.2 | 2.2, 3.1 | `LLMService.swift` |
| 3.3 | 3.2 (`LLMService.swift`) | `AppleScriptHelper.swift`, `ServiceDispatcher.swift`, `NotificationHelper.swift`, test files |
| 3.4 | 3.3, 2.2 (`AppSettings.swift`) | Modified: `AppSettings.swift`, `LauncherViewModel.swift` |
| 4.1 | 2.2 (`ServiceRegistry.swift`), 2.1b (`QueryInputView.swift`), 2.1d (`LauncherViewModel.swift`) | Modified: `LauncherViewModel.swift`, `QueryInputView.swift`, `ServiceRegistry.swift` |
| 4.2 | 4.1, 2.3 (`ServiceButton.swift`, `ServiceBar.swift`) | Modified: `ServiceButton.swift`, `ServiceBar.swift`, `LauncherViewModel.swift` |
| 5.1 | 2.2 (`AppSettings.swift`) | `SetupWizardView.swift` |
| 5.2 | 1.3 (`HotKeyProvider.swift`) | `HotkeySetupStep.swift` |
| 5.3 | 2.2 (`ServiceRegistry.swift`) | `SearchProviderStep.swift`, `LLMSelectionStep.swift` |
| 5.4 | 5.1-5.3 | `SlashCommandStep.swift`, `LaunchOnStartupStep.swift`, `LoginItemManager.swift` |
| 6.1 | 5.1-5.4 (wizard views for reference), 2.2, 3.3 | `SettingsView.swift` |
| 6.2 | 1.2, 6.1 | Modified: `LauncherWindowController.swift`, `Assets.xcassets` |
| 6.3 | All prior tasks | Modified: `LauncherWindowController.swift`, `ServiceDispatcher.swift`, `NotificationHelper.swift` |

---

## Full Interface Contracts

These types are referenced across multiple tasks. Define them exactly as shown to prevent signature drift between files.

```swift
// Courier/Models/ServiceType.swift
import Foundation

enum ServiceCategory: String, Codable {
    case llm
    case search
}

enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case claude, chatgpt, gemini, perplexity, kagi, google, duckduckgo

    var id: String { rawValue }

    var category: ServiceCategory {
        switch self {
        case .claude, .chatgpt, .gemini, .perplexity: return .llm
        case .kagi, .google, .duckduckgo: return .search
        }
    }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .chatgpt: return "ChatGPT"
        case .gemini: return "Gemini"
        case .perplexity: return "Perplexity"
        case .kagi: return "Kagi"
        case .google: return "Google"
        case .duckduckgo: return "DuckDuckGo"
        }
    }

    var iconName: String { rawValue }  // Matches asset catalog name

    /// Display order: LLMs first, then search engines
    static let displayOrder: [ServiceType] = [
        .claude, .chatgpt, .gemini, .perplexity,
        .kagi, .google, .duckduckgo
    ]
}
```

```swift
// Courier/Services/ServiceProtocol.swift
import Foundation

protocol ServiceProvider {
    var type: ServiceType { get }
    var browserURL: String { get }               // Base URL for browser dispatch
    var bundleIdentifier: String? { get }         // Native app bundle ID, nil if browser-only
    var defaultSlashCommands: [String] { get }    // e.g., ["/cl", "/claude"]
    var appendsQueryToURL: Bool { get }           // true for search engines, Perplexity

    /// Dispatch the query to this service. Throws on failure.
    func dispatch(query: String) async throws
}
```

```swift
// Courier/HotKey/HotKeyProvider.swift
import Foundation

protocol HotKeyProvider {
    /// Register the global hotkey. Calls `handler` on key-up.
    func register(handler: @escaping () -> Void)

    /// Unregister the current hotkey.
    func unregister()

    /// Whether the current shortcut is a restricted system shortcut.
    func isRestricted(_ shortcut: Any) -> Bool
}
```

```swift
// Courier/Services/ServiceDispatcher.swift (interface only — implementation in Phase 3)
import Foundation

@MainActor
protocol ServiceDispatching {
    /// Dispatch query to the given service. Handles native app / browser fallback internally.
    func dispatch(query: String, to service: ServiceType) async

    /// Cancel any in-flight dispatch (e.g., clipboard restore timer).
    func cancelPending()
}
```

---

## Known Compilation Issues

These are common compilation errors encountered when building this specific architecture. Address them proactively:

1. **`weak var` inside `@Observable`**: The `@Observable` macro does not support observing weak references. Any `weak var` property in an `@Observable` class must be annotated with `@ObservationIgnored`:
   ```swift
   @Observable
   final class LauncherViewModel {
       @ObservationIgnored weak var queryTextView: NSTextView?
       // ...
   }
   ```
   Without this, the compiler emits a cryptic error about the observation macro expansion.

2. **`KeyboardShortcuts` API version differences**: The package API can differ between 2.x versions. If `KeyboardShortcuts.setShortcut(.init(.space, modifiers: .option), for:)` doesn't compile, check the resolved package source at `.build/checkouts/KeyboardShortcuts/Sources/`. The `Key` enum and `Shortcut` initializer may have changed.

3. **`kAXTrustedCheckOptionPrompt` bridging**: `kAXTrustedCheckOptionPrompt` is a `CFString` that requires `takeRetainedValue()` or `takeUnretainedValue()` to bridge to Swift. Use `takeRetainedValue()` exactly **once** — calling it twice will crash (double-free). Preferred pattern:
   ```swift
   let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
   let options = [promptKey: true] as CFDictionary
   AXIsProcessTrustedWithOptions(options)
   ```
   Using `takeUnretainedValue()` is safer as it avoids ownership transfer issues.

4. **`NSViewRepresentable` type constraints**: The compiler can struggle with generic constraints if the `NSViewRepresentable` body references types that aren't fully concrete. Always use concrete return types (e.g., `NSScrollView`, not `some NSView`) in `makeNSView` and `updateNSView`.

5. **`@MainActor` isolation in `NSWindowDelegate`**: Methods like `windowDidResignKey(_:)` are called on the main thread but the compiler may warn about actor isolation. Annotate the conforming class with `@MainActor` or use `nonisolated` on delegate methods that don't access actor-isolated state.

---

## Implementation Discipline for Agentic Builds

These rules ensure reliable implementation by an AI coding agent:

1. **Commit after each task** (not each phase). This prevents context window overflow and provides natural recovery points. Use descriptive commit messages: `"Phase 1 Task 1.2: Floating panel with state machine"`.

2. **Rollback on repeated failure**: If a task doesn't compile after 3 attempts, `git stash`, re-read the task description and all referenced skeleton code, then start the task fresh. Do not accumulate workarounds on top of broken code.

3. **Exact imports per file**: Each task specifies the required `import` statements. Include them exactly — missing `import Observation` (for `@Observable`) and `import KeyboardShortcuts` are the most common omissions.

4. **Build after every file creation**: Run `xcodebuild -scheme Courier -destination 'platform=macOS' build 2>&1 | tail -30` after creating each new file. Fix compilation errors immediately before moving to the next file. Do not batch file creation.

5. **Machine-checkable vs human-only verification**: In the verification checklist, items that can be verified by compilation or unit tests should be checked by the agent. Items requiring visual inspection, VoiceOver testing, or multi-monitor testing should be flagged for human review at the checkpoint.

---

## Verification Checklist (43 items — see full plan for details)

Key items: builds clean, menu bar only, hotkey works, rapid toggle stable, service always selected, slash commands work, settings persist, a11y passes, contrast passes both modes, canBecomeKey working, special chars encoded, all Spaces + full-screen, no activation stealing, no UI freeze during dispatch, clipboard restore works, Reduce Motion/Transparency respected, toast works, wizard completes, Stage Manager compatible, Secure Event Input documented, per-app keystroke config editable in Settings.

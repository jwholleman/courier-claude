# Phase 5: Setup Wizard

> Read `courier-architecture.md` first if you haven't already.

---

## Task 5.1 — Wizard container + navigation

- **Window type**: Standard `NSWindow` (NOT `NSPanel`, NOT a sheet) — centered on screen, non-resizable, fixed size (~500x400pt). Use `NSHostingView` to embed the SwiftUI wizard view. The wizard window should be `titled` + `closable` but NOT `resizable` or `miniaturizable`.
- `SetupWizardView` with step indicators (dots/progress) + Back/Next buttons
- Show on first launch (`hasCompletedSetup == false`)
- 5 steps, keyboard navigable (Tab between controls, Enter for Next)
- **Quit during wizard**: If the user quits (Cmd+Q or closes window) before finishing, `hasCompletedSetup` remains `false`. On next launch, wizard restarts from step 1. Partial selections from previous steps are preserved in UserDefaults so the user doesn't have to re-select services/hotkey. The close button should confirm: "Setup is not complete. Courier won't be fully functional until setup is finished. Quit anyway?"
- **Required imports**: `SetupWizardView.swift` needs `import SwiftUI`.
- Verify: wizard appears on first launch, all navigation works, quitting mid-wizard shows confirmation, re-launch resumes with preserved selections, a11y audit passes
- Files created: `SetupWizardView.swift`. Files modified: `AppDelegate.swift` (show wizard on first launch), `AppSettings.swift` (add hasCompletedSetup)
- **Commit**: `git commit -m "Phase 5 Task 5.1: Setup wizard container with step navigation"`

---

## Task 5.2 — Hotkey setup step

- **Shortcut recorder + registration — use `KeyboardShortcuts` package for BOTH**: The `KeyboardShortcuts` Swift package by Sindre Sorhus (MIT license, widely used) handles shortcut recording UI, global hotkey registration, conflict detection, and localized key name display in a single package. **Use it for both the recorder AND the global hotkey registration.** This means:
  - **Remove `GlobalHotKey.swift` and `KeyCodeMapping.swift`** from the project structure. The `KeyboardShortcuts` package replaces them entirely.
  - The `HotKeyProvider` protocol abstraction (Task 1.3) still applies — wrap `KeyboardShortcuts` behind it so it could theoretically be swapped later.
  - Add `KeyboardShortcuts` as a Swift Package Manager dependency.
  - Do NOT use both `KeyboardShortcuts` and a custom Carbon wrapper simultaneously — they will conflict (double-registering the same hotkey via Carbon).
  - The recorder UI is `KeyboardShortcuts.Recorder("Shortcut:", name: .toggleCourier)` in SwiftUI.
- Display human-readable key name (e.g., "Option Space") using localized key names (important for non-US keyboard layouts)
- "Use Default" resets to Option+Space
- **Restricted shortcuts**: Reject system-reserved key combos with inline error "This shortcut is reserved by macOS":
  - Cmd+Q, Cmd+H, Cmd+M, Cmd+W, Cmd+Tab, Cmd+Space (Spotlight), Cmd+Shift+Space
  - Single modifier keys without a non-modifier key (e.g., just "Option" alone)
  - F11 (Show Desktop), F12 (legacy Dashboard)
  - Require at least one modifier key (Option, Cmd, Ctrl, Shift) + one non-modifier key
- **Conflict detection**: if chosen shortcut is already registered by another app, show inline warning "This shortcut may be in use by another app"
- **Required imports**: `HotkeySetupStep.swift` needs `import SwiftUI` and `import KeyboardShortcuts`.
- Verify: recording captures key, display is correct and localized, reserved shortcuts are rejected with error, conflict warning appears when appropriate, "Use Default" works
- Files created: `HotkeySetupStep.swift`. Files modified: `HotKeyProvider.swift` (restricted shortcut validation)
- **Commit**: `git commit -m "Phase 5 Task 5.2: Hotkey setup step with recorder and validation"`

---

## Task 5.3 — Search + LLM selection steps

- Search: single-select (Kagi, Google, DDG)
- LLMs: multi-select toggles (Claude, ChatGPT, Gemini, Perplexity)
- Detect installed native apps via `ServiceRegistry.installedAppsCache` (see Dispatch Chain section in architecture doc), show indicator badge (e.g., "App installed" chip)
- At least one service total must be enabled (prevent user from disabling everything)
- **Required imports**: `SearchProviderStep.swift` and `LLMSelectionStep.swift` need `import SwiftUI`.
- Verify: selections persist to AppSettings, contrast/labeling passes, can't proceed with zero services
- Files created: `SearchProviderStep.swift`, `LLMSelectionStep.swift`. Files modified: `ServiceRegistry.swift` (installedAppsCache for badge)
- **Commit**: `git commit -m "Phase 5 Task 5.3: Search and LLM selection steps with installed app detection"`

---

## Task 5.4 — Slash commands + startup steps

- Editable table of slash commands per enabled service
- Pre-filled with defaults, user can override
- Validate uniqueness (no two services share the same slash command) — show inline error if duplicate
- Launch-on-startup toggle via `SMAppService`. **On each app launch**, check `SMAppService.mainApp.status` — if the user had enabled login item but it was lost (e.g., app was updated/replaced in /Applications), re-register automatically. Store the user's intent in UserDefaults (`loginItemEnabled: Bool`) separately from the system registration state.
- "Finish" -> `hasCompletedSetup = true`, dismiss wizard, register hotkey
- **Sparkle placeholder**: Reserve a "Check for Updates..." menu item in the menu bar menu (disabled, tooltip "Coming in a future version"). Sparkle auto-update integration is deferred to post-v1, but the UI slot should exist now so it doesn't require a menu restructure later.
- Verify: custom slash commands save, duplicate detection works, startup toggle works, wizard doesn't reappear on next launch, login item survives app replacement in /Applications
- Files created: `SlashCommandStep.swift`, `LaunchOnStartupStep.swift`, `LoginItemManager.swift`
- **Commit**: `git commit -m "Phase 5 Task 5.4: Slash command editor, login item, Finish button"`

---

## Phase 5 Build Verification

```bash
xcodebuild -scheme Courier -destination 'platform=macOS' build && xcodebuild -scheme CourierTests -destination 'platform=macOS' test 2>&1 | tail -20
```

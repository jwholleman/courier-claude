# Phase 6: Settings & Polish

> Read `courier-architecture.md` first if you haven't already.

---

## Task 6.1 — Settings window

- All wizard options in tabbed/sectioned layout
- Open via menu bar "Settings..." (Cmd+,)
- Changes apply immediately (hotkey re-registers, service list updates in launcher)
- Dark/light/system appearance mode selector
- Disabled services shown in settings with toggle to re-enable (re-enabling adds them back to launcher)
- **Per-App Keystroke Configuration section**: For each LLM service (Claude, ChatGPT, Gemini, Perplexity), show a dropdown to select the keystroke sequence used during native app dispatch: "Cmd+N (New conversation)", "Cmd+L (Focus input)", "None (Just paste)". Default values come from Task 3.3's `LLMKeystroke` enum, but users can override per-service. This is critical because target apps change keyboard shortcuts across versions — making this user-configurable avoids shipping hotfixes.
- **"Check for Updates..." menu item**: Add to the menu bar menu, disabled with tooltip "Coming in a future version". This reserves the UI slot for Sparkle integration post-v1.
- **"Reset to Defaults" button** at bottom of settings, with confirmation alert: "Reset all settings to defaults? This cannot be undone." Resets hotkey, service selection, slash commands, appearance, keystroke config, and login item to their default values.
- **Required imports**: `SettingsView.swift` needs `import SwiftUI` and `import KeyboardShortcuts`.
- Verify: all settings persist and take effect immediately, a11y audit passes, re-enabling a service makes it appear in launcher, Reset to Defaults restores all original values, per-app keystroke config changes take effect on next dispatch
- Files created: `SettingsView.swift`. Files modified: `AppDelegate.swift` (wire Cmd+, to settings), `CourierApp.swift` (Settings menu item, Check for Updates placeholder)
- **Commit**: `git commit -m "Phase 6 Task 6.1: Settings window with per-app keystroke config"`

---

## Task 6.2 — Visual polish

- Launcher: 680pt wide, 12pt corner radius, 16pt/12pt padding, system shadow
- Animate panel show/hide (fade + slight scale, ~0.15s duration) — use `NSAnimationContext.runAnimationGroup` with `panel.animator().alphaValue`. Do NOT use `CABasicAnimation` (lower-level, overkill for a single panel) or SwiftUI `.animation()` modifiers on the `NSHostingView` (causes layout thrashing and dropped frames with the text editor present). See the `LauncherWindowController` skeleton code in Phase 1 for the exact pattern.
- **Commit**: `git commit -m "Phase 6 Task 6.2: Visual polish — animations, dark/light mode, Reduce Motion/Transparency"`
- **Reduce Motion**: Check `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`. When `true`, replace the fade+scale animation with an instant show/hide (or a very short fade <0.05s). This is an Apple accessibility requirement. Listen for `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` to react to changes while the app is running.
- System/light/dark mode theming via `NSApp.appearance`. **All custom colors must be defined in Assets.xcassets with Both Appearances variants**, or use `NSColor(name:dynamicProvider:)`. Never hardcode RGB values — they won't switch with appearance changes. When system appearance changes while the panel is visible, the panel should update immediately (test by toggling appearance in System Settings with panel open).
- **Reduce Transparency**: When `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency` is `true`, the `NSVisualEffectView` renders opaque. Verify that text contrast and overall appearance are correct in this mode — the background will be a solid grey rather than translucent. No code changes needed (the visual effect view handles this automatically), but verify visually.
- Verify contrast ratios in both light and dark mode using Digital Color Meter or Accessibility Inspector
- Verify: looks polished in both light and dark, contrast passes in both modes, animations feel smooth, rapid toggle doesn't produce visual artifacts, Reduce Motion -> no animation, Reduce Transparency -> opaque background with correct contrast
- Files modified: `LauncherWindowController.swift` (animation — already in skeleton), `Assets.xcassets` (color sets with Both Appearances), `LauncherPanel.swift` (shadow tuning)

---

## Task 6.3 — Edge cases

- Unconfigured/disabled services: **hidden from launcher** (not shown at all), but visible as disabled in Settings where they can be re-enabled
- Handle empty query (submit disabled — already done in Task 2.1)
- Handle very long queries (scrolling works, 8000 char warning — already done in Task 2.1)
- Multi-monitor: center on screen with current mouse/focus (already done in Task 1.2)
- Hotkey conflict detection/warning (already done in Task 1.3)
- Gemini: show as available but mark "(Browser only)" until native app exists
- If all services somehow get disabled: prevent this in Settings (at least one must remain enabled)
- **System state changes while app is running**:
  - Display configuration change (monitor added/removed, resolution change): re-calculate panel position on next show. Listen for `NSApplication.didChangeScreenParametersNotification`.
  - System appearance change (light<->dark) while panel is visible: colors should update automatically via asset catalog / dynamic `NSColor`. Verify no stale cached colors.
  - Sleep/wake cycle: verify hotkey still works after wake. Listen for `NSWorkspace.didWakeNotification`, re-check `AXIsProcessTrusted()` and re-register hotkey if needed.
  - Default browser changed while running: no action needed (`NSWorkspace.open` always uses current default).
  - Target app installed/uninstalled while running: `ServiceRegistry.installedAppsCache` refreshes automatically via workspace notifications (see Dispatch Chain section in architecture doc).
  - **Stage Manager enabled/disabled**: Verify panel appears correctly in Stage Manager mode — not grouped with other windows, dismisses properly, appears over staged window sets. The `.canJoinAllSpaces` + `.fullScreenAuxiliary` collection behavior should handle this, but must be verified visually.
  - **Secure Event Input**: If `IsSecureEventInputEnabled()` returns true when the hotkey fails to fire, show toast: "A secure input app may be blocking Courier's hotkey." This is checked on the 60-second timer (Task 1.3) but also worth checking reactively if the user reports the hotkey stopped working.
- **Crash recovery**: If the app crashes mid-dispatch (clipboard not yet restored), the user's original clipboard is lost. Mitigation: write a `pendingClipboardRestore: Bool` flag to UserDefaults before step 1, clear it after step 6. On next launch, if flag is set, show notification: "Courier may not have restored your clipboard from the last session." (Full clipboard recovery is impractical — just inform the user.)
- Verify: disabling a service hides it from launcher, shows disabled in settings, re-enabling brings it back. Cannot disable all services. Monitor add/remove doesn't break panel positioning. Sleep/wake -> hotkey still works. Appearance change -> colors update immediately. Stage Manager -> panel not grouped. Secure Event Input -> toast shown.
- Files modified: `LauncherWindowController.swift` (screen-change listener, sleep/wake), `ServiceDispatcher.swift` (crash recovery flag), `NotificationHelper.swift` (toast panel canBecomeKey=false)
- **Commit**: `git commit -m "Phase 6 Task 6.3: Edge cases — Stage Manager, secure input, crash recovery, display changes"`

---

## Error Handling & Toast Notifications

The app uses two notification mechanisms via `NotificationHelper.swift`:

### Custom transient toast (auto-dismiss after 4 seconds, no permission required)
Used for most operational feedback (paste failures, browser failures, clipboard status).

- **Pre-create a single reusable toast `NSPanel`** at app launch (like the launcher panel). Update text and reshow on each notification. Do not allocate a new panel per toast.
- Position: top-center of the active screen, 80pt below the menu bar (similar to system HUD notifications)
- Size: auto-width based on text (min 200pt, max 400pt), ~40pt height
- Background: `NSVisualEffectView` with `.hudWindow` material, 8pt corner radius (dark translucent pill, similar to system volume/brightness HUD)
- Text: `.systemFont(ofSize: 13)`, `.white` (on HUD background), single line, centered
- Animation: fade in 0.15s, auto-dismiss after 4s with fade out 0.3s. Respects Reduce Motion (instant show/hide).
- Clicking the toast dismisses it immediately. If the toast has an action (e.g., "open browser fallback"), clicking performs the action then dismisses.
- If a new toast fires while one is showing, replace the current one immediately (no queue, no stacking).
- `panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)` (just above the launcher panel, below system alerts). Do NOT use `.statusBar` — it's too aggressive and overrides system floating panels.
- **Critical — `canBecomeKey` and `canBecomeMain` must both return `false`** on the toast panel. Without this, showing a toast while the launcher is open causes the launcher panel to resign key, which triggers dismissal. Override both in the toast `NSPanel` subclass (or set via a non-activating style). This is the most likely source of "launcher randomly dismisses" bugs.
- `panel.isReleasedWhenClosed = false` (panel is pre-created and reused)
- `panel.ignoresMouseEvents = false` (clickable), `panel.collectionBehavior = [.canJoinAllSpaces, .stationary]`

### System `UNUserNotificationCenter` notification (persists in Notification Center)
Reserved for critical errors that require user action (permission denied, accessibility revoked). These need the notification permission prompt on first use — request permission during setup wizard.

### Error Message Reference

| Scenario | Feedback Type | Message |
|----------|--------------|---------|
| AppleScript paste fails (all retries exhausted) | Toast | "Couldn't paste into [App]. Query copied to clipboard." + opens browser fallback |
| Accessibility permission denied | System notification | "Courier needs Accessibility access to paste queries." + action to open System Settings |
| Accessibility permission revoked | System notification | "Courier lost Accessibility access. Click to re-enable." + action to open System Settings |
| Automation permission denied (per-app) | System notification | "Courier needs permission to control [App]." + action to open System Settings -> Automation |
| Browser fails to open | Toast | "Couldn't open browser. Query copied to clipboard." |
| URL construction fails | Toast | "Couldn't create URL. Query copied to clipboard." |
| Target app not responding (cold launch) | Toast | "Waiting for [App] to launch..." (shown after 3s, auto-dismiss when app activates or at 10s timeout) |
| Target app not responding (warm, all retries) | Toast | "Couldn't reach [App]. Query copied to clipboard." + opens browser fallback |
| Hotkey registration fails (conflict) | Alert dialog | "Option+Space is already in use. Choose a different shortcut." + shortcut recorder |
| Query exceeds 8000 chars | Inline warning | "Query will be truncated to 8000 characters" (below input field) |
| Large clipboard skipped | Toast | "Clipboard too large to save — original clipboard will not be restored." |
| Crash recovery (pending restore flag) | Toast on launch | "Courier may not have restored your clipboard from the last session." |

---

## Automated Test Plan

### Unit Tests (Xcode test target, run in CI)
- **Service registry**: lookups by type, by slash command, exact-match-only, unknown command returns nil
- **Slash command parsing**: all 14 commands, case insensitivity (with explicit locale), non-first-character rejection, partial match rejection
- **URL encoding**: custom `CharacterSet` encodes `&`, `=`, `+`, `#`. Round-trip test: encode -> construct URL -> verify query param value. Test with emoji, CJK, RTL text.
- **Settings migration**: simulate version 0 -> version 1, verify values preserved
- **AppSettings**: round-trip persistence, always-has-selection invariant, disabled-service fallback
- **Whitespace trimming**: empty, spaces-only, newlines-only, tabs -> all rejected
- **Submit debounce**: simulated double-Enter only fires one dispatch

### Integration Tests (Xcode test target, mock NSWorkspace)
- **Dispatch chain**: mock `NSWorkspace` to verify correct URL construction, correct bundle ID lookup, correct fallback from native -> browser
- **Clipboard save/restore cycle**: save -> modify -> restore -> verify contents match original
- **Concurrent dispatch**: verify second dispatch cancels first's restore timer
- **Rapid sequential dispatch**: submit -> immediately re-invoke -> submit again -> verify first clipboard restore was cancelled, second dispatch owns clipboard, and final restore returns original clipboard contents

### UI Tests (XCUITest, run manually pre-release)
- Panel show/dismiss (hotkey, Escape, click-outside, resign key via system alert)
- Keyboard navigation (Tab, arrow keys, Enter)
- Service selection (click, keyboard, slash command)
- Setup wizard happy path (all 5 steps with defaults -> Finish -> wizard dismissed -> hotkey works -> panel appears)
- Setup wizard quit mid-wizard (preserved selections on re-launch)

### Manual Test Matrix (per phase)
- Multi-monitor (test panel position on external display, mixed DPI)
- Full-screen app (test panel appears over full-screen Safari)
- VoiceOver (full flow: invoke -> type -> select service -> submit)
- Japanese IME (marked text composition -> submit)
- Sleep/wake -> hotkey still works
- Appearance change (light<->dark with panel open)
- Reduce Motion enabled -> panel show/hide has no animation
- Reduce Transparency enabled -> panel background is opaque, text legible, contrast passes
- Held Enter key -> only one dispatch fires (submit debounce)
- System alert appears while panel is visible -> panel dismisses (resign key)
- Notification Center opened while panel visible -> panel dismisses
- Stage Manager mode (panel appears, not grouped with other windows, dismisses correctly)
- Secure Event Input active (1Password open) -> document hotkey behavior as known limitation

### Performance Tests
- Hotkey-to-cursor latency: `os_signpost` markers, 10 trials, p95 < 80ms
- Memory footprint: Instruments Allocations, measured after Phase 2 (panel shown, 10 lines of text) and after Phase 6 (all services configured). Target < 30MB resident.

---

## Verification Checklist (Applied After Each Phase)

1. Build and run successfully (zero warnings, zero errors)
2. Menu bar icon appears, no dock icon
3. Hotkey triggers/dismisses panel
4. Rapid hotkey toggling doesn't glitch
5. A service is always selected (never blank)
6. Service selection + submission dispatches correctly
7. Slash commands work for ALL 14 commands across ALL 7 services (see Task 4.1 test matrix)
8. Settings persist across app restarts and reboots
9. Error notifications (toasts + system) appear for all failure scenarios
10. Apple HIG checklist passes for all new UI
11. Accessibility audit passes (Xcode Inspector, VoiceOver test)
12. Contrast ratios verified in both light AND dark mode (4.5:1 text, 3:1 components)
13. Text input receives keystrokes on first focus (canBecomeKey working)
14. Special characters in queries encode correctly (test: `&`, `=`, `+`, `#`, `%`, emoji, CJK)
15. Panel appears on all Spaces/desktops and over full-screen apps
16. Menu bar does NOT change to Courier's when panel is shown (no activation stealing)
17. Hotkey responds within 100ms even after extended idle (App Nap prevention)
18. UI does not freeze during AppleScript dispatch (background thread)
19. Automation permission prompt handled separately from Accessibility permission
20. Pasting text starting with `/cl ` does NOT trigger slash command
21. Whitespace-only input cannot be submitted
22. Memory footprint stays under 30MB resident (profile with Instruments after Phase 2)
23. Panel positioned in upper-third of screen (not dead center)
24. Single-instance check: second launch activates first and quits
25. About window shows correct version number
26. Focus returns to previous app on dismiss (and doesn't crash if previous app quit)
27. Accessibility permission revocation detected and notification shown
28. Sleep/wake cycle -> hotkey still works
29. Display configuration change -> panel repositions correctly
30. Japanese IME / emoji picker works in text field
31. Concurrent submit doesn't corrupt clipboard restore
32. Cold-launch target app (not running) -> dispatch succeeds within 10s timeout
33. Reserved shortcuts (Cmd+Q, Cmd+Tab, etc.) rejected in shortcut recorder
34. Panel background is translucent blur (NSVisualEffectView), correct in both translucent and Reduce Transparency modes
35. Reduce Motion -> panel show/hide has no animation
36. Panel dismisses when it loses key status (system alert, Notification Center, Dock click)
37. Double-tap / held Enter only fires one dispatch (submit debounce)
38. Toast notification appears, auto-dismisses, and is clickable
39. Help menu item opens documentation URL
40. Setup wizard happy path completes successfully (all 5 steps -> wizard dismissed -> hotkey works -> panel appears -> text input accepts keystrokes -> submit dispatches correctly)
41. Stage Manager: panel appears correctly, not grouped with other app windows, dismisses properly
42. Secure Event Input: behavior documented when active (known limitation — hotkey may not fire)
43. Per-app keystroke config: user can edit Cmd+N/Cmd+L/none per LLM service in Settings, changes take effect on next dispatch

---

## Phase 6 Build Verification

```bash
xcodebuild -scheme Courier -destination 'platform=macOS' build && xcodebuild -scheme CourierTests -destination 'platform=macOS' test 2>&1 | tail -20
```

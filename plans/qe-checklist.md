# Courier QE Checklist

Comprehensive quality checklist for manual validation and automated test coverage.

---

## Automated Tests

Run all test suites before any release:

- [ ] `AppSettingsTests` (11 tests) — settings persistence, fallback logic, v1→v2 migration
- [ ] `ServiceRegistryTests` (4 tests) — provider lookup, slash command mapping
- [ ] `SlashCommandTests` (6 tests) — exact match, case insensitivity, prefix highlighting, Turkish locale
- [ ] `URLEncodingTests` (9 tests) — `&`, `=`, `+`, `#`, space, emoji, CJK, injection prevention
- [ ] `DispatchChainTests` (13 tests) — URL structures, keystroke config, clipboard round-trip, crash flag

All 43 tests must pass with no cross-test UserDefaults contamination.

---

## A — Core Functionality

- [ ] Hotkey (⌥Space default) opens launcher
- [ ] Hotkey again closes launcher
- [ ] Escape key closes launcher
- [ ] Return submits query
- [ ] Return ignored when query is empty or whitespace-only
- [ ] Cmd+Return inserts newline, does not submit
- [ ] Shift+Return inserts newline, does not submit
- [ ] Deliver button disabled when query is empty
- [ ] Double-Return doesn't double-dispatch (debounce)

---

## B — Service Switching

- [ ] All 9 services appear in correct order
- [ ] Clicking a service icon selects it
- [ ] Hold Cmd → position indicators appear under each service icon
- [ ] Cmd+1 through Cmd+9 switch services by position
- [ ] Out-of-bounds Cmd+Number is silently ignored
- [ ] Last-used service is restored on next launch
- [ ] If last-used service is disabled, first enabled service is selected

### Slash Commands

- [ ] Typing `/` as first character enters slash mode
- [ ] Pasting `/` as first character does NOT enter slash mode
- [ ] Partial prefix (e.g. `/c`) highlights matching services in overlay but does not switch
- [ ] Exact match + space (e.g. `/cl `) switches to Claude and clears prefix
- [ ] Unmatched prefix + space exits slash mode, keeps text as-is
- [ ] All 19 built-in commands resolve correctly (see table below)
- [ ] Commands are case-insensitive (`/CL`, `/Google`, etc.)

| Command | Service |
|---------|---------|
| `/cl`, `/claude` | Claude |
| `/cc`, `/claudecode` | Claude Code |
| `/ch`, `/chatgpt` | ChatGPT |
| `/ge`, `/gemini` | Gemini |
| `/p`, `/perplexity` | Perplexity |
| `/k`, `/kagi` | Kagi |
| `/g`, `/google` | Google |
| `/yt`, `/youtube` | YouTube |
| `/d`, `/ddg`, `/duckduckgo` | DuckDuckGo |

---

## C — Dispatch Paths

### Search Services (URL-based)
- [ ] Google opens `https://www.google.com/search?q=<query>`
- [ ] Kagi opens `https://kagi.com/search?q=<query>`
- [ ] DuckDuckGo opens `https://duckduckgo.com/?q=<query>`
- [ ] YouTube opens `https://www.youtube.com/results?search_query=<query>`
- [ ] Perplexity opens `https://www.perplexity.ai/search?q=<query>`
- [ ] Query with `&`, `=`, `+`, `#` encodes correctly (no spurious params)
- [ ] Query with spaces, emoji, CJK characters encodes correctly

### LLM Browser Services
- [ ] Claude browser: opens claude.ai, paste lands in input
- [ ] ChatGPT browser: opens chatgpt.com, paste lands in input
- [ ] Gemini browser: opens gemini.google.com, paste lands in input
- [ ] Cold browser launch: paste waits for page load (3s + 800ms settle)
- [ ] Warm browser launch: paste arrives faster (900ms + 800ms settle)

### Native App Services (when installed)
- [ ] Claude native: new conversation opened (Shift+Cmd+O), query pasted, Return sent
- [ ] ChatGPT native: new conversation opened (Cmd+N), query pasted, Return sent
- [ ] Keystroke override (Advanced settings) changes new-conversation key used
- [ ] Cold native launch: extended delays (10–15s timeout, 2s settle)
- [ ] Warm native launch: normal delays

### Claude Code
- [ ] Resolves `claude` binary from versioned path, Homebrew, or `/usr/local/bin`
- [ ] Opens Terminal and runs `cd ~; claude "<prompt>"`
- [ ] If binary not found: toast "Claude Code isn't available" + copies query

### Clipboard Handling
- [ ] Clipboard contents saved before dispatch
- [ ] Clipboard contents restored after dispatch (within service-specific delay)
- [ ] Clipboard >50MB: skipped with toast "Clipboard too large to save"
- [ ] Empty clipboard: no restore attempt (nil path)

### Query Limits
- [ ] Query >8000 chars: warning "Query will be truncated to 8000 characters" appears
- [ ] Dispatch truncates to 8000 chars silently

---

## D — Toast & Notifications

### In-App Toasts (auto-dismiss after 4s, click to dismiss)
- [ ] Dispatch failure → "Query copied to clipboard" toast
- [ ] App launch timeout → toast with app name
- [ ] Accessibility not granted (paste-only fallback) → instructional toast
- [ ] Claude Code not found → toast
- [ ] Secure input blocking hotkey → toast
- [ ] Clipboard too large → toast
- [ ] Crash recovery on launch → toast
- [ ] Toast respects Reduce Motion (no animation when enabled)
- [ ] Toast appears top-center, 12pt below menu bar

### System Notifications (Notification Center)
- [ ] Accessibility revoked: persistent notification with link to System Settings
- [ ] Automation denied: persistent notification with link to System Settings

### Permission Alerts (Modal)
- [ ] Accessibility alert: appears when AXIsProcessTrusted returns false
- [ ] Accessibility alert "Open Accessibility Settings" opens correct pane
- [ ] Automation alert: appears when System Events AppleScript is denied
- [ ] Automation alert "Use Browser Instead" falls back correctly

---

## E — Settings

### General Tab
- [ ] Theme picker: Light / Dark / System applies immediately
- [ ] Launch at Login toggle enables/disables SMAppService registration
- [ ] Hotkey recorder captures new shortcut
- [ ] Hotkey reset button restores ⌥Space
- [ ] Orange warning appears when hotkey is ⌥Space and ChatGPT.app is installed

### Services Section (General Tab)
- [ ] Enable/disable toggle works per service
- [ ] Cannot disable the last remaining enabled service
- [ ] Drag handle visible on hover; drag reorders services
- [ ] New order reflected in launcher immediately
- [ ] Custom slash commands field: comma-separated, "/" prefix, case-folded
- [ ] Empty custom field reverts to built-in defaults

### Advanced Tab
- [ ] Keystroke picker for Claude: Cmd+N / Cmd+L / Shift+Cmd+O / None
- [ ] Keystroke picker for ChatGPT: same options
- [ ] Picker selections persist across restart
- [ ] "None (Just paste)" skips new-conversation keystroke

### Reset
- [ ] Reset All Settings restores all defaults (hotkey, order, slash commands, overrides, login item, theme)
- [ ] Confirmation dialog appears before reset

### Persistence
- [ ] All settings survive app restart (UserDefaults round-trip)
- [ ] Settings version 2 migration: legacy ChatGPT "none" → "cmdN"

---

## F — Setup Wizard

- [ ] Wizard appears on first launch (`hasCompletedSetup == false`)
- [ ] Wizard does not appear on subsequent launches
- [ ] Step 1 (Welcome): displays app icon and tagline
- [ ] Step 2 (Service Selection): 3×3 grid, tiles toggle on/off, selection highlighted
- [ ] Cannot proceed with all services disabled
- [ ] Step 3 (Hotkey): recorder + reset button functional
- [ ] Step 4 (Almost Done): Launch at Login toggle
- [ ] Back button (and Cmd+[) navigates to previous step
- [ ] Return advances to next step
- [ ] Return on final step completes wizard
- [ ] Accessibility: each step announced as "Setup step X of 4"

---

## G — Permissions & System

- [ ] Accessibility permission requested at first launch requiring paste
- [ ] Permission monitor checks every 60s; alerts if revoked
- [ ] Permission state rechecked after sleep/wake
- [ ] Single-instance guard: launching a second copy activates the first and exits
- [ ] App Nap disabled (hotkey fires reliably during system idle)
- [ ] Panel repositions on screen parameter change (multi-monitor, resolution change)

---

## H — Accessibility (VoiceOver)

- [ ] NSPanel has correct accessibility role and label
- [ ] NSTextView placeholder text announced
- [ ] Cmd+Number service switch announced
- [ ] Service button selection state announced
- [ ] Setup wizard step progress announced
- [ ] Service selection tiles announce selection state
- [ ] Search provider tiles announce selection state
- [ ] Settings drag handles, toggles, and fields labeled
- [ ] Hotkey recorder labeled

---

## I — Edge Cases

- [ ] Crash recovery: if `pendingClipboardRestore` flag set at launch, toast appears and flag clears
- [ ] Multi-line query (newlines via Cmd+Return) dispatches intact
- [ ] Query containing `"` and `\` dispatches without AppleScript injection
- [ ] Panel resizes smoothly from 1 to N lines (80–320pt range)
- [ ] Slash mode state clears when panel is closed and reopened
- [ ] `hasSubmitted` debounce resets when panel reopens

---

## J — Browser Fallback (item #14)

*Separate verification pass — see known issues #14.*

- [ ] Claude: native dispatch fails → browser opens, query pastes, Return sent
- [ ] ChatGPT: native dispatch fails → browser opens, query pastes, Return sent
- [ ] Gemini: browser opens, query pastes, Return sent (browser-only service)

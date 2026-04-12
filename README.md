# Courier

Courier is a macOS menu bar utility for sending a query to a chosen service from a single launcher.

Press a global keyboard shortcut, type a prompt or search, choose a destination, and dispatch it without manually switching between apps and browser tabs.

## What It Does

- Opens a Spotlight-style launcher from a global hotkey
- Sends a query to a selected service
- Supports both native-app dispatch and browser-backed services
- Lets you enable, disable, and reorder services in Settings
- Supports slash commands for quick service switching
- Remembers the last used service and falls back safely if that service is disabled

## Supported Services

Courier currently supports these services:

- Claude
- Claude Code
- ChatGPT
- Gemini
- Perplexity
- Kagi
- Google
- YouTube
- DuckDuckGo

Dispatch behavior varies by service and whether the **Use desktop apps** setting is enabled:

- `Claude`, `ChatGPT`, `Perplexity`: native app dispatch when the desktop app is installed and Use desktop apps is on; browser fallback otherwise
- `Gemini`: browser-backed
- `Kagi`, `Google`, `YouTube`, `DuckDuckGo`: browser-backed search submission
- `Claude Code`: opens a new Terminal window and starts a fresh Claude Code session

## Key Features

### Launcher

- Global hotkey to open the launcher
- Keyboard navigation for service switching
- Slash command mode by typing `/` at the start of the input
- Command-key overlay for service shortcuts
- Character limit handling for long queries

### Settings

- Change the global keyboard shortcut
- Toggle launch at login
- Change theme
- Enable or disable services
- Reorder services by drag and drop
- Edit slash commands per service
- Configure native-app keystrokes for supported services
- Toggle whether to use desktop apps (when off, all services fall back to browser)
- Reset settings back to defaults

When **Use desktop apps** is on, Courier detects which supported desktop apps (Claude, ChatGPT, Perplexity) are installed and dispatches to them directly. Settings shows which apps are currently detected.

## Service Ordering

Service order is user-configurable in Settings.

- Reordering in Settings is reflected in the launcher
- The launcher uses the same ordered enabled-services list for:
  - visible service buttons
  - command-number positions
  - fallback selection when the current service is disabled

## Slash Commands

Courier supports built-in slash commands and user overrides.

Examples:

- `/cl` for Claude
- `/cc` for Claude Code
- `/ch` for ChatGPT
- `/ge` for Gemini
- `/p` for Perplexity
- `/k` for Kagi
- `/g` for Google
- `/yt` for YouTube
- `/ddg` for DuckDuckGo

Slash commands are exact-match, case-insensitive, and customizable in Settings.

## Development

### Requirements

- macOS 14+
- Xcode 15+
- Swift 5.9+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation

### Generate the Project

```bash
xcodegen generate
```

### Build

```bash
xcodebuild -scheme Courier -destination 'platform=macOS' build
```

### Test

```bash
xcodebuild -scheme CourierTests -destination 'platform=macOS' test
```

## Project Structure

- [`Courier/App`](/Users/John Holleman/repos/Courier/courier-claude/Courier/App): app lifecycle and app delegate
- [`Courier/Models`](/Users/John Holleman/repos/Courier/courier-claude/Courier/Models): settings, service types, slash commands
- [`Courier/Services`](/Users/John Holleman/repos/Courier/courier-claude/Courier/Services): dispatch logic per service
- [`Courier/Views`](/Users/John Holleman/repos/Courier/courier-claude/Courier/Views): launcher, settings, setup UI
- [`CourierTests`](/Users/John Holleman/repos/Courier/courier-claude/CourierTests): unit and behavior tests
- [`plans`](/Users/John Holleman/repos/Courier/courier-claude/plans): architecture and phased implementation notes

## Notes And Known Behavior

- Secure Event Input is monitored and Courier will warn if it appears active.
- Manual verification on April 1, 2026 did not reproduce a blocked Courier hotkey while Secure Event Input was active on this machine, so this is currently documented as a cautionary warning rather than a confirmed failure mode.
- Gemini currently behaves as a browser-backed service.
- Claude Code depends on a local Claude Code installation being available on the Mac.

## Verification Status

Recent manual verification covered:

- launcher behavior in light and dark mode
- reduce motion / reduce transparency behavior
- sleep / wake hotkey behavior
- Stage Manager behavior
- service fallback behavior
- YouTube dispatch
- Claude Code dispatch
- settings reordering reflected in the launcher

Automated verification currently includes:

- service registry coverage
- slash command lookup coverage
- URL encoding coverage
- clipboard save / restore coverage
- settings persistence and fallback coverage

## Installation

1. Download `Courier-1.0.1.dmg` from the [Releases page](https://github.com/jwholleman/courier/releases)
2. Open the dmg and drag **Courier Launcher** to Applications
3. Launch Courier from Applications — macOS may show a Gatekeeper prompt on first launch; click **Open** to proceed
4. Complete the setup wizard to configure your hotkey, services, and login item

## Permissions

Courier requires two permissions granted during the setup wizard:

- **Accessibility** — required for native dispatch (pasting into Claude, ChatGPT)
- **Automation** — macOS prompts per-app the first time Courier dispatches to it; click Allow

If a permission was denied, open **System Settings → Privacy & Security → Accessibility** (or **Automation**) and enable Courier.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Hotkey doesn't fire | System Settings → Privacy & Security → Accessibility — enable Courier |
| "Courier Launcher.app can't be opened" on first launch | Right-click → Open, or System Settings → Privacy & Security → click Open Anyway |
| Query doesn't paste into native app | System Settings → Privacy & Security → Automation → enable Courier → target app |
| Hotkey conflicts with another app | Courier Settings → General → change the hotkey |
| ChatGPT conflict with ⌥Space | ChatGPT desktop also uses ⌥Space — change one; Courier warns in Settings when this is detected |

## Screenshots

*(screenshots coming soon)*

# Changelog

All notable changes to Courier will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.0.1] - 2026-04-12

### Changed

- Increased the menu bar icon size slightly so the toolbar presence reads more clearly
- Improved setup service icon rendering in dark mode so Kagi stays visible during onboarding

### Fixed

- Removed a Swift accessibility announcement warning from launcher builds

## [1.0.0] – 2026-04-12

### Added

- Global hotkey launcher (⌥Space default, fully customizable)
- Native dispatch to Claude and ChatGPT desktop apps; browser dispatch for Gemini, Perplexity, Kagi, Google, YouTube, DuckDuckGo, and Claude Code
- Slash commands for quick service switching (`/cl`, `/ch`, `/ge`, `/p`, `/k`, `/g`, `/yt`, `/ddg`, `/cc`, and more)
- Cmd+number overlay for keyboard-driven service selection
- Setup wizard for first-run configuration (hotkey, services, login item)
- Settings window with per-service keystroke overrides, drag-to-reorder, service enable/disable, theme selector, and launch-at-login toggle
- Toast notifications and persistent accessibility alerts
- Sparkle auto-update (checks against appcast.xml on GitHub)
- Developer ID signing and notarization for Gatekeeper compatibility

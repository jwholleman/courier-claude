# Phase 7: Deployment

> Read `courier-architecture.md` first if you haven't already.

---

## Overview

Courier is not App Store eligible — `com.apple.security.app-sandbox` is `false` (required for Apple Events / native dispatch). Distribution is via **Developer ID** signing + Apple notarization + direct download (.dmg). This phase produces a shippable, notarized `.dmg` and wires up Sparkle for future over-the-air updates.

---

## Task 7.1 — Developer ID signing setup

- In Xcode → Project → Signing & Capabilities, set `DEVELOPMENT_TEAM` to your Apple Developer account team ID
- Confirm `CODE_SIGN_STYLE = Automatic` (already set)
- Signing identity: **Developer ID Application** (not Apple Development, not App Store)
- Confirm entitlements are correct:
  - `com.apple.security.app-sandbox = false` — required for Apple Events; means no App Store
  - `com.apple.security.automation.apple-events = true` — required for native dispatch
  - No additional entitlements needed at this time
- Verify: project builds without signing errors; `codesign -dv --verbose=4 build/Courier.app` shows `Developer ID Application` identity
- Files modified: `Courier.xcodeproj/project.pbxproj` (DEVELOPMENT_TEAM)
- **Commit**: `git commit -m "Phase 7 Task 7.1: Developer ID signing setup"`

---

## Task 7.2 — Version number housekeeping

- Move version numbers out of `Info.plist` and into Xcode build settings:
  - Set `MARKETING_VERSION = 1.0.0` in project build settings (maps to `CFBundleShortVersionString`)
  - Set `CURRENT_PROJECT_VERSION = 1` in project build settings (maps to `CFBundleVersion`)
  - In `Info.plist`, replace hardcoded version strings with `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)`
- This allows bumping versions from build settings or CI without editing the plist by hand
- `CFBundleShortVersionString` is the user-visible version (e.g. `1.0.0`); `CFBundleVersion` is the monotonically increasing build number (e.g. `1`)
- Verify: `About Courier` window shows correct version string; `defaults read ~/Library/Preferences/com.courier.Courier CFBundleShortVersionString` returns `1.0.0`
- Files modified: `Info.plist`, `Courier.xcodeproj/project.pbxproj`
- **Commit**: `git commit -m "Phase 7 Task 7.2: Move version numbers to build settings"`

---

## Task 7.3 — Archive and notarize

### Archive
- In Xcode: Product → Archive → select **Developer ID** distribution → export to disk
- Or via command line:
  ```bash
  xcodebuild archive \
    -scheme Courier \
    -archivePath build/Courier.xcarchive \
    -destination "generic/platform=macOS"

  xcodebuild -exportArchive \
    -archivePath build/Courier.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist ExportOptions.plist
  ```
- `ExportOptions.plist` must specify `method = developer-id` and `signingStyle = automatic`

### Notarize
- Use `notarytool` (Xcode 13+):
  ```bash
  xcrun notarytool submit build/export/Courier.app \
    --apple-id YOUR_APPLE_ID \
    --team-id YOUR_TEAM_ID \
    --password APP_SPECIFIC_PASSWORD \
    --wait
  ```
  Use an **app-specific password** (generated at appleid.apple.com), not your Apple ID password
- Staple the notarization ticket so the app passes Gatekeeper offline:
  ```bash
  xcrun stapler staple build/export/Courier.app
  ```
- Verify: `spctl --assess --type execute -v build/export/Courier.app` prints `accepted` — this is the Gatekeeper check end users' Macs will run
- Files created: `ExportOptions.plist` (committed to repo for reproducible builds)
- **Commit**: `git commit -m "Phase 7 Task 7.3: Add ExportOptions.plist for Developer ID archive export"`

---

## Task 7.4 — DMG installer

- Create a distributable `.dmg` with a background image, app icon, and Applications alias using `create-dmg` (Homebrew):
  ```bash
  brew install create-dmg
  create-dmg \
    --volname "Courier" \
    --window-size 540 380 \
    --icon-size 128 \
    --icon "Courier.app" 140 190 \
    --app-drop-link 400 190 \
    --hide-extension "Courier.app" \
    "Courier-1.0.0.dmg" \
    "build/export/"
  ```
- Notarize the `.dmg` itself (separate from notarizing the `.app`):
  ```bash
  xcrun notarytool submit Courier-1.0.0.dmg \
    --apple-id YOUR_APPLE_ID \
    --team-id YOUR_TEAM_ID \
    --password APP_SPECIFIC_PASSWORD \
    --wait
  xcrun stapler staple Courier-1.0.0.dmg
  ```
- Verify: mount the dmg, drag app to Applications, launch it — Gatekeeper should not block or warn; `spctl --assess --type execute -v /Applications/Courier.app` prints `accepted`
- Files created: `scripts/build-dmg.sh` (shell script wrapping the above for repeatability)
- **Commit**: `git commit -m "Phase 7 Task 7.4: DMG build script"`

---

## Task 7.5 — Sparkle auto-update

Sparkle is the standard macOS auto-update framework. Phase 6 already added a disabled "Check for Updates..." menu item as a placeholder — this task wires it up.

### Add Sparkle via SPM
- Add package: `https://github.com/sparkle-project/Sparkle` version `≥ 2.0.0`
- Link `Sparkle.framework` to the Courier target

### Generate EdDSA keys
```bash
# One-time key generation — store the private key securely (NOT in the repo)
./bin/generate_keys
```
- Add the **public key** to `Info.plist` as `SUPublicEDKey`
- Store the **private key** in your password manager; it signs each release's appcast

### Wire up the updater
- In `AppDelegate.swift`, instantiate `SPUStandardUpdaterController` and store it as a property
- Connect the "Check for Updates..." menu item action to `updater.checkForUpdates(_:)`
- Remove the `isEnabled = false` and tooltip placeholder added in Phase 6

### Appcast
- Host an `appcast.xml` at a stable URL (e.g. GitHub Releases raw URL or a dedicated CDN path)
- Add `SUFeedURL` to `Info.plist` pointing to that URL
- `appcast.xml` template:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
      <title>Courier</title>
      <item>
        <title>Version 1.0.0</title>
        <sparkle:version>1</sparkle:version>
        <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
        <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        <enclosure url="https://YOUR_HOST/Courier-1.0.0.dmg"
                   sparkle:edSignature="SIGNATURE_FROM_SIGN_UPDATE"
                   length="FILE_SIZE_IN_BYTES"
                   type="application/octet-stream" />
      </item>
    </channel>
  </rss>
  ```
- Sign each release's dmg: `./bin/sign_update Courier-1.0.0.dmg` — paste the output `edSignature` into the appcast

### Required entitlement
- Add `com.apple.security.network.client = true` to `Courier.entitlements` — Sparkle needs outbound network access to fetch the appcast and download updates

- Verify: "Check for Updates..." is enabled; clicking it contacts the appcast URL and either shows "You're up to date" or the update UI; no console errors about missing SUPublicEDKey or network entitlement
- Files modified: `AppDelegate.swift`, `Courier.entitlements`, `Info.plist`; files created: `appcast.xml`
- **Commit**: `git commit -m "Phase 7 Task 7.5: Sparkle auto-update integration"`

---

## Task 7.6 — Changelog

- Add `CHANGELOG.md` to the repo root in [Keep a Changelog](https://keepachangelog.com) format:
  ```markdown
  # Changelog

  ## [1.0.0] – 2026-XX-XX
  ### Added
  - Initial release
  - Global hotkey launcher (⌥Space default)
  - Native dispatch to Claude, ChatGPT; browser dispatch for Gemini, Perplexity, Kagi, Google, YouTube, DuckDuckGo, Claude Code
  - Slash commands for quick service switching
  - Setup wizard for first-run configuration
  - Settings window with per-service keystroke config, service reordering, theme selector
  - Sparkle auto-update
  ```
- On each future release: add a new `## [x.y.z]` section at the top before tagging
- When creating a GitHub Release (`gh release create vX.Y.Z`), copy the relevant `CHANGELOG.md` section into the release body — this is what users see on the GitHub Releases page and what Sparkle shows in the update prompt
- In `appcast.xml` (Task 7.5), add a `<sparkle:releaseNotesLink>` pointing to the GitHub Release URL so the Sparkle update sheet shows the release notes:
  ```xml
  <sparkle:releaseNotesLink>https://github.com/jwholleman/courier/releases/tag/v1.0.0</sparkle:releaseNotesLink>
  ```
- Verify: `CHANGELOG.md` exists at repo root; GitHub Release is created with formatted release notes; Sparkle update sheet shows a release notes link
- Files created: `CHANGELOG.md`
- **Commit**: `git commit -m "Phase 7 Task 7.6: Add CHANGELOG.md"`

---

## Task 7.7 — User-facing documentation

The README already covers the developer side well. This task adds what's missing for end users. The Help menu item already points to the GitHub repo, so the README is the user-facing docs for v1.

Replace the "Future Documentation" stub at the bottom of `README.md` with the following sections:

### Installation
- Download `Courier-X.Y.Z.dmg` from the [GitHub Releases page](https://github.com/jwholleman/courier/releases)
- Open the dmg, drag Courier to Applications
- Launch Courier from Applications — macOS may show a Gatekeeper prompt on first launch; click Open to proceed
- Complete the setup wizard (hotkey, services, login item)

### Permissions
Courier requires two permissions granted during the setup wizard:
- **Accessibility** — required for native dispatch (pasting into Claude, ChatGPT)
- **Automation** — macOS prompts per-app the first time Courier dispatches to it; click Allow

If a permission was denied, open System Settings → Privacy & Security → Accessibility (or Automation) and enable Courier.

### Troubleshooting
| Symptom | Fix |
|---------|-----|
| Hotkey doesn't fire | Check System Settings → Privacy & Security → Accessibility — Courier must be enabled |
| "Courier.app can't be opened" on first launch | Right-click → Open, or check System Settings → Privacy & Security → click Open Anyway |
| Query doesn't paste into native app | Grant Automation permission: System Settings → Privacy & Security → Automation → Courier |
| Hotkey conflicts with another app | Open Courier Settings → change the hotkey |
| ChatGPT hotkey conflict (⌥Space) | ChatGPT desktop also uses ⌥Space — change one of them; Courier warns in Settings |

- Remove the existing "Future Documentation" section from `README.md`
- Add a `## Screenshots` placeholder section with a note: *(screenshots coming soon)* — fill in with actual screenshots before publishing
- Verify: README renders correctly on GitHub; all links in README are valid; troubleshooting table covers the known issues from the QE checklist
- Files modified: `README.md`
- **Commit**: `git commit -m "Phase 7 Task 7.7: User-facing documentation in README"`

---

## Release Checklist

Run through this before publishing each release:

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in build settings
2. Add a new entry to `CHANGELOG.md`
3. Build passes with zero warnings and zero errors
4. Archive → export with Developer ID
5. `spctl --assess` passes on exported `.app`
6. Notarize and staple `.app`
7. Build `.dmg` via `scripts/build-dmg.sh`
8. Notarize and staple `.dmg`
9. `spctl --assess` passes on stapled `.dmg`
10. Sign dmg with `./bin/sign_update`, update `appcast.xml` with new version + signature + file size + `<sparkle:releaseNotesLink>`
11. Upload `.dmg` to release host
12. Publish updated `appcast.xml`
13. Create GitHub Release (`gh release create vX.Y.Z`) with the `CHANGELOG.md` entry as the body
14. Launch installed copy → "Check for Updates..." detects new version and shows release notes link

---

## Phase 7 Build Verification

```bash
# Verify signing
codesign -dv --verbose=4 build/export/Courier.app

# Verify Gatekeeper
spctl --assess --type execute -v build/export/Courier.app

# Verify notarization staple
xcrun stapler validate build/export/Courier.app
```

# Phase 1: Skeleton App (Menu Bar + Floating Window + Hotkey)

> Read `courier-architecture.md` first if you haven't already.

---

## Step 0 — Create project scaffolding files

Before writing any Swift code, create the project infrastructure files verbatim and verify the empty project compiles.

**Files to create (copy exactly from `courier-architecture.md`):**
1. `project.yml` — in repo root (`/Users/John Holleman/repos/Courier-claude/Courier-claude/project.yml`)
2. `Courier/App/Info.plist`
3. `Courier/Courier.entitlements`
4. `Courier/Resources/Assets.xcassets/Contents.json` (root manifest)
5. `Courier/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
6. `Courier/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
7. `Courier/Resources/Assets.xcassets/MenuBarIcon.imageset/Contents.json`
8. `Courier/Resources/Assets.xcassets/ServiceIcons/Contents.json` (namespace folder)
9. `Courier/Resources/Assets.xcassets/ServiceIcons/{claude,chatgpt,gemini,perplexity,kagi,google,duckduckgo}.imageset/Contents.json`
10. Empty `CourierTests/` directory
11. A minimal `Courier/App/CourierApp.swift` with just enough to compile:
    ```swift
    import SwiftUI

    @main
    struct CourierApp: App {
        var body: some Scene {
            MenuBarExtra("Courier", systemImage: "paperplane") {
                Text("Courier")
            }
        }
    }
    ```

**Verification:**
```bash
cd /Users/John Holleman/repos/Courier-claude/Courier-claude
xcodegen generate && xcodebuild -scheme Courier -destination 'platform=macOS' build 2>&1 | tail -30
```

This must succeed (zero errors) before proceeding to Task 1.1. If SPM resolution fails, run `xcodebuild -resolvePackageDependencies -scheme Courier` first.

**Commit**: `git add -A && git commit -m "Step 0: Project scaffolding — XcodeGen, Info.plist, entitlements, asset catalog"`

---

## Task 1.1 — Xcode project + menu bar app

- Create macOS SwiftUI project, deployment target macOS 14.0
- Set `LSUIElement = YES` in Info.plist
- `CourierApp.swift` with `MenuBarExtra` (placeholder SF Symbol template image, 16x16pt)
- **`@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate`** in `CourierApp.swift` — this connects the AppKit `AppDelegate` to the SwiftUI lifecycle. `AppDelegate` will own the `LauncherWindowController` and set up the hotkey in `applicationDidFinishLaunching`.
- **Single-instance check**: In `AppDelegate.applicationDidFinishLaunching`, check `NSRunningApplication.runningApplications(withBundleIdentifier:)`. If another instance is already running, activate it and call `NSApp.terminate(nil)`. Without this, two copies can fight over the same hotkey and menu bar slot.
- Menu items: "About Courier", "Show Courier", "Settings..." (Cmd+,), "Help" (opens documentation URL), "Quit Courier" (Cmd+Q)
- **About window**: Standard about panel showing app icon, version number (from bundle), copyright. Use `NSApp.orderFrontStandardAboutPanel(options:)` with `[.credits: NSAttributedString(...), .version: "1.0"]`.
- **Help menu item**: Opens the project's documentation URL in the default browser (even if it's just a GitHub repo README for V1). This is an HIG expectation — the Help menu is standard for macOS apps and gives users somewhere to go when permissions or dispatch don't work as expected.
- **Menu bar icon**: Use `paperplane` SF Symbol as template image for initial development (reference it by name in code: `Image(systemName: "paperplane")`). **Do not try to generate PNG image files for the menu bar icon during implementation** — SF Symbols work directly in SwiftUI `MenuBarExtra`. For service icons, generate 20x20pt solid-color placeholder PNGs (white square on transparent background) so the asset catalog resolves and the build succeeds. Real icons will be added during Human Checkpoint 3. For shipping, create a custom 16x16pt template image (alpha-channel only, 2x variant at 32x32pt) depicting a paper airplane or envelope motif matching the "Courier" name.
- All menu items have accessibility labels
- Verify: app in menu bar only (no dock), menu renders, About window shows version, Help opens URL, launching a second instance activates the first and quits, HIG + a11y pass
- **Required imports**: `CourierApp.swift` needs `import SwiftUI` and `import AppKit` (for `@NSApplicationDelegateAdaptor`). `AppDelegate.swift` needs `import AppKit` and `import KeyboardShortcuts`.
- Files created: `Courier/App/CourierApp.swift` (replace Step 0 stub), `Courier/App/AppDelegate.swift`. Files from Step 0 already exist: `project.yml`, `Info.plist`, `Courier.entitlements`, `Assets.xcassets`.
- **Commit**: `git commit -m "Phase 1 Task 1.1: Menu bar app with About, Help, single-instance check"`

---

## Task 1.2 — Floating panel with state machine

- `LauncherPanel` (NSPanel): `styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView]`. **`.fullSizeContentView` is required** — without it, the content is inset by the title bar height even on a borderless panel, creating a mysterious gap at the top. Additionally set:
  ```swift
  panel.level = .floating
  panel.isFloatingPanel = true
  panel.isMovableByWindowBackground = false  // Always repositions to fixed location on show
  panel.hasShadow = true
  panel.isReleasedWhenClosed = false  // Critical — NSPanel defaults to true. Without this,
                                      // any close() call deallocates the pre-created panel,
                                      // and subsequent access crashes. Always use orderOut()
                                      // to hide, but this is a safety net.
  ```
- **Override `canBecomeKey` to return `true`** — required for text input to work
- **Critical — activation behavior**: Do NOT call `NSApp.activate(ignoringOtherApps:)` — this would steal activation from the current app and swap the menu bar to Courier's. Use `panel.makeKeyAndOrderFront(nil)` only. The panel receives keyboard input via `canBecomeKey = true` without app activation. If text input doesn't work during Phase 1 verification, investigate `canBecomeKey` and `makeFirstResponder` before considering activation as a workaround.
- **Critical — collection behavior**: Set `panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` so the panel appears on all Spaces/desktops and over full-screen apps. Without this, the launcher is invisible on non-current Spaces.
- **Ownership chain**: `AppDelegate` (retained by SwiftUI via `@NSApplicationDelegateAdaptor`) creates and strongly retains `LauncherWindowController` in `applicationDidFinishLaunching`. `LauncherWindowController` creates and strongly retains the `LauncherPanel`. This explicit chain is required because SwiftUI's lifecycle can release objects not anchored to the `App` struct. The panel and its `NSHostingView` must never be garbage collected while the app is running.
- **`LauncherViewModel` ownership and dependency injection**: `LauncherWindowController` creates and owns the `LauncherViewModel`. It passes the view model into the SwiftUI view hierarchy via `NSHostingView(rootView: LauncherView(viewModel: viewModel))`. This allows the controller to access `viewModel.queryTextView` for first responder management (Task 2.1) while SwiftUI views observe the same instance via `@Observable`. Do NOT let SwiftUI create the view model — the controller needs a reference to it before the hosting view exists.
- **Panel background — `NSVisualEffectView`**: Launcher-style apps (Spotlight, Raycast, Alfred) use a translucent blurred background. This is a defining visual characteristic. The view hierarchy must be:
  ```
  NSPanel
  └── NSVisualEffectView (set as panel.contentView)
      ├── material: .hudWindow
      ├── blendingMode: .behindWindow
      ├── state: .active
      └── NSHostingView (subview, pinned with Auto Layout)
  ```
  Set `panel.contentView = visualEffectView`, then add the hosting view as a subview of the visual effect view. Do NOT set the hosting view as the panel's content view directly. When `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency` is `true`, the visual effect view renders opaque — verify colors and contrast are correct in both translucent and opaque modes. The corner radius should be applied to the visual effect view's layer (`wantsLayer = true`, `layer?.cornerRadius = 12`, `layer?.masksToBounds = true`).
- **NSHostingView sizing**: Set `hostingView.translatesAutoresizingMaskIntoConstraints = false`, pin to the `NSVisualEffectView` (not the panel's content view directly — the visual effect view IS the content view now). Set `panel.contentMinSize = NSSize(width: 680, height: 80)` and `panel.contentMaxSize = NSSize(width: 680, height: 320)`. The hosting view's SwiftUI root view should use `.frame(width: 680)` with flexible height.
- Panel state machine in `LauncherWindowController`: `hidden → animatingIn → visible → animatingOut → hidden`
- Rapid toggle protection: if hotkey pressed during animation, queue the toggle (don't drop or double-fire)
- **Show sequence — `makeKey` before animation**: Call `panel.makeKeyAndOrderFront(nil)` and `panel.makeFirstResponder(viewModel.queryTextView)` *before* starting the fade/scale animation. This makes the panel key immediately, so keystrokes land in the `NSTextView` naturally during `animatingIn` — no keystroke buffering is needed. The animation is purely visual (opacity/transform); input readiness must not wait for it.
- **Panel position**: Center horizontally on screen, position top edge at **25% of screen height from top** (upper-third, matching Spotlight/Raycast positioning). Use `NSEvent.mouseLocation` + `NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })` to find the correct screen. Do NOT use `NSScreen.main` — it returns the screen with the key window, not the screen the user is looking at. Panel always repositions to this fixed location on show (no persistent drag position).
- **Track previously active application**: On hotkey press (before showing panel), record `NSWorkspace.shared.frontmostApplication`. Store as a weak reference (`weak var previousApp: NSRunningApplication?`). On dismiss, check `previousApp?.isTerminated != true` before calling `previousApp?.activate()`. If terminated, do nothing (focus goes to whatever macOS picks).
- Hide: clear query text, order out
- **Pre-create panel at app launch**: Create the `LauncherPanel` and its `NSHostingView` at app startup and keep them in memory (hidden). Do NOT lazily initialize on first hotkey press — this adds 200-400ms of latency on first invocation. Reuse the same hosting view across show/hide cycles.
- **Performance target**: <80ms from hotkey press to cursor blinking in text field. Measure with `os_signpost` in Instruments during Phase 1 verification. Run 10 trials, verify p95 < 80ms.
- Bridge to SwiftUI via `NSHostingView`
- **VoiceOver announcement**: When panel becomes visible, call `NSAccessibility.post(element: panel, notification: .created)` so VoiceOver announces the panel. When hidden, post `.uiElementDestroyed`.
- Wire "Show Courier" menu item to toggle panel
- Verify: floating window appears in upper-third of screen with mouse pointer (test multi-monitor), VoiceOver announces panel on show and dismissal, rapid Option+Space+Option+Space doesn't glitch, text input receives keystrokes, panel appears over full-screen apps, panel appears on other Spaces, menu bar does NOT change to Courier's when panel is shown, typing during animation is not lost, focus returns to previous app on dismiss, no gap at top of panel (.fullSizeContentView working), hotkey-to-cursor p95 < 80ms, **panel appears correctly in Stage Manager mode (not grouped with other windows)**, **document that hotkey may not fire when secure input is active (1Password, etc.)**
- **Required imports**: `LauncherPanel.swift` needs `import AppKit`. `LauncherWindowController.swift` needs `import AppKit` and `import SwiftUI`. `LauncherView.swift` needs `import SwiftUI`. `LauncherViewModel.swift` needs `import AppKit` and `import Observation`.
- **Critical**: In `LauncherViewModel.swift`, annotate `weak var queryTextView: NSTextView?` with `@ObservationIgnored` — see Known Compilation Issues in architecture doc.
- Files created: `LauncherPanel.swift`, `LauncherWindowController.swift`, `LauncherView.swift` (placeholder), `LauncherViewModel.swift` (stub with `@ObservationIgnored weak var queryTextView` and `clearQuery()`). Files modified: `AppDelegate.swift` (add windowController ownership)
- **Commit**: `git commit -m "Phase 1 Task 1.2: Floating panel with state machine, visual effect background"`

---

## Task 1.3 — Global hotkey with conflict detection

- Use the `KeyboardShortcuts` package (Sindre Sorhus, MIT) for global hotkey registration — see Task 5.2 for details. This replaces the original `GlobalHotKey.swift` and `KeyCodeMapping.swift` files. The package wraps Carbon's `RegisterEventHotKey` internally.
- **Abstract behind protocol**: Wrap `KeyboardShortcuts` behind a `HotKeyProvider` protocol so it could be swapped if the package is abandoned or Apple provides a native API in the future.
- `AccessibilityPermission.swift` checking `AXIsProcessTrusted()`, prompts user if needed
- Register Option+Space -> toggle panel
- **Conflict detection**: if `RegisterEventHotKey` returns an error, show an alert: "Option+Space is already in use. Choose a different shortcut." with a shortcut recorder inline. Note: the Carbon API does NOT report which app owns the conflicting shortcut — only that registration failed. Do not attempt to identify the conflicting app.
- Store custom hotkey in `AppSettings` if user changes it
- **Prevent App Nap**: `LSUIElement` apps with no visible windows are candidates for App Nap, which can add seconds of latency to hotkey response. On app launch, call `ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "Listening for global hotkey")` and hold the returned `NSObjectProtocol` token for the app's lifetime.
- **Monitor accessibility permission revocation**: Users can revoke Accessibility permission in System Settings while Courier is running, silently breaking the hotkey. The Carbon hotkey handler may not fire at all after revocation (behavior varies by macOS version), so checking "on each hotkey attempt" is unreliable. Instead:
  - Check `AXIsProcessTrusted()` on a **60-second timer** (the call is lightweight, <1ms)
  - **Also check `IsSecureEventInputEnabled()`** on the same timer. When another app (1Password, banking apps) enables secure input, Carbon global hotkeys may not fire. If secure input is active, show toast: "A secure input app may be blocking Courier's hotkey." This is a known macOS limitation — no workaround exists.
  - Check on `NSWorkspace.didWakeNotification` (sleep/wake can reset trust state)
  - Check when the Settings window is opened (natural moment to verify permissions)
  - If revoked, show system notification: "Courier lost Accessibility access. Click to re-enable." with an action to open `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
- **Required imports**: `HotKeyProvider.swift` needs `import Foundation` and `import KeyboardShortcuts`. `AccessibilityPermission.swift` needs `import AppKit` and `import ApplicationServices` (for `AXIsProcessTrusted`).
- Verify: Option+Space shows/hides panel from any app. If another app owns Option+Space, conflict alert appears and alternative shortcut works. Hotkey responds within 100ms even after the app has been idle for minutes (App Nap prevention working). Revoking Accessibility permission shows re-enable notification. Secure Event Input active -> toast shown.
- Files created: `HotKeyProvider.swift`, `AccessibilityPermission.swift`. Files modified: `AppDelegate.swift` (hotkey registration, App Nap, accessibility monitoring, secure input monitoring)
- **Commit**: `git commit -m "Phase 1 Task 1.3: Global hotkey, accessibility monitoring, secure input detection"`

---

## Skeleton Code

### `Courier/Views/Launcher/LauncherPanel.swift`

```swift
import AppKit

final class LauncherPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        isMovableByWindowBackground = false
        hasShadow = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    // Required for text input to work in a .nonactivatingPanel
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

### `Courier/Views/Launcher/LauncherWindowController.swift`

```swift
import AppKit
import SwiftUI

final class LauncherWindowController: NSObject, NSWindowDelegate {

    enum PanelState {
        case hidden
        case animatingIn
        case visible
        case animatingOut
    }

    private(set) var panel: LauncherPanel
    private(set) var viewModel: LauncherViewModel
    private let hostingView: NSHostingView<LauncherView>
    private let visualEffectView: NSVisualEffectView

    private var state: PanelState = .hidden
    private var pendingToggle = false
    private weak var previousApp: NSRunningApplication?
    private var globalClickMonitor: Any?

    override init() {
        let panelRect = NSRect(x: 0, y: 0, width: 680, height: 80)
        panel = LauncherPanel(contentRect: panelRect)
        viewModel = LauncherViewModel()

        let rootView = LauncherView(viewModel: viewModel)
        hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true

        super.init()

        panel.contentView = visualEffectView
        visualEffectView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
        ])

        panel.contentMinSize = NSSize(width: 680, height: 80)
        panel.contentMaxSize = NSSize(width: 680, height: 320)
        panel.delegate = self

        // Add global click monitor once — check isVisible in handler
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self, self.panel.isVisible else { return }
            if !self.panel.frame.contains(NSEvent.mouseLocation) {
                self.hide()
            }
        }
    }

    deinit {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Public

    func toggle() {
        switch state {
        case .hidden:
            show()
        case .visible:
            hide()
        case .animatingIn, .animatingOut:
            pendingToggle = true
        }
    }

    // MARK: - Private

    private func show() {
        state = .animatingIn
        previousApp = NSWorkspace.shared.frontmostApplication
        positionPanel()

        // makeKey BEFORE animation — input works immediately
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.panel.makeFirstResponder(self.viewModel.queryTextView)
        }

        NSAccessibility.post(element: panel, notification: .created)

        // Animation using NSAnimationContext
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.alphaValue = 1.0
            state = .visible
            drainPendingToggle()
        } else {
            panel.alphaValue = 0.0
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                panel.animator().alphaValue = 1.0
            }, completionHandler: { [weak self] in
                self?.state = .visible
                self?.drainPendingToggle()
            })
        }
    }

    private func hide() {
        state = .animatingOut
        viewModel.clearQuery()

        let finishHide: () -> Void = { [weak self] in
            guard let self else { return }
            self.panel.orderOut(nil)
            NSAccessibility.post(element: self.panel, notification: .uiElementDestroyed)
            if self.previousApp?.isTerminated != true {
                self.previousApp?.activate()
            }
            self.state = .hidden
            self.drainPendingToggle()
        }

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            finishHide()
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                panel.animator().alphaValue = 0.0
            }, completionHandler: finishHide)
        }
    }

    private func positionPanel() {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: {
            $0.frame.contains(mouseLocation)
        }) ?? NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.maxY - (screen.frame.height * 0.25)
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }

    private func drainPendingToggle() {
        if pendingToggle {
            pendingToggle = false
            toggle()
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        if state == .visible {
            hide()
        }
    }
}
```

### `Courier/App/AppDelegate.swift`

```swift
import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleCourier = Self("toggleCourier")
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    // Strong reference — keeps window controller (and panel) alive for app lifetime
    private var windowController: LauncherWindowController!
    private var activityToken: NSObjectProtocol?
    private var accessibilityTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance guard
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if running.count > 1 {
            running.first(where: { $0 != .current })?.activate()
            NSApp.terminate(nil)
            return
        }

        // Prevent App Nap
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Listening for global hotkey"
        )

        // Create and retain the window controller (which creates panel + view model)
        windowController = LauncherWindowController()

        // Register global hotkey (default: Option+Space)
        if KeyboardShortcuts.getShortcut(for: .toggleCourier) == nil {
            KeyboardShortcuts.setShortcut(.init(.space, modifiers: .option), for: .toggleCourier)
        }
        KeyboardShortcuts.onKeyUp(for: .toggleCourier) { [weak self] in
            self?.windowController.toggle()
        }

        // Accessibility permission check
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }

        // Periodic accessibility + secure input monitoring (60s)
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            if !AXIsProcessTrusted() {
                // TODO: Show system notification to re-enable accessibility
            }
            if IsSecureEventInputEnabled() {
                // TODO: Show toast "A secure input app may be blocking Courier's hotkey"
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityTimer?.invalidate()
    }
}
```

---

## Phase 1 Build Verification

```bash
# Install XcodeGen if not present
which xcodegen || brew install xcodegen

# Generate project and build
cd /Users/John Holleman/repos/Courier-claude/Courier-claude
xcodegen generate && xcodebuild -scheme Courier -destination 'platform=macOS' build 2>&1 | tail -20

# If SPM resolution fails, try:
# xcodebuild -resolvePackageDependencies -scheme Courier
```

If `KeyboardShortcuts` fails to resolve or compile, check the installed version's API against the skeleton code. The package README in `.build/checkouts/KeyboardShortcuts/` is the source of truth.

---

## Phase 1 Test Skeleton

```swift
// CourierTests/PanelStateTests.swift
import XCTest
@testable import Courier

final class PanelStateTests: XCTestCase {

    func testToggleFromHiddenShowsPanel() {
        // Verify: state transitions from .hidden to .animatingIn to .visible
    }

    func testToggleFromVisibleHidesPanel() {
        // Verify: state transitions from .visible to .animatingOut to .hidden
    }

    func testToggleDuringAnimationQueues() {
        // Verify: toggle during .animatingIn sets pendingToggle = true
        // and drains after animation completes
    }

    func testPreviousAppRestoredOnDismiss() {
        // Verify: previousApp.activate() called on hide (mock NSRunningApplication)
    }

    func testPreviousAppTerminatedNocrash() {
        // Verify: if previousApp.isTerminated == true, no crash on dismiss
    }

    func testSingleInstanceCheck() {
        // Verify: second instance detection logic
    }
}
```

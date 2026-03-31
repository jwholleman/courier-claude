import AppKit
import SwiftUI

@MainActor
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
    private let dispatcher: ServiceDispatcher

    private var state: PanelState = .hidden
    private var pendingToggle = false
    private weak var previousApp: NSRunningApplication?
    private var globalClickMonitor: Any?

    override init() {
        let panelRect = NSRect(x: 0, y: 0, width: 680, height: 80)
        panel = LauncherPanel(contentRect: panelRect)

        let settings = AppSettings()
        viewModel = LauncherViewModel()
        viewModel.settings = settings
        viewModel.selectedService = settings.effectiveSelectedService
        let registry = ServiceRegistry()
        registry.settings = settings
        dispatcher = ServiceDispatcher(registry: registry)

        // Create stub root view pre-super.init; closures capturing self are set post-super.init
        let rootView = LauncherView(viewModel: viewModel, onSubmit: nil, onDismiss: nil)
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

        // Update rootView with closures now that self is available
        hostingView.rootView = LauncherView(
            viewModel: viewModel,
            onSubmit: { [weak self] in self?.handleSubmit() },
            onDismiss: { [weak self] in self?.hide() }
        )

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

        // Global click-outside monitor — dismisses panel when clicking elsewhere
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            if !self.panel.frame.contains(NSEvent.mouseLocation) {
                self.hide()
            }
        }

        // Start observing contentHeight so panel resizes with content
        observeContentHeight()
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

    private func handleSubmit() {
        let query = viewModel.queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        let serviceType = viewModel.selectedService
        guard !query.isEmpty else { return }

        // Save last-used service before dismissing
        viewModel.settings?.lastUsedService = serviceType

        hide()

        Task {
            do {
                try await dispatcher.dispatch(query: query, serviceType: serviceType)
            } catch {
                await NotificationHelper.showToast("Dispatch failed: \(error.localizedDescription)")
            }
        }
    }

    private func show() {
        state = .animatingIn
        previousApp = NSWorkspace.shared.frontmostApplication
        positionPanel()

        // Activate Courier before showing the panel — steals focus from any app
        // (e.g. ChatGPT) that also owns Option+Space, causing their launcher to close.
        NSApp.activate(ignoringOtherApps: true)

        // makeKey BEFORE animation — input works immediately during animatingIn
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.panel.makeFirstResponder(self.viewModel.queryTextView)
        }

        NSAccessibility.post(element: panel, notification: .created)

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

    private func updatePanelHeight() {
        let newHeight = viewModel.contentHeight
        panel.setContentSize(NSSize(width: 680, height: newHeight))
        // Reposition to keep top edge fixed after height change
        positionPanel()
    }

    /// Recursive observation pattern — re-registers after each change.
    private func observeContentHeight() {
        withObservationTracking {
            _ = viewModel.contentHeight
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.updatePanelHeight()
                self?.observeContentHeight()
            }
        }
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowDidResignKey(_ notification: Notification) {
        Task { @MainActor in
            if self.state == .visible {
                self.hide()
            }
        }
    }
}

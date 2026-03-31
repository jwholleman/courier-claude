import AppKit

/// A reusable, non-activating HUD-style toast panel.
/// Pre-created at launch and reused — never allocate per-toast.
final class ToastPanel: NSPanel {

    private let label = NSTextField(labelWithString: "")
    private var dismissTimer: Timer?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 40),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        ignoresMouseEvents = false

        // Visual effect background
        let fx = NSVisualEffectView(frame: contentView!.bounds)
        fx.material = .hudWindow
        fx.blendingMode = .behindWindow
        fx.state = .active
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 8
        fx.layer?.masksToBounds = true
        fx.autoresizingMask = [.width, .height]
        contentView?.addSubview(fx)

        // Label
        label.font = .systemFont(ofSize: 13)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        fx.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: fx.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: fx.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: fx.centerYAnchor),
        ])

        // Click to dismiss
        let click = NSClickGestureRecognizer(target: self, action: #selector(dismiss))
        contentView?.addGestureRecognizer(click)
    }

    func show(_ message: String, on screen: NSScreen? = NSScreen.main) {
        dismissTimer?.invalidate()
        label.stringValue = message

        // Size to content (min 200, max 400)
        let attrs: [NSAttributedString.Key: Any] = [.font: label.font as Any]
        let textWidth = (message as NSString).boundingRect(
            with: NSSize(width: 400, height: 40),
            options: .usesLineFragmentOrigin,
            attributes: attrs
        ).width
        let width = max(200, min(400, textWidth + 48))
        setContentSize(NSSize(width: width, height: 40))

        // Position top-center of screen, 80pt below menu bar
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens[0]
        let x = targetScreen.frame.midX - width / 2
        let y = targetScreen.frame.maxY - targetScreen.frame.height + targetScreen.visibleFrame.maxY
               + targetScreen.frame.height - targetScreen.visibleFrame.maxY - 80
        setFrameTopLeftPoint(NSPoint(x: x, y: targetScreen.visibleFrame.maxY - 12))

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion {
            alphaValue = 1
            orderFrontRegardless()
        } else {
            alphaValue = 0
            orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                animator().alphaValue = 1
            }
        }

        dismissTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    @objc func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion {
            orderOut(nil)
        } else {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.orderOut(nil)
            })
        }
    }
}

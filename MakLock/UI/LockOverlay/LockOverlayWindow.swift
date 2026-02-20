import AppKit

/// Full-screen overlay panel that blocks interaction with a protected app.
/// Uses NSPanel with .nonactivatingPanel so MakLock does NOT become the active app
/// when the overlay is shown — this lets the system Touch ID dialog keep focus.
final class LockOverlayWindow: NSPanel {
    init(for screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.animationBehavior = .none
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
    }

    /// Reposition the overlay to match the given screen frame.
    func reposition(to screen: NSScreen) {
        setFrame(screen.frame, display: true)
    }

    /// Whether the window should accept key status.
    /// Disabled during Touch ID (system dialog needs focus), enabled for password input.
    var allowKeyStatus = false

    override var canBecomeKey: Bool { allowKeyStatus }
    override var canBecomeMain: Bool { false }
}

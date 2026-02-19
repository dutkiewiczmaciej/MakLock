import AppKit

/// Full-screen overlay window that blocks interaction with a protected app.
final class LockOverlayWindow: NSWindow {
    init(for screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
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

import AppKit

/// Overlay panel that asks for authentication. Can be fullscreen or windowed.
final class LockOverlayWindow: NSWindow {
    let isFullScreen: Bool

    init(for screen: NSScreen?, isFullScreen: Bool) {
        self.isFullScreen = isFullScreen
        
        let rect = isFullScreen ? (screen?.frame ?? NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)) : NSRect(x: 0, y: 0, width: 500, height: 400)
        let style: NSWindow.StyleMask = isFullScreen ? [.borderless] : [.titled, .closable, .fullSizeContentView]

        super.init(
            contentRect: rect,
            styleMask: style,
            backing: .buffered,
            defer: false
        )

        if !isFullScreen {
            self.title = "MakLock"
            self.titlebarAppearsTransparent = true
            self.hasShadow = true
            self.animationBehavior = .alertPanel
        } else {
            self.hasShadow = false
            self.animationBehavior = .none
            self.level = .screenSaver
        }

        self.titleVisibility = .hidden
        self.level = isFullScreen ? .screenSaver : .modalPanel
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        if isFullScreen {
            self.collectionBehavior.insert(.fullScreenAuxiliary)
        }
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        
        if !isFullScreen {
            self.center()
        }
    }
    
    /// Reposition the overlay to match the given screen frame (for full screen mode).
    func reposition(to screen: NSScreen) {
        if isFullScreen {
            setFrame(screen.frame, display: true)
        }
    }
    
    var allowKeyStatus = true

    override var canBecomeKey: Bool { allowKeyStatus }
    override var canBecomeMain: Bool { allowKeyStatus }
}

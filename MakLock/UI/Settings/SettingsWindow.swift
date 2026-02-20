import AppKit
import SwiftUI

/// Manages the Settings window lifecycle.
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .openSettings,
            object: nil
        )
    }

    @objc func openSettings(_ notification: Notification) {
        let targetScreen = notification.object as? NSScreen ?? NSScreen.main ?? NSScreen.screens[0]

        if let window {
            centerWindow(window, on: targetScreen)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MakLock Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        centerWindow(window, on: targetScreen)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    private func centerWindow(_ window: NSWindow, on screen: NSScreen) {
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let origin = NSPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2
        )
        window.setFrameOrigin(origin)
    }
}

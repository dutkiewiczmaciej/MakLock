import AppKit
import SwiftUI

/// Manages the App Picker modal window.
final class AppPickerWindowController {
    private var window: NSWindow?

    func show(from parentWindow: NSWindow? = nil) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let pickerView = AppPickerView(
            onAppsSelected: { [weak self] apps in
                for app in apps {
                    ProtectedAppsManager.shared.addApp(
                        bundleIdentifier: app.bundleIdentifier,
                        name: app.name,
                        path: app.path
                    )
                }
                self?.close()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )

        let hostingController = NSHostingController(rootView: pickerView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Add Applications"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false

        // Position on the same screen as the parent window
        if let parentWindow {
            let parentFrame = parentWindow.frame
            let pickerSize = window.frame.size
            let x = parentFrame.midX - pickerSize.width / 2
            let y = parentFrame.midY - pickerSize.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func close() {
        window?.close()
        window = nil
    }
}

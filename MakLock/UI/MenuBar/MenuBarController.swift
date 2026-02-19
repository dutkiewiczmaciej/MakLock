import AppKit
import SwiftUI

/// Manages the NSStatusItem and menu bar icon states.
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    /// Current lock state displayed in the menu bar.
    enum IconState {
        /// No protected apps are running.
        case idle
        /// A protected app is running (unlocked).
        case active
        /// An overlay is currently displayed.
        case locked
    }

    var iconState: IconState = .idle {
        didSet { updateIcon() }
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 280)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView(
            onToggleProtection: { [weak self] in
                self?.toggleProtection()
            },
            onSettingsClicked: { [weak self] in
                self?.hidePopover()
                NotificationCenter.default.post(name: .openSettings, object: nil)
            },
            onQuitClicked: {
                NSApplication.shared.terminate(nil)
            }
        ))
        self.popover = popover

        if let button = statusItem?.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if let popover, popover.isShown {
            hidePopover()
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func hidePopover() {
        popover?.performClose(nil)
    }

    private func toggleProtection() {
        var settings = Defaults.shared.appSettings
        settings.isProtectionEnabled.toggle()
        Defaults.shared.appSettings = settings

        if !settings.isProtectionEnabled {
            OverlayWindowService.shared.dismissAll()
            iconState = .idle
        } else {
            iconState = .active
        }
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let symbolName: String
        switch iconState {
        case .idle:
            symbolName = "lock.open"
        case .active:
            symbolName = "lock"
        case .locked:
            symbolName = "lock.fill"
        }

        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MakLock")

        // Add a small badge dot for locked state
        if iconState == .locked, let baseImage = image {
            let size = NSSize(width: 18, height: 18)
            let badged = NSImage(size: size, flipped: false) { rect in
                baseImage.draw(in: NSRect(x: 0, y: 2, width: 14, height: 14))
                NSColor.systemOrange.setFill()
                let dot = NSRect(x: 12, y: 12, width: 6, height: 6)
                NSBezierPath(ovalIn: dot).fill()
                return true
            }
            badged.isTemplate = false
            button.image = badged
        } else {
            button.image = image
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openSettings = Notification.Name("com.makmak.MakLock.openSettings")
}

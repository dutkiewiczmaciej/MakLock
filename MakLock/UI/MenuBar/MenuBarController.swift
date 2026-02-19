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
        popover.contentSize = NSSize(width: 260, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView(
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

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let symbolName: String
        switch iconState {
        case .idle:
            symbolName = "lock"
        case .active:
            symbolName = "lock.fill"
        case .locked:
            symbolName = "lock.fill"
        }
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MakLock")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openSettings = Notification.Name("com.makmak.MakLock.openSettings")
}

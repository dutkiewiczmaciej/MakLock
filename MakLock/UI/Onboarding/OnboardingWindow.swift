import AppKit
import SwiftUI

/// Controller for the first-launch onboarding window.
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    /// Whether onboarding is currently being shown.
    var isShowing: Bool { window != nil }

    private init() {}

    /// Show onboarding if the user hasn't completed it yet.
    func showIfNeeded() {
        guard !Defaults.shared.hasCompletedOnboarding else { return }
        show()
    }

    /// Show the onboarding window as a modal-like experience.
    func show() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            return
        }

        let onboardingView = OnboardingView {
            Defaults.shared.hasCompletedOnboarding = true
            self.close()
        }

        let hostingView = NSHostingView(rootView: onboardingView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Welcome to MakLock"
        newWindow.contentView = hostingView
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()

        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }

    /// Close the onboarding window.
    func close() {
        window?.close()
        window = nil
    }
}

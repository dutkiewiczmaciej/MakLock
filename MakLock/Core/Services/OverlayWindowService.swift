import AppKit
import SwiftUI

/// Manages overlay window lifecycle: show, hide, and timeout failsafe.
final class OverlayWindowService {
    static let shared = OverlayWindowService()

    private var overlayWindows: [LockOverlayWindow] = []
    private var timeoutTimer: Timer?
    private var currentApp: ProtectedApp?

    /// Callback when overlay is dismissed after successful authentication.
    var onUnlocked: (() -> Void)?

    private init() {
        // Observe screen configuration changes (connect/disconnect monitors)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Show the lock overlay for a protected app on all screens.
    func show(for app: ProtectedApp) {
        // Don't show duplicate overlays
        guard overlayWindows.isEmpty else { return }

        currentApp = app

        // Hide the protected app's windows so content isn't visible behind the overlay
        hideProtectedApp(bundleIdentifier: app.bundleIdentifier)

        createOverlayWindows(for: app)
        startTimeoutTimer()

        // Don't activate or make key — the system Touch ID dialog needs focus
        NSLog("[MakLock] Overlay shown for: %@", app.name)
    }

    /// Hide all overlay windows.
    func hide() {
        stopTimeoutTimer()

        // Cancel any in-progress Touch ID evaluation
        AuthenticationService.shared.cancelAuthentication()

        // Mark the app as authenticated so it won't re-lock immediately
        if let app = currentApp {
            AppMonitorService.shared.markAuthenticated(app.bundleIdentifier)

            // Bring the protected app back to the foreground
            activateProtectedApp(bundleIdentifier: app.bundleIdentifier)
        }

        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()
        currentApp = nil
        NSLog("[MakLock] Overlay dismissed")
    }

    /// Dismiss all overlays (used by panic key).
    func dismissAll() {
        hide()
    }

    /// Whether an overlay is currently displayed.
    var isShowing: Bool {
        !overlayWindows.isEmpty
    }

    /// Enable key window status on overlay windows (needed for password input).
    func enableKeyboardInput() {
        for window in overlayWindows {
            window.allowKeyStatus = true
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Screen Management

    @objc private func screensDidChange(_ notification: Notification) {
        guard !overlayWindows.isEmpty else { return }

        let screens = NSScreen.screens

        // Reposition existing windows to match current screens (don't recreate to avoid re-triggering Touch ID)
        for (index, window) in overlayWindows.enumerated() {
            if index < screens.count {
                window.reposition(to: screens[index])
            }
        }

        // Close excess windows if screens were removed
        while overlayWindows.count > screens.count {
            overlayWindows.removeLast().close()
        }

        // Add new windows for new screens (only blur, no Touch ID trigger)
        if let app = currentApp {
            for screenIndex in overlayWindows.count..<screens.count {
                let window = LockOverlayWindow(for: screens[screenIndex])
                let overlayView = LockOverlayView(
                    appName: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    isPrimary: false,
                    onDismiss: { [weak self] in
                        self?.hide()
                        self?.onUnlocked?()
                    }
                )
                window.contentView = NSHostingView(rootView: overlayView)
                window.orderFront(nil)
                overlayWindows.append(window)
            }
        }

        NSLog("[MakLock] Overlays repositioned for screen change (%d screens)", screens.count)
    }

    private func createOverlayWindows(for app: ProtectedApp) {
        let primaryScreen = NSScreen.main ?? NSScreen.screens.first

        for screen in NSScreen.screens {
            let window = LockOverlayWindow(for: screen)
            let isPrimary = (screen == primaryScreen)

            let overlayView = LockOverlayView(
                appName: app.name,
                bundleIdentifier: app.bundleIdentifier,
                isPrimary: isPrimary,
                onDismiss: { [weak self] in
                    self?.hide()
                    self?.onUnlocked?()
                }
            )

            window.contentView = NSHostingView(rootView: overlayView)
            // Don't make key or activate — system Touch ID dialog needs focus
            window.orderFront(nil)
            overlayWindows.append(window)
        }
    }

    // MARK: - App Window Management

    /// Hide the protected app's windows so content isn't visible behind the overlay.
    private func hideProtectedApp(bundleIdentifier: String) {
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            app.hide()
            NSLog("[MakLock] Hidden app windows: %@", bundleIdentifier)
        }
    }

    /// Bring the protected app back to the foreground after successful auth.
    private func activateProtectedApp(bundleIdentifier: String) {
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            // Small delay to let overlay close first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                app.unhide()
                app.activate()
                NSLog("[MakLock] Activated app: %@", bundleIdentifier)
            }
        }
    }

    // MARK: - Timeout

    private func startTimeoutTimer() {
        let timeout = SafetyManager.isDevMode
            ? SafetyManager.devModeTimeout
            : SafetyManager.overlayTimeout

        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            NSLog("[MakLock Safety] Overlay timeout reached (%.0fs) — auto-dismissing", timeout)
            self?.hide()
        }
    }

    private func stopTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

}

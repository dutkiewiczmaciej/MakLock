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
        createOverlayWindows(for: app)
        startTimeoutTimer()
        NSLog("[MakLock] Overlay shown for: %@", app.name)
    }

    /// Hide all overlay windows.
    func hide() {
        stopTimeoutTimer()
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

    // MARK: - Screen Management

    @objc private func screensDidChange(_ notification: Notification) {
        guard let app = currentApp, !overlayWindows.isEmpty else { return }

        // Rebuild overlays for the new screen configuration
        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()
        createOverlayWindows(for: app)
        NSLog("[MakLock] Overlays repositioned for screen change (%d screens)", NSScreen.screens.count)
    }

    private func createOverlayWindows(for app: ProtectedApp) {
        for screen in NSScreen.screens {
            let window = LockOverlayWindow(for: screen)

            let overlayView = LockOverlayView(
                appName: app.name,
                bundleIdentifier: app.bundleIdentifier,
                onDismiss: { [weak self] in
                    self?.hide()
                    self?.onUnlocked?()
                }
            )

            window.contentView = NSHostingView(rootView: overlayView)
            window.makeKeyAndOrderFront(nil)
            overlayWindows.append(window)
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

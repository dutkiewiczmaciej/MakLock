import AppKit
import SwiftUI

/// Manages overlay window lifecycle: show, hide, and timeout failsafe.
final class OverlayWindowService {
    static let shared = OverlayWindowService()

    private var overlayWindows: [LockOverlayWindow] = []
    private var timeoutTimer: Timer?
    private var currentApp: ProtectedApp?

    /// Callback when the user requests unlock (Touch ID or password).
    var onUnlockRequested: ((ProtectedApp) -> Void)?

    /// Callback when the user requests password input.
    var onPasswordRequested: ((ProtectedApp) -> Void)?

    private init() {}

    /// Show the lock overlay for a protected app on all screens.
    func show(for app: ProtectedApp) {
        // Don't show duplicate overlays
        guard overlayWindows.isEmpty else { return }

        currentApp = app

        for screen in NSScreen.screens {
            let window = LockOverlayWindow(for: screen)

            let overlayView = LockOverlayView(
                appName: app.name,
                bundleIdentifier: app.bundleIdentifier,
                onUnlock: { [weak self] in
                    self?.handleUnlock()
                },
                onDismiss: { [weak self] in
                    self?.hide()
                }
            )

            window.contentView = NSHostingView(rootView: overlayView)
            window.makeKeyAndOrderFront(nil)
            overlayWindows.append(window)
        }

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

    // MARK: - Private

    private func handleUnlock() {
        guard let app = currentApp else { return }
        onUnlockRequested?(app)
    }
}

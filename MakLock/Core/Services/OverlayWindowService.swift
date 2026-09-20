import AppKit
import SwiftUI

/// Manages overlay window lifecycle: show, hide, and timeout failsafe.
final class OverlayWindowService {
    static let shared = OverlayWindowService()

    private var overlayWindows: [LockOverlayWindow] = []
    private var timeoutTimer: Timer?
    private var currentApp: ProtectedApp?
    private var isDenying = false

    /// Callback when overlay is dismissed after successful authentication.
    /// Passes the name of the unlocked app.
    var onUnlocked: ((String) -> Void)?

    /// Callback when the overlay is dismissed without authentication (cancelled or timed out).
    /// Passes the name of the app that stayed locked.
    var onAccessDenied: ((String) -> Void)?

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

        // Don't hide the protected app — the overlay blur covers its content,
        // and hiding it causes macOS to reassign app focus, which interferes
        // with the system Touch ID dialog.

        createOverlayWindows(for: app)
        startTimeoutTimer()

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
        }

        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()

        // Activate the protected app now that overlays are gone.
        // Small delay ensures overlay panels and Touch ID dialog are fully dismissed
        // before attempting to bring the app forward.
        if let bundleID = currentApp?.bundleIdentifier {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.activateProtectedApp(bundleIdentifier: bundleID)
            }
        }

        currentApp = nil
        NSLog("[MakLock] Overlay dismissed")
    }

    /// Dismiss the overlay WITHOUT granting access: the protected app is hidden,
    /// stays locked, and the attempt is recorded in the access log.
    func deny(reason: String) {
        guard let app = currentApp, !isDenying else { return }
        isDenying = true

        stopTimeoutTimer()
        AuthenticationService.shared.cancelAuthentication()
        AccessLog.record("Access denied to \(app.name) (\(app.bundleIdentifier)): \(reason)")

        // Hide the app before removing the blur so its content is never revealed
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == app.bundleIdentifier }?
            .hide()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.isDenying = false
            // Authenticated (e.g. by Watch) or dismissed in the meantime
            guard self.currentApp?.bundleIdentifier == app.bundleIdentifier else { return }

            self.overlayWindows.forEach { $0.close() }
            self.overlayWindows.removeAll()
            self.currentApp = nil

            // Let the next activation of the app trigger the lock again
            AppMonitorService.shared.clearPendingLock(for: app.bundleIdentifier)
            self.onAccessDenied?(app.name)
            NSLog("[MakLock] Overlay dismissed without authentication")

            // The app could not be hidden and is still in front — keep it locked
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == app.bundleIdentifier {
                self.show(for: app)
            }
        }
    }

    /// Dismiss all overlays (used by panic key).
    func dismissAll() {
        hide()
    }

    /// Whether an overlay is currently displayed.
    var isShowing: Bool {
        !overlayWindows.isEmpty
    }

    /// Bundle identifier of the currently locked app (if any).
    var currentBundleIdentifier: String? {
        currentApp?.bundleIdentifier
    }

    /// Display name of the currently locked app (if any).
    var currentAppName: String? {
        currentApp?.name
    }

    /// During Touch ID: drop the overlay just below the system Touch ID dialog
    /// (which is shown at the screen-saver level) so the dialog is always visible
    /// and clickable. The overlay keeps receiving clicks, so its Cancel button works.
    /// After auth: restore the normal overlay level.
    func setTouchIDMode(_ active: Bool) {
        let level: NSWindow.Level = active
            ? NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
            : .screenSaver
        for window in overlayWindows {
            window.level = level
            window.ignoresMouseEvents = false
        }
    }

    /// Enable key window status on overlay windows (needed for password input).
    func enableKeyboardInput() {
        setTouchIDMode(false)
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
                        let name = self?.currentApp?.name ?? "app"
                        self?.hide()
                        self?.onUnlocked?(name)
                    },
                    onCancel: { [weak self] in
                        self?.deny(reason: "cancelled at the lock screen")
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
                    let name = self?.currentApp?.name ?? "app"
                    self?.hide()
                    self?.onUnlocked?(name)
                },
                onCancel: { [weak self] in
                    self?.deny(reason: "cancelled at the lock screen")
                }
            )

            window.contentView = NSHostingView(rootView: overlayView)
            // Don't make key or activate — system Touch ID dialog needs focus
            window.orderFront(nil)
            overlayWindows.append(window)
        }
    }

    // MARK: - App Window Management

    /// Bring the protected app to the foreground after successful auth.
    /// Only activates if the app is already running — never launches a closed app.
    private func activateProtectedApp(bundleIdentifier: String) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            NSLog("[MakLock] App not running, skipping activation: %@", bundleIdentifier)
            return
        }
        app.activate()
        NSLog("[MakLock] Activated app: %@", bundleIdentifier)
    }

    // MARK: - Timeout

    private func startTimeoutTimer() {
        let timeout = SafetyManager.isDevMode
            ? SafetyManager.devModeTimeout
            : SafetyManager.overlayTimeout

        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            NSLog("[MakLock Safety] Overlay timeout reached (%.0fs) — auto-dismissing", timeout)
            // Never grant access on timeout — dismiss and keep the app locked
            self?.deny(reason: "lock screen timed out without authentication")
        }
    }

    private func stopTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

}

// MARK: - Access Log

/// Records failed access attempts to `~/Library/Logs/MakLock/access.log` (viewable in Console).
enum AccessLog {
    static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/MakLock/access.log")

    static func record(_ message: String) {
        NSLog("[MakLock Access] %@", message)

        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: fileURL)
        }
    }
}

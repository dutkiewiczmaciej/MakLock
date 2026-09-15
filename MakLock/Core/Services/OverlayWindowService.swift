import AppKit
import SwiftUI

/// Manages overlay window lifecycle: show, hide, and timeout failsafe.
final class OverlayWindowService: NSObject, NSWindowDelegate {
    static let shared = OverlayWindowService()

    private var overlayWindows: [LockOverlayWindow] = []
    private var timeoutTimer: Timer?
    private var currentApp: ProtectedApp?
    private var hiddenAppBundleID: String?

    /// Callback when overlay is dismissed after successful authentication.
    /// Passes the name of the unlocked app.
    var onUnlocked: ((String) -> Void)?

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Show the lock overlay for a protected app.
    func show(for app: ProtectedApp) {
        guard overlayWindows.isEmpty else { return }

        currentApp = app
        hiddenAppBundleID = app.bundleIdentifier

        let isFullScreen = Defaults.shared.appSettings.isFullScreenOverlay

        // Hide the protected app so its contents are not visible
        if !isFullScreen {
            if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                runningApp.hide()
            }
        }

        createOverlayWindows(for: app, isFullScreen: isFullScreen)
        startTimeoutTimer()

        NSLog("[MakLock] Overlay shown for: %@", app.name)
    }

    /// Hide the overlay window and activate the target app (on successful unlock or panic).
    func hide() {
        stopTimeoutTimer()

        AuthenticationService.shared.cancelAuthentication()

        if let app = currentApp {
            AppMonitorService.shared.markAuthenticated(app.bundleIdentifier)
        }

        let bundleID = currentApp?.bundleIdentifier ?? hiddenAppBundleID

        overlayWindows.forEach { 
            $0.delegate = nil
            $0.close() 
        }
        overlayWindows.removeAll()

        if let bundleID = bundleID {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.activateProtectedApp(bundleIdentifier: bundleID)
            }
        }

        currentApp = nil
        hiddenAppBundleID = nil
        NSLog("[MakLock] Overlay dismissed")
    }

    func dismissAll() {
        hide()
    }

    var isShowing: Bool {
        !overlayWindows.isEmpty
    }

    var currentBundleIdentifier: String? {
        currentApp?.bundleIdentifier
    }

    var currentAppName: String? {
        currentApp?.name
    }

    func setTouchIDMode(_ active: Bool) {
        for window in overlayWindows {
            window.ignoresMouseEvents = active
        }
    }

    func enableKeyboardInput() {
        setTouchIDMode(false)
        for window in overlayWindows {
            window.allowKeyStatus = true
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func screensDidChange(_ notification: Notification) {
        guard !overlayWindows.isEmpty, let firstWindow = overlayWindows.first, firstWindow.isFullScreen else { return }

        let screens = NSScreen.screens

        for (index, window) in overlayWindows.enumerated() {
            if index < screens.count {
                window.reposition(to: screens[index])
            }
        }

        while overlayWindows.count > screens.count {
            overlayWindows.removeLast().close()
        }

        if let app = currentApp {
            for screenIndex in overlayWindows.count..<screens.count {
                let window = LockOverlayWindow(for: screens[screenIndex], isFullScreen: true)
                let overlayView = LockOverlayView(
                    appName: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    isPrimary: false,
                    onDismiss: { [weak self] in
                        let name = self?.currentApp?.name ?? "app"
                        self?.hide()
                        self?.onUnlocked?(name)
                    }
                )
                window.contentView = NSHostingView(rootView: overlayView)
                window.orderFront(nil)
                overlayWindows.append(window)
            }
        }
    }

    private func createOverlayWindows(for app: ProtectedApp, isFullScreen: Bool) {
        if isFullScreen {
            let primaryScreen = NSScreen.main ?? NSScreen.screens.first

            for screen in NSScreen.screens {
                let window = LockOverlayWindow(for: screen, isFullScreen: true)
                let isPrimary = (screen == primaryScreen)

                let overlayView = LockOverlayView(
                    appName: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    isPrimary: isPrimary,
                    onDismiss: { [weak self] in
                        let name = self?.currentApp?.name ?? "app"
                        self?.hide()
                        self?.onUnlocked?(name)
                    }
                )

                window.contentView = NSHostingView(rootView: overlayView)
                window.orderFront(nil)
                overlayWindows.append(window)
            }
        } else {
            let window = LockOverlayWindow(for: nil, isFullScreen: false)
            window.delegate = self

            let overlayView = LockOverlayView(
                appName: app.name,
                bundleIdentifier: app.bundleIdentifier,
                isPrimary: true,
                onDismiss: { [weak self] in
                    let name = self?.currentApp?.name ?? "app"
                    self?.hide()
                    self?.onUnlocked?(name)
                }
            )

            window.contentView = NSHostingView(rootView: overlayView)
            window.orderFront(nil)
            overlayWindows.append(window)
        }
        
        // Make MakLock active so the overlay window is visible above other apps
        NSApp.activate(ignoringOtherApps: true)
    }

    private func activateProtectedApp(bundleIdentifier: String) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return
        }
        app.unhide()
        app.activate()
        NSLog("[MakLock] Activated app: %@", bundleIdentifier)
    }

    private func startTimeoutTimer() {
        let timeout = SafetyManager.isDevMode
            ? SafetyManager.devModeTimeout
            : SafetyManager.overlayTimeout

        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            NSLog("[MakLock Safety] Overlay timeout reached (%.0fs) — auto-dismissing", timeout)
            self?.closeWithoutUnlocking()
        }
    }

    private func stopTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        NSLog("[MakLock] User closed the lock window")
        closeWithoutUnlocking()
    }

    private func closeWithoutUnlocking() {
        stopTimeoutTimer()
        AuthenticationService.shared.cancelAuthentication()
        
        if let bundleID = currentApp?.bundleIdentifier ?? hiddenAppBundleID {
            AppMonitorService.shared.cancelPendingLock(for: bundleID)
        }

        overlayWindows.forEach { 
            $0.delegate = nil
            $0.close() 
        }
        overlayWindows.removeAll()
        currentApp = nil
        hiddenAppBundleID = nil
    }
}
import AppKit

import AppKit

extension OverlayWindowService {
    /// Quit the currently locked app without unlocking.
    func quitCurrentApp() {
        guard let bundleID = currentApp?.bundleIdentifier ?? hiddenAppBundleID else { return }
        
        // Prevent hide() from reactivating this app
        let tempBundleID = hiddenAppBundleID
        hiddenAppBundleID = nil
        currentApp = nil
        
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            NSLog("[MakLock] Quitting app from lock overlay: %@", bundleID)
            app.terminate()
        }
        
        // Hide the overlay
        hide()
    }
}

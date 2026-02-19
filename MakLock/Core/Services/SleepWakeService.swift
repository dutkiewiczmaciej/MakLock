import Foundation
import AppKit

/// Monitors system sleep/wake events and triggers auto-lock on sleep.
final class SleepWakeService {
    static let shared = SleepWakeService()

    /// Callback when the system is about to sleep.
    var onSleep: (() -> Void)?

    /// Callback when the system wakes from sleep.
    var onWake: (() -> Void)?

    private var isObserving = false

    private init() {}

    /// Begin observing sleep/wake notifications.
    func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        let center = NSWorkspace.shared.notificationCenter

        center.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        center.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        NSLog("[MakLock] Sleep/wake observer started")
    }

    /// Stop observing sleep/wake notifications.
    func stopObserving() {
        guard isObserving else { return }
        isObserving = false

        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NSLog("[MakLock] Sleep/wake observer stopped")
    }

    // MARK: - Handlers

    @objc private func handleSleep(_ notification: Notification) {
        guard Defaults.shared.appSettings.lockOnSleep else { return }
        NSLog("[MakLock] System going to sleep — triggering auto-lock")
        onSleep?()
    }

    @objc private func handleWake(_ notification: Notification) {
        NSLog("[MakLock] System woke from sleep")
        onWake?()
    }
}

import Foundation
import Sparkle
import UserNotifications

/// Manages automatic updates via Sparkle 2.
///
/// Uses `SPUStandardUpdaterController` for the standard update UI.
/// Implements gentle update reminders for menu bar (LSUIElement) apps —
/// background update checks post a macOS notification instead of
/// showing a modal window that would be hidden behind other apps.
final class UpdateService: NSObject, SPUStandardUserDriverDelegate {
    static let shared = UpdateService()

    /// Lazy so `self` is available as `userDriverDelegate` at creation time.
    private(set) lazy var controller: SPUStandardUpdaterController = {
        SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
    }()

    /// The underlying updater for programmatic access (e.g. "Check for Updates" button).
    var updater: SPUUpdater { controller.updater }

    private override init() {
        super.init()
    }

    /// Trigger lazy initialization of the controller (call from AppDelegate).
    func start() {
        _ = controller
    }

    // MARK: - SPUStandardUserDriverDelegate (Gentle Reminders)

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        // If app is in immediate focus (user just launched), show standard Sparkle UI
        if immediateFocus { return true }

        // Background update found → post a macOS notification
        postUpdateNotification(version: update.displayVersionString)
        return false
    }

    private func postUpdateNotification(version: String) {
        let content = UNMutableNotificationContent()
        content.title = "MakLock Update Available"
        content.body = "Version \(version) is ready to install."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "maklock-update",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

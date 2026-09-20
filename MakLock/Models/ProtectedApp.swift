import Foundation

/// An application that the user has chosen to protect with MakLock.
struct ProtectedApp: Codable, Identifiable, Hashable {
    /// Unique identifier for this entry.
    let id: UUID

    /// The app's bundle identifier (e.g. "com.apple.Safari").
    let bundleIdentifier: String

    /// Display name (e.g. "Safari").
    let name: String

    /// Path to the application bundle on disk.
    let path: String

    /// Whether protection is currently enabled for this app.
    var isEnabled: Bool

    /// Whether to auto-close this app after inactivity timeout.
    /// When enabled, the app will be terminated after the global inactive timeout
    /// to prevent notifications from appearing while the app is locked.
    var autoClose: Bool

    /// Minutes the app stays unlocked after a successful authentication, even across
    /// relaunch, idle lock and sleep. `nil` means ask every time (default behaviour).
    /// Optional so lists saved by older versions still decode.
    var stayUnlockedMinutes: Int?

    /// Date the app was added to the protected list.
    let dateAdded: Date

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        name: String,
        path: String,
        isEnabled: Bool = true,
        autoClose: Bool = false,
        stayUnlockedMinutes: Int? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
        self.isEnabled = isEnabled
        self.autoClose = autoClose
        self.stayUnlockedMinutes = stayUnlockedMinutes
        self.dateAdded = dateAdded
    }
}

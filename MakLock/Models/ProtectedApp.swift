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

    /// Date the app was added to the protected list.
    let dateAdded: Date

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        name: String,
        path: String,
        isEnabled: Bool = true,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
        self.isEnabled = isEnabled
        self.dateAdded = dateAdded
    }
}

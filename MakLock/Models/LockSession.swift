import Foundation

/// Represents an active lock session for a protected application.
struct LockSession: Identifiable {
    let id: UUID
    let app: ProtectedApp
    let lockedAt: Date
    var isOverlayVisible: Bool

    init(app: ProtectedApp, lockedAt: Date = Date()) {
        self.id = UUID()
        self.app = app
        self.lockedAt = lockedAt
        self.isOverlayVisible = true
    }

    /// Seconds since the overlay was shown.
    var elapsedSeconds: TimeInterval {
        Date().timeIntervalSince(lockedAt)
    }
}

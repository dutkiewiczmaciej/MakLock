import Foundation

/// Authentication methods supported by MakLock.
enum AuthMethod: String, Codable, CaseIterable {
    /// Touch ID biometric authentication.
    case touchID

    /// Backup password stored in Keychain.
    case password
}

/// Result of an authentication attempt.
enum AuthResult {
    case success
    case failure(AuthError)
    case cancelled
}

/// Authentication errors.
enum AuthError: Error, LocalizedError {
    case biometryNotAvailable
    case biometryNotEnrolled
    case biometryLockout
    case wrongPassword
    case noPasswordSet
    case systemError(String)

    var errorDescription: String? {
        switch self {
        case .biometryNotAvailable:
            return String(localized: "Touch ID is not available on this Mac.")
        case .biometryNotEnrolled:
            return String(localized: "No fingerprints are enrolled in Touch ID.")
        case .biometryLockout:
            return String(localized: "Touch ID is locked. Use your password instead.")
        case .wrongPassword:
            return String(localized: "Incorrect password. Please try again.")
        case .noPasswordSet:
            return String(localized: "No backup password has been set. Go to Settings → Security.")
        case .systemError(let message):
            return message
        }
    }
}

import LocalAuthentication
import Foundation

/// Handles Touch ID and password authentication.
final class AuthenticationService {
    static let shared = AuthenticationService()

    /// Whether a Touch ID evaluation is currently in progress.
    private(set) var isAuthenticating = false

    /// The active LAContext — kept so it can be cancelled on overlay dismiss.
    private var activeContext: LAContext?

    /// A Touch ID request that arrived while another prompt was showing
    /// (e.g. the lock overlay appearing while the Settings prompt is up).
    /// It starts as soon as the current prompt finishes.
    private var queuedRequest: (() -> Void)?

    private init() {}

    /// Attempt Touch ID authentication.
    /// Only one evaluatePolicy runs at a time; a concurrent call is queued and
    /// started when the current one finishes, so its completion always fires.
    func authenticateWithTouchID(reason: String = String(localized: "Unlock this app"), completion: @escaping (AuthResult) -> Void) {
        guard !isAuthenticating else {
            NSLog("[MakLock] Touch ID already in progress — queuing request")
            queuedRequest = { [weak self] in
                self?.authenticateWithTouchID(reason: reason, completion: completion)
            }
            return
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            let authError = mapLAError(error)
            completion(.failure(authError))
            return
        }

        isAuthenticating = true
        activeContext = context

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.activeContext = nil
                defer { self.startQueuedRequest() }

                if success {
                    completion(.success)
                } else if let error = error as? LAError, error.code == .userCancel {
                    completion(.cancelled)
                } else {
                    let authError = self.mapLAError(error as NSError?)
                    completion(.failure(authError))
                }
            }
        }
    }

    /// Cancel any in-progress Touch ID evaluation (called when overlay is dismissed externally).
    func cancelAuthentication() {
        queuedRequest = nil
        activeContext?.invalidate()
        activeContext = nil
        isAuthenticating = false
    }

    private func startQueuedRequest() {
        guard let request = queuedRequest else { return }
        queuedRequest = nil
        request()
    }

    /// Verify the backup password.
    func authenticateWithPassword(_ password: String) -> AuthResult {
        guard KeychainManager.shared.hasPassword() else {
            return .failure(.noPasswordSet)
        }

        if KeychainManager.shared.verifyPassword(password) {
            return .success
        } else {
            return .failure(.wrongPassword)
        }
    }

    /// Authenticate with Touch ID, falling back to macOS login password.
    /// Used for settings access gating — shows the native system dialog, not the full-screen overlay.
    func authenticateWithSystemFallback(reason: String, completion: @escaping (AuthResult) -> Void) {
        guard !isAuthenticating else {
            completion(.cancelled)
            return
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(.failure(mapLAError(error)))
            return
        }

        isAuthenticating = true
        activeContext = context

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.activeContext = nil
                defer { self.startQueuedRequest() }

                if success {
                    completion(.success)
                } else if let error = error as? LAError, error.code == .userCancel {
                    completion(.cancelled)
                } else {
                    completion(.failure(self.mapLAError(error as NSError?)))
                }
            }
        }
    }

    /// Check if Touch ID is available on this Mac.
    var isTouchIDAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // MARK: - Private

    private func mapLAError(_ error: NSError?) -> AuthError {
        guard let error else { return .systemError(String(localized: "Unknown error")) }

        switch LAError.Code(rawValue: error.code) {
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .biometryLockout
        default:
            return .systemError(error.localizedDescription)
        }
    }
}

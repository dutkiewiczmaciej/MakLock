import LocalAuthentication
import Foundation

/// Handles Touch ID and password authentication.
final class AuthenticationService {
    static let shared = AuthenticationService()

    private init() {}

    /// Attempt Touch ID authentication.
    func authenticateWithTouchID(reason: String = "Unlock this app", completion: @escaping (AuthResult) -> Void) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            let authError = mapLAError(error)
            completion(.failure(authError))
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
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

    /// Check if Touch ID is available on this Mac.
    var isTouchIDAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // MARK: - Private

    private func mapLAError(_ error: NSError?) -> AuthError {
        guard let error else { return .systemError("Unknown error") }

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

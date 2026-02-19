import SwiftUI

/// Password fallback input view shown in the lock overlay.
struct PasswordInputView: View {
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var shakeOffset: CGFloat = 0

    let onSuccess: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Enter Password")
                .font(MakLockTypography.title)
                .foregroundColor(MakLockColors.textPrimary)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .onSubmit { verifyPassword() }
                .offset(x: shakeOffset)

            if let errorMessage {
                Text(errorMessage)
                    .font(MakLockTypography.caption)
                    .foregroundColor(MakLockColors.error)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }

                PrimaryButton("Unlock") {
                    verifyPassword()
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MakLockColors.cardDark)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        )
    }

    private func verifyPassword() {
        let result = AuthenticationService.shared.authenticateWithPassword(password)

        switch result {
        case .success:
            onSuccess()
        case .failure(let error):
            errorMessage = error.localizedDescription
            password = ""
            triggerShake()
        case .cancelled:
            break
        }
    }

    private func triggerShake() {
        withAnimation(Animation.default.speed(4)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(Animation.default.speed(4)) {
                shakeOffset = -10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(Animation.default.speed(4)) {
                shakeOffset = 0
            }
        }
    }
}

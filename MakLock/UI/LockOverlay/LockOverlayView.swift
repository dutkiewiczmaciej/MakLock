import SwiftUI

/// The lock overlay UI: blur background with centered unlock card.
/// Touch ID triggers automatically on appear — no user interaction needed for the happy path.
struct LockOverlayView: View {
    let appName: String
    let bundleIdentifier: String
    let isPrimary: Bool
    let onDismiss: () -> Void
    /// Called when the user gives up — the app must stay locked.
    let onCancel: () -> Void

    @State private var isVisible = false
    @State private var showPasswordInput = false
    @State private var authState: AuthState = .authenticating
    @State private var errorMessage: String?
    @State private var currentAttempt: UUID?

    private enum AuthState {
        case authenticating
        case waitingForUser
    }

    var body: some View {
        ZStack {
            // Blur background
            BlurView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Dark tint
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            if showPasswordInput {
                PasswordInputView(
                    onSuccess: {
                        onDismiss()
                    },
                    onCancel: {
                        showPasswordInput = false
                    }
                )
                .transition(.opacity)
            } else {
                // Unlock card
                VStack(spacing: 20) {
                    // App icon
                    AppIconView(bundleIdentifier: bundleIdentifier, size: 64)

                    // Title
                    Text("\(appName) is Locked")
                        .font(MakLockTypography.largeTitle)
                        .foregroundColor(MakLockColors.textPrimary)

                    if authState == .authenticating {
                        // Touch ID in progress
                        ProgressView()
                            .controlSize(.regular)
                            .padding(.top, 4)

                        Text("Authenticating...")
                            .font(MakLockTypography.body)
                            .foregroundColor(MakLockColors.textSecondary)
                    } else {
                        // Touch ID failed or cancelled — show options
                        if let errorMessage {
                            Text(errorMessage)
                                .font(MakLockTypography.caption)
                                .foregroundColor(MakLockColors.error)
                        }

                        PrimaryButton("Try Again", icon: "touchid") {
                            attemptTouchID()
                        }
                        .padding(.top, 4)

                        SecondaryButton("Use Password Instead") {
                            OverlayWindowService.shared.enableKeyboardInput()
                            withAnimation(MakLockAnimations.standard) {
                                showPasswordInput = true
                            }
                        }

                    }

                    // Always available, also while Touch ID is in progress,
                    // so the user is never stuck on the lock screen.
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(MakLockTypography.button)
                            .foregroundColor(MakLockColors.textPrimary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(MakLockColors.separator)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    // Dev mode skip button
                    #if DEBUG
                    Button("Skip (Dev)") {
                        onDismiss()
                    }
                    .font(MakLockTypography.caption)
                    .foregroundColor(MakLockColors.error)
                    .padding(.top, 8)
                    #endif
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(MakLockColors.cardDark)
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
                )
                .scaleEffect(isVisible ? 1.0 : 0.9)
                .opacity(isVisible ? 1.0 : 0.0)
                .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(MakLockAnimations.overlayAppear) {
                isVisible = true
            }
            // Only the primary screen triggers Touch ID (prevents duplicate system prompts)
            if isPrimary {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    attemptTouchID()
                }
            }
        }
    }

    private func attemptTouchID() {
        authState = .authenticating
        errorMessage = nil

        // If the system never answers, fall back to the buttons instead of spinning forever
        let attempt = UUID()
        currentAttempt = attempt
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            guard currentAttempt == attempt, authState == .authenticating else { return }
            AuthenticationService.shared.cancelAuthentication()
            OverlayWindowService.shared.setTouchIDMode(false)
            authState = .waitingForUser
            errorMessage = String(localized: "Touch ID did not respond.")
        }

        // Lower overlay level and pass through mouse so system Touch ID dialog gets full focus
        OverlayWindowService.shared.setTouchIDMode(true)

        AuthenticationService.shared.authenticateWithTouchID(
            reason: String(localized: "Unlock \(appName)")
        ) { result in
            guard currentAttempt == attempt else { return } // already timed out
            currentAttempt = nil

            // Restore overlay level and mouse capture
            OverlayWindowService.shared.setTouchIDMode(false)

            switch result {
            case .success:
                onDismiss()
            case .failure(let error):
                AccessLog.record("Touch ID failed for \(appName): \(error.localizedDescription)")
                authState = .waitingForUser
                errorMessage = error.localizedDescription
            case .cancelled:
                authState = .waitingForUser
            }
        }
    }
}

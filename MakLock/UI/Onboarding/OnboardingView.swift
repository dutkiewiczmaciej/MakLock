import SwiftUI

/// First-launch onboarding view with welcome, safety tutorial, password setup, and finish.
struct OnboardingView: View {
    @State private var currentStep = 0
    let onComplete: () -> Void

    /// Total number of steps (including interactive password step at index 2).
    private let totalSteps = 5

    private let infoSteps: [Int: OnboardingInfoStep] = [
        0: OnboardingInfoStep(
            icon: "lock.shield.fill",
            title: "Welcome to MakLock",
            description: "Lock any macOS app with Touch ID or password. Your apps, your privacy."
        ),
        1: OnboardingInfoStep(
            icon: "exclamationmark.triangle.fill",
            title: "Panic Key",
            description: "If you ever get locked out, press\n⌘ ⌥ ⇧ ⌃ U\nto instantly dismiss all overlays.\n\nTry it now — it always works."
        ),
        // Step 2 is interactive (password setup)
        3: OnboardingInfoStep(
            icon: "plus.app.fill",
            title: "Add Apps to Protect",
            description: "Open Settings → Apps to choose which applications require authentication. Start with a test app like Chess."
        ),
        4: OnboardingInfoStep(
            icon: "touchid",
            title: "You're All Set",
            description: "MakLock runs in your menu bar. Protected apps will require Touch ID to open — just put your finger on the sensor."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            Group {
                if currentStep == 2 {
                    PasswordSetupStep(onContinue: { advanceStep() })
                } else if let info = infoSteps[currentStep] {
                    InfoStepView(step: info)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(MakLockAnimations.standard, value: currentStep)

            // Navigation
            HStack {
                // Step indicators
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? MakLockColors.gold : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                if currentStep != 2 {
                    if currentStep < totalSteps - 1 {
                        PrimaryButton("Continue") {
                            advanceStep()
                        }
                    } else {
                        PrimaryButton("Get Started") {
                            onComplete()
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 480, height: 420)
        .background(MakLockColors.background)
    }

    private func advanceStep() {
        withAnimation(MakLockAnimations.standard) {
            currentStep += 1
        }
    }
}

// MARK: - Info Step View

private struct InfoStepView: View {
    let step: OnboardingInfoStep

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: step.icon)
                .font(.system(size: 48))
                .foregroundColor(MakLockColors.gold)
                .frame(height: 60)

            Text(step.title)
                .font(MakLockTypography.largeTitle)
                .foregroundColor(MakLockColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(step.description)
                .font(MakLockTypography.body)
                .foregroundColor(MakLockColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// MARK: - Password Setup Step

private struct PasswordSetupStep: View {
    let onContinue: () -> Void

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isSaved = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(MakLockColors.gold)
                .frame(height: 60)

            Text("Set Backup Password")
                .font(MakLockTypography.largeTitle)
                .foregroundColor(MakLockColors.textPrimary)

            Text("This password is used when Touch ID is unavailable.\nYou can change it later in Settings.")
                .font(MakLockTypography.body)
                .foregroundColor(MakLockColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if isSaved {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(MakLockColors.success)
                    Text("Password saved!")
                        .font(MakLockTypography.body)
                        .foregroundColor(MakLockColors.success)
                }
                .padding(.top, 8)

                PrimaryButton("Continue") {
                    onContinue()
                }
            } else {
                VStack(spacing: 12) {
                    SecureField("Password (4+ characters)", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                        .onSubmit { savePassword() }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(MakLockTypography.caption)
                        .foregroundColor(MakLockColors.error)
                }

                HStack(spacing: 12) {
                    SecondaryButton("Skip for now") {
                        onContinue()
                    }

                    PrimaryButton("Save Password") {
                        savePassword()
                    }
                }
            }

            Spacer()
        }
    }

    private func savePassword() {
        guard !password.isEmpty else {
            errorMessage = "Password cannot be empty."
            return
        }
        guard password.count >= 4 else {
            errorMessage = "Password must be at least 4 characters."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        let saved = KeychainManager.shared.savePassword(password)
        if saved {
            Defaults.shared.isBackupPasswordSet = true
            withAnimation(MakLockAnimations.standard) {
                isSaved = true
            }
        } else {
            errorMessage = "Failed to save. Please try again."
        }
    }
}

// MARK: - Models

private struct OnboardingInfoStep {
    let icon: String
    let title: String
    let description: String
}

import SwiftUI
import ServiceManagement

/// First-launch onboarding view with welcome, safety tutorial, password setup, and finish.
struct OnboardingView: View {
    @State private var currentStep = 0
    let onComplete: () -> Void

    private let totalSteps = 5

    private let infoSteps: [Int: OnboardingInfoStep] = [
        0: OnboardingInfoStep(
            icon: "lock.shield.fill",
            title: "Welcome to MakLock",
            description: "Lock any macOS app with Touch ID or password.\nYour apps, your privacy."
        ),
        // Step 1 = Panic Key (custom view)
        // Step 2 = Password Setup (custom view)
        3: OnboardingInfoStep(
            icon: "plus.app.fill",
            title: "Add Apps to Protect",
            description: "Open Settings → Apps to choose which applications require authentication.\n\nStart with a test app like Chess."
        )
        // Step 4 = Final Step (custom view with Launch at Login toggle)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch currentStep {
                case 1:
                    PanicKeyStep()
                case 2:
                    PasswordSetupStep(onContinue: { advanceStep() })
                case 4:
                    FinalStep()
                default:
                    if let info = infoSteps[currentStep] {
                        InfoStepView(step: info)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(MakLockAnimations.standard, value: currentStep)

            // Navigation
            HStack {
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? MakLockColors.gold : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                // Password step handles its own button
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
        .frame(width: 480, height: 440)
        .background(MakLockColors.background)
    }

    private func advanceStep() {
        withAnimation(MakLockAnimations.standard) {
            currentStep += 1
        }
    }
}

// MARK: - Info Step

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
                .frame(maxWidth: 340)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// MARK: - Panic Key Step

private struct PanicKeyStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(MakLockColors.gold)
                .frame(height: 60)

            Text("Emergency Panic Key")
                .font(MakLockTypography.largeTitle)
                .foregroundColor(MakLockColors.textPrimary)

            Text("If you ever get locked out, this shortcut\ninstantly dismisses all overlays:")
                .font(MakLockTypography.body)
                .foregroundColor(MakLockColors.textSecondary)
                .multilineTextAlignment(.center)

            // Visual keyboard shortcut
            HStack(spacing: 6) {
                KeyCap("⌘", label: "Command")
                Text("+").foregroundColor(MakLockColors.textSecondary)
                KeyCap("⌥", label: "Option")
                Text("+").foregroundColor(MakLockColors.textSecondary)
                KeyCap("⇧", label: "Shift")
                Text("+").foregroundColor(MakLockColors.textSecondary)
                KeyCap("⌃", label: "Control")
                Text("+").foregroundColor(MakLockColors.textSecondary)
                KeyCap("U", label: nil)
            }
            .padding(.vertical, 8)

            Text("Try it now — it always works, even in full screen.")
                .font(MakLockTypography.caption)
                .foregroundColor(MakLockColors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }
}

/// A visual keyboard key cap.
private struct KeyCap: View {
    let symbol: String
    let label: String?

    init(_ symbol: String, label: String?) {
        self.symbol = symbol
        self.label = label
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(symbol)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(MakLockColors.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(MakLockColors.cardDark)
                        .shadow(color: .black.opacity(0.4), radius: 1, y: 2)
                )

            if let label {
                Text(label)
                    .font(.system(size: 8))
                    .foregroundColor(MakLockColors.textSecondary)
            }
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
    @State private var showPassword = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(MakLockColors.gold)
                .frame(height: 60)

            Text("Set Backup Password")
                .font(MakLockTypography.largeTitle)
                .foregroundColor(MakLockColors.textPrimary)

            Text("Required as fallback when Touch ID is unavailable.\nYou can change it later in Settings.")
                .font(MakLockTypography.body)
                .foregroundColor(MakLockColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

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
                VStack(spacing: 10) {
                    passwordField("Password (4+ characters)", text: $password)
                    passwordField("Confirm Password", text: $confirmPassword)
                        .onSubmit { savePassword() }
                }

                // Show/hide toggle
                Button(action: { showPassword.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                        Text(showPassword ? "Hide password" : "Show password")
                            .font(MakLockTypography.caption)
                    }
                    .foregroundColor(MakLockColors.textSecondary)
                }
                .buttonStyle(.plain)

                if let errorMessage {
                    Text(errorMessage)
                        .font(MakLockTypography.caption)
                        .foregroundColor(MakLockColors.error)
                }

                PrimaryButton("Save Password") {
                    savePassword()
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func passwordField(_ placeholder: String, text: Binding<String>) -> some View {
        Group {
            if showPassword {
                TextField(placeholder, text: text)
            } else {
                SecureField(placeholder, text: text)
            }
        }
        .textFieldStyle(.roundedBorder)
        .frame(width: 260)
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

// MARK: - Final Step

private struct FinalStep: View {
    @State private var launchAtLogin = true

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "touchid")
                .font(.system(size: 48))
                .foregroundColor(MakLockColors.gold)
                .frame(height: 60)

            Text("You're All Set")
                .font(MakLockTypography.largeTitle)
                .foregroundColor(MakLockColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("MakLock runs in your menu bar.\nProtected apps will require Touch ID — just put your finger on the sensor.")
                .font(MakLockTypography.body)
                .foregroundColor(MakLockColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            VStack(spacing: 12) {
                Toggle("Launch MakLock at login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .tint(MakLockColors.gold)

                Text("You can also configure idle auto-lock\nand other options in Settings.")
                    .font(MakLockTypography.caption)
                    .foregroundColor(MakLockColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()
        }
        .onAppear {
            // Enable launch at login by default during onboarding
            enableLaunchAtLogin()
        }
        .onDisappear {
            // Save the user's choice when leaving this step
            saveLaunchAtLogin()
        }
    }

    private func enableLaunchAtLogin() {
        launchAtLogin = true
    }

    private func saveLaunchAtLogin() {
        var settings = Defaults.shared.appSettings
        settings.launchAtLogin = launchAtLogin
        Defaults.shared.appSettings = settings

        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("[MakLock] Failed to set login item: %@", error.localizedDescription)
        }
    }
}

// MARK: - Models

private struct OnboardingInfoStep {
    let icon: String
    let title: String
    let description: String
}

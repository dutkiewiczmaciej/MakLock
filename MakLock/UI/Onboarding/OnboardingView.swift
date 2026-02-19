import SwiftUI

/// First-launch onboarding view with welcome, safety tutorial, and setup steps.
struct OnboardingView: View {
    @State private var currentStep = 0
    let onComplete: () -> Void

    private let steps = [
        OnboardingStep(
            icon: "lock.shield.fill",
            title: "Welcome to MakLock",
            description: "Lock any macOS app with Touch ID or password. Your apps, your privacy."
        ),
        OnboardingStep(
            icon: "exclamationmark.triangle.fill",
            title: "Panic Key",
            description: "If you ever get locked out, press\n⌘ ⌥ ⇧ ⌃ U\nto instantly dismiss all overlays.\n\nTry it now — it always works."
        ),
        OnboardingStep(
            icon: "plus.app.fill",
            title: "Add Apps to Protect",
            description: "Open Settings → Apps to choose which applications require authentication. Start with a test app like Chess."
        ),
        OnboardingStep(
            icon: "touchid",
            title: "You're All Set",
            description: "MakLock runs in your menu bar. Protected apps will require Touch ID or your password to open."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: steps[currentStep].icon)
                    .font(.system(size: 48))
                    .foregroundColor(MakLockColors.gold)
                    .frame(height: 60)

                Text(steps[currentStep].title)
                    .font(MakLockTypography.largeTitle)
                    .foregroundColor(MakLockColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(steps[currentStep].description)
                    .font(MakLockTypography.body)
                    .foregroundColor(MakLockColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(MakLockAnimations.standard, value: currentStep)

            // Navigation
            HStack {
                // Step indicators
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? MakLockColors.gold : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    PrimaryButton("Continue") {
                        withAnimation(MakLockAnimations.standard) {
                            currentStep += 1
                        }
                    }
                } else {
                    PrimaryButton("Get Started") {
                        onComplete()
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 480, height: 360)
        .background(MakLockColors.background)
    }
}

private struct OnboardingStep {
    let icon: String
    let title: String
    let description: String
}

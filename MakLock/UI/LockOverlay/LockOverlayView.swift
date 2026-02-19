import SwiftUI

/// The lock overlay UI: blur background with centered unlock card.
struct LockOverlayView: View {
    let appName: String
    let bundleIdentifier: String
    let onUnlock: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var showPasswordInput = false

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

                    Text("Use Touch ID to unlock")
                        .font(MakLockTypography.body)
                        .foregroundColor(MakLockColors.textSecondary)

                    // Unlock button
                    PrimaryButton("Unlock", icon: "touchid") {
                        onUnlock()
                    }
                    .padding(.top, 4)

                    // Password fallback
                    SecondaryButton("Use Password Instead") {
                        withAnimation(MakLockAnimations.standard) {
                            showPasswordInput = true
                        }
                    }

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
        }
    }
}

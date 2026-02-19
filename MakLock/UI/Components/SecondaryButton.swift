import SwiftUI

/// Text-style button for secondary actions (Use Password, Cancel, etc.)
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MakLockTypography.caption)
                .foregroundColor(MakLockColors.textSecondary)
                .underline()
        }
        .buttonStyle(.plain)
    }
}

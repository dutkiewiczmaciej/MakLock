import SwiftUI

/// Gold accent button — used for primary actions (Unlock, Add, etc.)
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(MakLockTypography.button)
            }
            .foregroundColor(MakLockColors.background)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(MakLockColors.gold)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

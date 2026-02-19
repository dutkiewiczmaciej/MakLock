import SwiftUI

/// About window showing app version, credits, and links.
struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 16) {
            // App icon
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            // App name
            Text("MakLock")
                .font(MakLockTypography.largeTitle)

            // Version
            Text("Version \(version) (\(build))")
                .font(MakLockTypography.caption)
                .foregroundColor(.secondary)

            // Description
            Text("Lock any macOS app with Touch ID or password.")
                .font(MakLockTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 200)

            // Credits
            VStack(spacing: 4) {
                Text("Made by MakMak")
                    .font(MakLockTypography.body)
                Text("Free and open source under MIT License")
                    .font(MakLockTypography.caption)
                    .foregroundColor(.secondary)
            }

            // GitHub link
            Link(destination: URL(string: "https://github.com/dutkiewiczmaciej/maklock")!) {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                    Text("github.com/dutkiewiczmaciej/maklock")
                        .font(MakLockTypography.caption)
                }
            }
        }
        .padding(32)
        .frame(width: 360, height: 380)
    }
}

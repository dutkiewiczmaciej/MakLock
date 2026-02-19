import SwiftUI
import AppKit

/// Displays a macOS application icon with Launchpad-style rounding.
struct AppIconView: View {
    let bundleIdentifier: String?
    let size: CGFloat

    init(bundleIdentifier: String?, size: CGFloat = 64) {
        self.bundleIdentifier = bundleIdentifier
        self.size = size
    }

    var body: some View {
        Group {
            if let image = appIcon {
                Image(nsImage: image)
                    .resizable()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .foregroundColor(MakLockColors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
    }

    private var appIcon: NSImage? {
        guard let bundleID = bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

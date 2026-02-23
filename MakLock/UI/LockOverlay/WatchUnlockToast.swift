import AppKit
import SwiftUI

/// Brief HUD toast shown when an app is auto-unlocked via Apple Watch proximity.
/// Appears centered on the primary screen for 2 seconds, then fades out.
final class WatchUnlockToast {
    static let shared = WatchUnlockToast()

    private var window: NSPanel?
    private var dismissTimer: Timer?

    private init() {}

    /// Show the "Unlocked with Apple Watch" toast on the given app's screen.
    func show(for bundleIdentifier: String? = nil) {
        // Don't stack multiple toasts
        dismiss()

        let toast = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        toast.isOpaque = false
        toast.backgroundColor = .clear
        toast.hasShadow = false
        toast.level = .popUpMenu
        toast.hidesOnDeactivate = false
        toast.collectionBehavior = [.canJoinAllSpaces, .transient]
        toast.isMovableByWindowBackground = false
        toast.ignoresMouseEvents = true

        let view = NSHostingView(rootView: WatchUnlockToastView())
        view.frame.size = view.fittingSize
        toast.setContentSize(view.fittingSize)
        toast.contentView = view

        // Find the screen where the protected app lives
        let screen = screenForApp(bundleIdentifier) ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.frame
        let toastSize = toast.frame.size
        let x = screenFrame.midX - toastSize.width / 2
        let y = screenFrame.midY - toastSize.height / 2
        toast.setFrameOrigin(NSPoint(x: x, y: y))

        toast.alphaValue = 0
        toast.orderFront(nil)

        self.window = toast

        // Fade in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            toast.animator().alphaValue = 1
        }

        // Auto-dismiss after 4 seconds
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    /// Find the screen containing the frontmost window of the given app.
    private func screenForApp(_ bundleIdentifier: String?) -> NSScreen? {
        guard let bundleIdentifier else { return nil }
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else { return nil }

        // Get the app's windows via CGWindowList
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for windowInfo in windowList {
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == app.processIdentifier,
                  let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let wx = bounds["X"], let wy = bounds["Y"],
                  let ww = bounds["Width"], let wh = bounds["Height"],
                  ww > 0, wh > 0 else { continue }

            let windowCenter = NSPoint(x: wx + ww / 2, y: wy + wh / 2)
            // Find which screen contains this window's center
            for screen in NSScreen.screens {
                // Convert screen frame to CGWindow coordinate space (origin top-left)
                let sf = screen.frame
                let mainHeight = NSScreen.screens[0].frame.height
                let cgRect = CGRect(x: sf.origin.x, y: mainHeight - sf.origin.y - sf.height, width: sf.width, height: sf.height)
                if cgRect.contains(windowCenter) {
                    return screen
                }
            }
        }
        return nil
    }

    /// Dismiss the toast with fade-out.
    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil

        guard let window else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.close()
            self?.window = nil
        })
    }
}

/// The SwiftUI content for the Watch unlock toast.
private struct WatchUnlockToastView: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "applewatch")
                .font(.system(size: 32))
                .foregroundColor(MakLockColors.gold)

            VStack(alignment: .leading, spacing: 4) {
                Text("Unlocked")
                    .font(MakLockTypography.headline)
                    .foregroundColor(MakLockColors.textPrimary)
                Text("Apple Watch is nearby")
                    .font(MakLockTypography.caption)
                    .foregroundColor(MakLockColors.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MakLockColors.cardDark)
                .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        )
    }
}

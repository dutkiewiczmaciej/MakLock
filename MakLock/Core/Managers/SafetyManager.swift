import Foundation
import HotKey
import AppKit

/// Manages safety mechanisms to prevent the user from getting locked out.
///
/// Safety features:
/// - Panic key (Cmd+Option+Shift+Control+U) dismisses all overlays instantly
/// - System blacklist prevents locking Terminal, Xcode, and other dev tools
/// - Overlay timeout (60s) auto-dismisses stuck overlays
/// - Dev mode (DEBUG only) adds Skip button and 10s auto-dismiss
final class SafetyManager {
    static let shared = SafetyManager()

    /// Callback invoked when the panic key is pressed.
    var onPanicKeyPressed: (() -> Void)?

    /// Whether dev mode safety features are active.
    static var isDevMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Maximum overlay display time before auto-dismiss (seconds).
    static let overlayTimeout: TimeInterval = 60

    /// Dev mode auto-dismiss time (seconds).
    static let devModeTimeout: TimeInterval = 10

    /// Bundle identifiers that can never be locked.
    static let systemBlacklist: Set<String> = [
        // Apple system apps
        "com.apple.Terminal",
        "com.apple.finder",
        "com.apple.ActivityMonitor",
        "com.apple.systempreferences",          // Monterey and earlier
        "com.apple.SystemSettings",              // Ventura+
        "com.apple.System-Preferences",

        // Development tools
        "com.apple.dt.Xcode",
        "com.googlecode.iterm2",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.sublimetext.4",
        "com.jetbrains.intellij",

        // MakLock itself
        "com.makmak.MakLock",
    ]

    private var panicHotKey: HotKey?

    private init() {
        setupPanicKey()
    }

    // MARK: - Panic Key

    private func setupPanicKey() {
        // Cmd + Option + Shift + Control + U
        panicHotKey = HotKey(
            key: .u,
            modifiers: [.command, .option, .shift, .control]
        )

        panicHotKey?.keyDownHandler = { [weak self] in
            self?.triggerPanic()
        }
    }

    private func triggerPanic() {
        NSLog("[MakLock Safety] Panic key activated — dismissing all overlays")
        onPanicKeyPressed?()
    }

    // MARK: - Blacklist

    /// Check whether an app is on the system blacklist and must never be locked.
    static func isBlacklisted(_ bundleIdentifier: String) -> Bool {
        return systemBlacklist.contains(bundleIdentifier)
    }
}

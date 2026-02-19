import AppKit
import Combine

/// Manages the list of protected applications with CRUD operations and persistence.
final class ProtectedAppsManager: ObservableObject {
    static let shared = ProtectedAppsManager()

    @Published private(set) var apps: [ProtectedApp] = []

    private init() {
        apps = Defaults.shared.protectedApps
    }

    /// Add an application to the protected list.
    func addApp(bundleIdentifier: String, name: String, path: String) {
        guard !apps.contains(where: { $0.bundleIdentifier == bundleIdentifier }) else { return }

        let app = ProtectedApp(
            bundleIdentifier: bundleIdentifier,
            name: name,
            path: path
        )
        apps.append(app)
        save()
        NSLog("[MakLock] Added protected app: %@ (%@)", name, bundleIdentifier)
    }

    /// Add an app from an NSRunningApplication.
    func addApp(from runningApp: NSRunningApplication) {
        guard let bundleID = runningApp.bundleIdentifier,
              let name = runningApp.localizedName,
              let url = runningApp.bundleURL else { return }

        addApp(bundleIdentifier: bundleID, name: name, path: url.path)
    }

    /// Remove an application from the protected list.
    func removeApp(_ app: ProtectedApp) {
        apps.removeAll { $0.id == app.id }
        save()
        NSLog("[MakLock] Removed protected app: %@", app.name)
    }

    /// Toggle protection on or off for an app.
    func toggleApp(_ app: ProtectedApp) {
        guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[index].isEnabled.toggle()
        save()
    }

    /// Check whether an app with the given bundle identifier is protected and enabled.
    func isProtected(_ bundleIdentifier: String) -> Bool {
        return apps.contains { $0.bundleIdentifier == bundleIdentifier && $0.isEnabled }
    }

    private func save() {
        Defaults.shared.protectedApps = apps
    }
}

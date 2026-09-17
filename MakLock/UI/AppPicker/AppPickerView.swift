import SwiftUI
import AppKit
import CoreServices
import UniformTypeIdentifiers

/// Modal view for selecting applications to protect.
struct AppPickerView: View {
    @State private var searchText = ""
    @State private var selectedBundleIDs: Set<String> = []
    @State private var installedApps: [AppInfo] = []
    /// Explains why apps picked via "Browse…" could not be added.
    @State private var browseNotice: String?
    /// Bundle ID of the row to scroll to after browsing.
    @State private var scrollTarget: String?

    let onAppsSelected: ([AppInfo]) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Applications")
                    .font(MakLockTypography.title)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)

            Divider()
                .padding(.top, 8)

            // App list
            ScrollViewReader { proxy in
                List(filteredApps, id: \.bundleIdentifier) { app in
                    AppPickerRow(
                        app: app,
                        isSelected: selectedBundleIDs.contains(app.bundleIdentifier)
                    ) {
                        toggleSelection(app.bundleIdentifier)
                    }
                }
                .listStyle(.plain)
                .onChange(of: scrollTarget) { target in
                    guard let target else { return }
                    // Wait for the list to pick up the newly added row
                    DispatchQueue.main.async {
                        withAnimation { proxy.scrollTo(target, anchor: .center) }
                        scrollTarget = nil
                    }
                }
            }

            Divider()

            if let browseNotice {
                Text(browseNotice)
                    .font(MakLockTypography.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            // Footer
            HStack {
                Text("\(selectedBundleIDs.count) selected")
                    .font(MakLockTypography.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Browse…") {
                    browseForApps()
                }
                .help("Choose an app that is not in the list")

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                PrimaryButton("Add Selected") {
                    let selected = installedApps.filter { selectedBundleIDs.contains($0.bundleIdentifier) }
                    onAppsSelected(selected)
                }
                .disabled(selectedBundleIDs.isEmpty)
            }
            .padding()
        }
        .frame(width: 440, height: 520)
        .onAppear {
            loadInstalledApps()
        }
    }

    private var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return installedApps
        }
        let query = searchText
        return installedApps.filter { app in
            app.name.localizedCaseInsensitiveContains(query) ||
            app.bundleIdentifier.localizedCaseInsensitiveContains(query) ||
            app.searchableNames.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    private func toggleSelection(_ bundleID: String) {
        if selectedBundleIDs.contains(bundleID) {
            selectedBundleIDs.remove(bundleID)
        } else {
            selectedBundleIDs.insert(bundleID)
        }
    }

    private func loadInstalledApps() {
        let alreadyProtected = Set(Defaults.shared.protectedApps.map(\.bundleIdentifier))
        var apps: [AppInfo] = []
        var seenBundleIDs: Set<String> = []

        for dir in Self.appDirectories {
            for path in Self.appPaths(in: dir) {
                guard let app = Self.appInfo(atPath: path),
                      !SafetyManager.isBlacklisted(app.bundleIdentifier),
                      !alreadyProtected.contains(app.bundleIdentifier),
                      seenBundleIDs.insert(app.bundleIdentifier).inserted else { continue }
                apps.append(app)
            }
        }

        installedApps = Self.sortedByName(apps)
    }

    /// Let the user pick apps installed outside the scanned directories.
    private func browseForApps() {
        browseNotice = nil

        let panel = NSOpenPanel()
        panel.title = "Choose Applications"
        panel.prompt = "Choose"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            addPickedApps(panel.urls)
        }

        // Never runModal() here: an app-modal session makes a lock overlay that
        // appears in the meantime ignore clicks and suspends its timeout failsafe.
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    /// Add apps chosen via "Browse…" to the list and select them, reporting any that were rejected.
    private func addPickedApps(_ urls: [URL]) {
        let alreadyProtected = Set(Defaults.shared.protectedApps.map(\.bundleIdentifier))
        var apps = installedApps
        var rejected: [String] = []
        var firstPickedBundleID: String?

        for url in urls {
            let fallbackName = url.deletingPathExtension().lastPathComponent
            guard let app = Self.appInfo(atPath: url.path) else {
                rejected.append("\(fallbackName) can't be protected because it has no bundle identifier.")
                continue
            }
            if SafetyManager.isBlacklisted(app.bundleIdentifier) {
                rejected.append("\(app.name) can't be locked for safety reasons.")
                continue
            }
            if alreadyProtected.contains(app.bundleIdentifier) {
                rejected.append("\(app.name) is already protected.")
                continue
            }
            if !apps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                apps.append(app)
            }
            selectedBundleIDs.insert(app.bundleIdentifier)
            if firstPickedBundleID == nil { firstPickedBundleID = app.bundleIdentifier }
        }

        installedApps = Self.sortedByName(apps)
        browseNotice = rejected.isEmpty ? nil : rejected.joined(separator: " ")

        if let firstPickedBundleID {
            // Clear the filter so the picked app is visible, then reveal it
            searchText = ""
            scrollTarget = firstPickedBundleID
        }
    }

    // MARK: - App Discovery

    /// Directories scanned for installed applications.
    /// `~/Applications` holds per-user installs and browser web apps (PWAs).
    private static var appDirectories: [String] {
        [
            "/Applications",
            "/System/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path,
        ]
    }

    /// Paths of all `.app` bundles in a directory. Subfolders are searched one level deep
    /// to cover "Utilities" and browser web app folders (e.g. "Chrome Apps", "Brave Browser Apps").
    private static func appPaths(in dir: String, includingSubfolders: Bool = true) -> [String] {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { return [] }

        var paths: [String] = []
        for item in contents.sorted() where !item.hasPrefix(".") {
            let path = "\(dir)/\(item)"
            if item.hasSuffix(".app") {
                paths.append(path)
            } else if includingSubfolders {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
                    paths.append(contentsOf: appPaths(in: path, includingSubfolders: false))
                }
            }
        }
        return paths
    }

    /// Read bundle identifier and display names for the application at the given path.
    private static func appInfo(atPath path: String) -> AppInfo? {
        guard let bundle = Bundle(path: path),
              let bundleID = bundle.bundleIdentifier else { return nil }

        // Use localized display name from Spotlight metadata (most reliable)
        let fileURL = URL(fileURLWithPath: path)
        var spotlightName: String?
        if let mdItem = MDItemCreateWithURL(nil, fileURL as CFURL),
           let mdName = MDItemCopyAttribute(mdItem, kMDItemDisplayName) as? String {
            spotlightName = mdName.replacingOccurrences(of: ".app", with: "")
        }

        // Fallback to FileManager displayName
        let displayName = FileManager.default.displayName(atPath: path)
            .replacingOccurrences(of: ".app", with: "")

        let name = spotlightName ?? displayName

        // Collect alternative names for search
        var searchNames: Set<String> = []

        // Filename (always English on macOS, e.g. "Chess")
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        searchNames.insert(fileName)
        searchNames.insert(displayName)
        if let sn = spotlightName { searchNames.insert(sn) }

        // CFBundleName / CFBundleDisplayName from Info.plist
        if let bundleName = bundle.infoDictionary?["CFBundleName"] as? String {
            searchNames.insert(bundleName)
        }
        if let displayName = bundle.infoDictionary?["CFBundleDisplayName"] as? String {
            searchNames.insert(displayName)
        }

        // Localized names from the bundle
        if let localDict = bundle.localizedInfoDictionary {
            if let n = localDict["CFBundleDisplayName"] as? String { searchNames.insert(n) }
            if let n = localDict["CFBundleName"] as? String { searchNames.insert(n) }
        }

        NSLog("[MakLock] App: %@ | display=%@ | spotlight=%@ | searchNames=%@",
              bundleID, displayName, spotlightName ?? "nil", searchNames.description)

        return AppInfo(
            bundleIdentifier: bundleID,
            name: name,
            path: path,
            searchableNames: Array(searchNames)
        )
    }

    private static func sortedByName(_ apps: [AppInfo]) -> [AppInfo] {
        apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - AppInfo

/// Lightweight info about an installed application.
struct AppInfo: Identifiable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let path: String
    /// All localized names (English, Polish, etc.) for search.
    var searchableNames: [String] = []
}

// MARK: - Row

private struct AppPickerRow: View {
    let app: AppInfo
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AppIconView(bundleIdentifier: app.bundleIdentifier, size: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(MakLockTypography.headline)
                    Text(app.bundleIdentifier)
                        .font(MakLockTypography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? MakLockColors.gold : .secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

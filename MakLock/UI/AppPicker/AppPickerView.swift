import SwiftUI
import AppKit
import CoreServices

/// Modal view for selecting applications to protect.
struct AppPickerView: View {
    @State private var searchText = ""
    @State private var selectedBundleIDs: Set<String> = []
    @State private var installedApps: [AppInfo] = []

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
            List(filteredApps, id: \.bundleIdentifier) { app in
                AppPickerRow(
                    app: app,
                    isSelected: selectedBundleIDs.contains(app.bundleIdentifier)
                ) {
                    toggleSelection(app.bundleIdentifier)
                }
            }
            .listStyle(.plain)

            Divider()

            // Footer
            HStack {
                Text("\(selectedBundleIDs.count) selected")
                    .font(MakLockTypography.caption)
                    .foregroundColor(.secondary)
                Spacer()
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
        let fileManager = FileManager.default
        let appDirs = ["/Applications", "/System/Applications"]
        var apps: [AppInfo] = []

        let alreadyProtected = Set(Defaults.shared.protectedApps.map(\.bundleIdentifier))

        for dir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let path = "\(dir)/\(item)"
                guard let bundle = Bundle(path: path),
                      let bundleID = bundle.bundleIdentifier,
                      !SafetyManager.isBlacklisted(bundleID),
                      !alreadyProtected.contains(bundleID) else { continue }

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
                let fileName = (item as NSString).deletingPathExtension
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

                apps.append(AppInfo(
                    bundleIdentifier: bundleID,
                    name: name,
                    path: path,
                    searchableNames: Array(searchNames)
                ))
            }
        }

        installedApps = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

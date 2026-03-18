import Foundation

/// Represents a currently mounted external volume.
struct ExternalVolume: Identifiable, Hashable {
    var id: String { uuid }

    let uuid: String
    let name: String
    let mountPath: String
}

/// Enumerates mounted external volumes and checks their connection status.
final class ExternalDriveService {
    static let shared = ExternalDriveService()

    private init() {}

    private let resourceKeys: Set<URLResourceKey> = [
        .volumeUUIDStringKey,
        .volumeNameKey,
        .volumeLocalizedNameKey,
        .volumeIsInternalKey,
        .volumeIsLocalKey
    ]

    func listMountedExternalVolumes() -> [ExternalVolume] {
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(resourceKeys),
            options: [.skipHiddenVolumes]
        ) else {
            return []
        }

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: resourceKeys) else { return nil }
            guard (values.volumeIsLocal ?? true) else { return nil }
            guard (values.volumeIsInternal ?? true) == false else { return nil }
            guard let uuid = values.volumeUUIDString, !uuid.isEmpty else { return nil }

            let name = values.volumeLocalizedName ?? values.volumeName ?? url.lastPathComponent
            return ExternalVolume(uuid: uuid, name: name, mountPath: url.path)
        }
        .sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func isVolumeConnected(uuid: String) -> Bool {
        guard !uuid.isEmpty else { return false }
        return listMountedExternalVolumes().contains(where: { $0.uuid == uuid })
    }
}

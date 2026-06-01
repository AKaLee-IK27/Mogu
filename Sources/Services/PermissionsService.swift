import Foundation

// Administrator elevation has no preflight permission grant. macOS prompts only
// when the user chooses an elevated system-level operation. Full Disk Access is
// optional and detected by probing the system TCC database, which is readable
// only after FDA is granted.
@MainActor
final class PermissionsService: ObservableObject {
    @Published private(set) var fullDiskAccess: PermissionStatus = .unknown

    init() {}

    func refresh() {
        fullDiskAccess = probeFullDiskAccess()
    }

    func status(for kind: PermissionKind) -> PermissionStatus {
        switch kind {
        case .administrator: return .promptsWhenNeeded
        case .fullDiskAccess: return fullDiskAccess
        }
    }

    // Permissions each screen's operations may optionally require.
    static func requirements(for item: SidebarItem) -> [PermissionKind] {
        switch item {
        case .clean, .optimize: return [.administrator]
        case .analyze, .uninstall, .status, .purge, .permissions: return []
        }
    }

    private func probeFullDiskAccess() -> PermissionStatus {
        let path = "/Library/Application Support/com.apple.TCC/TCC.db"
        guard FileManager.default.fileExists(atPath: path) else { return .unknown }

        do {
            let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
            defer { try? handle.close() }
            _ = try handle.read(upToCount: 1)
            return .granted
        } catch {
            return .notGranted
        }
    }
}

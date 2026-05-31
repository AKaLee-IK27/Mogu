import Foundation
import AppKit

// Detects permission status (where possible) and opens the relevant System
// Settings panes. Full Disk Access has no public query API, so it's probed by
// attempting to read a TCC-protected file — failure means not granted.
@MainActor
final class PermissionsService: ObservableObject {
    @Published private(set) var fullDiskAccess: PermissionStatus = .unknown

    init() {
        refresh()
    }

    func refresh() {
        fullDiskAccess = Self.probeFullDiskAccess()
    }

    func status(for kind: PermissionKind) -> PermissionStatus {
        switch kind {
        case .fullDiskAccess: return fullDiskAccess
        // No reliable pre-flight detection; macOS prompts at first use.
        case .administrator, .automation: return .promptsWhenNeeded
        }
    }

    // Reading a TCC-protected file (the TCC database) succeeds only when Full
    // Disk Access is granted. A thrown error means it's not.
    private static func probeFullDiskAccess() -> PermissionStatus {
        let probe = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        guard FileManager.default.fileExists(atPath: probe.path) else { return .unknown }
        do {
            let handle = try FileHandle(forReadingFrom: probe)
            defer { try? handle.close() }
            _ = try handle.read(upToCount: 1)
            return .granted
        } catch {
            return .notGranted
        }
    }

    func openSettings(for kind: PermissionKind) {
        guard let url = kind.settingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    // Permissions each screen's operations may require, most-impactful first.
    static func requirements(for item: SidebarItem) -> [PermissionKind] {
        switch item {
        case .clean:    return [.fullDiskAccess, .administrator]
        case .optimize: return [.administrator, .automation]
        case .analyze:  return [.fullDiskAccess]
        case .uninstall, .status, .purge, .permissions: return []
        }
    }
}

import Foundation

// Administrator elevation has no preflight permission grant. macOS prompts only
// when the user chooses an elevated system-level operation.
@MainActor
final class PermissionsService: ObservableObject {
    init() {}

    func refresh() {}

    func status(for kind: PermissionKind) -> PermissionStatus {
        switch kind {
        case .administrator: return .promptsWhenNeeded
        }
    }

    // Permissions each screen's operations may optionally require.
    static func requirements(for item: SidebarItem) -> [PermissionKind] {
        switch item {
        case .clean, .optimize: return [.administrator]
        case .analyze, .uninstall, .status, .purge, .permissions: return []
        }
    }
}

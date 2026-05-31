import Foundation

// The OS permissions the bundled `mo` runtime may need, surfaced to the user so
// they understand what they're granting and why. See PermissionsService for
// detection and Settings deep links.
enum PermissionKind: String, CaseIterable, Identifiable {
    case fullDiskAccess
    case administrator
    case automation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullDiskAccess: return "Full Disk Access"
        case .administrator:  return "Administrator"
        case .automation:     return "Automation (Apple Events)"
        }
    }

    var icon: String {
        switch self {
        case .fullDiskAccess: return "externaldrive.fill"
        case .administrator:  return "key.fill"
        case .automation:     return "gearshape.fill"
        }
    }

    // Why the runtime needs it, in plain language.
    var why: String {
        switch self {
        case .fullDiskAccess:
            return "Lets Mole scan and clean caches, logs, and app data across your "
                + "Library and other apps' folders. Without it, previews and cleanup "
                + "miss system-protected locations."
        case .administrator:
            return "Some optimize and clean steps modify system files (LaunchServices, "
                + "network caches, system caches) and need an admin password or Touch ID."
        case .automation:
            return "Lets Mole tell Finder and the Dock to refresh after optimization."
        }
    }

    // Deep link to the relevant System Settings pane, when one exists.
    var settingsURL: URL? {
        switch self {
        case .fullDiskAccess:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        case .automation:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        case .administrator:
            return nil // Not a Settings toggle — prompted at run time.
        }
    }
}

enum PermissionStatus {
    case granted            // detected as granted
    case notGranted         // detected as missing
    case promptsWhenNeeded  // can't pre-detect; macOS prompts at use
    case unknown            // couldn't determine

    var label: String {
        switch self {
        case .granted:           return "Granted"
        case .notGranted:        return "Not granted"
        case .promptsWhenNeeded: return "Prompts when needed"
        case .unknown:           return "Unknown"
        }
    }
}

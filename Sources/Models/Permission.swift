import Foundation

// Runtime elevation is optional and requested only for system-level cleanup.
// Full Disk Access is optional and suppresses macOS per-folder scan prompts.
enum PermissionKind: String, CaseIterable, Identifiable {
    case administrator
    case fullDiskAccess

    var id: String { rawValue }

    var title: String {
        switch self {
        case .administrator: return "Administrator"
        case .fullDiskAccess: return "Full Disk Access"
        }
    }

    var icon: String {
        switch self {
        case .administrator: return "key.fill"
        case .fullDiskAccess: return "externaldrive.fill"
        }
    }

    var why: String {
        switch self {
        case .administrator:
            return "Lets Mogu ask for your password only when you choose system-level cleanup. Optional; user-owned cleanup works without it."
        case .fullDiskAccess:
            return "Lets Mole scan your home folder quietly — macOS won't ask for each folder (Desktop, Documents, Downloads, …). Optional; the app works without it, you'll just see a per-folder prompt the first time you scan each one."
        }
    }

    var settingsURL: URL? {
        switch self {
        case .administrator: return nil
        case .fullDiskAccess:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
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

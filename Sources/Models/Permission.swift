import Foundation

// Runtime elevation is optional and requested only for system-level cleanup.
enum PermissionKind: String, CaseIterable, Identifiable {
    case administrator

    var id: String { rawValue }

    var title: String { "Administrator" }
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

import SwiftUI

// MARK: - Design Tokens
// Adaptive light/dark mode. Follows system colorScheme.

enum DesignTokens {

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let pill: CGFloat = 999
    }

    enum Font {
        static let page = SwiftUI.Font.system(size: 24, weight: .bold)
        static let section = SwiftUI.Font.system(size: 17, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 14, weight: .regular)
        static let bodyStrong = SwiftUI.Font.system(size: 14, weight: .medium)
        static let caption = SwiftUI.Font.system(size: 12, weight: .regular)
        static let captionStrong = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let label = SwiftUI.Font.system(size: 11, weight: .medium)
        static let sectionLabel = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let labelUppercase = SwiftUI.Font.system(size: 11, weight: .semibold)

        static let mono = SwiftUI.Font.system(size: 12, weight: .regular, design: .monospaced)
        static let monoBold = SwiftUI.Font.system(size: 12, weight: .semibold, design: .monospaced)
        static let monoLarge = SwiftUI.Font.system(size: 20, weight: .bold, design: .monospaced)
        static let displayNumber = SwiftUI.Font.system(size: 28, weight: .bold, design: .monospaced)

        static let sidebarTitle = SwiftUI.Font.system(size: 15, weight: .heavy, design: .rounded)
        static let sidebarSubtitle = SwiftUI.Font.system(size: 11, weight: .regular)
        static let sidebarItem = SwiftUI.Font.system(size: 13, weight: .regular)
        static let sidebarItemActive = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let code = SwiftUI.Font.system(size: 13, weight: .regular, design: .monospaced)
    }

    // Helper: create adaptive color from light/dark hex values
    static func adaptive(light: String, dark: String) -> SwiftUI.Color {
        SwiftUI.Color(light: SwiftUI.Color(hex: light), dark: SwiftUI.Color(hex: dark))
    }

    enum Color {
        // Surfaces
        static let sidebar = adaptive(light: "ececed", dark: "1e1e20")
        static let pageBackground = adaptive(light: "f5f5f7", dark: "121214")
        static let cardBackground = adaptive(light: "ffffff", dark: "1c1c1e")
        static let separator = adaptive(light: "d1d1d6", dark: "38383a")
        static let separatorLight = adaptive(light: "e5e5ea", dark: "2c2c2e")

        // Text, tuned for respective surfaces
        static let primary = adaptive(light: "1d1d1f", dark: "f5f5f7")
        static let secondary = adaptive(light: "515154", dark: "a1a1a6")
        static let tertiary = adaptive(light: "77777c", dark: "6e6e73")
        static let placeholder = adaptive(light: "aeaeb2", dark: "48484a")

        // Accent — Mogu navy/indigo (derived from the art's slate-blue, tuned for UI contrast)
        static let accent = adaptive(light: "3a4ea8", dark: "5d72d6")
        static let accentSecondary = adaptive(light: "7e8fde", dark: "8ea0f0")
        static let accentSoft = adaptive(light: "e7e9fb", dark: "20264a")
        static let accentTint = adaptive(light: "2c3e8f", dark: "7e92ef")

        // Status
        static let success = adaptive(light: "34c759", dark: "30d158")
        static let successText = adaptive(light: "1b7a2e", dark: "3dd560")
        static let successSoft = adaptive(light: "e8f9ec", dark: "0d2e12")
        static let warning = adaptive(light: "ff9500", dark: "ff9f0a")
        static let warningText = adaptive(light: "a05a00", dark: "ffd426")
        static let warningSoft = adaptive(light: "fff5e0", dark: "2e1f00")
        static let danger = adaptive(light: "ff3b30", dark: "ff453a")
        static let dangerText = adaptive(light: "c42118", dark: "ff6961")
        static let dangerSoft = adaptive(light: "ffe8e6", dark: "3d0a07")

        // Purge feature identity — teal, distinct from the other five tabs
        // (navy/green/red/orange/indigo) so its sidebar mark + loader read with
        // energy instead of muted gray.
        static let purgeAccent = adaptive(light: "0f8a9c", dark: "5ac8d8")

        // Utility
        static let codeBg = adaptive(light: "f0f0f2", dark: "2c2c2e")
        static let hoverOverlay = adaptive(light: "ececee", dark: "2a2a2c")
    }

    static func healthColor(score: Int) -> SwiftUI.Color {
        switch score {
        case 80...100: Color.successText
        case 60..<80: Color.warningText
        default: Color.dangerText
        }
    }

    static func healthBgColor(score: Int) -> SwiftUI.Color {
        switch score {
        case 80...100: Color.successSoft
        case 60..<80: Color.warningSoft
        default: Color.dangerSoft
        }
    }

    static func healthIcon(score: Int) -> String {
        switch score {
        case 80...100: "checkmark.seal.fill"
        case 60..<80: "exclamationmark.circle.fill"
        default: "xmark.circle.fill"
        }
    }

    @MainActor static let spring = Animation.spring(response: 0.25, dampingFraction: 0.75)
    @MainActor static let ease = Animation.easeInOut(duration: 0.25)
    @MainActor static func stagger(_ index: Int, base: Double = 0.04) -> Animation {
        Animation.spring(response: 0.35, dampingFraction: 0.8).delay(Double(index) * base)
    }

    enum Shadow {
        static let card = adaptive(light: "0000000a", dark: "0000004d") // ~4% light, ~30% dark
        static let cardRadius: CGFloat = 3
        static let cardY: CGFloat = 1
    }
}

extension SwiftUI.Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    /// Create adaptive color that resolves differently per colorScheme
    init(light: Self, dark: Self) {
        #if canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                NSColor(dark)
            } else {
                NSColor(light)
            }
        })
        #else
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #endif
    }


}

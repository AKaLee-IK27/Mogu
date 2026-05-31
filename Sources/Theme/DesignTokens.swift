import SwiftUI

// MARK: - Design Tokens
// Light-mode system for MoleMac, forced by MoleMacApp.

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

    enum Color {
        // Surfaces
        static let sidebar = SwiftUI.Color(hex: "ececed")
        static let pageBackground = SwiftUI.Color(hex: "f5f5f7")
        static let cardBackground = SwiftUI.Color.white
        static let separator = SwiftUI.Color(hex: "d1d1d6")
        static let separatorLight = SwiftUI.Color(hex: "e5e5ea")

        // Text, tuned for light surfaces
        static let primary = SwiftUI.Color(hex: "1d1d1f")
        static let secondary = SwiftUI.Color(hex: "515154")
        static let tertiary = SwiftUI.Color(hex: "77777c")
        static let placeholder = SwiftUI.Color(hex: "aeaeb2")

        // Accent
        static let accent = SwiftUI.Color(hex: "007aff")
        static let accentSecondary = SwiftUI.Color(hex: "5ac8fa")
        static let accentSoft = SwiftUI.Color(hex: "e5f1ff")
        static let accentTint = SwiftUI.Color(hex: "0055d4")

        // Status
        static let success = SwiftUI.Color(hex: "34c759")
        static let successText = SwiftUI.Color(hex: "1b7a2e")
        static let successSoft = SwiftUI.Color(hex: "e8f9ec")
        static let warning = SwiftUI.Color(hex: "ff9500")
        static let warningText = SwiftUI.Color(hex: "a05a00")
        static let warningSoft = SwiftUI.Color(hex: "fff5e0")
        static let danger = SwiftUI.Color(hex: "ff3b30")
        static let dangerText = SwiftUI.Color(hex: "c42118")
        static let dangerSoft = SwiftUI.Color(hex: "ffe8e6")

        // Utility
        static let codeBg = SwiftUI.Color(hex: "f0f0f2")
        static let hoverOverlay = SwiftUI.Color.black.opacity(0.04)
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
        static let card = SwiftUI.Color.black.opacity(0.06)
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
}

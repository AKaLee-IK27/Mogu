import SwiftUI

/// Lightweight onboarding shown on first launch. Three cards explaining what
/// Mogu does, the preview-before-delete safety net, and the optional-permission
/// model. Dismissed once via AppStorage.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let totalPages = 3

    var body: some View {
        VStack(spacing: 0) {
            // Card content — manually paged
            ZStack {
                ForEach(0..<totalPages, id: \.self) { index in
                    if index == currentPage {
                        card(for: index)
                            .transition(.opacity)
                    }
                }
            }
            .frame(height: 200)
            .padding(.horizontal, 32)
            .padding(.top, 28)

            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage
                              ? DesignTokens.Color.accent
                              : DesignTokens.Color.tertiary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 20)

            // Navigation buttons
            HStack(spacing: 16) {
                if currentPage == 0 {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                } else {
                    Button("Back") {
                        withAnimation(DesignTokens.spring) { currentPage -= 1 }
                    }
                }

                Spacer()

                Button(currentPage == totalPages - 1 ? "Get Started" : "Next") {
                    if currentPage == totalPages - 1 {
                        dismiss()
                    } else {
                        withAnimation(DesignTokens.spring) { currentPage += 1 }
                    }
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.Color.accent)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 400)
    }

    @ViewBuilder
    private func card(for index: Int) -> some View {
        switch index {
        case 0: onboardingCard(
            icon: "sparkles.square.filled.on.square",
            title: "What Mogu Does",
            body: "Mogu scans your Mac for caches, logs, leftover app files, and build artifacts. It is powered by the bundled Mole CLI. Nothing runs in the background."
        )
        case 1: onboardingCard(
            icon: "eye.circle",
            title: "Preview Before Delete",
            body: "Every destructive operation shows you exactly what will be affected before anything is removed. Clean, optimize, purge, and uninstall all preview first."
        )
        case 2: onboardingCard(
            icon: "lock.shield",
            title: "No Permissions Required",
            body: "Mogu needs no permission to start. Your administrator password is only requested when you choose to clean system-level items. Full Disk Access is optional."
        )
        default: EmptyView()
        }
    }

    private func onboardingCard(icon: String, title: String, body: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(DesignTokens.Color.accent)
                .frame(width: 64, height: 64)
                .background(DesignTokens.Color.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))

            Text(title)
                .font(DesignTokens.Font.section)
                .foregroundStyle(DesignTokens.Color.primary)

            Text(body)
                .font(DesignTokens.Font.body)
                .foregroundStyle(DesignTokens.Color.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 320)
        }
    }
}

import SwiftUI

// Shared failure state for the mo-backed tabs. Replaces the near-identical
// per-view `errorView(message:)` helpers so every tab fails the same way:
// a friendly heading, the underlying message, and an optional Retry that
// re-runs the tab's own load. Styled with DesignTokens — never raw text.
struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(DesignTokens.Color.danger)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("Something went wrong")
                    .font(DesignTokens.Font.section)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text(message)
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let retry {
                Button(action: retry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DesignTokens.Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

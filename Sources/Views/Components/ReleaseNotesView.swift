import SwiftUI

/// Shown after a version bump on next launch. Reads the bundled CHANGELOG.md
/// (falling back to "Initial release" if absent) and records the dismissed
/// version in AppStorage so it is not shown again.
struct ReleaseNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var changelog = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("What's New")
                    .font(DesignTokens.Font.section)
                    .foregroundStyle(DesignTokens.Color.primary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignTokens.Color.tertiary)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                Text(changelog)
                    .font(DesignTokens.Font.body)
                    .foregroundStyle(DesignTokens.Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 260)
            .padding(8)
            .background(DesignTokens.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.Color.accent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 400)
        .task { changelog = loadChangelog() }
    }

    private func loadChangelog() -> String {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md") else {
            return "Initial release of Mogu."
        }
        do {
            return try String(contentsOf: url)
        } catch {
            return "Initial release of Mogu."
        }
    }
}

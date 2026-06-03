import SwiftUI

struct HistoryView: View {
    let service: MoService
    @Binding var refreshTrigger: UUID
    @Binding var isLoading: Bool

    @State private var sessions: [HistorySession] = []
    @State private var totalFreed: String = "—"
    @State private var error: String?
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            ScrollView {
                if isLoading { loadingView }
                else if let error { ErrorStateView(message: error) { Task { await loadHistory() } } }
                else if sessions.isEmpty { emptyState }
                else { content }
            }
            .background(DesignTokens.Color.pageBackground)
        }
        .task { await loadHistory() }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Task { await loadHistory() }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("History")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Review past cleanup, purge, and uninstall sessions")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            if !sessions.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(totalFreed)
                        .font(DesignTokens.Font.monoBold)
                        .monospacedDigit()
                }
                .foregroundStyle(DesignTokens.Color.successText)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(DesignTokens.Color.successSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
            }
            HeaderIconButton(systemName: "arrow.clockwise", help: "Refresh history", disabled: isLoading) {
                Task { await loadHistory() }
            }
        }
        .padding(.horizontal, DesignTokens.Layout.headerHorizontalPadding)
        .padding(.vertical, DesignTokens.Layout.headerVerticalPadding)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Spacer()
            FeatureLoadingView(
                icon: "clock.arrow.circlepath",
                tint: DesignTokens.Color.accent,
                title: "Loading history…"
            )
            Spacer()
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.Color.tertiary)
            Text("No history yet")
                .font(DesignTokens.Font.section)
                .foregroundStyle(DesignTokens.Color.primary)
            Text("Run a Clean, Purge, or Uninstall to see your history here")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(DesignTokens.Spacing.xxxl)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            totalFreedCard
            ForEach(sessions) { session in
                sessionCard(session)
            }
        }
        .padding(.horizontal, DesignTokens.Layout.contentHorizontalPadding)
        .padding(.vertical, DesignTokens.Spacing.xl)
    }

    private var totalFreedCard: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignTokens.Color.successSoft)
                    .frame(width: 40, height: 40)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DesignTokens.Color.successText)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Total Space Freed")
                    .font(DesignTokens.Font.section)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text(totalFreed + " across \(sessions.count) sessions")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.secondary)
            }
            Spacer()
        }
        .padding(DesignTokens.Layout.cardPadding)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Shadow.cardRadius))
        .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardY, y: DesignTokens.Shadow.cardY)
    }

    @ViewBuilder
    private func sessionCard(_ s: HistorySession) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            commandIcon(s.command)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(s.command.capitalized)
                        .font(DesignTokens.Font.bodyStrong)
                        .foregroundStyle(DesignTokens.Color.primary)
                    Text(s.size)
                        .font(DesignTokens.Font.monoBold)
                        .foregroundStyle(DesignTokens.Color.successText)
                }
                Text(formatSessionDate(s.startedAt))
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text("\(s.items) items")
                    Text("·")
                    Text("\(s.operationCount) operations")
                    if s.actions.trashed > 0 {
                        Text("·")
                        Text("\(s.actions.trashed) trashed")
                    }
                    if s.actions.failed > 0 {
                        Text("·")
                        Text("\(s.actions.failed) failed")
                    }
                }
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
            }
            Spacer()
            if !s.endedAt.isEmpty {
                Text(durationText(from: s.startedAt, to: s.endedAt))
                    .font(DesignTokens.Font.mono)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
        }
        .padding(DesignTokens.Layout.cardPadding)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Shadow.cardRadius))
    }

    private func commandIcon(_ command: String) -> some View {
        let icon: String
        let color: SwiftUI.Color
        switch command.lowercased() {
        case "clean":
            icon = "sparkles"
            color = DesignTokens.Color.successText
        case "purge":
            icon = "trash.fill"
            color = DesignTokens.Color.purgeAccent
        case "uninstall":
            icon = "xmark.app.fill"
            color = DesignTokens.Color.dangerText
        case "optimize":
            icon = "bolt.horizontal.circle.fill"
            color = DesignTokens.Color.warning
        default:
            icon = "arrow.clockwise"
            color = DesignTokens.Color.accent
        }
        return ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 36, height: 36)
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Data loading

    private func loadHistory() async {
        isLoading = true
        error = nil
        do {
            let result = try await service.getHistory(limit: 100)
            sessions = result.sessions
            let bytes = result.totalFreedBytes
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            totalFreed = bytes > 0 ? formatter.string(fromByteCount: Int64(bytes)) : "0 B"
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
        withAnimation(DesignTokens.spring) { appear = true }
    }

    // MARK: - Helpers

    private func formatSessionDate(_ date: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let parsed = formatter.date(from: date) else { return date }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        return relative.localizedString(for: parsed, relativeTo: Date())
    }

    private func durationText(from start: String, to end: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let startDate = formatter.date(from: start),
              let endDate = formatter.date(from: end) else { return "" }
        let seconds = Int(endDate.timeIntervalSince(startDate))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let remaining = seconds % 60
        return "\(minutes)m \(remaining)s"
    }
}

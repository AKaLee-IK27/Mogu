import SwiftUI

struct InstallerView: View {
    let service: MoService
    @Binding var refreshTrigger: UUID
    @Binding var isLoading: Bool

    @State private var files: [InstallerFile] = []
    @State private var error: String?
    @State private var appear = false
    @State private var searchText = ""
    @State private var activity: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            ScrollView {
                if isLoading { loadingView }
                else if let error { ErrorStateView(message: error) { Task { await loadFiles() } } }
                else if files.isEmpty { emptyState }
                else { content }
            }
            .background(DesignTokens.Color.pageBackground)
        }
        .task { await loadFiles() }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Task { await loadFiles() }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Installer")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Find leftover .dmg, .pkg, and .zip installers in your home directory")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            if !files.isEmpty {
                InlineSearchField(text: $searchText, prompt: "Search installers")
                    .frame(width: 200)
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(totalInstallerSize)
                        .font(DesignTokens.Font.monoBold)
                        .monospacedDigit()
                }
                .foregroundStyle(DesignTokens.Color.warningText)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(DesignTokens.Color.warningSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
            }
            HeaderIconButton(systemName: "arrow.clockwise", help: "Re-scan", disabled: isLoading) {
                Task { await loadFiles() }
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
                icon: "shippingbox.fill",
                tint: DesignTokens.Color.warning,
                title: "Scanning for installers…"
            )
            Spacer()
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Spacer()
            Image(systemName: "shippingbox")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.Color.tertiary)
            Text("No installers found")
                .font(DesignTokens.Font.section)
                .foregroundStyle(DesignTokens.Color.primary)
            Text("Your home directory is clean of leftover installers")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
            Spacer()
        }
        .padding(DesignTokens.Spacing.xxxl)
    }

    // MARK: - Content

    private var filteredFiles: [InstallerFile] {
        guard !searchText.isEmpty else { return files }
        return files.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.location.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            installerSummaryCard
            installerNote
            fileList
        }
        .padding(.horizontal, DesignTokens.Layout.contentHorizontalPadding)
        .padding(.vertical, DesignTokens.Spacing.xl)
    }

    private var installerSummaryCard: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignTokens.Color.warningSoft)
                    .frame(width: 40, height: 40)
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DesignTokens.Color.warningText)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Installers Found")
                    .font(DesignTokens.Font.section)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("\(files.count) files totaling \(totalInstallerSize)")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.secondary)
            }
            Spacer()
        }
        .padding(DesignTokens.Layout.cardPadding)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Shadow.cardRadius))
    }

    private var installerNote: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.Color.warningText)
            Text("Review-only: delete these files manually from Finder or use Clean to remove")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
        }
        .padding(DesignTokens.Spacing.md)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Color.warningSoft)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
    }

    private var fileList: some View {
        VStack(spacing: 0) {
            ForEach(Array(filteredFiles.enumerated()), id: \.element.id) { index, file in
                installerRow(file)
                if index < filteredFiles.count - 1 {
                    Rectangle()
                        .fill(DesignTokens.Color.separatorLight)
                        .frame(height: 1)
                        .padding(.leading, 40)
                }
            }
        }
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Shadow.cardRadius))
        .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardY, y: DesignTokens.Shadow.cardY)
    }

    private func installerRow(_ file: InstallerFile) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: installerIcon(for: file.name))
                .font(.system(size: 16))
                .foregroundStyle(DesignTokens.Color.tertiary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(DesignTokens.Font.bodyStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                    .lineLimit(1)
                Text(file.path)
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            Text(file.size.humanReadable)
                .font(DesignTokens.Font.mono)
                .monospacedDigit()
                .foregroundStyle(DesignTokens.Color.warningText)
                .lineLimit(1)
            Text(file.location)
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.tertiary)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, 2)
                .background(DesignTokens.Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.tiny))
        }
        .padding(.horizontal, DesignTokens.Layout.cardPadding)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private func installerIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.hasSuffix(".dmg") { return "disk" }
        if lower.hasSuffix(".pkg") || lower.hasSuffix(".mpkg") { return "archivebox" }
        if lower.hasSuffix(".zip") { return "zip" }
        if lower.hasSuffix(".iso") { return "opticaldiscdrive" }
        if lower.hasSuffix(".xip") { return "archivebox" }
        return "doc"
    }

    private var totalInstallerSize: String {
        files.reduce(UInt64(0)) { $0 + $1.size }.humanReadable
    }

    // MARK: - Data loading

    private func loadFiles() async {
        isLoading = true
        error = nil
        activity = []

        var accumulated = ""
        for await event in service.stream(args: ["installer", "--dry-run"]) {
            switch event {
            case .line(let line):
                let cleaned = MoOutputParser.stripControlSequences(line)
                if !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    accumulated += cleaned + "\n"
                }
            case .finished:
                break
            case .error(let msg):
                error = msg
                isLoading = false
                return
            }
        }
        let result = MoOutputParser.parseInstallerList(text: accumulated)
        files = result.files
        isLoading = false
        withAnimation(DesignTokens.spring) { appear = true }
    }
}

import SwiftUI

struct AnalyzeView: View {
    let service: MoService
    @ObservedObject var permissions: PermissionsService
    @Environment(\.openURL) private var openURL
    @Binding var refreshTrigger: UUID
    @Binding var isLoading: Bool
    @State private var result: AnalysisResult?
    @State private var error: String?
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            if shouldShowFullDiskAccessHint {
                fullDiskAccessHint
                    .padding(.horizontal, DesignTokens.Layout.contentHorizontalPadding)
                    .padding(.top, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.lg)
            }

            ScrollView {
                if isLoading { loadingView }
                else if let error { ErrorStateView(message: error) { Task { await loadAnalysis() } } }
                else if let r = result { analysisContent(r) }
            }
            .background(DesignTokens.Color.pageBackground)
        }
        .task {
            permissions.refresh()
            await loadAnalysis()
        }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Task { await loadAnalysis() }
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Analyze")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("See what's taking up space in your home folder")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            if let r = result {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(r.totalSize.humanReadable)
                        .font(DesignTokens.Font.monoBold)
                        .monospacedDigit()
                }
                .foregroundStyle(DesignTokens.Color.accentTint)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(DesignTokens.Color.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
            }
            HeaderIconButton(systemName: "arrow.clockwise", help: "Re-analyze", disabled: isLoading) {
                Task { await loadAnalysis() }
            }
        }
        .padding(.horizontal, DesignTokens.Layout.headerHorizontalPadding)
        .padding(.vertical, DesignTokens.Layout.headerVerticalPadding)
    }

    private var shouldShowFullDiskAccessHint: Bool {
        switch permissions.status(for: .fullDiskAccess) {
        case .granted: return false
        case .notGranted, .promptsWhenNeeded, .unknown: return true
        }
    }

    private var fullDiskAccessHint: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.warningText)
                .frame(width: 28, height: 28)
                .background(DesignTokens.Color.warningSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text("Full Disk Access not granted")
                    .font(DesignTokens.Font.captionStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Some folders will be skipped during the scan. Grant Full Disk Access in System Settings to see complete results.")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let settingsURL = PermissionKind.fullDiskAccess.settingsURL {
                Button {
                    openURL(settingsURL)
                } label: {
                    Text("Open Settings")
                        .font(DesignTokens.Font.captionStrong)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(DesignTokens.Color.accent)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Color.warningSoft)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                .stroke(DesignTokens.Color.warningText.opacity(0.22), lineWidth: DesignTokens.Stroke.hairline)
        )
    }

    private func analysisContent(_ r: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            analyzeSummaryCard

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                sectionHeader("Top entries", subtitle: "\(r.entries.count) directories")

                VStack(spacing: 0) {
                    ForEach(Array(r.entries.enumerated()), id: \.element.id) { i, entry in
                        entryRow(entry, totalSize: r.totalSize)
                            .opacity(appear ? 1 : 0)
                            .offset(x: appear ? 0 : -8)
                            .animation(DesignTokens.stagger(i), value: appear)

                        if i < r.entries.count - 1 {
                            Rectangle()
                                .fill(DesignTokens.Color.separatorLight)
                                .frame(height: 1)
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(DesignTokens.Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                        .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
                )
                .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
            }

            if let largeFiles = r.largeFiles, !largeFiles.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    sectionHeader("Large files", subtitle: "\(largeFiles.count) found")

                    VStack(spacing: 0) {
                        ForEach(largeFiles.prefix(10)) { file in
                            largeFileRow(file)
                            if file.id != largeFiles.prefix(10).last?.id {
                                Rectangle()
                                    .fill(DesignTokens.Color.separatorLight)
                                    .frame(height: 1)
                                    .padding(.leading, 40)
                            }
                        }
                    }
                    .background(DesignTokens.Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                            .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
                    )
                }
            }
        }
        .padding(.horizontal, DesignTokens.Layout.contentHorizontalPadding)
        .padding(.vertical, DesignTokens.Spacing.xxl)
        .onAppear { withAnimation(DesignTokens.spring) { appear = true } }
    }

    private var analyzeSummaryCard: some View {
        guard let r = result else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.xl) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                                .fill(DesignTokens.Color.accentSoft)
                                .frame(width: 56, height: 56)
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(DesignTokens.Color.accentTint)
                        }

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Scan complete")
                                .font(DesignTokens.Font.section)
                                .foregroundStyle(DesignTokens.Color.primary)
                            Text("Found \(r.totalFiles) files across \(r.entries.count) top directories.")
                                .font(DesignTokens.Font.caption)
                                .foregroundStyle(DesignTokens.Color.secondary)
                        }
                    }

                    Spacer(minLength: DesignTokens.Spacing.lg)

                    VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxs) {
                        Text(r.totalSize.humanReadable)
                            .font(DesignTokens.Font.displayNumberLarge)
                            .foregroundStyle(DesignTokens.Color.primary)
                            .monospacedDigit()
                        Text("analyzed")
                            .font(DesignTokens.Font.labelUppercase)
                            .foregroundStyle(DesignTokens.Color.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Scanned path")
                        .font(DesignTokens.Font.labelUppercase)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                    Text(NSHomeDirectory())
                        .font(DesignTokens.Font.mono)
                        .foregroundStyle(DesignTokens.Color.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.Color.insetBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
            }
            .padding(DesignTokens.Layout.cardPadding)
            .background(DesignTokens.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge)
                    .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
            )
            .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
        )
    }

    private func entryRow(_ entry: DiskEntry, totalSize: UInt64) -> some View {
        let fraction = totalSize > 0 ? Double(entry.size) / Double(totalSize) : 0
        return VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: (entry.isDir ?? false) ? "folder.fill" : "doc.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle((entry.isDir ?? false) ? DesignTokens.Color.accentTint : DesignTokens.Color.tertiary)
                    .frame(width: 34, height: 34)
                    .background((entry.isDir ?? false) ? DesignTokens.Color.accentSoft : DesignTokens.Color.codeBg)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))

                Text(entry.name)
                    .font(DesignTokens.Font.bodyStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: DesignTokens.Spacing.md)

                Text(String(format: "%.1f%%", fraction * 100))
                    .font(DesignTokens.Font.mono)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                    .frame(width: 48, alignment: .trailing)

                Text(entry.size.humanReadable)
                    .font(DesignTokens.Font.monoBold)
                    .foregroundStyle(DesignTokens.Color.secondary)
                    .monospacedDigit()
                    .frame(width: 64, alignment: .trailing)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.top, DesignTokens.Spacing.md)

            MiniBar(value: fraction, color: DesignTokens.Color.accent)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.md)
        }
    }

    private func largeFileRow(_ file: DiskEntry) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "doc.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.tertiary)
                .frame(width: 28, height: 28)
                .background(DesignTokens.Color.codeBg)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))

            Text(file.name)
                .font(DesignTokens.Font.mono)
                .foregroundStyle(DesignTokens.Color.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(file.size.humanReadable)
                .font(DesignTokens.Font.monoBold)
                .foregroundStyle(DesignTokens.Color.secondary)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            FeatureLoadingView(
                icon: "chart.pie.fill",
                tint: DesignTokens.Color.accentTint,
                title: "Analyzing disk usage",
                subtitle: "Measuring what's taking up space in your home folder"
            )
            Text("This may take a few seconds for large home directories.")
                .font(DesignTokens.Font.captionStrong)
                .foregroundStyle(DesignTokens.Color.accentTint)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(DesignTokens.Color.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadAnalysis() async {
        isLoading = true; error = nil
        do { result = try await service.getAnalysis(path: NSHomeDirectory()) }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}

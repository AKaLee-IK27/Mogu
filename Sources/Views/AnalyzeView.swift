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
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
            }

            ScrollView {
                if isLoading { loadingView }
                else if let error { errorView(message: error) }
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
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Disk Analysis")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Visualize disk usage and find large files")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            if let r = result {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive.fill").font(.system(size: 10))
                    Text(r.totalSize.humanReadable)
                        .font(DesignTokens.Font.monoLarge)
                        .foregroundStyle(DesignTokens.Color.accentTint)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(DesignTokens.Color.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
            }
            HeaderIconButton(systemName: "arrow.clockwise", help: "Re-analyze", disabled: isLoading) {
                Task { await loadAnalysis() }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    private var shouldShowFullDiskAccessHint: Bool {
        switch permissions.status(for: .fullDiskAccess) {
        case .granted: return false
        case .notGranted, .promptsWhenNeeded, .unknown: return true
        }
    }

    private var fullDiskAccessHint: some View {
        HStack(spacing: 8) {
            Image(systemName: PermissionKind.fullDiskAccess.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DesignTokens.Color.tertiary)
            Text("Grant Full Disk Access to scan without per-folder prompts")
                .font(DesignTokens.Font.captionStrong)
                .foregroundStyle(DesignTokens.Color.secondary)
            Spacer(minLength: 0)
            if let settingsURL = PermissionKind.fullDiskAccess.settingsURL {
                Button {
                    openURL(settingsURL)
                } label: {
                    Text("Open Settings")
                        .font(DesignTokens.Font.label)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(DesignTokens.Color.accent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    }

    private func analysisContent(_ r: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Top Entries", subtitle: "\(r.totalFiles) files")
                .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(r.entries.enumerated()), id: \.element.id) { i, entry in
                    entryRow(entry, totalSize: r.totalSize)
                        .opacity(appear ? 1 : 0)
                        .offset(x: appear ? 0 : -8)
                        .animation(DesignTokens.stagger(i), value: appear)

                    if i < r.entries.count - 1 {
                        Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1).padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, 16)

            if let largeFiles = r.largeFiles, !largeFiles.isEmpty {
                sectionHeader("Large Files")
                    .padding(.horizontal, 32).padding(.top, 28).padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(largeFiles.prefix(10)) { file in
                        HStack(spacing: 10) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(DesignTokens.Color.tertiary)
                                .frame(width: 20)
                            Text(file.name)
                                .font(DesignTokens.Font.body)
                                .foregroundStyle(DesignTokens.Color.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(file.size.humanReadable)
                                .font(DesignTokens.Font.mono)
                                .foregroundStyle(DesignTokens.Color.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Summary footer
            HStack(spacing: 24) {
                summaryItem("Total Size", r.totalSize.humanReadable)
                summaryItem("Total Files", "\(r.totalFiles)")
                summaryItem("Path", r.path)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
        .padding(.bottom, 32)
        .onAppear { withAnimation(DesignTokens.spring) { appear = true } }
    }

    private func entryRow(_ entry: DiskEntry, totalSize: UInt64) -> some View {
        let fraction = totalSize > 0 ? Double(entry.size) / Double(totalSize) : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: (entry.isDir ?? false) ? "folder.fill" : "doc.fill")
                    .font(.system(size: 12))
                    .foregroundStyle((entry.isDir ?? false) ? DesignTokens.Color.accent : DesignTokens.Color.tertiary)
                    .frame(width: 20)

                Text(entry.name)
                    .font(DesignTokens.Font.bodyStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                    .lineLimit(1)

                Spacer()

                Text(entry.size.humanReadable)
                    .font(DesignTokens.Font.mono)
                    .foregroundStyle(DesignTokens.Color.secondary)

                Text(String(format: "%.1f%%", fraction * 100))
                    .font(DesignTokens.Font.mono)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            MiniBar(value: fraction, color: DesignTokens.Color.accent)
                .padding(.horizontal, 34)
                .padding(.bottom, 10)
        }
    }

    private func summaryItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(DesignTokens.Font.labelUppercase).foregroundStyle(DesignTokens.Color.tertiary)
            Text(value).font(DesignTokens.Font.mono)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2)
            Text("Analyzing disk usage...").font(DesignTokens.Font.body).foregroundStyle(DesignTokens.Color.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 24)).foregroundStyle(DesignTokens.Color.danger)
            Text(message).font(DesignTokens.Font.caption).foregroundStyle(DesignTokens.Color.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadAnalysis() async {
        isLoading = true; error = nil
        do { result = try await service.getAnalysis(path: NSHomeDirectory()) }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}

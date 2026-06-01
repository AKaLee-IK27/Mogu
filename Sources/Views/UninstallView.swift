import SwiftUI

struct UninstallView: View {
    let service: MoService
    @Binding var refreshTrigger: UUID
    @Binding var runTrigger: UUID
    @Binding var isLoading: Bool
    @State private var apps: [AppInfo] = []
    @State private var error: String?
    @State private var appear = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            ScrollView {
                if isLoading { loadingView }
                else if let error { ErrorStateView(message: error) { Task { await loadApps() } } }
                else if apps.isEmpty { emptyState }
                else { content }
            }
            .background(DesignTokens.Color.pageBackground)
        }
        .task { await loadApps() }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Task { await loadApps() }
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("App Uninstaller")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Browse installed apps with disk footprint")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            if !apps.isEmpty {
                InlineSearchField(text: $searchText, prompt: "Search apps")
                    .frame(width: 200)
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive.fill").font(.system(size: 10))
                    Text(totalAppsSize)
                        .font(DesignTokens.Font.monoLarge)
                        .foregroundStyle(DesignTokens.Color.accentTint)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(DesignTokens.Color.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
            }
            HeaderIconButton(systemName: "arrow.clockwise", help: "Re-scan", disabled: isLoading) {
                Task { await loadApps() }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    private var filteredApps: [AppInfo] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.bundleID?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Installed Apps", subtitle: "\(filteredApps.count) found")
                .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 12)

            uninstallNote
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            // Table header
            HStack {
                Text("Application").font(DesignTokens.Font.label).foregroundStyle(DesignTokens.Color.tertiary).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 32)
                Text("Size").font(DesignTokens.Font.label).foregroundStyle(DesignTokens.Color.tertiary).frame(width: 80, alignment: .trailing).padding(.trailing, 32)
            }.padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(filteredApps.enumerated()), id: \.element.id) { i, app in
                    appRow(app)
                        .opacity(appear ? 1 : 0)
                        .offset(x: appear ? 0 : -8)
                        .animation(DesignTokens.stagger(i), value: appear)

                    if i < filteredApps.count - 1 {
                        Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1).padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 32)
        .onAppear { withAnimation(DesignTokens.spring) { appear = true } }
    }

    private var uninstallNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Color.accent)
                .padding(.top, 1)
            Text("Uninstall is interactive. Run in Terminal for full removal. Browse mode shows app sizes here.")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    }

    private func appRow(_ app: AppInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "app.fill")
                .font(.system(size: 15))
                .foregroundStyle(DesignTokens.Color.tertiary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(DesignTokens.Font.bodyStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                if let bid = app.bundleID {
                    Text(bid).font(DesignTokens.Font.mono).foregroundStyle(DesignTokens.Color.tertiary)
                }
            }

            Spacer()

            Text(app.size.humanReadable)
                .font(DesignTokens.Font.mono)
                .foregroundStyle(DesignTokens.Color.tertiary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var totalAppsSize: String {
        apps.reduce(0) { $0 + $1.size }.humanReadable
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.app.fill")
                .font(.system(size: 28))
                .foregroundStyle(DesignTokens.Color.tertiary)
            Text("No apps found")
                .font(DesignTokens.Font.bodyStrong)
                .foregroundStyle(DesignTokens.Color.primary)
            Text("Mole did not detect any removable applications.")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2)
            Text("Scanning installed applications...").font(DesignTokens.Font.body).foregroundStyle(DesignTokens.Color.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadApps() async {
        isLoading = true
        error = nil
        appear = false
        apps.removeAll()
        do {
            let result = try await service.getUninstallList()
            apps = result.apps
            withAnimation(DesignTokens.spring) { appear = true }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

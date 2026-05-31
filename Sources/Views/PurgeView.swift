import SwiftUI

struct PurgeView: View {
    let service: MoService
    @Binding var refreshTrigger: UUID
    @Binding var isLoading: Bool
    @State private var projects: [PurgeProject] = []
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
                else if let error { errorView(message: error) }
                else if projects.isEmpty { emptyState }
                else { content }
            }
            .background(DesignTokens.Color.pageBackground)
        }
        .task { await loadProjects() }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Task { await loadProjects() }
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Project Artifacts")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Find node_modules, target, .build, and dist directories")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            if !projects.isEmpty {
                InlineSearchField(text: $searchText, prompt: "Search projects")
                    .frame(width: 200)
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill.badge.minus").font(.system(size: 10))
                    Text(totalArtifactsSize)
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
                Task { await loadProjects() }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    private var filteredProjects: [PurgeProject] {
        guard !searchText.isEmpty else { return projects }
        return projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.type.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Projects", subtitle: "\(filteredProjects.count) found")
                .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 12)

            purgeNote
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(filteredProjects.enumerated()), id: \.element.id) { i, project in
                    projectRow(project)
                        .opacity(appear ? 1 : 0)
                        .offset(x: appear ? 0 : -8)
                        .animation(DesignTokens.stagger(i), value: appear)

                    if i < filteredProjects.count - 1 {
                        Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1).padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 32)
        .onAppear { withAnimation(DesignTokens.spring) { appear = true } }
    }

    private var purgeNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Color.accent)
                .padding(.top, 1)
            Text("Purge scans ~/Repos, ~/dev, ~/Code, and other common project directories. Interactive cleanup requires Terminal.")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    }

    private func projectRow(_ project: PurgeProject) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 14))
                .foregroundStyle(DesignTokens.Color.tertiary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(DesignTokens.Font.bodyStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text(project.type)
                    .font(DesignTokens.Font.mono)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }

            Spacer()

            Text(project.size.humanReadable)
                .font(DesignTokens.Font.mono)
                .foregroundStyle(DesignTokens.Color.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var totalArtifactsSize: String {
        projects.reduce(0) { $0 + $1.size }.humanReadable
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 28))
                .foregroundStyle(DesignTokens.Color.successText)
            Text("No artifacts found")
                .font(DesignTokens.Font.bodyStrong)
                .foregroundStyle(DesignTokens.Color.primary)
            Text("Mole did not find any project build artifacts in the scanned directories.")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("Scanning project directories...").font(DesignTokens.Font.body).foregroundStyle(DesignTokens.Color.secondary)
            if !activity.isEmpty {
                ActivityFeed(lines: activity)
                    .padding(.horizontal, 32)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 40)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 24)).foregroundStyle(DesignTokens.Color.danger)
            Text(message).font(DesignTokens.Font.caption).foregroundStyle(DesignTokens.Color.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadProjects() async {
        isLoading = true
        error = nil
        appear = false
        projects.removeAll()
        activity.removeAll()
        var collected = ""
        for await event in service.stream(args: ["purge", "--dry-run", "--include-empty"]) {
            switch event {
            case .line(let l):
                collected += l + "\n"
                let t = l.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty {
                    activity.append(t)
                    if activity.count > 80 { activity.removeFirst(activity.count - 80) }
                }
            case .finished:
                // purge exits non-zero when nothing is found; treat as empty.
                let result = await service.purgeResult(fromText: collected)
                projects = result.projects
            case .error(let m):
                error = m
            }
        }
        withAnimation(DesignTokens.spring) { appear = true }
        isLoading = false
    }
}

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
                else if let error { ErrorStateView(message: error) { Task { await loadProjects() } } }
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
        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Purge")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Scan for node_modules, target, .build, and dist directories")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            if !projects.isEmpty {
                InlineSearchField(text: $searchText, prompt: "Search projects")
                    .frame(width: 200)
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "folder.fill.badge.minus")
                        .font(.system(size: 11, weight: .semibold))
                    Text(totalArtifactsSize)
                        .font(DesignTokens.Font.monoBold)
                        .monospacedDigit()
                }
                .foregroundStyle(DesignTokens.Color.accentTint)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(DesignTokens.Color.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
            }
            HeaderIconButton(systemName: "arrow.clockwise", help: "Re-scan", disabled: isLoading) {
                Task { await loadProjects() }
            }
        }
        .padding(.horizontal, DesignTokens.Layout.headerHorizontalPadding)
        .padding(.vertical, DesignTokens.Layout.headerVerticalPadding)
    }

    private var filteredProjects: [PurgeProject] {
        guard !searchText.isEmpty else { return projects }
        return projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.type.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            purgeSummaryCard
            purgeNote

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                sectionHeader("Projects", subtitle: "\(filteredProjects.count) found")

                VStack(spacing: 0) {
                    ForEach(Array(filteredProjects.enumerated()), id: \.element.id) { i, project in
                        projectRow(project)
                            .opacity(appear ? 1 : 0)
                            .offset(x: appear ? 0 : -8)
                            .animation(DesignTokens.stagger(i), value: appear)

                        if i < filteredProjects.count - 1 {
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
        }
        .padding(.horizontal, DesignTokens.Layout.contentHorizontalPadding)
        .padding(.vertical, DesignTokens.Spacing.xxl)
        .onAppear { withAnimation(DesignTokens.spring) { appear = true } }
    }

    private var purgeSummaryCard: some View {
        guard !projects.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.xl) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                                .fill(DesignTokens.Color.purgeAccent.opacity(0.12))
                                .frame(width: 56, height: 56)
                            Image(systemName: "folder.fill.badge.minus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(DesignTokens.Color.purgeAccent)
                        }

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Read-only artifact scan")
                                .font(DesignTokens.Font.section)
                                .foregroundStyle(DesignTokens.Color.primary)
                            Text("Found \(projects.count) projects with build caches and dependency folders.")
                                .font(DesignTokens.Font.caption)
                                .foregroundStyle(DesignTokens.Color.secondary)
                        }
                    }

                    Spacer(minLength: DesignTokens.Spacing.lg)

                    VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxs) {
                        Text(totalArtifactsSize)
                            .font(DesignTokens.Font.displayNumberLarge)
                            .foregroundStyle(DesignTokens.Color.primary)
                            .monospacedDigit()
                        Text("total artifacts")
                            .font(DesignTokens.Font.labelUppercase)
                            .foregroundStyle(DesignTokens.Color.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Scanned paths")
                        .font(DesignTokens.Font.labelUppercase)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                    Text("~/Repos, ~/dev, ~/Code, ~/Projects, and other common directories")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
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

    private var purgeNote: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.purgeAccent)
                .frame(width: 28, height: 28)
                .background(DesignTokens.Color.purgeAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text("Terminal required for cleanup")
                    .font(DesignTokens.Font.captionStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Purge is a read-only scan. For interactive cleanup, run `mo purge` in Terminal with the flags you need.")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Color.insetBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
        )
    }

    private func projectRow(_ project: PurgeProject) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "folder.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.purgeAccent)
                .frame(width: 34, height: 34)
                .background(DesignTokens.Color.purgeAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(project.name)
                    .font(DesignTokens.Font.bodyStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(project.type)
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DesignTokens.Color.codeBg)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
            }

            Spacer(minLength: DesignTokens.Spacing.md)

            Text(project.size.humanReadable)
                .font(DesignTokens.Font.monoBold)
                .foregroundStyle(DesignTokens.Color.secondary)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var totalArtifactsSize: String {
        projects.reduce(0) { $0 + $1.size }.humanReadable
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.successText)
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("No build artifacts found")
                    .font(DesignTokens.Font.section)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Mole did not find any project build caches or dependency folders in the scanned directories.")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignTokens.Spacing.xxxl)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge)
                .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
        )
        .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
    }

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            FeatureLoadingView(
                icon: "folder.fill.badge.minus",
                tint: DesignTokens.Color.purgeAccent,
                title: "Scanning project directories",
                subtitle: "Finding build caches and dependency folders"
            )
            if !activity.isEmpty {
                ActivityFeed(lines: activity, visible: 8)
                    .padding(.horizontal, DesignTokens.Layout.contentHorizontalPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
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

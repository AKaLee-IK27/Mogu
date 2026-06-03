import SwiftUI

struct CleanView: View {
    let service: MoService
    @ObservedObject var permissions: PermissionsService
    @Binding var refreshTrigger: UUID
    @Binding var runTrigger: UUID
    @Binding var isLoading: Bool
    @Binding var isRunning: Bool
    @Binding var hasData: Bool
    @State private var categories: [CleanCategory] = []
    @State private var error: String?
    @State private var resultMessage: String?
    @State private var appear = false
    @State private var activity: [String] = []
    @State private var foundCount = 0
    @State private var runningMessage = "Cleaning in progress..."
    @State private var systemCleanAvailable = false
    @State private var systemCleanPreviewReady = false
    @State private var systemCleanPreviewLines: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            PreflightBanner(item: .clean, permissions: permissions)
                .padding(.horizontal, 32)
                .padding(.top, 12)
                .padding(.bottom, 16)

            ScrollView {
                if isLoading {
                    loadingView
                } else if let error {
                    ErrorStateView(message: error) { Task { await loadPreview() } }
                } else if isRunning {
                    runningView
                } else {
                    content
                }
            }
            .background(DesignTokens.Color.pageBackground)
        }
        .task { await loadPreview() }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Task { await loadPreview() }
        }
        .onChange(of: runTrigger) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Task { await cleanAllAdminFirst() }
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Clean")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Preview cache, log, and leftover data before anything is removed")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            if hasData {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Previewed")
                        .font(DesignTokens.Font.captionStrong)
                    Text(totalCleanableSize)
                        .font(DesignTokens.Font.monoBold)
                        .monospacedDigit()
                }
                .foregroundStyle(DesignTokens.Color.accentTint)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(DesignTokens.Color.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
            }
            HeaderIconButton(systemName: "arrow.clockwise", help: "Re-scan", disabled: isLoading || isRunning) {
                Task { await loadPreview() }
            }
            // Clean All stays disabled until a preview has loaded — enforces the
            // app's preview-before-delete invariant — and while the granted
            // system-confirm card is showing (use that card's button instead).
            HeaderActionButton(label: "Clean All", systemName: "sparkles",
                               disabled: isLoading || isRunning || !hasData || systemCleanAvailable) {
                Task { await cleanAllAdminFirst() }
            }
        }
        .padding(.horizontal, DesignTokens.Layout.headerHorizontalPadding)
        .padding(.vertical, DesignTokens.Layout.headerVerticalPadding)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            if categories.isEmpty && resultMessage == nil {
                emptyState
            } else {
                if !categories.isEmpty {
                    previewSummaryCard
                    previewNote

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        sectionHeader("Read-only cleanup preview", subtitle: "\(categories.count) categories")

                        VStack(spacing: 0) {
                            ForEach(Array(categories.enumerated()), id: \.element.id) { i, category in
                                CleanCategoryRow(category: category, maxSize: maxCategorySize)
                                    .opacity(appear ? 1 : 0)
                                    .offset(x: appear ? 0 : -8)
                                    .animation(DesignTokens.stagger(i), value: appear)

                                if i < categories.count - 1 {
                                    Rectangle()
                                        .fill(DesignTokens.Color.separatorLight)
                                        .frame(height: 1)
                                        .padding(.leading, 64)
                                }
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(DesignTokens.Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                                .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
                        )
                        .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
                    }
                }

                if resultMessage != nil {
                    resultBanner
                }

                if systemCleanAvailable {
                    systemCleanCard
                }
            }
        }
        .padding(.horizontal, DesignTokens.Layout.contentHorizontalPadding)
        .padding(.vertical, DesignTokens.Spacing.xxl)
        .onAppear { withAnimation(DesignTokens.spring) { appear = true } }
    }

    private var previewSummaryCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.xl) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                            .fill(DesignTokens.Color.accentSoft)
                            .frame(width: 56, height: 56)
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(DesignTokens.Color.accentTint)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Cleanup preview ready")
                            .font(DesignTokens.Font.section)
                            .foregroundStyle(DesignTokens.Color.primary)
                        Text("Mole found data that can be removed after confirmation.")
                            .font(DesignTokens.Font.caption)
                            .foregroundStyle(DesignTokens.Color.secondary)
                    }
                }

                Spacer(minLength: DesignTokens.Spacing.lg)

                VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxs) {
                    Text(totalCleanableSize)
                        .font(DesignTokens.Font.displayNumberLarge)
                        .foregroundStyle(DesignTokens.Color.primary)
                        .monospacedDigit()
                    Text("previewed cleanable data")
                        .font(DesignTokens.Font.labelUppercase)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                }
            }

            HStack(spacing: DesignTokens.Spacing.md) {
                CleanSummaryMetric(title: "Categories", value: "\(categories.count)", systemName: "square.grid.2x2.fill", tint: DesignTokens.Color.accent)
                CleanSummaryMetric(title: "Locations", value: "\(previewedLocationCount)", systemName: "folder.fill", tint: DesignTokens.Color.successText)
                CleanSummaryMetric(title: "Largest", value: largestCategory?.name ?? "None", systemName: "arrow.up.right.square.fill", tint: DesignTokens.Color.warningText)
            }
        }
        .padding(DesignTokens.Layout.cardPadding)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge)
                .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
        )
        .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
    }

    private var previewNote: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.accentTint)
                .frame(width: 28, height: 28)
                .background(DesignTokens.Color.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text("Safety contract")
                    .font(DesignTokens.Font.captionStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Cleaning runs across the full preview shown below. Category rows are inspection-only because this Mole runtime does not support category-level cleaning.")
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

    private var maxCategorySize: UInt64 {
        categories.map(\.size).max() ?? 0
    }

    private var runningView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            VStack(spacing: DesignTokens.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.3)
                Text(runningMessage)
                    .font(DesignTokens.Font.bodyStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Mogu is streaming Mole output so you can see the cleanup progress.")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.secondary)
            }
            .padding(DesignTokens.Layout.cardPadding)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge)
                    .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
            )

            if !activity.isEmpty {
                ActivityFeed(lines: activity)
            }
        }
        .padding(.horizontal, DesignTokens.Layout.contentHorizontalPadding)
        .padding(.vertical, 60)
    }

    private var resultBanner: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.successText)
            Text(resultMessage ?? "Cleanup completed")
                .font(DesignTokens.Font.bodyStrong)
                .foregroundStyle(DesignTokens.Color.primary)
            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Color.successSoft)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                .stroke(DesignTokens.Color.successText.opacity(0.18), lineWidth: DesignTokens.Stroke.hairline)
        )
    }

    // Shown after admin is granted up front: the system-level dry-run preview,
    // with one confirm that cleans user-owned and system items together.
    private var systemCleanCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.warningText)
                    .frame(width: 36, height: 36)
                    .background(DesignTokens.Color.warningSoft)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text("System-level cleanup ready")
                            .font(DesignTokens.Font.section)
                            .foregroundStyle(DesignTokens.Color.primary)
                        Text("Admin previewed")
                            .font(DesignTokens.Font.labelUppercase)
                            .foregroundStyle(DesignTokens.Color.warningText)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Color.warningSoft)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
                    }
                    Text("Administrator access was granted for the elevated dry-run. Review the system output, then confirm the combined user-owned and system cleanup.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if !systemCleanPreviewLines.isEmpty {
                ActivityFeed(lines: systemCleanPreviewLines, visible: 10)
            }

            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Text("Runs user-owned cleanup first, then elevated system cleanup.")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.secondary)
                Spacer()
                Button {
                    Task { await runFullClean() }
                } label: {
                    Label("Clean user + system items", systemImage: "sparkles")
                        .font(DesignTokens.Font.bodyStrong)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.Color.warning)
                .disabled(isRunning)
            }
        }
        .padding(DesignTokens.Layout.cardPadding)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge)
                .stroke(DesignTokens.Color.warningText.opacity(0.22), lineWidth: DesignTokens.Stroke.hairline)
        )
        .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
    }

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            FeatureLoadingView(
                icon: "sparkles",
                tint: DesignTokens.Color.successText,
                title: "Building cleanup preview",
                subtitle: "Scanning caches, logs, and leftover app data before cleanup is enabled"
            )
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                Text(foundCount > 0 ? "Found \(foundCount) location\(foundCount == 1 ? "" : "s")…" : "Starting dry-run scan…")
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .font(DesignTokens.Font.captionStrong)
            .foregroundStyle(DesignTokens.Color.successText)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Color.successSoft)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
            .animation(DesignTokens.ease, value: foundCount)

            if !activity.isEmpty {
                ActivityFeed(lines: activity, visible: 8)
                    .padding(.horizontal, DesignTokens.Layout.contentHorizontalPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.successText)
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("Preview complete, nothing to clean")
                    .font(DesignTokens.Font.section)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Mole did not find cleanable cache, log, or leftover app data in the latest dry-run preview.")
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

    private var totalCleanableBytes: UInt64 {
        categories.reduce(0) { $0 + $1.size }
    }

    private var previewedLocationCount: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }

    private var largestCategory: CleanCategory? {
        categories.max { $0.size < $1.size }
    }

    private var totalCleanableSize: String {
        totalCleanableBytes.humanReadable
    }

    private func loadPreview() async {
        isLoading = true
        error = nil
        resultMessage = nil
        appear = false
        categories.removeAll()
        activity.removeAll()
        foundCount = 0
        resetSystemCleanEscalation()
        hasData = false
        await service.resetCleanPreview()
        for await event in service.stream(args: ["clean", "--dry-run"]) {
            switch event {
            case .line(let l):
                let t = l.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty {
                    activity.append(t)
                    if activity.count > 80 { activity.removeFirst(activity.count - 80) }
                    if MoOutputParser.isCleanScanFinding(t) { foundCount += 1 }
                }
            case .finished(let code):
                if code == 0 {
                    let result = await service.finalizeCleanPreview()
                    categories = result.categories
                    hasData = !categories.isEmpty
                } else {
                    error = "Cleanup preview failed (exit \(code))."
                }
            case .error(let m):
                error = m
            }
        }
        withAnimation(DesignTokens.spring) { appear = true }
        isLoading = false
    }

    private func appendActivity(_ line: String, limit: Int = 200) {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        activity.append(t)
        if activity.count > limit { activity.removeFirst(activity.count - limit) }
    }

    private func resetSystemCleanEscalation() {
        systemCleanAvailable = false
        systemCleanPreviewReady = false
        systemCleanPreviewLines.removeAll()
    }

    // Admin-first cleanup: when the user starts a clean, ask for the administrator
    // password up front (via the elevated dry-run). Granted → preview system items
    // and let the user confirm a combined user+system clean. Cancelled/declined →
    // clean user-owned items only. Preview-before-delete holds at both tiers
    // (`cleanPreviewIsReady` for user items, `systemCleanPreviewReady` for system).
    private func cleanAllAdminFirst() async {
        guard await service.cleanPreviewIsReady() else {
            error = "Run a cleanup preview before cleaning."
            return
        }
        resetSystemCleanEscalation()
        // Up-front admin prompt + system-level dry-run.
        await previewElevatedClean()
        if systemCleanPreviewReady {
            // Granted — surface the system preview and wait for explicit confirm.
            systemCleanAvailable = true
        } else {
            // Declined / unavailable — fall back to user-owned cleanup only.
            error = nil
            if await streamUserClean() {
                resultMessage = "Cleaned user-owned items. System items were skipped (admin not granted)."
                categories.removeAll()
                hasData = false
            }
        }
    }

    // Confirmed combined clean: user-owned items (unprivileged) then system items
    // (elevated). Runs only after the up-front elevated preview succeeded.
    private func runFullClean() async {
        guard systemCleanPreviewReady else {
            error = "Preview system-level cleanup before cleaning."
            return
        }
        guard await streamUserClean() else { return }
        await runElevatedClean()
    }

    // Unprivileged clean of user-owned items. Returns whether it succeeded.
    // Leaves escalation state untouched so a follow-on elevated clean can run.
    @discardableResult
    private func streamUserClean() async -> Bool {
        isRunning = true
        runningMessage = "Cleaning user-owned items..."
        error = nil
        resultMessage = nil
        activity.removeAll()
        var ok = false
        for await event in service.stream(args: ["clean"]) {
            switch event {
            case .line(let l):
                appendActivity(l)
            case .finished(let code):
                if code == 0 { ok = true }
                else if error == nil { error = "Cleanup failed (exit \(code))." }
            case .error(let m):
                error = m
            }
        }
        runningMessage = "Cleaning in progress..."
        isRunning = false
        return ok
    }

    private func previewElevatedClean() async {
        isRunning = true
        runningMessage = "Previewing system-level cleanup..."
        error = nil
        resultMessage = nil
        activity.removeAll()
        systemCleanPreviewReady = false
        systemCleanPreviewLines.removeAll()
        for await event in service.streamElevated(args: ["clean", "--dry-run"]) {
            switch event {
            case .line(let l):
                appendActivity(l)
                let t = l.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty {
                    systemCleanPreviewLines.append(t)
                    if systemCleanPreviewLines.count > 200 {
                        systemCleanPreviewLines.removeFirst(systemCleanPreviewLines.count - 200)
                    }
                }
            case .finished(let code):
                if code == 0 {
                    systemCleanPreviewReady = true
                    resultMessage = "System-level cleanup preview ready. Review it before cleaning."
                } else if error == nil {
                    error = "System-level cleanup preview failed (exit \(code))."
                }
            case .error(let m):
                error = m
            }
        }
        runningMessage = "Cleaning in progress..."
        isRunning = false
    }

    private func runElevatedClean() async {
        guard systemCleanPreviewReady else {
            error = "Preview system-level cleanup before cleaning."
            return
        }
        isRunning = true
        runningMessage = "Cleaning system-level items..."
        error = nil
        resultMessage = nil
        activity.removeAll()
        for await event in service.streamElevated(args: ["clean"]) {
            switch event {
            case .line(let l):
                appendActivity(l)
            case .finished(let code):
                if code == 0 {
                    resultMessage = "System-level cleanup completed"
                    resetSystemCleanEscalation()
                } else if error == nil {
                    error = "System-level cleanup failed (exit \(code))."
                }
            case .error(let m):
                error = m
            }
        }
        runningMessage = "Cleaning in progress..."
        isRunning = false
    }
}

private struct CleanSummaryMetric: View {
    let title: String
    let value: String
    let systemName: String
    let tint: SwiftUI.Color

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .font(DesignTokens.Font.labelUppercase)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                Text(value)
                    .font(DesignTokens.Font.captionStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Color.insetBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
    }
}

// One top-level cleanup category: a tappable header (icon, name, size, a
// relative size bar) that expands to reveal the real locations Mole found
// inside it. Read-only by design — Mole cleans the whole preview, so this is
// a transparency/inspect affordance, not a per-item selector.
private struct CleanCategoryRow: View {
    let category: CleanCategory
    let maxSize: UInt64
    @State private var expanded = false

    private var fraction: Double {
        maxSize > 0 ? min(1, Double(category.size) / Double(maxSize)) : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(DesignTokens.spring) { expanded.toggle() }
            } label: {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignTokens.Color.tertiary)
                        .frame(width: 12)
                        .rotationEffect(.degrees(expanded ? 90 : 0))

                    Image(systemName: Self.icon(for: category.name))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignTokens.Color.accentTint)
                        .frame(width: 34, height: 34)
                        .background(DesignTokens.Color.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Text(category.name)
                                .font(DesignTokens.Font.bodyStrong)
                                .foregroundStyle(DesignTokens.Color.primary)
                            Text("\(category.items.count) location\(category.items.count == 1 ? "" : "s")")
                                .font(DesignTokens.Font.caption)
                                .foregroundStyle(DesignTokens.Color.tertiary)
                                .monospacedDigit()
                                .padding(.horizontal, DesignTokens.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(DesignTokens.Color.codeBg)
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
                            Spacer(minLength: DesignTokens.Spacing.sm)
                            Text(category.size.humanReadable)
                                .font(DesignTokens.Font.monoBold)
                                .foregroundStyle(DesignTokens.Color.primary)
                                .monospacedDigit()
                        }
                        sizeBar
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 0) {
                    // Offset-keyed (not path-keyed): guards against a duplicate
                    // path within one section colliding ForEach IDs.
                    ForEach(Array(category.items.enumerated()), id: \.offset) { _, item in
                        itemRow(item)
                    }
                }
                .padding(.bottom, DesignTokens.Spacing.sm)
                .background(DesignTokens.Color.insetBackground.opacity(0.55))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var sizeBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DesignTokens.Color.separatorLight)
                Capsule()
                    .fill(DesignTokens.Color.accent.opacity(0.55))
                    .frame(width: max(4, geo.size.width * fraction))
            }
        }
        .frame(height: 4)
    }

    private func itemRow(_ item: CleanItem) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "circle.fill")
                .font(.system(size: 3))
                .foregroundStyle(DesignTokens.Color.placeholder)
            Text(Self.friendlyPath(item.path))
                .font(DesignTokens.Font.mono)
                .foregroundStyle(DesignTokens.Color.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: DesignTokens.Spacing.md)
            if let count = item.itemCount {
                Text("\(count) item\(count == 1 ? "" : "s")")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.placeholder)
                    .monospacedDigit()
            }
            Text(item.size.humanReadable)
                .font(DesignTokens.Font.monoBold)
                .foregroundStyle(DesignTokens.Color.tertiary)
                .monospacedDigit()
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.leading, 70)
        .padding(.trailing, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    // Replace the home prefix with ~ so paths read short and don't leak the
    // username. Middle truncation in the view handles anything still too long.
    static func friendlyPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    static func icon(for section: String) -> String {
        let s = section.lowercased()
        if s.contains("browser") { return "globe" }
        if s.contains("develop") { return "hammer.fill" }
        if s.contains("cloud") || s.contains("office") { return "cloud.fill" }
        if s.contains("system") { return "gearshape.fill" }
        if s.contains("essential") || s.contains("user") { return "person.crop.circle.fill" }
        if s.contains("log") { return "doc.text.fill" }
        return "shippingbox.fill"
    }
}

func sectionHeader(_ title: String, subtitle: String? = nil) -> some View {
    HStack(spacing: DesignTokens.Spacing.sm) {
        Text(title)
            .font(DesignTokens.Font.labelUppercase)
            .foregroundStyle(DesignTokens.Color.secondary)
        if let subtitle {
            Text(subtitle)
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.tertiary)
        }
        Spacer()
    }
}

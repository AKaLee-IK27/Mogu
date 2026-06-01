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
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Deep Cleanup")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Preview caches, logs, and orphaned app data before cleaning")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            if !categories.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 10))
                    Text(totalCleanableSize)
                        .font(DesignTokens.Font.monoLarge)
                        .foregroundStyle(DesignTokens.Color.accentTint)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if categories.isEmpty && resultMessage == nil {
                emptyState
            } else {
                if !categories.isEmpty {
                    sectionHeader("Previewed cleanup", subtitle: "\(categories.count) categories")
                        .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 8)

                    previewNote
                        .padding(.horizontal, 32)
                        .padding(.bottom, 12)

                    VStack(spacing: 0) {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { i, category in
                            CleanCategoryRow(category: category, maxSize: maxCategorySize)
                                .opacity(appear ? 1 : 0)
                                .offset(x: appear ? 0 : -8)
                                .animation(DesignTokens.stagger(i), value: appear)

                            if i < categories.count - 1 {
                                Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1).padding(.leading, 48)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .background(DesignTokens.Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
                    .padding(.horizontal, 16)
                }

                if resultMessage != nil {
                    resultBanner
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                }

                if systemCleanAvailable {
                    systemCleanCard
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                }
            }
        }
        .padding(.bottom, 32)
        .onAppear { withAnimation(DesignTokens.spring) { appear = true } }
    }

    private var previewNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Color.accent)
                .padding(.top, 1)
            Text("Cleaning runs across the full preview shown below. Category-level cleaning is not supported by this bundled Mole runtime.")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    }

    private var maxCategorySize: UInt64 {
        categories.map(\.size).max() ?? 0
    }

    private var runningView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.3)
            Text(runningMessage).font(DesignTokens.Font.bodyStrong).foregroundStyle(DesignTokens.Color.secondary)
            if !activity.isEmpty {
                ActivityFeed(lines: activity)
                    .padding(.horizontal, 32)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private var resultBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(DesignTokens.Color.successText)
            Text(resultMessage ?? "Cleanup completed").font(DesignTokens.Font.bodyStrong)
            Spacer()
        }
        .padding(12)
        .background(DesignTokens.Color.successSoft)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    }

    // Shown after admin is granted up front: the system-level dry-run preview,
    // with one confirm that cleans user-owned and system items together.
    private var systemCleanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignTokens.Color.warning)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("System-level cleanup ready")
                        .font(DesignTokens.Font.bodyStrong)
                        .foregroundStyle(DesignTokens.Color.primary)
                    Text("Administrator access granted. Review the system items below, then clean user-owned and system items together.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                }
                Spacer()
            }

            if !systemCleanPreviewLines.isEmpty {
                ActivityFeed(lines: systemCleanPreviewLines, visible: 10)
            }

            HStack {
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
        .padding(14)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            FeatureLoadingView(
                icon: "sparkles",
                tint: DesignTokens.Color.successText,
                title: "Scanning for cleanable data",
                subtitle: "Looking through caches, logs, and leftover app data"
            )
            Text(foundCount > 0 ? "Found \(foundCount) location\(foundCount == 1 ? "" : "s")…" : "Starting scan…")
                .font(DesignTokens.Font.captionStrong)
                .foregroundStyle(DesignTokens.Color.successText)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(DesignTokens.ease, value: foundCount)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 28))
                .foregroundStyle(DesignTokens.Color.successText)
            Text("Nothing to clean")
                .font(DesignTokens.Font.bodyStrong)
                .foregroundStyle(DesignTokens.Color.primary)
            Text("Mole did not find any cleanable cache or log data in the latest preview.")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var totalCleanableSize: String {
        categories.reduce(0) { $0 + $1.size }.humanReadable
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
                HStack(spacing: 12) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignTokens.Color.tertiary)
                        .frame(width: 12)
                        .rotationEffect(.degrees(expanded ? 90 : 0))

                    Image(systemName: Self.icon(for: category.name))
                        .font(.system(size: 15))
                        .foregroundStyle(DesignTokens.Color.accent)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(category.name)
                                .font(DesignTokens.Font.bodyStrong)
                                .foregroundStyle(DesignTokens.Color.primary)
                            Text("\(category.items.count)")
                                .font(DesignTokens.Font.caption)
                                .foregroundStyle(DesignTokens.Color.tertiary)
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(DesignTokens.Color.codeBg)
                                .clipShape(Capsule())
                            Spacer(minLength: 8)
                            Text(category.size.humanReadable)
                                .font(DesignTokens.Font.monoBold)
                                .foregroundStyle(DesignTokens.Color.secondary)
                                .monospacedDigit()
                        }
                        sizeBar
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
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
                .padding(.bottom, 6)
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
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 3))
                .foregroundStyle(DesignTokens.Color.placeholder)
            Text(Self.friendlyPath(item.path))
                .font(DesignTokens.Font.mono)
                .foregroundStyle(DesignTokens.Color.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 12)
            if let count = item.itemCount {
                Text("\(count) item\(count == 1 ? "" : "s")")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.placeholder)
                    .monospacedDigit()
            }
            Text(item.size.humanReadable)
                .font(DesignTokens.Font.mono)
                .foregroundStyle(DesignTokens.Color.tertiary)
                .monospacedDigit()
                .frame(minWidth: 56, alignment: .trailing)
        }
        .padding(.leading, 50)
        .padding(.trailing, 16)
        .padding(.vertical, 5)
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
    HStack(spacing: 8) {
        Text(title)
            .font(DesignTokens.Font.labelUppercase)
            .foregroundStyle(DesignTokens.Color.secondary)
        if let subtitle {
            Text(subtitle)
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
        }
        Spacer()
    }
}

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

    // Column-header sort (Finder-style): tap a header to sort by it, tap again to
    // flip direction. Defaults to size-descending — biggest space hogs first.
    private enum SortField { case name, size }
    @State private var sortField: SortField = .size
    @State private var sortAscending = false

    // Multi-select batch uninstall. Selection is keyed by the unique bundle path
    // (display names can collide, e.g. two "Numbers"), tracked globally so a
    // search filter only changes what's shown, not what's selected.
    @State private var selected: Set<String> = []
    @State private var isPreviewing = false
    @State private var isRunning = false
    @State private var showConfirm = false
    @State private var preview: UninstallPreview?
    @State private var pendingNames: [String] = []
    @State private var activity: [String] = []
    @State private var runningMessage = "Uninstalling…"
    @State private var resultMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            ScrollView {
                if isLoading { loadingView }
                else if isPreviewing { previewingView }
                else if isRunning { runningView }
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
        .sheet(isPresented: $showConfirm) { confirmSheet }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("App Uninstaller")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Select apps to remove them and their leftover files")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            if !apps.isEmpty && selected.isEmpty {
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
            if !selected.isEmpty {
                Text("\(selected.count) selected · \(selectedSize.humanReadable)")
                    .font(DesignTokens.Font.captionStrong)
                    .foregroundStyle(DesignTokens.Color.secondary)
                    .monospacedDigit()
                Button("Clear") { selected.removeAll() }
                    .buttonStyle(.plain)
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.accent)
                HeaderActionButton(label: "Uninstall", systemName: "trash",
                                   tint: DesignTokens.Color.dangerText,
                                   disabled: isPreviewing || isRunning) {
                    Task { await startPreview() }
                }
            }
            HeaderIconButton(systemName: "arrow.clockwise", help: "Re-scan",
                             disabled: isLoading || isPreviewing || isRunning) {
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

    // The displayed order: filter, then sort by the active column. Size ties break
    // by name so equal-size rows stay alphabetical rather than jittering.
    private var sortedApps: [AppInfo] {
        let asc = sortAscending
        return filteredApps.sorted { a, b in
            switch sortField {
            case .name:
                let cmp = a.name.localizedCaseInsensitiveCompare(b.name)
                return asc ? cmp == .orderedAscending : cmp == .orderedDescending
            case .size:
                if a.size != b.size { return asc ? a.size < b.size : a.size > b.size }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }
    }

    // Selectable apps in the current filter (admin-required ones are excluded —
    // see requiresAdmin). Drives the "select all" header toggle.
    private var eligibleKeys: [String] {
        filteredApps.filter { !$0.requiresAdmin }.map(rowKey)
    }
    private var allEligibleSelected: Bool {
        !eligibleKeys.isEmpty && eligibleKeys.allSatisfy { selected.contains($0) }
    }
    private var selectedApps: [AppInfo] {
        apps.filter { selected.contains(rowKey($0)) }
    }
    private var selectedSize: UInt64 {
        selectedApps.reduce(0) { $0 + $1.size }
    }

    private func rowKey(_ app: AppInfo) -> String { app.path ?? app.name }

    // A sortable column header: label + a direction chevron shown only on the
    // active column. Tap to sort by this field; tap the active one to flip.
    private func sortHeader(_ title: String, field: SortField, alignment: Alignment) -> some View {
        let active = sortField == field
        return Button {
            if active {
                sortAscending.toggle()
            } else {
                sortField = field
                sortAscending = (field == .name) // names default A→Z, sizes default large→small
            }
        } label: {
            HStack(spacing: 4) {
                if alignment == .trailing { Spacer(minLength: 0) }
                Text(title)
                    .font(DesignTokens.Font.label)
                    .foregroundStyle(active ? DesignTokens.Color.accent : DesignTokens.Color.tertiary)
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DesignTokens.Color.accent)
                    .opacity(active ? 1 : 0) // reserve space so the row never shifts
                if alignment == .leading { Spacer(minLength: 0) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Sort by \(title.lowercased())")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Installed Apps", subtitle: "\(filteredApps.count) found")
                .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 12)

            uninstallNote
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            if let resultMessage {
                resultBanner(resultMessage)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)
            }

            // Table header with a select-all-eligible toggle.
            HStack(spacing: 12) {
                Button { toggleSelectAll() } label: {
                    Image(systemName: allEligibleSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundStyle(allEligibleSelected ? DesignTokens.Color.accent : DesignTokens.Color.tertiary)
                }
                .buttonStyle(.plain)
                .disabled(eligibleKeys.isEmpty)
                .help("Select all eligible apps")
                .frame(width: 22)
                sortHeader("Application", field: .name, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                sortHeader("Size", field: .size, alignment: .trailing)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.leading, 32).padding(.trailing, 32).padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(sortedApps.enumerated()), id: \.offset) { i, app in
                    appRow(app)
                        .opacity(appear ? 1 : 0)
                        .offset(x: appear ? 0 : -8)
                        .animation(DesignTokens.stagger(i), value: appear)

                    if i < sortedApps.count - 1 {
                        Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1).padding(.leading, 70)
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
            Image(systemName: "arrow.uturn.backward.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Color.accent)
                .padding(.top, 1)
            Text("Selected apps and their leftover files move to the Trash, so you can restore them. Apps marked Admin are owned by the system or installed via Homebrew — remove those from Terminal with `mo uninstall`.")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    }

    private func appRow(_ app: AppInfo) -> some View {
        let key = rowKey(app)
        let isSelected = selected.contains(key)
        return HStack(spacing: 12) {
            // Selection control, or a lock for admin-required apps.
            Group {
                if app.requiresAdmin {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.Color.tertiary)
                        .help("Requires administrator — remove from Terminal: mo uninstall \"\(app.name)\"")
                } else {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 15))
                        .foregroundStyle(isSelected ? DesignTokens.Color.accent : DesignTokens.Color.tertiary)
                }
            }
            .frame(width: 22)

            Image(systemName: "app.fill")
                .font(.system(size: 15))
                .foregroundStyle(DesignTokens.Color.tertiary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(DesignTokens.Font.bodyStrong)
                        .foregroundStyle(DesignTokens.Color.primary)
                    if app.requiresAdmin { adminBadge }
                }
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
        .opacity(app.requiresAdmin ? 0.6 : 1)
        .background(isSelected ? DesignTokens.Color.accentSoft : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .onTapGesture { if !app.requiresAdmin { toggle(key) } }
    }

    private var adminBadge: some View {
        Text("Admin")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(DesignTokens.Color.warning)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(DesignTokens.Color.warningSoft)
            .clipShape(Capsule())
    }

    private func resultBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(DesignTokens.Color.successText)
            Text(message).font(DesignTokens.Font.bodyStrong)
            Spacer()
        }
        .padding(12)
        .background(DesignTokens.Color.successSoft)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    }

    private var totalAppsSize: String {
        apps.reduce(0) { $0 + $1.size }.humanReadable
    }

    // MARK: - Confirmation sheet

    private var confirmSheet: some View {
        let preview = preview ?? UninstallPreview(apps: [], totalSize: 0)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.dangerText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preview.apps.count == 1 ? "Uninstall 1 app?" : "Uninstall \(preview.apps.count) apps?")
                        .font(DesignTokens.Font.section)
                        .foregroundStyle(DesignTokens.Color.primary)
                    Text("These items move to the Trash — about \(preview.totalSize.humanReadable). You can restore them from Trash.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                }
                Spacer()
            }
            .padding(20)

            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(preview.apps) { app in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(app.name)
                                    .font(DesignTokens.Font.bodyStrong)
                                    .foregroundStyle(DesignTokens.Color.primary)
                                Spacer()
                                Text(app.size.humanReadable)
                                    .font(DesignTokens.Font.monoBold)
                                    .foregroundStyle(DesignTokens.Color.secondary)
                                    .monospacedDigit()
                            }
                            ForEach(Array(app.paths.enumerated()), id: \.offset) { _, path in
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 3))
                                        .foregroundStyle(DesignTokens.Color.placeholder)
                                    Text(friendlyPath(path))
                                        .font(DesignTokens.Font.mono)
                                        .foregroundStyle(DesignTokens.Color.tertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 320)

            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { showConfirm = false }
                    .keyboardShortcut(.cancelAction)
                Button {
                    showConfirm = false
                    Task { await runUninstall() }
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                        .font(DesignTokens.Font.bodyStrong)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.Color.dangerText)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 520)
    }

    // MARK: - States

    private var loadingView: some View {
        FeatureLoadingView(
            icon: "xmark.app.fill",
            tint: DesignTokens.Color.dangerText,
            title: "Scanning installed applications",
            subtitle: "Reading your Applications folder"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewingView: some View {
        FeatureLoadingView(
            icon: "trash",
            tint: DesignTokens.Color.dangerText,
            title: "Preparing uninstall preview",
            subtitle: "Finding leftover files for the selected apps"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Selection

    private func toggle(_ key: String) {
        if selected.contains(key) { selected.remove(key) } else { selected.insert(key) }
    }

    private func toggleSelectAll() {
        if allEligibleSelected {
            eligibleKeys.forEach { selected.remove($0) }
        } else {
            eligibleKeys.forEach { selected.insert($0) }
        }
    }

    // MARK: - Actions

    // Reload the app list. `message` (a post-uninstall success banner) is applied
    // in the same synchronous tail as `isLoading = false`, so SwiftUI coalesces
    // them into one render — the banner appears with the refreshed list, no flash
    // of list-without-banner. Also clears any stale parsed preview.
    private func loadApps(showing message: String? = nil) async {
        isLoading = true
        error = nil
        appear = false
        apps.removeAll()
        selected.removeAll()
        preview = nil
        resultMessage = nil
        await service.resetUninstallPreview()
        do {
            let result = try await service.getUninstallList()
            apps = result.apps
            withAnimation(DesignTokens.spring) { appear = true }
        } catch {
            self.error = error.localizedDescription
        }
        resultMessage = message
        isLoading = false
    }

    // Dry-run preview for the selected apps. Feeds "y\n" to clear Mole's two
    // confirmation prompts, accumulates the merged output, and parses it. The
    // parsed preview both populates the confirmation sheet and (when non-empty)
    // arms the preview-before-delete guard in MoService.
    private func startPreview() async {
        let targets = selectedApps
        guard !targets.isEmpty else { return }
        // Defense-in-depth: re-check admin status against the live filesystem in
        // case a bundle's ownership/source changed since the list was built. An
        // admin-required app would make Mole abort the whole batch, so refuse to
        // preview it rather than reach that dead end.
        if targets.contains(where: { MoService.bundleRequiresAdmin(path: $0.path, source: $0.source) }) {
            error = "One of the selected apps now needs administrator access. Re-scan and try again, or remove it from Terminal."
            return
        }
        let names = targets.map(\.name)
        pendingNames = names
        preview = nil
        isPreviewing = true
        error = nil
        resultMessage = nil
        await service.resetUninstallPreview()

        var text = ""
        for await event in service.streamFeeding(args: ["uninstall"] + names + ["--dry-run"], input: "y\n") {
            switch event {
            case .line(let l):
                text += l + "\n"
            case .finished(let code):
                if code == 0 {
                    let result = await service.finalizeUninstallPreview(text: text)
                    if result.isEmpty {
                        error = "Could not read the uninstall preview. Mole's output format may have changed."
                    } else {
                        preview = result
                        isPreviewing = false // leave the loading state before presenting the sheet
                        showConfirm = true
                    }
                } else {
                    error = "Uninstall preview failed (exit \(code))."
                }
            case .error(let m):
                error = m
            }
        }
        isPreviewing = false
    }

    // Execute the previewed uninstall (unprivileged, Trash routing). Guarded on
    // the preview-before-delete flag, and driven with the same fed "y\n".
    private func runUninstall() async {
        guard await service.uninstallPreviewIsReady() else {
            error = "Preview the apps before uninstalling."
            return
        }
        guard !pendingNames.isEmpty else { return }
        // Execute exactly what was previewed. If the selection changed after the
        // preview (a dismissed sheet, a re-selection), refuse and force a fresh
        // preview rather than acting on a stale set — the safety invariant must
        // not depend on the sheet staying modal. Compared order-independently so
        // it tracks the set of apps, not their incidental list order.
        guard pendingNames.sorted() == selectedApps.map(\.name).sorted() else {
            showConfirm = false
            await service.resetUninstallPreview()
            error = "Your selection changed after the preview. Click Uninstall again to re-check what will be removed."
            return
        }
        isRunning = true
        let count = pendingNames.count
        let freed = preview?.totalSize ?? 0
        runningMessage = count == 1 ? "Uninstalling \(pendingNames[0])…" : "Uninstalling \(count) apps…"
        error = nil
        resultMessage = nil
        activity.removeAll()

        var ok = false
        for await event in service.streamFeeding(args: ["uninstall"] + pendingNames, input: "y\n") {
            switch event {
            case .line(let l):
                appendActivity(l)
            case .finished(let code):
                if code == 0 { ok = true }
                else if error == nil { error = "Uninstall failed (exit \(code))." }
            case .error(let m):
                error = m
            }
        }
        isRunning = false
        if ok {
            let message = count == 1
                ? "Moved \(pendingNames[0]) to Trash (\(freed.humanReadable) freed)."
                : "Moved \(count) apps to Trash (\(freed.humanReadable) freed)."
            await service.resetUninstallPreview()
            await loadApps(showing: message) // refresh list + clear selection; banner applied atomically
        }
    }

    private func appendActivity(_ line: String, limit: Int = 200) {
        let t = MoOutputParser.stripControlSequences(line).trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        activity.append(t)
        if activity.count > limit { activity.removeFirst(activity.count - limit) }
    }

    // Replace the home prefix with ~ so paths read short and don't leak the
    // username. Mole already prints leftovers as ~-relative, but the bundle path
    // is absolute — normalize both.
    private func friendlyPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }
}

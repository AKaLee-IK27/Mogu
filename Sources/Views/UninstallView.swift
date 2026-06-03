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
    @State private var pendingRequiresAdmin = false
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
        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Uninstall")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Select apps, preview leftovers, then move them to Trash")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            if !apps.isEmpty && selected.isEmpty {
                InlineSearchField(text: $searchText, prompt: "Search apps")
                    .frame(width: 210)
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(totalAppsSize)
                        .font(DesignTokens.Font.monoBold)
                        .monospacedDigit()
                }
                .foregroundStyle(DesignTokens.Color.accentTint)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(DesignTokens.Color.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
            }
            if !selected.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "checkmark.square.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(selected.count) selected")
                        .font(DesignTokens.Font.captionStrong)
                    Text(selectedSize.humanReadable)
                        .font(DesignTokens.Font.monoBold)
                        .monospacedDigit()
                }
                .foregroundStyle(DesignTokens.Color.dangerText)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(DesignTokens.Color.dangerSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))

                Button("Clear") { selected.removeAll() }
                    .buttonStyle(.plain)
                    .font(DesignTokens.Font.captionStrong)
                    .foregroundStyle(DesignTokens.Color.accent)
                HeaderActionButton(label: selectedRequiresAdmin ? "Preview Admin Uninstall" : "Preview Uninstall",
                                   systemName: selectedRequiresAdmin ? "lock.shield" : "trash",
                                   tint: selectedRequiresAdmin ? DesignTokens.Color.warningText : DesignTokens.Color.dangerText,
                                   disabled: isPreviewing || isRunning) {
                    Task { await startPreview() }
                }
            }
            HeaderIconButton(systemName: "arrow.clockwise", help: "Re-scan",
                             disabled: isLoading || isPreviewing || isRunning) {
                Task { await loadApps() }
            }
        }
        .padding(.horizontal, DesignTokens.Layout.headerHorizontalPadding)
        .padding(.vertical, DesignTokens.Layout.headerVerticalPadding)
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

    // Standard user-owned apps in the current filter. Admin-required apps are
    // selectable manually, but select-all keeps the normal non-admin batch flow
    // unchanged and never pulls a password prompt into a mixed batch.
    private var eligibleKeys: [String] {
        filteredApps.filter { !$0.requiresAdmin && isSelectable($0) }.map(rowKey)
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

    private var selectedRequiresAdmin: Bool {
        selectedApps.contains { $0.requiresAdmin }
    }

    private func rowKey(_ app: AppInfo) -> String { app.path ?? app.name }

    private func isHomebrewApp(_ app: AppInfo) -> Bool {
        app.source?.caseInsensitiveCompare("Homebrew") == .orderedSame
    }

    private func isSelectable(_ app: AppInfo) -> Bool {
        !isHomebrewApp(app)
    }

    private func liveRequiresAdmin(_ app: AppInfo) -> Bool {
        MoService.bundleRequiresAdmin(path: app.path, source: app.source)
    }

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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            uninstallSummaryCard
            uninstallNote

            if let resultMessage {
                resultBanner(resultMessage)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                sectionHeader("Installed apps", subtitle: "\(filteredApps.count) shown")

                VStack(spacing: 0) {
                    // Table header with a select-all-eligible toggle.
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Button { toggleSelectAll() } label: {
                            Image(systemName: allEligibleSelected ? "checkmark.square.fill" : "square")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(allEligibleSelected ? DesignTokens.Color.accent : DesignTokens.Color.tertiary)
                        }
                        .buttonStyle(.plain)
                        .disabled(eligibleKeys.isEmpty)
                        .help("Select all eligible apps")
                        .frame(width: 22)
                        sortHeader("Application", field: .name, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        sortHeader("Size", field: .size, alignment: .trailing)
                            .frame(width: 92, alignment: .trailing)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Color.insetBackground)

                    ForEach(Array(sortedApps.enumerated()), id: \.offset) { i, app in
                        appRow(app)
                            .opacity(appear ? 1 : 0)
                            .offset(x: appear ? 0 : -8)
                            .animation(DesignTokens.stagger(i), value: appear)

                        if i < sortedApps.count - 1 {
                            Rectangle()
                                .fill(DesignTokens.Color.separatorLight)
                                .frame(height: 1)
                                .padding(.leading, 76)
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

    private var uninstallSummaryCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.xl) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                            .fill(DesignTokens.Color.dangerSoft)
                            .frame(width: 56, height: 56)
                        Image(systemName: selected.isEmpty ? "xmark.app.fill" : "checkmark.square.fill")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(DesignTokens.Color.dangerText)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(selected.isEmpty ? "Installed apps ready for review" : "Uninstall batch selected")
                            .font(DesignTokens.Font.section)
                            .foregroundStyle(DesignTokens.Color.primary)
                        Text(selected.isEmpty ? "Select apps to preview their leftovers before moving anything to Trash." : "Preview the selected apps and leftovers before the final Trash confirmation.")
                            .font(DesignTokens.Font.caption)
                            .foregroundStyle(DesignTokens.Color.secondary)
                    }
                }

                Spacer(minLength: DesignTokens.Spacing.lg)

                VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxs) {
                    Text(selected.isEmpty ? totalAppsSize : selectedSize.humanReadable)
                        .font(DesignTokens.Font.displayNumberLarge)
                        .foregroundStyle(DesignTokens.Color.primary)
                        .monospacedDigit()
                    Text(selected.isEmpty ? "installed app data" : "selected for preview")
                        .font(DesignTokens.Font.labelUppercase)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                }
            }

            HStack(spacing: DesignTokens.Spacing.md) {
                UninstallSummaryMetric(title: "Installed", value: "\(apps.count)", systemName: "square.grid.2x2.fill", tint: DesignTokens.Color.accent)
                UninstallSummaryMetric(title: "Selectable", value: "\(selectableAppsCount)", systemName: "checkmark.square.fill", tint: DesignTokens.Color.successText)
                UninstallSummaryMetric(title: "Admin", value: "\(adminRequiredCount)", systemName: "lock.shield.fill", tint: DesignTokens.Color.warningText)
                UninstallSummaryMetric(title: "Selected", value: "\(selected.count)", systemName: "trash.fill", tint: DesignTokens.Color.dangerText)
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

    private var uninstallNote: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.accentTint)
                .frame(width: 28, height: 28)
                .background(DesignTokens.Color.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text("Trash recovery")
                    .font(DesignTokens.Font.captionStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Selected apps and leftover files move to the Trash, so you can restore them. Apps marked Admin require your administrator password after preview; Homebrew casks stay locked and should be removed with `brew uninstall --cask --zap`.")
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

    private func appRow(_ app: AppInfo) -> some View {
        let key = rowKey(app)
        let isSelected = selected.contains(key)
        let selectable = isSelectable(app)
        return HStack(spacing: DesignTokens.Spacing.md) {
            // Selection control. Homebrew casks stay locked because running brew
            // through a root/admin GUI path can leave package-manager state worse.
            Group {
                if !selectable {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignTokens.Color.warningText)
                        .help("Homebrew cask — remove from Terminal: brew uninstall --cask --zap \"\(app.name)\"")
                } else {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? DesignTokens.Color.dangerText : (app.requiresAdmin ? DesignTokens.Color.warningText : DesignTokens.Color.tertiary))
                }
            }
            .frame(width: 22)

            Image(systemName: "app.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(app.requiresAdmin ? DesignTokens.Color.warningText : DesignTokens.Color.accentTint)
                .frame(width: 34, height: 34)
                .background(app.requiresAdmin ? DesignTokens.Color.warningSoft : DesignTokens.Color.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(app.name)
                        .font(DesignTokens.Font.bodyStrong)
                        .foregroundStyle(DesignTokens.Color.primary)
                    if app.requiresAdmin { adminBadge }
                    if isHomebrewApp(app) { brewBadge }
                }
                if let bid = app.bundleID {
                    Text(bid)
                        .font(DesignTokens.Font.mono)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if app.requiresAdmin {
                    Text(isHomebrewApp(app) ? "Homebrew cask, remove from Terminal" : "Admin password required after preview")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                }
            }

            Spacer(minLength: DesignTokens.Spacing.md)

            Text(app.size.humanReadable)
                .font(DesignTokens.Font.monoBold)
                .foregroundStyle(isSelected ? DesignTokens.Color.dangerText : DesignTokens.Color.secondary)
                .monospacedDigit()
                .frame(width: 92, alignment: .trailing)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .opacity(selectable ? 1 : 0.72)
        .background(isSelected ? DesignTokens.Color.dangerSoft : Color.clear)
        .onTapGesture { if selectable { toggle(app) } }
    }

    private var adminBadge: some View {
        Text("Admin")
            .font(DesignTokens.Font.labelUppercase)
            .foregroundStyle(DesignTokens.Color.warningText)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, 2)
            .background(DesignTokens.Color.warningSoft)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
    }

    private var brewBadge: some View {
        Text("Brew")
            .font(DesignTokens.Font.labelUppercase)
            .foregroundStyle(DesignTokens.Color.warningText)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, 2)
            .background(DesignTokens.Color.warningSoft)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
    }

    private func resultBanner(_ message: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.successText)
            Text(message)
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

    private var totalAppsSizeBytes: UInt64 {
        apps.reduce(0) { $0 + $1.size }
    }

    private var totalAppsSize: String {
        totalAppsSizeBytes.humanReadable
    }

    private var adminRequiredCount: Int {
        apps.filter(\.requiresAdmin).count
    }

    private var selectableAppsCount: Int {
        apps.filter(isSelectable).count
    }

    // MARK: - Confirmation sheet

    private var confirmSheet: some View {
        let preview = preview ?? UninstallPreview(apps: [], totalSize: 0)
        let needsAdmin = pendingRequiresAdmin
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.dangerText)
                    .frame(width: 40, height: 40)
                    .background(DesignTokens.Color.dangerSoft)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(needsAdmin
                         ? (preview.apps.count == 1 ? "Move 1 admin app to Trash?" : "Move \(preview.apps.count) admin apps to Trash?")
                         : (preview.apps.count == 1 ? "Move 1 app to Trash?" : "Move \(preview.apps.count) apps to Trash?"))
                        .font(DesignTokens.Font.section)
                        .foregroundStyle(DesignTokens.Color.primary)
                    Text(needsAdmin
                         ? "The dry-run preview found selected apps and leftovers totaling \(preview.totalSize.humanReadable). Mogu will ask for your administrator password after this confirmation; you can restore moved items from Trash."
                         : "The dry-run preview found selected apps and leftovers totaling \(preview.totalSize.humanReadable). You can restore them from Trash.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DesignTokens.Spacing.md)
                VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxs) {
                    Text(preview.totalSize.humanReadable)
                        .font(DesignTokens.Font.monoLarge)
                        .foregroundStyle(DesignTokens.Color.dangerText)
                        .monospacedDigit()
                    Text("previewed")
                        .font(DesignTokens.Font.labelUppercase)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                }
            }
            .padding(DesignTokens.Spacing.xl)

            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    ForEach(preview.apps) { app in
                        previewReceiptRow(app)
                    }
                }
                .padding(DesignTokens.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 340)
            .background(DesignTokens.Color.pageBackground)

            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Text(needsAdmin ? "Final action: enter your administrator password, then move the previewed apps and leftovers to Trash." : "Final action: move the previewed apps and leftovers to Trash.")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.secondary)
                Spacer()
                Button("Cancel") { showConfirm = false }
                    .keyboardShortcut(.cancelAction)
                Button {
                    showConfirm = false
                    Task { await runUninstall() }
                } label: {
                    Label(needsAdmin ? "Enter Password & Move to Trash" : "Move to Trash", systemImage: needsAdmin ? "lock.shield" : "trash")
                        .font(DesignTokens.Font.bodyStrong)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.Color.dangerText)
                .keyboardShortcut(.defaultAction)
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .frame(width: 600)
    }

    private func previewReceiptRow(_ app: UninstallPreviewApp) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "app.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.dangerText)
                    .frame(width: 30, height: 30)
                    .background(DesignTokens.Color.dangerSoft)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
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
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 3))
                        .foregroundStyle(DesignTokens.Color.placeholder)
                    Text(friendlyPath(path))
                        .font(DesignTokens.Font.mono)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.leading, 42)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
        )
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            FeatureLoadingView(
                icon: "xmark.app.fill",
                tint: DesignTokens.Color.dangerText,
                title: "Scanning installed applications",
                subtitle: "Reading Applications folders and app metadata"
            )
            Text("Admin apps need a password after preview. Homebrew casks stay locked.")
                .font(DesignTokens.Font.captionStrong)
                .foregroundStyle(DesignTokens.Color.dangerText)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(DesignTokens.Color.dangerSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewingView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            FeatureLoadingView(
                icon: "trash",
                tint: DesignTokens.Color.dangerText,
                title: "Preparing uninstall preview",
                subtitle: selectedRequiresAdmin ? "Finding leftovers first. Your password is only requested after the preview." : "Finding leftover files before the confirmation sheet opens"
            )
            Text("Dry-run only. Nothing moves to Trash yet.")
                .font(DesignTokens.Font.captionStrong)
                .foregroundStyle(DesignTokens.Color.dangerText)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(DesignTokens.Color.dangerSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var runningView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            VStack(spacing: DesignTokens.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.3)
                Text(runningMessage)
                    .font(DesignTokens.Font.bodyStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text(pendingRequiresAdmin ? "A macOS administrator password prompt may appear while Mole moves protected apps to Trash." : "Mogu is streaming Mole output while selected apps move to Trash.")
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

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "xmark.app.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.tertiary)
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("No removable apps found")
                    .font(DesignTokens.Font.section)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Mole did not detect any applications that can be removed from this list.")
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

    // MARK: - Selection

    private func toggle(_ app: AppInfo) {
        let key = rowKey(app)
        if selected.contains(key) {
            selected.remove(key)
            return
        }

        if app.requiresAdmin {
            selected = Set(selected.filter { existingKey in
                apps.first(where: { rowKey($0) == existingKey })?.requiresAdmin == true
            })
        } else {
            selected = Set(selected.filter { existingKey in
                apps.first(where: { rowKey($0) == existingKey })?.requiresAdmin != true
            })
        }
        selected.insert(key)
    }

    private func toggleSelectAll() {
        if allEligibleSelected {
            eligibleKeys.forEach { selected.remove($0) }
        } else {
            selected = Set(selected.filter { existingKey in
                apps.first(where: { rowKey($0) == existingKey })?.requiresAdmin != true
            })
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
        pendingRequiresAdmin = false
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
        let adminTargets = targets.filter { $0.requiresAdmin }
        let standardTargets = targets.filter { !$0.requiresAdmin }
        if !adminTargets.isEmpty && !standardTargets.isEmpty {
            error = "Preview administrator apps separately from normal apps."
            return
        }
        if targets.contains(where: isHomebrewApp) {
            error = "Homebrew casks should be removed from Terminal with brew uninstall --cask --zap."
            return
        }

        // Defense-in-depth: re-check admin status against the live filesystem in
        // case a bundle's ownership/source changed since the list was built.
        let requiresAdmin = !adminTargets.isEmpty
        let liveAdminTargets = targets.filter(liveRequiresAdmin)
        if requiresAdmin {
            guard liveAdminTargets.count == targets.count else {
                error = "One selected app no longer needs administrator access. Re-scan and preview it again."
                return
            }
        } else if !liveAdminTargets.isEmpty {
            error = "One selected app now needs administrator access. Re-scan and preview it separately."
            return
        }

        let names = targets.map(\.name)
        pendingNames = names
        pendingRequiresAdmin = requiresAdmin
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
        let currentTargets = selectedApps
        guard pendingRequiresAdmin == currentTargets.contains(where: { $0.requiresAdmin }) else {
            showConfirm = false
            await service.resetUninstallPreview()
            error = "Your selection's administrator requirement changed after the preview. Re-scan and preview again."
            return
        }
        if currentTargets.contains(where: isHomebrewApp) {
            showConfirm = false
            await service.resetUninstallPreview()
            error = "Homebrew casks should be removed from Terminal with brew uninstall --cask --zap."
            return
        }
        if pendingRequiresAdmin {
            guard currentTargets.allSatisfy(liveRequiresAdmin) else {
                showConfirm = false
                await service.resetUninstallPreview()
                error = "One selected app no longer needs administrator access. Re-scan and preview it again."
                return
            }
        } else if currentTargets.contains(where: liveRequiresAdmin) {
            showConfirm = false
            await service.resetUninstallPreview()
            error = "One selected app now needs administrator access. Re-scan and preview it separately."
            return
        }
        isRunning = true
        let count = pendingNames.count
        let freed = preview?.totalSize ?? 0
        runningMessage = pendingRequiresAdmin
            ? (count == 1 ? "Waiting for administrator password to uninstall \(pendingNames[0])…" : "Waiting for administrator password to uninstall \(count) apps…")
            : (count == 1 ? "Uninstalling \(pendingNames[0])…" : "Uninstalling \(count) apps…")
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

private struct UninstallSummaryMetric: View {
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

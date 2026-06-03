import SwiftUI
import AppKit

enum SidebarItem: String, CaseIterable, Identifiable {
    case status = "Status"
    case clean = "Clean"
    case uninstall = "Uninstall"
    case analyze = "Analyze"
    case optimize = "Optimize"
    case purge = "Purge"
    case permissions = "Permissions"

    var id: String { rawValue }
    var label: String { rawValue }

    var icon: String {
        switch self {
        case .status: return "gauge.medium"
        case .clean: return "sparkles"
        case .uninstall: return "xmark.app.fill"
        case .analyze: return "chart.bar.fill"
        case .optimize: return "bolt.horizontal.circle.fill"
        case .purge: return "trash.fill"
        case .permissions: return "lock.shield"
        }
    }

    var iconColor: SwiftUI.Color {
        switch self {
        case .status: return DesignTokens.Color.accent
        case .clean: return DesignTokens.Color.successText
        case .uninstall: return DesignTokens.Color.dangerText
        case .optimize: return DesignTokens.Color.warning
        case .analyze: return SwiftUI.Color(hex: "5856d6")
        case .purge: return DesignTokens.Color.purgeAccent
        case .permissions: return DesignTokens.Color.accent
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: SidebarItem
    @State private var moService = MoService()
    @StateObject private var permissions = PermissionsService()
    @State private var isAvailable = false
    @State private var sidebarHover: SidebarItem?
    @State private var loadedTabs: Set<String> = []

    // ── Sidebar collapse state ─────────────────────────
    @AppStorage("sidebarCollapsed") private var isSidebarCollapsed = false

    // ── Feature flags (AppStorage) ──────────────────────
    @AppStorage("hasSeenOnboarding")  private var hasSeenOnboarding  = false
    @AppStorage("lastSelectedTab")    private var lastSelectedTab    = SidebarItem.status.rawValue
    @AppStorage("lastSeenVersion")    private var lastSeenVersion    = ""
    @State private var showOnboarding = false
    @State private var showReleaseNotes = false
    @State private var showAbout = false

    // Trigger bindings (change UUID to fire action in child view)
    @State private var statusRefresh = UUID()
    @State private var cleanRefresh = UUID()
    @State private var cleanRun = UUID()
    @State private var uninstallRefresh = UUID()
    @State private var uninstallRun = UUID()
    @State private var analyzeRefresh = UUID()
    @State private var optimizePreview = UUID()
    @State private var optimizeRun = UUID()
    @State private var purgeRefresh = UUID()

    // Loading/running state bindings
    @State private var statusLoading = true
    @State private var cleanLoading = true
    @State private var cleanRunning = false
    @State private var cleanHasData = false
    @State private var uninstallLoading = true
    @State private var analyzeLoading = true
    @State private var optimizeRunning = false
    @State private var optimizeComplete = false
    @State private var purgeLoading = true

    init() {
        let requestedScreen = Foundation.ProcessInfo.processInfo.environment["MOGU_SCREEN"]?.lowercased()
        let initialItem: SidebarItem
        if let requested = requestedScreen,
           let match = SidebarItem.allCases.first(where: { $0.rawValue.lowercased() == requested }) {
            initialItem = match
        } else {
            let stored = UserDefaults.standard.string(forKey: "lastSelectedTab") ?? SidebarItem.status.rawValue
            initialItem = SidebarItem.allCases.first { $0.rawValue == stored } ?? .status
        }
        _selectedItem = State(initialValue: initialItem)
    }

    var body: some View {
        mainContent
            // ── Onboarding sheet ────────────────────────
            .sheet(isPresented: $showOnboarding) {
                OnboardingView()
            }
            // ── Release notes sheet ─────────────────────
            .sheet(isPresented: $showReleaseNotes) {
                ReleaseNotesView()
            }
            // ── About sheet ─────────────────────────────
            .sheet(isPresented: $showAbout) {
                AboutSheet()
            }
            // ── Notification observers ──────────────────
            .onReceive(NotificationCenter.default.publisher(for: .selectTab)) { notification in
                guard let raw = notification.userInfo?["sidebarItem"] as? String,
                      let item = SidebarItem(rawValue: raw) else { return }
                withAnimation(DesignTokens.spring) { selectedItem = item }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dockRefreshStatus)) { _ in
                withAnimation(DesignTokens.spring) { selectedItem = .status }
                statusRefresh = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: .dockQuickClean)) { _ in
                withAnimation(DesignTokens.spring) { selectedItem = .clean }
                cleanRefresh = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showOnboarding)) { _ in
                showOnboarding = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showAbout)) { _ in
                showAbout = true
            }
            // ── Lifecycle ───────────────────────────────
            .task {
                isAvailable = await moService.isAvailable()
                // Show onboarding on first launch.
                if !hasSeenOnboarding {
                    showOnboarding = true
                }
                // Show release notes after a version bump.
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                if lastSeenVersion.isEmpty {
                    lastSeenVersion = currentVersion
                } else if lastSeenVersion != currentVersion {
                    showReleaseNotes = true
                    lastSeenVersion = currentVersion
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                lastSelectedTab = newValue.rawValue
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: isSidebarCollapsed ? DesignTokens.Layout.sidebarCollapsedWidth : DesignTokens.Layout.sidebarWidth)
                .animation(DesignTokens.sidebarAnimation, value: isSidebarCollapsed)

            Rectangle()
                .fill(DesignTokens.Color.separator)
                .frame(width: 1)

            Group {
                if isAvailable {
                    tabContainer
                } else {
                    NotInstalledView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.Color.pageBackground)
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    // Toolbar items
    @ViewBuilder
    private var tabContainer: some View {
        ZStack {
            ForEach(SidebarItem.allCases) { item in
                tabView(for: item)
                    .zIndex(selectedItem == item ? 1 : 0)
                    .opacity(selectedItem == item ? 1 : 0)
                    .allowsHitTesting(selectedItem == item)
            }
        }
    }

    @ViewBuilder
    private func tabView(for item: SidebarItem) -> some View {
        switch item {
        case .status:
            StickyTab(key: item.id, isActive: selectedItem == item, loadedTabs: $loadedTabs) {
                StatusView(
                    service: moService,
                    isActive: selectedItem == .status,
                    refreshTrigger: $statusRefresh,
                    isLoading: $statusLoading
                )
            }
        case .clean:
            StickyTab(key: item.id, isActive: selectedItem == item, loadedTabs: $loadedTabs) {
                CleanView(
                    service: moService,
                    permissions: permissions,
                    refreshTrigger: $cleanRefresh,
                    runTrigger: $cleanRun,
                    isLoading: $cleanLoading,
                    isRunning: $cleanRunning,
                    hasData: $cleanHasData
                )
            }
        case .uninstall:
            StickyTab(key: item.id, isActive: selectedItem == item, loadedTabs: $loadedTabs) {
                UninstallView(
                    service: moService,
                    refreshTrigger: $uninstallRefresh,
                    runTrigger: $uninstallRun,
                    isLoading: $uninstallLoading
                )
            }
        case .analyze:
            StickyTab(key: item.id, isActive: selectedItem == item, loadedTabs: $loadedTabs) {
                AnalyzeView(
                    service: moService,
                    permissions: permissions,
                    refreshTrigger: $analyzeRefresh,
                    isLoading: $analyzeLoading
                )
            }
        case .optimize:
            StickyTab(key: item.id, isActive: selectedItem == item, loadedTabs: $loadedTabs) {
                OptimizeView(
                    service: moService,
                    permissions: permissions,
                    previewTrigger: $optimizePreview,
                    runTrigger: $optimizeRun,
                    isRunning: $optimizeRunning,
                    isComplete: $optimizeComplete
                )
            }
        case .purge:
            StickyTab(key: item.id, isActive: selectedItem == item, loadedTabs: $loadedTabs) {
                PurgeView(
                    service: moService,
                    refreshTrigger: $purgeRefresh,
                    isLoading: $purgeLoading
                )
            }
        case .permissions:
            StickyTab(key: item.id, isActive: selectedItem == item, loadedTabs: $loadedTabs) {
                PermissionsView(permissions: permissions)
            }
        }
    }

    // Bundled Mogu logo, loaded once (the sidebar recomputes on every hover,
    // so we must not re-decode the PNG per render). nil → fall back to the glyph.
    // Internal so AboutView in MoguApp.swift can reuse it.
    static let sidebarLogo: NSImage? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("SidebarLogo.png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    // Mogu brand mark: bundled SidebarLogo.png (emitted by scripts/make_icon.sh
    // and copied into Resources by build_app.sh); falls back to the bolt glyph if
    // the asset is absent (e.g. a bare `swift run` debug build).
    @ViewBuilder private var brandMark: some View {
        if let nsImage = Self.sidebarLogo {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(DesignTokens.Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader

            if !isSidebarCollapsed {
                Rectangle()
                    .fill(DesignTokens.Color.separator)
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            }

            sidebarNavigation

            Spacer()

            if !isSidebarCollapsed {
                sidebarFooter
                    .transition(.opacity)
            }
        }
        .background(DesignTokens.Color.sidebar)
    }

    private var sidebarHeader: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if !isSidebarCollapsed {
                HStack(spacing: 10) {
                    brandMark
                    Text("Mogu")
                        .font(DesignTokens.Font.sidebarTitle)
                        .foregroundStyle(DesignTokens.Color.primary)
                }
                Spacer()
            } else {
                brandMark
                    .frame(maxWidth: .infinity)
            }

            collapseToggle
        }
        .padding(.horizontal, isSidebarCollapsed ? 15 : 20)
        .padding(.top, 16)
        .padding(.bottom, isSidebarCollapsed ? 16 : 18)
    }

    private var collapseToggle: some View {
        Button {
            withAnimation(DesignTokens.sidebarAnimation) {
                isSidebarCollapsed.toggle()
            }
        } label: {
            Image(systemName: isSidebarCollapsed ? "chevron.right" : "chevron.left")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.tertiary)
                .frame(width: 28, height: 28)
                .background(DesignTokens.Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        }
        .buttonStyle(.plain)
        .help(isSidebarCollapsed ? "Expand sidebar" : "Collapse sidebar")
    }

    private var sidebarNavigation: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(SidebarItem.allCases) { item in
                SidebarRow(
                    item: item,
                    isSelected: selectedItem == item,
                    isHovered: sidebarHover == item && selectedItem != item,
                    isCollapsed: isSidebarCollapsed
                ) {
                    withAnimation(DesignTokens.spring) { selectedItem = item }
                }
                .onHover { hovering in sidebarHover = hovering ? item : nil }
            }
        }
        .padding(.horizontal, isSidebarCollapsed ? 10 : 12)
        .padding(.top, isSidebarCollapsed ? 16 : 10)
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DesignTokens.Color.separator)
                .frame(height: 1)
                .padding(.horizontal, 16)

            Text("Powered by bundled Mole")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.Color.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
    }
}

// Wraps a tab's content so its .task runs only once (on first appearance).
// After that, the view stays in memory and switching back is instant.
struct StickyTab<Content: View>: View {
    let key: String
    let isActive: Bool
    @Binding var loadedTabs: Set<String>
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if isActive || loadedTabs.contains(key) {
                content()
            } else {
                Color.clear
            }
        }
        .onChange(of: isActive) { _, active in
            if active { loadedTabs.insert(key) }
        }
        .onAppear {
            if isActive { loadedTabs.insert(key) }
        }
    }
}

// Header action buttons. Live in the normal view hierarchy (NOT a window
// .toolbar, which crashes on macOS 26.5) so per-screen Refresh / Run actions
// are reachable. Replaces the removed toolbar from commit d3a2635.
struct HeaderIconButton: View {
    let systemName: String
    let help: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(disabled ? DesignTokens.Color.tertiary : DesignTokens.Color.secondary)
                .frame(width: DesignTokens.Layout.iconButtonSize, height: DesignTokens.Layout.iconButtonSize)
                .background(DesignTokens.Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                        .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
                )
                .shadow(color: DesignTokens.Shadow.control, radius: DesignTokens.Shadow.controlRadius, y: DesignTokens.Shadow.controlY)
        }
        .buttonStyle(.plain)
        .frame(width: DesignTokens.Layout.minimumHitSize, height: DesignTokens.Layout.minimumHitSize)
        .contentShape(Rectangle())
        .disabled(disabled)
        .help(help)
    }
}

struct HeaderActionButton: View {
    let label: String
    let systemName: String
    var tint: SwiftUI.Color = DesignTokens.Color.accent
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: systemName)
                .font(DesignTokens.Font.bodyStrong)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .controlSize(.large)
        .frame(minHeight: DesignTokens.Layout.minimumHitSize)
        .disabled(disabled)
    }
}

// In-view search field. Replaces SwiftUI `.searchable`, which installs an
// NSSearchToolbarItem into the window's NSToolbar and triggers the macOS 26.5
// NSToolbar SIGTRAP crash (same root cause as the removed `.toolbar`).
struct InlineSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DesignTokens.Color.tertiary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(DesignTokens.Font.body)
                .foregroundStyle(DesignTokens.Color.primary)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.Color.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(minHeight: DesignTokens.Layout.minimumHitSize)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
        )
    }
}

// Live, terminal-style feed of the most recent streamed output lines. Used by
// scan operations (Clean/Purge) to show what's happening during a long scan.
struct ActivityFeed: View {
    let lines: [String]
    var visible: Int = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.suffix(visible).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(DesignTokens.Font.mono)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Color.codeBg)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
        )
    }
}

struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let isHovered: Bool
    let isCollapsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isCollapsed {
                collapsedRow
            } else {
                expandedRow
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(isCollapsed ? item.label : "")
    }

    private var collapsedRow: some View {
        VStack(spacing: 0) {
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isSelected ? item.iconColor : (isHovered ? DesignTokens.Color.primary : DesignTokens.Color.tertiary))
                .frame(width: 44, height: 44)
                .background(isSelected ? DesignTokens.Color.selectedOverlay : (isHovered ? DesignTokens.Color.hoverOverlay : Color.clear))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var expandedRow: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? item.iconColor : (isHovered ? DesignTokens.Color.primary : DesignTokens.Color.tertiary))
                .frame(width: 20, alignment: .center)

            Text(item.label)
                .font(isSelected ? DesignTokens.Font.sidebarItemActive : DesignTokens.Font.sidebarItem)
                .foregroundStyle(isSelected ? DesignTokens.Color.primary : (isHovered ? DesignTokens.Color.primary : DesignTokens.Color.secondary))

            Spacer()

            if isSelected {
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.iconColor)
                    .frame(width: 3, height: 18)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(DesignTokens.Color.selectedOverlay)
                    .shadow(color: DesignTokens.Shadow.control, radius: DesignTokens.Shadow.controlRadius, y: DesignTokens.Shadow.controlY)
            } else if isHovered {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(DesignTokens.Color.hoverOverlay)
            }
        }
        .contentShape(Rectangle())
    }
}

struct NotInstalledView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.Color.warning)
                .frame(width: 64, height: 64)
                .background(DesignTokens.Color.warningSoft)
                .clipShape(Circle())

            Text("Mole Runtime Missing")
                .font(DesignTokens.Font.section)
                .foregroundStyle(DesignTokens.Color.primary)

            Text("Rebuild the app bundle to include the bundled Mole runtime.")
                .font(DesignTokens.Font.body)
                .foregroundStyle(DesignTokens.Color.secondary)
                .multilineTextAlignment(.center)

            Text("./build_app.sh")
                .font(DesignTokens.Font.code)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(DesignTokens.Color.codeBg)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        }
    }
}

// MARK: - About Sheet (replaces system About panel with custom content)

struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 20) {
            if let nsImage = ContentView.sidebarLogo {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(DesignTokens.Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            VStack(spacing: 4) {
                Text("Mogu")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }

            Divider()

            VStack(spacing: 8) {
                Text("Built on [Mole](https://github.com/tw93/Mole) by @tw93")
                    .font(DesignTokens.Font.body)
                    .foregroundStyle(DesignTokens.Color.secondary)
                    .multilineTextAlignment(.center)
                Text("MIT License")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }

            Button {
                NSWorkspace.shared.open(URL(string: "https://github.com/AKaLee-IK27/Mogu")!)
            } label: {
                Label("View on GitHub", systemImage: "link")
            }
            .buttonStyle(.link)

            Button("Close") { dismiss() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(32)
        .frame(width: 320)
    }
}

import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case status = "Status"
    case clean = "Clean"
    case uninstall = "Uninstall"
    case analyze = "Analyze"
    case optimize = "Optimize"
    case purge = "Purge"

    var id: String { rawValue }
    var label: String { rawValue }

    var icon: String {
        switch self {
        case .status: return "gauge.medium"
        case .clean: return "sparkles"
        case .uninstall: return "app.badge.xmark"
        case .analyze: return "chart.bar.fill"
        case .optimize: return "bolt.horizontal.circle.fill"
        case .purge: return "trash.fill"
        }
    }

    var iconColor: SwiftUI.Color {
        switch self {
        case .status: return DesignTokens.Color.accent
        case .clean: return DesignTokens.Color.successText
        case .uninstall: return DesignTokens.Color.dangerText
        case .optimize: return DesignTokens.Color.warning
        case .analyze: return SwiftUI.Color(hex: "5856d6")
        case .purge: return DesignTokens.Color.secondary
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: SidebarItem
    @State private var moService = MoService()
    @State private var isAvailable = false
    @State private var sidebarHover: SidebarItem?
    @State private var loadedTabs: Set<String> = []

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
        let requestedScreen = Foundation.ProcessInfo.processInfo.environment["MOLEMAC_SCREEN"]?.lowercased()
        let initialItem = SidebarItem.allCases.first { $0.rawValue.lowercased() == requestedScreen } ?? .status
        _selectedItem = State(initialValue: initialItem)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 230)

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
        .task { isAvailable = await moService.isAvailable() }
        .toolbar { toolbarItems }
    }

    // Single toolbar source — only items for the active tab are rendered
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(id: "primary.refresh", placement: .primaryAction) {
            refreshButton
        }
        ToolbarItem(id: "primary.action", placement: .primaryAction) {
            actionButton
        }
    }

    @ViewBuilder
    private var refreshButton: some View {
        switch selectedItem {
        case .status:
            Button(action: { statusRefresh = UUID() }) {
                Image(systemName: "arrow.clockwise")
            }.help("Refresh").disabled(statusLoading)
        case .clean:
            Button(action: { cleanRefresh = UUID() }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }.disabled(cleanLoading || cleanRunning)
        case .uninstall:
            Button(action: { uninstallRefresh = UUID() }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }.disabled(uninstallLoading)
        case .analyze:
            Button(action: { analyzeRefresh = UUID() }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }.disabled(analyzeLoading)
        case .optimize:
            Button(action: { optimizePreview = UUID() }) {
                Label("Preview", systemImage: "eye")
            }.disabled(optimizeRunning || optimizeComplete)
        case .purge:
            Button(action: { purgeRefresh = UUID() }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }.disabled(purgeLoading)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch selectedItem {
        case .status, .analyze, .purge:
            EmptyView()
        case .clean:
            Button(action: { cleanRun = UUID() }) {
                Label("Clean All", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(cleanLoading || cleanRunning || !cleanHasData)
        case .uninstall:
            Button(action: { uninstallRun = UUID() }) {
                Label("Uninstall", systemImage: "trash.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(uninstallLoading)
        case .optimize:
            Button(action: { optimizeRun = UUID() }) {
                Label("Run", systemImage: "bolt.horizontal.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(SwiftUI.Color(hex: "ff9f0a"))
            .disabled(optimizeRunning || optimizeComplete)
        }
    }

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
            StickyTab(key: item.id, loadedTabs: $loadedTabs) {
                StatusView(
                    service: moService,
                    refreshTrigger: $statusRefresh,
                    isLoading: $statusLoading
                )
            }
        case .clean:
            StickyTab(key: item.id, loadedTabs: $loadedTabs) {
                CleanView(
                    service: moService,
                    refreshTrigger: $cleanRefresh,
                    runTrigger: $cleanRun,
                    isLoading: $cleanLoading,
                    isRunning: $cleanRunning,
                    hasData: $cleanHasData
                )
            }
        case .uninstall:
            StickyTab(key: item.id, loadedTabs: $loadedTabs) {
                UninstallView(
                    service: moService,
                    refreshTrigger: $uninstallRefresh,
                    runTrigger: $uninstallRun,
                    isLoading: $uninstallLoading
                )
            }
        case .analyze:
            StickyTab(key: item.id, loadedTabs: $loadedTabs) {
                AnalyzeView(
                    service: moService,
                    refreshTrigger: $analyzeRefresh,
                    isLoading: $analyzeLoading
                )
            }
        case .optimize:
            StickyTab(key: item.id, loadedTabs: $loadedTabs) {
                OptimizeView(
                    service: moService,
                    previewTrigger: $optimizePreview,
                    runTrigger: $optimizeRun,
                    isRunning: $optimizeRunning,
                    isComplete: $optimizeComplete
                )
            }
        case .purge:
            StickyTab(key: item.id, loadedTabs: $loadedTabs) {
                PurgeView(
                    service: moService,
                    refreshTrigger: $purgeRefresh,
                    isLoading: $purgeLoading
                )
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(DesignTokens.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("Mole")
                        .font(DesignTokens.Font.sidebarTitle)
                        .foregroundStyle(DesignTokens.Color.primary)
                    Spacer()
                }
                Text("System Cleaner")
                    .font(DesignTokens.Font.sidebarSubtitle)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 18)

            Rectangle()
                .fill(DesignTokens.Color.separator)
                .frame(height: 1)
                .padding(.horizontal, 16)

            VStack(spacing: 2) {
                ForEach(SidebarItem.allCases) { item in
                    SidebarRow(
                        item: item,
                        isSelected: selectedItem == item,
                        isHovered: sidebarHover == item && selectedItem != item
                    ) {
                        withAnimation(DesignTokens.spring) { selectedItem = item }
                    }
                    .onHover { hovering in sidebarHover = hovering ? item : nil }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            Spacer()

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
        .background(DesignTokens.Color.sidebar)
    }
}

// Wraps a tab's content so its .task runs only once (on first appearance).
// After that, the view stays in memory and switching back is instant.
struct StickyTab<Content: View>: View {
    let key: String
    @Binding var loadedTabs: Set<String>
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .onAppear {
                if loadedTabs.contains(key) { return }
                loadedTabs.insert(key)
            }
    }
}

struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                        .fill(DesignTokens.Color.cardBackground)
                        .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                        .fill(DesignTokens.Color.hoverOverlay)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
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

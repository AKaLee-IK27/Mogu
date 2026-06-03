import SwiftUI
import Sparkle

// MARK: - App-wide notification names

extension Notification.Name {
    /// Payload: userInfo["sidebarItem"] = SidebarItem.rawValue
    static let selectTab = Notification.Name("co.greenpassport.mogu.selectTab")
    /// No payload — refreshes the Status tab.
    static let dockRefreshStatus = Notification.Name("co.greenpassport.mogu.dockRefreshStatus")
    /// No payload — triggers a Clean preview.
    static let dockQuickClean = Notification.Name("co.greenpassport.mogu.dockQuickClean")
    /// Show onboarding again.
    static let showOnboarding = Notification.Name("co.greenpassport.mogu.showOnboarding")
    /// Show the About Mogu window.
    static let showAbout = Notification.Name("co.greenpassport.mogu.showAbout")
}

// MARK: - Menu Bar Status Widget

/// Lightweight NSStatusItem in the menu bar showing CPU/memory status.
/// Polls `mo status --json` every 30 s, builds a menu with system stats,
/// Quick Clean, and an Open Mogu action.
@MainActor
class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private var pollingTask: Task<Void, Never>?
    private var lastStatus: SystemStatus?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.title = ""
        statusItem.button?.image = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "Mogu")
        statusItem.button?.image?.isTemplate = true
        statusItem.menu = buildMenu()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)

        // Start polling on a background thread
        pollingTask = Task.detached { [weak self] in
            guard let self else { return }
            let service = MoService()
            while !Task.isCancelled {
                if let status = try? await service.getStatus() {
                    await self.updateMenu(with: status)
                }
                try? await Task.sleep(nanoseconds: 30_000_000_000)  // 30s
            }
        }
    }

    deinit {
        pollingTask?.cancel()
    }

    @objc private func statusItemClicked() {
        Task { await refreshStatus() }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Mogu", action: #selector(openMogu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let cpuItem = NSMenuItem(title: "CPU: —", action: nil, keyEquivalent: "")
        cpuItem.tag = 1
        menu.addItem(cpuItem)

        let memItem = NSMenuItem(title: "Memory: —", action: nil, keyEquivalent: "")
        memItem.tag = 2
        menu.addItem(memItem)

        let diskItem = NSMenuItem(title: "Disk: —", action: nil, keyEquivalent: "")
        diskItem.tag = 3
        menu.addItem(diskItem)

        menu.addItem(NSMenuItem.separator())

        let cleanItem = NSMenuItem(title: "Quick Clean", action: #selector(quickClean), keyEquivalent: "")
        cleanItem.target = self
        menu.addItem(cleanItem)

        let statusItem = NSMenuItem(title: "Refresh Status", action: #selector(refreshStatus), keyEquivalent: "")
        statusItem.target = self
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Mogu", action: #selector(quitMogu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openMogu() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .dockRefreshStatus, object: nil)
    }

    @objc private func quickClean() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .dockQuickClean, object: nil)
    }

    @objc private func refreshStatus() {
        Task {
            let service = MoService()
            if let status = try? await service.getStatus() {
                updateMenu(with: status)
            }
        }
    }

    @objc private func quitMogu() {
        NSApp.terminate(nil)
    }

    private func updateMenu(with status: SystemStatus) {
        guard let menu = statusItem.menu else { return }

        for item in menu.items {
            switch item.tag {
            case 1:
                item.title = "CPU: \(String(format: "%.0f%%", status.cpu.usage))"
            case 2:
                let used = Double(status.memory.used) / Double(status.memory.total) * 100
                item.title = "Memory: \(String(format: "%.0f%%", used))"
            case 3:
                if let disk = status.disks.first {
                    item.title = "Disk: \(String(format: "%.0f%%", disk.usedPercent)) used"
                }
            default: break
            }
        }

        let image: String
        switch status.healthScore {
        case 80...100: image = "gauge.medium"
        case 60..<80: image = "gauge.medium.badge.exclamationmark"
        default: image = "gauge.low"
        }
        statusItem.button?.image = NSImage(systemSymbolName: image, accessibilityDescription: "Mogu")
        statusItem.button?.image?.isTemplate = true
    }
}

// MARK: - AppDelegate (Dock menu + Menu Bar controller)

class MoguAppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController()
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let refreshItem = NSMenuItem(title: "Refresh Status", action: #selector(refreshStatus), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let cleanItem = NSMenuItem(title: "Quick Clean", action: #selector(quickClean), keyEquivalent: "")
        cleanItem.target = self
        menu.addItem(cleanItem)

        return menu
    }

    @objc private func refreshStatus() {
        NotificationCenter.default.post(name: .dockRefreshStatus, object: nil)
    }

    @objc private func quickClean() {
        NotificationCenter.default.post(name: .dockQuickClean, object: nil)
    }
}

// MARK: - Tab-select command helper

/// Each tab gets a Command that posts a notification. ContentView observes these
/// and switches its selectedItem accordingly.
private func tabCommand(_ item: SidebarItem, _ key: KeyEquivalent) -> some View {
    Button(item.label) {
        NotificationCenter.default.post(name: .selectTab, object: nil, userInfo: ["sidebarItem": item.rawValue])
    }
    .keyboardShortcut(key, modifiers: .command)
}

// MARK: - App

@main
struct MoguApp: App {
    @NSApplicationDelegateAdaptor(MoguAppDelegate.self) private var appDelegate

    // Sparkle updater — only activated when a real EdDSA key is configured.
    // Before release, generate a key pair with Sparkle's generate_keys tool
    // and set SUFeedURL + SUPublicEDKey in build_app.sh / Info.plist.
    private let updaterController: SPUStandardUpdaterController?

    init() {
        let info = Bundle.main.infoDictionary
        let feedURL = info?["SUFeedURL"] as? String ?? ""
        let publicKey = info?["SUPublicEDKey"] as? String ?? ""
        let isConfigured = feedURL != "https://example.com/mogu/appcast.xml"
            && publicKey != "CHANGEME" && !publicKey.isEmpty
        if isConfigured {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            updaterController = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 620)
        }

        // Preferences / Settings
        Settings {
            SettingsView()
        }

        .commands {
            // Remove the default "New File" command
            CommandGroup(replacing: .newItem) {}

            // ── App menu additions ──────────────────────────

            CommandGroup(replacing: .appInfo) {
                Button("About Mogu") {
                    NotificationCenter.default.post(name: .showAbout, object: nil)
                }
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController?.checkForUpdates(nil)
                }
                .disabled(updaterController == nil)
            }

            // ── Edit menu (standard commands) ─────────────
            CommandGroup(replacing: .textFormatting) {}

            // ── Navigate → tab switching ──────────────────
            CommandMenu("Navigate") {
                tabCommand(.status, "1")
                tabCommand(.clean, "2")
                tabCommand(.uninstall, "3")
                tabCommand(.analyze, "4")
                tabCommand(.optimize, "5")
                Divider()
                tabCommand(.purge, "6")
                tabCommand(.installer, "7")
                tabCommand(.history, "8")
                tabCommand(.permissions, "9")
            }

            // ── Help menu ─────────────────────────────────
            CommandGroup(replacing: .help) {
                Button("Show Onboarding…") {
                    NotificationCenter.default.post(name: .showOnboarding, object: nil)
                }
                Divider()
                Link("Mogu on GitHub", destination: URL(string: "https://github.com/AKaLee-IK27/Mogu")!)
            }

            // ── File → Share ──────────────────────────────
            CommandGroup(after: .saveItem) {
                Button("Share Mogu…") {
                    guard let url = URL(string: "https://github.com/AKaLee-IK27/Mogu") else { return }
                    let picker = NSSharingServicePicker(items: [url])
                    if let window = NSApp.keyWindow ?? NSApp.windows.first {
                        picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
                    }
                }
            }
        }
    }
}

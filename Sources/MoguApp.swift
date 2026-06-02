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

// MARK: - AppDelegate (Dock menu)

class MoguAppDelegate: NSObject, NSApplicationDelegate {
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
                tabCommand(.permissions, "7")
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

import SwiftUI
import ServiceManagement

/// Minimal preferences window. One General tab with auto-update toggle,
/// launch-at-login toggle, and version display.
struct SettingsView: View {
    @AppStorage("automaticallyChecksForUpdates") private var autoUpdate = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var appVersion = ""
    @State private var runtimeVersion = ""

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 420)
        .onAppear {
            appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            runtimeVersion = readRuntimeVersion()
        }
    }

    private var generalTab: some View {
        Form {
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $autoUpdate)
                    .disabled(!sparkleConfigured)
                if !sparkleConfigured {
                    Text("Updates are not configured. Set SUFeedURL and SUPublicEDKey before release.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLoginItem(enabled: newValue)
                    }
            }

            Section("About") {
                HStack {
                    Text("Mogu version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                }
                HStack {
                    Text("Mole runtime")
                    Spacer()
                    Text(runtimeVersion)
                        .foregroundStyle(DesignTokens.Color.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func setLoginItem(enabled: Bool) {
        do {
            if #available(macOS 13.0, *) {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Failed to \(enabled ? "register" : "unregister") login item: \(error)")
        }
    }

    private func readRuntimeVersion() -> String {
        guard let url = Bundle.main.url(forResource: "VERSION", withExtension: nil),
              let contents = try? String(contentsOf: url) else {
            return "unknown"
        }
        return contents.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sparkleConfigured: Bool {
        let info = Bundle.main.infoDictionary
        let feedURL = info?["SUFeedURL"] as? String ?? ""
        let publicKey = info?["SUPublicEDKey"] as? String ?? ""
        return feedURL != "https://example.com/mogu/appcast.xml"
            && publicKey != "CHANGEME" && !publicKey.isEmpty
    }
}

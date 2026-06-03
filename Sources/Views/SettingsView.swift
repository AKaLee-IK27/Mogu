import SwiftUI
import ServiceManagement

/// Minimal preferences window. One General tab with auto-update toggle,
/// launch-at-login toggle, and version display.
struct SettingsView: View {
    @AppStorage("automaticallyChecksForUpdates") private var autoUpdate = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var appVersion = ""
    @State private var runtimeVersion = ""
    @State private var appear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                updatesCard
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 8)
                    .animation(DesignTokens.spring, value: appear)

                startupCard
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 8)
                    .animation(DesignTokens.spring.delay(0.04), value: appear)

                aboutCard
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 8)
                    .animation(DesignTokens.spring.delay(0.08), value: appear)
            }
            .padding(DesignTokens.Layout.cardPadding)
            .frame(maxWidth: .infinity)
        }
        .background(DesignTokens.Color.pageBackground)
        .frame(width: 480)
        .onAppear {
            appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            runtimeVersion = readRuntimeVersion()
            withAnimation(DesignTokens.spring) { appear = true }
        }
    }

    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.accentTint)
                    .frame(width: 34, height: 34)
                    .background(DesignTokens.Color.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Updates")
                        .font(DesignTokens.Font.section)
                        .foregroundStyle(DesignTokens.Color.primary)
                    Text("Control how Mogu checks for new releases.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                }
                Spacer()
            }

            VStack(spacing: 0) {
                settingsToggleRow(
                    title: "Check for updates automatically",
                    subtitle: sparkleConfigured ? nil : "Updates are not configured. Set SUFeedURL and SUPublicEDKey before release.",
                    isOn: $autoUpdate,
                    disabled: !sparkleConfigured
                )
            }
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
    }

    private var startupCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "power")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.successText)
                    .frame(width: 34, height: 34)
                    .background(DesignTokens.Color.successSoft)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Startup")
                        .font(DesignTokens.Font.section)
                        .foregroundStyle(DesignTokens.Color.primary)
                    Text("Choose whether Mogu opens when you log in.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                }
                Spacer()
            }

            VStack(spacing: 0) {
                settingsToggleRow(
                    title: "Launch at login",
                    subtitle: "Mogu will open automatically when you log into this Mac.",
                    isOn: $launchAtLogin,
                    disabled: false
                )
            }
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
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "info.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.tertiary)
                    .frame(width: 34, height: 34)
                    .background(DesignTokens.Color.codeBg)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("About")
                        .font(DesignTokens.Font.section)
                        .foregroundStyle(DesignTokens.Color.primary)
                    Text("Version information for Mogu and its bundled runtime.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                }
                Spacer()
            }

            VStack(spacing: 0) {
                settingsInfoRow(title: "Mogu version", value: appVersion)
                settingsDivider()
                settingsInfoRow(title: "Mole runtime", value: runtimeVersion)
            }
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
    }

    private func settingsToggleRow(title: String, subtitle: String?, isOn: Binding<Bool>, disabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(title)
                    .font(DesignTokens.Font.bodyStrong)
                    .foregroundStyle(disabled ? DesignTokens.Color.tertiary : DesignTokens.Color.primary)
                Spacer()
                Toggle("", isOn: isOn)
                    .toggleStyle(.switch)
                    .disabled(disabled)
                    .labelsHidden()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.top, DesignTokens.Spacing.md)

            if let subtitle {
                Text(subtitle)
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(disabled ? DesignTokens.Color.warningText : DesignTokens.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.md)
            }
        }
    }

    private func settingsInfoRow(title: String, value: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(DesignTokens.Font.bodyStrong)
                .foregroundStyle(DesignTokens.Color.primary)
            Spacer()
            Text(value)
                .font(DesignTokens.Font.mono)
                .foregroundStyle(DesignTokens.Color.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    private func settingsDivider() -> some View {
        Rectangle()
            .fill(DesignTokens.Color.separatorLight)
            .frame(height: 1)
            .padding(.horizontal, DesignTokens.Spacing.md)
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

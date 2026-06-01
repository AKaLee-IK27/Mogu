import SwiftUI

// Dedicated screen explaining MoleMac's minimal, progressive permission model.
struct PermissionsView: View {
    @ObservedObject var permissions: PermissionsService
    @Environment(\.openURL) private var openURL
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    permissionCard
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 8)
                        .animation(DesignTokens.spring, value: appear)

                    fullDiskAccessCard
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 8)
                        .animation(DesignTokens.spring.delay(0.04), value: appear)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .background(DesignTokens.Color.pageBackground)
        }
        .onAppear {
            permissions.refresh()
            withAnimation(DesignTokens.spring) { appear = true }
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Permissions")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Start without grants; escalate only when you choose")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "lock.open")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignTokens.Color.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text("No permissions required to start")
                        .font(DesignTokens.Font.section)
                        .foregroundStyle(DesignTokens.Color.primary)
                    Text("Clean, optimize, analyze, uninstall, and purge start unprivileged.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                }
                Spacer()
                adminBadge
            }

            Text("Administrator access is optional. MoleMac asks for your password only when you choose to preview and clean system-level items. Nothing is stored; nothing runs in the background.")
                .font(DesignTokens.Font.body)
                .foregroundStyle(DesignTokens.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
    }

    private var fullDiskAccessCard: some View {
        let permission = PermissionKind.fullDiskAccess
        let status = permissions.status(for: permission)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: permission.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignTokens.Color.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(permission.title)
                            .font(DesignTokens.Font.section)
                            .foregroundStyle(DesignTokens.Color.primary)
                        Text("Optional")
                            .font(DesignTokens.Font.label)
                            .foregroundStyle(DesignTokens.Color.accentTint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DesignTokens.Color.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
                    }
                    Text("Scan quietly without macOS asking per protected folder.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                }
                Spacer()
                statusBadge(status)
            }

            Text(permission.why)
                .font(DesignTokens.Font.body)
                .foregroundStyle(DesignTokens.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let settingsURL = permission.settingsURL {
                Button {
                    openURL(settingsURL)
                } label: {
                    Label("Open in System Settings", systemImage: "gearshape")
                        .font(DesignTokens.Font.bodyStrong)
                }
                .buttonStyle(.bordered)
                .tint(DesignTokens.Color.accent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
    }

    private func statusBadge(_ status: PermissionStatus) -> some View {
        let style = statusStyle(for: status)
        return HStack(spacing: 5) {
            Image(systemName: style.icon).font(.system(size: 11))
            Text(status.label).font(DesignTokens.Font.label)
        }
        .foregroundStyle(style.foreground)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(style.background)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
    }

    private func statusStyle(for status: PermissionStatus) -> (icon: String, foreground: SwiftUI.Color, background: SwiftUI.Color) {
        switch status {
        case .granted:
            return ("checkmark.circle.fill", DesignTokens.Color.successText, DesignTokens.Color.successSoft)
        case .notGranted:
            return ("exclamationmark.circle.fill", DesignTokens.Color.warningText, DesignTokens.Color.warningSoft)
        case .promptsWhenNeeded:
            return ("key.fill", DesignTokens.Color.warningText, DesignTokens.Color.warningSoft)
        case .unknown:
            return ("questionmark.circle.fill", DesignTokens.Color.tertiary, DesignTokens.Color.codeBg)
        }
    }

    private var adminBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "key.fill").font(.system(size: 11))
            Text("Admin optional").font(DesignTokens.Font.label)
        }
        .foregroundStyle(DesignTokens.Color.warningText)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(DesignTokens.Color.warningSoft)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
    }
}

// Compact per-operation banner: clean/optimize can optionally escalate for
// system-level work, but the first run is unprivileged.
struct PreflightBanner: View {
    let item: SidebarItem
    @ObservedObject var permissions: PermissionsService

    var body: some View {
        let required = PermissionsService.requirements(for: item)
        if required.contains(.administrator) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignTokens.Color.tertiary)
                Text("No permissions required to start")
                    .font(DesignTokens.Font.captionStrong)
                    .foregroundStyle(DesignTokens.Color.secondary)
                Text("Admin password is optional for system-level items.")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    Image(systemName: "key.fill").font(.system(size: 10))
                    Text("Optional admin").font(DesignTokens.Font.label)
                }
                .foregroundStyle(DesignTokens.Color.warningText)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(DesignTokens.Color.warningSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DesignTokens.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        }
    }
}

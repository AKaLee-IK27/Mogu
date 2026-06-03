import SwiftUI

// Dedicated screen explaining Mogu's minimal, progressive permission model.
struct PermissionsView: View {
    @ObservedObject var permissions: PermissionsService
    @Environment(\.openURL) private var openURL
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    permissionCard
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 8)
                        .animation(DesignTokens.spring, value: appear)

                    fullDiskAccessCard
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 8)
                        .animation(DesignTokens.spring.delay(0.04), value: appear)
                }
                .padding(.horizontal, DesignTokens.Layout.contentHorizontalPadding)
                .padding(.top, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.xxxl)
            }
            .background(DesignTokens.Color.pageBackground)
        }
        .onAppear {
            permissions.refresh()
            withAnimation(DesignTokens.spring) { appear = true }
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Permissions")
                    .font(DesignTokens.Font.page)
                    .foregroundStyle(DesignTokens.Color.primary)
                Text("Start without grants; escalate only when you choose")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 11, weight: .semibold))
                Text("Minimal grants")
                    .font(DesignTokens.Font.captionStrong)
            }
            .foregroundStyle(DesignTokens.Color.successText)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Color.successSoft)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
        }
        .padding(.horizontal, DesignTokens.Layout.headerHorizontalPadding)
        .padding(.vertical, DesignTokens.Layout.headerVerticalPadding)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.successText)
                    .frame(width: 40, height: 40)
                    .background(DesignTokens.Color.successSoft)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text("No permissions required to start")
                            .font(DesignTokens.Font.section)
                            .foregroundStyle(DesignTokens.Color.primary)
                        Text("Starts safe")
                            .font(DesignTokens.Font.labelUppercase)
                            .foregroundStyle(DesignTokens.Color.successText)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Color.successSoft)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
                    }
                    Text("Clean, optimize, analyze, uninstall, and purge start unprivileged.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                }
                Spacer(minLength: DesignTokens.Spacing.md)
                adminBadge
            }

            Text("Administrator access is optional. Mogu asks for your password only when you choose to preview system-level cleanup or uninstall a protected app. Nothing is stored; nothing runs in the background.")
                .font(DesignTokens.Font.body)
                .foregroundStyle(DesignTokens.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignTokens.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge)
                .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
        )
        .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
    }

    private var fullDiskAccessCard: some View {
        let permission = PermissionKind.fullDiskAccess
        let status = permissions.status(for: permission)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                Image(systemName: permission.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.accentTint)
                    .frame(width: 40, height: 40)
                    .background(DesignTokens.Color.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text(permission.title)
                            .font(DesignTokens.Font.section)
                            .foregroundStyle(DesignTokens.Color.primary)
                        Text("Optional")
                            .font(DesignTokens.Font.labelUppercase)
                            .foregroundStyle(DesignTokens.Color.accentTint)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Color.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
                    }
                    Text("Scan quietly without macOS asking per protected folder.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                }
                Spacer(minLength: DesignTokens.Spacing.md)
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
        .padding(DesignTokens.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xLarge)
                .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
        )
        .shadow(color: DesignTokens.Shadow.card, radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
    }

    private func statusBadge(_ status: PermissionStatus) -> some View {
        let style = statusStyle(for: status)
        return HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: style.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(status.label)
                .font(DesignTokens.Font.labelUppercase)
        }
        .foregroundStyle(style.foreground)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
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
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "key.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("Admin optional")
                .font(DesignTokens.Font.labelUppercase)
        }
        .foregroundStyle(DesignTokens.Color.warningText)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
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
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.accentTint)
                    .frame(width: 28, height: 28)
                    .background(DesignTokens.Color.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("No permissions required to start")
                        .font(DesignTokens.Font.captionStrong)
                        .foregroundStyle(DesignTokens.Color.primary)
                    Text("Admin password is only requested for system-level cleanup or protected app uninstall.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                }
                Spacer(minLength: 0)
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Optional admin")
                        .font(DesignTokens.Font.labelUppercase)
                }
                .foregroundStyle(DesignTokens.Color.warningText)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(DesignTokens.Color.warningSoft)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                    .stroke(DesignTokens.Color.separatorLight, lineWidth: DesignTokens.Stroke.hairline)
            )
        }
    }
}

import SwiftUI

// Dedicated screen explaining each OS permission Mole may use, its live status
// (where detectable), and a link to grant it in System Settings.
struct PermissionsView: View {
    @ObservedObject var permissions: PermissionsService
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(DesignTokens.Color.separatorLight).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    intro
                        .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 12)

                    VStack(spacing: 12) {
                        ForEach(Array(PermissionKind.allCases.enumerated()), id: \.element.id) { i, kind in
                            permissionCard(kind)
                                .opacity(appear ? 1 : 0)
                                .offset(y: appear ? 0 : 8)
                                .animation(DesignTokens.stagger(i), value: appear)
                        }
                    }
                    .padding(.horizontal, 24)
                }
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
                Text("What Mole asks for, and why")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
            }
            Spacer()
            HeaderIconButton(systemName: "arrow.clockwise", help: "Re-check") {
                permissions.refresh()
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Color.accent)
                .padding(.top, 1)
            Text("Mole runs the open-source `mo` tools on your behalf. Some operations "
                 + "need macOS permissions. Grant only what you're comfortable with — "
                 + "operations degrade gracefully without them.")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    }

    private func permissionCard(_ kind: PermissionKind) -> some View {
        let status = permissions.status(for: kind)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: kind.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(DesignTokens.Color.accent)
                    .frame(width: 24)
                Text(kind.title)
                    .font(DesignTokens.Font.bodyStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                Spacer()
                statusBadge(status)
            }
            Text(kind.why)
                .font(DesignTokens.Font.caption)
                .foregroundStyle(DesignTokens.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if kind.settingsURL != nil {
                Button {
                    permissions.openSettings(for: kind)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.right.square").font(.system(size: 11))
                        Text("Open in System Settings").font(DesignTokens.Font.captionStrong)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Color.accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large))
    }

    private func statusBadge(_ status: PermissionStatus) -> some View {
        let (icon, tint): (String, SwiftUI.Color) = {
            switch status {
            case .granted:           return ("checkmark.circle.fill", DesignTokens.Color.successText)
            case .notGranted:        return ("exclamationmark.triangle.fill", DesignTokens.Color.warningText)
            case .promptsWhenNeeded: return ("hand.raised.fill", DesignTokens.Color.tertiary)
            case .unknown:           return ("questionmark.circle.fill", DesignTokens.Color.tertiary)
            }
        }()
        return HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11))
            Text(status.label).font(DesignTokens.Font.label)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill))
    }
}

// Compact per-operation banner: shows which permissions the current operation
// uses and their status, so the user knows what they're granting before acting.
struct PreflightBanner: View {
    let item: SidebarItem
    @ObservedObject var permissions: PermissionsService

    var body: some View {
        let required = PermissionsService.requirements(for: item)
        if !required.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignTokens.Color.tertiary)
                Text("Uses:")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(DesignTokens.Color.tertiary)
                ForEach(required) { kind in
                    permissionPill(kind)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DesignTokens.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        }
    }

    private func permissionPill(_ kind: PermissionKind) -> some View {
        let status = permissions.status(for: kind)
        let dot: SwiftUI.Color = {
            switch status {
            case .granted: return DesignTokens.Color.successText
            case .notGranted: return DesignTokens.Color.warning
            default: return DesignTokens.Color.tertiary
            }
        }()
        return Button {
            if kind.settingsURL != nil { permissions.openSettings(for: kind) }
        } label: {
            HStack(spacing: 5) {
                Circle().fill(dot).frame(width: 6, height: 6)
                Image(systemName: kind.icon).font(.system(size: 10))
                Text(kind.title).font(DesignTokens.Font.label)
            }
            .foregroundStyle(DesignTokens.Color.secondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(DesignTokens.Color.pageBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        }
        .buttonStyle(.plain)
        .help(kind.settingsURL != nil ? "Open System Settings — \(kind.title)" : kind.why)
    }
}

import SwiftUI

// MARK: - Section headers

/// A Settings section header with its icon beside the title — one consistent look across
/// every settings page, in place of bare text headers.
struct SettingsSectionHeader: View {
    let icon: String
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: 6) {
            IconView(icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            Text(title)
        }
    }
}

// MARK: - Icon tile

/// The icon tile every Settings row leads with: glass on the platforms that have it, a
/// plain fill where they don't, over `IconView` so icon packs reach it like everywhere else.
struct SettingsIconTile: View {
    let icon: String
    var size: CGFloat = 28
    var cornerRadius: CGFloat = 7

    var body: some View {
        ZStack {
            IconView(icon)
                .font(.system(size: 13, weight: .semibold))
                // Adapts to the appearance: white vanished against light mode's pale glass.
                .foregroundStyle(.primary)
        }
        .frame(width: size, height: size)
        .glassChrome(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            enabled: true,
            tint: nil,
            off: .ultraThinMaterial
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        )
    }
}

// MARK: - Rows

/// A Settings toggle as a full row: the same icon tile the nav rows lead with, the title
/// beside it, the switch at the end — one look for every page. `switchTint` stays the one
/// place the switch's colour is set.
struct SettingsToggleRow: View {
    let icon: String
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                SettingsIconTile(icon: icon)
                Text(title)
                    .font(.body)
            }
        }
        .switchTint()
    }
}

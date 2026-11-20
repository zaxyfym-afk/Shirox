import SwiftUI

// MARK: - Section headers

/// A Settings section header: the icon in a small accent tile, the title as a bold tracked
/// caption — one consistent look across every settings page, in place of bare text headers.
struct SettingsSectionHeader: View {
    let icon: String
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: 8) {
            IconView(icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.accentColor)
                )
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
        .textCase(.uppercase)
        .padding(.top, 4)
    }
}

// MARK: - Icon tile

/// The icon tile every Settings row leads with: a tinted squircle over `IconView`, so icon
/// packs reach it like everywhere else, with a hairline that keeps it crisp on glass.
struct SettingsIconTile: View {
    let icon: String
    var size: CGFloat = 28
    var cornerRadius: CGFloat = 7
    /// The tile's accent: the row's own, so a section can group by colour.
    var tint: Color = .accentColor

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint.opacity(0.14))
            IconView(icon)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
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
    var tint: Color = .accentColor
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                SettingsIconTile(icon: icon, tint: tint)
                Text(title)
                    .font(.body)
            }
        }
        .switchTint()
    }
}

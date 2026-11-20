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

// MARK: - Page intro

/// A settings page's opening card: the icon it was opened with, its name, and one line on
/// what it's for — every page says what it does before its first section.
struct SettingsPageIntro: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IconView(icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(title)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

/// The intro as a clear-backed list row, so it sits above a page's sections without the
/// grouped background doubling up behind the card.
struct SettingsIntroRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        SettingsPageIntro(icon: icon, title: title, subtitle: subtitle)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 2, trailing: 16))
    }
}

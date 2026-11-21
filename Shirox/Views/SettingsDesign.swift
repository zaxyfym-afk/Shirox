import SwiftUI

// MARK: - Page tint

/// The accent a settings page carries: set by `SettingsList`, read by every header, tile and
/// row that doesn't ask for a colour of its own. One environment value, so all of a page's
/// sections take the page's colour without a call-site change.
private struct SettingsSectionTintKey: EnvironmentKey {
    static let defaultValue: Color = .accentColor
}

extension EnvironmentValues {
    var settingsSectionTint: Color {
        get { self[SettingsSectionTintKey.self] }
        set { self[SettingsSectionTintKey.self] = newValue }
    }
}

// MARK: - Page scaffold

/// A Settings page's list, with the page's own chrome: an optional hero header opening the
/// list — the page's icon in a gradient tile, its name, and a one-line description of what
/// the page decides — and every section carded over a tinted grouped background. The one
/// container every settings page builds on, so a redesign lands everywhere at once.
///
/// A Mac keeps the grouped form it already looks right in; the hero renders above the form.
struct SettingsList<Content: View>: View {
    /// The page's accent: the hero tile and every section header that doesn't carry its own.
    var tint: Color = .accentColor
    /// The hero: the page's icon, title and subtitle. Nil keeps the page headerless —
    /// the root, whose profile card opens it instead.
    var heroIcon: String?
    var heroTitle: LocalizedStringKey?
    var heroSubtitle: LocalizedStringKey?
    @ViewBuilder var content: Content

    var body: some View {
        #if os(macOS)
        Group {
            if let heroIcon, let heroTitle {
                VStack(spacing: 0) {
                    SettingsPageHero(icon: heroIcon, title: heroTitle, subtitle: heroSubtitle, tint: tint)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Form { content }
                        .formStyle(.grouped)
                }
            } else {
                Form { content }
                    .formStyle(.grouped)
            }
        }
        #else
        List {
            if let heroIcon, let heroTitle {
                Section {
                    SettingsPageHero(icon: heroIcon, title: heroTitle, subtitle: heroSubtitle, tint: tint)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 6, trailing: 16))
                }
            }
            content
        }
        .listStyle(.insetGrouped)
        .tint(tint)
        .environment(\.settingsSectionTint, tint)
        .applySettingsBackground(tint: tint)
        #endif
    }
}

#if !os(macOS)
/// The page's own background: the system's grouped base, tinted by the page's accent so
/// every subpage reads as its own room. iOS 15 keeps the plain grouped colour — the
/// scroll-content background modifier is 16's — and the tint wash stays off it.
extension View {
    @ViewBuilder
    fileprivate func applySettingsBackground(tint: Color) -> some View {
        if #available(iOS 16.4, tvOS 16.4, *) {
            self
                .scrollContentBackground(.hidden)
                .background(
                    tint.opacity(0.10)
                        .overlay(
                            LinearGradient(colors: [tint.opacity(0.14), Color.clear],
                                           startPoint: .top, endPoint: .center)
                                .ignoresSafeArea()
                        )
                        .ignoresSafeArea()
                )
        } else {
            self
        }
    }
}
#endif

// MARK: - Hero

/// The header block every settings subpage opens with: the page's icon in a gradient tile,
/// the page's name, and one line saying what the page is for.
struct SettingsPageHero: View {
    let icon: String
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        LinearGradient(colors: [tint.opacity(0.85), tint.opacity(0.45)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        IconView(icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                    )
                    .shadow(color: tint.opacity(0.35), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title2.weight(.bold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 6)
    }
}

// MARK: - Section headers

/// A Settings section header: the icon in a small accent tile, the title as a bold tracked
/// caption — one consistent look across every settings page, in place of bare text headers.
/// The tile takes the section's own colour when one is given, else the page's.
struct SettingsSectionHeader: View {
    let icon: String
    let title: LocalizedStringKey
    /// The section's own colour; nil takes the page's from the environment.
    var tint: Color?

    @Environment(\.settingsSectionTint) private var pageTint

    var body: some View {
        let color = tint ?? pageTint
        HStack(spacing: 8) {
            IconView(icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(
                            LinearGradient(colors: [color.opacity(0.95), color.opacity(0.6)],
                                           startPoint: .top, endPoint: .bottom)
                        )
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
    /// The tile's accent: the row's own when given, else the page's from the environment.
    var tint: Color?

    @Environment(\.settingsSectionTint) private var pageTint

    var body: some View {
        let color = tint ?? pageTint
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(colors: [color.opacity(0.20), color.opacity(0.10)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            IconView(icon)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(color.opacity(0.18), lineWidth: 0.5)
        )
    }
}

// MARK: - Rows

/// A settings navigation row: the icon tile the row leads with, the title, and an optional
/// value line. It draws NO chevron of its own — a `NavigationLink` row already carries the
/// system's, and drawing a second one beside it is exactly the doubled arrows the user
/// called out; rows that navigate without a NavigationLink (a Button pushing a page, a
/// Menu) pass `showsChevron: true` for the one arrow they do want.
struct SettingsNavRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    /// The row tile's accent: the row's own when given, else the page's.
    var tint: Color?
    var showsChevron: Bool = false

    @Environment(\.settingsSectionTint) private var pageTint

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconTile(icon: icon, size: 34, cornerRadius: 9, tint: tint ?? pageTint)

            Text(title)
                .font(.body)

            Spacer()

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            if showsChevron {
                IconView("chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}

/// A tap-down for the rows that are plain Buttons — a pressed scale and fade, so custom
/// navigation rows answer the touch the way a system row does.
struct SettingsRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A Settings toggle as a full row: the same icon tile the nav rows lead with, the title
/// beside it, the switch at the end — one look for every page. `switchTint` stays the one
/// place the switch's colour is set.
struct SettingsToggleRow: View {
    let icon: String
    let title: LocalizedStringKey
    var tint: Color?
    @Binding var isOn: Bool

    @Environment(\.settingsSectionTint) private var pageTint

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                SettingsIconTile(icon: icon, tint: tint ?? pageTint)
                Text(title)
                    .font(.body)
            }
        }
        .switchTint()
    }
}

// MARK: - Sections

/// A settings section with the design system's header: the same shape as `Section("…")`,
/// so a page's bare headers become one consistent, tiled look with a one-line swap.
struct SettingsSection<Content: View>: View {
    let icon: String
    let titleKey: LocalizedStringKey
    /// The section's own accent, when it wants one; else the page's.
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        Section { content } header: {
            SettingsSectionHeader(icon: icon, title: titleKey, tint: tint)
        }
    }
}

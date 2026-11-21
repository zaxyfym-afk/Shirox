import SwiftUI

// MARK: - Page scaffold

/// A Settings page's list. The one container every settings page builds on, so a redesign
/// lands everywhere at once — and this pass made it deliberately plain: the system's own
/// inset-grouped list, the standard background, no page colour, no hero header. The
/// navigation title carries the page's name, as a system page does.
///
/// A Mac keeps the grouped form it already looks right in.
struct SettingsList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        #if os(macOS)
        Form { content }
            .formStyle(.grouped)
        #else
        List { content }
            .listStyle(.insetGrouped)
        #endif
    }
}

// MARK: - Section headers

/// A Settings section header: plain text, the system's own look. The tiled icon-and-name
/// headers this replaced drew a decorated block above every group; the title alone says
/// what the section is.
struct SettingsSectionHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
    }
}

// MARK: - Rows

/// A settings navigation row: the icon, the title, and an optional value line. The icon
/// rides bare — monochrome, no tile behind it — the way a system row's does. It draws NO
/// chevron of its own: a `NavigationLink` row already carries the system's, and drawing a
/// second one beside it is exactly the doubled arrows the user called out; rows that
/// navigate without a NavigationLink (a Button pushing a page, a Menu) pass
/// `showsChevron: true` for the one arrow they do want.
struct SettingsNavRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            IconView(icon)
                .font(.body.weight(.regular))
                .foregroundStyle(.secondary)
                .frame(width: 26)

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

/// A Settings toggle as a full row: the icon, the title beside it, the switch at the end —
/// one look for every page. `switchTint` keeps the switch on the app's chosen accent.
struct SettingsToggleRow: View {
    let icon: String
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                IconView(icon)
                    .font(.body.weight(.regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 26)
                Text(title)
                    .font(.body)
            }
        }
        .switchTint()
    }
}

// MARK: - Sections

/// A settings section with a plain text header: the same shape as `Section("…")`, so a
/// page's decorated headers become one consistent, plain look with a one-line swap.
struct SettingsSection<Content: View>: View {
    let titleKey: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        Section { content } header: {
            SettingsSectionHeader(titleKey)
        }
    }
}

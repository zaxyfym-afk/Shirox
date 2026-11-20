import SwiftUI

/// Settings ▸ Customization: everything that shapes how Shirox looks and behaves, in one
/// place — appearance, layout, episodes, and the schedule's starting point. Every control
/// here is real and saved; what a page owns outright (player, subtitles) is linked to
/// rather than duplicated.
struct CustomizationSettingsView: View {
    @AppStorage(AppColorScheme.key) private var colorScheme = AppColorScheme.system.rawValue
    @AppStorage(AppTint.key) private var tint = AppTint.monochrome.rawValue
    @AppStorage(DetailLayoutSetting.cinematicHomeKey) private var cinematicHomeLayout = true
    @AppStorage(DetailLayoutSetting.cinematicKey) private var cinematicDetailLayout = true
    @AppStorage(CardTitleSetting.hiddenKey) private var hideCardTitles = false
    @AppStorage("hideFillerEpisodes") private var hideFillerEpisodes = false
    @AppStorage(UpcomingCalendarViewModel.libraryOnlyDefaultKey) private var scheduleStartsInLibrary = false

    var body: some View {
        SettingsList {

            Section {
                Picker("settings.appearance", selection: $colorScheme) {
                    ForEach(AppColorScheme.allCases) { scheme in
                        Text(scheme.title).tag(scheme.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .retinted(tint)

                TintColorRow(tint: $tint)
            } header: {
                SettingsSectionHeader(icon: "circle", title: "settings.appearance")
            } footer: {
                Text("settings.buttons_switches_and_highlights_monochrome")
            }

            if DetailLayoutSetting.isOffered {
                Section {
                    Toggle("settings.cinematic_home", isOn: $cinematicHomeLayout)
                        .switchTint()
                    Toggle("settings.cinematic_detail_pages", isOn: $cinematicDetailLayout)
                        .switchTint()
                    Toggle("settings.hide_titles_on_cards", isOn: $hideCardTitles)
                        .switchTint()
                } header: {
                    SettingsSectionHeader(icon: "square.grid.3x2", title: "settings.layout")
                } footer: {
                    Text("settings.cinematic_note")
                }
            }

            Section {
                Toggle("settings.hide_filler_episodes", isOn: $hideFillerEpisodes)
                    .switchTint()
                Text("settings.hide_filler_note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                SettingsSectionHeader(icon: "list.bullet.rectangle", title: "common.episodes")
            }

            Section {
                Toggle("settings.schedule_starts_in_library", isOn: $scheduleStartsInLibrary)
                    .switchTint()
                Text("settings.schedule_starts_note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                SettingsSectionHeader(icon: "calendar", title: "shared.upcoming")
            }

            Section {
                NavigationLink {
                    PlayerSettingsView()
                } label: {
                    SettingsNavRow(icon: "play.tv", title: String(localized: "settings.player"))
                }
                NavigationLink {
                    SubtitleSettingsPage()
                } label: {
                    SettingsNavRow(icon: "captions.bubble", title: String(localized: "settings.subtitles"))
                }
                #if !os(tvOS)
                NavigationLink {
                    TabBarCustomizationView()
                } label: {
                    SettingsNavRow(icon: "square.stack.3d.up", title: String(localized: "settings.customize_tabs"))
                }
                #endif
            } header: {
                SettingsSectionHeader(icon: "ellipsis.circle", title: "settings.more_to_customize")
            } footer: {
                Text("settings.more_to_customize_note")
            }
        }
        .softScrollEdges()
        .navigationTitle("settings.customization")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

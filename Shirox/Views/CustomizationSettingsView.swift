import SwiftUI

/// Settings ▸ Customization: everything that shapes how Shirox looks — appearance and app
/// icon, layout, episodes, and the schedule's starting point. Every control here is real
/// and saved; appearance lives on this page alone, and the pages that own the rest (player,
/// subtitles, tabs) each have their one door on the root.
struct CustomizationSettingsView: View {
    @AppStorage(AppColorScheme.key) private var colorScheme = AppColorScheme.system.rawValue
    @AppStorage(AppTint.key) private var tint = AppTint.monochrome.rawValue
    @AppStorage(DetailLayoutSetting.cinematicHomeKey) private var cinematicHomeLayout = true
    @AppStorage(DetailLayoutSetting.cinematicKey) private var cinematicDetailLayout = true
    @AppStorage("hideFillerEpisodes") private var hideFillerEpisodes = false
    @AppStorage(UpcomingCalendarViewModel.libraryOnlyDefaultKey) private var scheduleStartsInLibrary = false
    #if os(iOS) && !targetEnvironment(macCatalyst)
    @State private var appIcon = UIApplication.shared.alternateIconName
    @State private var appIconError: String?
    #endif

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

                #if os(iOS) && !targetEnvironment(macCatalyst)
                Picker("settings.app_icon", selection: appIconSelection) {
                    ForEach(AppIconOption.all) { option in
                        Text(option.title).tag(option.name)
                    }
                }
                .pickerStyle(.menu)
                .retinted(tint)
                #endif

                TintColorRow(tint: $tint)

                NavigationLink {
                    IconPacksSettingsView()
                } label: {
                    LabeledContent("settings.icon_packs") {
                        Text(IconPackStore.shared.selected?.pack.name ?? String(localized: "settings.sf_symbols"))
                            .foregroundStyle(.secondary)
                    }
                }
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
        }
        .softScrollEdges()
        .navigationTitle("settings.customization")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(iOS) && !targetEnvironment(macCatalyst)
        .alert("settings.couldnt_change_icon",
               isPresented: Binding(get: { appIconError != nil }, set: { if !$0 { appIconError = nil } })) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(appIconError ?? "")
        }
        #endif
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    /// Picking an icon asks iOS to switch to it; the picker only moves once it has.
    private var appIconSelection: Binding<String?> {
        Binding(get: { appIcon }, set: { name in
            guard name != appIcon else { return }
            guard UIApplication.shared.supportsAlternateIcons else {
                appIconError = String(localized: "settings.this_device_doesnt_support_changing")
                return
            }
            UIApplication.shared.setAlternateIconName(name) { error in
                DispatchQueue.main.async {
                    if let error {
                        appIconError = error.localizedDescription
                    } else {
                        appIcon = name
                    }
                }
            }
        })
    }
    #endif
}

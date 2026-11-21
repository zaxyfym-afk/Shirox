import SwiftUI

/// Settings ▸ Customization: everything that shapes how Shirox looks. The theme leads as
/// the real Kavsoft appearance picker — the animated sky preview and the sliding capsule,
/// the same component onboarding uses — over the tint swatches, then the app's icon and
/// icon packs, then the layout toggles. Appearance lives on this page alone; the pages that
/// own the rest (player, subtitles, tabs) each have their one door on the root.
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
    @State private var showIconPicker = false
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        SettingsList {
            themeSection
            iconSection
            if DetailLayoutSetting.isOffered {
                layoutSection
            }
            detailsSection
        }
        .softScrollEdges()
        .navigationTitle("settings.customization")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(iOS) && !targetEnvironment(macCatalyst)
        .sheet(isPresented: $showIconPicker, onDismiss: { appIcon = UIApplication.shared.alternateIconName }, content: {
            if #available(iOS 26, *) {
                AppIconPickerSheet()
            }
        })
        .alert("settings.couldnt_change_icon",
               isPresented: Binding(get: { appIconError != nil }, set: { if !$0 { appIconError = nil } })) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(appIconError ?? "")
        }
        #endif
    }

    // MARK: Theme

    /// Appearance as the interactive Kavsoft picker, inline: the animated sky turns night
    /// or day with the choice and the segmented capsule slides under it, exactly as
    /// onboarding presents it. The pick applies the moment it's tapped. Below iOS 17 the
    /// component's own availability ladder keeps it working; macOS and tvOS keep a menu.
    private var themeSection: some View {
        Section {
            #if os(iOS) && !targetEnvironment(macCatalyst)
            KavsoftThemePicker(
                value: Binding(
                    get: { AppColorScheme(rawValue: colorScheme) ?? .system },
                    set: { colorScheme = $0.rawValue }
                ),
                envColorScheme: systemScheme
            )
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .listRowBackground(Color.clear)
            #else
            Picker("settings.appearance", selection: $colorScheme) {
                ForEach(AppColorScheme.allCases) { scheme in
                    Text(scheme.title).tag(scheme.rawValue)
                }
            }
            .pickerStyle(.menu)
            .retinted(tint)
            #endif

            TintColorRow(tint: $tint)
        } header: {
            SettingsSectionHeader("settings.appearance")
        } footer: {
            Text("settings.buttons_switches_and_highlights_monochrome")
        }
    }

    // MARK: Icon

    private var iconSection: some View {
        Section {
            #if os(iOS) && !targetEnvironment(macCatalyst)
            if #available(iOS 26, *) {
                Button {
                    showIconPicker = true
                } label: {
                    LabeledContent("settings.app_icon") {
                        Text(appIconTitle)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                appIconPicker
            }
            #endif

            NavigationLink {
                IconPacksSettingsView()
            } label: {
                LabeledContent("settings.icon_packs") {
                    Text(IconPackStore.shared.selected?.pack.name ?? String(localized: "settings.sf_symbols"))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Layout

    private var layoutSection: some View {
        Section {
            Toggle("settings.cinematic_home", isOn: $cinematicHomeLayout)
                .switchTint()
            Toggle("settings.cinematic_detail_pages", isOn: $cinematicDetailLayout)
                .switchTint()
        } header: {
            SettingsSectionHeader("settings.layout")
        } footer: {
            Text("settings.cinematic_note")
        }
    }

    // MARK: Details

    /// The two content-level choices: filler episodes on the detail page, and where the
    /// schedule opens.
    private var detailsSection: some View {
        Section {
            Toggle("settings.hide_filler_episodes", isOn: $hideFillerEpisodes)
                .switchTint()
            Toggle("settings.schedule_starts_in_library", isOn: $scheduleStartsInLibrary)
                .switchTint()
        } header: {
            SettingsSectionHeader("settings.details")
        }
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    private var appIconPicker: some View {
        Picker("settings.app_icon", selection: appIconSelection) {
            ForEach(AppIconOption.all) { option in
                Text(option.title).tag(option.name)
            }
        }
        .pickerStyle(.menu)
        .retinted(tint)
    }

    private var appIconTitle: String {
        AppIconOption(name: appIcon).title
    }

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

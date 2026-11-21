import SwiftUI

// Only TMDB can be pointed at a custom base URL so far. AniList, Jikan and MyAnimeList are
// blocked in some regions too and could get the same kind of rewrite `TMDBHosts` does.

/// Expert settings for regions where TMDB, DNS or more is blocked, kept out of the way at
/// the end of Settings. Built as a bench, not a list: the connection test sits up top as a
/// full-width strip with its results, and each area below — TMDB proxies, encrypted DNS,
/// the traffic proxy, the User-Agent, the reset — is one collapsible panel whose header
/// always shows whether it's in use, so the page's state reads before anything is opened.
/// Every setting, field and validation the page had is preserved inside its panel.
struct AdvancedNetworkSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NetworkTestPanel()
                NetworkPanel(
                    title: "TMDB", icon: "photo.on.rectangle",
                    state: TMDBProxyPanel.Content.stateLabel
                ) {
                    TMDBProxyPanel.Content()
                }
                NetworkPanel(
                    titleKey: "settings.dns_over_https", icon: "lock.shield",
                    state: SecureDNSPanel.Content.stateLabel
                ) {
                    SecureDNSPanel.Content()
                }
                NetworkPanel(
                    titleKey: "settings.proxy", icon: "network.badge.shield.half.filled",
                    state: ProxyPanel.Content.stateLabel
                ) {
                    ProxyPanel.Content()
                }
                NetworkPanel(
                    titleKey: "settings.user_agent", icon: "globe",
                    state: UserAgentPanel.Content.stateLabel
                ) {
                    UserAgentPanel.Content()
                }
                NetworkResetPanel()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .softScrollEdges()
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("settings.advanced_network")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Panel

/// One collapsible area: the header row carries the area's name and whether it's in use;
/// opening it reveals the controls. The state label is written by the area itself, so the
/// collapsed page never lies.
private struct NetworkPanel<Content: View>: View {
    var titleKey: LocalizedStringKey?
    var titleText: String?
    let icon: String
    let state: (label: String, active: Bool)
    @ViewBuilder var content: () -> Content

    init(title: String, icon: String, state: @autoclosure () -> (label: String, active: Bool),
         @ViewBuilder content: @escaping () -> Content) {
        self.titleKey = nil
        self.titleText = title
        self.icon = icon
        self.state = state()
        self.content = content
    }

    init(titleKey: LocalizedStringKey, icon: String, state: @autoclosure () -> (label: String, active: Bool),
         @ViewBuilder content: @escaping () -> Content) {
        self.titleKey = titleKey
        self.titleText = nil
        self.icon = icon
        self.state = state()
        self.content = content
    }

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    IconView(icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(state.active ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.secondary))
                        .frame(width: 28)

                    if let titleText {
                        Text(verbatim: titleText)
                            .font(.body.weight(.semibold))
                    } else {
                        Text(titleKey ?? "settings.proxy")
                            .font(.body.weight(.semibold))
                    }

                    Spacer(minLength: 8)

                    Text(verbatim: state.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(state.active ? Color.primary.opacity(0.10) : Color.primary.opacity(0.05))
                        )
                        .foregroundStyle(state.active ? Color.primary : Color.secondary)

                    IconView("chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// A toggle's explanation as a note under it. Each panel shows its explanation while its
/// toggle is off; once it's on, the explanation sits above the fields it belongs to.
private func noteRow(_ text: String) -> some View {
    Text(text)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
}

/// A text field for an address: no autocorrection or capitals, the URL keyboard.
private func addressField(_ title: String, text: Binding<String>, prompt: String? = nil) -> some View {
    TextField(title, text: text, prompt: prompt.map { Text($0) })
        .autocorrectionDisabled()
        #if os(iOS)
        .textInputAutocapitalization(.never)
        .keyboardType(.URL)
        #endif
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
}

// MARK: - TMDB

private struct TMDBProxyPanel {
    struct Content: View {
        @AppStorage(TMDBHostSettings.useProxiesKey) private var useProxies = false
        @AppStorage(TMDBHostSettings.apiBaseKey) private var apiBase = ""
        @AppStorage(TMDBHostSettings.imageBaseKey) private var imageBase = ""

        /// What the panel's header pill says, from the same keys the panel edits.
        static var stateLabel: (label: String, active: Bool) {
            let on = UserDefaults.standard.bool(forKey: TMDBHostSettings.useProxiesKey)
            return (on ? String(localized: "settings.in_use") : String(localized: "settings.off"),
                    on)
        }

        var body: some View {
            Toggle("settings.use_custom_tmdb_proxies", isOn: $useProxies)
                .switchTint()
                .onChangeOf(useProxies) { isOn in
                    guard isOn else { return }
                    if apiBase.isEmpty { apiBase = TMDBHostSettings.defaultAPIBase }
                    if imageBase.isEmpty { imageBase = TMDBHostSettings.defaultImageBase }
                }
            if useProxies {
                noteRow(Self.note)
                addressField(String(localized: "settings.custom_api_base_url"), text: $apiBase, prompt: TMDBHostSettings.defaultAPIBase)
                addressField(String(localized: "settings.custom_image_base_url"), text: $imageBase, prompt: TMDBHostSettings.defaultImageBase)
                Text(verbatim: Self.validityFooter(apiBase: apiBase, imageBase: imageBase))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        private static let note = String(localized: "settings.routes_tmdb_traffic_through_your")

        private static func validityFooter(apiBase: String, imageBase: String) -> String {
            let explanation = String(localized: "settings.replaces_https_api_themoviedb_org")
            let apiValid = TMDBHostSettings.validBase(apiBase) != nil
            let imageValid = TMDBHostSettings.validBase(imageBase) != nil
            switch (apiValid, imageValid) {
            case (true, true):   return explanation
            case (false, true):  return String(localized: "settings.no_valid_api_address_yet") + " " + explanation
            case (true, false):  return String(localized: "settings.no_valid_image_address_yet") + " " + explanation
            case (false, false): return String(localized: "settings.no_valid_api_or_image") + " " + explanation
            }
        }
    }
}

// MARK: - DNS

private struct SecureDNSPanel {
    struct Content: View {
        @AppStorage(SecureDNSSettings.enabledKey) private var secureDNS = false
        @AppStorage(SecureDNSSettings.serverURLKey) private var serverURL = ""
        @AppStorage(SecureDNSSettings.serverAddressesKey) private var serverAddresses = ""

        static var stateLabel: (label: String, active: Bool) {
            let on = UserDefaults.standard.bool(forKey: SecureDNSSettings.enabledKey)
            return (on ? String(localized: "settings.in_use") : String(localized: "settings.off"),
                    on)
        }

        var body: some View {
            Toggle("settings.encrypted_dns", isOn: $secureDNS)
                .switchTint()
                .onChangeOf(secureDNS) { isOn in
                    guard isOn else { return }
                    if serverURL.isEmpty { serverURL = SecureDNSSettings.defaultServerURL }
                    if serverAddresses.isEmpty { serverAddresses = SecureDNSSettings.defaultServerAddresses }
                }
            if secureDNS {
                noteRow(Self.note)
                addressField(String(localized: "settings.server_url"), text: $serverURL, prompt: SecureDNSSettings.defaultServerURL)
                addressField(String(localized: "settings.server_ip_addresses"), text: $serverAddresses, prompt: SecureDNSSettings.defaultServerAddresses)
                Text(verbatim: Self.usabilityFooter(serverURL: serverURL, serverAddresses: serverAddresses))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        private static let note = String(localized: "settings.looks_up_servers_over_encrypted")

        private static func usabilityFooter(serverURL: String, serverAddresses: String) -> String {
            let explanation = String(localized: "settings.cloudflare_https_cloudflare_dns_com")
            let usable = SecureDNSSettings(enabled: true, serverURL: serverURL, serverAddresses: serverAddresses).resolver != nil
            return usable ? explanation : String(localized: "settings.needs_https_url_footer") + explanation
        }
    }
}

// MARK: - Proxy

private struct ProxyPanel {
    struct Content: View {
        @AppStorage(NetworkProxySettings.enabledKey) private var enabled = false
        @AppStorage(NetworkProxySettings.kindKey) private var kindValue = NetworkProxySettings.Kind.socks5.rawValue
        @AppStorage(NetworkProxySettings.hostKey) private var host = ""
        @AppStorage(NetworkProxySettings.portKey) private var port = ""
        @AppStorage(NetworkProxySettings.usernameKey) private var username = ""
        /// In the Keychain, not in `@AppStorage`.
        @State private var password = ProxyKeychain.read(NetworkProxySettings.passwordAccount) ?? ""

        private var kind: NetworkProxySettings.Kind { NetworkProxySettings.Kind(rawValue: kindValue) ?? .socks5 }

        static var stateLabel: (label: String, active: Bool) {
            let on = UserDefaults.standard.bool(forKey: NetworkProxySettings.enabledKey)
            return (on ? String(localized: "settings.in_use") : String(localized: "settings.off"),
                    on)
        }

        var body: some View {
            Toggle("settings.proxy_all_traffic", isOn: $enabled)
                .switchTint()
                .onChangeOf(enabled) { isOn in
                    if isOn, port.isEmpty { port = kind.defaultPort }
                }
            if enabled {
                noteRow(Self.note)
                Picker("settings.type", selection: $kindValue) {
                    ForEach(NetworkProxySettings.Kind.allCases, id: \.rawValue) { kind in
                        Text(kind.title).tag(kind.rawValue)
                    }
                }
                .onChangeOf(kindValue) { _ in
                    // A port that was the other type's default follows the type.
                    if NetworkProxySettings.Kind.allCases.contains(where: { $0.defaultPort == port }) { port = kind.defaultPort }
                }
                addressField(String(localized: "settings.host"), text: $host, prompt: "proxy.example.com")
                TextField("settings.port", text: $port, prompt: Text(kind.defaultPort))
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                addressField(String(localized: "settings.username"), text: $username, prompt: String(localized: "settings.optional"))
                SecureField("settings.password", text: $password, prompt: Text("settings.optional"))
                    .onChangeOf(password) { ProxyKeychain.save($0, account: NetworkProxySettings.passwordAccount) }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                Text(verbatim: Self.completenessFooter(host: host, port: port))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        private static var note: String {
            NetworkProxy.isSupported
                ? String(localized: "settings.sends_app_module_and_web")
                : String(localized: "settings.a_proxy_for_all_traffic")
        }

        private static func completenessFooter(host: String, port: String) -> String {
            let settings = NetworkProxySettings(enabled: true, kind: NetworkProxySettings.Kind.socks5, host: host, port: port,
                                                username: "", password: "")
            let explanation = String(localized: "settings.the_password_is_kept_in")
            return settings.server == nil
                ? String(localized: "settings.needs_a_host_and_port") + explanation
                : explanation
        }
    }
}

// MARK: - User-Agent

private struct UserAgentPanel {
    struct Content: View {
        @AppStorage(NetworkUserAgent.enabledKey) private var enabled = false
        @AppStorage(NetworkUserAgent.valueKey) private var userAgent = ""

        static var stateLabel: (label: String, active: Bool) {
            let on = UserDefaults.standard.bool(forKey: NetworkUserAgent.enabledKey)
            return (on ? String(localized: "settings.in_use") : String(localized: "settings.off"),
                    on)
        }

        var body: some View {
            Toggle("settings.custom_user_agent", isOn: $enabled)
                .switchTint()
                .onChangeOf(enabled) { isOn in
                    if isOn, userAgent.isEmpty { userAgent = NetworkUserAgent.standard }
                }
            if enabled {
                noteRow(Self.note)
                addressField("User-Agent", text: $userAgent, prompt: NetworkUserAgent.standard)
                Button("settings.use_shiroxs_own") { userAgent = NetworkUserAgent.standard }
                    .disabled(userAgent == NetworkUserAgent.standard)
            }
        }

        private static let note = String(localized: "settings.the_browser_shirox_claims_to")
    }
}

// MARK: - Test

/// The bench's headline: one full-width strip that runs every service check and prints
/// each result with its own icon, then a one-line verdict underneath.
private struct NetworkTestPanel: View {
    @State private var checks: [NetworkCheck] = []
    @State private var isTesting = false

    private var verdict: String? {
        guard !checks.isEmpty, !isTesting else { return nil }
        let failed = checks.filter { $0.outcome == .failed }.count
        let skipped = checks.filter { $0.outcome == .skipped }.count
        if failed == 0, skipped == 0 { return String(localized: "settings.all_checks_passed") }
        if failed == 0 { return String(localized: "settings.checks_reachable_but_skipped") }
        return String(localized: "settings.checks_failed_count \(failed)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: test) {
                HStack(spacing: 10) {
                    if isTesting {
                        ProgressView()
                            .tint(.primary)
                    } else {
                        IconView("stethoscope")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(isTesting ? String(localized: "settings.testing_connection") : String(localized: "settings.test_connection"))
                        .font(.body.weight(.bold))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.primary.opacity(0.85))
                )
                .foregroundStyle(.white)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isTesting)

            if let verdict {
                Text(verbatim: verdict)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(checks) { check in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        IconView(icon(for: check.outcome))
                            .foregroundStyle(color(for: check.outcome))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.title)
                                .font(.subheadline.weight(.medium))
                            Text(check.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Text("settings.checks_tmdbs_api_and_images")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    func test() {
        isTesting = true
        checks = []
        Task {
            let diagnostics = NetworkDiagnostics(dnsInUse: SecureDNS.active, proxyInUse: NetworkProxy.active)
            checks = await diagnostics.run()
            isTesting = false
        }
    }

    private func icon(for outcome: NetworkCheck.Outcome) -> String {
        switch outcome {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        case .skipped: return "minus.circle"
        }
    }

    private func color(for outcome: NetworkCheck.Outcome) -> Color {
        switch outcome {
        case .passed: return .green
        case .failed: return .red
        case .skipped: return .secondary
        }
    }
}

// MARK: - Reset

private struct NetworkResetPanel: View {
    @State private var confirm = false
    @State private var isResetting = false
    @State private var didReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(role: .destructive) {
                confirm = true
            } label: {
                HStack {
                    Text(didReset ? String(localized: "settings.network_state_reset") : String(localized: "settings.reset_network_state"))
                    Spacer()
                    if isResetting { ProgressView() }
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red.opacity(0.10))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .disabled(isResetting)

            Text("settings.clears_cookies_website_data_the")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .confirmationDialog("settings.reset_network_state_confirm", isPresented: $confirm, titleVisibility: .visible) {
            Button("common.reset", role: .destructive, action: reset)
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.signs_shirox_out_of_websites")
        }
    }

    private func reset() {
        isResetting = true
        Task {
            await NetworkReset.resetAll()
            isResetting = false
            didReset = true
        }
    }
}

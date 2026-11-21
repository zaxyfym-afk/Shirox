import SwiftUI

/// The anime detail page's module control, standing where the external-links button used
/// to be. One menu: the installed modules to switch between — the one serving this page
/// marked — and the way into the Module Store. The module's site and the trackers' pages
/// keep a section here, so what the links button did is preserved, one level down.
///
/// Choosing a module really switches: the manager selects it, the page reloads its detail
/// and episodes from that module, and the choice persists as the app's active module.
/// While the page's data is in flight the menu still opens; the switch itself waits.
struct ModuleSwitcherMenu: View {
    /// The module id this page was opened with (a deep link can name one explicitly).
    let pageModuleId: String?
    /// The page's href on its module's site, for the links section.
    let href: String?
    /// Re-run when a module is chosen: the page reloads from the new source.
    let onSwitch: () -> Void
    /// Opens the Module Store. A push, made by the page hosting the menu — a Menu's
    /// items can't carry a NavigationLink on every iOS this app ships to.
    let onOpenStore: () -> Void
    /// The trackers' pages, listed under the module's own site.
    var trackers: [WebLink] = []

    @ObservedObject private var moduleManager = ModuleManager.shared
    @Environment(\.openURL) private var openURL

    /// The module actually serving this page: the page's own when it names one, else the
    /// app's active module.
    private var currentModule: ModuleDefinition? {
        if let pageModuleId {
            return moduleManager.modules.first { $0.id == pageModuleId }
        }
        return moduleManager.activeModule
    }

    var body: some View {
        Menu {
            Section(String(localized: "common.modules")) {
                ForEach(moduleManager.modules) { module in
                    Button {
                        switchTo(module)
                    } label: {
                        HStack {
                            Text(module.sourceName)
                            if module.id == currentModule?.id {
                                IconView("checkmark")
                            }
                        }
                    }
                    .disabled(module.id == currentModule?.id || moduleManager.isLoading)
                }

                if moduleManager.modules.isEmpty {
                    Text("release.no_modules_installed")
                }
            }

            Section {
                Button(action: onOpenStore) {
                    Label("store.title", icon: "cart")
                }
            }

            linksSection
        } label: {
            // The same footprint the links button had, so the bar's rhythm doesn't shift:
            // one icon, one tappable target.
            Group {
                if moduleManager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    IconView("puzzlepiece.extension")
                        .font(.system(size: 17, weight: .medium))
                }
            }
            .foregroundStyle(.primary)
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("release.switch_module")
    }

    /// The links the old button offered, kept: the module's own site first, then the
    /// trackers'. Only the links that resolve appear — a page with none gets no section.
    @ViewBuilder
    private var linksSection: some View {
        let links = ModuleWebsiteLinks.links(href: href, moduleId: pageModuleId) + trackers
        if !links.isEmpty {
            Section(String(localized: "release.open_on_web")) {
                ForEach(links, id: \.url) { link in
                    Button { openURL(link.url) } label: {
                        Label("modules.open_on \(link.name)", icon: "safari")
                    }
                }
            }
        }
    }

    private func switchTo(_ module: ModuleDefinition) {
        guard module.id != currentModule?.id, !moduleManager.isLoading else { return }
        moduleManager.selectModule(module)
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        ToastManager.shared.show(
            message: String(localized: "release.module_switched \(module.sourceName)"),
            type: .success, duration: 1.8
        )
        onSwitch()
    }
}

/// The module's own page on the web, resolved the way `ModuleWebsiteButton` resolves it —
/// extracted so the switcher menu can list it without keeping a second button alive.
enum ModuleWebsiteLinks {
    /// Read on the main actor: the module manager's state is main-actor isolated, and
    /// this only ever runs from a menu's body.
    @MainActor
    static func links(href: String?, moduleId: String?) -> [WebLink] {
        guard let href, !href.isEmpty else { return [] }
        let modules = ModuleManager.shared.modules
        let module = moduleId.map { id in modules.first { $0.id == id } } ?? ModuleManager.shared.activeModule
        let url: URL?
        if let id = moduleId ?? module?.id, let page = ModuleWebLinks.shared.url(moduleId: id, href: href) {
            url = page
        } else if let module {
            url = module.webURL(forHref: href)
        } else {
            url = ModuleDefinition.webURL(forHref: href, baseUrl: nil)
        }
        guard let url else { return [] }
        let name = module?.sourceName ?? url.host ?? String(localized: "modules.website")
        return [WebLink(name: name, url: url)]
    }
}

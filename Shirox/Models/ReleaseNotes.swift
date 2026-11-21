import Foundation

/// One release of the app, as the Changelog page shows it. The entries are the app's own
/// release history, kept here so the page works offline; the release workflow appends the
/// new version before it builds the IPA (see PROGRESS.md, "Changelog page").
struct ShiroxRelease: Identifiable, Decodable {
    let version: String
    let build: String
    /// ISO-8601 date, shown as "21 Nov 2026".
    let date: String
    var features: [String]
    var improvements: [String]
    var fixes: [String]

    var id: String { "\(version) (\(build))" }
}

enum ReleaseNotes {
    /// The version this build ships as, matched against the entries to mark "current".
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    static var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
    static var currentID: String { "\(currentVersion) (\(currentBuild))" }

    /// Newest first. Every line is one thing that shipped, condensed from the release's
    /// own notes — nothing here is invented after the fact.
    static let releases: [ShiroxRelease] = [
        ShiroxRelease(
            version: "1.6.0", build: "132", date: "2026-11-21",
            features: [
                "Changelog page: the app's release history as a timeline, offline",
                "Onboarding: swipe between pages, and a Modules setup page with recommended modules, the Store and import-by-link",
                "Icon packs published on the website, with the old links migrating automatically"
            ],
            improvements: [
                "Player, Library, Downloads, Sources, Modules, General and Advanced Network pages rebuilt one by one",
                "Download quality shows the label only — nothing truncated",
                "Onboarding pages sit centred on the screen; the Kavsoft splash honours Reduce Motion",
                "Schedule's date selector follows the picked day in every direction"
            ],
            fixes: [
                "Copy Name is back on the anime long-press menu",
                "The floating Today button is gone from Schedule",
                "Library's title no longer collapses into the navigation bar",
                "Rapid Next taps can't duplicate the last onboarding page"
            ]
        ),
        ShiroxRelease(
            version: "1.5.0", build: "131", date: "2026-11-21",
            features: [
                "The appearance picker is the real Kavsoft port — animated sky, sliding capsule, applied the moment it's tapped",
                "Notification permission step built from the Kavsoft CompactNotificationView port",
                "Signed-out Notifications is a connection screen for AniList and MyAnimeList"
            ],
            improvements: [
                "Onboarding rebuilt to four white/grey screens with one back control",
                "Sources & Integrations folded into Settings › Sources; the This Device header is gone",
                "Search's source picker lists anime sources only, as tiles"
            ],
            fixes: [
                "Notification taps resolve ids against the provider that owns them — no more wrong titles",
                "Store Test runs the real pipeline, and an honest manifest check on uninstalled modules",
                "The module catalog is cached, so a dead network shows saved shelves",
                "Raw localization keys fixed everywhere they were found"
            ]
        ),
        ShiroxRelease(
            version: "1.4.0", build: "130", date: "2026-11-21",
            features: [
                "Settings › Modules opens with a full Get-more-sources row into the Module Store",
                "Appearance selection in onboarding as three previewing cards"
            ],
            improvements: [
                "Player settings: engine cards, full-width segments, a large watched threshold",
                "Downloads: concurrency as five segments; Modules: the store's door first",
                "Schedule and notifications tab icons enlarged to 22 pt in 44 pt targets"
            ],
            fixes: [
                "Home Tour removed completely — overlay, spotlight, popovers, launch logic and its 21 keys",
                "The onboarding's five informational pages are gone"
            ]
        ),
        ShiroxRelease(
            version: "1.3.0", build: "129", date: "2026-11-21",
            features: [
                "Module detail pages: icon, version, author, Activate and a Test button",
                "The Module Store rebuilt on the two community catalogs, shelves and search"
            ],
            improvements: [
                "Settings rebuilt one page at a time — Player's three panes, Subtitles' pinned preview, Reader's tap-zone diagram, Storage's usage meter and the rest",
                "Search's source picker offers anime sources only"
            ],
            fixes: [
                "Gooey Refresh runs through an explicit state machine — no half pulls, no stuck spinners",
                "Profile and the manage-modules middle step removed from Settings"
            ]
        ),
        ShiroxRelease(
            version: "1.2.0", build: "128", date: "2026-11-21",
            features: [
                "Onboarding redesigned as its own lit scenes with the community catalogs wired in"
            ],
            improvements: [
                "Settings redesigned across every page — hero headers, new sections and rows",
                "The Module Store's shelves fill from the Cufiy library and the Sora catalog"
            ],
            fixes: [
                "The intro's split-screen reveal is fixed — the icon no longer shares the stage",
                "Doubled navigation arrows in Settings are gone",
                "Schedule's selected day reads clearly in both appearances"
            ]
        ),
        ShiroxRelease(
            version: "1.1.0", build: "127", date: "2026-11-20",
            features: [
                "Notifications, the feed and releases sit side by side in the tab layout"
            ],
            improvements: [],
            fixes: []
        )
    ]
}

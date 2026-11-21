import SwiftUI

/// Slim banner shown at the top of the screen when ProviderManager is actively using a fallback provider.
struct ProviderStatusBanner: View {
    @ObservedObject private var manager = ProviderManager.shared

    var body: some View {
        if manager.fallbackActive {
            HStack(alignment: .top, spacing: 8) {
                IconView("exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.footnote.weight(.semibold))
                    // The service's own explanation, where it gave one. During an AniList
                    // outage this is the difference between "the app ignored which tracker I
                    // picked" and "AniList says it has switched its API off".
                    if let reason = manager.fallbackReason {
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Names the provider actually serving results — `fallbackServedBy`, not `primary`, which
    /// stays whichever provider the user chose and would name the one that *didn't* answer.
    private var headline: String {
        guard let served = manager.fallbackServedBy else { return String(localized: "shared.using_fallback_provider") }
        return String(localized: "shared.showing_instead \(served.displayName)")
    }
}

/// Whether both providers are signed in (so there is something to switch).
@MainActor
private var bothProvidersSignedIn: Bool {
    AniListAuthManager.shared.isLoggedIn && MALAuthManager.shared.isLoggedIn
}

/// Capsule-pill switcher for the global primary provider (used in the Library).
/// Shown only when BOTH AniList and MyAnimeList are signed in.


/// How Search's source button appears. Home's provider menu shared this once; the menu moved
/// out of the bar, leaving Search's module button as the only reader.
enum ProviderMenuStyle: String, CaseIterable {
    case iconAndName, iconOnly, hidden

    static let key = "providerMenuStyle"

    var title: String {
        switch self {
        case .iconAndName: return String(localized: "shared.icon_and_name")
        case .iconOnly:    return String(localized: "shared.icon_only")
        case .hidden:      return String(localized: "shared.hidden")
        }
    }
}

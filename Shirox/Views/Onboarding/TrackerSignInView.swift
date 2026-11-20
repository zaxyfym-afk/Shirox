import AuthenticationServices
import SwiftUI

/// Signing in to a tracker, as onboarding's checklist presents it: both services, their own
/// logos, live status, one tap each. The logos are the services' own apple-touch icons, the
/// same bytes the Library and Settings show, with a monogram standing in until they arrive.
struct TrackerSignInView: View {
    @ObservedObject private var aniListAuth = AniListAuthManager.shared
    @ObservedObject private var malAuth = MALAuthManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    #if os(iOS)
    /// The web session needs a window to anchor to; inside a sheet of our own, the app's key
    /// window still is one.
    @State private var presentationWindow: UIWindow?
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                cards
                    .padding(.top, 8)

                Text("onboarding.what_syncing_does")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("onboarding.sign_in_to_a_tracker")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("common.done") { dismiss() }
            }
        }
        #if os(iOS)
        .onAppear {
            presentationWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        }
        #endif
    }

    // MARK: - Cards

    @ViewBuilder
    private var cards: some View {
        // Side by side where there's room, one under the other on a phone.
        let pair = Group {
            card(.anilist, brand: Color(red: 0.008, green: 0.663, blue: 1.0),
                 blurb: "onboarding.anilist_blurb",
                 isLoggedIn: aniListAuth.isLoggedIn,
                 username: aniListAuth.username,
                 needsAgain: aniListAuth.needsReauthentication) {
                signIn(.anilist)
            }
            card(.mal, brand: Color(red: 0.18, green: 0.318, blue: 0.635),
                 blurb: "onboarding.mal_blurb",
                 isLoggedIn: malAuth.isLoggedIn,
                 username: malAuth.username,
                 needsAgain: false) {
                signIn(.mal)
            }
        }
        #if os(iOS)
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: 14) { pair }
        } else {
            VStack(spacing: 14) { pair }
        }
        #else
        HStack(alignment: .top, spacing: 14) { pair }
        #endif
    }

    /// One service: its logo, name, a line on what it is, and the state of its account —
    /// a plain sign-in while signed out, "sign in again" when its token was refused, and a
    /// plain status once in.
    @ViewBuilder
    private func card(_ type: ProviderType, brand: Color, blurb: LocalizedStringKey,
                      isLoggedIn: Bool, username: String?, needsAgain: Bool,
                      action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            CachedAsyncImage(urlString: type.iconURL)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .accessibilityHidden(true)

            Text(type.displayName)
                .font(.headline)

            Text(blurb)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if isLoggedIn, !needsAgain {
                Label {
                    if let username {
                        Text("onboarding.signed_in_as \(username)")
                    } else {
                        Text("settings.signed_in")
                    }
                } icon: {
                    IconView("checkmark.circle.fill")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1), in: Capsule())
            } else {
                Button(action: action) {
                    Text(needsAgain ? String(localized: "settings.sign_in_again") : String(localized: "library.sign_in"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(brand))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .animation(.easeInOut(duration: 0.2), value: isLoggedIn)
    }

    // MARK: - Actions

    private func signIn(_ type: ProviderType) {
        #if os(iOS)
        guard let presentationWindow else { return }
        if type == .anilist {
            aniListAuth.login(presentationAnchor: presentationWindow)
        } else {
            malAuth.login(presentationAnchor: presentationWindow)
        }
        #else
        guard let anchor = keyPresentationAnchor() else { return }
        if type == .anilist {
            aniListAuth.login(presentationAnchor: anchor)
        } else {
            malAuth.login(presentationAnchor: anchor)
        }
        #endif
    }
}

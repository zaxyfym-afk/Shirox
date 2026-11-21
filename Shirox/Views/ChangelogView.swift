import SwiftUI

/// Settings › Changelog: the app's release history as a timeline. A vertical line joins
/// the versions, each one a version-and-build headline with its date, and its notes
/// grouped under Features / Improvements / Fixes. The current build's dot is filled and
/// its row sits at the top; the TMDB attribution closes the page, the credits context its
/// terms ask for.
struct ChangelogView: View {
    var body: some View {
        Group {
            if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
                TimelineList().scrollContentBackground(.hidden)
            } else {
                TimelineList()
            }
        }
        .background(changelogBackground)
        .navigationTitle("settings.changelog")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private var changelogBackground: some View {
        #if os(tvOS)
        return Color.clear
        #else
        return Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
        #endif
    }
}

private struct TimelineList: View {
    var body: some View {
        List {
            Section {
                ForEach(Array(ReleaseNotes.releases.enumerated()), id: \.element.id) { index, release in
                    ReleaseRow(release: release, isCurrent: index == 0)
                }
            } footer: {
                credits
            }
        }
        .listStyle(.insetGrouped)
        .listRowSeparatorTint(Color.primary.opacity(0.08))
    }

    /// The TMDB notice, relocated here from the Settings footer: same words, an
    /// unobtrusive place that is still a credits context.
    private var credits: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image("TMDBLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 12)
                .accessibilityLabel("TMDB")
            Text("settings.this_application_uses_tmdb_and")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One version on the timeline: the dot on the line, the version headline, the date, and
/// the note groups. The current build's dot is filled; older ones are rings.
private struct ReleaseRow: View {
    let release: ShiroxRelease
    let isCurrent: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // The timeline's spine, drawn per row so List recycling keeps it whole: a dot
            // on the line, the line continuing past the row's ends.
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.22), lineWidth: 1.5)
                        .background(Circle().fill(Color(uiColor: .systemGroupedBackground)))
                    if isCurrent {
                        Circle()
                            .fill(Color.primary.opacity(0.85))
                            .frame(width: 9, height: 9)
                    }
                }
                .frame(width: 16, height: 16)

                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 1.5)
            }
            .padding(.top, 7)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "v\(release.version)")
                        .font(.title3.weight(.heavy))
                        .monospacedDigit()
                    Text(verbatim: "(\(release.build))")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if isCurrent {
                        Text("settings.current_release")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.primary.opacity(0.10)))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                Text(release.date, format: .dateTime.day().month(.wide).year())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                NoteGroup(title: "changelog.features", items: release.features)
                NoteGroup(title: "changelog.improvements", items: release.improvements)
                NoteGroup(title: "changelog.fixes", items: release.fixes)
            }
            .padding(.vertical, 6)
            .padding(.leading, 4)
            .padding(.trailing, 12)
        }
        .listRowInsets(EdgeInsets())
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }
}

/// One labelled group of notes. Empty groups don't appear at all.
private struct NoteGroup: View {
    let title: LocalizedStringKey
    let items: [String]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.primary.opacity(0.28))
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        Text(verbatim: item)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

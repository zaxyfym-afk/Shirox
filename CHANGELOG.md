# Changelog

## Unreleased: the restoration arc (2026-11-21)

### Fixed

- Navigation: the tab bar is the original five tabs (Home, Library,
  Downloads, Settings, Search) again; notifications and store are out of the
  bar, the hold menu, the sidebar, the launch picker and quick actions.
- Intro splash: the 1024pt mark no longer renders at natural size; the
  carry-on holds it at 90pt and the mask expansion is constrained too.
- Gooey refresh: the blob now anchors to the window's hardware top inset
  instead of the scroll view's local safe area, so it shows on every page
  that pulls - Home (both layouts), Browse, Library, Schedule, Store, and
  the anime detail pages, which had no pull to refresh at all before.
- Schedule: no zoom transition in, no interactive drag dismissal, so a
  downward drag always scrolls the list instead of closing the page.
- Home: the sections are out of their sticky cards, back to the original
  header-over-shelf layout (AnimeSection, Continue Watching, Continue
  Reading).

### Added

- Schedule and Notifications as two separate round buttons at Home's top
  right (the iOS 26 shared glass capsule is hidden behind them).
- Anime long-press menus: AniList and MAL links from their own ids, share,
  copy link, watchlist/watching/completed through the title's own provider,
  and AniList favourites (new ToggleFavourite mutation).
- Onboarding, redesigned: floating mark over an accent wash, directional
  page turns, a stretching progress capsule, spring-press controls; the
  functional checklist and both sign-in sheets unchanged underneath.
- Settings, redesigned: tiled section headers, tinted squircle row icons,
  chevrons, a restyled profile card, and thirteen bare headers swapped to
  the shared header component. No binding or option was removed.
- KAVSOFT_AUDIT.md: the whole `everything` folder audited, example by
  example.

## Unreleased: the redesign arc

Local main, commits 40b2d46..4585a2a on top of bfeb07a. Not yet built or
released; apps.json still reads 1.1.0 (127).

### Added

- Home: calendar and notifications buttons in the top bar, and a one-time
  onboarding tour (coach marks over a dimmed screen, Skip and Next, replay
  entry in Settings).
- Schedule: a week-paged horizontal calendar with real dates, per-week
  on-demand loading, the month in the bar and a Today button.
- Onboarding: AniList and MAL sign-in cards with their real logos and one-tap
  sign-in; page 0 types out its promise a phrase at a time on iOS 18+.
- Notifications tab: the Activity and Episodes feeds side by side, full tab
  plumbing and an unread badge on the bell.
- Profiles: twelve bundled avatars, with the colour sitting on every avatar
  state and the artwork picker demoted.
- Module Store: catalog model, service, tab UI and the ModuleManager install
  bridge, with a bundled empty placeholder (catalog integration pending,
  see TODO.md).
- Settings: the theme and app icon pickers as full-screen scenes on iOS 26.

### Changed

- Home: section rows are sticky cards that stack as the page scrolls on
  iOS 18; the plain look stays below 18 and on Mac and tvOS.
- Refresh: the gooey MorphingRefresh blob on the native refresh control.
- Launch: the splash carries on from the launch screen on every start and
  shrinks to reveal onboarding on first run (iOS and Catalyst; Mac and tvOS
  keep SplashView).
- Toasts: stacked glass capsules with mesh tint bleed on iOS 26; the
  ToastManager API is unchanged.
- Settings: the twelve intro cards are out; the root is regrouped (You,
  Playback, Library and Storage, Sources, App) and every section header goes
  through the design system.

### Fixed

- Profile picker bugs and the avatar colour across states.
- Duplicate settings doors consolidated (appearance and layout only on
  Customization, which owns the icon picker and packs).
- The tour stays off Mac and tvOS (no tour flag, no replay entry).
- The theme picker's segmented control declared its `@Namespace` inside the
  computed property (invalid scope; the first real compile verdict, Codemagic
  build 2): moved to the view's stored properties (cd8c299).
- The thirteen-error compile round of Codemagic build 3 (a2d832c): the launch
  screen now runs on the app's iOS 15 floor with the same behavior on 17+, the
  tour carries an iOS 15 shape eraser instead of `AnyShape`, and a batch of
  scope, type and availability errors were fixed across thirteen files.

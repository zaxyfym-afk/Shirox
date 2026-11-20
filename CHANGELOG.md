# Changelog

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

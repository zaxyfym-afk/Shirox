# Changelog

## Unreleased: the ninth session (2026-11-21)

### Settings, rebuilt one page at a time

The main Settings page keeps its design. Every page INSIDE it got a new layout, not a
recolor:

- Player: three panes under a segmented control — Playback (engine, quality, ambient,
  background audio, spatial), Controls (landscape, glass, hold action and tolerance, pause
  for Control Center), Episodes (skip lengths, auto-skip, auto-next, reverse order, the
  watched threshold). One-tap navigation instead of one long scroll.
- Subtitles: the live preview is pinned above the controls and stays visible while the
  sliders scroll under it; Style, Background, Position and Timing are their own groups.
- Reader: a diagram of the page's two tap zones — which side goes forward flips with the
  reversed-direction toggle, and the diagram dims when tap zones are off.
- Library: the title-language order is its own drag-to-reorder group; badges, matching and
  the on-device library keep their sections, with the filler and schedule notes folded in.
- Downloads: quality as five plain segments, automation grouped, delete-all moved to an
  "On Disk" section with the size it will remove.
- Storage & Cache: a usage meter (total with a proportional bar over artwork, downloads,
  website data and other) opens the page; every individual reset is a row with its size,
  no longer folded into a disclosure group.
- Notifications: the master switch and the system's permission status share one section;
  the manual check now shows what the last sweep found beside the button.
- Customization: the theme leads as three plain segments (System / Light / Dark), the tint
  swatches under it, then icon and icon packs, then layout, then the filler and schedule
  toggles as one Details group.
- Backup: two big action buttons — create with the accounts switch and its consequences
  written above the button, restore with its own progress line — and the last restore's
  report below.
- Advanced network: the connection test leads the page, before the proxies it diagnoses;
  reset stays last.
- Discord: the account rides under the master switch, so sign-in state is the first thing
  the page says.

Descriptions are shorter throughout: notes that repeated the row's title are gone, and the
warnings that remain (backup accounts, mpv, revoked tokens) are the ones that earn their
space.

### Removed

- Profile is completely gone from Settings — the card, the picker, the whole local-profile
  system behind it (ProfilesView, ProfileManager, ProfileSwap, AppProfile, the avatar
  catalog and its tests). Account authentication lives on Sources & Integrations.
- The "Manage Installed Modules" step: Settings › Modules opens the full module manager
  directly now. Its automation toggles (default extension, reuse last result, reuse last
  stream) moved to a menu on the manager's toolbar.
- The built-in AniList / MyAnimeList / Simkl rows on the module manager — those sources
  have their own page now.
- The hero header and every icon-and-title block on every settings page, and every page
  tint: the subpages are the system's own inset-grouped lists. This also removes what
  rendered behind the Providers section — the tinted background wash and the hero tile's
  glow shadow were the artifact.

### New

- Sources & Integrations, its own Settings category: AniList and MyAnimeList as account
  cards (icon, status, sign in/out, make primary, drag to reorder the chain), Simkl with
  its budget row, Discord, the tracking toggles and the library sync runs.
- Module detail pages: icon, name, version, author and source; Activate; a Test button —
  exactly that label — that runs the module the way playing runs it (search, episodes,
  stream) and reports pass, the step it failed on and why, or why it couldn't run. Nothing
  is faked: manga, local-files and Jellyfin modules say they aren't run this way. Copy
  Link copies the manifest. Remove confirms first.
- The Module Store, rebuilt: no featured shelf, no hero — clean rows with a neutral
  monogram fallback when an icon is missing (inline `data:` icons decode now), category
  chips, search, and the installed modules at the bottom. The store detail page carries
  Install / Update / Reinstall, Test, Copy Link, Remove, and version, compatibility and
  source as quiet lines.
- Search's source picker: only the anime sources — AniList, MyAnimeList, Simkl while
  signed in, and the installed modules that can search. Picking one switches the search
  and re-runs the query, as before. No module management in this sheet.

### Fixed

- Gooey Refresh: the pull now runs through an explicit state machine (idle → refreshing →
  completing → idle). The trigger fires only from idle — one haptic, one refresh per pull —
  and the machine returns to idle only once the refresh has finished AND the pull is back
  at rest, so holding the gesture or dragging on after a fast refresh can never re-arm it.
  The shrink-back animation also refuses re-entry, so the geometry ticks can't restart it.
- The schedule and notifications buttons are toolbar-sized now: 19 pt icons in 44 pt hit
  targets, matching buttons, never a merged capsule.

### Housekeeping

- 109 unused localization keys pruned (the profile system's, the removed intermediate
  pages', the shortened notes); 39 new keys translated into all fourteen languages.
- Version 1.3.0 (129).

## Unreleased: the eighth session (2026-11-21)

### Fixed

- Gooey refresh: the pull now runs its whole length over 110 pt (near twice the native
  control's own scale) and the blob's growth is smoothed (slow start, gathering middle,
  eased end), so the gooey materialises gradually and stretches as the finger drags.
- Gooey refresh jitter: the gooey style no longer sits on the native `.refreshable` control.
  Beginning that control at the list's rest offset shifted the whole page downward by the
  control's height - the trigger jitter, worst on full-bleed pages where every image jumps.
  The pull is read straight off the scroll geometry now: crossing the threshold fires one
  refresh, one haptic, and the list never moves. The position is stable from pull to
  completion, and the refresh stays repeatable.
- Schedule: the episode-count dot under the date numbers is gone (both the paged calendar
  and the weekday chips); it read as a stray dot.
- Schedule: the selected date's circle is the label colour with the number in the background
  colour - solid and readable in light and dark and under every tint, instead of an accent
  that can sit against a number the same colour as itself.
- Intro split-screen: the reveal no longer hands the stage to a VStack where the icon's
  greedy frame and the full-height onboarding split the screen between them. Everything
  lives in one ZStack now: the icon shrinks, rides up under the status bar and fades, and
  the onboarding owns the full screen from the first frame to the last. No AnyLayout, so
  iOS 15 through 26 run the same code.
- Settings: the doubled arrows are gone. Navigation rows drew their own chevron beside the
  system NavigationLink's; the custom one only shows on rows that navigate without a
  NavigationLink (the Store button, the replay menu).
- The About section is removed from Settings. The imprint, privacy, contributors and
  licences pages stay reachable under the device section, and the TMDB logo and notice
  moved into that section's footer, where the attribution still lives.
- The backup builder: SwiftLint, the strings check and the icons check are green again, and
  the nightly no longer pins an Xcode version the runner may not carry.

### Changed

- Settings redesigned, every page: a hero header opens each subpage (the page's icon in a
  gradient tile, its name, and one line on what the page decides), each page carries its
  own accent (players blue, sources green, library mint, and so on) that tints its section
  headers, row tiles and background, and the whole list sits on that tinted grouped
  background. Pages: Providers, Notifications, Player, Subtitles, Reader, Library,
  Downloads, Storage, Modules, Store, General, Customization, Backup, Advanced network,
  Logs, Log filters, Icon packs, Tab bar, Language and Discord. Every control, binding and
  saved preference is untouched.
- Settings root: the profile card is a floating gradient-ringed card, sections carry their
  own colours, and the App section wears the release badge's red.
- Onboarding redesigned: every page is its own lit scene (two slowly drifting pools of the
  page's colour over the system background), the welcome's typewriter runs larger in the
  page's colour, page turns arrive with a scale, the hero tiles are glass with a coloured
  shadow, the checklist rows sit on ultra-thin material with an accent ring once done, and
  the next button is a gradient capsule. The splash reveal, the typewriter engine, the
  zoom-out sheets and the glass chrome are the Kavsoft pieces, unchanged underneath.
- Module Store: the shelves fill from the two community catalogs - the Cufiy library
  (https://library.cufiy.net/api/modules.json) and the xdfkenny index
  (https://sora-modules.xdfke.me/modules.json) - fetched fresh on every load, mapped to
  store entries, filtered to the anime and anime-bearing multi modules, and de-duplicated
  by manifest. A source that fails (Cloudflare in front of Cufiy can challenge) reports
  itself in a soft line while the other's shelves stay up; pull to refresh tries again.
  The hand-set catalog URL keeps working as a third source.
- Version 1.2.0 (128), up from 1.1.0 (127), across apps.json and every target.

### Fixed (build system)

- SwiftLint green again: the violations a2d832c onward had left were fixed by hand (a
  force unwrap in the store, nested decoder types, an optional initialised `= nil`, a
  private extension, a blank line before a brace, a multiple-closures-with-trailing-
  closure call in the cinematic page, and a 2000 the separator rule wants written 2_000).
- The three strings-check and icons-check failures are fixed: one mistyped catalog key,
  and three SF Symbols (arrow.left.arrow.right.square, forward.end,
  text.badge.checkmark) registered in iconpacks/icons.json.
- The nightly's Xcode pin (26.3) is gone: the runner picks its newest Xcode at run time.
  Under the old pin the same code hit three of its own errors; two are fixed at the source
  (the HLS audio-rendition chain decomposed so no checker times out, and the ambiguous
  literal arithmetic in PosterViewer and SettingsPickers written with typed literals), and
  the newest-toolchain pick keeps the pin from rotting again.

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

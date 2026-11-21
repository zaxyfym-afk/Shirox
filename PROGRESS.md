# Progress

Updated: 2026-11-21, eighth session (gooey, schedule, settings everywhere, onboarding, store, CI).

## This session, in short

The user listed twelve problems, most of them regressions the seventh session's work had
left behind or half-finished. Done, in the order requested:

- Gooey refresh slowed (110 pt pull, smoothed growth) and de-jittered: the gooey style no
  longer sits on the native `.refreshable` control, whose begin-refreshing content shift
  was the downward jump of every image at the trigger. The pull reads straight off the
  scroll geometry; one crossing, one refresh, one haptic. Shared by Home, Browse, Library,
  Schedule, Store and both detail pages, since they all wear the one modifier.
- Schedule: the under-number dots removed from both day cell styles; the selected circle is
  now label-colour on background-colour text, readable in every appearance and tint.
- The About section is gone from Settings; legal pages live under the device section and
  the TMDB notice is that section's footer.
- The Profile tab: none exists to remove. The bar has been Home, Library, Downloads,
  Settings and Search since 6ded1c8, verified back through history and in the current
  tree; account management stays in Settings' You section, as the brief asked. Nothing
  was deleted.
- Settings redesigned on every page through a rebuilt SettingsDesign: page heroes with
  gradient tiles, a per-page accent carried through headers, tiles and background, the
  doubled chevrons removed, the profile card gradient-ringed. Nineteen subpages restyled.
- Intro split-screen fixed: one ZStack, icon rides up and fades, onboarding full screen.
- Onboarding redesigned again on the Kavsoft engines (splash reveal, typewriter, zoom
  sheets, glass): per-page aurora scenes, gradient controls, material cards.
- Module Store: both catalog links implemented (Cufiy + xdfkenny), merged, filtered to
  anime, de-duplicated; failures per source, non-fatal.
- Dead code: the About strings and the AnyLayout era of the launch screen are gone; the
  unused catalog keys removed; nothing unreferenced beyond that was touched.
- Version 1.2.0 (128) everywhere.
- CI: SwiftLint's sixteen violations fixed; strings and icons checks green; the nightly's
  Xcode 26.3 pin replaced with pick-newest-at-runtime, and the three 26.3-only errors
  fixed at the source. Codemagic stays primary.

Updated: 2026-11-21, seventh session (navigation restoration + the repair arc).

## This session, in short

The user handed the project over fresh, listed the regressions the redesign
had left behind, and asked for the original navigation back plus the
Kavsoft work finished properly. Done, in the order requested:

- The tab bar is the original five tabs again: Home, Library, Downloads,
  Settings, Search. Notifications is NOT a tab anywhere (bell page from
  Home's toolbar); Store is NOT a tab (its doors are Settings and the
  Modules page); the launch-tab picker, the sidebar, the tab bar's hold
  menu, the pre-18 bar, the Mac toolbar and the Catalyst sidebar all follow.
  Quick actions lost the store shortcut.
- Schedule and Notifications are two separate round buttons at Home's top
  right, each with its own icon, hit area and action; iOS 26's shared glass
  capsule is hidden behind them (sharedBackgroundVisibility) and each button
  wears its own circle chrome.
- Schedule pushes plainly: the iOS 26 zoom transition is gone (it let a
  downward drag dismiss the page mid-scroll), so it opens straight away and
  scrolling never closes it. The Monday-Sunday strip is untouched.
- Home's categories are out of the cards: AnimeSection, Continue Watching
  and Continue Reading are the plain header-over-shelf layout again
  (homeSectionCard is no longer called from Home).
- Gooey refresh fixed everywhere and ADDED to the anime detail pages. The
  blob had been positioning itself from the scroll view's local safe area,
  which full-bleed pages read as zero: it drew off screen. It now anchors to
  the window's hardware top inset, shifted by the scroll view's own offset,
  so it grows out of the island on Home (both layouts), Browse, Library,
  Schedule, Store and BOTH detail pages. DetailView (module items) and
  AniListDetailView (phone and cinematic) got real refresh actions that
  reload the page's own data.
- The intro splash fixed: the mark was drawn with no size constraint, so the
  1024pt asset filled the screen (the "extremely zoomed in" report). It now
  holds at 90pt, cross-fades into the 150pt icon, and the mask expansion
  later launches use is constrained the same way. Timing and transitions are
  the reference's.
- Onboarding redesigned: floating mark over a soft accent wash, pages that
  carry themselves in from the turn's direction, a stretching progress
  capsule, a spring press style on every control, and the same functional
  checklist (source + tracker with real state) with its sheets intact.
- Long-press menus expanded: AnimeContextMenuItems on the Home/search/browse
  cards, library rows, schedule entries and relations rows - full title,
  open in AniList, open in MAL (each built from its own id, omitted when the
  title has none), share, copy link, watchlist/watching/completed through
  the provider the title belongs to (progress and score preserved), and
  AniList favourites via a new ToggleFavourite mutation.
- Settings redesigned: the section header is a tiled, tracked caption; rows
  lead with a tinted squircle tile and carry a chevron; thirteen bare
  section headers across the pages swapped to the shared header component;
  the profile card and toggle rows restyled. Every toggle, picker and
  binding is untouched.
- KAVSOFT_AUDIT.md is new: every example in `everything`, what it does,
  where it lives and whether it works.

Updated: 2026-11-20, sixth session (the first green build: Codemagic build 6).

## Where things stand

- Remote `origin/main`: 3858330 (the poller's finished-status fix),
  verified with `git ls-remote` 2026-11-20 20:29 UTC; the green-build docs
  ride on top ([skip ci]). Pushed in this arc: 4b93a9d (second cron),
  cd8c299 (namespace fix), d614cc7 (docs), a2d832c (thirteen compile
  fixes), ae79d4b (docs), 9b7d783 (scripts/codemagic.py into the repo),
  b8b4d81 (poller phase fix), 89e2166 (build 4's seven errors), e21f70d
  (build 5's three), 3858330 (finished-status fix). The user pushed
  ac59ac3 and 6eb9103 themselves (codemagic.yaml and its Metal Toolchain
  step).
- Codemagic is the primary builder, driven by API: `build --authorized`
  triggered each build, `wait` polled every 5 s, `errors` pulled the real
  diagnostics, `artifacts` delivered the signed links. The loop: build 4
  failed (7 errors: the tab bar's TabContent builder, a second type-check
  timeout, .task on an if/else, Image(decorative:) being asset-name-only,
  .fill.tertiary being 17+), fixed in 89e2166; build 5 failed (3 errors:
  @TabContentBuilder<Int>, View.badge wanting a plain Int — the redesign's
  Int? badge had never actually compiled), fixed in e21f70d; BUILD 6
  FINISHED GREEN (6b00aad5c1876cf706761326, on e21f70de, 5m04s): the
  first green build of the redesign, Verify IPA passed, built SHA = pushed
  SHA, unsigned Shirox.ipa 27.1 MB (1.1.0 (127), iPhoneOS, min iOS 15.0)
  plus dSYMs. The token is at .scratch/codemagic-token; the script now
  lives in the repo at scripts/codemagic.py.
- The green build's .ipa is delivered as a FILE (workspace
  download/Shirox.ipa, sha256 4c60...f2ce): Codemagic's artifact links
  UA-sniff (browsers get an itms-services install manifest, not the file)
  and the presigned direct URL lives about a minute. Standard flow since:
  `python3 scripts/codemagic.py ipa [--download PATH]` refreshes both
  links or fetches the file for the latest green build — no build
  triggered for links, ever.
- The redesign is GREEN on the primary for the first time (build 6). The
  GitHub backup nightly still fails under its pinned Xcode 26.3 (three
  errors of its own: a HLSManifestParser type-check timeout, an ambiguous
  '-' in PosterViewer, an ambiguous '*' in SettingsPickers) — the full
  story is in BUILD_STATUS.md. SwiftLint, Semgrep, Strings and icons are
  green.
- The `latest` release IPA ("Shirox 1.1.0 (127)", 2026-11-20 02:51 UTC) was
  built from bfeb07a, before the redesign. It does not contain the new work.
- Full backup: `shirox-local-backup-2026-11-20.bundle` in the workspace root.

## Completed (local and remote are the same history now)

| Commit | Work |
|---|---|
| 40b2d46 | Home top bar: calendar + bell replace the provider dropdown |
| 3f62281 | MorphingRefresh on the native refresh control |
| eecd447 | Week-paged HorizontalCalendar for the schedule |
| 1ab3290 | AniList + MAL onboarding sign-in cards |
| 2b06e8b | Notifications tab (Activity + Episodes), unread badge |
| 720f58f | 12 bundled profile avatars, colour on every avatar state |
| b048544 | Module Store foundation (catalog, service, tab, ModuleManager bridge) |
| 6cc26c7 | Settings: intro cards out, SettingsIconTile and SettingsToggleRow in |
| 1326438 | Settings root regrouped, one door per destination |
| 440ad83 | Theme and app icon pickers as scenes on iOS 26 |
| 485765a | Splash carries on from the launch screen (iOS and Catalyst) |
| 50458de | Toasts: stacked glass capsules, mesh tint on iOS 26 |
| 421723b | Home rows as sticky cards on iOS 18 |
| ab31eae | Home tour: coach marks for calendar and bell, runs once |
| 470d325 | Onboarding page 0 typewriter |
| 280bb1e | The last 33 bare settings headers become SettingsSectionHeader |
| 4585a2a | Tour platform guards (no tour on Mac and tvOS) |

Session four on top: 045a789 (merge of the bot's apps.json stamp), db1f1c9
(docs), 0d88a56 and 1a4ebbf (lint green), 691b25d (build CI), 0ada78d
(docs). Session five on top: the user's ac59ac3 and 6eb9103 (codemagic.yaml
and the Metal Toolchain step), 4b93a9d (second cron), cd8c299 (namespace
fix), d614cc7 (docs), a2d832c (the thirteen compile errors of build 3),
ae79d4b (docs). Session six on top: 9b7d783 (scripts/codemagic.py into
the repo), b8b4d81 (poller phase fix), 89e2166 (build 4's seven errors),
e21f70d (build 5's three), 3858330 (finished-status fix), plus the
green-build docs.

## Pending, in order

1. The GitHub backup nightly needs its own pass under Xcode 26.3: fix
   HLSManifestParser.swift:152's type-check timeout, PosterViewer.swift:37's
   ambiguous '-', and SettingsPickers.swift:447's ambiguous '*', or unpin
   DEVELOPER_DIR to the latest Xcode in nightly.yaml. Any of it needs a
   push; the Codemagic primary is already green.
2. The verification list in TODO.md section 2 (schemes, tests, on-device),
   now that a green IPA exists.
3. Module Store completion (TODO.md). The catalog research is done: 287 real
   modules from both libraries, 147 anime plus 45 multi, in
   .scratch/module-research/ (copy under download/) waiting to be wired in.

## Blocked

Nothing in code. The only wall was macOS runner capacity at European peak,
now handled by the macos-15 pool and the 03:07 UTC cron.

## Latest verified GitHub commit

3858330 (fix: codemagic poller knows finished), verified 2026-11-20
20:29 UTC by `git ls-remote`; e21f70d, the green-build fix commit, is two
below it. The green-build docs ride on top of 3858330.

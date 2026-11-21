# Todo

## 0. Ninth session (2026-11-21): what is done and what is next

- DONE: profile system removed end to end (Settings card, picker, ProfileManager/Swap/
  AppProfile, avatars, tests); Sources & Integrations created with AniList/MAL account
  cards + Simkl + Discord + tracking + sync; Settings › Modules opens the manager directly
  with automation in its toolbar menu and the built-in source rows moved off it; every
  Settings subpage rebuilt (Player panes, pinned subtitle preview, reader tap-zone diagram,
  library order card, download segments, storage meter, notifications status, customization
  theme segments, backup action cards, advanced network diagnostics-first, Discord
  status-first); descriptions shortened; Module Store rebuilt without the featured shelf,
  monogram icon fallback + data-URI icons; module detail pages with a real Test (exact
  label), Copy Link, Install/Update/Remove; Search source picker shows only anime sources;
  gooey refresh state machine (one haptic, one refresh, no re-arm while held); schedule +
  notifications buttons at 19 pt in 44 pt targets; 109 dead keys pruned, 39 new keys in 14
  languages; version 1.3.0 (129).
- NEXT ON DEVICE: every rebuilt subpage in light and dark on a small phone and a large one
  (the Player's segmented panes and the storage meter especially); the module Test button
  against a real module (passed, failed, needs-verification paths); the Search source
  picker's re-search on switch; a long-held gooey pull past a fast refresh (no haptic
  spam, no second refresh); Sources & Integrations drag-to-reorder with an editMode list
  that also holds sign-in buttons.
- NEXT IN PIPELINE: the Codemagic build for this arc; the four xcodebuild scheme builds
  and the ShiroxTests suite still need a Mac.

## 0. Eighth session (2026-11-21): what is done and what is next

- DONE: gooey refresh slowed and de-jittered (no native control under the gooey style);
  schedule dots removed and the selected date readable; About removed; Profile tab verified
  absent (nothing to remove, account management stays in Settings); Settings redesigned on
  the root and all nineteen subpages with the doubled arrows gone; intro split-screen
  fixed; onboarding rebuilt on the Kavsoft engines; both Module Store catalog links wired
  (Cufiy and xdfkenny); dead code and unused strings removed; version 1.2.0 (128);
  SwiftLint, strings and icons green; nightly Xcode pin replaced.
- NEXT ON DEVICE: the gooey pull's new 110 pt feel; the gooey trigger without a native
  control (pull, hold, release); schedule selection in light and dark; every Settings page
  on a phone; the intro reveal on a Dynamic Island phone and a notched one; onboarding
  page turns with Reduce Motion on; the store with both catalogs live and the Cufiy
  source's Cloudflare behaviour from a phone.
- NEXT IN PIPELINE: the Codemagic build for this arc; the four xcodebuild scheme builds
  and the ShiroxTests suite still need a Mac (iOS floor 15.0 untouched; tests updated for
  the new pull distance and smoothing).

## 0. Restoration arc (2026-11-21): what is done and what is next

- DONE: original five-tab bar restored; notifications/store removed from
  every navigation surface; schedule + notifications as separate buttons;
  schedule's zoom transition and drag dismissal gone; Home sections out of
  their cards; gooey blob window-anchored and on both detail pages; detail
  refresh wired; intro splash sized; onboarding redesigned; long-press
  menus expanded (AniList/MAL/watchlist/favourites/share); store's doors in
  Settings only; settings design system rebuilt.
- NEXT ON DEVICE: pull to refresh on an anime detail page (gooey style,
  iOS 18+); the two top-right buttons on iOS 26 (separate circles, not one
  capsule); schedule scroll vs dismissal; first-run splash size on a
  notched phone and a Dynamic Island phone; onboarding's page turns with
  Reduce Motion on; a long-press on a Home card with AniList signed in.
- NEXT IN PIPELINE: DONE for the arc - Codemagic build 8 finished green on
  0eb80a65 (4m52s) and the unsigned IPA is delivered. The GitHub backup
  nightly's three Xcode-26.3 type-check failures (below) remain open.

## 1. Build pipeline (Codemagic primary GREEN, Actions backup needs a pass)

- THE REDESIGN IS GREEN: Codemagic build 6 (6b00aad5c1876cf706761326, on
  e21f70de, 5m04s, 2026-11-20 ~20:24 UTC) built and verified the unsigned
  IPA — 27.1 MB, 1.1.0 (127), iPhoneOS, min iOS 15.0. The loop was fully
  API-driven: build 4 (7 errors, fixed in 89e2166), build 5 (3 errors,
  fixed in e21f70d), build 6 green. The script lives in the repo at
  scripts/codemagic.py; builds start ONLY via `build --authorized` /
  `trigger --authorized` (pushes do not trigger Codemagic; no webhook).
  Token: .scratch/codemagic-token (outside the repo; never printed or
  committed).
- Remaining in the pipeline: the GitHub backup nightly fails under its
  pinned Xcode 26.3 even on the green code (HLSManifestParser.swift:152
  type-check timeout, PosterViewer.swift:37 "ambiguous '-'",
  SettingsPickers.swift:447 "ambiguous '*'"); fix those or unpin to the
  latest Xcode in nightly.yaml. Do not rebuild unchanged code; do not
  assume every exit code 65 is the same error.
- GitHub Actions backup: push-triggered plus crons at 21:07 and 03:07 UTC
  (macos-15, Xcode 26.3); it cannot get a runner at European peak, the
  crons land in the quiet windows. Pushing while a nightly run is still
  PENDING supersedes (cancels) it; use `[skip ci]` on docs-only pushes.
- Built SHA = pushed SHA was verified for build 6; the artifact links were
  delivered (signed short-lived links via
  `python3 scripts/codemagic.py artifacts 6b00aad5c1876cf706761326`).

## 2. Verification after the first green build

- The four xcodebuild scheme builds (iOS, macOS, tvOS, Catalyst), zero
  errors and zero warnings. The nightly only builds iOS; the others need the
  user's Mac or their own workflow.
- The ShiroxTests suite, including MorphingRefreshTests, ProfileAvatarTests
  and ModuleStoreTests.
- On device: profile edits persist across relaunch; avatar colour on every
  state; MAL sign-in from onboarding; calendar paging across weeks;
  notifications permission and badge; store install and uninstall
  round-trip; the theme scene and icon carousel on iOS 26; the carry-on
  splash on cold start and on first run; the tour firing once after
  onboarding and from the replay menu.

## 3. Module Store completion

The research is done: 287 modules with real versions and sources from
library.cufiy.net (api/modules.json) and sora-modules.xdfke.me (the
xdfkenny modules.json index plus 176 per-module manifests), classified:
147 anime, 45 multi (anime among general catalogs), 34 manga, 61 excluded
(K-drama, live-action, unrelated; novels listed separately). Data in
.scratch/module-research/ and download/module-research/.

- Wire the catalog into the store: add the anime and multi modules, exclude
  K-drama, live-action, unrelated; manga stays out for now.
- Modules stay optional and installable through the store; never hardcode
  every module into the app.
- Searching, filtering, installing, removing, enabling, disabling and
  updating; show name, icon, description, version and source; no duplicate
  listings; compatibility, permission and dependency validation; automatic
  catalog updates where technically possible (Cufiy: one-shot re-fetch with
  a browser UA; xdfkenny: index then manifest hydration, ETag support).
- Verify install and uninstall end to end.

## Declined (do not pick up again)

- Settings search (struck from the plan).
- Removing the macOS, tvOS and Mac Catalyst targets and their build scripts
  (the approved plan keeps all four schemes; only revisit if the user asks).

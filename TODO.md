# Todo

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

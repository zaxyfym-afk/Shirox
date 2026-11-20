# Todo

## 1. First green build (automated now, watch it)

- Pushes to main and the daily 03:07 UTC cron both build the nightly on
  macos-15 with Xcode 26.3 (691b25d). Watch run 5 (44763289051) or the next
  cron run; on failure, read the failing step's logs, fix, push, rebuild.
- Pushing while a nightly run is PENDING supersedes (cancels) it; pushing
  while one is RUNNING does not. Use `[skip ci]` on docs-only pushes.
- Fix compile errors, push, rebuild, until green. Risk areas: the four
  availability-heavy ports (launch screen, toasts, sticky sections, tour) and
  the `animation(_:body:)` calls in LaunchScreen.swift (iOS 17 API, target is
  17.0).
- Verify the built SHA equals the pushed SHA, then deliver the artifact link
  and the run link.

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

# Todo

## 1. Sync and first build (blocked on a PAT from the user)

- Push local main (seventeen redesign commits + merge + docs) to origin main;
  verify with `git ls-remote`.
- The push triggers the nightly; if it does not run, dispatch it (command in
  BUILD_STATUS.md). Poll the run, read the failing step's logs on failure.
- Fix compile errors, push, rebuild, until green. Risk areas: the four
  availability-heavy ports (launch screen, toasts, sticky sections, tour) and
  the `animation(_:body:)` calls in LaunchScreen.swift (iOS 17 API, target is
  17.0).
- Verify the built SHA equals the pushed SHA, then deliver the artifact link
  and the run link.

## 2. Verification after the first green build

- The four xcodebuild scheme builds (iOS, macOS, tvOS, Catalyst), zero
  errors and zero warnings.
- The ShiroxTests suite, including MorphingRefreshTests, ProfileAvatarTests
  and ModuleStoreTests.
- On device: profile edits persist across relaunch; avatar colour on every
  state; MAL sign-in from onboarding; calendar paging across weeks;
  notifications permission and badge; store install and uninstall
  round-trip; the theme scene and icon carousel on iOS 26; the carry-on
  splash on cold start and on first run; the tour firing once after
  onboarding and from the replay menu.

## 3. Module Store completion

Sources: library.cufiy.net (library listing, newest first) and
sora-modules.xdfke.me (library section).

- Add all compatible anime modules from both libraries to the catalog.
  Exclude K-drama, live-action and unrelated content; exclude manga for now.
- Modules stay optional and installable through the store; never hardcode
  every module into the app.
- Searching, filtering, installing, removing, enabling, disabling and
  updating; show name, icon, description, version and source; no duplicate
  listings; compatibility, permission and dependency validation; automatic
  catalog updates where technically possible.
- Inspect the real libraries, APIs, manifests or source repositories; do not
  invent module data.
- Verify install and uninstall end to end.

## Declined (do not pick up again)

- Settings search (struck from the plan).
- Removing the macOS, tvOS and Mac Catalyst targets and their build scripts
  (the approved plan keeps all four schemes; only revisit if the user asks).

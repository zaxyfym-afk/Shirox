# Todo

## 1. First green build (Codemagic primary, Actions backup)

- Builds start ONLY through the Codemagic API and ONLY on the user's
  explicit authorization (pushes do not trigger Codemagic; no webhook).
  The tool is `python3 /home/z/my-project/scripts/codemagic.py`:
  `build --authorized` = trigger exactly one build on main + poll 5 s +
  report; also `trigger --authorized`, `wait <id>`, `status`, `logs`,
  `errors <id>` (real `error:` diagnostics with file:line, grouped),
  `artifacts <id>` (IPA download URLs), `builds`, `apps`. Token:
  .scratch/codemagic-token (outside the repo; never printed or committed).
- Build 1 (ac59ac3) failed on the missing Metal Toolchain, fixed in
  codemagic.yaml and confirmed working. Build 2 (6eb9103) failed on the
  SettingsPickers.swift namespace scope error, fixed in cd8c299. Build 3
  (d614cc7 tip, 4m48s) failed on thirteen error groups across 13 files,
  fixed in a2d832c (the app's iOS floor is 15.0, not 17.0 — that is the
  tests target). a2d832c is UNBUILT: the next build is build 4, awaiting
  the user's go.
- On failure: `errors <buildId>` gives the real diagnostics; fix, commit,
  push (a push triggers only the GitHub nightly backup), ask for
  authorization, rebuild. Do not rebuild unchanged code; do not assume
  every exit code 65 is the same error.
- GitHub Actions stays as backup: push-triggered plus crons at 21:07 and
  03:07 UTC (macos-15, Xcode 26.3). It cannot get a runner at European
  peak; the crons land in the quiet windows.
- Pushing while a nightly run is still PENDING supersedes (cancels) it;
  use `[skip ci]` on docs-only pushes.
- Remaining compile risk areas: the four availability-heavy ports (launch
  screen, toasts, sticky sections, tour). The launch screen's
  `animation(_:body:)` uses are gone with its iOS 15 rewrite in a2d832c.
- Verify the built SHA equals the pushed SHA, then deliver the artifact
  link and the run link.

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

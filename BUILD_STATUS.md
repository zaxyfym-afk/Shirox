# Build status

## Current state (2026-11-21, restoration arc)

- The restoration arc's code is PUSHED but NOT YET BUILT at the time of this
  note: the Codemagic build starts right after the push, via the API, on the
  user's standing authorization. Every mechanism from the sixth session is
  unchanged: codemagic.yaml (Metal toolchain first, then buildipa.sh, then
  the IPA verification), builds only by API, scripts/codemagic.py, token via
  CODEMAGIC_API_TOKEN.
- What the build will see for the first time: the five-tab enum, the
  toolbar's sharedBackgroundVisibility branches (iOS 26-gated), the
  window-anchored blob, the detail pages' first refreshable, the new
  ToggleFavourite mutation, the redesigned onboarding and the settings
  header system. Known risk areas: the ToolbarContentBuilder's
  availability branches and the CinematicPage init gaining a parameter.

## Current state (2026-11-20, evening UTC)

- Codemagic is the PRIMARY builder now. The repo is connected to a Codemagic
  app ("Shirox", id 6b007bef80479dc6751778f3, Mac mini M2, latest Xcode) and
  codemagic.yaml at the repo root drives it: Metal toolchain install, then
  the same buildipa.sh (unsigned IPA at build/Shirox.ipa), then an IPA
  verification step, artifacts build/Shirox.ipa + build/dSYMs. CORRECTION of
  an earlier claim here: pushes do NOT start Codemagic builds. Despite the
  triggering section in codemagic.yaml, no webhook delivers push events
  (proven: a2d832c, pushed 18:08 without [skip ci], never built). Builds 1-3
  were started from the dashboard; from build 4 on, builds start through
  the API, only on the user's explicit authorization.
- First compile verdict of the redesign came from Codemagic build 1
  (6b007c7f8f52ca27512968dd, ac59ac3): failed compiling
  Shirox/Views/Shared/AlphaThreshold.metal, "cannot execute tool 'metal'
  due to missing Metal Toolchain". Environment problem, not a shader bug;
  fixed by the Install Metal Toolchain step in codemagic.yaml (xcodebuild
  -downloadComponent metalToolchain), CONFIRMED working in build 2. Do not
  undo that step.
- Codemagic build 2 (6b007de98f52ca275129695b, 6eb9103, 2m14s): the Metal
  stage passed and the Swift build started, then failed. The error:
  SettingsPickers.swift:194, attribute 'private' can only be used in a
  non-local scope, from `@Namespace private var capsule` declared inside
  the computed segmentedControl property of ThemePickerSheet.
- Fixed in cd8c299: the namespace moved to the view's stored properties
  (right below `@State private var isDark`). It was the only mis-scoped
  wrapper in the repo; the other 14 @Namespace declarations were checked
  and are already at view scope. That push also carried 4b93a9d (a second
  daily cron, 21:07 UTC, in the European-night quiet window).
- Codemagic build 3 (6b0083b58f52ca2751296b63, 17:31-17:36, 4m48s) ran on
  d614cc7 — the tip when it started; code identical to cd8c299 for compile
  purposes. The namespace fix held, and the compile moved into the
  redesign's real error surface — exit 65, thirteen error groups / 45 raw
  diagnostics across 13 files.
- The big discovery in build 3's log: the APP target's iOS deployment floor
  is 15.0. The 17.0 in the project belongs to the ShiroxTests target, which
  an earlier note here had confused. The redesign had written 16/17/26-only
  APIs into ungated code (LaunchScreen's AnyLayout, visualEffect, named
  springs, Task.sleep(for:), presentationBackground, geometryGroup; AnyShape
  in the tour).
- Fixed in a2d832c, one commit, all thirteen errors, no features removed.
  Scope and type errors: Self in two stored-property initializers
  (ModuleStoreEntry, ModuleStoreService), optional chaining on a
  non-optional AppIconOption (CustomizationSettingsView), the generic nested
  StickySection.Config hoisted to file-scope StickySectionConfig,
  Image(decorative:) given its 17 gate with an Image(uiImage:) fallback
  (ProfilesView), the optional screenshots guard (ModuleStoreView), and the
  ShiroxApp type-check timeout decomposed into a tabCell helper.
  Availability ladders: LaunchScreen rewritten to run on the iOS 15 floor
  with the same behavior on 17+ (the project's View+AdaptiveSheet shim
  pattern), AnyTourShape (an iOS 15 shape eraser) replacing AnyShape in the
  tour plus @ViewBuilder on its two extension methods, TypingAnimation and
  MorphingBlob gated to 18, Toast made Equatable for animation(value:).
  Access fix: the theme scene's private Color constants made fileprivate
  (private extension members don't reach other types in the same file).
- The authorized API loop, 2026-11-20 19:53-20:24 UTC, ran three builds to
  the first green build of the redesign. Build 4 (6b00a5412c8557a2754b8cbe,
  on 9b7d783e, failed 3m19s): the thirteen fixes held, and the compile
  moved on — 7 new errors in 4 files, fixed in 89e2166 (ShiroxApp's
  tabCell: a ViewBuilder cannot build `Tab`, and TabContent.badge takes an
  Int; a second type-check timeout on the pre-18 tabItem chain, extracted
  into legacyTabCell; LaunchScreen's `.task` chained on an if/else block,
  wrapped in a Group; ProfilesView's Image(decorative:) is asset-name-only,
  so Image(uiImage:); StickySection's .fill.tertiary gated to 17+ with
  UIKit's tertiarySystemFill below). Build 5 (6b00a8e5cf51ef96776f360c, on
  89e21666, failed 2m34s): TabContentBuilder is generic
  (@TabContentBuilder<Int>), and View.badge also takes a non-optional Int —
  the redesign's Int? badge had never actually compiled (builds 3 and 4
  died before reaching it); fixed in e21f70d. Build 6
  (6b00aad5c1876cf706761326, on e21f70de): FINISHED, 5m04s, every step
  green, Verify IPA passed, built SHA = pushed SHA. Unsigned Shirox.ipa
  27.1 MB (v1.1.0 build 127, iPhoneOS, min iOS 15.0) plus
  Shirox.app.dSYM.zip 21.3 MB. Artifacts come from `artifacts <buildId>`:
  the v3 short_lived_download_url links are signed (no auth needed, but
  short-lived — regenerate with the same command); the v1
  /artifacts/<uuid>/<uuid>/<file> form needs the x-auth-token header.
  Codemagic's success status string is "finished".
- Artifact links, learned by probing (2026-11-20 ~20:40 UTC): the signed
  api.codemagic.io URL sniffs the client. Browsers (iPhone Safari included)
  get a 302 to an itms-services:// install manifest — the "Install" option
  the user saw, useless for an unsigned IPA (nothing is signed to install).
  Every other client gets a 302 to a presigned storage.googleapis.com URL
  holding the raw file — and that presign lives about ONE MINUTE, so a
  pasted "direct link" can never survive a chat. No query parameter
  (download/direct/file/...) changes the sniffing. The robust delivery is
  the file itself: `ipa --download <path>` resolves a fresh presign and
  downloads in one shot. Done for build 6: workspace download/Shirox.ipa,
  28445186 bytes, sha256
  4c6039d32fd4a43c8320c2831f36f38facbb4d131e40e7005d8c32fb7f0af2ce,
  verified as a real Payload/Shirox.app zip (778 files). scripts/codemagic.py
  now prints BOTH links per artifact (direct file URL with its expiry +
  the install page) in artifacts/report, and `ipa [buildId] [--download P]`
  re-fetches fresh links for the latest green build on every run — it
  never triggers a build. Expired link: re-run the command; do not rebuild
  for links.
- GitHub Actions stays as the backup: the nightly runs on push and on two
  crons (21:07 and 03:07 UTC, macos-15, Xcode 26.3 pinned via
  DEVELOPER_DIR). It still cannot get a runner at European peak: the runs
  queued 2026-11-20 between 14:09 and 17:38 UTC were all cancelled after
  ~15 minutes with no runner ever assigned. The cron times sit in the
  windows that have always landed (23:30-02:41 UTC). KNOWN GAP: the
  nightlies on 89e2166 (run 44808737313) and e21f70d (44809997043) got
  runners and FAILED for real — under the pinned Xcode 26.3 the same green
  code hits three of its own errors (a type-check timeout at
  HLSManifestParser.swift:152, "ambiguous use of operator '-'" at
  PosterViewer.swift:37, and '*' at SettingsPickers.swift:447) that
  Codemagic's Xcode 26.6 compiles fine. The backup needs its own pass:
  fix those three spots or unpin to the latest Xcode in nightly.yaml.

## Next build procedure (the API era)

Pushes do NOT start Codemagic builds (no webhook). A build starts only
through the API, only on the user's explicit authorization. On "build the
IPA":

1. Commit and push any pending work; verify the remote SHA
   (`git ls-remote origin main`). Pushes trigger the GitHub nightly
   (backup); a push while a nightly run is PENDING supersedes it. Docs-only
   pushes carry `[skip ci]` so no Actions run starts.
2. `python3 /home/z/my-project/scripts/codemagic.py build --authorized`
   starts exactly one build on main (workflow shirox-ios-ipa), records the
   build id + commit SHA in .scratch/codemagic-build-log.jsonl, polls every
   5 s (429-aware backoff), and prints the final report. Separate tools:
   `trigger --authorized`, `wait <id>`, `status <id>`, `logs <id>`,
   `errors <id>` (real `error:` diagnostics, file:line, grouped),
   `artifacts <id>`, `report <id>`, `builds`, `apps`. All tested against
   build 3's real data.
3. On failure: `errors <buildId>` gives the real compiler errors. Fix,
   commit, push, ask for authorization again. Do not rebuild unchanged
   code, and do not assume every exit code 65 is the same error.
4. On success: `report`/`artifacts` print the unsigned IPA download URL
   (short-lived signed link from the API); verify the built commit SHA
   equals the pushed SHA before delivering anything.

API map (base https://api.codemagic.io, header `x-auth-token`):
GET /apps; GET /builds?limit=N; GET /builds/{id} (the build doc sits in
"build": status, artefacts, buildActions with per-step logUrl,
commit.hash, fileWorkflowId); POST /builds {appId, workflowId, branch} ->
{buildId}; POST /builds/{id}/cancel (208 when already finished); step logs
at GET /builds/{id}/step/{actionId} (plain text, HTML-escaped); v3 mirror
at codemagic.io/api/v3/builds/{id} (+ /actions; artifacts there carry
short_lived_download_url).

## Known compile risk areas

The primary (Codemagic, Xcode latest) is green end to end since build 6.
Remaining compile risk lives in the backup's pinned Xcode 26.3 (the three
errors in the bullet above) and in the never-yet-built macOS/tvOS/Catalyst
targets (the user's Mac). The four availability-heavy ports (launch screen,
toasts, sticky sections, tour) all compiled and are inside the green IPA.

## History

| Date (UTC) | Commit | Result | Notes |
|---|---|---|---|
| 2026-11-19 23:30 | 21a185a | success | pre-redesign |
| 2026-11-20 01:45 to 02:41 | 5a80473, 95e4262, bfeb07a | success | pre-redesign; the IPA on the `latest` release is from bfeb07a |
| 2026-11-20 14:09 | db1f1c9 | cancelled in queue | macos-26: no runner at European peak |
| 2026-11-20 14:44 | 0d88a56 | cancelled in queue | same |
| 2026-11-20 15:03 | 1a4ebbf | cancelled in queue | same; survived 25 min, so not a fixed timer |
| 2026-11-20 15:26 | 691b25d | cancelled in queue | run 5, first macos-15 attempt: same, 15:02 in queue |
| 2026-11-20 16:17 | 0ada78d | cancelled in queue | dispatched; 15:12 in queue |
| 2026-11-20 16:33 | 0ada78d | cancelled in queue | dispatched; 15:04 in queue |
| 2026-11-20 16:51 | 0ada78d | cancelled in queue | dispatched; 15:03 in queue |
| 2026-11-20 16:58 | ac59ac3 | cancelled in queue | superseded by the 6eb9103 push while pending |
| 2026-11-20 17:05 | 6eb9103 | cancelled in queue | superseded by the cd8c299 push while pending |
| 2026-11-20 | ac59ac3 | Codemagic failed | build 1 6b007c7f8f52ca27512968dd: missing Metal Toolchain at AlphaThreshold.metal |
| 2026-11-20 | 6eb9103 | Codemagic failed | build 2 6b007de98f52ca275129695b, 2m14s: Metal fixed; SettingsPickers.swift:194 namespace scope |
| 2026-11-20 17:31 | d614cc7 | Codemagic failed | build 3 6b0083b58f52ca2751296b63, 4m48s: Metal ok, namespace ok; 13 error groups (16/17 APIs against the 15.0 app floor, scope and type errors). GitHub nightly 44782836661 starved in queue, 15:06 |
| 2026-11-20 18:08 | a2d832c | built as build 4's base | the thirteen-fix code first compiled in build 4 (on 9b7d783, docs + script on top); GitHub nightly 44789885826 got a runner late and was cancelled mid-run, no verdict |
| 2026-11-20 19:53 | 9b7d783 | Codemagic failed | build 4 6b00a5412c8557a2754b8cbe, 3m19s: 7 errors in 4 files (tabCell builder/badge, tabItem chain timeout, .task on if/else, Image(decorative:) String, .fill.tertiary 17+). Fixed in 89e2166 |
| 2026-11-20 20:09 | 89e2166 | Codemagic failed | build 5 6b00a8e5cf51ef96776f360c, 2m34s: @TabContentBuilder needs <Int>; View.badge takes a plain Int (the old Int? badge never compiled). Fixed in e21f70d. Nightly 44808737313: real failure under Xcode 26.3 |
| 2026-11-20 20:15 | e21f70d | Codemagic GREEN | build 6 6b00aad5c1876cf706761326, 5m04s, finished: FIRST GREEN BUILD of the redesign; Shirox.ipa 27.1 MB verified (min iOS 15.0), built SHA = pushed SHA. Nightly 44809997043: Xcode 26.3 fails on 3 of its own (HLSManifestParser timeout, PosterViewer '-', SettingsPickers '*') |

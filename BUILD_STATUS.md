# Build status

## Current state (2026-11-20, evening UTC)

- Codemagic is the PRIMARY builder now. The repo is connected to a Codemagic
  app ("Shirox", Mac mini M2, latest Xcode, webhook on push to main) and
  codemagic.yaml at the repo root drives it: Metal toolchain install, then
  the same buildipa.sh (unsigned IPA at build/Shirox.ipa), then an IPA
  verification step, artifacts build/Shirox.ipa + build/dSYMs.
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
- Codemagic build 3 ran on cd8c299: the namespace fix held, and the compile
  moved into the redesign's real error surface — exit 65, thirteen errors
  across 13 files.
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
- Codemagic build 4 runs on a2d832c (push webhook). Its verdict is on the
  Codemagic dashboard (no API token in this sandbox). The redesign still has
  never linked, so more rounds are possible.
- GitHub Actions stays as the backup: the nightly runs on push and on two
  crons (21:07 and 03:07 UTC, macos-15, Xcode 26.3 pinned via
  DEVELOPER_DIR). It still cannot get a runner at European peak: the runs
  queued 2026-11-20 between 14:09 and 17:38 UTC were all cancelled after
  ~15 minutes with no runner ever assigned. The cron times sit in the
  windows that have always landed (23:30-02:41 UTC).

## Next build procedure

1. Push local main and verify the remote SHA (`git ls-remote origin main`).
   Note: a push while a nightly run is still PENDING supersedes (cancels) it;
   a push while one is RUNNING does not. Use `[skip ci]` on docs-only pushes.
2. Every push to main triggers both a Codemagic build (webhook; primary,
   its dashboard is the verdict) and the GitHub nightly (backup).
3. Codemagic logs are read on the dashboard (no API token here). If a token
   is added to the sandbox later, the Codemagic builds API can be polled.
4. GitHub nightly: poll the run authenticated; on failure read the failing
   step's logs. A dispatch, if one is needed:
   `curl -X POST -H "Authorization: Bearer $PAT" -H "Accept: application/vnd.github+json" https://api.github.com/repos/zaxyfym-afk/Shirox/actions/workflows/nightly.yaml/dispatches -d '{"ref":"main"}'`
5. Fix, commit, push, rebuild, until green. Do not rebuild unchanged code,
   and do not assume every exit code 65 is the same error. Verify the built
   commit equals the pushed SHA, then deliver the artifact link, the run
   link and the release download.

## Known compile risk areas (never yet linked)

- The four availability-heavy ports: launch screen (485765a, rewritten to
  the iOS 15 floor in a2d832c), toasts (50458de), sticky sections (421723b),
  tour (ab31eae, platform guards in 4585a2a).
- iOS availability guards across the platform ladder (26 / 18 / Mac /
  tvOS); the app's floor is iOS 15, the tests' is 17.

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
| 2026-11-20 17:23 | cd8c299 | Codemagic failed | build 3: Metal ok, namespace ok; 13 errors (16/17 APIs against the 15.0 app floor, scope and type errors). GitHub nightly 44782836661 starved in queue, 15:06 |
| 2026-11-20 18:08 | a2d832c | pending | build 4: the thirteen errors fixed; GitHub nightly 44789885826 as backup |

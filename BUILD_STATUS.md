# Build status

## Current state (2026-11-20, early evening UTC)

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
  daily cron, 21:07 UTC, in the European-night quiet window). Codemagic
  build 3 on cd8c299 is auto-triggered by the push webhook; its verdict
  lands on the Codemagic dashboard (no API token in this sandbox, so the
  dashboard is the source of truth for it).
- GitHub Actions stays as the backup: the nightly runs on push and on two
  crons (21:07 and 03:07 UTC, macos-15, Xcode 26.3 pinned via
  DEVELOPER_DIR). It still cannot get a runner at European peak: five more
  attempts on 2026-11-20 (dispatched 16:17, 16:33 and 16:51, plus two runs
  superseded while pending) each waited ~15 minutes in queue and were
  cancelled with no runner ever assigned. The cron times sit in the
  windows that have always landed (23:30-02:41 UTC).
- The redesign is still not compiled green anywhere. Build 2 was the first
  real Swift verdict; more errors past SettingsPickers.swift are expected.
  The risk areas are unchanged, below.

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

## Known compile risk areas (never yet compiled green)

- The four availability-heavy ports: launch screen (485765a), toasts
  (50458de), sticky sections (421723b), tour (ab31eae, platform guards in
  4585a2a).
- The `animation(_:body:)` calls in LaunchScreen.swift (iOS 17 API; the
  deployment target is 17.0).
- iOS availability guards across the platform ladder (26 / 18 / Mac / tvOS).

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
| 2026-11-20 17:23 | cd8c299 | pending | Codemagic build 3 (dashboard) + GitHub nightly 44782836661 (backup) |

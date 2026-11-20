# Build status

## Current state (2026-11-20, late afternoon UTC)

- Remote main: 691b25d. Everything is pushed and verified. The tree is green
  on every check that can run without a Mac: SwiftLint, Semgrep, Strings and
  icons all pass (the lint took two rounds: the fixer's own diffs at 0d88a56,
  then three hand fixes at 1a4ebbf).
- The redesign has still NEVER been compiled. The first runner that picks the
  build up renders that verdict; the risk areas are unchanged, below.
- Runner starvation, root-caused: the macos-26 free pool never allocated a
  runner at European peak. Three nightly runs (db1f1c9 at 14:09, 0d88a56 at
  14:44, 1a4ebbf at 15:03 UTC) each waited in queue for 15 to 25 minutes and
  were then cancelled with no runner ever assigned, while every successful
  build this month landed between 23:30 and 02:41 UTC. GitHub's own status
  was fully operational and the billing shows net zero (public repo), so it
  is pool capacity at peak, not us.
- The fix, 691b25d: the build job moved to the macos-15 pool (a different
  queue) with Xcode 26.3 pinned via DEVELOPER_DIR (the macos-15 image default
  is 16.4, too old for the iOS 26 availability guards), plus a daily cron at
  03:07 UTC, inside the quiet window that has always landed. The workflow is
  active; the cron builds even if a peak attempt starves.
- Run 5 (44763289051, on 691b25d) was still queued on macos-15 when this was
  written. Whatever happens to it, the next guaranteed build is the 03:07 UTC
  cron; any push to main also triggers one.

## Next build procedure

1. Push local main and verify the remote SHA (`git ls-remote origin main`).
   Note: a push while a nightly run is still PENDING supersedes (cancels) it;
   a push while one is RUNNING does not. Use `[skip ci]` on docs-only pushes.
2. The push triggers the nightly. If a dispatch is needed:
   `curl -X POST -H "Authorization: Bearer $PAT" -H "Accept: application/vnd.github+json" https://api.github.com/repos/zaxyfym-afk/Shirox/actions/workflows/nightly.yaml/dispatches -d '{"ref":"main"}'`
3. Poll the run (authenticated; respect rate limits).
4. On failure: read the failing step's logs, fix, commit, push, rebuild.
5. Verify the run's head_sha equals the pushed SHA, then deliver the artifact
   link, the run link and the release download.

## Known compile risk areas (never yet compiled)

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
| 2026-11-20 15:40 | 691b25d | run 5, queued at press time | first macos-15 attempt, Xcode 26.3 |
| 2026-11-21 03:07 | cron | scheduled | the daily build lands in the quiet window |

# Build status

## Current state (2026-11-20)

- Last successful build: the nightly ran on bfeb07a, before the redesign.
  "Shirox 1.1.0 (127)" on the `latest` release, updated 2026-11-20 02:51 UTC,
  asset present (HTTP 200). It does NOT contain the redesign.
- Remote main: e7a92a9 (the bot's apps.json stamp). Local main: the redesign
  tip plus merge and docs commits; never built anywhere yet.
- The sandbox cannot build (no Swift toolchain on Linux). Builds run on
  GitHub Actions via .github/workflows/nightly.yaml: push to main or
  workflow_dispatch, concurrency group `nightly`, macos-26 runner, unsigned
  IPA (CODE_SIGNING_ALLOWED=NO), artifact `Shirox-Nightly-IPA`, release tag
  `latest`, release renamed from apps.json.

## Next build procedure

1. Push local main and verify the remote SHA (`git ls-remote origin main`).
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

| Date | Commit | Result | Notes |
|---|---|---|---|
| 2026-11-20 02:51 UTC | bfeb07a | success | pre-redesign; Shirox 1.1.0 (127) on the `latest` release |
| 2026-11-20 | local redesign tip | not started | push blocked on a PAT; everything staged |

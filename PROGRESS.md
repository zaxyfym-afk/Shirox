# Progress

Updated: 2026-11-20, fifth session (Codemagic era: API automation ready).

## Where things stand

- Remote `origin/main`: ae79d4b, verified with `git ls-remote` (2026-11-20
  18:21 UTC). Pushed in this arc: 4b93a9d (second cron), cd8c299
  (namespace fix), d614cc7 (docs), a2d832c (thirteen compile fixes),
  ae79d4b (docs). The user pushed ac59ac3 and 6eb9103 themselves
  (codemagic.yaml and its Metal Toolchain step).
- Codemagic is the primary builder, driven by API now. Pushes do NOT build
  (no webhook; an earlier note here was wrong); builds start only through
  the API on explicit authorization. Verdicts so far: build 1 failed on a
  missing Metal Toolchain (fixed in codemagic.yaml by the user, confirmed
  working), build 2 on the SettingsPickers.swift namespace scope error
  (fixed in cd8c299), build 3 (on d614cc7, 4m48s) on thirteen error groups
  across 13 files (fixed in a2d832c; the app's iOS floor turned out to be
  15.0, and 16/17/26-only APIs in ungated code were the root of most of
  them). The API integration is ready and tested against build 3's real
  data: scripts/codemagic.py (build --authorized / trigger / wait / logs /
  errors / artifacts / report), token at .scratch/codemagic-token. a2d832c
  is still unbuilt; the next build starts on the user's say-so.
- The redesign is still not compiled green anywhere. SwiftLint, Semgrep,
  Strings and icons are green. The full build story, including GitHub
  Actions' peak starvation and its two quiet-window crons, is in
  BUILD_STATUS.md.
- The `latest` release IPA ("Shirox 1.1.0 (127)", 2026-11-20 02:51 UTC) was
  built from bfeb07a, before the redesign. It does not contain the new work.
- Full backup: `shirox-local-backup-2026-11-20.bundle` in the workspace root.

## Completed (local and remote are the same history now)

| Commit | Work |
|---|---|
| 40b2d46 | Home top bar: calendar + bell replace the provider dropdown |
| 3f62281 | MorphingRefresh on the native refresh control |
| eecd447 | Week-paged HorizontalCalendar for the schedule |
| 1ab3290 | AniList + MAL onboarding sign-in cards |
| 2b06e8b | Notifications tab (Activity + Episodes), unread badge |
| 720f58f | 12 bundled profile avatars, colour on every avatar state |
| b048544 | Module Store foundation (catalog, service, tab, ModuleManager bridge) |
| 6cc26c7 | Settings: intro cards out, SettingsIconTile and SettingsToggleRow in |
| 1326438 | Settings root regrouped, one door per destination |
| 440ad83 | Theme and app icon pickers as scenes on iOS 26 |
| 485765a | Splash carries on from the launch screen (iOS and Catalyst) |
| 50458de | Toasts: stacked glass capsules, mesh tint on iOS 26 |
| 421723b | Home rows as sticky cards on iOS 18 |
| ab31eae | Home tour: coach marks for calendar and bell, runs once |
| 470d325 | Onboarding page 0 typewriter |
| 280bb1e | The last 33 bare settings headers become SettingsSectionHeader |
| 4585a2a | Tour platform guards (no tour on Mac and tvOS) |

Session four on top: 045a789 (merge of the bot's apps.json stamp), db1f1c9
(docs), 0d88a56 and 1a4ebbf (lint green), 691b25d (build CI), 0ada78d
(docs). Session five on top: the user's ac59ac3 and 6eb9103 (codemagic.yaml
and the Metal Toolchain step), 4b93a9d (second cron), cd8c299 (namespace
fix), d614cc7 (docs), a2d832c (the thirteen compile errors of build 3),
ae79d4b (docs). The Codemagic API-era docs ride on top ([skip ci], no
Actions run; see BUILD_STATUS.md for the corrected triggering facts).

## Pending, in order

1. First green build of the redesign: on the user's authorization, run
   `python3 /home/z/my-project/scripts/codemagic.py build --authorized`
   (starts exactly one build on main, records the id + SHA, polls every
   5 s, reports). On failure: `errors <buildId>` for the real diagnostics,
   fix, push, ask for authorization again. GitHub Actions stays as backup
   with crons at 21:07 and 03:07 UTC.
2. After green: verify the built SHA, deliver the IPA, then the verification
   list in TODO.md.
3. Module Store completion (TODO.md). The catalog research is done: 287 real
   modules from both libraries, 147 anime plus 45 multi, in
   .scratch/module-research/ (copy under download/) waiting to be wired in.

## Blocked

Nothing in code. The only wall was macOS runner capacity at European peak,
now handled by the macos-15 pool and the 03:07 UTC cron.

## Latest verified GitHub commit

ae79d4b (Docs: compile round 3, the thirteen errors and the iOS 15 floor),
verified 2026-11-20 18:21 UTC by `git ls-remote`; a2d832c, the code fix
commit, is the one below it.

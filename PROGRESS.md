# Progress

Updated: 2026-11-20, fifth session (Codemagic era: the first compile verdicts).

## Where things stand

- Remote `origin/main`: cd8c299, verified with `git ls-remote` after every
  push. Pushed this session: 4b93a9d (a second daily cron, 21:07 UTC) and
  cd8c299 (the SettingsPickers.swift namespace fix). The user pushed
  ac59ac3 and 6eb9103 themselves (codemagic.yaml and its Metal Toolchain
  step).
- Codemagic is the primary builder now (the repo is connected; every push
  to main builds). Its first two builds gave the redesign its first real
  compile verdicts: build 1 failed on a missing Metal Toolchain (fixed in
  codemagic.yaml by the user, confirmed working in build 2), build 2 failed
  on the SettingsPickers.swift namespace scope error (fixed in cd8c299).
  Build 3 on cd8c299 is auto-triggered; its verdict is on the Codemagic
  dashboard (no API token in this sandbox).
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
fix).

## Pending, in order

1. First green build of the redesign: Codemagic build 3 on cd8c299 (the
   dashboard has the verdict; no API token here). On compile errors: read
   the log, fix, push (which rebuilds), repeat. GitHub Actions stays as
   backup with crons at 21:07 and 03:07 UTC.
2. After green: verify the built SHA, deliver the IPA, then the verification
   list in TODO.md.
3. Module Store completion (TODO.md). The catalog research is done: 287 real
   modules from both libraries, 147 anime plus 45 multi, in
   .scratch/module-research/ (copy under download/) waiting to be wired in.

## Blocked

Nothing in code. The only wall was macOS runner capacity at European peak,
now handled by the macos-15 pool and the 03:07 UTC cron.

## Latest verified GitHub commit

cd8c299 (fix: move theme picker namespace to view scope), verified
2026-11-20 by `git ls-remote`.

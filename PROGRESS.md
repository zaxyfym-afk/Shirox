# Progress

Updated: 2026-11-20, fourth session (recovery, sync, lint, CI).

## Where things stand

- Remote `origin/main`: 691b25d, verified with `git ls-remote` after every
  push. Pushed this session: db1f1c9 (the 17 redesign commits + merge + the
  five memory files), 0d88a56 (swiftlint's own fixes, extracted from CI's
  diff), 1a4ebbf (three hand lint fixes), 691b25d (macos-15 + Xcode 26.3 +
  the 03:07 UTC cron).
- The redesign is fully on GitHub. SwiftLint, Semgrep, Strings and icons are
  green. The code has never been compiled (no Swift toolchain in the sandbox,
  and the macOS pool starved at European peak all afternoon; the full story
  and the automation that replaces the waiting are in BUILD_STATUS.md).
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
(docs), 0d88a56 and 1a4ebbf (lint green), 691b25d (build CI).

## Pending, in order

1. First green build of the redesign: run 5 (44763289051) or the 03:07 UTC
   cron. On compile errors: read the logs, fix, push, repeat.
2. After green: verify the built SHA, deliver the IPA, then the verification
   list in TODO.md.
3. Module Store completion (TODO.md). The catalog research is done: 287 real
   modules from both libraries, 147 anime plus 45 multi, in
   .scratch/module-research/ (copy under download/) waiting to be wired in.

## Blocked

Nothing in code. The only wall was macOS runner capacity at European peak,
now handled by the macos-15 pool and the 03:07 UTC cron.

## Latest verified GitHub commit

691b25d (ci: macos-15 with Xcode 26.3 for the IPA, and a 03:07 UTC cron),
verified 2026-11-20 by `git ls-remote`.

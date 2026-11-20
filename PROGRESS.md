# Progress

Updated: 2026-11-20, fourth session (recovery and sync audit).

## Where things stand

- Remote `origin/main`: e7a92a9, the nightly bot's apps.json stamp on top of
  bfeb07a (verified 2026-11-20 by `git ls-remote` and `git fetch`).
- Local `main`: bfeb07a + the seventeen redesign commits + merge 045a789
  (folding in e7a92a9) + the docs commit that added these files. Clean tree.
  The redesign is NOT on GitHub yet.
- The `latest` release IPA ("Shirox 1.1.0 (127)", updated 2026-11-20 02:51
  UTC) was built from bfeb07a, before the redesign. It must not be mistaken
  for current work.
- Full backup: `shirox-local-backup-2026-11-20.bundle` in the workspace root
  (taken before the merge; re-taken after the docs commit).

## Completed (local main, on top of bfeb07a)

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

All seventeen passed the sandbox checks (i18n, icons, icon packs, pbxproj
structure). None has ever been compiled (no Swift toolchain in the sandbox).

## In progress

Nothing. The redesign arc's sandbox work is complete; no half-written files.

## Pending, in order

1. Push local main to origin (blocked, see below) and verify the remote SHA.
2. First Actions build of the redesign: watch the nightly run, fix compile
   errors (risk areas in BUILD_STATUS.md), push, rebuild, until green.
3. The full verification list: four scheme builds, the ShiroxTests suite,
   the on-device checks (details in TODO.md).
4. Module Store completion (details in TODO.md).

## Blocked

- Push and build: this session has no GitHub credentials. No PAT is stored on
  disk by policy, so the user has to paste one (contents: write, actions:
  write). Everything is staged: local main is a fast-forward for origin/main,
  the tree is clean, a bundle backup exists.

## Latest verified GitHub commit

e7a92a9 (chore: update apps.json [skip ci], on top of bfeb07a), verified
2026-11-20. No redesign commit is on GitHub yet; the next verified SHA gets
recorded here after the push.

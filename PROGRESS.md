# Progress

Updated: 2026-11-20, sixth session (the first green build: Codemagic build 6).

## Where things stand

- Remote `origin/main`: 3858330 (the poller's finished-status fix),
  verified with `git ls-remote` 2026-11-20 20:29 UTC; the green-build docs
  ride on top ([skip ci]). Pushed in this arc: 4b93a9d (second cron),
  cd8c299 (namespace fix), d614cc7 (docs), a2d832c (thirteen compile
  fixes), ae79d4b (docs), 9b7d783 (scripts/codemagic.py into the repo),
  b8b4d81 (poller phase fix), 89e2166 (build 4's seven errors), e21f70d
  (build 5's three), 3858330 (finished-status fix). The user pushed
  ac59ac3 and 6eb9103 themselves (codemagic.yaml and its Metal Toolchain
  step).
- Codemagic is the primary builder, driven by API: `build --authorized`
  triggered each build, `wait` polled every 5 s, `errors` pulled the real
  diagnostics, `artifacts` delivered the signed links. The loop: build 4
  failed (7 errors: the tab bar's TabContent builder, a second type-check
  timeout, .task on an if/else, Image(decorative:) being asset-name-only,
  .fill.tertiary being 17+), fixed in 89e2166; build 5 failed (3 errors:
  @TabContentBuilder<Int>, View.badge wanting a plain Int — the redesign's
  Int? badge had never actually compiled), fixed in e21f70d; BUILD 6
  FINISHED GREEN (6b00aad5c1876cf706761326, on e21f70de, 5m04s): the
  first green build of the redesign, Verify IPA passed, built SHA = pushed
  SHA, unsigned Shirox.ipa 27.1 MB (1.1.0 (127), iPhoneOS, min iOS 15.0)
  plus dSYMs. The token is at .scratch/codemagic-token; the script now
  lives in the repo at scripts/codemagic.py.
- The redesign is GREEN on the primary for the first time (build 6). The
  GitHub backup nightly still fails under its pinned Xcode 26.3 (three
  errors of its own: a HLSManifestParser type-check timeout, an ambiguous
  '-' in PosterViewer, an ambiguous '*' in SettingsPickers) — the full
  story is in BUILD_STATUS.md. SwiftLint, Semgrep, Strings and icons are
  green.
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
ae79d4b (docs). Session six on top: 9b7d783 (scripts/codemagic.py into
the repo), b8b4d81 (poller phase fix), 89e2166 (build 4's seven errors),
e21f70d (build 5's three), 3858330 (finished-status fix), plus the
green-build docs.

## Pending, in order

1. The GitHub backup nightly needs its own pass under Xcode 26.3: fix
   HLSManifestParser.swift:152's type-check timeout, PosterViewer.swift:37's
   ambiguous '-', and SettingsPickers.swift:447's ambiguous '*', or unpin
   DEVELOPER_DIR to the latest Xcode in nightly.yaml. Any of it needs a
   push; the Codemagic primary is already green.
2. The verification list in TODO.md section 2 (schemes, tests, on-device),
   now that a green IPA exists.
3. Module Store completion (TODO.md). The catalog research is done: 287 real
   modules from both libraries, 147 anime plus 45 multi, in
   .scratch/module-research/ (copy under download/) waiting to be wired in.

## Blocked

Nothing in code. The only wall was macOS runner capacity at European peak,
now handled by the macos-15 pool and the 03:07 UTC cron.

## Latest verified GitHub commit

3858330 (fix: codemagic poller knows finished), verified 2026-11-20
20:29 UTC by `git ls-remote`; e21f70d, the green-build fix commit, is two
below it. The green-build docs ride on top of 3858330.

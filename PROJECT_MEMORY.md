# Project memory

Read this file, PROGRESS.md, TODO.md and BUILD_STATUS.md at the start of every
session, then `git fetch origin` and compare local `main` with `origin/main`
before touching any code. The repo is the source of truth for code; these
files are the source of truth for state.

## What Shirox is

Shirox is a SwiftUI anime tracker (iOS, macOS, tvOS, Mac Catalyst), a fork of
xibrox/Shirox carrying a redesign arc from November 2026. The work fork lives
at github.com/zaxyfym-afk/Shirox and is public.

- Remotes: `origin` = zaxyfym-afk/Shirox (the work fork; Actions run here),
  `upstream` = xibrox/Shirox.
- Development happens in the z.ai Linux sandbox at `/home/z/my-project/repo`.
  That box has no Swift toolchain: nothing is ever compiled there. All builds
  go through Codemagic (primary since 2026-11-20), GitHub Actions (backup) or
  the user's Mac.
- The version lives in `apps.json` (1.1.0, build 127) and names the release.
- Port scripts and generators live OUTSIDE the repo, in the sandbox workspace
  at `/home/z/my-project/scripts/` (`ws*_strings.py`, `pbx_edit.py`,
  `poll_build.sh`, avatar and icon scratch dirs). The repo's own tools are
  `scripts/i18n/`, `scripts/icons/icons.py`, `scripts/check-commit-msg.sh`,
  and the `xcode_*.rb` / `add_files.rb` helpers at the root.
- Full-ref bundle backups of the local repo are written to the workspace root
  (`shirox-local-backup-*.bundle`). Restore with
  `git clone <bundle> -b main <dir>`.

## Targets and building

Four schemes, all kept building on purpose (the approved plan and CLAUDE.md
require it; do not remove the Mac paths unless the user asks again):
`Shirox_iOS`, `Shirox_macOS`, `Shirox_tvOS`, `Shirox_MacCatalyst`, plus
`buildipa.sh`, `buildcatalyst.sh`, `builddmg.sh`, `buildtvos.sh`.

Codemagic is the primary builder since 2026-11-20: the repo is connected to
a Codemagic app ("Shirox", Mac mini M2, latest Xcode, webhook on push to
main). codemagic.yaml installs the Metal Toolchain first (the app has a
Metal shader, Shirox/Views/Shared/AlphaThreshold.metal, and fresh CI
machines ship without the Metal compiler; that step is proven working and
must stay), then runs the same buildipa.sh, verifies the IPA and exposes
build/Shirox.ipa plus dSYMs as artifacts. The dashboard is the verdict;
there is no Codemagic API token in the sandbox.

GitHub Actions is the backup: the `nightly` workflow
(.github/workflows/nightly.yaml) runs on every push to main, on
workflow_dispatch and on two crons (21:07 and 03:07 UTC), one run at a time
(concurrency group `nightly`): it moves the `latest` tag to the commit,
builds an unsigned IPA on macos-15 with Xcode 26.3 pinned via DEVELOPER_DIR
(CODE_SIGNING_ALLOWED=NO), uploads artifact `Shirox-Nightly-IPA`, uploads
`Shirox.ipa` to the `latest` release, has the bot stamp size and date into
apps.json, and renames the release from apps.json. The free macOS pools do
not allocate at European peak: runs queued then are cancelled after about
15 minutes with no runner ever assigned, while every success this month
landed between 23:30 and 02:41 UTC, which is where the crons sit. Other
workflows: i18n, commit-messages, semgrep, swiftlint.

## The redesign arc (November 2026)

Seventeen commits on top of bfeb07a (SHAs and details in PROGRESS.md): the
home top bar (calendar + bell), MorphingRefresh, a week-paged horizontal
schedule calendar, AniList + MAL onboarding, a notifications tab, bundled
profile avatars, the Module Store foundation, the settings regroup with theme
and icon picker scenes on iOS 26, the splash carry-on, stacked glass toasts,
sticky home sections on iOS 18, the home tour, and the typewriter onboarding
page.

Platform ladder used throughout: iOS 26 gets scenes and mesh effects, iOS 18
gets sticky sections and the typewriter, Mac and tvOS keep the plain look and
are excluded from the tour. The `ToastManager` API was left untouched.

Known compile risk areas (verdicts so far: builds 2 and 3 died on a namespace
scope error and then thirteen more errors, all fixed; the app has still never
linked): the four availability-heavy ports (launch screen, toasts, sticky
sections, tour). The app target's iOS deployment floor is 15.0 — the 17.0 in
the project is the ShiroxTests target — so anything 16/17/18/26-only in
ungated code goes through the shim pattern in View+AdaptiveSheet.swift or an
#available branch. See BUILD_STATUS.md.

## Git discipline (the sync protocol)

GitHub is the source of truth. After every completed feature or logical group
of changes:

1. Save the modified files.
2. Run the sandbox checks (i18n, icons, icon packs, pbxproj structure).
3. Update PROGRESS.md, CHANGELOG.md, TODO.md, BUILD_STATUS.md.
4. Review the full `git diff`.
5. Commit in the repo's voice ("Area: what changed, in one line"; the message
   rules in scripts/check-commit-msg.sh: no em dash, no emoji, no hidden
   Unicode, no attribution trailers).
6. Push to origin main.
7. Verify with `git ls-remote origin main` (or a fetch) that the remote really
   has the commit. Never claim a push without this step.
8. Record the verified SHA in PROGRESS.md.

Never force-push, never overwrite newer remote work, never claim a build or a
push that was not verified, never confuse static checks with a successful
Xcode build. If a push or build fails, investigate, fix and retry.

## Credentials

GitHub credentials are never written to disk in the sandbox (by policy), so
each session that needs to push or dispatch a workflow must ask the user for
a PAT. It needs contents: write (push) and actions: write (dispatch), classic
or fine-grained, short expiry is fine. Everything above is arranged so that
the PAT is the only missing piece at any given moment.

#!/usr/bin/env python3
"""Codemagic API automation for the Shirox iOS IPA build.

Codemagic (https://api.codemagic.io) is the PRIMARY IPA builder; GitHub Actions
is the backup. This script talks to the official Codemagic REST API.

Commands
  apps                              List applications
  builds [--limit N]                Recent builds: index, status, commit, duration
  status <buildId>                  One build's details
  wait <buildId>                    Poll (default 5s) until the build finishes
  logs <buildId> [--all] [-o DIR]   Step logs (default: script + failed steps)
  errors <buildId>                  Compiler errors with file:line, grouped
  artifacts <buildId>               Artifacts with download URLs
  report <buildId>                  Full report: status, SHA, duration, errors/artifacts
  trigger --authorized [--branch B] [--workflow W]
                                    Start exactly ONE build on main. The
                                    --authorized flag is required: no build is
                                    ever started without explicit authorization.
  build --authorized                trigger + wait + report in one shot

The API token is read from CODEMAGIC_API_TOKEN, falling back to the file
named by CODEMAGIC_TOKEN_FILE (default: /home/z/my-project/.scratch/
codemagic-token in the z.ai sandbox). The token is never bundled with this
script, never printed, and never committed.
"""

import argparse
import html
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

API = "https://api.codemagic.io"
V3 = "https://codemagic.io/api/v3"
APP_ID = os.environ.get("CODEMAGIC_APP_ID", "6b007bef80479dc6751778f3")
WORKFLOW = os.environ.get("CODEMAGIC_WORKFLOW_ID", "shirox-ios-ipa")
BRANCH = "main"
TOKEN_FILE = os.environ.get(
    "CODEMAGIC_TOKEN_FILE", "/home/z/my-project/.scratch/codemagic-token"
)
BUILD_LEDGER = os.environ.get(
    "CODEMAGIC_BUILD_LEDGER", "/home/z/my-project/.scratch/codemagic-build-log.jsonl"
)


def default_repo():
    """The checkout this script lives in (scripts/..), else the sandbox path."""
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if os.path.isdir(os.path.join(here, ".git")):
        return here
    return "/home/z/my-project/repo"


REPO = os.environ.get("SHIROX_REPO") or default_repo()

# Codemagic reports the build's current PHASE as status while it runs
# (queued, preparing, fetching, building, publishing, finishing, ...). A
# build that runs to the end reports "finished" (the success state);
# failures report "failed". Only these are final; anything else keeps the
# poller going.
TERMINAL = {"succeeded", "success", "finished", "failed", "error",
            "cancelled", "canceled", "skipped"}
FAILED_STATES = {"failed", "error"}
CANCELLED_STATES = {"cancelled", "canceled"}
OK_STATES = {"succeeded", "success", "finished"}

ERROR_LINE = re.compile(
    r"^(?P<file>[^:\s][^:\n]*?):(?P<line>\d+):(?P<col>\d+): error: (?P<msg>.*?)\s*$",
    re.MULTILINE,
)
ERROR_LINE_NOLOC = re.compile(r"^(?P<msg>(?:\S+: )?error: .*?)\s*$", re.MULTILINE)


def load_token():
    token = os.environ.get("CODEMAGIC_API_TOKEN")
    if token:
        return token.strip()
    try:
        with open(TOKEN_FILE, encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError as exc:
        sys.exit(f"No Codemagic API token: set CODEMAGIC_API_TOKEN or create {TOKEN_FILE} ({exc})")


def request(path, base=API, body=None, method=None, raw=False, attempts=6):
    """One API call with retry/backoff. Returns parsed JSON, or text when raw."""
    url = base.rstrip("/") + "/" + path.lstrip("/")
    data = json.dumps(body).encode() if body is not None else None
    headers = {"x-auth-token": load_token()}
    if data is not None:
        headers["Content-Type"] = "application/json"
    for attempt in range(1, attempts + 1):
        req = urllib.request.Request(url, data=data, headers=headers,
                                     method=method or ("POST" if data is not None else "GET"))
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                payload = resp.read().decode("utf-8", "replace")
            return payload if raw else json.loads(payload)
        except urllib.error.HTTPError as exc:
            if exc.code == 429:
                wait = exc.headers.get("Retry-After")
                delay = min(120, int(wait) if wait and wait.isdigit() else 30)
                print(f"  rate-limited, backing off {delay}s", file=sys.stderr)
                time.sleep(delay)
                continue
            if 500 <= exc.code < 600 and attempt < attempts:
                time.sleep(5 * attempt)
                continue
            detail = exc.read().decode("utf-8", "replace")[:300]
            raise SystemExit(f"HTTP {exc.code} on {method or 'GET'} {url}\n{detail}")
        except (urllib.error.URLError, TimeoutError) as exc:
            if attempt < attempts:
                time.sleep(5 * attempt)
                continue
            raise SystemExit(f"network error on {url}: {exc}")
    raise SystemExit(f"gave up on {url} after {attempts} attempts")


def parse_ts(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def fmt_duration(started, finished):
    s, f = parse_ts(started), parse_ts(finished)
    if not s:
        return "not started"
    end = f or datetime.now(timezone.utc)
    secs = int((end - s).total_seconds())
    mark = "" if f else " (so far)"
    return f"{secs // 60}m{secs % 60:02d}s{mark}"


def get_build(build_id):
    doc = request(f"/builds/{build_id}")
    return (doc or {}).get("build") or {}


def actions_of(build):
    """Normalized [{id, name, type, status}] from the v1 build doc."""
    out = []
    for a in build.get("buildActions") or []:
        out.append({
            "id": a.get("_id"),
            "name": a.get("name") or "",
            "type": a.get("type") or "script",
            "status": a.get("status") or "",
        })
    return out


def step_log(build_id, action_id):
    text = request(f"/builds/{build_id}/step/{action_id}", raw=True)
    return html.unescape(text)


def relevant_actions(build):
    """Script steps plus anything failed: where compiler errors can appear."""
    acts = actions_of(build)
    picked = [a for a in acts if a["type"] == "script" or a["status"] == "failed"]
    return picked or acts


# ------------------------------------------------------------- commands ----


def cmd_apps(_args):
    for app in request("/apps").get("applications", []):
        print(app.get("_id"), "|", app.get("appName"), "|", app.get("projectType"))


def cmd_builds(args):
    doc = request(f"/builds?limit={args.limit}")
    for b in doc.get("builds", []):
        commit = (b.get("commit") or {})
        print(f"#{b.get('index')} {b.get('_id')} {b.get('status', '?'):>8} "
              f"{(commit.get('hash') or '--------')[:8]} "
              f"{b.get('fileWorkflowId') or b.get('workflowId') or '-'} "
              f"{fmt_duration(b.get('startedAt'), b.get('finishedAt'))} "
              f"{(commit.get('commitMessage') or '')[:60]}")


def cmd_status(args):
    b = get_build(args.build_id)
    commit = b.get("commit") or {}
    print("build:     ", b.get("_id"), f"(#{b.get('index')})")
    print("status:    ", b.get("status"))
    print("workflow:  ", b.get("fileWorkflowId") or b.get("workflowId"))
    print("branch:    ", b.get("branch"))
    print("commit:    ", (commit.get("hash") or "")[:8], "|", (commit.get("commitMessage") or "")[:70])
    print("duration:  ", fmt_duration(b.get("startedAt"), b.get("finishedAt")))
    arts = b.get("artefacts") or []
    print("artefacts: ", len(arts))
    for a in actions_of(b):
        print(f"  step {a['status'] or '?':>7} | {a['name']}")


def cmd_wait(args):
    last = None
    deadline = time.monotonic() + args.max_minutes * 60
    while True:
        b = get_build(args.build_id)
        status = b.get("status") or "?"
        if status != last:
            stamp = datetime.now(timezone.utc).strftime("%H:%M:%S")
            print(f"[{stamp} UTC] {status} "
                  f"({fmt_duration(b.get('startedAt'), b.get('finishedAt'))})")
            last = status
        if status in TERMINAL:
            commit = (b.get("commit") or {}).get("hash") or ""
            print(f"finished: {status} | commit {commit[:8]} | "
                  f"{fmt_duration(b.get('startedAt'), b.get('finishedAt'))}")
            if status in OK_STATES:
                return 0
            if status in CANCELLED_STATES:
                return 2
            return 1
        if time.monotonic() > deadline:
            print(f"still {status} after {args.max_minutes} minutes; giving up on polling "
                  f"(the build keeps running on Codemagic).")
            return 4
        time.sleep(args.interval)


def fetch_logs(build_id, build, all_steps):
    acts = actions_of(build) if all_steps else relevant_actions(build)
    logs = []
    for a in acts:
        if not a["id"]:
            continue
        try:
            logs.append((a, step_log(build_id, a["id"])))
        except SystemExit as exc:
            print(f"  (no log for step '{a['name']}': {exc})", file=sys.stderr)
    return logs


def cmd_logs(args):
    b = get_build(args.build_id)
    pairs = fetch_logs(args.build_id, b, args.all)
    if args.out:
        os.makedirs(args.out, exist_ok=True)
        for a, text in pairs:
            safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", a["name"]).strip("_")
            path = os.path.join(args.out, f"{a['status'] or 'step'}-{safe}.log")
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(text)
            print(f"{path}  ({len(text)} chars, {a['name']})")
    else:
        for a, text in pairs:
            print(f"\n===== {a['name']} [{a['status']}] =====\n")
            print(text)


def extract_errors(text):
    errors = []
    seen = set()
    for m in ERROR_LINE.finditer(text):
        key = (m.group("file"), m.group("line"), m.group("msg"))
        if key not in seen:
            seen.add(key)
            errors.append({"file": m.group("file"), "line": m.group("line"),
                           "col": m.group("col"), "msg": m.group("msg")})
    if not errors:
        for m in ERROR_LINE_NOLOC.finditer(text):
            msg = m.group("msg")
            if key_helper(msg) not in seen:
                seen.add(key_helper(msg))
                errors.append({"file": None, "line": None, "col": None, "msg": msg})
    return errors


def key_helper(msg):
    return (None, None, msg)


def cmd_errors(args):
    b = get_build(args.build_id)
    grouped = {}
    others = []
    for a, text in fetch_logs(args.build_id, b, all_steps=False):
        for e in extract_errors(text):
            if e["file"]:
                grouped.setdefault(e["file"], []).append(e)
            else:
                others.append((a["name"], e["msg"]))
    total = sum(len(v) for v in grouped.values()) + len(others)
    if total == 0:
        print("No 'error:' lines found in the build's step logs.")
        return
    print(f"{total} error(s) in {len(grouped) + (1 if others else 0)} place(s):\n")
    for f in sorted(grouped):
        rel = f.replace("/Users/builder/clone/", "")
        print(f"{rel}:")
        for e in grouped[f]:
            print(f"  :{e['line']}:{e['col']}  {e['msg']}")
        print()
    for step, msg in others:
        print(f"[{step}] {msg}")


def cmd_artifacts(args):
    b = get_build(args.build_id)
    v1_arts = b.get("artefacts") or []
    if v1_arts:
        print("v1 artefacts:")
        print(json.dumps(v1_arts, indent=1))
    try:
        doc = request(f"/builds/{args.build_id}", base=V3)
        arts = (doc.get("data") or {}).get("artifacts") or []
    except SystemExit as exc:
        print(f"v3 artifacts unavailable: {exc}")
        arts = []
    if not arts and not v1_arts:
        print("No artifacts (the build produced none, or it failed before packaging).")
        return
    for a in arts:
        size = a.get("size_in_bytes")
        size_h = f"{size / 1_048_576:.1f} MB" if isinstance(size, (int, float)) else "?"
        print(f"{a.get('name', '?')}  ({size_h}, {a.get('type', '?')})")
        print(f"  {a.get('short_lived_download_url') or '(no download URL in the entry)'}")


def cmd_report(args):
    b = get_build(args.build_id)
    status = b.get("status") or "?"
    commit = b.get("commit") or {}
    print("=== Codemagic build report ===")
    print("build id:  ", b.get("_id"), f"(#{b.get('index')})")
    print("status:    ", status)
    print("commit:    ", (commit.get("hash") or "")[:8],
          "|", (commit.get("commitMessage") or "")[:70])
    print("workflow:  ", b.get("fileWorkflowId") or b.get("workflowId"))
    print("duration:  ", fmt_duration(b.get("startedAt"), b.get("finishedAt")))
    print()
    if status in FAILED_STATES or status in CANCELLED_STATES:
        print("--- errors ---")
        cmd_errors(args)
        print()
        print("Next: fix the errors above, commit, then ask for authorization to "
              "push and rebuild.")
    elif status in OK_STATES:
        print("--- artifacts ---")
        cmd_artifacts(args)
    else:
        print("Build is not finished; run:")
        print(f"  python3 {sys.argv[0]} wait {args.build_id}")


def remote_head():
    try:
        out = subprocess.run(["git", "ls-remote", "origin", "refs/heads/main"],
                             cwd=REPO, capture_output=True, text=True, timeout=30)
        return out.stdout.split()[0] if out.stdout else "?"
    except Exception:
        return "?"


def cmd_trigger(args):
    if not args.authorized:
        print("Refusing to start a build: no authorization.")
        print("Builds are started ONLY on explicit authorization. Re-run with --authorized.")
        return 3
    resp = request("/builds", body={"appId": APP_ID, "workflowId": args.workflow,
                                    "branch": args.branch})
    build_id = resp.get("buildId") or resp.get("build", {}).get("_id")
    if not build_id:
        raise SystemExit(f"unexpected trigger response: {json.dumps(resp)[:300]}")
    sha = remote_head()
    record = {"time": datetime.now(timezone.utc).isoformat(timespec="seconds"),
              "event": "build-triggered", "buildId": build_id, "commit": sha,
              "branch": args.branch, "workflow": args.workflow}
    with open(BUILD_LEDGER, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(record) + "\n")
    print(f"build started: {build_id}")
    print(f"commit (origin/main at trigger): {sha[:8]}")
    print(f"dashboard: https://codemagic.io/app/{APP_ID}/build/{build_id}")
    print(f"recorded in {BUILD_LEDGER}")
    return build_id


def cmd_build(args):
    build_id = cmd_trigger(args)
    if not isinstance(build_id, str):
        return build_id  # trigger refused (or failed): pass the exit code through
    print("\n--- watching the build ---\n")
    wait_code = cmd_wait(argparse.Namespace(build_id=build_id, interval=args.interval,
                                            max_minutes=args.max_minutes))
    print()
    cmd_report(argparse.Namespace(build_id=build_id))
    return wait_code


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("apps").set_defaults(func=cmd_apps)

    p = sub.add_parser("builds")
    p.add_argument("--limit", type=int, default=10)
    p.set_defaults(func=cmd_builds)

    p = sub.add_parser("status")
    p.add_argument("build_id")
    p.set_defaults(func=cmd_status)

    p = sub.add_parser("wait")
    p.add_argument("build_id")
    p.add_argument("--interval", type=int, default=5, help="poll seconds (default 5)")
    p.add_argument("--max-minutes", type=int, default=90)
    p.set_defaults(func=cmd_wait)

    p = sub.add_parser("logs")
    p.add_argument("build_id")
    p.add_argument("--all", action="store_true", help="every step, not just script/failed")
    p.add_argument("-o", "--out", help="write each step log into this directory")
    p.set_defaults(func=cmd_logs)

    p = sub.add_parser("errors")
    p.add_argument("build_id")
    p.set_defaults(func=cmd_errors)

    p = sub.add_parser("artifacts")
    p.add_argument("build_id")
    p.set_defaults(func=cmd_artifacts)

    p = sub.add_parser("report")
    p.add_argument("build_id")
    p.set_defaults(func=cmd_report)

    p = sub.add_parser("trigger")
    p.add_argument("--authorized", action="store_true",
                   help="required: confirms the build was explicitly authorized")
    p.add_argument("--branch", default=BRANCH)
    p.add_argument("--workflow", default=WORKFLOW)
    p.set_defaults(func=cmd_trigger)

    p = sub.add_parser("build")
    p.add_argument("--authorized", action="store_true",
                   help="required: confirms the build was explicitly authorized")
    p.add_argument("--branch", default=BRANCH)
    p.add_argument("--workflow", default=WORKFLOW)
    p.add_argument("--interval", type=int, default=5)
    p.add_argument("--max-minutes", type=int, default=90)
    p.set_defaults(func=cmd_build)

    args = parser.parse_args()
    code = args.func(args)
    if isinstance(code, int):
        sys.exit(code)


if __name__ == "__main__":
    main()

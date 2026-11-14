#!/usr/bin/env python3
"""Renovate agent: an LLM reads each ready Renovate PR and says whether it could be merged
unattended; the verdict is posted as a PR comment and a label. PRs judged safe are then
merged one at a time, each watched in ArgoCD and reverted if its apps do not settle.

    nix develop --command python3 .github/renovate-agent/agent.py

The model reads untrusted text (upstream release notes), so it never gets the GitHub
token: this script fetches the PR data, posts the comments and does the merging itself,
and starts Claude with every credential but its own removed from the environment.

Environment:
    GITHUB_REPOSITORY          owner/repo (required)
    GH_TOKEN                   token for gh: read PRs, comment, label, merge, push a revert
    CLAUDE_CODE_OAUTH_TOKEN    Claude credential
    ONLY_PR                    handle just this PR number
    FORCE=true                 re-triage PRs that already have a verdict
    DRY_RUN=true               print the comments and the merge plan, change nothing
    RENOVATE_AGENT_MODEL       default: sonnet
    RENOVATE_AGENT_BUDGET_USD  per batch of 8 PRs, default: 5
    RUN_URL                    link to the workflow run, added to the comments
"""

import base64
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
REPO = os.environ.get("GITHUB_REPOSITORY", "")
WORK = Path("renovate-agent-work")

AUTO_MERGE_TYPES = ("patch", "minor", "digest")  # what the model may call safe
BATCH = 8  # PRs per Claude run; each run has its own budget
MAX_MERGES = 10  # per run
SETTLE_TIMEOUT = 20 * 60  # seconds for ArgoCD to sync a merge and the apps to get healthy
SOAK = 5 * 60  # seconds the apps must then stay Synced and Healthy without a break
POLL = 20
REQUIRED_CHECK = "Validate"
MARKER = "<!-- renovate-agent:verdict"
BOT = "github-actions"
ZERO_WIDTH_SPACE = chr(0x200B)

# The agent's whole reach: read the checkout and the PR files this script wrote, read
# GitHub pages (release notes), read cluster state. No Edit/Write, no arbitrary shell, no
# gh; in --print mode anything not listed is denied.
ALLOWED_TOOLS = [
    "Read",
    "Grep",
    "Glob",
    "Bash(kubectl get *)",
    "WebFetch(domain:github.com)",
    "WebFetch(domain:api.github.com)",
    "WebFetch(domain:raw.githubusercontent.com)",
]


def gh(*args: str) -> str:
    return subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout


def flag(name: str) -> bool:
    return os.environ.get(name, "").lower() == "true"


def summary(text: str) -> None:
    """Show text on the workflow run page (and in the log)."""
    print(text)
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a") as f:
            f.write(text + "\n")


# --- selecting PRs -----------------------------------------------------------------------


def denylist() -> re.Pattern:
    lines = (HERE / "denylist.txt").read_text().splitlines()
    patterns = [line.strip() for line in lines if line.strip() and not line.startswith("#")]
    return re.compile("|".join(patterns))


def title_key(title: str) -> str:
    """Identifies a verdict. The title carries the target version, so a rebase keeps the
    verdict and a newer version gets a fresh one."""
    return base64.b64encode(title.encode()).decode()


def is_renovate(pr: dict) -> bool:
    """A renovate/* branch of this repo, opened by the owner or the Renovate bot. The repo
    is public: a fork PR that merely names its branch renovate/* must not count."""
    owner = REPO.split("/")[0].lower()
    return (
        pr["headRefName"].startswith("renovate/")
        and not pr["isCrossRepository"]
        and not pr["isDraft"]
        and pr["author"]["login"].lower() in (owner, "renovate", "app/renovate")
    )


def is_green(pr: dict) -> bool:
    """CI passed, including Renovate's stability-days status (minimumReleaseAge). Not
    needed for a verdict, but nothing is merged without it."""
    checks = pr["statusCheckRollup"]

    def passed(check: dict) -> bool:
        if check["__typename"] == "StatusContext":
            return check["state"] == "SUCCESS"
        return check["status"] == "COMPLETED" and check["conclusion"] in ("SUCCESS", "SKIPPED", "NEUTRAL")

    ran_ci = any(c.get("name") == REQUIRED_CHECK and c.get("conclusion") == "SUCCESS" for c in checks)
    return ran_ci and all(passed(c) for c in checks)


def has_verdict(pr: dict) -> bool:
    marker = f"{MARKER} key={title_key(pr['title'])} -->"
    return any(c["author"]["login"] == BOT and marker in c["body"] for c in pr["comments"])


def list_prs() -> list[dict]:
    fields = (
        "number,title,headRefName,headRefOid,author,isCrossRepository,isDraft,createdAt,"
        "files,statusCheckRollup,comments,labels,mergeable"
    )
    prs = json.loads(gh("pr", "list", "--repo", REPO, "--state", "open", "--limit", "100", "--json", fields))
    only = os.environ.get("ONLY_PR", "")
    mine = [pr for pr in prs if is_renovate(pr) and (not only or str(pr["number"]) == only)]
    return sorted(mine, key=lambda pr: pr["number"])


def needs_triage(pr: dict) -> bool:
    """No agent:safe / agent:needs-human label yet, or the label is from an older version
    of the PR. Removing the label from a PR therefore gets it triaged again."""
    labels = {label["name"] for label in pr["labels"]}
    return not labels & {"agent:safe", "agent:needs-human"} or not has_verdict(pr)


def reverted_titles() -> set[str]:
    """Titles of updates this agent merged and had to revert. Renovate reopens the same
    update after a revert; without this it would be merged and reverted every night."""
    merged = gh("pr", "list", "--repo", REPO, "--state", "merged", "--label", "agent:reverted", "--json", "title")
    return {pr["title"] for pr in json.loads(merged)}


def never_auto_merge(pr: dict, deny: re.Pattern, reverted: set[str]) -> str:
    """Why this PR needs a human whatever the model says, or '' if it does not."""
    if any(deny.search(f["path"]) for f in pr["files"]):
        return "it touches a denylisted path (`.github/renovate-agent/denylist.txt`)"
    if pr["title"] in reverted:
        return "the agent merged this same update before and had to revert it"
    return ""


def select_prs() -> list[dict]:
    deny, reverted = denylist(), reverted_titles()
    selected = []
    for pr in list_prs():
        if not (needs_triage(pr) or flag("FORCE")):
            continue
        selected.append(
            {
                "number": pr["number"],
                "title": pr["title"],
                "opened": pr["createdAt"],
                "ci": "passing" if is_green(pr) else "not passing (yet)",
                "files": [f["path"] for f in pr["files"]],
                "never_auto_merge": never_auto_merge(pr, deny, reverted),
            }
        )
    return selected


def fetch_pr(pr: dict) -> None:
    """Write the PR description and diff to a file for the model to read."""
    number = str(pr["number"])
    body = json.loads(gh("pr", "view", number, "--repo", REPO, "--json", "body"))["body"]
    diff = gh("pr", "diff", number, "--repo", REPO)
    pr["file"] = str(WORK / f"pr-{number}.md")
    Path(pr["file"]).write_text(f"# {pr['title']}\n\n{body}\n\n# Diff\n\n```diff\n{diff}\n```\n")


# --- running the model -------------------------------------------------------------------


def model_env() -> dict:
    """The environment without credentials, except the one Claude itself needs. TF_VAR_*
    are the secrets the dev shell's hook loads from OpenBao when it can."""
    secret = re.compile(r"TOKEN|SECRET|PASSWORD|KEY|^TF_VAR_", re.IGNORECASE)
    return {k: v for k, v in os.environ.items() if k == "CLAUDE_CODE_OAUTH_TOKEN" or not secret.search(k)}


def one_line(text: str, limit: int = 300) -> str:
    text = " ".join(str(text).split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def log_event(event: dict) -> None:
    """Print what Claude is doing, as it happens: its notes, each tool call, failed calls."""
    blocks = event.get("message", {}).get("content", [])
    for block in blocks if isinstance(blocks, list) else []:
        kind = block.get("type")
        if kind == "text" and block["text"].strip():
            print(f"  claude: {one_line(block['text'])}", flush=True)
        elif kind == "thinking" and block["thinking"].strip():
            print(f"  claude (thinking): {one_line(block['thinking'], 200)}", flush=True)
        elif kind == "tool_use" and block["name"] == "StructuredOutput":
            print("  claude > writing the verdicts", flush=True)
        elif kind == "tool_use":
            args = ", ".join(f"{key}={one_line(value, 150)}" for key, value in block["input"].items())
            print(f"  claude > {block['name']}({args})", flush=True)
        elif kind == "tool_result" and block.get("is_error"):
            print(f"    failed: {one_line(block.get('content', ''), 200)}", flush=True)


def run_claude(prs: list[dict]) -> list[dict]:
    prompt = (
        (HERE / "triage.md").read_text()
        + "\n## Pull requests to triage\n\n```json\n"
        + json.dumps(prs, indent=2)
        + "\n```\n"
    )
    command = [
        "claude",
        "--print",
        "--model", os.environ.get("RENOVATE_AGENT_MODEL") or "sonnet",
        "--max-budget-usd", os.environ.get("RENOVATE_AGENT_BUDGET_USD") or "5",
        "--allowedTools", *ALLOWED_TOOLS,
        "--json-schema", (HERE / "verdict.schema.json").read_text(),
        # One JSON event per line while it works, so the job log shows progress; the last
        # event is the result.
        "--output-format", "stream-json",
        "--verbose",
        # Ignore the repo's own Claude settings and any MCP servers, so nothing in the
        # checkout can widen the allowlist.
        "--setting-sources", "user",
        "--strict-mcp-config",
        "--no-session-persistence",
    ]  # fmt: skip
    print(f"claude: triaging {', '.join('#' + str(pr['number']) for pr in prs)}", flush=True)
    # The prompt goes in on stdin: after the variadic --allowedTools it would otherwise be
    # read as one more tool name. stderr goes straight to the job log.
    claude = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=model_env())
    claude.stdin.write(prompt)
    claude.stdin.close()
    result = {}
    for line in claude.stdout:
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "result":
            result = event
        else:
            log_event(event)
    claude.wait()

    if result.get("is_error") or not isinstance((result.get("structured_output") or {}).get("verdicts"), list):
        sys.exit(f"claude returned no verdicts (exit {claude.returncode}): {result.get('subtype')} {result.get('result')}")
    denied = [d.get("tool_name") for d in result.get("permission_denials", [])]
    print(f"claude: {result.get('num_turns')} turns, ${result.get('total_cost_usd', 0):.2f}, denied tool calls: {denied}")
    return result["structured_output"]["verdicts"]


# --- publishing --------------------------------------------------------------------------


def clean(text: str, limit: int) -> str:
    """Model output goes into a public comment: cap it, defuse @mentions and HTML comments,
    and make sure it cannot carry one of our credentials out."""
    for name in ("CLAUDE_CODE_OAUTH_TOKEN", "GH_TOKEN"):
        if os.environ.get(name):
            text = text.replace(os.environ[name], "[redacted]")
    return text[:limit].replace("@", "@" + ZERO_WIDTH_SPACE).replace("<!--", "&lt;!--")


def comment_body(pr: dict, verdict: dict, safe: bool) -> str:
    headline = "✅ safe to auto-merge" if safe else "⚠️ needs a human"
    parts = [
        f"{MARKER} key={title_key(pr['title'])} -->",
        f"### Renovate agent: {headline} ({verdict['update_type']})",
        "**" + " ".join(clean(verdict["summary"], 200).split()) + "**",
        clean(verdict["details"], 2500),
    ]
    if pr["never_auto_merge"] and verdict["verdict"] == "safe":
        parts.append(f"> The agent judged this update safe, but {pr['never_auto_merge']}, so it needs a human.")
    run = os.environ.get("RUN_URL")
    parts.append(
        "---\n<sub>Written by an LLM reading the diff and release notes; check before relying on it."
        + (f" [Run]({run})." if run else "")
        + " PRs labelled `agent:safe` are merged by the agent, one at a time, and reverted if"
        " their ArgoCD apps do not settle; remove the label to stop that.</sub>"
    )
    return "\n\n".join(parts)


def post_verdict(number: int, body: str) -> None:
    """One verdict comment per PR: update ours if it exists, otherwise create it."""
    comments = json.loads(gh("api", f"repos/{REPO}/issues/{number}/comments?per_page=100"))
    ours = [c for c in comments if c["user"]["login"] == f"{BOT}[bot]" and c["body"].startswith(MARKER)]
    if ours:
        gh("api", "-X", "PATCH", f"repos/{REPO}/issues/comments/{ours[0]['id']}", "-f", f"body={body}")
    else:
        gh("api", "-X", "POST", f"repos/{REPO}/issues/{number}/comments", "-f", f"body={body}")


def set_label(number: int, safe: bool) -> None:
    add, remove = ("agent:safe", "agent:needs-human") if safe else ("agent:needs-human", "agent:safe")
    gh("api", "-X", "POST", f"repos/{REPO}/issues/{number}/labels", "-f", f"labels[]={add}")
    # Fails with 404 when the PR never had the other label; that is fine.
    subprocess.run(["gh", "api", "-X", "DELETE", f"repos/{REPO}/issues/{number}/labels/{remove}"], capture_output=True)


def publish(prs: list[dict], verdicts: list[dict]) -> None:
    """Does not trust the model: verdicts for PRs that were not selected are dropped, and
    a major update or a PR that must never be auto-merged needs a human whatever the
    verdict says."""
    by_number = {pr["number"]: pr for pr in prs}
    for verdict in verdicts:
        pr = by_number.get(verdict["number"])
        if pr is None:
            print(f"#{verdict['number']}: not a selected PR, ignored")
            continue
        # The prompt says majors always need a human; the model has ignored that before.
        if verdict["update_type"] not in AUTO_MERGE_TYPES and not pr["never_auto_merge"]:
            pr["never_auto_merge"] = f"it is a {verdict['update_type']} update and only patch, minor and digest updates are auto-merged"
        safe = verdict["verdict"] == "safe" and not pr["never_auto_merge"]
        body = comment_body(pr, verdict, safe)
        one_line = re.sub(r"[|\r\n]+", " ", clean(verdict["summary"], 200))
        summary(f"| #{pr['number']} | {'safe' if safe else 'needs-human'} | {verdict['update_type']} | {one_line} |")
        if flag("DRY_RUN"):
            print(f"===== #{pr['number']} =====\n{body}\n")
            continue
        post_verdict(pr["number"], body)
        set_label(pr["number"], safe)


# --- merging -----------------------------------------------------------------------------


def comment(number: int, body: str) -> None:
    gh("api", "-X", "POST", f"repos/{REPO}/issues/{number}/comments", "-f", f"body={body}")


def kubectl(*args: str) -> dict:
    done = subprocess.run(["kubectl", "get", *args, "-o", "json"], check=True, capture_output=True, text=True)
    return json.loads(done.stdout)


def argo_apps() -> dict[str, dict]:
    return {app["metadata"]["name"]: app for app in kubectl("applications.argoproj.io", "-n", "argocd")["items"]}


def sources(app: dict) -> list[dict]:
    return app["spec"].get("sources") or [app["spec"]["source"]]


def is_settled(app: dict) -> bool:
    status = app.get("status", {})
    return status.get("sync", {}).get("status") == "Synced" and status.get("health", {}).get("status") == "Healthy"


def state(app: dict) -> str:
    status = app.get("status", {})
    return f"{status.get('sync', {}).get('status')}/{status.get('health', {}).get('status')}"


def contains_commit(revision: str, sha: str, known: dict[str, bool]) -> bool:
    """Whether `revision` is `sha` or a later commit on top of it. Master can move during
    the watch (backup commits, other pushes) and the apps track HEAD."""
    if revision not in known:
        try:
            status = gh("api", f"repos/{REPO}/compare/{sha}...{revision}", "--jq", ".status").strip()
        except subprocess.CalledProcessError:
            return False  # not a commit of this repo (a chart version), or GitHub is unreachable: ask again
        known[revision] = status in ("identical", "ahead")
    return known[revision]


def apps_for(files: list[str], apps: dict[str, dict]) -> tuple[set[str], set[str]]:
    """The ArgoCD apps a change to these files rolls out.

    parents: apps that render a directory of this repo containing one of the files.
    children: Application manifests in the files themselves (most of k3s-apps/*.yaml);
    their parent applies the manifest, then they sync on their own.
    """
    repo = f"github.com/{REPO}".lower()
    parents, children = set(), set()
    for file in files:
        owners = [
            (source["path"], name)
            for name, app in apps.items()
            for source in sources(app)
            if source.get("path")
            and repo in source["repoURL"].lower()
            and file.startswith(source["path"].rstrip("/") + "/")
        ]
        if not owners:
            raise LookupError(f"no ArgoCD app deploys {file}")
        parents.add(max(owners, key=lambda owner: len(owner[0]))[1])
        if file.endswith((".yaml", ".yml")) and Path(file).exists():
            for doc in yaml.safe_load_all(Path(file).read_text()):
                if isinstance(doc, dict) and doc.get("kind") == "Application":
                    children.add(doc["metadata"]["name"])
    return parents, children


def preflight(watched: set[str], apps: dict[str, dict]) -> str:
    """Why it is not a good moment to merge, or '' if it is."""
    for node in kubectl("nodes")["items"]:
        ready = [c["status"] for c in node["status"]["conditions"] if c["type"] == "Ready"]
        if ready != ["True"]:
            return f"node {node['metadata']['name']} is not Ready"
    for ceph in kubectl("cephclusters.ceph.rook.io", "-A")["items"]:
        health = ceph.get("status", {}).get("ceph", {}).get("health")
        if health not in ("HEALTH_OK", "HEALTH_WARN"):
            return f"Ceph is {health}"
    for name in sorted(watched):
        if name not in apps:
            return f"ArgoCD app {name} does not exist"
        if not apps[name]["spec"].get("syncPolicy", {}).get("automated"):
            return f"ArgoCD app {name} is not auto-synced"
        if not is_settled(apps[name]):
            return f"ArgoCD app {name} is already {state(apps[name])}"
    return ""


def wait_settled(sha: str, parents: set[str], children: set[str]) -> str:
    """Wait until ArgoCD has rolled out commit `sha` and the apps have stayed Synced and
    Healthy for SOAK seconds. Returns '' on success, otherwise what is wrong."""
    deadline = time.monotonic() + SETTLE_TIMEOUT
    parents_synced_at = None  # ISO time: children must have been reconciled after this
    settled_since = None
    known_revisions = {sha: True}

    def at_commit(app: dict) -> bool:
        sync = app.get("status", {}).get("sync", {})
        revisions = [r for r in [sync.get("revision"), *sync.get("revisions", [])] if r]
        return any(contains_commit(r, sha, known_revisions) for r in revisions)

    def not_settled() -> list[str]:
        nonlocal parents_synced_at
        apps = argo_apps()
        waiting = [
            f"{n} ({state(apps[n]) if at_commit(apps[n]) else 'not at the merged commit yet'})"
            for n in sorted(parents)
            if not (at_commit(apps[n]) and is_settled(apps[n]))
        ]
        if not waiting and parents_synced_at is None:
            parents_synced_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        if parents_synced_at:
            waiting += [
                f"{n} ({state(apps[n])})"
                for n in sorted(children)
                if not (is_settled(apps[n]) and apps[n]["status"].get("reconciledAt", "") > parents_synced_at)
            ]
        return waiting

    while True:
        time.sleep(POLL)
        try:
            waiting = not_settled()
        except (subprocess.CalledProcessError, KeyError, json.JSONDecodeError) as error:
            # The update is already deployed: a failed look at the cluster must not skip
            # the revert. Count it as not settled and keep trying until the deadline.
            waiting = [f"could not read ArgoCD state ({type(error).__name__})"]
        if waiting:
            settled_since = None
            print(f"  waiting for {', '.join(waiting)}", flush=True)
            if time.monotonic() > deadline:
                return "not Synced and Healthy: " + ", ".join(waiting)
            continue
        # A soak that started before the deadline is allowed to finish after it.
        settled_since = settled_since or time.monotonic()
        if time.monotonic() - settled_since >= SOAK:
            return ""


def revert(sha: str) -> None:
    """Push a revert of `sha` straight to master."""
    tree = str(WORK / "revert")
    token = base64.b64encode(f"x-access-token:{os.environ['GH_TOKEN']}".encode()).decode()
    url = f"https://github.com/{REPO}.git"

    def git(*args: str, cwd: str = ".") -> None:
        subprocess.run(["git", *args], check=True, cwd=cwd)

    WORK.mkdir(exist_ok=True)
    git("fetch", "--depth", "20", url, "master")
    git("worktree", "add", "--detach", tree, "FETCH_HEAD")
    git("-c", "user.name=github-actions[bot]",
        "-c", "user.email=41898282+github-actions[bot]@users.noreply.github.com",
        "revert", "--no-edit", sha, cwd=tree)  # fmt: skip
    git("-c", f"http.extraheader=AUTHORIZATION: basic {token}", "push", url, "HEAD:master", cwd=tree)


def merge_commit(number: int) -> str:
    """The commit a just-merged PR landed as. Retried: without it the rollout cannot be
    watched or reverted."""
    for attempt in range(10):
        try:
            return json.loads(gh("pr", "view", str(number), "--repo", REPO, "--json", "mergeCommit"))["mergeCommit"]["oid"]
        except (subprocess.CalledProcessError, TypeError, KeyError):
            time.sleep(POLL)
    sys.exit(f"#{number} was merged but its merge commit could not be read: check it and revert by hand if needed")


def merge_one(pr: dict) -> bool:
    """Merge one PR and see it through. Returns False if no further PR should be merged."""
    number = pr["number"]
    files = [f["path"] for f in pr["files"]]
    try:
        parents, children = apps_for(files, argo_apps())
    except LookupError as error:
        summary(f"- #{number} not merged: {error}")
        return True
    watched = parents | children
    problem = preflight(watched, argo_apps())
    if problem:
        summary(f"- #{number} not merged: {problem}")
        return False
    if flag("DRY_RUN"):
        summary(f"- #{number} would be merged, watching ArgoCD apps {', '.join(sorted(watched))}")
        return True

    try:
        gh("pr", "merge", str(number), "--repo", REPO, "--squash", "--match-head-commit", pr["headRefOid"])
    except subprocess.CalledProcessError as error:
        summary(f"- #{number} not merged: {error.stderr.strip()}")
        return True
    # Merged: from here on every path either confirms the rollout or reverts it.
    sha = merge_commit(number)
    print(f"#{number} merged as {sha}, watching {', '.join(sorted(watched))}", flush=True)

    problem = wait_settled(sha, parents, children)
    if not problem:
        summary(f"- #{number} merged ({sha[:8]}): {', '.join(sorted(watched))} Synced and Healthy for {SOAK // 60} min")
        comment(number, f"Merged by the Renovate agent as {sha}. ArgoCD apps {', '.join(sorted(watched))} "
                        f"stayed Synced and Healthy for {SOAK // 60} minutes afterwards.")  # fmt: skip
        return True

    summary(f"- #{number} merged ({sha[:8]}) and **reverted**: {problem}")
    revert(sha)
    # The label is what stops this update from being merged again: set it before anything else.
    gh("api", "-X", "POST", f"repos/{REPO}/issues/{number}/labels", "-f", "labels[]=agent:reverted")
    comment(number, f"The Renovate agent merged this as {sha} and then **reverted it**: after "
                    f"{SETTLE_TIMEOUT // 60} minutes ArgoCD was still {problem}.\n\n"
                    "The same update will not be auto-merged again; it needs a human.")  # fmt: skip
    sys.exit(f"#{number} was reverted: {problem}")


def merge_candidates() -> list[dict]:
    """Open PRs with green CI that carry a safe verdict for their current title."""
    deny, reverted = denylist(), reverted_titles()
    return [
        pr
        for pr in list_prs()
        if is_green(pr)
        and has_verdict(pr)
        and "agent:safe" in [label["name"] for label in pr["labels"]]
        and not never_auto_merge(pr, deny, reverted)
        and pr["mergeable"] != "CONFLICTING"
    ]


def merge_safe_prs() -> None:
    """Merge the safe PRs one at a time. The list is read again before every merge: a
    merge takes up to half an hour, and removing agent:safe meanwhile must still work."""
    summary(f"### Safe PRs to merge: {len(merge_candidates())}")
    handled = set()
    while len(handled) < MAX_MERGES:
        candidates = [pr for pr in merge_candidates() if pr["number"] not in handled]
        if not candidates:
            break
        handled.add(candidates[0]["number"])
        if not merge_one(candidates[0]):
            break


def main() -> None:
    if not REPO:
        sys.exit("GITHUB_REPOSITORY is not set")
    prs = select_prs()
    summary(f"### PRs selected for triage: {len(prs)}")
    if prs:
        summary("| PR | Verdict | Type | Summary |\n|---|---|---|---|")
    WORK.mkdir(exist_ok=True)
    for start in range(0, len(prs), BATCH):
        batch = prs[start : start + BATCH]
        for pr in batch:
            fetch_pr(pr)
        publish(batch, run_claude(batch))
    merge_safe_prs()


if __name__ == "__main__":
    main()

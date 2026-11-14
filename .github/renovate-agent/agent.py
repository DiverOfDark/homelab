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
    RENOVATE_AGENT_BUDGET_USD  default: 5
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

MAX_PRS = 10
MAX_MERGES = 3  # per run
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
    """CI passed, including Renovate's stability-days status (minimumReleaseAge)."""
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
    ready = [pr for pr in prs if is_renovate(pr) and is_green(pr) and (not only or str(pr["number"]) == only)]
    return sorted(ready, key=lambda pr: pr["number"])


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
        if has_verdict(pr) and not flag("FORCE"):
            continue
        selected.append(
            {
                "number": pr["number"],
                "title": pr["title"],
                "opened": pr["createdAt"],
                "files": [f["path"] for f in pr["files"]],
                "never_auto_merge": never_auto_merge(pr, deny, reverted),
            }
        )
    return selected[:MAX_PRS]


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
        "--output-format", "json",
        # Ignore the repo's own Claude settings and any MCP servers, so nothing in the
        # checkout can widen the allowlist.
        "--setting-sources", "user",
        "--strict-mcp-config",
        "--no-session-persistence",
    ]  # fmt: skip
    # The prompt goes in on stdin: after the variadic --allowedTools it would otherwise be
    # read as one more tool name.
    done = subprocess.run(command, input=prompt, capture_output=True, text=True, env=model_env())
    try:
        result = json.loads(done.stdout)
        verdicts = result["structured_output"]["verdicts"]
    except (json.JSONDecodeError, KeyError, TypeError):
        sys.exit(f"claude returned no verdicts (exit {done.returncode}):\n{done.stdout[-2000:]}\n{done.stderr[-2000:]}")
    if result.get("is_error"):
        sys.exit(f"claude reported an error: {result.get('result')}")

    denied = [d.get("tool_name") for d in result.get("permission_denials", [])]
    print(f"claude: {result.get('num_turns')} turns, ${result.get('total_cost_usd', 0):.2f}, denied tool calls: {denied}")
    return verdicts


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
    a PR that must never be auto-merged needs a human whatever the verdict says."""
    by_number = {pr["number"]: pr for pr in prs}
    summary("| PR | Verdict | Type | Summary |\n|---|---|---|---|")
    for verdict in verdicts:
        pr = by_number.get(verdict["number"])
        if pr is None:
            print(f"#{verdict['number']}: not a selected PR, ignored")
            continue
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
    while True:
        time.sleep(POLL)
        apps = argo_apps()

        def at_commit(app: dict) -> bool:
            sync = app.get("status", {}).get("sync", {})
            return sha in [sync.get("revision"), *sync.get("revisions", [])]

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
    sha = json.loads(gh("pr", "view", str(number), "--repo", REPO, "--json", "mergeCommit"))["mergeCommit"]["oid"]
    print(f"#{number} merged as {sha}, watching {', '.join(sorted(watched))}", flush=True)

    problem = wait_settled(sha, parents, children)
    if not problem:
        summary(f"- #{number} merged ({sha[:8]}): {', '.join(sorted(watched))} Synced and Healthy for {SOAK // 60} min")
        comment(number, f"Merged by the Renovate agent as {sha}. ArgoCD apps {', '.join(sorted(watched))} "
                        f"stayed Synced and Healthy for {SOAK // 60} minutes afterwards.")  # fmt: skip
        return True

    summary(f"- #{number} merged ({sha[:8]}) and **reverted**: {problem}")
    revert(sha)
    gh("api", "-X", "POST", f"repos/{REPO}/issues/{number}/labels", "-f", "labels[]=agent:reverted")
    comment(number, f"The Renovate agent merged this as {sha} and then **reverted it**: after "
                    f"{SETTLE_TIMEOUT // 60} minutes ArgoCD was still {problem}.\n\n"
                    "The same update will not be auto-merged again; it needs a human.")  # fmt: skip
    sys.exit(f"#{number} was reverted: {problem}")


def merge_safe_prs() -> None:
    """Merge the PRs that carry a safe verdict for their current title, one at a time."""
    deny, reverted = denylist(), reverted_titles()
    candidates = [
        pr
        for pr in list_prs()
        if has_verdict(pr)
        and "agent:safe" in [label["name"] for label in pr["labels"]]
        and not never_auto_merge(pr, deny, reverted)
        and pr["mergeable"] != "CONFLICTING"
    ]
    summary(f"### Safe PRs to merge: {len(candidates)}")
    for pr in candidates[:MAX_MERGES]:
        if not merge_one(pr):
            break


def main() -> None:
    if not REPO:
        sys.exit("GITHUB_REPOSITORY is not set")
    prs = select_prs()
    summary(f"### PRs selected for triage: {len(prs)}")
    if prs:
        WORK.mkdir(exist_ok=True)
        for pr in prs:
            fetch_pr(pr)
        publish(prs, run_claude(prs))
    merge_safe_prs()


if __name__ == "__main__":
    main()

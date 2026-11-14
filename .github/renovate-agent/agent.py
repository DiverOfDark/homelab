#!/usr/bin/env python3
"""Renovate triage agent: an LLM reads each ready Renovate PR and says whether it could be
merged unattended. Nothing is merged here.

    agent.py triage  <dir>   pick the PRs, run Claude over them, write <dir>/prs.json and
                             <dir>/verdicts.json. Needs only read access.
    agent.py publish <dir>   comment and label the PRs from those two files. Needs
                             pull-requests/issues write, and is the only part that does.

Run inside `nix develop .#renovate-agent` (python3, gh, kubectl, claude).

Environment:
    GITHUB_REPOSITORY          owner/repo (required)
    GH_TOKEN                   token for gh
    CLAUDE_CODE_OAUTH_TOKEN    Claude credential (triage only)
    ONLY_PR                    triage just this PR number
    FORCE=true                 re-triage PRs that already have a verdict
    DRY_RUN=true               publish: print the comments instead of posting them
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
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = os.environ.get("GITHUB_REPOSITORY", "")

MAX_PRS = 10
REQUIRED_CHECK = "Validate"
MARKER = "<!-- renovate-agent:verdict"
BOT = "github-actions"

# The agent's whole reach: read the checkout, read PRs and GitHub releases, read cluster
# state. No Edit/Write, no WebFetch, no arbitrary shell; in --print mode anything not
# listed is denied.
ALLOWED_TOOLS = [
    "Read",
    "Grep",
    "Glob",
    "Bash(gh pr view *)",
    "Bash(gh pr diff *)",
    "Bash(gh api *)",
    "Bash(kubectl get *)",
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


def select_prs() -> list[dict]:
    fields = "number,title,headRefName,author,isCrossRepository,isDraft,createdAt,files,statusCheckRollup,comments"
    prs = json.loads(gh("pr", "list", "--repo", REPO, "--state", "open", "--limit", "100", "--json", fields))
    only = os.environ.get("ONLY_PR", "")
    deny = denylist()

    selected = []
    for pr in sorted(prs, key=lambda pr: pr["number"]):
        if only and str(pr["number"]) != only:
            continue
        if not (is_renovate(pr) and is_green(pr)):
            continue
        if has_verdict(pr) and not flag("FORCE"):
            continue
        files = [f["path"] for f in pr["files"]]
        selected.append(
            {
                "number": pr["number"],
                "title": pr["title"],
                "branch": pr["headRefName"],
                "opened": pr["createdAt"],
                "files": files,
                "denylisted": any(deny.search(path) for path in files),
            }
        )
    return selected[:MAX_PRS]


# --- running the model -------------------------------------------------------------------


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
    done = subprocess.run(command, input=prompt, capture_output=True, text=True)
    try:
        result = json.loads(done.stdout)
        verdicts = result["structured_output"]["verdicts"]
    except (json.JSONDecodeError, KeyError, TypeError):
        sys.exit(f"claude returned no verdicts (exit {done.returncode}):\n{done.stdout[-2000:]}\n{done.stderr[-2000:]}")
    if result.get("is_error"):
        sys.exit(f"claude reported an error: {result.get('result')}")

    print(
        f"claude: {result.get('num_turns')} turns, ${result.get('total_cost_usd', 0):.2f}, "
        f"{len(result.get('permission_denials', []))} denied tool calls"
    )
    return verdicts


def triage(out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    prs = select_prs()
    (out / "prs.json").write_text(json.dumps(prs, indent=2))
    (out / "verdicts.json").write_text("[]")

    summary(f"### PRs selected for triage: {len(prs)}")
    if not prs:
        return

    verdicts = run_claude(prs)
    (out / "verdicts.json").write_text(json.dumps(verdicts, indent=2))

    summary("| PR | Verdict | Type | Summary |\n|---|---|---|---|")
    for v in verdicts:
        one_line = re.sub(r"[|\r\n]+", " ", v["summary"])
        summary(f"| #{v['number']} | {v['verdict']} | {v['update_type']} | {one_line} |")


# --- publishing --------------------------------------------------------------------------


def clean(text: str, limit: int) -> str:
    """Model output goes into a public comment: cap it, defuse @mentions and HTML comments."""
    return text[:limit].replace("@", "@​").replace("<!--", "&lt;!--")


def comment_body(pr: dict, verdict: dict, safe: bool) -> str:
    headline = "✅ safe to auto-merge" if safe else "⚠️ needs a human"
    parts = [
        f"{MARKER} key={title_key(pr['title'])} -->",
        f"### Renovate agent: {headline} ({verdict['update_type']})",
        "**" + " ".join(clean(verdict["summary"], 200).split()) + "**",
        clean(verdict["details"], 2500),
    ]
    if pr["denylisted"] and verdict["verdict"] == "safe":
        parts.append(
            "> The agent judged this update safe, but it touches a denylisted path "
            "(`.github/renovate-agent/denylist.txt`), so it always needs a human."
        )
    run = os.environ.get("RUN_URL")
    parts.append(
        "---\n<sub>Triage only: nothing was merged."
        + (f" [Run]({run})." if run else "")
        + " Written by an LLM reading the diff and release notes; check before relying on it.</sub>"
    )
    return "\n\n".join(parts)


def post_comment(number: int, body: str) -> None:
    """One comment per PR: update ours if it exists, otherwise create it."""
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


def publish(out: Path) -> None:
    """Does not trust the model: verdicts for PRs that were not selected are dropped, and
    a denylisted PR needs a human whatever the verdict says."""
    prs = {pr["number"]: pr for pr in json.loads((out / "prs.json").read_text())}
    for verdict in json.loads((out / "verdicts.json").read_text()):
        pr = prs.get(verdict["number"])
        if pr is None:
            print(f"#{verdict['number']}: not a selected PR, ignored")
            continue
        safe = verdict["verdict"] == "safe" and not pr["denylisted"]
        body = comment_body(pr, verdict, safe)
        if flag("DRY_RUN"):
            print(f"===== #{pr['number']} =====\n{body}\n")
            continue
        post_comment(pr["number"], body)
        set_label(pr["number"], safe)
        print(f"#{pr['number']}: {'safe' if safe else 'needs-human'}")


if __name__ == "__main__":
    commands = {"triage": triage, "publish": publish}
    if len(sys.argv) != 3 or sys.argv[1] not in commands:
        sys.exit(__doc__)
    if not REPO:
        sys.exit("GITHUB_REPOSITORY is not set")
    commands[sys.argv[1]](Path(sys.argv[2]))

#!/usr/bin/env bash
# Prints (as a JSON array) the open Renovate PRs the agent should triage now:
#   - opened from a renovate/* branch of this repo by the repo owner or renovate[bot]
#     (the repo is public: never pick up a fork PR that merely names its branch renovate/*)
#   - CI green, including Renovate's own stability-days status (minimumReleaseAge)
#   - not triaged yet for the current title; the title carries the target version, so a
#     rebase does not re-triage but a newer version does
# Env: GITHUB_REPOSITORY (required), ONLY_PR, FORCE=true, MAX_PRS, REQUIRED_CHECK.
set -euo pipefail

repo=${GITHUB_REPOSITORY:?}
dir=$(cd "$(dirname "$0")" && pwd)
deny=$(grep -vE '^[[:space:]]*(#|$)' "$dir/denylist.txt" | paste -sd'|')

gh pr list --repo "$repo" --state open --limit 100 \
  --json number,title,headRefName,author,isCrossRepository,isDraft,createdAt,files,statusCheckRollup,comments |
  jq --arg owner "${repo%%/*}" \
    --arg deny "$deny" \
    --arg only "${ONLY_PR:-}" \
    --arg force "${FORCE:-false}" \
    --arg required "${REQUIRED_CHECK:-Validate}" \
    --argjson max "${MAX_PRS:-10}" '
    def green:
      if .__typename == "StatusContext" then .state == "SUCCESS"
      else .status == "COMPLETED" and (.conclusion | IN("SUCCESS", "SKIPPED", "NEUTRAL")) end;
    def key: .title | @base64;
    def triaged:
      (key) as $k
      | any(.comments[];
          (.author.login | IN("github-actions", "github-actions[bot]"))
          and (.body | contains("<!-- renovate-agent:verdict key=" + $k + " -->")));

    map(select(
      (.headRefName | startswith("renovate/"))
      and (.isCrossRepository | not)
      and (.isDraft | not)
      and (.author.login | ascii_downcase | IN(($owner | ascii_downcase), "renovate", "renovate[bot]", "app/renovate"))
      and ($only == "" or (.number | tostring) == $only)
      and (.statusCheckRollup | length > 0 and all(.[]; green)
           and any(.[]; .name == $required and .conclusion == "SUCCESS"))
      and ($force == "true" or (triaged | not))
    ))
    | sort_by(.number)
    | .[:$max]
    | map({
        number,
        title,
        branch: .headRefName,
        opened: .createdAt,
        key: key,
        files: [.files[].path],
        denylisted: ([.files[].path | select(test($deny))] | length > 0)
      })'

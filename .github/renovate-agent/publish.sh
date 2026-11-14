#!/usr/bin/env bash
# Posts the agent's verdicts: one comment per PR (updated in place on later runs) and an
# agent:safe / agent:needs-human label. This is the only place with write access, and it
# does not trust the model: verdicts for PRs that were not selected are dropped, denylisted
# PRs are forced to needs-human, mentions are defused and the text is length-capped.
# Usage: publish.sh <prs.json> <verdicts.json>
# Env: GITHUB_REPOSITORY, GH_TOKEN (pull-requests + issues write), DRY_RUN=true, RUN_URL.
set -euo pipefail

prs=${1:?usage: publish.sh <prs.json> <verdicts.json>}
verdicts=${2:?usage: publish.sh <prs.json> <verdicts.json>}
repo=${GITHUB_REPOSITORY:?}
marker_prefix='<!-- renovate-agent:verdict'

jq -c --slurpfile v "$verdicts" '
  ($v[0] | map({key: (.number | tostring), value: .}) | from_entries) as $by
  | .[] | select($by[.number | tostring]) | . + {v: $by[.number | tostring]}
  | .forced = (.denylisted and .v.verdict == "safe")
  | .verdict = (if .denylisted then "needs-human" else .v.verdict end)' "$prs" |
  while read -r row; do
    number=$(jq -r .number <<<"$row")
    verdict=$(jq -r .verdict <<<"$row")
    body=$(jq -r --arg prefix "$marker_prefix" --arg run "${RUN_URL:-}" '
      def clean(n): .[:n] | gsub("@"; "@​") | gsub("<!--"; "&lt;!--");
      "\($prefix) key=\(.key) -->\n"
      + "### Renovate agent: "
      + (if .verdict == "safe" then "✅ safe to auto-merge" else "⚠️ needs a human" end)
      + " (\(.v.update_type))\n\n"
      + "**" + (.v.summary | clean(200) | gsub("[\r\n]+"; " ")) + "**\n\n"
      + (.v.details | clean(2500)) + "\n\n"
      + (if .forced then "> The agent judged this update safe, but it touches a denylisted path (`.github/renovate-agent/denylist.txt`), so it always needs a human.\n\n" else "" end)
      + "---\n<sub>Triage only: nothing was merged."
      + (if $run != "" then " [Run](\($run))." else "" end)
      + " Written by an LLM reading the diff and release notes; check before relying on it.</sub>"' <<<"$row")

    if [ "${DRY_RUN:-false}" = "true" ]; then
      printf '===== #%s -> %s =====\n%s\n\n' "$number" "$verdict" "$body"
      continue
    fi

    existing=$(gh api --paginate "repos/$repo/issues/$number/comments" |
      jq -s --arg prefix "$marker_prefix" \
        '[.[][] | select(.user.login == "github-actions[bot]" and (.body | startswith($prefix)))][0].id // empty')
    if [ -n "$existing" ]; then
      gh api -X PATCH "repos/$repo/issues/comments/$existing" -f body="$body" >/dev/null
    else
      gh api -X POST "repos/$repo/issues/$number/comments" -f body="$body" >/dev/null
    fi

    other=$([ "$verdict" = "safe" ] && echo "agent:needs-human" || echo "agent:safe")
    gh api -X POST "repos/$repo/issues/$number/labels" -f "labels[]=agent:$verdict" >/dev/null
    gh api -X DELETE "repos/$repo/issues/$number/labels/$other" >/dev/null 2>&1 || true
    echo "#$number -> $verdict"
  done

#!/usr/bin/env bash
# Runs the triage agent over prs.json (from select.sh) and writes its verdicts.
# Usage: triage.sh <prs.json> <verdicts.json>
# Env: CLAUDE_CODE_OAUTH_TOKEN (or a logged-in claude), GH_TOKEN (read-only), GH_REPO.
set -euo pipefail

prs=${1:?usage: triage.sh <prs.json> <verdicts.json>}
out=${2:?usage: triage.sh <prs.json> <verdicts.json>}
dir=$(cd "$(dirname "$0")" && pwd)
result=$(mktemp)

prompt="$(cat "$dir/triage.md")

## Pull requests to triage

\`\`\`json
$(jq 'map(del(.key))' "$prs")
\`\`\`"

# The tool allowlist is the agent's whole reach: read the checkout, read PRs and GitHub
# releases, read cluster state. No Edit/Write, no WebFetch, no arbitrary shell. Anything
# not listed is denied in --print mode. Project/local settings and MCP servers are ignored
# so nothing in the repo can widen it.
claude -p "$prompt" \
  --model "${RENOVATE_AGENT_MODEL:-sonnet}" \
  --max-budget-usd "${RENOVATE_AGENT_BUDGET_USD:-5}" \
  --allowedTools "Read" "Grep" "Glob" \
    "Bash(gh pr view *)" "Bash(gh pr diff *)" "Bash(gh api *)" "Bash(kubectl get *)" \
  --json-schema "$(cat "$dir/verdict.schema.json")" \
  --output-format json \
  --setting-sources user \
  --strict-mcp-config \
  --no-session-persistence </dev/null >"$result" || {
  echo "claude exited non-zero" >&2
  jq '{is_error, subtype, result}' "$result" >&2 || cat "$result" >&2
  exit 1
}

jq '{is_error, num_turns, total_cost_usd, denied: (.permission_denials | length)}' "$result" >&2
jq -e '.is_error == false and (.structured_output.verdicts | type == "array")' "$result" >/dev/null || {
  echo "agent returned no usable verdicts" >&2
  jq '{subtype, result}' "$result" >&2
  exit 1
}
jq '.structured_output.verdicts' "$result" >"$out"

#!/usr/bin/env bash
# One gate-2 audit of an arm's plan, headless, as its own measured session.
#
# usage: run-audit.sh <label> <worktree> <plugin-dir> <plan>
#   label  e.g. A-r1a; names the log
#   plan   path relative to the worktree
# Runs the /audit-plan command's instructions with all eight plan lenses and no
# questions. Prints the session id for the manifest. Does not commit.
set -u
[ "$#" -eq 4 ] || { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
label=$1 wt=$2 plugin=$3 plan=$4
here="$(cd "$(dirname "$0")" && pwd)"
[ -f "$wt/$plan" ] || { echo "run-audit: no plan at $wt/$plan" >&2; exit 2; }
mkdir -p "$here/runs"
log="$here/runs/audit-$label-$(date -u +%Y%m%dT%H%M%SZ).json"
cd "$wt" || exit 2
claude -p --plugin-dir "$plugin" --model opus --permission-mode auto --permission-prompts none \
  --output-format json \
  "Invoke the auditing-artifacts skill at gate 2 on the plan $plan. Its parent spec is named in the plan's spec: field. The spec is approved and frozen; no lens may reopen a spec design decision. Use the full plan lens set, all eight lenses, dispatched in one message, then reconcile. Do not fix the findings and do not commit. Record the audit in the plan and report the verdict with the blocking findings." > "$log"
rc=$?
node -e '
  const o = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  console.log(`session ${o.session_id}  result ${o.subtype}  cli cost $${(o.total_cost_usd || 0).toFixed(2)}`);
  console.log(String(o.result).slice(0, 3000));
' "$log" || echo "run-audit: no JSON result in $log (rc=$rc)" >&2
exit "$rc"

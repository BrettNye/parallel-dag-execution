#!/usr/bin/env bash
# One fix session on the D2 plan, headless, as its own measured session.
#
# usage: run-fix.sh <label> <worktree> <plan> <prompt-file>
#   prompt-file  fix-prompt.md after a gate-2 round, preflight-fix-prompt.md
#                after a preflight halt; {plan} and {planname} are filled in
# Prints the session id for the manifest. Does not commit.
set -u
[ "$#" -eq 4 ] || { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
label=$1 wt=$2 plan=$3 pfile=$4
here="$(cd "$(dirname "$0")" && pwd)"; runs="${D2_RUNS:-$here/runs}"
[ -f "$wt/$plan" ] || { echo "run-fix: no plan at $wt/$plan" >&2; exit 2; }
[ -f "$pfile" ] || { echo "run-fix: no prompt file $pfile" >&2; exit 2; }
planname=$(basename "$plan")
prompt="$(sed -e "s|{plan}|$plan|g" -e "s|{planname}|$planname|g" "$pfile")"
mkdir -p "$runs"
log="$runs/fix-$label-$(date -u +%Y%m%dT%H%M%SZ).json"
cd "$wt" || exit 2
export CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0
claude -p --model opus --permission-mode auto --permission-prompts none --output-format json "$prompt" > "$log"
rc=$?
node -e '
  const o = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  console.log(`session ${o.session_id}  result ${o.subtype}  cli cost $${(o.total_cost_usd || 0).toFixed(2)}`);
  console.log(String(o.result));
' "$log" || echo "run-fix: no JSON result in $log (rc=$rc)" >&2
exit "$rc"

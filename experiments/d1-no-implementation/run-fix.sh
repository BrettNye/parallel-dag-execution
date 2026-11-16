#!/usr/bin/env bash
# Apply one gate-2 round's findings to an arm's plan, headless, as its own measured session.
#
# usage: run-fix.sh <label> <worktree> <plan> <full|contracts-only>
# contracts-only adds the rule that a fix may add what, never how.
set -u
[ "$#" -eq 4 ] || { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
label=$1 wt=$2 plan=$3 mode=$4
here="$(cd "$(dirname "$0")" && pwd)"
planname=$(basename "$plan")
if [ "$mode" = contracts-only ]; then
  rule='This plan is contracts-only (`implementation: contracts-only`). A fix may add or tighten acceptance criteria, `## Contracts` entries (signatures, usage, exit codes, output and file formats), `files:`, `depends_on:`, and prose that states WHAT must hold. A fix may not add HOW: no function bodies, no test code, no prescribed algorithm or idiom, and no `## Implementation` section. If a finding can only be closed by prescribing how, close it with an acceptance criterion instead, and list it in your report under the heading "needs-implementation".'
else
  rule=''
fi
prompt="$(sed -e "s|{plan}|$plan|g" -e "s|{planname}|$planname|g" "$here/fix-prompt.md" | awk -v r="$rule" '{ if ($0 == "{arm_rule}") print r; else print }')"
mkdir -p "$here/runs"
log="$here/runs/fix-$label-$(date -u +%Y%m%dT%H%M%SZ).json"
cd "$wt" || exit 2
claude -p --model opus --permission-mode auto --permission-prompts none --output-format json "$prompt" > "$log"
rc=$?
node -e '
  const o = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  console.log(`session ${o.session_id}  result ${o.subtype}  cli cost $${(o.total_cost_usd || 0).toFixed(2)}`);
  console.log(String(o.result));
' "$log" || echo "run-fix: no JSON result in $log (rc=$rc)" >&2
exit "$rc"

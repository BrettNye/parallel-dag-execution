#!/usr/bin/env bash
# One gate-2 audit round of the D2 plan, headless, as its own measured session.
#
# usage: run-audit.sh <label> <worktree> <plugin-dir> <plan> <round>
#   label  e.g. gate2-r1; names the log
#   plan   path relative to the worktree
#   round  1 runs the full plan lens set; 2 and later run the skill's
#          diff-scoped re-audit (the design: later rounds follow the skill)
# Prints the session id for the manifest. Does not fix or commit.
set -u
[ "$#" -eq 5 ] || { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
label=$1 wt=$2 plugin=$3 plan=$4 round=$5
case "$round" in ''|*[!0-9]*|0*) echo "run-audit: round must be a positive integer, got '$round'" >&2; exit 2 ;; esac
here="$(cd "$(dirname "$0")" && pwd)"; runs="${D2_RUNS:-$here/runs}"
[ -f "$wt/$plan" ] || { echo "run-audit: no plan at $wt/$plan" >&2; exit 2; }
if [ "$round" -eq 1 ]; then
  lenses='Use the full plan lens set, all eight lenses, dispatched in one message, then reconcile.'
else
  lenses="This is round $round. Run the diff-scoped re-audit the skill describes: only the lenses the change since the last audit touches, recording the others as carried."
fi
# Each round overwrites the plan's .audit/ directory, so it is copied to
# runs/audit-<label>/ afterwards; an existing copy is never overwritten.
keep="$runs/audit-$label"
[ ! -e "$keep" ] || { echo "run-audit: $keep already exists; use a new label" >&2; exit 2; }
mkdir -p "$runs"
log="$runs/audit-$label-$(date -u +%Y%m%dT%H%M%SZ).json"
cd "$wt" || exit 2
export CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0
claude -p --plugin-dir "$plugin" --model opus --permission-mode auto --permission-prompts none \
  --output-format json \
  "Invoke the auditing-artifacts skill at gate 2 on the plan $plan. Its parent spec is named in the plan's spec: field. The spec is approved and frozen; no lens may reopen a spec design decision. $lenses Do not fix the findings and do not commit. Record the audit in the plan and report the verdict with the blocking findings." > "$log"
rc=$?
node -e '
  const o = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  console.log(`session ${o.session_id}  result ${o.subtype}  cli cost $${(o.total_cost_usd || 0).toFixed(2)}`);
  console.log(String(o.result).slice(0, 3000));
' "$log" || echo "run-audit: no JSON result in $log (rc=$rc)" >&2
adir="$(dirname "$plan")/.audit/$(basename "$plan")"
if [ -d "$adir" ]; then cp -r "$adir" "$keep" && echo "kept $adir as $keep"
else echo "run-audit: no $adir after the audit; nothing kept" >&2; fi
exit "$rc"

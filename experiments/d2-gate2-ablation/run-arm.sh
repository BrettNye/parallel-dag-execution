#!/usr/bin/env bash
# Run one experiment arm's plan headless, the way an overnight or hand-off run would.
#
# usage: run-arm.sh <label> <worktree> <plugin-dir> <plan> <budget-usd>
#   label       e.g. A or B; names the log
#   worktree    the arm's git worktree; the run starts there
#   plugin-dir  the pinned plugin copy (pin-plugin.sh), the same for both arms
#   plan        plan path relative to the worktree
#   budget-usd  the run's cost cap; hitting it means the run did not finish
#
# Each call is one invocation. Calling it again for the same arm is a
# re-invocation: measure.cjs counts each execution session after the first as
# an intervention. The executor resumes from the statuses in the plan file.
#
# Prints the session id to put in the manifest's "execution" list, and keeps
# the CLI's JSON result (with its own cost figure) under runs/.
set -u
[ "$#" -eq 5 ] || { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
label=$1 wt=$2 plugin=$3 plan=$4 budget=$5
here="$(cd "$(dirname "$0")" && pwd)"; runs="${D2_RUNS:-$here/runs}"
[ -f "$plugin/.claude-plugin/plugin.json" ] || { echo "run-arm: $plugin is not a plugin directory" >&2; exit 2; }
[ -f "$wt/$plan" ] || { echo "run-arm: no plan at $wt/$plan" >&2; exit 2; }
mkdir -p "$runs"
# The budget caps the whole run: each re-invocation gets what earlier invocations
# of this label (logs <label>-<utc>.json) have left.
left=$(node -e '
  const fs = require("fs"), [dir, label, budget] = process.argv.slice(1);
  const re = new RegExp("^" + label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "-\\d{8}T\\d{6}Z\\.json$");
  let spent = 0;
  for (const f of fs.readdirSync(dir)) if (re.test(f)) {
    try { spent += JSON.parse(fs.readFileSync(dir + "/" + f, "utf8")).total_cost_usd || 0; } catch {}
  }
  console.log((Number(budget) - spent).toFixed(2));
' "$runs" "$label" "$budget") || exit 2
case "$left" in -*|0.00) echo "run-arm: $label has spent its \$$budget budget; the run did not finish" >&2; exit 3 ;; esac
log="$runs/$label-$(date -u +%Y%m%dT%H%M%SZ).json"

cd "$wt" || exit 2
export CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0   # D2: every run, so no run stops at the 10-minute wait
# auto: the permission classifier decides; --permission-prompts none: nothing
# can wait for a person, so anything that would have prompted is denied instead.
claude -p \
  --plugin-dir "$plugin" \
  --model opus \
  --permission-mode auto \
  --permission-prompts none \
  --max-budget-usd "$left" \
  --output-format json \
  "Invoke the executing-dag-plans skill on the plan file: $plan" > "$log"
rc=$?
node -e '
  const o = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  console.log(`session ${o.session_id}  result ${o.subtype}  cli cost $${(o.total_cost_usd || 0).toFixed(2)}  turns ${o.num_turns}`);
' "$log" || echo "run-arm: no JSON result in $log (rc=$rc)" >&2
exit "$rc"

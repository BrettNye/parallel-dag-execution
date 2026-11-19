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
here="$(cd "$(dirname "$0")" && pwd)"
[ -f "$plugin/.claude-plugin/plugin.json" ] || { echo "run-arm: $plugin is not a plugin directory" >&2; exit 2; }
[ -f "$wt/$plan" ] || { echo "run-arm: no plan at $wt/$plan" >&2; exit 2; }
mkdir -p "$here/runs"
log="$here/runs/$label-$(date -u +%Y%m%dT%H%M%SZ).json"

cd "$wt" || exit 2
# auto: the permission classifier decides; --permission-prompts none: nothing
# can wait for a person, so anything that would have prompted is denied instead.
claude -p \
  --plugin-dir "$plugin" \
  --model opus \
  --permission-mode auto \
  --permission-prompts none \
  --max-budget-usd "$budget" \
  --output-format json \
  "Invoke the executing-dag-plans skill on the plan file: $plan" > "$log"
rc=$?
node -e '
  const o = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  console.log(`session ${o.session_id}  result ${o.subtype}  cli cost $${(o.total_cost_usd || 0).toFixed(2)}  turns ${o.num_turns}`);
' "$log" || echo "run-arm: no JSON result in $log (rc=$rc)" >&2
exit "$rc"

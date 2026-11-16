#!/usr/bin/env bash
# Derive Plan B from Plan A's round-1 draft, headless, so the conversion is its
# own measured session.
#
# usage: convert-plan-b.sh <arm-a-worktree> <arm-b-worktree> <plan path relative to the worktree>
# Copies the plan from arm A's HEAD into arm B, then runs the conversion prompt in
# arm B. Prints the session id for the manifest's B "conversion" stage. Does not commit.
set -eu
[ "$#" -eq 3 ] || { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
a=$1 b=$2 plan=$3
here="$(cd "$(dirname "$0")" && pwd)"
git -C "$a" cat-file -e "HEAD:$plan" || { echo "convert: $plan is not committed in arm A" >&2; exit 2; }
mkdir -p "$b/$(dirname "$plan")"
git -C "$a" show "HEAD:$plan" > "$b/$plan"
prompt="$(sed "s|{plan}|$plan|g" "$here/conversion-prompt.md")"
mkdir -p "$here/runs"
log="$here/runs/conversion-$(date -u +%Y%m%dT%H%M%SZ).json"
cd "$b"
claude -p --model opus --permission-mode auto --permission-prompts none \
  --output-format json "$prompt" > "$log"
node -e '
  const o = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  console.log(`session ${o.session_id}  result ${o.subtype}  cli cost $${(o.total_cost_usd || 0).toFixed(2)}`);
  console.log(o.result);
' "$log"

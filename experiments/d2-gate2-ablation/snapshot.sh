#!/usr/bin/env bash
# Tag the D2 plan as one of the three arm snapshots. The tag never moves.
#
# usage: snapshot.sh <gate2-worktree> <plan> <S0|S1|S2>
#   plan  path relative to the worktree; must be committed and pass plan-state check
# Prints "d2-<S> <commit>". Exit 2 when the tag exists, the plan has uncommitted
# changes, or plan-state check reports anything.
set -eu
[ "$#" -eq 3 ] || { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
wt=$1 plan=$2 s=$3
case "$s" in S0|S1|S2) ;; *) echo "snapshot: snapshot must be S0, S1 or S2, got '$s'" >&2; exit 2 ;; esac
tag="d2-$s"
[ -f "$wt/$plan" ] || { echo "snapshot: no plan at $wt/$plan" >&2; exit 2; }
if git -C "$wt" rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "snapshot: tag $tag already exists; it never moves" >&2; exit 2
fi
if [ -n "$(git -C "$wt" status --porcelain -- "$plan")" ]; then
  echo "snapshot: $plan has uncommitted changes; commit first" >&2; exit 2
fi
rc=0; out=$(sh "$wt/skills/writing-dag-plans/plan-state" check "$wt/$plan" 2>&1) || rc=$?
if [ "$rc" -ne 0 ] || [ -n "$out" ]; then
  printf '%s\n' "$out" >&2; echo "snapshot: plan-state check failed; not tagging" >&2; exit 2
fi
git -C "$wt" tag "$tag" HEAD
echo "$tag $(git -C "$wt" rev-parse HEAD)"

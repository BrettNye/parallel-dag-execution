#!/usr/bin/env bash
# Create one D2 run's worktree: the base commit plus its arm's plan snapshot.
#
# usage: make-run.sh <repo> <base> <arm> <n> <plan> <dest-parent>
#   arm   none (snapshot d2-S0), round1 (d2-S1) or full (d2-S2)
#   n     1 or 2
#   plan  path of the plan inside the repo
# Makes <dest-parent>/pde-d2-run-<id> on branch d2/run-<id> from <base>, where <id>
# is random hex, with experiments/ left out of the checkout, and commits the
# snapshot's plan as "docs(plans): add the plan". Nothing a run can see names its
# arm: the mapping "<arm>-<n> <id> <branch> <dir>" goes to runs/run-map.txt
# (D2_RUNS overrides runs/). Prints the worktree path.
set -eu
[ "$#" -eq 6 ] || { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
repo=$1 base=$2 arm=$3 n=$4 plan=$5 parent=$6
case "$arm" in none) s=S0 ;; round1) s=S1 ;; full) s=S2 ;; *) echo "make-run: arm must be none, round1 or full, got '$arm'" >&2; exit 2 ;; esac
case "$n" in 1|2) ;; *) echo "make-run: n must be 1 or 2, got '$n'" >&2; exit 2 ;; esac
here="$(cd "$(dirname "$0")" && pwd)"; runs="${D2_RUNS:-$here/runs}"; map="$runs/run-map.txt"
[ -d "$parent" ] || { echo "make-run: no directory $parent" >&2; exit 2; }
if [ -f "$map" ] && grep -q "^$arm-$n " "$map"; then
  echo "make-run: $arm-$n is already in $map" >&2; exit 2
fi
git -C "$repo" rev-parse -q --verify "refs/tags/d2-$s" >/dev/null || { echo "make-run: no tag d2-$s" >&2; exit 2; }
content=$(git -C "$repo" show "d2-$s:$plan") || { echo "make-run: d2-$s has no $plan" >&2; exit 2; }
id=$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')
branch="d2/run-$id" dest="$parent/pde-d2-run-$id"
[ ! -e "$dest" ] || { echo "make-run: $dest already exists" >&2; exit 2; }
if git -C "$repo" rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
  echo "make-run: branch $branch already exists" >&2; exit 2
fi

git -C "$repo" worktree add -q --no-checkout -b "$branch" "$dest" "$base"
# MSYS_NO_PATHCONV: Git Bash would rewrite '!/experiments/' as a Windows path. It
# would also stop converting a -C path, so cd instead.
( cd "$dest" && MSYS_NO_PATHCONV=1 git sparse-checkout set --no-cone '/*' '!/experiments/' )
git -C "$dest" checkout -q
mkdir -p "$(dirname "$dest/$plan")"
printf '%s\n' "$content" > "$dest/$plan"
git -C "$dest" add -- "$plan"
git -C "$dest" -c user.name="Brett Nye" -c user.email="43053436+BrettNye@users.noreply.github.com" \
  commit -q --allow-empty -m "docs(plans): add the plan"
mkdir -p "$runs"
echo "$arm-$n $id $branch $dest" >> "$map"
echo "$dest"

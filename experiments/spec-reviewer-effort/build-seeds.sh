#!/usr/bin/env bash
# Builds the seeded-defect commits locally (they are never pushed).
# Each seeded commit = the original task commit with one defect folded in:
# same parent, same message, so `git show <sha>` looks like an ordinary
# implementer commit. Prints "<seed-id> <base-case> <new-sha>" per line.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
E=experiments/spec-reviewer-effort
WT=$(mktemp -d)/seed-wt
while read -r seed base_case; do
  [[ -z "$seed" || "$seed" == \#* ]] && continue
  base_sha=$(sed -n 's/^commit: //p' "$E/cases/$base_case.md")
  git worktree add -q --detach "$WT" "$base_sha"
  git -C "$WT" apply "$PWD/$E/seeds/$seed.patch"
  git -C "$WT" -c user.name="$(git log -1 --format=%an "$base_sha")" \
    -c user.email="$(git log -1 --format=%ae "$base_sha")" \
    commit -q -a --amend --no-edit
  echo "$seed $base_case $(git -C "$WT" rev-parse HEAD)"
  git worktree remove --force "$WT"
done < "$E/seeds/map.txt"

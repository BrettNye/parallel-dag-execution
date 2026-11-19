#!/usr/bin/env bash
# Set up the blind final reviews: shuffle the run branches, give each a letter
# from P to U, and check each out detached in its own worktree.
#
# usage: make-blind.sh <repo> <dest-parent> <branch>...   (1 to 6 branches)
# Makes <dest-parent>/review-<L> at each branch head with experiments/ left out
# of the checkout, and writes the key, "<L>=<branch> <sha>" per line, to
# runs/blind-key.txt (D2_RUNS overrides runs/). The reviewers never see the key.
set -eu
[ "$#" -ge 3 ] || { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
repo=$1 parent=$2; shift 2
[ "$#" -le 6 ] || { echo "make-blind: at most 6 branches, got $#" >&2; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"; runs="${D2_RUNS:-$here/runs}"
key="$runs/blind-key.txt"
[ ! -e "$key" ] || { echo "make-blind: $key already exists" >&2; exit 2; }
for b in "$@"; do
  git -C "$repo" rev-parse -q --verify "refs/heads/$b" >/dev/null || { echo "make-blind: no branch $b" >&2; exit 2; }
done
[ -d "$parent" ] || { echo "make-blind: no directory $parent" >&2; exit 2; }
letters="P Q R S T U"
i=0; for b in "$@"; do i=$((i+1)); L=$(echo "$letters" | cut -d' ' -f"$i")
  [ ! -e "$parent/review-$L" ] || { echo "make-blind: $parent/review-$L already exists" >&2; exit 2; }
done

mkdir -p "$runs"
tmpkey="$key.tmp"; : > "$tmpkey"
i=0
printf '%s\n' "$@" | shuf | while IFS= read -r b; do
  i=$((i+1)); L=$(echo "$letters" | cut -d' ' -f"$i")
  sha=$(git -C "$repo" rev-parse "$b")
  dest="$parent/review-$L"
  git -C "$repo" worktree add -q --no-checkout --detach "$dest" "$sha"
  # MSYS_NO_PATHCONV: Git Bash would rewrite '!/experiments/' as a Windows path.
  ( cd "$dest" && MSYS_NO_PATHCONV=1 git sparse-checkout set --no-cone '/*' '!/experiments/' && git checkout -q )
  echo "$L=$b $sha" >> "$tmpkey"
done
mv "$tmpkey" "$key"
cut -d' ' -f1 "$key" | sed "s|=.*||;s|^|$parent/review-|"

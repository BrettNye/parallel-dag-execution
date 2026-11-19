#!/usr/bin/env bash
# Export the plugin at one commit into a plain directory that both arms load
# with --plugin-dir. A plain export, not a worktree: nothing can move it.
#
# usage: pin-plugin.sh <repo> <commit> <dest-parent>
# Prints the directory it made: <dest-parent>/pde-pinned-<short sha>.
set -eu
[ "$#" -eq 3 ] || { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
repo=$1 commit=$2 parent=$3
sha=$(git -C "$repo" rev-parse --verify "$commit^{commit}")
dest="$parent/pde-pinned-$(git -C "$repo" rev-parse --short "$sha")"
[ -e "$dest" ] && { echo "pin-plugin: $dest already exists" >&2; exit 2; }
mkdir -p "$dest"
git -C "$repo" archive "$sha" | tar -x -C "$dest"
echo "$sha" > "$dest/PINNED_COMMIT"
[ -f "$dest/.claude-plugin/plugin.json" ] || { echo "pin-plugin: no plugin manifest at $commit" >&2; exit 1; }
echo "$dest"

#!/usr/bin/env sh
# A stale mutex (mtime older than the 60s threshold) must be broken; commit succeeds.
set -eu

HELPER="$(cd "$(dirname "$0")/../../skills/executing-dag-plans" && pwd)/git-commit-safe"
[ -f "$HELPER" ] || { echo "FAIL: helper not found at $HELPER" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q
git config user.email t@t.test
git config user.name tester
echo base > base.txt && git add base.txt && git commit -qm base

lock="$(git rev-parse --git-dir)/dag-commit.lock"
mkdir "$lock"
# Backdate mtime beyond the 60s stale threshold (GNU touch in git-bash).
touch -d "120 seconds ago" "$lock"

echo x > f.txt
if ! sh "$HELPER" "after stale" f.txt; then
  echo "FAIL: helper did not succeed despite stale lock" >&2
  exit 1
fi

if [ "$(git rev-list --count HEAD)" -ne 2 ]; then
  echo "FAIL: commit did not land" >&2
  exit 1
fi
if [ -e "$lock" ]; then
  echo "FAIL: lock not released after commit" >&2
  exit 1
fi
echo "PASS stale-lock"

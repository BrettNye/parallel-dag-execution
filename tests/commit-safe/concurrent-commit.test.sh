#!/usr/bin/env sh
# Forks N concurrent git-commit-safe invocations on disjoint files and asserts:
# all land, no index.lock errors, each commit touches exactly one file.
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

N=12
i=1
while [ "$i" -le "$N" ]; do
  echo "content-$i" > "file-$i.txt"
  sh "$HELPER" "task-$i" "file-$i.txt" > "out-$i.log" 2>&1 &
  i=$((i + 1))
done
wait

fail=0

if grep -liE "index\.lock|Unable to create" out-*.log >/dev/null 2>&1; then
  echo "FAIL: index.lock error present in a commit log" >&2
  fail=1
fi

count="$(git rev-list --count HEAD)"
if [ "$count" -ne $((N + 1)) ]; then
  echo "FAIL: expected $((N + 1)) commits, got $count" >&2
  fail=1
fi

# Every non-base commit must touch exactly one file (no bundling).
for h in $(git log --format=%H "$(git rev-list --max-parents=0 HEAD)"..HEAD); do
  n="$(git show --name-only --format= "$h" | grep -c .)"
  if [ "$n" -ne 1 ]; then
    echo "FAIL: commit $h touched $n files (bundling)" >&2
    fail=1
  fi
done

[ "$fail" -eq 0 ] && echo "PASS concurrent-commit"
exit "$fail"

#!/usr/bin/env bash
# Tests for snapshot.sh and make-run.sh in a throwaway git repo.
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PS_SRC="${PLAN_STATE:-C:/Users/Brett/workspace/personal/repos/parallel-dag-execution/skills/writing-dag-plans/plan-state}"
fails=0; passes=0
ok()   { passes=$((passes+1)); echo "  PASS: $1"; }
bad()  { fails=$((fails+1));  echo "  FAIL: $1"; }
chk()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$3] got [$2])"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
R="$tmp/repo"; P=docs/plan.md
mkdir -p "$R/skills/writing-dag-plans" "$R/docs" "$R/experiments"
cp "$PS_SRC" "$R/skills/writing-dag-plans/plan-state"
echo x > "$R/experiments/x.txt"
cat > "$R/$P" <<'EOF'
---
title: demo
created: 2026-11-16
---

## Tasks

## Task: one

```yaml
id: task-a
depends_on: []
files: [a.sh]
status: pending
```

## Task: two

```yaml
id: task-b
depends_on: [task-a]
files: [b.sh]
status: pending
```
EOF
g() { git -C "$R" -c user.name=t -c user.email=t@t "$@"; }
g init -q && sh "$R/skills/writing-dag-plans/plan-state" render "$R/$P" && g add -A && g commit -qm base
base=$(g rev-parse HEAD)

echo "T1: snapshot.sh tags a clean plan, once"
out="$(bash "$HERE/snapshot.sh" "$R" "$P" S0 2>&1)"; rc=$?
chk "S0 exits 0" "$rc" "0"
chk "tag d2-S0 at HEAD" "$(g rev-parse d2-S0^{commit})" "$base"
g commit -q --allow-empty -m later
bash "$HERE/snapshot.sh" "$R" "$P" S0 >/dev/null 2>&1; rc=$?
chk "existing tag exits 2" "$rc" "2"
chk "existing tag not moved" "$(g rev-parse d2-S0^{commit})" "$base"
bash "$HERE/snapshot.sh" "$R" "$P" S3 >/dev/null 2>&1; chk "S3 exits 2" "$?" "2"

echo
echo "T2: snapshot.sh refuses a plan that fails check, or has uncommitted changes"
sed -i 's/^id: task-b$/id: task-a/' "$R/$P"
bash "$HERE/snapshot.sh" "$R" "$P" S1 >/dev/null 2>&1; chk "uncommitted change exits 2" "$?" "2"
g commit -qam dup
bash "$HERE/snapshot.sh" "$R" "$P" S1 >/dev/null 2>&1; chk "duplicate id exits 2" "$?" "2"
g rev-parse -q --verify d2-S1 >/dev/null; chk "no d2-S1 tag" "$?" "1"
sed -i '0,/^id: task-a$/! s/^id: task-a$/id: task-b/' "$R/$P"; g commit -qam fixed
bash "$HERE/snapshot.sh" "$R" "$P" S1 >/dev/null 2>&1; chk "fixed plan tags S1" "$?" "0"
echo '<!-- full -->' >> "$R/$P"; g commit -qam s2
bash "$HERE/snapshot.sh" "$R" "$P" S2 >/dev/null 2>&1; chk "S2 tags" "$?" "0"

echo
echo "T3: make-run.sh gives neutral names and keeps the arm in a private map"
export D2_RUNS="$tmp/runs"
D="$tmp/run parent"; mkdir -p "$D"
out="$(bash "$HERE/make-run.sh" "$R" "$base" round1 1 "$P" "$D" 2>&1)"; rc=$?
chk "exit 0 with a space in dest" "$rc" "0"
map="$tmp/runs/run-map.txt"
line="$(grep '^round1-1 ' "$map")"
id="$(echo "$line" | cut -d' ' -f2)"
W="$D/pde-d2-run-$id"
chk "prints the worktree" "$out" "$W"
chk "map line" "$line" "round1-1 $id d2/run-$id $W"
case "$id" in *[!0-9a-f]*|'') bad "id is hex ($id)" ;; *) ok "id is hex" ;; esac
chk "plan is the S1 snapshot" "$(cat "$W/$P")" "$(g show d2-S1:$P)"
[ -e "$W/experiments" ]; chk "no experiments/ on disk" "$?" "1"
chk "branch starts at base" "$(g rev-parse "d2/run-$id~1")" "$base"
chk "neutral commit message" "$(git -C "$W" log -1 --format=%s)" "docs(plans): add the plan"
chk "plan committed" "$(git -C "$W" status --porcelain -- "$P")" ""
case "$(git -C "$W" log --format=%s%n%b; git -C "$W" branch --show-current; echo "$W")" in
  *round1*|*none*|*full*) bad "no arm name in log, branch or path" ;; *) ok "no arm name in log, branch or path" ;; esac
bash "$HERE/make-run.sh" "$R" "$base" round1 1 "$P" "$D" >/dev/null 2>&1; chk "same run again exits 2" "$?" "2"
bash "$HERE/make-run.sh" "$R" "$base" best 1 "$P" "$D" >/dev/null 2>&1; chk "arm best exits 2" "$?" "2"
bash "$HERE/make-run.sh" "$R" "$base" none 3 "$P" "$D" >/dev/null 2>&1; chk "n 3 exits 2" "$?" "2"
out="$(bash "$HERE/make-run.sh" "$R" "$base" none 2 "$P" "$D" 2>&1)"; rc=$?
chk "none-2 exits 0" "$rc" "0"
chk "none plan is S0" "$(cat "$out/$P")" "$(g show d2-S0:$P)"
[ "$out" != "$W" ]; chk "a second run gets its own id" "$?" "0"
bash "$HERE/make-run.sh" "$R" "$base" none 1 "$P" >/dev/null 2>&1; chk "wrong arg count exits 2" "$?" "2"

for w in "$D"/pde-d2-run-*; do g worktree remove --force "$w" >/dev/null 2>&1; done
echo "RESULT: $passes passed, $fails failed"
[ "$fails" -eq 0 ]

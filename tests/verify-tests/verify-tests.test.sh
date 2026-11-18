#!/usr/bin/env bash
# Test suite for skills/executing-dag-plans/verify-tests
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO/skills/executing-dag-plans/verify-tests"
[ -f "$SCRIPT" ] || { echo "FAIL: verify-tests not found at $SCRIPT" >&2; exit 1; }
command -v rg >/dev/null 2>&1 || { echo "tests need rg (ripgrep)" >&2; exit 2; }
if command -v dash >/dev/null 2>&1; then ALTSH=dash; else ALTSH=sh; echo "NOTE: dash not installed - alt-shell cases run under sh"; fi
fails=0; passes=0
ok()   { passes=$((passes+1)); echo "  PASS: $1"; }
bad()  { fails=$((fails+1));  echo "  FAIL: $1"; }
chk()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$3] got [$2])"; fi; }
has()  { if printf '%s\n' "$2" | rg -qF -- "$3"; then ok "$1"; else bad "$1 (missing [$3] in: $2)"; fi; }
hasnt(){ if printf '%s\n' "$2" | rg -qF -- "$3"; then bad "$1 (unexpected [$3] in: $2)"; else ok "$1"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# mkplan <path> <extra yaml lines for task-a>
mkplan() {
cat > "$1" <<PLAN
---
title: demo
created: 2026-11-17
---

## Tasks

## Task: a

\`\`\`yaml
id: task-a
depends_on: []
files:
  - t/a.sh
status: pending
$2
\`\`\`
PLAN
}
mkplan "$tmp/notests.md" ''
mkplan "$tmp/nobase.md" 'tests:
  - t/a.sh :: round counts'

# run <shell> <args...>: prints "rc:stdout"; stderr goes to $tmp/e.
run() { local sh_="$1" out rc; shift; out="$("$sh_" "$SCRIPT" "$@" 2>"$tmp/e")"; rc=$?; printf '%s:%s' "$rc" "$out"; }
err() { cat "$tmp/e"; }

r="$(run sh)"; e="$(err)"
chk "args: no arguments is usage" "$r" "2:"
has "args: no arguments is usage (0 args stderr)" "$e" "verify-tests <plan> <id>"
r="$(run sh "$tmp/notests.md")"; e="$(err)"
chk "args: one argument is usage" "$r" "2:"
has "args: one argument is usage (stderr)" "$e" "verify-tests <plan> <id>"
r="$(run sh "$tmp/notests.md" task-a extra)"; e="$(err)"
chk "args: three arguments is usage" "$r" "2:"
has "args: three arguments is usage (stderr)" "$e" "verify-tests <plan> <id>"

r="$(run sh "$tmp/notests.md" zz)"; e="$(err)"
chk "args: plan-state error is relayed" "$r" "2:"
has "args: plan-state error is relayed (stderr)" "$e" "plan-state: no task with id zz"
r="$(run sh "$tmp/missing.md" task-a)"; e="$(err)"
chk "args: unreadable plan is relayed" "$r" "2:"
has "args: unreadable plan is relayed (stderr)" "$e" "plan-state: cannot read"

r="$(run sh "$tmp/notests.md" task-a)"
chk "args: no named tests exits 0" "$r" "0:verify-tests: task-a: no named tests"
r="$(run sh "$tmp/nobase.md" task-a)"; e="$(err)"
chk "args: no base_sha exits 2" "$r" "2:"
has "args: no base_sha exits 2 (stderr)" "$e" "verify-tests: task-a: no base_sha (set the task running first)"

# The same cases under dash (or sh when dash is missing), exit codes and stdout only.
alt="$(run "$ALTSH"; run "$ALTSH" "$tmp/notests.md"; run "$ALTSH" "$tmp/notests.md" task-a x; run "$ALTSH" "$tmp/notests.md" zz; run "$ALTSH" "$tmp/missing.md" task-a; run "$ALTSH" "$tmp/notests.md" task-a; run "$ALTSH" "$tmp/nobase.md" task-a)"
chk "args: runs under dash" "$alt" "2:2:2:2:2:0:verify-tests: task-a: no named tests2:"

echo "attributes"
chk "eol attribute is lf" "$(git -C "$REPO" check-attr eol -- skills/executing-dag-plans/verify-tests)" "skills/executing-dag-plans/verify-tests: eol: lf"
chk "script has no CR byte" "$(tr -d -c '\r' < "$SCRIPT" | wc -c | tr -d ' ')" "0"

echo "RESULT: $passes passed, $fails failed"
[ "$fails" -eq 0 ]

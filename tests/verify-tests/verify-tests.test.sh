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

echo "trees"
# Runs use their own TMPDIR, so the suite can see what verify-tests leaves behind.
VT_T="$tmp/T"; mkdir -p "$VT_T"
: > "$tmp/allout"
# vt <plan> [shell]: prints "rc:stdout" up to the total line (the tail blocks are checked in "tails");
# stderr goes to $tmp/e; all stdout is also kept in $tmp/allout.
vt() { local out rc; out="$(TMPDIR="$VT_T" "${2:-sh}" "$SCRIPT" "$1" T1 2>"$tmp/e")"; rc=$?
  printf '%s\n' "$out" >> "$tmp/allout"
  printf '%s:%s' "$rc" "$(printf '%s\n' "$out" | sed '/^verify-tests: T1: /q')"; }
newrepo() { mkdir -p "$1" && git -C "$1" init -q && git -C "$1" config user.email t@example.com &&
  git -C "$1" config user.name t && git -C "$1" config core.autocrlf false; }
put() { mkdir -p "$(dirname -- "$1/$2")"; printf '%s\n' "$3" > "$1/$2"; }
commit() { git -C "$1" add -A && git -C "$1" commit -qm "$2"; }
# writeplan <dir> <base> <files yaml> <tests yaml> [front matter lines]: writes <dir>/plan.md, left untracked.
writeplan() {
  { printf -- '---\ntitle: demo\n'; [ -n "${5:-}" ] && printf '%s\n' "$5"
    printf -- '---\n\n## Task: one\n\n```yaml\nid: T1\ndepends_on: []\nfiles:\n%s\nstatus: running\nbase_sha: %s\ntests:\n%s\n```\n' "$3" "$2" "$4"; } > "$1/plan.md"
}
LIB_BAD='add() { echo 0; }'
LIB_GOOD='add() { echo $(($1 + $2)); }'
DEMO='. ./lib.sh
if [ "$(add 1 2)" = 3 ]; then echo "PASS: adds"; else echo "FAIL: adds (got $(add 1 2))"; fi'
FILES2='  - lib.sh
  - t/demo.test.sh'
# mkrepo <dir> [suite]: the suite and a wrong lib.sh are committed, base_sha is taken (B),
# then the task's commit makes lib.sh right. The plan's T1 names t/demo.test.sh :: adds.
mkrepo() {
  newrepo "$1"; put "$1" lib.sh "$LIB_BAD"; put "$1" t/demo.test.sh "${2:-$DEMO}"; commit "$1" base
  B=$(git -C "$1" rev-parse HEAD)
  put "$1" lib.sh "$LIB_GOOD"; commit "$1" task
  writeplan "$1" "$B" "$FILES2" '  - t/demo.test.sh :: adds'
}
wtcount() { git -C "$1" worktree list | wc -l | tr -d ' '; }
tmpleft() { ls -A "$1" | wc -l | tr -d ' '; }

mkrepo "$tmp/r1"
st0="$(git -C "$tmp/r1" status --porcelain)"; ck0="$(cksum < "$tmp/r1/plan.md")"; h0="$(git -C "$tmp/r1" rev-parse HEAD)"
r="$(vt "$tmp/r1/plan.md")"; r2="$(vt "$tmp/r1/plan.md" "$ALTSH")"
chk "trees: red then green is ok" "$r|$r2" "0:ok	t/demo.test.sh	adds
verify-tests: T1: 1 ok, 0 failed|0:ok	t/demo.test.sh	adds
verify-tests: T1: 1 ok, 0 failed"
chk "trees: shared tree untouched" "$(git -C "$tmp/r1" status --porcelain)|$(cksum < "$tmp/r1/plan.md")|$(git -C "$tmp/r1" rev-parse HEAD)" "$st0|$ck0|$h0"
ok0="$(wtcount "$tmp/r1"):$(tmpleft "$VT_T")"

# The suite stops at its first line while new.sh, which the task creates, is missing.
newrepo "$tmp/r2"; put "$tmp/r2" t/demo.test.sh '[ -f new.sh ] || exit 1
. ./new.sh
if [ "$(add 1 2)" = 3 ]; then echo "PASS: adds"; else echo "FAIL: adds"; fi'; commit "$tmp/r2" base
B=$(git -C "$tmp/r2" rev-parse HEAD); put "$tmp/r2" new.sh "$LIB_GOOD"; commit "$tmp/r2" task
writeplan "$tmp/r2" "$B" '  - new.sh
  - t/demo.test.sh' '  - t/demo.test.sh :: adds'
r="$(vt "$tmp/r2/plan.md")"
chk "trees: absent before is ok-absent" "$r" "0:ok-absent	t/demo.test.sh	adds
verify-tests: T1: 1 ok, 0 failed"

mkrepo "$tmp/r3" 'echo "PASS: adds"'
r="$(vt "$tmp/r3/plan.md")"
chk "trees: passing before is not-red" "$r" "1:not-red	t/demo.test.sh	adds
verify-tests: T1: 0 ok, 1 failed"
fail0="$(wtcount "$tmp/r3"):$(tmpleft "$VT_T")"
chk "trees: no worktree or temp dir left" "$ok0|$fail0" "1:0|1:0"

# At base_sha the suite has only case x; the task's commit adds case y, which passes on the old code.
newrepo "$tmp/r4"; put "$tmp/r4" lib.sh "$LIB_BAD"; put "$tmp/r4" t/demo.test.sh 'echo "FAIL: x"'; commit "$tmp/r4" base
B=$(git -C "$tmp/r4" rev-parse HEAD); put "$tmp/r4" lib.sh "$LIB_GOOD"; put "$tmp/r4" t/demo.test.sh 'echo "FAIL: x"
echo "PASS: y"'; commit "$tmp/r4" task
writeplan "$tmp/r4" "$B" "$FILES2" '  - t/demo.test.sh :: y'
r="$(vt "$tmp/r4/plan.md")"
chk "trees: new case passing on old code is not-red" "$r" "1:not-red	t/demo.test.sh	y
verify-tests: T1: 0 ok, 1 failed"

# At base_sha the suite file does not exist; the task's commit adds it.
newrepo "$tmp/r5"; put "$tmp/r5" lib.sh "$LIB_BAD"; commit "$tmp/r5" base
B=$(git -C "$tmp/r5" rev-parse HEAD); put "$tmp/r5" lib.sh "$LIB_GOOD"; put "$tmp/r5" t/demo.test.sh 'echo "PASS: y"'; commit "$tmp/r5" task
writeplan "$tmp/r5" "$B" "$FILES2" '  - t/demo.test.sh :: y'
r="$(vt "$tmp/r5/plan.md")"
chk "trees: new suite file is kept in the before tree" "$r" "1:not-red	t/demo.test.sh	y
verify-tests: T1: 0 ok, 1 failed"

mkrepo "$tmp/r6" 'echo "FAIL: adds (still wrong)"'
r="$(vt "$tmp/r6/plan.md")"
chk "trees: failing after is not-green" "$r" "1:not-green	t/demo.test.sh	adds
verify-tests: T1: 0 ok, 1 failed"
# lib.sh is right at base_sha and wrong after the task's commit.
newrepo "$tmp/r7"; put "$tmp/r7" lib.sh "$LIB_GOOD"; put "$tmp/r7" t/demo.test.sh "$DEMO"; commit "$tmp/r7" base
B=$(git -C "$tmp/r7" rev-parse HEAD); put "$tmp/r7" lib.sh "$LIB_BAD"; commit "$tmp/r7" task
writeplan "$tmp/r7" "$B" "$FILES2" '  - t/demo.test.sh :: adds'
r="$(vt "$tmp/r7/plan.md")"
chk "trees: not-green wins over not-red" "$r" "1:not-green	t/demo.test.sh	adds
verify-tests: T1: 0 ok, 1 failed"

mkrepo "$tmp/r8" "$DEMO"'
echo "PASS: adds"'
r="$(vt "$tmp/r8/plan.md")"
chk "trees: duplicate name is ambiguous" "$r" "1:ambiguous	t/demo.test.sh	adds
verify-tests: T1: 0 ok, 1 failed"

# Before: "  FAIL: x (detail)" and "FAIL: exit 0". After: "PASS: x", "PASS: x2", "PASS: exit 0 with charter".
# Both trees print "FAIL: xy (z)", a result line for no entry (a bare prefix match would make x ambiguous).
mkrepo "$tmp/r9" '. ./lib.sh
echo "FAIL: xy (z)"
if [ "$(add 1 2)" = 3 ]; then echo "PASS: x"; echo "PASS: x2"; echo "PASS: exit 0 with charter"
else echo "  FAIL: x (expected [1] got [2])"; echo "FAIL: exit 0"; fi'
writeplan "$tmp/r9" "$B" "$FILES2" '  - t/demo.test.sh :: x
  - t/demo.test.sh :: x2
  - t/demo.test.sh :: exit 0'
r="$(vt "$tmp/r9/plan.md")"
chk "trees: fail line with ( detail matches" "$r" "1:ok	t/demo.test.sh	x
ok-absent	t/demo.test.sh	x2
not-green	t/demo.test.sh	exit 0
verify-tests: T1: 2 ok, 1 failed"

newrepo "$tmp/r10"; put "$tmp/r10" lib.sh "$LIB_BAD"; put "$tmp/r10" t/demo.test.sh '. ./lib.sh
if [ "$(add 1 2)" = 3 ]; then echo "ok - adds"; else echo "not ok - adds"; fi'; commit "$tmp/r10" base
B=$(git -C "$tmp/r10" rev-parse HEAD); put "$tmp/r10" lib.sh "$LIB_GOOD"; commit "$tmp/r10" task
writeplan "$tmp/r10" "$B" "$FILES2" '  - t/demo.test.sh :: adds' 'test_command: sh {file}
test_pass_prefix: "ok - "
test_fail_prefix: "not ok - "'
r="$(vt "$tmp/r10/plan.md")"
chk "trees: custom command and prefixes" "$r" "0:ok	t/demo.test.sh	adds
verify-tests: T1: 1 ok, 0 failed"

newrepo "$tmp/r11"; put "$tmp/r11" lib.sh "$LIB_BAD"; put "$tmp/r11" "t/it's a.test.sh" "$DEMO"; commit "$tmp/r11" base
B=$(git -C "$tmp/r11" rev-parse HEAD); put "$tmp/r11" lib.sh "$LIB_GOOD"; commit "$tmp/r11" task
writeplan "$tmp/r11" "$B" "  - lib.sh
  - t/it's a.test.sh" "  - t/it's a.test.sh :: adds"
r="$(vt "$tmp/r11/plan.md")"
chk "trees: file with a space and a quote" "$r" "0:ok	t/it's a.test.sh	adds
verify-tests: T1: 1 ok, 0 failed"

# The task's commit leaves lib.sh wrong; an uncommitted edit in the shared tree would fix it.
newrepo "$tmp/r12"; put "$tmp/r12" lib.sh "$LIB_BAD"; put "$tmp/r12" t/demo.test.sh "$DEMO"; commit "$tmp/r12" base
B=$(git -C "$tmp/r12" rev-parse HEAD); put "$tmp/r12" lib.sh 'add() { echo 1; }'; commit "$tmp/r12" task
put "$tmp/r12" lib.sh "$LIB_GOOD"
writeplan "$tmp/r12" "$B" "$FILES2" '  - t/demo.test.sh :: adds'
r="$(vt "$tmp/r12/plan.md")"
chk "trees: uncommitted change is ignored" "$r" "1:not-green	t/demo.test.sh	adds
verify-tests: T1: 0 ok, 1 failed"

newrepo "$tmp/r13"; put "$tmp/r13" t/demo.test.sh 'if [ -f new.sh ]; then echo "PASS: new"; else echo "FAIL: new (new.sh missing)"; fi'
commit "$tmp/r13" base; B=$(git -C "$tmp/r13" rev-parse HEAD); put "$tmp/r13" new.sh 'x=1'; commit "$tmp/r13" task
writeplan "$tmp/r13" "$B" '  - new.sh
  - t/demo.test.sh' '  - t/demo.test.sh :: new'
r="$(vt "$tmp/r13/plan.md")"
chk "trees: before tree deletes a path new since base" "$r" "0:ok	t/demo.test.sh	new
verify-tests: T1: 1 ok, 0 failed"

mkrepo "$tmp/r14" '. ./lib.sh
if [ "$(add 1 2)" = 3 ]; then echo "PASS: a"; echo "PASS: b"; else echo "FAIL: a"; echo "FAIL: b"; fi'
writeplan "$tmp/r14" "$B" "$FILES2" '  - t/demo.test.sh :: b
  - t/demo.test.sh :: a'
r="$(vt "$tmp/r14/plan.md")"
chk "trees: two entries keep tests: order" "$r" "0:ok	t/demo.test.sh	b
ok	t/demo.test.sh	a
verify-tests: T1: 2 ok, 0 failed"

writeplan "$tmp/r1" 0000000 "$FILES2" '  - t/demo.test.sh :: adds'
r="$(vt "$tmp/r1/plan.md")"; e="$(err)"
chk "trees: base_sha not a commit" "$r|$(printf '%s' "$e" | rg -c 'is not a commit')" "2:|1"

# dep.sh is git-ignored and exists only in the shared working tree.
newrepo "$tmp/r15"; put "$tmp/r15" .gitignore 'dep.sh'; put "$tmp/r15" lib.sh "$LIB_BAD"
put "$tmp/r15" t/demo.test.sh 'if [ -f dep.sh ]; then . ./dep.sh; fi
if [ "$(dep 2>/dev/null)" = yes ]; then echo "PASS: dep"; else echo "FAIL: dep (no dep.sh)"; fi'
commit "$tmp/r15" base; B=$(git -C "$tmp/r15" rev-parse HEAD); put "$tmp/r15" lib.sh "$LIB_GOOD"; commit "$tmp/r15" task
put "$tmp/r15" dep.sh 'dep() { echo yes; }'
writeplan "$tmp/r15" "$B" "$FILES2" '  - t/demo.test.sh :: dep'
r="$(vt "$tmp/r15/plan.md")"
chk "trees: ignored dependency is not in the after tree" "$r" "1:not-green	t/demo.test.sh	dep
verify-tests: T1: 0 ok, 1 failed"


echo "tails"
# vtfull <plan> [shell]: like vt, but prints the whole stdout, the tail blocks included.
vtfull() { local out rc; out="$(TMPDIR="$VT_T" "${2:-sh}" "$SCRIPT" "$1" T1 2>"$tmp/e")"; rc=$?
  printf '%s\n' "$out" >> "$tmp/allout"; printf '%s:%s' "$rc" "$out"; }
# a.sh is absent before (new.sh is created by the task) and passes after; b.sh fails after.
newrepo "$tmp/q1"; put "$tmp/q1" t/a.sh 'echo start
[ -f new.sh ] || exit 1
echo "PASS: x"'; put "$tmp/q1" t/b.sh 'echo "FAIL: y"'; commit "$tmp/q1" base
B=$(git -C "$tmp/q1" rev-parse HEAD); put "$tmp/q1" new.sh 'x=1'; commit "$tmp/q1" task
writeplan "$tmp/q1" "$B" '  - new.sh
  - t/a.sh
  - t/b.sh' '  - t/a.sh :: x
  - t/b.sh :: y'
r="$(vtfull "$tmp/q1/plan.md")"
chk "tails: spec example order" "$r" "1:ok-absent	t/a.sh	x
not-green	t/b.sh	y
verify-tests: T1: 1 ok, 1 failed
--- t/a.sh (before)
  | start
--- t/b.sh (after)
  | FAIL: y"

mkrepo "$tmp/q2" 'i=1; while [ "$i" -le 30 ]; do echo "line $i"; i=$((i + 1)); done
echo "FAIL: adds"'
r="$(vtfull "$tmp/q2/plan.md" | sed '1,/^verify-tests: T1: /d')"
chk "tails: last 20 lines only" "$(printf '%s\n' "$r" | rg -c '^  \| ')|$(printf '%s\n' "$r" | sed -n '2p')|$(printf '%s\n' "$r" | tail -n 1)" "20|  | line 12|  | FAIL: adds"

# lib.sh is right at base_sha and wrong after: the suite passes before and fails after.
newrepo "$tmp/q3"; put "$tmp/q3" lib.sh "$LIB_GOOD"; put "$tmp/q3" t/demo.test.sh "$DEMO"; commit "$tmp/q3" base
B=$(git -C "$tmp/q3" rev-parse HEAD); put "$tmp/q3" lib.sh "$LIB_BAD"; commit "$tmp/q3" task
writeplan "$tmp/q3" "$B" "$FILES2" '  - t/demo.test.sh :: adds'
r="$(vtfull "$tmp/q3/plan.md")"
chk "tails: not-red and not-green gives only after" "$(printf '%s\n' "${r#*:}" | rg '^(not-|---)')" "not-green	t/demo.test.sh	adds
--- t/demo.test.sh (after)"

# g fails in both trees; h is absent before (new.sh is missing) and passes after.
newrepo "$tmp/q4"; put "$tmp/q4" t/demo.test.sh 'echo "FAIL: g"
if [ -f new.sh ]; then echo "PASS: h"; fi'; commit "$tmp/q4" base
B=$(git -C "$tmp/q4" rev-parse HEAD); put "$tmp/q4" new.sh 'x=1'; commit "$tmp/q4" task
writeplan "$tmp/q4" "$B" '  - new.sh
  - t/demo.test.sh' '  - t/demo.test.sh :: g
  - t/demo.test.sh :: h'
r="$(vtfull "$tmp/q4/plan.md")"
chk "tails: one file gives after then before" "$(printf '%s\n' "${r#*:}" | rg '^(not-|ok|---)')" "not-green	t/demo.test.sh	g
ok-absent	t/demo.test.sh	h
--- t/demo.test.sh (after)
--- t/demo.test.sh (before)"

newrepo "$tmp/q5"; put "$tmp/q5" t/a.sh 'echo "FAIL: p"'; put "$tmp/q5" t/b.sh 'echo "FAIL: p"'; commit "$tmp/q5" base
B=$(git -C "$tmp/q5" rev-parse HEAD); put "$tmp/q5" new.sh 'x=1'; commit "$tmp/q5" task
writeplan "$tmp/q5" "$B" '  - new.sh
  - t/a.sh
  - t/b.sh' '  - t/b.sh :: p
  - t/a.sh :: p'
r="$(vtfull "$tmp/q5/plan.md")"
chk "tails: file order follows tests:" "$(printf '%s\n' "${r#*:}" | rg '^---')" "--- t/b.sh (after)
--- t/a.sh (after)"

# t/a.sh's output has no final newline: its tail line must still end, before t/b.sh's header.
newrepo "$tmp/q8"; put "$tmp/q8" t/a.sh 'printf "FAIL: p"'; put "$tmp/q8" t/b.sh 'echo "FAIL: p"'; commit "$tmp/q8" base
B=$(git -C "$tmp/q8" rev-parse HEAD); put "$tmp/q8" new.sh 'x=1'; commit "$tmp/q8" task
writeplan "$tmp/q8" "$B" '  - new.sh
  - t/a.sh
  - t/b.sh' '  - t/a.sh :: p
  - t/b.sh :: p'
TMPDIR="$VT_T" sh "$SCRIPT" "$tmp/q8/plan.md" T1 > "$tmp/q8.out" 2>"$tmp/e"
last=$(tail -c 1 "$tmp/q8.out" | od -An -c | tr -d ' ')
chk "tails: output with no final newline" "$(sed '1,/^verify-tests: T1: /d' "$tmp/q8.out")|$last" "--- t/a.sh (after)
  | FAIL: p
--- t/b.sh (after)
  | FAIL: p|\\n"

# t/gone.sh is listed in files: and named in tests:, but was never committed.
mkrepo "$tmp/q6"
B=$(git -C "$tmp/q6" rev-list --max-parents=0 HEAD); writeplan "$tmp/q6" "$B" "$FILES2
  - t/gone.sh" '  - t/gone.sh :: q'
r="$(vtfull "$tmp/q6/plan.md" | sed '1,/^verify-tests: T1: /d')"
chk "tails: no output shows placeholder" "$r" "--- t/gone.sh (after)
  | (no output)"

mkrepo "$tmp/q7"
r="$(vtfull "$tmp/q7/plan.md")"
chk "tails: all ok prints no block" "$(printf '%s\n' "${r#*:}" | rg '^---' | wc -l | tr -d ' ')|$r" "0|0:ok	t/demo.test.sh	adds
verify-tests: T1: 1 ok, 0 failed"
echo "signals"
# mksleepy <dir>: like mkrepo, but while <dir>.flag exists the suite writes its pid to <dir>.mark and sleeps.
mksleepy() {
  newrepo "$1"; put "$1" lib.sh "$LIB_BAD"
  put "$1" t/demo.test.sh "if [ -f '$1.flag' ]; then echo \$\$ > '$1.mark'; exec sleep 30; fi
$DEMO"
  commit "$1" base; B=$(git -C "$1" rev-parse HEAD); put "$1" lib.sh "$LIB_GOOD"; commit "$1" task
  writeplan "$1" "$B" "$FILES2" '  - t/demo.test.sh :: adds'; : > "$1.flag"
}
waitfile() { local i=0; while [ ! -s "$1" ] && [ "$i" -lt 300 ]; do sleep 0.1; i=$((i+1)); done; [ -s "$1" ]; }
# startvt <shell> <dir> <tmpdir>: starts verify-tests in the background with job control on, so
# SIGINT is not ignored in it; sets pid.
startvt() { set -m; TMPDIR="$3" "$1" "$SCRIPT" "$2/plan.md" T1 >"$2.so" 2>"$2.se" & pid=$!; set +m; }
# sigrun <shell> <signal> <tag>: prints "rc:<interrupted lines>:<worktrees>:<entries left in TMPDIR>".
sigrun() {
  local d="$tmp/s$3" T="$tmp/Ts$3" rc; mkdir -p "$T"; mksleepy "$d"
  startvt "$1" "$d" "$T"; waitfile "$d.mark" || echo "(suite never started)"
  kill -s "$2" "$pid"; wait "$pid"; rc=$?
  cat "$d.so" >> "$tmp/allout"
  printf '%s:%s:%s:%s' "$rc" "$(rg -c 'verify-tests: T1: interrupted' "$d.se")" "$(wtcount "$d")" "$(tmpleft "$T")"
}
chk "signals: TERM mid-run cleans up" "$(sigrun sh TERM TERM1)|$(sigrun "$ALTSH" TERM TERM2)" "2:1:1:0|2:1:1:0"
chk "signals: INT mid-run cleans up" "$(sigrun sh INT INT1)|$(sigrun "$ALTSH" INT INT2)" "2:1:1:0|2:1:1:0"
chk "signals: HUP mid-run cleans up" "$(sigrun sh HUP HUP1)|$(sigrun "$ALTSH" HUP HUP2)" "2:1:1:0|2:1:1:0"

# suitegone <shell> <tag> <nojc>: TERM mid-run, then is the process the suite started still alive?
# Prints "rc:alive". <nojc>=1 sets VERIFY_TESTS_NO_JOBCTL, standing in for a shell where set -m
# cannot turn job control on (no terminal), so the suite shares verify-tests' process group.
# The suite starts sleep as its own child and waits, so the sleeping process is a grandchild of
# verify-tests' child: stopping only the child would leave it running.
mkspawner() {
  newrepo "$1"; put "$1" lib.sh "$LIB_BAD"
  put "$1" t/demo.test.sh "if [ -f '$1.flag' ]; then sleep 30 & echo \$! > '$1.mark'; wait; exit 1; fi
$DEMO"
  commit "$1" base; B=$(git -C "$1" rev-parse HEAD); put "$1" lib.sh "$LIB_GOOD"; commit "$1" task
  writeplan "$1" "$B" "$FILES2" '  - t/demo.test.sh :: adds'; : > "$1.flag"
}
suitegone() {
  local d="$tmp/sg$2" T="$tmp/Tsg$2" rc a; mkdir -p "$T"; mkspawner "$d"
  VERIFY_TESTS_NO_JOBCTL="$3" startvt "$1" "$d" "$T"; waitfile "$d.mark" || echo "(suite never started)"
  kill -s TERM "$pid"; wait "$pid"; rc=$?; sleep 1
  if kill -0 "$(cat "$d.mark")" 2>/dev/null; then a=1; kill "$(cat "$d.mark")" 2>/dev/null; else a=0; fi
  cat "$d.so" >> "$tmp/allout"
  printf '%s:%s' "$rc" "$a"
}
chk "signals: TERM stops a process the suite started" "$(suitegone sh a '')|$(suitegone "$ALTSH" b '')" "2:0|2:0"
chk "signals: TERM stops a process the suite started, without job control" "$(suitegone sh c 1)|$(suitegone "$ALTSH" d 1)" "2:0|2:0"

# A cleanup hook that writes <dir>.clean and then sleeps keeps the trap busy while a second TERM arrives.
sig2() {
  local d="$tmp/s2$2" T="$tmp/Ts2$2" rc; mkdir -p "$T"; mksleepy "$d"
  VERIFY_TESTS_CLEANUP_HOOK="echo x > '$d.clean'; sleep 2" startvt "$1" "$d" "$T"
  waitfile "$d.mark" || echo "(suite never started)"
  kill -s TERM "$pid"; waitfile "$d.clean" || echo "(cleanup never started)"
  kill -s TERM "$pid"; wait "$pid"; rc=$?
  cat "$d.so" >> "$tmp/allout"
  printf '%s:%s:%s' "$rc" "$(wtcount "$d")" "$(tmpleft "$T")"
}
chk "signals: second signal during cleanup still exits 2" "$(sig2 sh a)|$(sig2 "$ALTSH" b)" "2:1:0|2:1:0"

d="$tmp/sk"; T="$tmp/Tsk"; mkdir -p "$T"; mksleepy "$d"
startvt sh "$d" "$T"; waitfile "$d.mark" || echo "(suite never started)"
kill -s KILL "$pid"; wait "$pid" 2>/dev/null
kill "$(cat "$d.mark")" 2>/dev/null; sleep 1
# Stand in for the OS temp reaper: delete what the killed run left under its TMPDIR.
for i in 1 2 3 4 5; do rm -rf "$T"/* 2>/dev/null; [ "$(tmpleft "$T")" = 0 ] && break; sleep 1; done
leak="$(wtcount "$d")"
rm -f "$d.flag"
r="$(TMPDIR="$T" sh "$SCRIPT" "$d/plan.md" T1 2>/dev/null)"; rc=$?
printf '%s\n' "$r" >> "$tmp/allout"
chk "signals: KILL leaves a registration the next run prunes" "$leak|$rc|$(wtcount "$d")" "3|0|1"

echo "cleanup"
mkrepo "$tmp/c1"; T="$tmp/Tc1"; mkdir -p "$T"
r="$(VERIFY_TESTS_CLEANUP_HOOK='git -C "$1" worktree lock "$2/after"' TMPDIR="$T" sh "$SCRIPT" "$tmp/c1/plan.md" T1 2>"$tmp/e")"; rc=$?
printf '%s\n' "$r" >> "$tmp/allout"
chk "cleanup: failed removal exits 2" "$rc|$(rg -c 'verify-tests: T1: cleanup failed' "$tmp/e")" "2|1"

# Every stdout line of every run above is a label line, a total line, or empty.
stray="$(rg -v '^((ok|ok-absent|not-red|not-green|ambiguous)\t|verify-tests: T1: \d+ ok, \d+ failed$|--- .* \((after|before)\)$|  \| |$)' "$tmp/allout")"
chk "trees: git stdout never reaches stdout" "$stray|$(rg -c 'HEAD is now at|Preparing worktree' "$tmp/allout")|$(rg -c '^verify-tests: T1: ' "$tmp/allout")" "||25"

echo "attributes"
chk "eol attribute is lf" "$(git -C "$REPO" check-attr eol -- skills/executing-dag-plans/verify-tests)" "skills/executing-dag-plans/verify-tests: eol: lf"
chk "script has no CR byte" "$(tr -d -c '\r' < "$SCRIPT" | wc -c | tr -d ' ')" "0"

echo "RESULT: $passes passed, $fails failed"
[ "$fails" -eq 0 ]

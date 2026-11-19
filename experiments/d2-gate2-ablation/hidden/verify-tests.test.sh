#!/usr/bin/env bash
# Acceptance suite (E3 named tests): skills/executing-dag-plans/verify-tests.
# Run from the root of a working copy: bash <this file>
# Case names start with the spec line they test
# (docs/superpowers/specs/2026-11-17-named-tests-design.md).
command -v rg >/dev/null 2>&1 || { echo "tests need rg (ripgrep)" >&2; exit 2; }
[ -f skills/writing-dag-plans/plan-state ] || { echo "run from the root of a working copy" >&2; exit 2; }
VT="skills/executing-dag-plans/verify-tests"

fails=0; passes=0
rgc()  { _n="$(rg -c "$@")"; echo "${_n:-0}"; }
ok()   { passes=$((passes+1)); echo "  PASS: $1"; }
bad()  { fails=$((fails+1));  echo "  FAIL: $1"; }
chk()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$3] got [$2])"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export GIT_CEILING_DIRECTORIES="$tmp"
T="$(printf '\t')"

newrepo() {
  mkdir -p "$1"; git -C "$1" init -q
  git -C "$1" config user.email t@t.test; git -C "$1" config user.name tester
  git -C "$1" config core.autocrlf false; git -C "$1" config commit.gpgsign false
  printf 'docs/\n' >> "$1/.git/info/exclude"   # the plan stays out of every commit
}
commit() { git -C "$1" add -A && git -C "$1" commit -qm "$2"; }

# vplan FILE BASE FILES-LINES TESTS-LINES [FRONTMATTER] [STATUS]
# One task T1. BASE empty means no base_sha: line. Line arguments end in newlines.
vplan() {
  mkdir -p "$(dirname "$1")"
  bl=""; [ -n "$2" ] && bl="base_sha: $2
"
  printf -- '---\ntitle: verify\n%s---\n\n```mermaid\nflowchart TD\n```\n\n## Tasks\n\n## Task: one\n\n```yaml\nid: T1\ndepends_on: []\nfiles:\n%s%s%sstatus: %s\n```\n\nBody.\n' \
    "${5:-}" "$3" "$4" "$bl" "${6:-running}" > "$1"
}

# scen NAME BEFORE AFTER [SUITE]
# Base commit: lib/out.txt = BEFORE. Task commit: adds tests/x.test.sh (SUITE, default
# "cat lib/out.txt") and sets lib/out.txt = AFTER. Plan at docs/plans/plan.md with
# base_sha = the base commit, files lib/out.txt and tests/x.test.sh, and the tests: lines
# in $TESTS (default: the one entry "tests/x.test.sh :: alpha"). Sets R, P, B.
scen() {
  R="$tmp/$1"; newrepo "$R"; mkdir -p "$R/lib" "$R/tests"
  wr "$2" "$R/lib/out.txt"; echo readme > "$R/README"; commit "$R" base
  B="$(git -C "$R" rev-parse HEAD)"
  printf '%s\n' "${4:-cat lib/out.txt}" > "$R/tests/x.test.sh"
  wr "$3" "$R/lib/out.txt"; commit "$R" task
  P="$R/docs/plans/plan.md"
  vplan "$P" "$B" '  - lib/out.txt
  - tests/x.test.sh
' "${TESTS:-tests:
  - tests/x.test.sh :: alpha
}" "${FM:-}" "${STATUS:-running}"
}
wr() { if [ -n "$1" ]; then printf '%s\n' "$1" > "$2"; else : > "$2"; fi; }
vt() { out="$(sh "$VT" "$@" 2>"$tmp/err" </dev/null)"; rc=$?; err="$(cat "$tmp/err")"; }
cnt() { printf '%s\n' "$1" | rgc -F -- "$2"; }
wtn() { git -C "$1" worktree list | wc -l | tr -d ' '; }

echo "U: usage and early exits"
sh "$VT" >"$tmp/o" 2>/dev/null </dev/null; rc=$?
chk "L209: no arguments exits 2 with nothing on stdout" "$rc|$(cat "$tmp/o")" "2|"
scen u1 'FAIL: alpha' 'PASS: alpha'
sh "$VT" "$P" >"$tmp/o" 2>/dev/null </dev/null; rc=$?
chk "L209: only the plan exits 2 with nothing on stdout" "$rc|$(cat "$tmp/o")" "2|"

vt "$P" ZZ
chk "L216: a plan-state tests error (unknown id) is relayed on stderr with exit 2" \
  "$rc|$out|$(cnt "$err" 'plan-state: no task with id ZZ')" "2||1"
vt "$tmp/nope.md" T1
chk "L216: a plan-state tests error (cannot read) is relayed with exit 2" \
  "$rc|$out|$(cnt "$err" "plan-state: cannot read $tmp/nope.md")" "2||1"
TESTS='tests:
  - tests/x.test.sh alpha
' scen u2 'FAIL: alpha' 'PASS: alpha'
vt "$P" T1
chk "L216: a bad tests entry is relayed with exit 2" \
  "$rc|$out|$(cnt "$err" 'plan-state: T1 has a bad tests entry; run: plan-state check')" "2||1"

TESTS='model_hint: cheap
' scen u3 'x' 'y'
vt "$P" T1
chk "L218: a task with no tests: prints the no-named-tests line and exits 0" "$rc|$out" "0|verify-tests: T1: no named tests"

vplan "$tmp/out-of-repo/plan.md" "" '  - lib/a.sh
' ''
vt "$tmp/out-of-repo/plan.md" T1
chk "L210: no tests, no base_sha, plan outside any repository: still exit 0 with the no-named-tests line" \
  "$rc|$out" "0|verify-tests: T1: no named tests"

scen u4 'FAIL: alpha' 'PASS: alpha'; vplan "$P" "" '  - lib/out.txt
  - tests/x.test.sh
' 'tests:
  - tests/x.test.sh :: alpha
'
vt "$P" T1
chk "L219: no base_sha: exit 2, the message on stderr, nothing on stdout" \
  "$rc|$out|$(cnt "$err" 'verify-tests: T1: no base_sha (set the task running first)')" "2||1"

scen u5 'FAIL: alpha' 'PASS: alpha'; sed -i "s/^base_sha: .*/base_sha: 1234567/" "$P"
vt "$P" T1
chk "L292: a base_sha that is not a commit exits 2 with nothing on stdout and leaves no worktree" \
  "$rc|$out|$(wtn "$R")" "2||1"

vplan "$tmp/out-of-repo2/plan.md" "0123456789abcdef0123456789abcdef01234567" '  - tests/x.test.sh
' 'tests:
  - tests/x.test.sh :: alpha
'
vt "$tmp/out-of-repo2/plan.md" T1
chk "L292: named tests in a plan outside any repository exit 2 with nothing on stdout" "$rc|$out" "2|"

echo
echo "L: labels, totals, tails"
scen l1 'FAIL: alpha (expected 1 got 2)' '  PASS: alpha'
vt "$P" T1
chk "L253: failed before (fail line with \" (\"), passed after: ok, exit 0, exact stdout" "$rc|$out" \
  "0|ok${T}tests/x.test.sh${T}alpha
verify-tests: T1: 1 ok, 0 failed"

STATUS=done scen l1b 'FAIL: alpha' 'PASS: alpha'
vt "$P" T1
chk "L217: an exact fail line counts as failed; a done task can be checked" "$rc|$out" \
  "0|ok${T}tests/x.test.sh${T}alpha
verify-tests: T1: 1 ok, 0 failed"

scen l2 'setup broke' 'PASS: alpha'
vt "$P" T1
chk "L254: absent before, passed after: ok-absent, exit 0, before block" "$rc|$out" \
  "0|ok-absent${T}tests/x.test.sh${T}alpha
verify-tests: T1: 1 ok, 0 failed
--- tests/x.test.sh (before)
  | setup broke"

scen l3 'PASS: alpha' 'PASS: alpha'
vt "$P" T1
chk "L255: passed before: not-red, exit 1, before block" "$rc|$out" \
  "1|not-red${T}tests/x.test.sh${T}alpha
verify-tests: T1: 0 ok, 1 failed
--- tests/x.test.sh (before)
  | PASS: alpha"

scen l4 'FAIL: alpha' 'FAIL: alpha (still)'
vt "$P" T1
chk "L256: failed after: not-green, exit 1, after block" "$rc|$out" \
  "1|not-green${T}tests/x.test.sh${T}alpha
verify-tests: T1: 0 ok, 1 failed
--- tests/x.test.sh (after)
  | FAIL: alpha (still)"

scen l5 'FAIL: alpha' 'nothing ran'
vt "$P" T1
chk "L239: absent after is not-green" "$rc|$out" \
  "1|not-green${T}tests/x.test.sh${T}alpha
verify-tests: T1: 0 ok, 1 failed
--- tests/x.test.sh (after)
  | nothing ran"

scen l6 'PASS: alpha' 'FAIL: alpha'
vt "$P" T1
chk "L271: not-red and not-green prints not-green and only an after block" "$rc|$out" \
  "1|not-green${T}tests/x.test.sh${T}alpha
verify-tests: T1: 0 ok, 1 failed
--- tests/x.test.sh (after)
  | FAIL: alpha"

scen l7 'FAIL: alpha' 'PASS: alpha
PASS: alpha'
vt "$P" T1
chk "L257: two result lines after: ambiguous, exit 1, after block" "$rc|$out" \
  "1|ambiguous${T}tests/x.test.sh${T}alpha
verify-tests: T1: 0 ok, 1 failed
--- tests/x.test.sh (after)
  | PASS: alpha
  | PASS: alpha"

scen l8 'PASS: alpha
FAIL: alpha (x)' 'PASS: alpha'
vt "$P" T1
chk "L238: ambiguous in the before tree only is ambiguous, with an after block (tails follow the label)" "$rc|$out" \
  "1|ambiguous${T}tests/x.test.sh${T}alpha
verify-tests: T1: 0 ok, 1 failed
--- tests/x.test.sh (after)
  | PASS: alpha"

scen l9 'FAIL: alpha
FAIL: alpha' 'FAIL: alpha'
vt "$P" T1
chk "L238: ambiguous wins over not-green" "$rc|${out%%$'\n'*}" "1|ambiguous${T}tests/x.test.sh${T}alpha"

scen l10 "$(i=1; while [ $i -le 25 ]; do echo "line $i"; i=$((i+1)); done)" 'PASS: alpha'
want="0|ok-absent${T}tests/x.test.sh${T}alpha
verify-tests: T1: 1 ok, 0 failed
--- tests/x.test.sh (before)"
i=6; while [ $i -le 25 ]; do want="$want
  | line $i"; i=$((i+1)); done
vt "$P" T1
chk "L266: a tail is the last 20 lines of the run's output" "$rc|$out" "$want"

scen l11 '' 'PASS: alpha'
vt "$P" T1
chk "L275: a run with no output shows (no output)" "$rc|$out" \
  "0|ok-absent${T}tests/x.test.sh${T}alpha
verify-tests: T1: 1 ok, 0 failed
--- tests/x.test.sh (before)
  | (no output)"

# Spec example: a.sh :: x absent before / passing after, b.sh :: y failing after.
R="$tmp/ex"; newrepo "$R"; mkdir -p "$R/lib" "$R/tests"
printf 'a-setup\n' > "$R/lib/a.out"; printf 'FAIL: y\n' > "$R/lib/b.out"; commit "$R" base; B="$(git -C "$R" rev-parse HEAD)"
echo 'cat lib/a.out' > "$R/tests/a.sh"; echo 'cat lib/b.out' > "$R/tests/b.sh"
printf 'PASS: x\n' > "$R/lib/a.out"; printf 'FAIL: y (no)\n' > "$R/lib/b.out"; commit "$R" task
P="$R/docs/plan.md"
vplan "$P" "$B" '  - lib/a.out
  - lib/b.out
  - tests/a.sh
  - tests/b.sh
' 'tests:
  - tests/a.sh :: x
  - tests/b.sh :: y
'
vt "$P" T1
chk "L277: the spec's own example" "$rc|$out" \
  "1|ok-absent${T}tests/a.sh${T}x
not-green${T}tests/b.sh${T}y
verify-tests: T1: 1 ok, 1 failed
--- tests/a.sh (before)
  | a-setup
--- tests/b.sh (after)
  | FAIL: y (no)"

# Tail order: files in order of first appearance; per file the after block, then the before block.
R="$tmp/ord"; newrepo "$R"; mkdir -p "$R/lib" "$R/tests"
printf 'a-setup\n' > "$R/lib/a.out"; printf 'b-old\nPASS: z\n' > "$R/lib/b.out"; commit "$R" base; B="$(git -C "$R" rev-parse HEAD)"
echo 'cat lib/a.out' > "$R/tests/a.sh"; echo 'cat lib/b.out' > "$R/tests/b.sh"
printf 'PASS: x\n' > "$R/lib/a.out"; printf 'FAIL: y\nPASS: z\n' > "$R/lib/b.out"; commit "$R" task
P="$R/docs/plan.md"
vplan "$P" "$B" '  - lib/a.out
  - lib/b.out
  - tests/a.sh
  - tests/b.sh
' 'tests:
  - tests/b.sh :: y
  - ./tests/a.sh :: x
  - tests/b.sh :: z
'
vt "$P" T1
chk "L273: entries in tests: order; tails by first appearance, after block before before block" "$rc|$out" \
  "1|not-green${T}tests/b.sh${T}y
ok-absent${T}tests/a.sh${T}x
not-red${T}tests/b.sh${T}z
verify-tests: T1: 1 ok, 2 failed
--- tests/b.sh (after)
  | FAIL: y
  | PASS: z
--- tests/b.sh (before)
  | b-old
  | PASS: z
--- tests/a.sh (before)
  | a-setup"

echo
echo "M: matching output lines"
TESTS='tests:
  - tests/x.test.sh :: exit 0
  - tests/x.test.sh :: exit 0 with charter
' scen m1 'FAIL: exit 0 (expected 0 got 1)
FAIL: exit 0 with charter (expected x)' 'PASS: exit 0
PASS: exit 0 with charter'
vt "$P" T1
chk "L116: \"exit 0\" and \"exit 0 with charter\" are told apart" "$rc|$out" \
  "0|ok${T}tests/x.test.sh${T}exit 0
ok${T}tests/x.test.sh${T}exit 0 with charter
verify-tests: T1: 2 ok, 0 failed"

scen m2 'FAIL: alphabet
FAIL: alpha(x)' 'PASS: alpha'
vt "$P" T1
chk "L115: \"FAIL: alphabet\" and \"FAIL: alpha(x)\" are not fail lines for alpha" "$rc|${out%%$'\n'*}" "0|ok-absent${T}tests/x.test.sh${T}alpha"

scen m3 'FAIL: alpha' 'PASS: alpha (slow)'
vt "$P" T1
chk "L113: a pass line must equal the prefix and the case exactly" "$rc|${out%%$'\n'*}" "1|not-green${T}tests/x.test.sh${T}alpha"

scen m4 'FAIL: alpha' "$(printf '\t  PASS: alpha  \r')"
vt "$P" T1
chk "L111: leading whitespace, trailing whitespace and a trailing CR are removed before matching" "$rc|$out" \
  "0|ok${T}tests/x.test.sh${T}alpha
verify-tests: T1: 1 ok, 0 failed"

scen m5 'FAIL: alpha' 'PASS: alpha' 'cat lib/out.txt >&2; exit 3'
vt "$P" T1
chk "L232: standard error is captured, and the suite's exit code is ignored" "$rc|$out" \
  "0|ok${T}tests/x.test.sh${T}alpha
verify-tests: T1: 1 ok, 0 failed"

FM='test_pass_prefix: "ok "
test_fail_prefix: "not ok "
' TESTS='tests:
  - tests/x.test.sh :: alpha
  - tests/x.test.sh :: beta
' scen m6 'not ok alpha
FAIL: beta' 'ok alpha
PASS: beta'
vt "$P" T1
chk "L99: custom prefixes replace the defaults" "$rc|$out" \
  "1|ok${T}tests/x.test.sh${T}alpha
not-green${T}tests/x.test.sh${T}beta
verify-tests: T1: 1 ok, 1 failed
--- tests/x.test.sh (after)
  | ok alpha
  | PASS: beta"

echo
echo "C: test_command and how the suite runs"
R="$tmp/c1"; newrepo "$R"; mkdir -p "$R/lib" "$R/tests"
printf 'FAIL: alpha\n' > "$R/lib/out.txt"; commit "$R" base; B="$(git -C "$R" rev-parse HEAD)"
printf '%s\n' '[ "$0|$1" = "tests/my suite.test.sh|tests/my suite.test.sh" ] || { echo "FAIL: alpha (args $0|$1)"; exit 0; }' 'cat lib/out.txt' > "$R/tests/my suite.test.sh"
printf 'PASS: alpha\n' > "$R/lib/out.txt"; commit "$R" task
P="$R/docs/plan.md"
vplan "$P" "$B" '  - lib/out.txt
  - tests/my suite.test.sh
' 'tests:
  - tests/my suite.test.sh :: alpha
' 'test_command: sh {file} {file}
'
vt "$P" T1
chk "L105: every {file} is replaced by the single-quoted <file>" "$rc|$out" \
  "0|ok${T}tests/my suite.test.sh${T}alpha
verify-tests: T1: 1 ok, 0 failed"

scen c2 'FAIL: alpha' 'PASS: alpha' 'if read -r l; then echo "FAIL: alpha (stdin gave $l)"; else cat lib/out.txt; fi'
printf 'data\n' > "$tmp/stdin"
out="$(sh "$VT" "$P" T1 2>/dev/null <"$tmp/stdin")"; rc=$?
chk "L106: the suite's standard input is /dev/null" "$rc|${out%%$'\n'*}" "0|ok${T}tests/x.test.sh${T}alpha"

TESTS='tests:
  - tests/x.test.sh :: alpha
  - tests/x.test.sh :: beta
' scen c3 'FAIL: alpha
FAIL: beta' 'PASS: alpha
PASS: beta' "echo run >> '$tmp/runs.log'; cat lib/out.txt"
rm -f "$tmp/runs.log"
vt "$P" T1
chk "L232: each distinct file runs once per tree" "$rc|$(wc -l < "$tmp/runs.log" | tr -d ' ')" "0|2"

echo
echo "W: the trees"
R="$tmp/w1"; newrepo "$R"; mkdir -p "$R/lib" "$R/tests"; echo old > "$R/other.txt"
echo old > "$R/lib/mine.txt"; commit "$R" base; B="$(git -C "$R" rev-parse HEAD)"
echo new > "$R/other.txt"; commit "$R" "someone else"
echo new > "$R/lib/mine.txt"; echo new > "$R/lib/added.txt"
cat > "$R/tests/x.test.sh" <<'EOF'
[ "$(cat other.txt)" = new ] || { echo "other.txt is old"; exit 0; }
if [ "$(cat lib/mine.txt)" = new ]; then echo "PASS: mine"; else echo "FAIL: mine (old)"; fi
if [ -e lib/added.txt ]; then echo "PASS: added"; else echo "FAIL: added (missing)"; fi
EOF
commit "$R" task
P="$R/docs/plan.md"
vplan "$P" "$B" '  - ./lib/mine.txt
  - lib/added.txt
  - tests/x.test.sh
' 'tests:
  - tests/x.test.sh :: mine
  - tests/x.test.sh :: added
'
vt "$P" T1
chk "L228: before tree: task files back at base_sha, new ones deleted, test file and others' work kept" "$rc|$out" \
  "0|ok${T}tests/x.test.sh${T}mine
ok${T}tests/x.test.sh${T}added
verify-tests: T1: 2 ok, 0 failed"

scen w2 'FAIL: alpha' 'FAIL: alpha'
echo 'PASS: alpha' > "$R/lib/out.txt"; echo 'staged' > "$R/README"; git -C "$R" add README
snap() { git -C "$R" status --porcelain=v1 -uall; git -C "$R" rev-parse HEAD; git -C "$R" for-each-ref; git -C "$R" diff --cached; git -C "$R" diff; cksum < "$P"; }
s0="$(snap)"
vt "$P" T1
chk "L226: uncommitted changes in the shared working tree are ignored" "$rc|${out%%$'\n'*}" "1|not-green${T}tests/x.test.sh${T}alpha"
chk "L300: the plan, working tree, index, HEAD and refs are untouched" "$rc|$(snap)" "1|$s0"

R="$tmp/w3"; newrepo "$R"; mkdir -p "$R/lib" "$R/tests"; echo base > "$R/lib/out.txt"; commit "$R" base; B="$(git -C "$R" rev-parse HEAD)"
echo x > "$R/lib/out.txt"; commit "$R" task
P="$R/docs/plan.md"
vplan "$P" "$B" '  - lib/out.txt
  - tests/gone.test.sh
' 'tests:
  - tests/gone.test.sh :: alpha
'
vt "$P" T1
chk "L233: a file missing from a tree counts as a run with no output" "$rc|$out" \
  "1|not-green${T}tests/gone.test.sh${T}alpha
verify-tests: T1: 0 ok, 1 failed
--- tests/gone.test.sh (after)
  | (no output)"

scen w4 'FAIL: alpha' 'PASS: alpha'
sed -i "s/^base_sha: \(.\{12\}\).*/base_sha: \1/" "$P"
vt "$P" T1
chk "L148: an abbreviated base_sha (12 hex) is resolved" "$rc|$out" \
  "0|ok${T}tests/x.test.sh${T}alpha
verify-tests: T1: 1 ok, 0 failed"

echo
echo "K: cleanup"
mp() { p="$1"; command -v cygpath >/dev/null 2>&1 && p="$(cygpath -m "$p")"; printf '%s\n' "$p"; }
mkdir -p "$tmp/td"; TD="$(cd "$tmp/td" && pwd -P)"
scen k1 'FAIL: alpha' 'PASS: alpha' "pwd -P >> '$tmp/pwd.log'; cat lib/out.txt"
git -C "$R" worktree add -q --detach "$tmp/stale" HEAD 2>/dev/null; rm -rf "$tmp/stale"
out="$(TMPDIR="$tmp/td" sh "$VT" "$P" T1 2>/dev/null </dev/null)"; rc=$?
inside=0; total=0
while IFS= read -r d; do total=$((total+1)); case "$(mp "$d")" in "$(mp "$TD")"/*) inside=$((inside+1)) ;; esac; done < "$tmp/pwd.log"
chk "L225: both trees are made under \$TMPDIR" "$rc|$total|$inside" "0|2|2"
chk "L246: after exit 0, no worktree is left and stale registrations are pruned" "$(wtn "$R")" "1"
chk "L246: the temporary directory is removed" "$rc|$(find "$tmp/td" -mindepth 1 -type d | wc -l | tr -d ' ')" "0|0"

scen k2 'PASS: alpha' 'FAIL: alpha'
out="$(TMPDIR="$tmp/td" sh "$VT" "$P" T1 2>/dev/null </dev/null)"; rc=$?
chk "L246: after exit 1, no worktree and no temporary directory is left" \
  "$rc|$(wtn "$R")|$(find "$tmp/td" -mindepth 1 -type d | wc -l | tr -d ' ')" "1|1|0"

for sig in TERM HUP; do
  rm -f "$tmp/mark"
  scen "k-$sig" 'FAIL: alpha' 'PASS: alpha' ": > '$tmp/mark'; sleep 3; cat lib/out.txt"
  TMPDIR="$tmp/td" sh "$VT" "$P" T1 >"$tmp/io.out" 2>"$tmp/io.err" </dev/null &
  pid=$!
  i=0; while [ ! -e "$tmp/mark" ] && [ $i -lt 120 ] && kill -0 "$pid" 2>/dev/null; do sleep 1; i=$((i+1)); done
  kill -s "$sig" "$pid" 2>/dev/null
  wait "$pid"; rc=$?
  chk "L222: $sig during a run exits 2 with the interrupted line, and cleans up" \
    "$rc|$(cnt "$(cat "$tmp/io.err")" 'verify-tests: T1: interrupted')|$(wtn "$R")|$(find "$tmp/td" -mindepth 1 -type d | wc -l | tr -d ' ')" "2|1|1|0"
done

echo
echo "RESULT: $passes passed, $fails failed"
[ "$fails" -eq 0 ]

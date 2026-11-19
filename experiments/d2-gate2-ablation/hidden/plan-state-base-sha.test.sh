#!/usr/bin/env bash
# Acceptance suite (E3 named tests): `plan-state set <plan> <id> running` and base_sha.
# Run from the root of a working copy: bash <this file>
# Case names start with the spec line they test
# (docs/superpowers/specs/2026-11-17-named-tests-design.md).
command -v rg >/dev/null 2>&1 || { echo "tests need rg (ripgrep)" >&2; exit 2; }
PS="skills/writing-dag-plans/plan-state"
[ -f "$PS" ] || { echo "run from the root of a working copy ($PS not found)" >&2; exit 2; }

fails=0; passes=0
ok()   { passes=$((passes+1)); echo "  PASS: $1"; }
bad()  { fails=$((fails+1));  echo "  FAIL: $1"; }
chk()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$3] got [$2])"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
# Keep git from finding a repository above the fixtures (the "no repository" cases).
export GIT_CEILING_DIRECTORIES="$tmp"
ps() { sh "$PS" "$@"; }

newrepo() {
  mkdir -p "$1"; git -C "$1" init -q
  git -C "$1" config user.email t@t.test; git -C "$1" config user.name tester
  git -C "$1" config core.autocrlf false; git -C "$1" config commit.gpgsign false
  printf 'docs/\n' >> "$1/.git/info/exclude"
}
commit() { echo "$2" > "$1/f.txt"; git -C "$1" add -A && git -C "$1" commit -qm "$2"; }

# mkplan FILE STATUS EXTRA: one task T1 with status STATUS; EXTRA is extra yaml lines
# (each ending in a newline) put before status:.
mkplan() {
  mkdir -p "$(dirname "$1")"
  printf -- '---\ntitle: base sha\n---\n\n```mermaid\nflowchart TD\n```\n\n## Tasks\n\n## Task: one\n\n```yaml\nid: T1\ndepends_on: []\nfiles:\n  - lib/a.sh\n  - tests/a.test.sh\n%sstatus: %s\n```\n\nBody.\n' "$3" "$2" > "$1"
}
TESTS='tests:
  - tests/a.test.sh :: alpha
'
after_status() { awk 'p { print; exit } /^status:/ { p = 1 }' "$1"; }
nbase() { n="$(rg -c "^base_sha:" "$1")"; echo "${n:-0}"; }
run() { out="$(ps "$@" 2>"$tmp/err")"; rc=$?; err="$(cat "$tmp/err")"; }

R="$tmp/repo"; newrepo "$R"; commit "$R" one
H1="$(git -C "$R" rev-parse HEAD)"

echo "S1: set running writes base_sha"
P="$R/docs/plans/p1.md"; mkplan "$P" ready "$TESTS"
run set "$P" T1 running
chk "L153: ready -> running exits 0 and writes base_sha: <full HEAD of the plan's repo> on the line after status:" \
  "$rc|$(rg -c '^status: running$' "$P")|$(after_status "$P")|$(nbase "$P")" "0|1|base_sha: $H1|1"

P="$R/docs/plans/p2.md"; mkplan "$P" ready ""
run set "$P" T1 running
chk "L375: a task without tests: also gets base_sha when it runs" \
  "$rc|$(after_status "$P")" "0|base_sha: $H1"

echo
echo "S2: written once, kept through later moves"
P="$R/docs/plans/p3.md"; mkplan "$P" ready "$TESTS"
ps set "$P" T1 running >/dev/null 2>&1
commit "$R" two; H2="$(git -C "$R" rev-parse HEAD)"
ps set "$P" T1 ready >/dev/null 2>&1; r1=$?
ps set "$P" T1 running >/dev/null 2>&1; r2=$?
chk "L90: running -> ready -> running after a new commit keeps the first base_sha" \
  "$r1|$r2|$(nbase "$P")|$(rg '^base_sha:' "$P")" "0|0|1|base_sha: $H1"
ps set "$P" T1 done >/dev/null 2>&1; r3=$?
chk "L163: running -> done keeps base_sha" "$r3|$(rg -c '^status: done$' "$P")|$(rg '^base_sha:' "$P")" "0|1|base_sha: $H1"

P="$R/docs/plans/p4.md"; mkplan "$P" ready "$TESTS"
ps set "$P" T1 running >/dev/null 2>&1
ps set "$P" T1 failed >/dev/null 2>&1; r1=$?
chk "L163: running -> failed keeps base_sha" "$r1|$(rg '^base_sha:' "$P")" "0|base_sha: $H2"

P="$R/docs/plans/p5.md"; mkplan "$P" ready "base_sha: abcdef1
$TESTS"
run set "$P" T1 running
chk "L157: an existing base_sha is left untouched" "$rc|$(nbase "$P")|$(rg '^base_sha:' "$P")" "0|1|base_sha: abcdef1"

P="$R/docs/plans/p6.md"; mkplan "$P" pending "$TESTS"
run set "$P" T1 ready
chk "L163: pending -> ready writes no base_sha" "$rc|$(nbase "$P")" "0|0"

P="$R/docs/plans/p7.md"; mkplan "$P" pending "$TESTS"; before="$(cksum < "$P")"
run set "$P" T1 running
chk "L156: an illegal move (pending -> running) is refused as today, the plan unchanged" \
  "$rc|$(cksum < "$P")" "2|$before"

echo
echo "S3: git fails"
P="$tmp/norepo/p.md"; mkplan "$P" ready "$TESTS"; before="$(cksum < "$P")"
if git -C "$tmp/norepo" rev-parse HEAD >/dev/null 2>&1; then echo "NOTE: $tmp/norepo is inside a repository; S3 cases are not meaningful"; fi
run set "$P" T1 running
chk "L159: no repository, task with tests: exit 2 with the refusal, plan unchanged" \
  "$rc|$(printf '%s\n' "$err" | rg -cF 'plan-state: refused T1: cannot read HEAD for base_sha')|$(cksum < "$P")" "2|1|$before"

E="$tmp/empty"; newrepo "$E"
P="$E/docs/p.md"; mkplan "$P" ready "$TESTS"; before="$(cksum < "$P")"
run set "$P" T1 running
chk "L159: a repository with no commit, task with tests: exit 2 with the refusal, plan unchanged" \
  "$rc|$(printf '%s\n' "$err" | rg -cF 'plan-state: refused T1: cannot read HEAD for base_sha')|$(cksum < "$P")" "2|1|$before"

P="$tmp/norepo/q.md"; mkplan "$P" ready ""
run set "$P" T1 running
chk "L161: no repository, task without tests: set running, no base_sha, no message" \
  "$rc|$out|$err|$(rg -c '^status: running$' "$P")|$(nbase "$P")" "0|||1|0"

P="$tmp/norepo/r.md"; mkplan "$P" ready "base_sha: abcdef1
$TESTS"
run set "$P" T1 running
chk "L157: a task that already has base_sha does not call git: set running succeeds outside a repository" \
  "$rc|$(rg -c '^status: running$' "$P")|$(rg '^base_sha:' "$P")" "0|1|base_sha: abcdef1"

echo
echo "RESULT: $passes passed, $fails failed"
[ "$fails" -eq 0 ]

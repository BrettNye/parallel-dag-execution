#!/usr/bin/env bash
# Acceptance suite (E3 named tests): rules 16 and 17 in `plan-state check`,
# the new `plan-state tests <plan> <id>` subcommand, and the usage header.
# Run from the root of a working copy: bash <this file>
# Case names start with the spec line they test
# (docs/superpowers/specs/2026-11-17-named-tests-design.md).
command -v rg >/dev/null 2>&1 || { echo "tests need rg (ripgrep)" >&2; exit 2; }
PS="skills/writing-dag-plans/plan-state"
[ -f "$PS" ] || { echo "run from the root of a working copy ($PS not found)" >&2; exit 2; }

fails=0; passes=0
rgc()  { _n="$(rg -c "$@")"; echo "${_n:-0}"; }
ok()   { passes=$((passes+1)); echo "  PASS: $1"; }
bad()  { fails=$((fails+1));  echo "  FAIL: $1"; }
chk()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$3] got [$2])"; fi; }
has()  { if printf '%s\n' "$2" | rg -qF -- "$3"; then ok "$1"; else bad "$1 (missing [$3] in: $2)"; fi; }
hasnt(){ if printf '%s\n' "$2" | rg -qF -- "$3"; then bad "$1 (unexpected [$3] in: $2)"; else ok "$1"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
ps() { sh "$PS" "$@"; }
TAB="$(printf '\t')"
# Expected lines that end in a space, kept in quotes so no editor trims them.
PL="pass PASS: "; FL="fail FAIL: "; PL2="pass ok "; FL2="fail not ok "

# mkplan FILE FRONTMATTER-EXTRA YAML...: a plan with one "## Task:" section per YAML block.
# FRONTMATTER-EXTRA is inserted verbatim (give it a trailing newline, or pass "").
mkplan() {
  f="$1"; fm="$2"; shift 2
  {
    printf -- '---\ntitle: named tests\n%s---\n\n```mermaid\nflowchart TD\n```\n\n## Tasks\n\n' "$fm"
    n=0
    for y in "$@"; do n=$((n+1)); printf '## Task: task %s\n\n```yaml\n%s\n```\n\nBody.\n\n' "$n" "$y"; done
  } > "$f"
}
# A task T1 that owns lib/a.sh and tests/a.test.sh; $1 is its tests: block (or "").
t1() {
  printf 'id: T1\ndepends_on: []\nfiles:\n  - lib/a.sh\n  - tests/a.test.sh\n%sstatus: pending' "$1"
}
# Run plan-state, splitting stdout and stderr: sets out, err, rc.
run() { out="$(ps "$@" 2>"$tmp/err")"; rc=$?; err="$(cat "$tmp/err")"; }

echo "R16: rule 16 in plan-state check"

mkplan "$tmp/ok.md" "" "$(t1 'tests:
  - tests/a.test.sh :: alpha
  - ./tests/a.test.sh :: beta, gamma
')"
run check "$tmp/ok.md"
chk "L130: a plan with well-formed tests: entries passes check" "$rc|$out" "0|"

mkplan "$tmp/r1.md" "" "$(t1 'tests:
  - tests/a.test.sh alpha
')"
run check "$tmp/r1.md"
chk "L132: an entry with no \" :: \" exits 1 with its rule 16 line" "$rc|$out" \
  '1|plan-state: rule 16: T1 tests entry "tests/a.test.sh alpha" is not "<file> :: <case>"'

mkplan "$tmp/r2.md" "" "$(t1 "$(printf 'tests:\n  - tests/a.test.sh ::   \t')
")"
run check "$tmp/r2.md"
chk "L75: an entry ending in \" ::\" plus spaces has no case; the raw entry is quoted without trailing whitespace" "$rc|$out" \
  '1|plan-state: rule 16: T1 tests entry "tests/a.test.sh ::" is not "<file> :: <case>"'

mkplan "$tmp/r3.md" "" "$(t1 'tests:
  - ./ :: alpha
')"
run check "$tmp/r3.md"
chk "L80: a file that is only ./ is empty after normalisation" "$rc|$out" \
  '1|plan-state: rule 16: T1 tests entry "./ :: alpha" is not "<file> :: <case>"'

mkplan "$tmp/r4.md" "" "$(t1 'tests:
  - ./tests/b.test.sh :: alpha
')"
run check "$tmp/r4.md"
chk "L134: a test file not in files: is named, normalised" "$rc|$out" \
  '1|plan-state: rule 16: T1 test file tests/b.test.sh is not in its files:'

mkplan "$tmp/r5.md" "" "$(printf 'id: T1\ndepends_on: []\nfiles: [lib/a.sh, ./tests/a.test.sh]\ntests:\n  - ././tests/a.test.sh :: alpha\nstatus: pending')"
run check "$tmp/r5.md"
chk "L80: leading ./ removed from both the entry and an inline files: list before comparing" "$rc|$out" "0|"

mkplan "$tmp/r6.md" "" "$(t1 'tests:
  - tests/a.test.sh # note :: alpha
')"
run check "$tmp/r6.md"
chk "L76: \" #\" in an entry is literal text, not a comment" "$rc|$out" \
  '1|plan-state: rule 16: T1 test file tests/a.test.sh # note is not in its files:'

mkplan "$tmp/r7.md" "" "$(t1 'tests:
  - "tests/a.test.sh :: alpha"
')"
run check "$tmp/r7.md"
chk "L77: quotes around an entry are not stripped" "$rc|$out" \
  '1|plan-state: rule 16: T1 test file "tests/a.test.sh is not in its files:'

mkplan "$tmp/r8.md" "" "$(t1 'tests:
  - tests/a.test.sh :: alpha
  - ./tests/a.test.sh  ::  alpha
')"
run check "$tmp/r8.md"
chk "L137: an entry the same as an earlier one after normalisation is repeated (raw entry quoted)" "$rc|$out" \
  '1|plan-state: rule 16: T1 tests entry "./tests/a.test.sh  ::  alpha" is repeated'

mkplan "$tmp/r9.md" "" "$(t1 'tests:
  - tests/a.test.sh :: alpha
  - tests/a.test.sh :: alpha
  - tests/a.test.sh :: alpha
')"
run check "$tmp/r9.md"
chk "L137: one repeated line per repeat" "$rc|$(printf '%s\n' "$out" | rgc 'is repeated')" "1|2"

mkplan "$tmp/r10.md" "" "$(t1 'tests: [tests/a.test.sh :: alpha]
')"
run check "$tmp/r10.md"
chk "L139: an inline list on the tests: line is a rule 16 violation" "$rc|$out" \
  '1|plan-state: rule 16: T1 tests must be a block list'

mkplan "$tmp/r11.md" "" "$(t1 'tests: tests/a.test.sh :: alpha
')"
run check "$tmp/r11.md"
chk "L71: a scalar on the tests: line is a rule 16 violation" "$rc|$out" \
  '1|plan-state: rule 16: T1 tests must be a block list'

mkplan "$tmp/r12.md" "" "$(t1 'tests:   # the cases
  - tests/a.test.sh :: alpha
')"
run check "$tmp/r12.md"
chk "L73: a trailing comment on the tests: line is not a value" "$rc|$out" "0|"

mkplan "$tmp/r13.md" "" "$(t1 '')" "$(printf 'id: T2\ndepends_on: [T1]\nfiles:\n  - lib/b.sh\ntests:\n  - lib/b.sh\nstatus: pending')"
run check "$tmp/r13.md"
chk "L130: a violation in a second task names that task" "$rc|$out" \
  '1|plan-state: rule 16: T2 tests entry "lib/b.sh" is not "<file> :: <case>"'

mkplan "$tmp/r14.md" 'test_command: bash run.sh   # no placeholder
' "$(t1 '')"
run check "$tmp/r14.md"
chk "L140: test_command with no {file}" "$rc|$out" '1|plan-state: rule 16: test_command has no {file}'

mkplan "$tmp/r15.md" 'test_pass_prefix: ""
' "$(t1 '')"
run check "$tmp/r15.md"
chk "L142: an empty test_pass_prefix" "$rc|$out" '1|plan-state: rule 16: test_pass_prefix is empty'

mkplan "$tmp/r16.md" 'test_fail_prefix:    # none
' "$(t1 '')"
run check "$tmp/r16.md"
chk "L142: a test_fail_prefix that is empty after comment-stripping" "$rc|$out" '1|plan-state: rule 16: test_fail_prefix is empty'

mkplan "$tmp/r17.md" 'test_command: sh {file} -v
test_pass_prefix: "ok "
test_fail_prefix: '"'"'not ok '"'"'
' "$(t1 'tests:
  - tests/a.test.sh :: alpha
')"
run check "$tmp/r17.md"
chk "L98: well-formed plan-level test fields pass check" "$rc|$out" "0|"

echo
echo "R17: base_sha"
for v in abc1234 0123456789abcdef0123456789abcdef01234567; do
  mkplan "$tmp/s.md" "" "$(printf 'id: T1\ndepends_on: []\nfiles: [lib/a.sh]\nbase_sha: %s\nstatus: running' "$v")"
  run check "$tmp/s.md"
  chk "L148: base_sha $v (7 or 40 lowercase hex) passes" "$rc|$out" "0|"
done
for v in abc123 ABCDEF1 abcdefg 0123456789abcdef0123456789abcdef012345678; do
  mkplan "$tmp/s.md" "" "$(printf 'id: T1\ndepends_on: []\nfiles: [lib/a.sh]\nbase_sha: %s\nstatus: running' "$v")"
  run check "$tmp/s.md"
  chk "L148: base_sha $v is a rule 17 violation" "$rc|$out" "1|plan-state: rule 17: T1 base_sha is $v"
done

echo
echo "TS: plan-state tests output"

mkplan "$tmp/t1.md" "" "$(printf 'id: T1\ndepends_on: []\nfiles:\n  - lib/a.sh   # the code\n  - "./tests/a.test.sh"\ntests:\n  - tests/a.test.sh :: alpha\n  - ././tests/a.test.sh   ::   beta, gamma # delta  \n  - tests/a.test.sh :: x :: y\nstatus: pending')"
run tests "$tmp/t1.md" T1
want="base -
command bash {file}
${PL}
${FL}
file lib/a.sh
file tests/a.test.sh
test tests/a.test.sh${TAB}alpha
test tests/a.test.sh${TAB}beta, gamma # delta
test tests/a.test.sh${TAB}x :: y"
chk "L168: defaults applied, files and entries normalised, exact stdout, exit 0" "$rc|$out" "0|$want"

mkplan "$tmp/t2.md" 'test_command: sh {file} --quiet   # run it
test_pass_prefix: "ok "  # tap
test_fail_prefix: '"'"'not ok '"'"'
' "$(printf 'id: T1\ndepends_on: []\nfiles: [lib/a.sh, "tests/a.test.sh"]\ntests:\n  - tests/a.test.sh :: alpha\nbase_sha: 0123456789abcdef0123456789abcdef01234567\nstatus: done')"
run tests "$tmp/t2.md" T1
want="base 0123456789abcdef0123456789abcdef01234567
command sh {file} --quiet
${PL2}
${FL2}
file lib/a.sh
file tests/a.test.sh
test tests/a.test.sh${TAB}alpha"
chk "L177: plan-level values comment-stripped and unquoted, inline files: split, base_sha shown" "$rc|$out" "0|$want"

mkplan "$tmp/t3.md" "" "$(printf 'id: T1\ndepends_on: []\nfiles: []\nsingle_threaded: true\nstatus: ready')"
run tests "$tmp/t3.md" T1
chk "L181: a task with no files and no tests prints only the four header lines" "$rc|$out" "0|base -
command bash {file}
${PL}
${FL}"

mkplan "$tmp/t4.lf" "" "$(t1 'tests:
  - tests/a.test.sh :: alpha
')"
sed 's/$/\r/' "$tmp/t4.lf" > "$tmp/t4.md"
run tests "$tmp/t4.md" T1
chk "L75: a CRLF plan gives the same output with no CR" "$rc|$out" "0|base -
command bash {file}
${PL}
${FL}
file lib/a.sh
file tests/a.test.sh
test tests/a.test.sh${TAB}alpha"

mkplan "$tmp/t5.md" "" "$(t1 '')" "$(printf 'id: T2\ndepends_on: [T1]\nfiles:\n  - lib/b.sh\ntests:\n  - lib/b.sh\n  - tests/zz.sh :: q\nstatus: pending')"
run tests "$tmp/t5.md" T1
chk "L199: other tasks' bad entries do not affect this task" "$rc|$out" "0|base -
command bash {file}
${PL}
${FL}
file lib/a.sh
file tests/a.test.sh"

echo
echo "TE: plan-state tests exit 2"

run tests
chk "L189: only the subcommand: exit 2, nothing on stdout, usage text on stderr" \
  "$rc|$out|$(printf '%s\n' "$err" | rgc 'rules 1-5 and 7-17')" "2||1"

run tests "$tmp/nope.md"
chk "L191: an unreadable plan is reported before the missing id" \
  "$rc|$out|$(printf '%s\n' "$err" | rgc -F "plan-state: cannot read $tmp/nope.md")|$(printf '%s\n' "$err" | rgc 'rules 1-5')" "2||1|0"

mkdir "$tmp/adir"
run tests "$tmp/adir" T1
chk "L191: a directory as the plan: exit 2, nothing on stdout, cannot read" \
  "$rc|$out|$(printf '%s\n' "$err" | rgc -F "plan-state: cannot read $tmp/adir")" "2||1"

run tests "$tmp/ok.md"
chk "L192: no id: exit 2, nothing on stdout, usage text on stderr" \
  "$rc|$out|$(printf '%s\n' "$err" | rgc 'rules 1-5 and 7-17')" "2||1"

run tests "$tmp/ok.md" T1 T1
chk "L192: two ids: exit 2, nothing on stdout, usage text on stderr" \
  "$rc|$out|$(printf '%s\n' "$err" | rgc 'rules 1-5 and 7-17')" "2||1"

run tests "$tmp/ok.md" ZZ
chk "L193: an unknown id" "$rc|$out|$(printf '%s\n' "$err" | rgc -F 'plan-state: no task with id ZZ')" "2||1"

mkplan "$tmp/dup.md" "" "$(t1 '')" "$(t1 '')"
run tests "$tmp/dup.md" T1
chk "L194: a duplicate id" "$rc|$out|$(printf '%s\n' "$err" | rgc -F 'plan-state: id T1 is not unique; run: plan-state check')" "2||1"

mkplan "$tmp/e5.md" 'test_command: bash run.sh
test_pass_prefix: ""
test_fail_prefix: ""
' "$(t1 'tests:
  - tests/a.test.sh
')"
run tests "$tmp/e5.md" ZZ
chk "L188: an unknown id is the only group reported, ahead of plan-level rule 16" \
  "$rc|$out|$(printf '%s\n' "$err" | rgc -F 'no task with id ZZ')|$(printf '%s\n' "$err" | rgc 'rule 16')" "2||1|0"

run tests "$tmp/e5.md" T1
chk "L196: every failing plan-level rule 16 line, in rule 16's order, and no task-level line" \
  "$rc|$out|$(printf '%s\n' "$err" | rg '^plan-state: rule 16:')|$(printf '%s\n' "$err" | rgc 'bad tests entry')" \
  "2||plan-state: rule 16: test_command has no {file}
plan-state: rule 16: test_pass_prefix is empty
plan-state: rule 16: test_fail_prefix is empty|0"

mkplan "$tmp/e5b.md" 'test_fail_prefix: ""
' "$(t1 '')"
run tests "$tmp/e5b.md" T1
chk "L196: a single plan-level failure is reported exactly as check prints it" \
  "$rc|$out|$(printf '%s\n' "$err" | rg '^plan-state: rule 16:')" "2||plan-state: rule 16: test_fail_prefix is empty"

BADLINE='plan-state: T1 has a bad tests entry; run: plan-state check'
k=0
for blk in 'tests:
  - tests/a.test.sh alpha
' 'tests:
  - tests/b.test.sh :: alpha
' 'tests:
  - tests/a.test.sh :: alpha
  - ./tests/a.test.sh :: alpha
' 'tests: [tests/a.test.sh :: alpha]
'; do
  k=$((k+1))
  case $k in 1) what="an entry that does not split" ;; 2) what="a test file not in files:" ;;
             3) what="a repeated entry" ;; 4) what="a value on the tests: line" ;; esac
  mkplan "$tmp/e6.md" "" "$(t1 "$blk")"
  run tests "$tmp/e6.md" T1
  chk "L198: $what: exit 2, nothing on stdout, the bad-entry line on stderr" \
    "$rc|$out|$(printf '%s\n' "$err" | rgc -F "$BADLINE")" "2||1"
done

echo
echo "TU: usage header"
run
chk "L200: usage lists the tests subcommand and prints through the Exit: line" \
  "$rc|$(printf '%s\n' "$err" | rgc 'plan-state[ \t]+tests[ \t]')|$(printf '%s\n' "$err" | rgc '^Exit:')" "2|1|1"
has "L200: the check line reads rules 1-5 and 7-17" "$err" "validate rules 1-5 and 7-17"

echo
echo "RESULT: $passes passed, $fails failed"
[ "$fails" -eq 0 ]

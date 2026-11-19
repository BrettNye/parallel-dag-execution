#!/usr/bin/env bash
# The hidden accuracy check: every test suite in a branch, run under gawk, mawk
# and busybox awk, and under dash and busybox sh, then the hidden functional
# suite when one is given. Neither the plan nor any run is told it exists.
#
# usage: hidden-check.sh <worktree> [<suite-dir>]
# Copies the worktree (tracked files at HEAD; a plain directory is copied as
# is) into each container, so the branch on disk is never written to. Prints
# one line per (awk, test file), each hidden case's PASS/FAIL line, and totals;
# exits 1 if any suite fails.
set -u
[ "$#" -eq 1 ] || [ "$#" -eq 2 ] || { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
wt=$1 suite=${2:-}
[ -d "$wt" ] || { echo "hidden-check: no directory $wt" >&2; exit 2; }
[ -z "$suite" ] || [ -d "$suite" ] || { echo "hidden-check: no suite directory $suite" >&2; exit 2; }
# ripgrep is installed in the containers: the suites may call rg (a declared test
# dependency). HIDDEN_WITH_RG=0 leaves it out.
# HIDDEN_EXTRA_PKG replaces it (the tests use a missing package to break setup).
extra=${HIDDEN_EXTRA_PKG:-ripgrep}; [ "${HIDDEN_WITH_RG:-1}" = 0 ] && extra=""
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
if [ -e "$wt/.git" ]; then
  git -C "$wt" archive HEAD | tar -x -C "$work" || { echo "hidden-check: cannot export $wt" >&2; exit 2; }
else
  cp -r "$wt/." "$work/" || { echo "hidden-check: cannot copy $wt" >&2; exit 2; }
fi
src="$work"; command -v cygpath >/dev/null 2>&1 && src="$(cygpath -w "$work")"
mount=""
if [ -n "$suite" ]; then
  hs="$(cd "$suite" && pwd)"; command -v cygpath >/dev/null 2>&1 && hs="$(cygpath -w "$hs")"
  mount="-v $hs:/hidden:ro"
fi

# Each runner prints "PASS <awk> <file>" or "FAIL <awk> <file>"; a hidden suite's
# own "  PASS: x" / "  FAIL: x" lines are kept, prefixed, so cases can be counted.
run_suites='
  git config --global user.name hidden-check; git config --global user.email hc@example.invalid
  git config --global init.defaultBranch main; git config --global --add safe.directory "*"
  cp -r /src /w && cd /w && git init -q && git add -A && git commit -qm base
  for t in tests/*/*.test.sh; do
    [ -f "$t" ] || continue
    # A suite whose tally lines error out can exit 0 having dropped failures, so a
    # missing command or a shell syntax error in its output also fails it.
    if bash "$t" >/tmp/out 2>&1 && ! grep -qE "command not found|syntax error" /tmp/out; then echo "PASS $AWKNAME $t"; else echo "FAIL $AWKNAME $t"; sed "s/^/    /" /tmp/out | tail -15; fi
  done
  for t in /hidden/*.test.sh; do
    [ -f "$t" ] || continue
    n="hidden/${t#/hidden/}"
    if bash "$t" >/tmp/out 2>&1 && ! grep -qE "command not found|syntax error" /tmp/out; then echo "PASS $AWKNAME $n"; else echo "FAIL $AWKNAME $n"; fi
    grep -E "^  (PASS|FAIL): " /tmp/out | sed "s|^|$AWKNAME $n|"
  done'

debian() {  # mawk is Debian's default awk; gawk is installed beside it
  MSYS_NO_PATHCONV=1 docker run --rm -e EXTRA_APT="$extra" -v "$src:/src:ro" $mount debian:stable-slim sh -c '
    apt-get update -qq >/dev/null && apt-get install -y -qq git gawk dash $EXTRA_APT >/dev/null 2>&1 || exit 3
    for a in mawk gawk; do
      ln -sf "/usr/bin/$a" /usr/local/bin/awk; export AWKNAME=$a
      ( '"$run_suites"' ); rm -rf /w
    done'
}
alpine() {  # busybox awk and busybox sh; bash and git only for the harness
  MSYS_NO_PATHCONV=1 docker run --rm -e EXTRA_APK="$extra" -v "$src:/src:ro" $mount alpine:3.20 sh -c '
    apk add --no-cache -q bash git $EXTRA_APK >/dev/null || exit 3
    export AWKNAME=busybox
    '"$run_suites"
}

out="$( { debian; alpine; } 2>&1 )"
printf '%s\n' "$out"
# A container whose setup failed prints nothing, which would read as fewer suites,
# not as a failure. Every awk must have run.
ran=$(printf '%s\n' "$out" | awk '/^(PASS|FAIL) / { print $2 }' | sort -u | tr '\n' ' ')
if [ "$ran" != "busybox gawk mawk " ]; then
  echo "HIDDEN CHECK: incomplete, ran under: ${ran:-nothing}"; exit 2
fi
pass=$(printf '%s\n' "$out" | awk '/^PASS /' | wc -l | tr -d ' ')
fail=$(printf '%s\n' "$out" | awk '/^FAIL /' | wc -l | tr -d ' ')
echo "HIDDEN CHECK: $pass passed, $fail failed"
if [ -n "$suite" ]; then
  cp=$(printf '%s\n' "$out" | awk '/^[a-z]+ hidden\/[^ ]+  PASS: /' | wc -l | tr -d ' ')
  cf=$(printf '%s\n' "$out" | awk '/^[a-z]+ hidden\/[^ ]+  FAIL: /' | wc -l | tr -d ' ')
  echo "HIDDEN CASES: $cp passed, $cf failed"
fi
[ "$fail" -eq 0 ] && [ "$pass" -gt 0 ]

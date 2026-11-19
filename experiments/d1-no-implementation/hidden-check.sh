#!/usr/bin/env bash
# The hidden accuracy check: every test suite in a branch, run under gawk, mawk
# and busybox awk, and under dash and busybox sh. Neither plan names it.
#
# usage: hidden-check.sh <worktree>
# Copies the worktree (tracked files at HEAD) into each container, so the
# branch on disk is never written to. Prints one line per (awk, test file) and
# a total; exits 1 if any case fails.
set -u
[ "$#" -eq 1 ] || { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
wt=$1
# ripgrep is installed in the containers: the suites may call rg (a declared test
# dependency). HIDDEN_WITH_RG=0 leaves it out.
extra=ripgrep; [ "${HIDDEN_WITH_RG:-1}" = 0 ] && extra=""
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
git -C "$wt" archive HEAD | tar -x -C "$work" || { echo "hidden-check: cannot export $wt" >&2; exit 2; }
src="$work"; command -v cygpath >/dev/null 2>&1 && src="$(cygpath -w "$work")"

# Each runner prints "PASS <awk> <file>" or "FAIL <awk> <file>".
run_suites='
  git config --global user.name hidden-check; git config --global user.email hc@example.invalid
  git config --global init.defaultBranch main; git config --global --add safe.directory "*"
  cp -r /src /w && cd /w && git init -q && git add -A && git commit -qm base
  for t in tests/*/*.test.sh; do
    # A suite whose tally lines error out can exit 0 having dropped failures, so a
    # missing command or a shell syntax error in its output also fails it.
    if bash "$t" >/tmp/out 2>&1 && ! grep -qE "command not found|syntax error" /tmp/out; then echo "PASS $AWKNAME $t"; else echo "FAIL $AWKNAME $t"; sed "s/^/    /" /tmp/out | tail -15; fi
  done'

debian() {  # mawk is Debian's default awk; gawk is installed beside it
  MSYS_NO_PATHCONV=1 docker run --rm -e EXTRA_APT="$extra" -v "$src:/src:ro" debian:stable-slim sh -c '
    apt-get update -qq >/dev/null && apt-get install -y -qq git gawk dash $EXTRA_APT >/dev/null 2>&1 || exit 3
    for a in mawk gawk; do
      ln -sf "/usr/bin/$a" /usr/local/bin/awk; export AWKNAME=$a
      ( '"$run_suites"' ); rm -rf /w
    done'
}
alpine() {  # busybox awk and busybox sh; bash and git only for the harness
  MSYS_NO_PATHCONV=1 docker run --rm -e EXTRA_APK="$extra" -v "$src:/src:ro" alpine:3.20 sh -c '
    apk add --no-cache -q bash git $EXTRA_APK >/dev/null || exit 3
    export AWKNAME=busybox
    '"$run_suites"
}

out="$( { debian; alpine; } 2>&1 )"
printf '%s\n' "$out"
pass=$(printf '%s\n' "$out" | awk '/^PASS /' | wc -l | tr -d ' ')
fail=$(printf '%s\n' "$out" | awk '/^FAIL /' | wc -l | tr -d ' ')
echo "HIDDEN CHECK: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && [ "$pass" -gt 0 ]

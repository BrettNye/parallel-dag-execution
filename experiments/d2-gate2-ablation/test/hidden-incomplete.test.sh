#!/usr/bin/env bash
# hidden-check.sh must refuse a result that is missing an awk (a container that failed
# to set up), not report the suites that did run as the whole answer. Needs Docker.
HERE="$(cd "$(dirname "$0")/.." && pwd)"
out="$(HIDDEN_EXTRA_PKG=no-such-package-d2 bash "$HERE/hidden-check.sh" "$HERE/test/hidden-fixture/repo" 2>&1)"; rc=$?
echo "$out" | tail -2
if [ "$rc" = 2 ] && printf '%s\n' "$out" | grep -q "^HIDDEN CHECK: incomplete"; then echo "RESULT: 1 passed, 0 failed"; else echo "RESULT: 0 passed, 1 failed (rc=$rc)"; exit 1; fi

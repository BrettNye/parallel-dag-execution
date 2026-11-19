#!/usr/bin/env bash
# Tests for run-arm.sh, run-audit.sh and run-fix.sh, with a fake claude on PATH.
HERE="$(cd "$(dirname "$0")/.." && pwd)"
fails=0; passes=0
ok()   { passes=$((passes+1)); echo "  PASS: $1"; }
bad()  { fails=$((fails+1));  echo "  FAIL: $1"; }
chk()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$3] got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (no [$3] in [$2])" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 (found [$3])" ;; *) ok "$1" ;; esac; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/out" "$tmp/plug in/.claude-plugin" "$tmp/work tree/docs"
echo '{}' > "$tmp/plug in/.claude-plugin/plugin.json"
echo '# plan' > "$tmp/work tree/docs/p.md"
cat > "$tmp/bin/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_OUT/argv"
printf '%s\n' "${CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS-unset}" > "$FAKE_OUT/env"
printf '%s\n' "${@: -1}" > "$FAKE_OUT/prompt"
if [ -n "${FAKE_AUDIT:-}" ]; then mkdir -p docs/.audit/p.md && echo "round $FAKE_AUDIT" > docs/.audit/p.md/reconciliation.md; fi
echo '{"session_id":"s1","subtype":"success","total_cost_usd":0,"num_turns":1,"result":"ok"}'
EOF
chmod +x "$tmp/bin/claude"
export PATH="$tmp/bin:$PATH" FAKE_OUT="$tmp/out" D2_RUNS="$tmp/runs"
unset CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS
W="$tmp/work tree"; P="$tmp/plug in"

echo "T1: run-arm.sh"
out="$(bash "$HERE/run-arm.sh" none-1 "$W" "$P" docs/p.md 30 2>&1)"; rc=$?
chk "exit 0 with spaces in paths" "$rc" "0"
has "prints the session" "$out" "session s1"
chk "wait ceiling off" "$(cat "$tmp/out/env")" "0"
has "budget passed" "$(tr '\n' ' ' < "$tmp/out/argv")" "--max-budget-usd 30.00 "
has "log written to D2_RUNS" "$(ls "$tmp/runs")" "none-1-"
bash "$HERE/run-arm.sh" none-1 "$W" "$P" docs/p.md >/dev/null 2>&1; chk "wrong arg count exits 2" "$?" "2"
bash "$HERE/run-arm.sh" none-1 "$W" "$P" docs/nope.md 30 >/dev/null 2>&1; chk "missing plan exits 2" "$?" "2"

echo
echo "T1b: run-arm.sh caps the whole run, not each invocation"
printf '{"session_id":"x","total_cost_usd":12}\n' > "$tmp/runs/full-1-20260101T000000Z.json"
bash "$HERE/run-arm.sh" full-1 "$W" "$P" docs/p.md 30 >/dev/null 2>&1; rc=$?
chk "second invocation exits 0" "$rc" "0"
has "budget is what is left" "$(tr '\n' ' ' < "$tmp/out/argv")" "--max-budget-usd 18.00 "
printf '{"session_id":"y","total_cost_usd":19}\n' > "$tmp/runs/full-1-20260101T000001Z.json"
: > "$tmp/out/argv"
out="$(bash "$HERE/run-arm.sh" full-1 "$W" "$P" docs/p.md 30 2>&1)"; rc=$?
chk "spent budget exits 3" "$rc" "3"
has "says the run did not finish" "$out" "did not finish"
chk "claude not called" "$(cat "$tmp/out/argv")" ""
printf '{"session_id":"z","total_cost_usd":50}\n' > "$tmp/runs/full-1-pf-20260101T000000Z.json"
printf '{"session_id":"z","total_cost_usd":50}\n' > "$tmp/runs/fix-full-1-20260101T000000Z.json"
bash "$HERE/run-arm.sh" full-2 "$W" "$P" docs/p.md 30 >/dev/null 2>&1
has "other labels' logs do not count" "$(tr '\n' ' ' < "$tmp/out/argv")" "--max-budget-usd 30.00 "

echo
echo "T2: run-audit.sh"
bash "$HERE/run-audit.sh" r1 "$W" "$P" docs/p.md 1 >/dev/null 2>&1; rc=$?
chk "round 1 exit 0" "$rc" "0"
has "round 1 uses all eight lenses" "$(cat "$tmp/out/prompt")" "all eight lenses"
chk "round 1 wait ceiling off" "$(cat "$tmp/out/env")" "0"
bash "$HERE/run-audit.sh" r2 "$W" "$P" docs/p.md 2 >/dev/null 2>&1; rc=$?
chk "round 2 exit 0" "$rc" "0"
has "round 2 is diff-scoped" "$(cat "$tmp/out/prompt")" "diff-scoped re-audit"
hasnt "round 2 does not force eight" "$(cat "$tmp/out/prompt")" "all eight"
has "round 2 names its round" "$(cat "$tmp/out/prompt")" "This is round 2."
FAKE_AUDIT=2 bash "$HERE/run-audit.sh" gate2-r2 "$W" "$P" docs/p.md 2 >/dev/null 2>&1
chk "round's audit files are kept" "$(cat "$tmp/runs/audit-gate2-r2/reconciliation.md" 2>&1)" "round 2"
FAKE_AUDIT=3 bash "$HERE/run-audit.sh" gate2-r2 "$W" "$P" docs/p.md 2 >/dev/null 2>&1; rc=$?
chk "an existing copy is never overwritten" "$rc:$(cat "$tmp/runs/audit-gate2-r2/reconciliation.md")" "2:round 2"
bash "$HERE/run-audit.sh" r0 "$W" "$P" docs/p.md 0 >/dev/null 2>&1; chk "round 0 exits 2" "$?" "2"
bash "$HERE/run-audit.sh" rx "$W" "$P" docs/p.md x >/dev/null 2>&1; chk "round x exits 2" "$?" "2"
bash "$HERE/run-audit.sh" r1 "$W" "$P" docs/p.md >/dev/null 2>&1; chk "wrong arg count exits 2" "$?" "2"
bash "$HERE/run-audit.sh" r1 "$W" "$P" docs/nope.md 1 >/dev/null 2>&1; chk "missing plan exits 2" "$?" "2"

echo
echo "T3: run-fix.sh"
printf 'fix {plan} {planname}\n' > "$tmp/prompt.md"
bash "$HERE/run-fix.sh" f1 "$W" docs/p.md "$tmp/prompt.md" >/dev/null 2>&1; rc=$?
chk "exit 0" "$rc" "0"
chk "placeholders filled" "$(cat "$tmp/out/prompt")" "fix docs/p.md p.md"
bash "$HERE/run-fix.sh" f1 "$W" docs/p.md >/dev/null 2>&1; chk "wrong arg count exits 2" "$?" "2"
bash "$HERE/run-fix.sh" f1 "$W" docs/nope.md "$tmp/prompt.md" >/dev/null 2>&1; chk "missing plan exits 2" "$?" "2"
bash "$HERE/run-fix.sh" f1 "$W" docs/p.md "$tmp/none.md" >/dev/null 2>&1; chk "missing prompt file exits 2" "$?" "2"

echo "RESULT: $passes passed, $fails failed"
[ "$fails" -eq 0 ]

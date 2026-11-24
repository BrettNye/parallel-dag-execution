#!/usr/bin/env bash
# Test suite for skills/auditing-artifacts/audit-stats
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO/skills/auditing-artifacts/audit-stats"
[ -f "$SCRIPT" ] || { echo "FAIL: audit-stats not found at $SCRIPT" >&2; exit 1; }
# A second POSIX shell, to catch bashisms. dash if present; otherwise sh.
if command -v dash >/dev/null 2>&1; then ALTSH=dash; else ALTSH=sh; echo "NOTE: dash not installed - alt-shell cases run under sh"; fi
fails=0; passes=0
ok()   { passes=$((passes+1)); echo "  PASS: $1"; }
bad()  { fails=$((fails+1));  echo "  FAIL: $1"; }
chk()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$3] got [$2])"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Three reports in the three lens-line forms, one nested a level down as a kept round.
mkdir -p "$tmp/a/.audit/plan.md/round1" "$tmp/b"
cat > "$tmp/a/.audit/plan.md/reconciliation.md" <<'EOF'
## Verdict: NOT READY — 2 blocking

### Blocking findings

**B1. The awk name clashes.**
- Evidence: something.
- Lenses: grounding, charter

**B2. The loop never ends.**
- Found by: coherence. My probe supplied the evidence; grounding did not see it.

### Deferred
**D1. A deferred one.**
- Lenses: design
EOF
cat > "$tmp/a/.audit/plan.md/round1/reconciliation.md" <<'EOF'
## Verdict: NOT READY — 2 blocking

### Blocking findings

**R2-B1. Errors on other tasks are shown as warnings.**
- Contributing lenses: absence (BLOCKING), coherence (DEFERRED, merged and promoted). The reconciler read the skill.

**R2-B2. No lens named here.**
- Evidence: none.

## Something else
**X1. Not a finding.**
- Lenses: verifiability
EOF
cat > "$tmp/b/reconciliation.md" <<'EOF'
## Verdict: READY — 0 blocking

### Blocking findings

None.

### Solid
- Lenses: coverage
EOF

WANT='audit-stats: 3 reports, 4 blocking findings, 1 with no lens line
lens                  blocking  alone
coherence                    2      1
absence                      1      0
charter                      1      0
grounding                    1      0'

echo "T1: counts per lens across three reports and three lens-line forms"
out="$(sh "$SCRIPT" "$tmp/a" "$tmp/b" 2>&1)"; rc=$?
chk "report" "$rc:$out" "0:$WANT"
out="$($ALTSH "$SCRIPT" "$tmp/a" "$tmp/b" 2>&1)"; rc=$?
chk "report under $ALTSH" "$rc:$out" "0:$WANT"

echo
echo "T2: a file argument, and a path with no reports"
out="$(sh "$SCRIPT" "$tmp/b/reconciliation.md" 2>&1)"; rc=$?
chk "one READY report" "$rc:$out" "0:audit-stats: 1 reports, 0 blocking findings, 0 with no lens line
lens                  blocking  alone"
mkdir -p "$tmp/empty"
out="$(sh "$SCRIPT" "$tmp/empty" 2>&1)"; rc=$?
chk "no reports exits 2" "$rc:$out" "2:audit-stats: no reconciliation.md under $tmp/empty"
out="$(sh "$SCRIPT" "$tmp/nope" 2>&1)"; rc=$?
chk "missing path exits 2" "$rc:$out" "2:audit-stats: cannot read $tmp/nope"

echo
echo "T3: the default path is the current directory"
out="$(cd "$tmp/b" && sh "$SCRIPT" 2>&1)"; rc=$?
chk "no argument reads ." "$rc:$(printf '%s\n' "$out" | head -n 1)" "0:audit-stats: 1 reports, 0 blocking findings, 0 with no lens line"

echo
echo "T4: bold lens line, CRLF, words that are not lenses, and only the first lens line counts"
mkdir -p "$tmp/c"
printf '%s\r\n' '### Blocking findings' '' '**B1. One.**' '- **Lenses:** verifiability, reconciler, context-sufficiency' '- Lenses: dag-integrity' > "$tmp/c/reconciliation.md"
out="$(sh "$SCRIPT" "$tmp/c" 2>&1)"; rc=$?
chk "CRLF and bold" "$rc:$out" "0:audit-stats: 1 reports, 1 blocking findings, 0 with no lens line
lens                  blocking  alone
context-sufficiency          1      0
verifiability                1      0"

echo
echo "T5: a one-finding report may use the singular heading"
mkdir -p "$tmp/d"
printf '%s\n' '### Blocking finding' '' '**R2-B1. One.** Prose with no lens line.' '### Deferred' > "$tmp/d/reconciliation.md"
out="$(sh "$SCRIPT" "$tmp/d" 2>&1)"; rc=$?
chk "singular heading counts, no lens line" "$rc:$(printf '%s\n' "$out" | head -n 1)" "0:audit-stats: 1 reports, 1 blocking findings, 1 with no lens line"

echo
echo "T6: a bold label inside a finding does not start a new one"
mkdir -p "$tmp/f"
printf '%s
' '### Blocking findings' '' '**B1. One.**' '- Lenses: coherence' '**Resolution:** change the sketch.' '' '**R2-B3. Two.**' '- Lenses: grounding' > "$tmp/f/reconciliation.md"
out="$(sh "$SCRIPT" "$tmp/f" 2>&1)"; rc=$?
chk "bold label is not a finding" "$rc:$(printf '%s
' "$out" | head -n 1)" "0:audit-stats: 1 reports, 2 blocking findings, 0 with no lens line"

echo "RESULT: $passes passed, $fails failed"
[ "$fails" -eq 0 ]

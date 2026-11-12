#!/usr/bin/env bash
# Test suite for skills/writing-dag-plans/plan-state
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO/skills/writing-dag-plans/plan-state"
[ -f "$SCRIPT" ] || { echo "FAIL: plan-state not found at $SCRIPT" >&2; exit 1; }
# A second POSIX shell, to catch bashisms. dash if present; otherwise sh.
if command -v dash >/dev/null 2>&1; then ALTSH=dash; else ALTSH=sh; echo "NOTE: dash not installed - alt-shell cases run under sh"; fi
fails=0; passes=0
ok()   { passes=$((passes+1)); echo "  PASS: $1"; }
bad()  { fails=$((fails+1));  echo "  FAIL: $1"; }
chk()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$3] got [$2])"; fi; }
has()  { if printf '%s\n' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1 (missing [$3] in: $2)"; fi; }
hasnt(){ if printf '%s\n' "$2" | grep -qF -- "$3"; then bad "$1 (unexpected [$3] in: $2)"; else ok "$1"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
ps() { sh "$SCRIPT" "$@"; }

# A clean three-task plan: a -> b, a -> c; b and c share nothing.
clean_plan() {
cat > "$1" <<'EOF'
---
title: demo
created: 2026-11-12
---

```mermaid
flowchart TD
    stale["stale"]
```

## Context

Demo.

## Tasks

## Task: install hook

```yaml
id: task-a
depends_on: []
files:
  - bin/hook.sh   # the hook
  - .claude/settings.json
status: done
```

Body.

## Task: docs

```yaml
id: task-b
depends_on: [task-a]
files: [docs/install.md]
status: pending
```

## Task: tests

```yaml
id: task-c
depends_on:
  - task-a
files:
  - tests/hook.test.sh
  - tests/fixtures/one.txt
  - tests/fixtures/two.txt
status: pending
model_hint: cheap
```
EOF
}

echo "T1: a clean plan passes check"
clean_plan "$tmp/p1.md"
out="$(ps check "$tmp/p1.md" 2>&1)"; rc=$?
chk "exit 0" "$rc" "0"
chk "no output" "$out" ""

echo
echo "T2: duplicate id (rule 1)"
clean_plan "$tmp/p2.md"; sed -i 's/^id: task-c$/id: task-b/' "$tmp/p2.md"
out="$(ps check "$tmp/p2.md" 2>&1)"; rc=$?
chk "exit 1" "$rc" "1"
has "names rule 1 and the id" "$out" "rule 1: duplicate id task-b"

echo
echo "T3: cycle (rule 2)"
clean_plan "$tmp/p3.md"; sed -i 's/^depends_on: \[\]$/depends_on: [task-b]/' "$tmp/p3.md"
out="$(ps check "$tmp/p3.md" 2>&1)"; rc=$?
chk "exit 1" "$rc" "1"
has "names rule 2" "$out" "rule 2: cycle among"
has "cycle lists task-a" "$out" "task-a"
has "cycle lists task-b" "$out" "task-b"

echo
echo "T4: undefined dependency (rule 3)"
clean_plan "$tmp/p4.md"; sed -i 's/^depends_on: \[task-a\]$/depends_on: [task-a, task-zz]/' "$tmp/p4.md"
out="$(ps check "$tmp/p4.md" 2>&1)"; rc=$?
chk "exit 1" "$rc" "1"
has "names rule 3, task and dep" "$out" "rule 3: task-b depends on undefined task-zz"

echo
echo "T5: shared file without a dependency path (rule 4)"
clean_plan "$tmp/p5.md"; sed -i 's|^files: \[docs/install.md\]$|files: [docs/install.md, tests/hook.test.sh]|' "$tmp/p5.md"
out="$(ps check "$tmp/p5.md" 2>&1)"; rc=$?
chk "exit 1" "$rc" "1"
has "names both tasks and the file" "$out" "rule 4: task-b and task-c both declare tests/hook.test.sh"
clean_plan "$tmp/p5b.md"; sed -i 's|^files: \[docs/install.md\]$|files: [docs/install.md, bin/hook.sh]|' "$tmp/p5b.md"
out="$(ps check "$tmp/p5b.md" 2>&1)"; rc=$?
chk "shared file WITH a path (a -> b) passes" "$rc" "0"

echo
echo "T6: required fields, empty files, status values (rule 5)"
clean_plan "$tmp/p6.md"; sed -i '0,/^status: pending$/{//d}' "$tmp/p6.md"
out="$(ps check "$tmp/p6.md" 2>&1)"; rc=$?
chk "exit 1" "$rc" "1"
has "missing status named" "$out" "rule 5: task-b has no status"
clean_plan "$tmp/p6b.md"; sed -i 's|^files: \[docs/install.md\]$|files: []|' "$tmp/p6b.md"
out="$(ps check "$tmp/p6b.md" 2>&1)"
has "empty files refused" "$out" "rule 5: task-b has empty files"
printf 'single_threaded: true\n' > "$tmp/st"; sed -i "/^files: \[\]$/r $tmp/st" "$tmp/p6b.md"
out="$(ps check "$tmp/p6b.md" 2>&1)"; rc=$?
chk "empty files allowed when single_threaded" "$rc" "0"
clean_plan "$tmp/p6c.md"; sed -i '0,/^status: pending$/s//status: finished/' "$tmp/p6c.md"
out="$(ps check "$tmp/p6c.md" 2>&1)"
has "bad status value named" "$out" "rule 5: task-b has status finished"

echo
echo "T7: enums and default_implementer (rules 7-10, 12)"
clean_plan "$tmp/p7.md"
sed -i 's/^model_hint: cheap$/model_hint: fable\nreview_mode: both/' "$tmp/p7.md"
sed -i 's/^created: 2026-11-12$/created: 2026-11-12\ndefault_quality_reviewer_hint: huge\ndefault_review_mode: none\ndefault_implementer: ""/' "$tmp/p7.md"
out="$(ps check "$tmp/p7.md" 2>&1)"; rc=$?
chk "exit 1" "$rc" "1"
has "rule 7" "$out" "rule 7: task-c model_hint is fable"
has "rule 8" "$out" "rule 8: default_quality_reviewer_hint is huge"
has "rule 9" "$out" "rule 9: task-c review_mode is both"
has "rule 10" "$out" "rule 10: default_review_mode is none"
has "rule 12" "$out" "rule 12: default_implementer is empty"

echo
echo "T8: spec: must be a readable single file (rule 11)"
mkdir -p "$tmp/repo/docs/specs"; : > "$tmp/repo/docs/specs/real.md"
clean_plan "$tmp/repo/p8.md"; sed -i 's/^created: 2026-11-12$/created: 2026-11-12\nspec: docs\/specs\/gone.md/' "$tmp/repo/p8.md"
out="$(cd "$tmp/repo" && ps check p8.md 2>&1)"; rc=$?
chk "missing spec exit 1" "$rc" "1"
has "missing spec named" "$out" "rule 11: spec docs/specs/gone.md"
sed -i 's|^spec: docs/specs/gone.md$|spec: docs/specs|' "$tmp/repo/p8.md"
out="$(cd "$tmp/repo" && ps check p8.md 2>&1)"
has "directory spec refused" "$out" "rule 11: spec docs/specs"
sed -i 's|^spec: docs/specs$|spec: docs/specs/real.md|' "$tmp/repo/p8.md"
out="$(cd "$tmp/repo" && ps check p8.md 2>&1)"; rc=$?
chk "real spec passes" "$rc" "0"

echo
echo "T9: ready lists tasks whose deps are all done"
clean_plan "$tmp/p9.md"
chk "b and c ready" "$(ps ready "$tmp/p9.md" | tr '\n' ' ')" "task-b task-c "
sed -i 's/^status: done$/status: running/' "$tmp/p9.md"
chk "nothing ready while a runs" "$(ps ready "$tmp/p9.md")" ""

echo
echo "T10: set changes a status and redraws the mermaid block"
clean_plan "$tmp/p10.md"
ps set "$tmp/p10.md" task-b ready >/dev/null 2>&1; rc=$?
chk "pending -> ready (deps done) exit 0" "$rc" "0"
has "status rewritten" "$(cat "$tmp/p10.md")" "status: ready"
has "mermaid redrawn with ready class" "$(cat "$tmp/p10.md")" 'task-b["task-b: docs<br/>files: docs/install.md"]:::ready'
hasnt "stale node gone" "$(cat "$tmp/p10.md")" 'stale["stale"]'
before="$(cat "$tmp/p10.md")"
out="$(ps set "$tmp/p10.md" task-a running 2>&1)"; rc=$?
chk "done -> running refused exit 2" "$rc" "2"
has "refusal names the move" "$out" "task-a: done -> running"
chk "file unchanged after refusal" "$(cat "$tmp/p10.md")" "$before"
clean_plan "$tmp/p10b.md"; sed -i 's/^status: done$/status: running/' "$tmp/p10b.md"
out="$(ps set "$tmp/p10b.md" task-b ready 2>&1)"; rc=$?
chk "pending -> ready with unfinished deps refused" "$rc" "2"

echo
echo "T11: failed cascades skipped downstream, and only to pending/ready"
cat > "$tmp/p11.md" <<'EOF'
---
title: cascade
---

## Task: a

```yaml
id: a
depends_on: []
files: [a.txt]
status: running
```

## Task: b

```yaml
id: b
depends_on: [a]
files: [b.txt]
status: pending
```

## Task: c

```yaml
id: c
depends_on: [b]
files: [c.txt]
status: pending
```

## Task: d

```yaml
id: d
depends_on: []
files: [d.txt]
status: running
```
EOF
out="$(ps set "$tmp/p11.md" a failed 2>&1)"; rc=$?
chk "exit 0" "$rc" "0"
chk "a failed" "$(awk '/^id: a$/{f=1} f&&/^status:/{print $2;exit}' "$tmp/p11.md")" "failed"
chk "b skipped" "$(awk '/^id: b$/{f=1} f&&/^status:/{print $2;exit}' "$tmp/p11.md")" "skipped"
chk "c skipped (transitive)" "$(awk '/^id: c$/{f=1} f&&/^status:/{print $2;exit}' "$tmp/p11.md")" "skipped"
chk "d untouched" "$(awk '/^id: d$/{f=1} f&&/^status:/{print $2;exit}' "$tmp/p11.md")" "running"
has "reports what was skipped" "$out" "skipped: b c"
has "mermaid block inserted when absent" "$(cat "$tmp/p11.md")" '```mermaid'

echo
echo "T12: render is idempotent and draws the spec's node shape"
clean_plan "$tmp/p12.md"
ps render "$tmp/p12.md"; first="$(cat "$tmp/p12.md")"
ps render "$tmp/p12.md"; chk "second render changes nothing" "$(cat "$tmp/p12.md")" "$first"
chk "exactly one mermaid block" "$(grep -c '^```mermaid' "$tmp/p12.md")" "1"
has "done class" "$first" 'task-a["task-a: install hook<br/>files: bin/hook.sh, .claude/settings.json"]:::done'
has "+N more for 3+ files" "$first" 'files: tests/hook.test.sh +2 more"]'
has "pending has no class" "$first" 'task-b["task-b: docs<br/>files: docs/install.md"]'
hasnt "pending carries no :::" "$first" 'docs/install.md"]:::'
has "edge" "$first" "task-a --> task-c"
has "classDef skipped" "$first" "classDef skipped fill:#d3d3d3,stroke:#333,stroke-dasharray: 5 5"

echo
echo "T13: a '## Task:' inside a code fence is not a task"
clean_plan "$tmp/p13.md"
cat >> "$tmp/p13.md" <<'EOF'

Example of the format:

````markdown
## Task: not real

```yaml
id: ghost
depends_on: [nobody]
files: []
status: pending
```
````
EOF
out="$(ps check "$tmp/p13.md" 2>&1)"; rc=$?
chk "fenced example ignored, exit 0" "$rc" "0"
hasnt "ghost not parsed" "$(ps ready "$tmp/p13.md")" "ghost"

echo
echo "T14: tree for a small DAG, flat table for a deep one"
clean_plan "$tmp/p14.md"
out="$(ps tree "$tmp/p14.md")"
has "header counts" "$out" "DAG: 3 tasks · 1 done · 0 running · 0 failed · 0 skipped · 2 pending"
has "root line" "$out" "[task-a] install hook"
has "child connector" "$out" "└──→ [task-c] tests"
{ printf -- '---\ntitle: deep\n---\n'; prev=""; for i in 1 2 3 4 5; do
    d="[]"; [ -n "$prev" ] && d="[$prev]"
    printf '\n## Task: t%s\n\n```yaml\nid: t%s\ndepends_on: %s\nfiles: [f%s]\nstatus: pending\n```\n' "$i" "$i" "$d" "$i"; prev="t$i"; done; } > "$tmp/p14b.md"
out="$(ps tree "$tmp/p14b.md")"
hasnt "deep DAG has no tree connectors" "$out" "──→"
has "deep DAG lists t5" "$out" "[t5] t5"

echo
echo "T15: the repo's own plans parse without a usage error"
for p in "$REPO"/docs/superpowers/plans/*.md; do
  ps check "$p" >/dev/null 2>&1; rc=$?
  if [ "$rc" -le 1 ]; then ok "check ran on $(basename "$p") (rc=$rc)"; else bad "check crashed on $(basename "$p") (rc=$rc)"; fi
done
out="$(ps check "$REPO/docs/superpowers/plans/2026-08-27-seams-and-ground-truth-dag.md" 2>&1)"; rc=$?
chk "v0.6.0 plan is clean" "$rc:$out" "0:"

echo
echo "T16: usage errors exit 2"
ps bogus "$tmp/p1.md" >/dev/null 2>&1; chk "unknown command" "$?" "2"
ps check "$tmp/nope.md" >/dev/null 2>&1; chk "unreadable plan" "$?" "2"
ps set "$tmp/p1.md" task-b sideways >/dev/null 2>&1; chk "unknown status" "$?" "2"
ps set "$tmp/p1.md" task-zz ready >/dev/null 2>&1; chk "unknown id" "$?" "2"

echo
echo "T17: runs under a second POSIX shell ($ALTSH)"
clean_plan "$tmp/p17.md"
out="$($ALTSH "$SCRIPT" check "$tmp/p17.md" 2>&1)"; rc=$?
chk "check exit 0 under $ALTSH" "$rc:$out" "0:"
$ALTSH "$SCRIPT" set "$tmp/p17.md" task-b ready >/dev/null 2>&1; rc=$?
chk "set exit 0 under $ALTSH" "$rc" "0"

charter() {
cat > "$1" <<'EOF'
---
id: superspec-charter-demo
type: superspec-charter
charter_kind: delivery
children: [core, api, ui]
---

# Demo

## Children
| id | child | plan | owner | depends on | ships alone |
|----|-------|------|-------|------------|-------------|
| core | engine | docs/plans/core.md | Ana | | yes |
| api | http api | | Bo | C1 | held until ui |
| ui | screens | | Cy | api, C2 | dark |

## Contracts between children
| id | contract | owner | consumers |
|----|----------|-------|-----------|
| C1 | Job type | core | api |
| C2 | Error shape | api | ui |

## Shared invariants
EOF
}

echo
echo "T18: parent: and child: on a plan (rule 13)"
mkdir -p "$tmp/r18/docs"; charter "$tmp/r18/docs/charter.md"
clean_plan "$tmp/r18/p.md"; sed -i 's/^created: 2026-11-12$/created: 2026-11-12\nparent: docs\/charter.md\nchild: api/' "$tmp/r18/p.md"
out="$(cd "$tmp/r18" && ps check p.md 2>&1)"; rc=$?
chk "child listed in the charter passes" "$rc:$out" "0:"
sed -i 's/^child: api$/child: billing/' "$tmp/r18/p.md"
out="$(cd "$tmp/r18" && ps check p.md 2>&1)"
has "child missing from charter" "$out" "rule 13: child billing is not in docs/charter.md children"
sed -i 's/^child: billing$//' "$tmp/r18/p.md"
out="$(cd "$tmp/r18" && ps check p.md 2>&1)"
has "parent without child" "$out" "rule 13: parent and child must be set together"
sed -i 's|^parent: docs/charter.md$|parent: docs/gone.md\nchild: api|' "$tmp/r18/p.md"
out="$(cd "$tmp/r18" && ps check p.md 2>&1)"
has "unreadable parent" "$out" "rule 13: parent docs/gone.md"

echo
echo "T19: charter checks its own graph"
charter "$tmp/c1.md"
out="$(ps charter "$tmp/c1.md" 2>&1)"; rc=$?
chk "clean charter exit 0" "$rc:$out" "0:"
charter "$tmp/c2.md"; sed -i 's/^| api | http api | | Bo | C1 |/| api | http api | | Bo | C9, nobody |/' "$tmp/c2.md"
out="$(ps charter "$tmp/c2.md" 2>&1)"; rc=$?
chk "exit 1" "$rc" "1"
has "unknown contract dependency" "$out" "charter: api depends on C9, which is neither a child nor a contract"
has "unknown child dependency" "$out" "charter: api depends on nobody"
charter "$tmp/c3.md"; sed -i 's/^| C2 | Error shape | api | ui |$/| C2 | Error shape | | ui |/' "$tmp/c3.md"
out="$(ps charter "$tmp/c3.md" 2>&1)"
has "contract with no owner" "$out" "charter: contract C2 has no owner"
charter "$tmp/c4.md"; sed -i 's/^| C1 | Job type | core | api |$/| C1 | Job type | ui | api |/' "$tmp/c4.md"
out="$(ps charter "$tmp/c4.md" 2>&1)"
has "cycle through a contract owner" "$out" "charter: cycle among children"
charter "$tmp/c5.md"; sed -i 's/^children: \[core, api, ui\]$/children: [core, api]/' "$tmp/c5.md"
out="$(ps charter "$tmp/c5.md" 2>&1)"
has "frontmatter and table disagree" "$out" "charter: ui is in the Children table but not in children:"
charter "$tmp/c6.md"; sed -i 's/^| C2 | Error shape | api | ui |$/| C1 | Error shape | api | ui |/' "$tmp/c6.md"
out="$(ps charter "$tmp/c6.md" 2>&1)"
has "duplicate contract id" "$out" "charter: duplicate contract id C1"

echo
echo "T20: an escaped pipe inside a table cell does not shift the columns"
charter "$tmp/c7.md"; sed -i 's/^| C1 | Job type | core | api |$/| C1 | Job record: state is queued \\| running \\| done | core | api |/' "$tmp/c7.md"
has "fixture carries the escaped pipes" "$(cat "$tmp/c7.md")" 'queued \| running \| done | core'
out="$(ps charter "$tmp/c7.md" 2>&1)"; rc=$?
chk "escaped pipes: clean charter exit 0" "$rc:$out" "0:"

echo
echo "RESULT: $passes passed, $fails failed"
[ "$fails" -eq 0 ]

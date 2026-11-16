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
# Replace (or, with an empty replacement, delete) the first "status: pending" line.
# GNU sed spells this 0,/re/; busybox sed has no such address.
first_status() { awk -v r="$2" '!d && /^status: pending$/ { d = 1; if (r != "") print r; next } { print }' "$1" > "$1.t" && mv "$1.t" "$1"; }

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
clean_plan "$tmp/p6.md"; first_status "$tmp/p6.md" ""
out="$(ps check "$tmp/p6.md" 2>&1)"; rc=$?
chk "exit 1" "$rc" "1"
has "missing status named" "$out" "rule 5: task-b has no status"
clean_plan "$tmp/p6b.md"; sed -i 's|^files: \[docs/install.md\]$|files: []|' "$tmp/p6b.md"
out="$(ps check "$tmp/p6b.md" 2>&1)"
has "empty files refused" "$out" "rule 5: task-b has empty files"
printf 'single_threaded: true\n' > "$tmp/st"; sed -i "/^files: \[\]$/r $tmp/st" "$tmp/p6b.md"
out="$(ps check "$tmp/p6b.md" 2>&1)"; rc=$?
chk "empty files allowed when single_threaded" "$rc" "0"
clean_plan "$tmp/p6c.md"; first_status "$tmp/p6c.md" "status: finished"
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
echo
echo "T21: rule 14, contracts-only plans"
# addsec FILE N SECTION [fenced]: put "## SECTION" after the yaml block of the Nth task
addsec() {
  awk -v n="$2" -v sec="$3" -v fenced="$4" '
    /^## Task:/ { t++; inblk = 0 }
    { print }
    t == n && /^```yaml/ { inblk = 1; next }
    t == n && inblk && /^```/ { inblk = 0
      if (fenced != "") print "\n```\n## " sec "\n```"; else print "\n## " sec "\n\ntext"
    }' "$1" > "$1.new" && mv "$1.new" "$1"
}
setimpl() { sed -i "s/^created: 2026-11-12\$/created: 2026-11-12\nimplementation: $2/" "$1"; }
clean_plan "$tmp/r21.md"; setimpl "$tmp/r21.md" contracts-only
out="$(ps check "$tmp/r21.md" 2>&1)"; rc=$?
chk "contracts-only plan without Contracts sections exits 1" "$rc" "1"
has "names the task" "$out" "plan-state: rule 14: task-a has no ## Contracts section"
clean_plan "$tmp/r21b.md"; setimpl "$tmp/r21b.md" bogus
out="$(ps check "$tmp/r21b.md" 2>&1)"; rc=$?
chk "implementation: bogus exits 1" "$rc" "1"
has "names the bad value" "$out" "plan-state: rule 14: implementation is bogus"
clean_plan "$tmp/r21c.md"; setimpl "$tmp/r21c.md" contracts-only
for n in 1 2 3; do addsec "$tmp/r21c.md" $n Contracts; done
addsec "$tmp/r21c.md" 2 Implementation
out="$(ps check "$tmp/r21c.md" 2>&1)"; rc=$?
chk "both sections exits 1" "$rc" "1"
has "flags the Implementation section" "$out" "plan-state: rule 14: task-b has an ## Implementation section"
hasnt "task with both has Contracts" "$out" "task-b has no ## Contracts"
hasnt "other tasks not flagged" "$out" "task-c has"
clean_plan "$tmp/r21d.md"; setimpl "$tmp/r21d.md" contracts-only
for n in 1 2 3; do addsec "$tmp/r21d.md" $n Contracts; done
out="$(ps check "$tmp/r21d.md" 2>&1)"; rc=$?
chk "all Contracts, no Implementation: clean" "$rc:$out" "0:"
clean_plan "$tmp/r21e.md"; setimpl "$tmp/r21e.md" contracts-only
addsec "$tmp/r21e.md" 1 Contracts; addsec "$tmp/r21e.md" 2 Contracts
sed -i 's/^id: task-c$/id: task-c\nis_wiring_task: true/' "$tmp/r21e.md"
out="$(ps check "$tmp/r21e.md" 2>&1)"; rc=$?
chk "wiring task needs neither section" "$rc:$out" "0:"
clean_plan "$tmp/r21f.md"; setimpl "$tmp/r21f.md" contracts-only
addsec "$tmp/r21f.md" 1 Contracts fenced; addsec "$tmp/r21f.md" 2 Contracts; addsec "$tmp/r21f.md" 3 Contracts
out="$(ps check "$tmp/r21f.md" 2>&1)"; rc=$?
chk "fenced Contracts heading does not count" "$rc" "1"
has "still reports task-a" "$out" "rule 14: task-a has no ## Contracts section"
clean_plan "$tmp/r21g.md"; setimpl "$tmp/r21g.md" full
addsec "$tmp/r21g.md" 1 Contracts
out="$(ps check "$tmp/r21g.md" 2>&1)"; rc=$?
chk "implementation: full with a Contracts section is clean" "$rc:$out" "0:"
clean_plan "$tmp/r21h.md"; addsec "$tmp/r21h.md" 1 Contracts
out="$(ps check "$tmp/r21h.md" 2>&1)"; rc=$?
chk "no implementation key is clean" "$rc:$out" "0:"
out="$($ALTSH "$SCRIPT" check "$tmp/r21.md" 2>&1)"; rc=$?
chk "rule 14 under $ALTSH" "$rc" "1"


# ---- round: count fix rounds, cap 3, rule 15 ----
# mkrr FILE STATUS RR: clean plan whose task-a has STATUS and, unless RR is empty, review_rounds: RR
mkrr() {
  clean_plan "$1"
  awk -v s="$2" -v r="$3" '/^status: done$/ && !d { d = 1; print "status: " s; if (r != "") print "review_rounds: " r; next } { print }' "$1" > "$1.t" && mv "$1.t" "$1"
}

echo
echo "T22: round counts fix rounds on a running task"
mkrr "$tmp/r22.md" running ""
out="$(ps round "$tmp/r22.md" task-a 2>&1)"; rc=$?
chk "absent field counts to 1" "$rc:$out" "0:1"
after="$(awk 'p { print; exit } /^status: running$/ { p = 1 }' "$tmp/r22.md")"
chk "inserted on the line after status" "$after" "review_rounds: 1"
mkrr "$tmp/r22b.md" running 0
out="$(ps round "$tmp/r22b.md" task-a 2>&1)"; rc=$?
chk "0 counts to 1" "$rc:$out" "0:1"
chk "field rewritten in place" "$(rg -c '^review_rounds: 1$' "$tmp/r22b.md"):$(rg -c '^review_rounds:' "$tmp/r22b.md")" "1:1"
mkrr "$tmp/r22c.md" running 2
out="$(ps round "$tmp/r22c.md" task-a 2>&1)"; rc=$?
chk "2 counts to 3" "$rc:$out" "0:3"
chk "field reads 3" "$(rg -c '^review_rounds: 3$' "$tmp/r22c.md")" "1"
mkrr "$tmp/r22d.md" running 3
before="$(cksum < "$tmp/r22d.md")"
out="$(ps round "$tmp/r22d.md" task-a 2>&1)"; rc=$?
chk "cap: exit 1 and message" "$rc:$out" "1:plan-state: task-a: review cap reached (3 fix rounds)"
chk "cap: plan unchanged" "$(cksum < "$tmp/r22d.md")" "$before"
out="$($ALTSH "$SCRIPT" round "$tmp/r22d.md" task-a 2>&1)"; rc=$?
chk "cap under $ALTSH" "$rc:$out" "1:plan-state: task-a: review cap reached (3 fix rounds)"
mkrr "$tmp/r22e.md" running ""
out="$($ALTSH "$SCRIPT" round "$tmp/r22e.md" task-a 2>&1)"; rc=$?
chk "absent field under $ALTSH" "$rc:$out" "0:1"
chk "inserted under $ALTSH" "$(awk 'p { print; exit } /^status: running$/ { p = 1 }' "$tmp/r22e.md")" "review_rounds: 1"

echo
echo "T23: round refuses a task that is not running"
mkrr "$tmp/r23.md" pending ""
before="$(cksum < "$tmp/r23.md")"
out="$(ps round "$tmp/r23.md" task-a 2>&1)"; rc=$?
chk "pending exits 2" "$rc" "2"
chk "pending plan unchanged" "$(cksum < "$tmp/r23.md")" "$before"
mkrr "$tmp/r23b.md" pending 3
before="$(cksum < "$tmp/r23b.md")"
out="$(ps round "$tmp/r23b.md" task-a 2>&1)"; rc=$?
chk "pending at 3 exits 2, not 1" "$rc" "2"
chk "pending at 3 plan unchanged" "$(cksum < "$tmp/r23b.md")" "$before"

echo
echo "T24: rule 15 and bad values"
mkrr "$tmp/r24.md" running 4
before="$(cksum < "$tmp/r24.md")"
ps round "$tmp/r24.md" task-a >/dev/null 2>&1; rc=$?
chk "round on 4 exits 2" "$rc" "2"
chk "round on 4 leaves plan alone" "$(cksum < "$tmp/r24.md")" "$before"
out="$(ps check "$tmp/r24.md" 2>&1)"; rc=$?
chk "check on 4 exits 1" "$rc" "1"
has "check names the value" "$out" "plan-state: rule 15: task-a review_rounds is 4"
for v in abc -1; do
  mkrr "$tmp/r24v.md" running "$v"
  out="$(ps check "$tmp/r24v.md" 2>&1)"
  has "rule 15 for $v" "$out" "plan-state: rule 15: task-a review_rounds is $v"
done
for v in 0 3; do
  mkrr "$tmp/r24w.md" running "$v"
  out="$(ps check "$tmp/r24w.md" 2>&1)"; rc=$?
  chk "no rule 15 for $v" "$rc:$out" "0:"
done

echo
echo "T25: round keeps CRLF"
mkrr "$tmp/r25.lf" running ""
awk -v BINMODE=3 '{ print $0 "\r" }' "$tmp/r25.lf" > "$tmp/r25.md"
ps round "$tmp/r25.md" task-a >/dev/null 2>&1; rc=$?
chk "CRLF plan round exits 0" "$rc" "0"
nl=$(wc -l < "$tmp/r25.md"); ncr=$(tr -cd '\r' < "$tmp/r25.md" | wc -c)
if [ "$nl" -eq "$ncr" ]; then ok "every line still ends in CR"; else bad "every line still ends in CR ($ncr CRs, $nl lines)"; fi
k=$(awk -v BINMODE=3 '/^status: running\r?$/ { print FNR + 1; exit }' "$tmp/r25.md")
head -n "$k" "$tmp/r25.md" | tail -n 1 > "$tmp/got"; printf 'review_rounds: 1\r\n' > "$tmp/want"
if cmp -s "$tmp/want" "$tmp/got"; then ok "inserted line is review_rounds: 1 CRLF"; else bad "inserted line is review_rounds: 1 CRLF"; fi

echo
echo "T26: round on an unwritable plan"
mkrr "$tmp/r26.md" running ""
chmod a-w "$tmp/r26.md"
if ( : >> "$tmp/r26.md" ) 2>/dev/null; then
  echo "NOTE: T26 not exercised - this user can write a read-only file"
else
  before="$(cksum < "$tmp/r26.md")"
  ps round "$tmp/r26.md" task-a >/dev/null 2>&1; rc=$?
  chk "unwritable plan exits 2" "$rc" "2"
  chk "unwritable plan unchanged" "$(cksum < "$tmp/r26.md")" "$before"
fi
chmod u+w "$tmp/r26.md"

echo
echo "T27: round argument errors and usage"
mkrr "$tmp/r27.md" running ""
ps round "$tmp/r27.md" >/dev/null 2>&1; chk "no id exits 2" "$?" "2"
ps round "$tmp/r27.md" task-a extra >/dev/null 2>&1; chk "extra arg exits 2" "$?" "2"
ps round "$tmp/r27.md" nope >/dev/null 2>&1; chk "unknown id exits 2" "$?" "2"
out="$(sh "$SCRIPT" 2>&1)"; rc=$?
chk "no args exits 2" "$rc" "2"
has "usage lists round" "$out" "plan-state round"
has "usage lists rules 1-5 and 7-15" "$out" "rules 1-5 and 7-15"


# T28 helpers. pf_head FILE: frontmatter and a mermaid block. pf_task FILE ID STATUS FILES:
# a task heading and its yaml; the caller then appends the task's text.
pf_head() { printf -- '---\ntitle: pf\ncreated: 2026-11-12\n---\n\n```mermaid\nflowchart TD\n```\n\n## Tasks\n\n' > "$1"; }
pf_task() { printf '## Task: %s\n\n```yaml\nid: %s\ndepends_on: %s\nfiles: [%s]\nstatus: %s\n```\n\n' "$2" "$2" "${5:-[]}" "$4" "$3" >> "$1"; }
# pf_run DIR PLAN [ARGS]: run preflight from inside DIR (not a git repo); sets out and rc
pf_run() { pfd="$1"; pfp="$2"; shift 2; out="$(cd "$pfd" && ps preflight "$pfp" "$@" 2>&1)"; rc=$?; }

echo
echo "T28: preflight, the path rule and P3"
pf="$tmp/pf"; mkdir -p "$pf/lib" "$pf/data/v1.d"; printf 'one\ntwo\n' > "$pf/lib/two.sh"

pf_head "$pf/benign.md"; pf_task "$pf/benign.md" task-x pending "out.txt"
cat >> "$pf/benign.md" <<'EOT'
Pick `and/or`, `7/7` and `missing/extra`; the helper is `lib/two.sh.`

```sh
cp lib/nowhere.sh out.txt
```
EOT
pf_run "$pf" benign.md
chk "benign exits 0" "$rc" "0"
chk "benign prints exactly one P3 warning" "$(printf '%s\n' "$out" | rg -c 'P3: warning:')" "1"
chk "benign prints no line without warning:" "$(printf '%s\n' "$out" | rg -v 'warning:' | wc -l | tr -d ' ')" "0"
has "benign warning names the code-block path" "$out" "plan-state: preflight: P3: warning: task-x cites lib/nowhere.sh, which does not exist and no task creates"

pf_head "$pf/abs.md"; pf_task "$pf/abs.md" task-x pending "out.txt"
printf 'Read `lib/gone.sh:4` first.\n' >> "$pf/abs.md"
pf_run "$pf" abs.md
chk "absent path:N" "$rc:$out" "1:plan-state: preflight: P3: task-x cites lib/gone.sh:4, which does not exist and no task creates"
out="$(cd "$pf" && $ALTSH "$SCRIPT" preflight abs.md 2>&1)"; rc=$?
chk "absent path:N under $ALTSH" "$rc:$out" "1:plan-state: preflight: P3: task-x cites lib/gone.sh:4, which does not exist and no task creates"

pf_head "$pf/twice.md"; pf_task "$pf/twice.md" task-x pending "out.txt"
printf 'See `lib/twice.sh` and then `lib/twice.sh:7`.\n' >> "$pf/twice.md"
pf_run "$pf" twice.md
chk "bare then suffixed: one line, exit 1" "$rc:$(printf '%s\n' "$out" | rg -c 'lib/twice.sh')" "1:1"
hasnt "bare then suffixed: not a warning" "$out" "warning:"
has "bare then suffixed: shows the suffixed citation" "$out" "cites lib/twice.sh:7,"

for c in 5 2-5 0 3-1 2 1-2; do
  pf_head "$pf/sfx.md"; pf_task "$pf/sfx.md" task-x pending "out.txt"
  printf 'See `lib/two.sh:%s`.\n' "$c" >> "$pf/sfx.md"
  pf_run "$pf" sfx.md
  case "$c" in
    5|2-5) chk "two.sh:$c is past the end" "$rc:$out" "1:plan-state: preflight: P3: task-x cites lib/two.sh:$c, past the end of the file (2 lines)" ;;
    0|3-1) chk "two.sh:$c is not a line range" "$rc:$out" "1:plan-state: preflight: P3: task-x cites lib/two.sh:$c, which is not a line range" ;;
    *)     chk "two.sh:$c prints nothing" "$rc:$out" "0:" ;;
  esac
done

pf_head "$pf/dir.md"; pf_task "$pf/dir.md" task-x pending "out.txt"
printf 'Look at `data/v1.d:3`.\n' >> "$pf/dir.md"
pf_run "$pf" dir.md
chk "directory with a suffix" "$rc:$out" "1:plan-state: preflight: P3: task-x cites data/v1.d:3, which is a directory"
pf_head "$pf/dirb.md"; pf_task "$pf/dirb.md" task-x pending "out.txt"
printf 'Look at `data/v1.d`.\n' >> "$pf/dirb.md"
pf_run "$pf" dirb.md
chk "directory cited bare prints nothing" "$rc:$out" "0:"

pf_head "$pf/own.md"; pf_task "$pf/own.md" task-x pending "lib/new.sh"
printf 'Create `lib/new.sh:9`.\n' >> "$pf/own.md"
pf_task "$pf/own.md" task-y pending "other.txt"
printf 'Read `lib/gone.sh:4`.\n' >> "$pf/own.md"
pf_run "$pf" own.md
chk "own declared path skipped, other task still reports" "$rc:$out" "1:plan-state: preflight: P3: task-y cites lib/gone.sh:4, which does not exist and no task creates"

pf_head "$pf/decl.md"; pf_task "$pf/decl.md" task-x pending "other.txt" "[task-y]"
printf 'Read `lib/later.sh:4`.\n' >> "$pf/decl.md"
pf_task "$pf/decl.md" task-y done "lib/later.sh"
pf_run "$pf" decl.md
chk "a path another task declares is not missing" "$rc:$out" "0:"

pf_head "$pf/st.md"; pf_task "$pf/st.md" task-d done "d.txt"
printf 'Read `lib/gone.sh:4`.\n' >> "$pf/st.md"
pf_task "$pf/st.md" task-p pending "p.txt"
printf 'Read `lib/gone.sh:4`.\n' >> "$pf/st.md"
pf_run "$pf" st.md
chk "done text not judged, pending text is" "$rc:$out" "1:plan-state: preflight: P3: task-p cites lib/gone.sh:4, which does not exist and no task creates"

pf_head "$pf/sec.md"; pf_task "$pf/sec.md" task-x pending "out.txt"
printf 'Body.\n\n## Implementation\n\nUse `a/impl.sh:1`.\n\n## Contracts\n\nUse `a/con.sh:1`.\n\n## Acceptance criteria\n\nUse `a/acc.sh:1`.\n\n### Example\n\nUse `a/ex.sh:1`.\n\n## Notes\n\nUse `a/notes.sh:1`.\n' >> "$pf/sec.md"
pf_run "$pf" sec.md
chk "four sections read" "$rc:$(printf '%s\n' "$out" | rg -c 'P3: task-x cites a/(impl|con|acc|ex)\.sh:1,')" "1:4"
hasnt "text after ## Notes is not read" "$out" "notes.sh"

pf_head "$pf/ord.md"; pf_task "$pf/ord.md" task-x pending "out.txt"
printf 'First `zz/last.sh:1` then `aa/first.sh:1`.\n' >> "$pf/ord.md"
pf_run "$pf" ord.md
chk "order is first appearance, not sorted" "$(printf '%s\n' "$out" | sed 's/.*cites \([^,]*\),.*/\1/' | tr '\n' ' ')" "zz/last.sh:1 aa/first.sh:1 "

pf_head "$pf/cyc.md"; pf_task "$pf/cyc.md" task-a pending "a.txt" "[task-b]"; pf_task "$pf/cyc.md" task-b pending "b.txt" "[task-a]"
pf_run "$pf" cyc.md
chk "cycle exits 1" "$rc" "1"
has "cycle prints rule 2" "$out" "rule 2:"
hasnt "cycle prints no preflight line" "$out" "preflight: P"

pf_run "$pf" abs.md extra
chk "extra argument exits 2" "$rc" "2"

for rp in 2026-08-27-seams-and-ground-truth-dag 2026-11-12-d1-prerequisites-dag; do
  sed 's/^status: done$/status: pending/' "$REPO/docs/superpowers/plans/$rp.md" > "$tmp/$rp.md"
  se="$(cd "$REPO" && ps preflight "$tmp/$rp.md" 2>&1 >/dev/null)"
  so="$(cd "$REPO" && ps preflight "$tmp/$rp.md" 2>/dev/null)"; rc=$?
  chk "real plan $rp: stderr empty" "$se" ""
  case "$rc" in
    0) ok "real plan $rp: exit 0" ;;
    1) if printf '%s\n' "$so" | rg -q 'preflight: P'; then ok "real plan $rp: exit 1 with a P line"; else bad "real plan $rp: exit 1 without a P line: $so"; fi ;;
    *) bad "real plan $rp: exit $rc" ;;
  esac
done

echo
echo "T29: preflight P2 and P4"
P2E="plan-state: preflight: P2: task-x uses lib/made.sh, which task-y declares, but does not depend on task-y"
pf_head "$pf/p2.md"; pf_task "$pf/p2.md" task-x pending "x.txt"
printf 'Use `lib/made.sh`.\n' >> "$pf/p2.md"
pf_task "$pf/p2.md" task-y pending "lib/made.sh"
pf_run "$pf" p2.md
chk "non-ancestor declarer is an error" "$rc:$out" "1:$P2E"
out="$(cd "$pf" && $ALTSH "$SCRIPT" preflight p2.md 2>&1)"; rc=$?
chk "P2 sibling under $ALTSH" "$rc:$out" "1:$P2E"

pf_head "$pf/p2dep.md"; pf_task "$pf/p2dep.md" task-x pending "x.txt" "[task-y]"
printf 'Use `lib/made.sh`.\n' >> "$pf/p2dep.md"
pf_task "$pf/p2dep.md" task-y pending "lib/made.sh"
pf_run "$pf" p2dep.md
chk "declarer is a dependency: no line" "$rc:$out" "0:"

pf_head "$pf/p2g.md"; pf_task "$pf/p2g.md" task-y pending "lib/made.sh"
pf_task "$pf/p2g.md" task-x pending "x.txt" "[task-y]"
pf_task "$pf/p2g.md" task-z pending "z.txt" "[task-x]"
printf 'Use `lib/made.sh`.\n' >> "$pf/p2g.md"
pf_run "$pf" p2g.md
chk "grand-ancestor declarer: no line" "$rc:$out" "0:"

pf_head "$pf/p2d.md"; pf_task "$pf/p2d.md" task-x pending "x.txt"
printf 'Use `lib/made.sh`.\n' >> "$pf/p2d.md"
pf_task "$pf/p2d.md" task-y pending "lib/made.sh" "[task-x]"
pf_run "$pf" p2d.md
chk "descendant-only declarer is a warning" "$rc:$out" "0:plan-state: preflight: P2: warning: task-x uses lib/made.sh, which task-y declares, but task-y depends on task-x"

pf_head "$pf/p2m.md"; pf_task "$pf/p2m.md" task-x pending "x.txt"
printf 'Use `lib/made.sh`.\n' >> "$pf/p2m.md"
pf_task "$pf/p2m.md" task-d pending "lib/made.sh" "[task-x, task-s]"
pf_task "$pf/p2m.md" task-s pending "lib/made.sh"
pf_run "$pf" p2m.md
chk "mixed declarers: error naming the non-descendant" "$rc:$out" "1:plan-state: preflight: P2: task-x uses lib/made.sh, which task-s declares, but does not depend on task-s"

pf_head "$pf/p2p3.md"; pf_task "$pf/p2p3.md" task-x pending "x.txt"
printf 'Read `lib/gone.sh:4` and `lib/made.sh`.\n' >> "$pf/p2p3.md"
pf_task "$pf/p2p3.md" task-y pending "lib/made.sh"
pf_run "$pf" p2p3.md
chk "P3 and P2 in one run" "$rc:$out" "1:plan-state: preflight: P3: task-x cites lib/gone.sh:4, which does not exist and no task creates
$P2E"

P4W="plan-state: preflight: P4: warning: task-x reads lib/two.sh while task-w, which can run at the same time, changes it"
for st in pending running done; do
  pf_head "$pf/p4.md"; pf_task "$pf/p4.md" task-x pending "x.txt"
  printf 'Read `lib/two.sh`.\n' >> "$pf/p4.md"
  pf_task "$pf/p4.md" task-w "$st" "lib/two.sh"
  pf_run "$pf" p4.md
  case "$st" in
    done) chk "P4: declarer $st prints nothing" "$rc:$out" "0:" ;;
    *)    chk "P4: declarer $st warns" "$rc:$out" "0:$P4W" ;;
  esac
done
pf_head "$pf/p4d.md"; pf_task "$pf/p4d.md" task-x pending "x.txt" "[task-w]"
printf 'Read `lib/two.sh`.\n' >> "$pf/p4d.md"
pf_task "$pf/p4d.md" task-w pending "lib/two.sh"
pf_run "$pf" p4d.md
chk "P4: dependent task prints nothing" "$rc:$out" "0:"

pf_head "$pf/p3p4.md"; pf_task "$pf/p3p4.md" task-w pending "lib/two.sh"
pf_task "$pf/p3p4.md" task-x pending "x.txt"
printf 'Read `lib/two.sh:5`.\n' >> "$pf/p3p4.md"
pf_run "$pf" p3p4.md
chk "P3 prints before P4 on one path" "$rc:$out" "1:plan-state: preflight: P3: task-x cites lib/two.sh:5, past the end of the file (2 lines)
plan-state: preflight: P4: warning: task-x reads lib/two.sh:5 while task-w, which can run at the same time, changes it"

echo
echo "T30: preflight P1"
pf3="$tmp/pf3"; mkdir -p "$pf3/lib" "$pf3/docs"; printf 'x\n' > "$pf3/lib/greet.sh"
P1L="plan-state: preflight: P1: warning: task-rename says to edit lib/greet.sh, which is not in its files:"
# p1_run TEXT [FILES]: one pending task whose text is TEXT
p1_run() { pf_head "$pf3/p.md"; pf_task "$pf3/p.md" task-rename pending "${2-docs/usage.md}"; printf '%s\n' "$1" >> "$pf3/p.md"; pf_run "$pf3" p.md; }
p1_run 'Rename the function `greet` to `say_hello` in `lib/greet.sh`.'
chk "rename case: one P1 warning" "$rc:$out" "0:$P1L"
out="$(cd "$pf3" && $ALTSH "$SCRIPT" preflight p.md 2>&1)"; rc=$?
chk "rename case under $ALTSH" "$rc:$out" "0:$P1L"

mv "$pf3/lib/greet.sh" "$pf3/lib/greet.sh.bak"
p1_run 'Rename the function `greet` to `say_hello` in `lib/greet.sh`.'
chk "absent: P1 before P3 warning" "$rc:$out" "0:$P1L
plan-state: preflight: P3: warning: task-rename cites lib/greet.sh, which does not exist and no task creates"
p1_run 'Rename the function `greet` to `say_hello` in `lib/greet.sh:4`.'
chk "absent with :4: P1 warning before P3 error" "$rc:$out" "1:plan-state: preflight: P1: warning: task-rename says to edit lib/greet.sh:4, which is not in its files:
plan-state: preflight: P3: task-rename cites lib/greet.sh:4, which does not exist and no task creates"
mv "$pf3/lib/greet.sh.bak" "$pf3/lib/greet.sh"

for v in Updated MODIFY rewrote 'appends to' 'Do not edit the header; update'; do
  p1_run "$v \`lib/greet.sh\`."
  chk "verb '$v' prints P1" "$rc:$out" "0:$P1L"
done
for v in 'Do not edit' 'Never modify' "Don't change"; do
  p1_run "$v \`lib/greet.sh\`."
  chk "negated '$v' prints nothing" "$rc:$out" "0:"
done
p1_run '`lib/greet.sh` is updated by the hook.'
chk "verb after the path prints nothing" "$rc:$out" "0:"
p1_run 'Update the file.
`lib/greet.sh`'
chk "verb on the line above prints nothing" "$rc:$out" "0:"
p1_run '```sh
# update lib/greet.sh
```'
chk "verb in a code block prints P1" "$rc:$out" "0:$P1L"
p1_run 'Rename the function in `lib/greet.sh`.' "lib/greet.sh"
chk "declared path prints nothing" "$rc:$out" "0:"
for v in 'See the changelog' 'Open the editor' 'The preupdate hook'; do
  p1_run "$v \`lib/greet.sh\`."
  chk "'$v' is no verb" "$rc:$out" "0:"
done

echo
echo "T31: round rewrites a quoted count"
for q in '"2"' "'2'"; do
  mkrr "$tmp/r31.md" running "$q"
  out="$(ps round "$tmp/r31.md" task-a 2>&1)"; rc=$?
  chk "round on $q counts to 3" "$rc:$out" "0:3"
  chk "round on $q writes review_rounds: 3" "$(awk '/^review_rounds:/ { print }' "$tmp/r31.md")" "review_rounds: 3"
  out="$(ps round "$tmp/r31.md" task-a 2>&1)"; rc=$?
  chk "round after $q reaches the cap" "$rc" "1"
done

echo
echo "T32: preflight reads ./ in files: as the same path"
p1_run 'Rename the function `greet` to `say_hello` in `lib/greet.sh`.' ./lib/greet.sh
chk "./lib/greet.sh in files: owns lib/greet.sh" "$rc:$out" "0:"
p1_run 'Rename the function `greet` to `say_hello` in `./lib/greet.sh`.' lib/greet.sh
chk "./ in the text matches files:" "$rc:$out" "0:"

echo "RESULT: $passes passed, $fails failed"
[ "$fails" -eq 0 ]

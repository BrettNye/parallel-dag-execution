#!/usr/bin/env bash
# Test suite for skills/auditing-artifacts/resolve-declared-paths
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO/skills/auditing-artifacts/resolve-declared-paths"
[ -f "$SCRIPT" ] || { echo "FAIL: resolver not found at $SCRIPT" >&2; exit 1; }
# A second POSIX shell, to catch bashisms. dash if present; otherwise sh, which
# still exercises the assertions rather than reporting a misleading rc=127.
if command -v dash >/dev/null 2>&1; then ALTSH=dash; else ALTSH=sh; echo "NOTE: dash not installed - alt-shell cases run under sh"; fi
fails=0; passes=0
ok()   { passes=$((passes+1)); echo "  PASS: $1"; }
bad()  { fails=$((fails+1));  echo "  FAIL: $1"; }
chk()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$3] got [$2])"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# table1 = data rows of table 1 (between its header sep and the CHARTER heading)
table1() { printf '%s\n' "$1" | awk '/^\| path \| declared at \| on disk \|$/{t=1;next} /^CHARTER CITATIONS/{t=0} t && /^\|/ && !/^\|---/'; }
table2() { printf '%s\n' "$1" | awk '/^\| entry \| cite \| status \|$/{t=1;next} t && /^\|/ && !/^\|---/'; }
# pathcells = just the first (path) cell of each table-1 data row
pathcells() { printf '%s\n' "$1" | awk -F'[|]' 'NF>1 { c=$2; sub(/^ /,"",c); sub(/ $/,"",c); if (c != "") print c }'; }

echo "T1: three declared paths - existing, missing, glob"
mkdir -p "$tmp/repo/src"; : > "$tmp/repo/src/real.ts"
cat > "$tmp/t1.md" <<'EOF'
files:
  - src/real.ts
  - src/gone.ts
  - src/**/*.ts
EOF
out="$(sh "$SCRIPT" "$tmp/t1.md" "$tmp/repo")"; rc=$?
chk "exit 0" "$rc" "0"
chk "table 1 has exactly 2 data rows" "$(table1 "$out" | grep -c .)" "2"
chk "glob absent from whole output" "$(printf '%s\n' "$out" | grep -c '\*\*')" "0"
if table1 "$out" | grep -q 'src/real\.ts .*EXISTS'; then ok "existing path EXISTS"; else bad "existing path not EXISTS"; fi
if table1 "$out" | grep -q 'src/gone\.ts .*ABSENT'; then ok "missing path ABSENT"; else bad "missing path not ABSENT"; fi


echo
echo "T2: a declared path that resolves to a directory reads DIR"
mkdir -p "$tmp/repo/docs/notes"
cat > "$tmp/t2.md" <<'EOF'
files:
  - docs/notes
  - src/real.ts
EOF
out="$(sh "$SCRIPT" "$tmp/t2.md" "$tmp/repo")"
if table1 "$out" | grep -q '| docs/notes | .* | DIR |'; then ok "directory reads DIR"; else bad "directory not DIR: $(table1 "$out")"; fi
if table1 "$out" | grep -q '| src/real.ts | .* | EXISTS |'; then ok "file still EXISTS"; else bad "file not EXISTS"; fi

echo
echo "T3: the three declared-at forms"
cat > "$tmp/t3.md" <<'EOF'
---
title: demo
spec: docs/specs/demo-spec.md
created: 2026-08-28
---

## Context

The resolver reads `src/prose-only.ts` today, and ignores `src/**/*.ts` globs,
`https://example.com/x.ts` URLs and `docs/what?.md` wildcards.

## Task: build it

```yaml
id: task-7
depends_on: []
files:
  - src/real.ts
status: pending
```
EOF
out="$(sh "$SCRIPT" "$tmp/t3.md" "$tmp/repo")"
rows="$(table1 "$out")"
chk "three rows" "$(printf '%s\n' "$rows" | grep -c .)" "3"
if printf '%s\n' "$rows" | grep -q '| docs/specs/demo-spec.md | frontmatter spec: | ABSENT |'; then ok "frontmatter spec: form"; else bad "frontmatter spec: form missing"; fi
if printf '%s\n' "$rows" | grep -q '| src/prose-only.ts | prose L9 | ABSENT |'; then ok "prose L<n> form"; else bad "prose L<n> form missing"; fi
if printf '%s\n' "$rows" | grep -q '| src/real.ts | task-7 files: | EXISTS |'; then ok "task-<id> files: form"; else bad "task-<id> files: form missing"; fi
chk "no bare-line-number declared-at" "$(printf '%s\n' "$rows" | awk -F"|" '$3 ~ /^ *[0-9]+ *$/' | grep -c .)" "0"
chk "no glob/URL/wildcard rows" "$(printf '%s\n' "$rows" | grep -cE '\*|\?|://')" "0"

# ---- charter fixtures -------------------------------------------------------
cat > "$tmp/repo/src/widget.ts" <<'EOF'
// layer boundaries are enforced here
export class Widget {
  render() {}
}
// trailing
EOF

echo
echo "T4: table 2 statuses OK / OK / OK-UNANCHORED"
cat > "$tmp/c4.md" <<'EOF'
# Audit charter - demo

## Enforcement map

| Rule | Enforced by | Consequence |
|---|---|---|
| layer boundaries | `src/widget.ts:2` depConstraints | drift only |

## Hard invariants

- **Widget renders** - `src/widget.ts:2`. Breaking it: nothing catches it.

## Notes

Some prose citing `src/widget.ts:2` with no entry label at all.
EOF
out="$(sh "$SCRIPT" "$tmp/t3.md" "$tmp/repo" "$tmp/c4.md")"; rc=$?
chk "exit 0 with charter" "$rc" "0"
if printf '%s\n' "$out" | grep -qx '| entry | cite | status |'; then ok "table 2 header exact"; else bad "table 2 header wrong"; fi
rows2="$(table2 "$out")"
chk "three citation rows" "$(printf '%s\n' "$rows2" | grep -c .)" "3"
chk "two OK rows" "$(printf '%s\n' "$rows2" | grep -c '| OK |')" "2"
chk "one OK-UNANCHORED row" "$(printf '%s\n' "$rows2" | grep -c '| OK-UNANCHORED |')" "1"
chk "zero SUSPECT rows" "$(printf '%s\n' "$rows2" | grep -c '| SUSPECT |')" "0"
if printf '%s\n' "$rows2" | grep -q '^| Widget renders | src/widget.ts:2 | OK |$'; then ok "bullet entry OK"; else bad "bullet entry row wrong"; fi
if printf '%s\n' "$rows2" | grep -q '^| layer boundaries | src/widget.ts:2 | OK |$'; then ok "table-row entry OK"; else bad "table-row entry row wrong"; fi

echo
echo "T5: MOVED and GONE"
cat > "$tmp/c5.md" <<'EOF'
- **Widget line far** - `src/widget.ts:999`.
- **Gone thing** - `src/deleted.ts:3`.
EOF
out="$(sh "$SCRIPT" "$tmp/t3.md" "$tmp/repo" "$tmp/c5.md")"
rows2="$(table2 "$out")"
if printf '%s\n' "$rows2" | grep -q '^| Widget line far | src/widget.ts:999 | MOVED |$'; then ok "past-EOF line MOVED"; else bad "past-EOF not MOVED: $rows2"; fi
if printf '%s\n' "$rows2" | grep -q '^| Gone thing | src/deleted.ts:3 | GONE |$'; then ok "deleted file GONE"; else bad "deleted file not GONE: $rows2"; fi

echo
echo "T6: SUSPECT fires positively, distinguished from OK-UNANCHORED"
cat > "$tmp/c6.md" <<'EOF'
- **Retry backoff scheduler** - `src/widget.ts:3`.
- `src/widget.ts:3` cited here with no bolded name.
EOF
out="$(sh "$SCRIPT" "$tmp/t3.md" "$tmp/repo" "$tmp/c6.md")"
rows2="$(table2 "$out")"
chk "two rows" "$(printf '%s\n' "$rows2" | grep -c .)" "2"
chk "exactly one SUSPECT" "$(printf '%s\n' "$rows2" | grep -c '| SUSPECT |')" "1"
if printf '%s\n' "$rows2" | grep -q '^| Retry backoff scheduler | src/widget.ts:3 | SUSPECT |$'; then ok "anchored-but-mismatched is SUSPECT"; else bad "SUSPECT did not fire: $rows2"; fi
chk "unlabeled sibling is OK-UNANCHORED" "$(printf '%s\n' "$rows2" | grep -c '| OK-UNANCHORED |')" "1"

echo
echo "T7: usage and unreadable-artifact exits"
err="$(sh "$SCRIPT" "$tmp/t3.md" 2>&1 >/dev/null)"; rc=$?
chk "one argument exits 2" "$rc" "2"
if printf '%s\n' "$err" | grep -q 'usage'; then ok "usage message on stderr"; else bad "no usage message"; fi
err="$(sh "$SCRIPT" "$tmp/nope.md" "$tmp/repo" 2>&1 >/dev/null)"; rc=$?
chk "unreadable artifact exits 1" "$rc" "1"
if printf '%s\n' "$err" | grep -q "cannot read .*nope.md"; then ok "unreadable message names the file"; else bad "unreadable message wrong: $err"; fi

echo "T8: placeholder paths are never reported ABSENT"
cat > "$tmp/t8.md" <<'EOF'
Plans live at `docs/superpowers/plans/YYYY-MM-DD-<topic>-dag.md` by default.
Mirror `src/real.ts` when you write one.
EOF
out="$(sh "$SCRIPT" "$tmp/t8.md" "$tmp/repo")"
rows="$(table1 "$out")"
chk "placeholder token skipped" "$(printf '%s\n' "$rows" | grep -c '<')" "0"
chk "one real row survives" "$(printf '%s\n' "$rows" | grep -c .)" "1"

echo "T9: a directory passed as the artifact exits 1, not a silent empty run"
err="$(sh "$SCRIPT" "$tmp/repo" "$tmp/repo" 2>&1 >/dev/null)"; rc=$?
chk "directory artifact exits 1" "$rc" "1"
if printf '%s\n' "$err" | grep -q 'cannot read'; then ok "directory artifact names the problem"; else bad "no message: $err"; fi

echo "T10: CRLF artifact and empty artifact"
printf 'files:\r\n  - src/real.ts\r\n' > "$tmp/t10.md"
out="$(sh "$SCRIPT" "$tmp/t10.md" "$tmp/repo")"
if table1 "$out" | grep -q '^| src/real.ts | task-unknown files: | EXISTS |$'; then ok "CRLF row clean"; else bad "CRLF row: $(table1 "$out" | cat -A)"; fi
: > "$tmp/empty.md"
out="$(sh "$SCRIPT" "$tmp/empty.md" "$tmp/repo")"; rc=$?
chk "empty artifact exits 0" "$rc" "0"
chk "empty artifact, no table-1 rows" "$(table1 "$out" | grep -c .)" "0"
chk "empty artifact still emits both headers" "$(printf '%s\n' "$out" | grep -cE '^\| (path \| declared at \| on disk|entry \| cite \| status) \|$')" "2"

echo "T11: ./sibling tokens resolve against the artifact's own directory"
mkdir -p "$tmp/docs"
: > "$tmp/docs/sibling.md"
cat > "$tmp/docs/t11.md" <<'EOF'
The lenses live in `./sibling.md` and never in `./nope.md`.
EOF
out="$(sh "$SCRIPT" "$tmp/docs/t11.md" "$tmp/repo")"
rows="$(table1 "$out")"
if printf '%s\n' "$rows" | grep -q '^| ./sibling.md | prose L1 | EXISTS |$'; then ok "existing sibling EXISTS"; else bad "sibling not EXISTS: $rows"; fi
if printf '%s\n' "$rows" | grep -q '^| ./nope.md | prose L1 | ABSENT |$'; then ok "missing sibling still ABSENT"; else bad "missing sibling wrong: $rows"; fi

echo
echo "T12: a backticked shell command with an embedded path is not a path-shaped token"
cat > "$tmp/t12.md" <<'EOF'
- `grep -c 'Seven lenses' src/real.ts` returns `0`.
- `grep -rc 'S1-S15' src/real.ts src/gone.ts` returns `0`.
- Mirror `src/real.ts` when you write one.
EOF
out="$(sh "$SCRIPT" "$tmp/t12.md" "$tmp/repo")"
rows="$(table1 "$out")"
chk "no command row in table 1" "$(printf '%s\n' "$rows" | grep -c 'grep')" "0"
chk "no whitespace-bearing path cell" "$(pathcells "$rows" | grep -c ' ')" "0"
chk "the one real prose path still resolves" "$(printf '%s\n' "$rows" | grep -c .)" "1"
if printf '%s\n' "$rows" | grep -q '^| src/real.ts | prose L3 | EXISTS |$'; then ok "real prose path survives"; else bad "real prose path lost: $rows"; fi

echo
echo "T13: files: inside a non-YAML fence is illustration, not a declaration"
cat > "$tmp/t13.md" <<'EOF'
## Task: demo

```yaml
id: task-real
files:
  - src/real.ts
```

Minimum-viable failing test:

```sh
cat > "$tmp/plan.md" <<'INNER'
files:
  - src/fake-heredoc.ts
  - src/gone.ts
INNER
```

```markdown
files:
  - src/fake-example.ts
```
EOF
out="$(sh "$SCRIPT" "$tmp/t13.md" "$tmp/repo")"
rows="$(table1 "$out")"
chk "sh-fenced heredoc entry not harvested" "$(printf '%s\n' "$rows" | grep -c 'fake-heredoc')" "0"
chk "markdown-fenced example entry not harvested" "$(printf '%s\n' "$rows" | grep -c 'fake-example')" "0"
chk "no entry misattributed to task-real" "$(printf '%s\n' "$rows" | grep -c 'src/gone.ts')" "0"
chk "exactly one declared row" "$(printf '%s\n' "$rows" | grep -c .)" "1"
if printf '%s\n' "$rows" | grep -q '^| src/real.ts | task-real files: | EXISTS |$'; then ok "yaml-fenced task block still harvested"; else bad "real task block lost: $rows"; fi

echo
echo "T14: an unfenced files: block is still harvested"
out="$(sh "$SCRIPT" "$tmp/t1.md" "$tmp/repo")"
chk "unfenced files: block still yields 2 rows" "$(table1 "$out" | grep -c .)" "2"


echo
echo "T15: an oversized cited line number is MOVED, not a false SUSPECT"
cat > "$tmp/repo/src/six.ts" <<'EOF'
line one alpha
the scheduler lives here
line three beta
line four gamma
line five delta
line six epsilon
EOF
cat > "$tmp/c15.md" <<'EOF'
- **Scheduler contract** - `src/six.ts:999999999999999999`.
- **Scheduler contract two** - `src/six.ts:9999999999999999999`.
- **Scheduler contract three** - `src/six.ts:99999999999999999999`.
EOF
out="$(sh "$SCRIPT" "$tmp/t3.md" "$tmp/repo" "$tmp/c15.md" 2>"$tmp/e15.txt")"; rc=$?
rows2="$(table2 "$out")"
chk "18-digit cite is MOVED" "$(printf '%s\n' "$rows2" | grep -c '^| Scheduler contract | src/six.ts:999999999999999999 | MOVED |$')" "1"
chk "19-digit cite is MOVED" "$(printf '%s\n' "$rows2" | grep -c '^| Scheduler contract two | src/six.ts:9999999999999999999 | MOVED |$')" "1"
chk "20-digit cite is MOVED" "$(printf '%s\n' "$rows2" | grep -c '^| Scheduler contract three | src/six.ts:99999999999999999999 | MOVED |$')" "1"
chk "no SUSPECT from an oversized cite" "$(printf '%s\n' "$rows2" | grep -c '| SUSPECT |')" "0"
chk "oversized-cite run exits 0" "$rc" "0"
chk "oversized-cite run leaves stderr empty" "$(wc -c < "$tmp/e15.txt" | tr -d ' ')" "0"
out="$("$ALTSH" "$SCRIPT" "$tmp/t3.md" "$tmp/repo" "$tmp/c15.md" 2>"$tmp/e15d.txt")"; rc=$?
chk "dash: oversized cite exits 0" "$rc" "0"
chk "dash: oversized cite leaves stderr empty" "$(wc -c < "$tmp/e15d.txt" | tr -d ' ')" "0"
chk "dash: 20-digit cite is MOVED" "$(table2 "$out" | grep -c '^| Scheduler contract three | src/six.ts:99999999999999999999 | MOVED |$')" "1"

echo
echo "T16: the anchor window is exactly +/-2 and the last line is in range"
cat > "$tmp/c16.md" <<'EOF'
- **Scheduler contract** - `src/six.ts:4`.
- **Scheduler contract two** - `src/six.ts:5`.
- **Scheduler contract three** - `src/six.ts:6`.
- **Scheduler contract four** - `src/six.ts:7`.
EOF
out="$(sh "$SCRIPT" "$tmp/t3.md" "$tmp/repo" "$tmp/c16.md")"
rows2="$(table2 "$out")"
if printf '%s\n' "$rows2" | grep -q '^| Scheduler contract | src/six.ts:4 | OK |$'; then ok "anchor 2 lines below cite is OK"; else bad "cite :4 not OK: $rows2"; fi
if printf '%s\n' "$rows2" | grep -q '^| Scheduler contract two | src/six.ts:5 | SUSPECT |$'; then ok "anchor 3 lines below cite is SUSPECT"; else bad "cite :5 not SUSPECT: $rows2"; fi
if printf '%s\n' "$rows2" | grep -q '^| Scheduler contract three | src/six.ts:6 | SUSPECT |$'; then ok "last line of file is in range"; else bad "cite :6 not in range: $rows2"; fi
if printf '%s\n' "$rows2" | grep -q '^| Scheduler contract four | src/six.ts:7 | MOVED |$'; then ok "one past last line is MOVED"; else bad "cite :7 not MOVED: $rows2"; fi


echo
echo "T17: dot-prefixed cite paths resolve; bare decimals never fabricate a row"
mkdir -p "$tmp/repo/.claude-plugin"
printf '{ "name": "demo-plugin" }\n' > "$tmp/repo/.claude-plugin/plugin.json"
printf '# git attributes for demo\n' > "$tmp/repo/.gitattributes"
cat > "$tmp/c17.md" <<'EOF'
- **Plugin manifest** - `.claude-plugin/plugin.json:1`.
- **Git attributes** - `.gitattributes:1`.
- **Version drift** - the text moved from 3.14:30 to 3.9 somewhere in prose.
- **Timing note** - at step 10:30 nothing at all happens here.
- **Ellipsis** - a bare ...:5 is not a citation either.
EOF
out="$(sh "$SCRIPT" "$tmp/t3.md" "$tmp/repo" "$tmp/c17.md" 2>"$tmp/e17.txt")"; rc=$?
rows2="$(table2 "$out")"
chk "dot-cite run exits 0" "$rc" "0"
chk "dot-cite run leaves stderr empty" "$(wc -c < "$tmp/e17.txt" | tr -d ' ')" "0"
chk "exactly two citation rows" "$(printf '%s\n' "$rows2" | grep -c .)" "2"
if printf '%s\n' "$rows2" | grep -q '^| Plugin manifest | \.claude-plugin/plugin\.json:1 | OK |$'; then ok "dot-prefixed dir cite resolves whole"; else bad "dot-prefixed dir cite wrong: $rows2"; fi
if printf '%s\n' "$rows2" | grep -q '^| Git attributes | \.gitattributes:1 | OK |$'; then ok "dotfile cite resolves whole"; else bad "dotfile cite wrong: $rows2"; fi
chk "leading dot never truncated from a cite cell" "$(printf '%s\n' "$rows2" | grep -c ' claude-plugin/')" "0"
chk "no GONE fabricated for an existing dotfile" "$(printf '%s\n' "$rows2" | grep -c '| GONE |')" "0"
chk "bare decimal 3.14:30 yields no row" "$(printf '%s\n' "$rows2" | grep -c '3\.14')" "0"
chk "bare 10:30 yields no row" "$(printf '%s\n' "$rows2" | grep -c '10:30')" "0"
chk "bare ...:5 yields no row" "$(printf '%s\n' "$rows2" | grep -c '\.\.\.')" "0"

echo
echo "T18: an unusable repo root is refused, never resolved into false ABSENT"
out="$(sh "$SCRIPT" "$tmp/t1.md" "$tmp/no-such-root" 2>"$tmp/e18.txt")"; rc=$?
err="$(cat "$tmp/e18.txt")"
chk "nonexistent repo root exits 1" "$rc" "1"
if printf '%s\n' "$err" | grep -q 'repo root is not a directory'; then ok "root message names the problem"; else bad "no root message: $err"; fi
if printf '%s\n' "$err" | grep -q 'no-such-root'; then ok "root message names the root"; else bad "root message omits root: $err"; fi
chk "bad root emits no table rows at all" "$(printf '%s\n' "$out" | grep -c '^|')" "0"
err="$(sh "$SCRIPT" "$tmp/t1.md" "$tmp/t1.md" 2>&1 >/dev/null)"; rc=$?
chk "a file as repo root exits 1" "$rc" "1"
if printf '%s\n' "$err" | grep -q 'repo root is not a directory'; then ok "file-as-root names the problem"; else bad "file-as-root message wrong: $err"; fi
err="$("$ALTSH" "$SCRIPT" "$tmp/t1.md" "$tmp/no-such-root" 2>&1 >/dev/null)"; rc=$?
chk "dash: nonexistent repo root exits 1" "$rc" "1"

echo
echo "T19: ~~~ fences honour the same language allowlist as backtick fences"
cat > "$tmp/t19.md" <<'T19EOF'
## Task: tilde demo

~~~sh
# see `src/tilde-prose.ts`
files:
  - src/fabricated-tilde.ts
~~~

~~~markdown
```yaml
id: task-fake
files:
  - src/fabricated-nested.ts
```
~~~

````markdown
```yaml
id: task-fake-two
files:
  - src/fabricated-backtick.ts
```
````

~~~yaml
id: task-tilde-real
files:
  - src/real.ts
~~~

```yaml
id: task-backtick-real
files:
  - docs/notes
```
T19EOF
out="$(sh "$SCRIPT" "$tmp/t19.md" "$tmp/repo")"
rows="$(table1 "$out")"
chk "tilde-sh files: entry not harvested" "$(printf '%s\n' "$rows" | grep -c 'fabricated-tilde')" "0"
chk "prose inside a tilde fence not harvested" "$(printf '%s\n' "$rows" | grep -c 'tilde-prose')" "0"
chk "backtick fence nested in a tilde fence stays closed" "$(printf '%s\n' "$rows" | grep -c 'fabricated-nested')" "0"
chk "shorter backtick fence nested in a longer one stays closed" "$(printf '%s\n' "$rows" | grep -c 'fabricated-backtick')" "0"
chk "exactly two declared rows" "$(printf '%s\n' "$rows" | grep -c .)" "2"
if printf '%s\n' "$rows" | grep -q '^| src/real.ts | task-tilde-real files: | EXISTS |$'; then ok "~~~yaml task block harvested"; else bad "~~~yaml block lost: $rows"; fi
if printf '%s\n' "$rows" | grep -q '^| docs/notes | task-backtick-real files: | DIR |$'; then ok "fence state survives the tilde blocks"; else bad "fence state scrambled: $rows"; fi

echo
echo "T20: the anchor window reaches BELOW the cite as far as it reaches above"
cat > "$tmp/repo/src/below.ts" <<'EOF'
line one alpha
line two beta
line three gamma
line four delta
the scheduler lives here
line six epsilon
EOF
cat > "$tmp/c20.md" <<'EOF'
- **Scheduler contract five** - `src/below.ts:3`.
- **Scheduler contract six** - `src/below.ts:2`.
EOF
out="$(sh "$SCRIPT" "$tmp/t3.md" "$tmp/repo" "$tmp/c20.md")"
rows2="$(table2 "$out")"
if printf '%s\n' "$rows2" | grep -q '^| Scheduler contract five | src/below.ts:3 | OK |$'; then ok "anchor 2 lines BELOW cite is OK"; else bad "cite :3 (anchor below) not OK: $rows2"; fi
if printf '%s\n' "$rows2" | grep -q '^| Scheduler contract six | src/below.ts:2 | SUSPECT |$'; then ok "anchor 3 lines BELOW cite is SUSPECT"; else bad "cite :2 (anchor below) not SUSPECT: $rows2"; fi

echo
echo "T21: an anchor token must be 4+ characters"
cat > "$tmp/repo/src/thr.ts" <<'EOF'
alpha beta gamma
abc marker line
delta epsilon zeta
EOF
cat > "$tmp/c21.md" <<'EOF'
- **Scheduler abc** - `src/thr.ts:2`.
EOF
out="$(sh "$SCRIPT" "$tmp/t3.md" "$tmp/repo" "$tmp/c21.md")"
rows2="$(table2 "$out")"
if printf '%s\n' "$rows2" | grep -q '^| Scheduler abc | src/thr.ts:2 | SUSPECT |$'; then ok "a 3-character label token is not an anchor"; else bad "3-char token anchored: $rows2"; fi
echo
echo "RESULT: $passes passed, $fails failed"
[ "$fails" -eq 0 ]

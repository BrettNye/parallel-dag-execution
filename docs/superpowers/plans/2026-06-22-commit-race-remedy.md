# Git Commit-Race Remedy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate git commit races among parallel implementer subagents via a committed `git-commit-safe` helper (atomic `mkdir` mutex + path-scoped commit + stale-lock breaking), wired into the implementer dispatch, verified by real concurrent-commit shell tests.

**Architecture:** One POSIX-`sh` helper script does all the work; the implementer-prompt and supporting docs are updated to route every implementer commit through it. Unlike the rest of this plugin (markdown skills with conformance fixtures), this feature has **genuinely executable tests** — shell tests that fork concurrent commits and assert no lock errors and no file bundling.

**Tech Stack:** POSIX `sh` running in git-bash on Windows (the environment implementer subagents use via the Bash tool). Git ≥ 2.x. No new dependencies.

## Global Constraints

- Helper interface is exactly: `git-commit-safe "<commit message>" <path> [<path>...]` — message first, then one or more explicit paths. (Spec §The helper.)
- The helper commits **only** the named paths via `git commit --only -m "<msg>" -- <paths>`. The `-m` MUST come before the `--` (everything after `--` is a pathspec). (Spec §The helper.)
- Mutex = atomic `mkdir` of `"$(git rev-parse --git-dir)/dag-commit.lock"`. Acquire timeout ≈ 30 s (300 tries × 0.1 s). Stale-lock threshold = 60 s. (Spec §The helper.)
- Mutex released via `trap ... EXIT INT TERM`. (Spec §The helper.)
- NEVER `git add -A` / `git add .` anywhere. Explicit paths only — enforced by the helper's interface. (Spec §Implementer-prompt change.)
- Helper lives at `skills/executing-dag-plans/git-commit-safe`; the executor injects its absolute path into each implementer dispatch. (Spec §Architecture, §path injection.)
- Additive/behavior-preserving: the controller's own behavior, the parallel-dispatch contract, file-scope tripwire, review chain, and resumability are unchanged. (Spec §Architecture.)

## How tests work here

This feature is a real shell script, so its tests are **executable** (run with `bash <test>.sh`, exit 0 = pass), unlike the markdown-skill conformance fixtures elsewhere in the repo. The doc-wiring tasks (2, 3) still verify via read-through + `grep`, since those edits are to skill markdown that an LLM executes.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `skills/executing-dag-plans/git-commit-safe` | The race-safe commit helper (mutex + path-scoped commit + stale-lock break) | 1 |
| `tests/commit-safe/concurrent-commit.test.sh` | Executable test: N concurrent commits land, no lock errors, no bundling | 1 |
| `tests/commit-safe/stale-lock.test.sh` | Executable test: a stale mutex is broken; commit succeeds | 1 |
| `skills/executing-dag-plans/implementer-prompt.md` | Route implementer commits through the helper; declare the injected helper path; inline fallback snippet | 2 |
| `skills/executing-dag-plans/SKILL.md` | Note helper-path injection (§Execution model) + a §Hard rules sentence | 3 |
| `agents/dag-implementer.md` | Commit hard-rule references the race-safe helper | 3 |

---

### Task 1: `git-commit-safe` helper + executable tests

**Files:**
- Create: `skills/executing-dag-plans/git-commit-safe`
- Test: `tests/commit-safe/concurrent-commit.test.sh`
- Test: `tests/commit-safe/stale-lock.test.sh`

**Interfaces:**
- Produces: the `git-commit-safe "<msg>" <path>...` CLI contract (consumed by Task 2's implementer-prompt and Task 3's docs). Exit 0 on success; exit 1 on mutex-timeout/git-failure; exit 2 on usage error.

- [ ] **Step 1: Write the concurrent-commit test (failing — helper doesn't exist yet)**

Create `tests/commit-safe/concurrent-commit.test.sh`:

```sh
#!/usr/bin/env sh
# Forks N concurrent git-commit-safe invocations on disjoint files and asserts:
# all land, no index.lock errors, each commit touches exactly one file.
set -eu

HELPER="$(cd "$(dirname "$0")/../../skills/executing-dag-plans" && pwd)/git-commit-safe"
[ -f "$HELPER" ] || { echo "FAIL: helper not found at $HELPER" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q
git config user.email t@t.test
git config user.name tester
echo base > base.txt && git add base.txt && git commit -qm base

N=12
i=1
while [ "$i" -le "$N" ]; do
  echo "content-$i" > "file-$i.txt"
  sh "$HELPER" "task-$i" "file-$i.txt" > "out-$i.log" 2>&1 &
  i=$((i + 1))
done
wait

fail=0

if grep -liE "index\.lock|Unable to create" out-*.log >/dev/null 2>&1; then
  echo "FAIL: index.lock error present in a commit log" >&2
  fail=1
fi

count="$(git rev-list --count HEAD)"
if [ "$count" -ne $((N + 1)) ]; then
  echo "FAIL: expected $((N + 1)) commits, got $count" >&2
  fail=1
fi

# Every non-base commit must touch exactly one file (no bundling).
for h in $(git log --format=%H "$(git rev-list --max-parents=0 HEAD)"..HEAD); do
  n="$(git show --name-only --format= "$h" | grep -c .)"
  if [ "$n" -ne 1 ]; then
    echo "FAIL: commit $h touched $n files (bundling)" >&2
    fail=1
  fi
done

[ "$fail" -eq 0 ] && echo "PASS concurrent-commit"
exit "$fail"
```

- [ ] **Step 2: Write the stale-lock test (also failing — no helper)**

Create `tests/commit-safe/stale-lock.test.sh`:

```sh
#!/usr/bin/env sh
# A stale mutex (mtime older than the 60s threshold) must be broken; commit succeeds.
set -eu

HELPER="$(cd "$(dirname "$0")/../../skills/executing-dag-plans" && pwd)/git-commit-safe"
[ -f "$HELPER" ] || { echo "FAIL: helper not found at $HELPER" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q
git config user.email t@t.test
git config user.name tester
echo base > base.txt && git add base.txt && git commit -qm base

lock="$(git rev-parse --git-dir)/dag-commit.lock"
mkdir "$lock"
# Backdate mtime beyond the 60s stale threshold (GNU touch in git-bash).
touch -d "120 seconds ago" "$lock"

echo x > f.txt
if ! sh "$HELPER" "after stale" f.txt; then
  echo "FAIL: helper did not succeed despite stale lock" >&2
  exit 1
fi

if [ "$(git rev-list --count HEAD)" -ne 2 ]; then
  echo "FAIL: commit did not land" >&2
  exit 1
fi
if [ -e "$lock" ]; then
  echo "FAIL: lock not released after commit" >&2
  exit 1
fi
echo "PASS stale-lock"
```

- [ ] **Step 3: Run both tests to verify they FAIL (no helper yet)**

Run:
```bash
bash tests/commit-safe/concurrent-commit.test.sh; echo "exit=$?"
bash tests/commit-safe/stale-lock.test.sh; echo "exit=$?"
```
Expected: both print `FAIL: helper not found ...` and `exit=1`. This is the RED state.

- [ ] **Step 4: Implement the helper**

Create `skills/executing-dag-plans/git-commit-safe`:

```sh
#!/usr/bin/env sh
# git-commit-safe — race-safe commit for parallel DAG implementer subagents.
# Usage: git-commit-safe "<commit message>" <path> [<path>...]
# Serializes commits via an atomic mkdir mutex and commits ONLY the named paths.
set -eu

if [ "$#" -lt 2 ]; then
  echo "usage: git-commit-safe \"<message>\" <path> [<path>...]" >&2
  exit 2
fi

msg="$1"
shift

git_dir="$(git rev-parse --git-dir)" || { echo "git-commit-safe: not a git repository" >&2; exit 1; }
lock="$git_dir/dag-commit.lock"
stale_seconds=60
timeout_tries=300      # ~30s at 0.1s/try
sleep_interval="0.1"

now_epoch() { date +%s; }
lock_mtime() { stat -c %Y "$lock" 2>/dev/null || echo 0; }

tries=0
while ! mkdir "$lock" 2>/dev/null; do
  mt="$(lock_mtime)"
  if [ "$mt" -ne 0 ]; then
    age=$(( $(now_epoch) - mt ))
    if [ "$age" -ge "$stale_seconds" ]; then
      rmdir "$lock" 2>/dev/null || true
      continue
    fi
  fi
  tries=$((tries + 1))
  if [ "$tries" -ge "$timeout_tries" ]; then
    echo "git-commit-safe: could not acquire commit lock after ~30s (held by another implementer?)" >&2
    exit 1
  fi
  sleep "$sleep_interval"
done
trap 'rmdir "$lock" 2>/dev/null || true' EXIT INT TERM

# Commit ONLY the named paths. --only takes the working-tree content of exactly
# these paths, ignoring any other staged content (no bundling). -m precedes --.
git commit --only -m "$msg" -- "$@"
```

Make it executable:
```bash
chmod +x skills/executing-dag-plans/git-commit-safe
```

- [ ] **Step 5: Run both tests to verify they PASS**

Run:
```bash
bash tests/commit-safe/concurrent-commit.test.sh; echo "exit=$?"
bash tests/commit-safe/stale-lock.test.sh; echo "exit=$?"
```
Expected: `PASS concurrent-commit` / `exit=0` and `PASS stale-lock` / `exit=0`.

- [ ] **Step 6: Commit**

```bash
git add skills/executing-dag-plans/git-commit-safe tests/commit-safe/concurrent-commit.test.sh tests/commit-safe/stale-lock.test.sh
git commit -m "feat(executing-dag-plans): add race-safe git-commit-safe helper + tests"
```

---

### Task 2: Route implementer commits through the helper

**Files:**
- Modify: `skills/executing-dag-plans/implementer-prompt.md` (§Context construction rules "MUST receive" list ~line 16-22; the project-conventions git-add block ~line 54-58)

**Interfaces:**
- Consumes: the `git-commit-safe "<msg>" <path>...` contract from Task 1.
- Produces: a `{git_commit_safe_path}` placeholder the executor fills (Task 3 documents the injection).

- [ ] **Step 1: Add the helper path to the "MUST receive" context list**

In `skills/executing-dag-plans/implementer-prompt.md` §Context construction rules, the "The implementer MUST receive:" bullet list, append:

```markdown
- The absolute path to the `git-commit-safe` helper (`skills/executing-dag-plans/git-commit-safe`), substituted into the prompt as `{git_commit_safe_path}`. Implementers commit through it so concurrent implementers don't race on the shared git index.
```

- [ ] **Step 2: Replace the git-add discipline block with helper usage**

In the prompt template's project-conventions area, find this existing block:

```
- Use `git add` with EXPLICIT file paths matching the task's `files:` list.
  NEVER `git add -A` or `git add .`. Other implementers may be running
  concurrently in the same repo; staging non-task files would bundle their
  work into your commit. Run `git status` before staging; verify ONLY your
  files are staged; then commit.
```

Replace it entirely with:

```
- Commit via the race-safe helper, NOT a bare `git commit`:

    {git_commit_safe_path} "<commit message>" <your task's files...>

  It serializes against other implementers running concurrently in the same
  repo (atomic lock around the commit instant) and commits ONLY the paths you
  name (so it cannot bundle another implementer's files). Pass EXPLICIT paths
  from your task's `files:` list. NEVER `git add -A` / `git add .`, and never a
  bare `git commit` — the shared index will lock-fail or bundle concurrent work.

  Fallback if `{git_commit_safe_path}` is unavailable, run the equivalent
  inline before committing:

    lock="$(git rev-parse --git-dir)/dag-commit.lock"
    until mkdir "$lock" 2>/dev/null; do sleep 0.1; done
    trap 'rmdir "$lock" 2>/dev/null' EXIT
    git commit --only -m "<message>" -- <your task's files...>
```

- [ ] **Step 3: Verify**

Run:
```bash
grep -nE "git-commit-safe|git_commit_safe_path|git commit --only" skills/executing-dag-plans/implementer-prompt.md
grep -nE "git add (-A|\.)" skills/executing-dag-plans/implementer-prompt.md
```
Expected: first grep shows the helper usage, the placeholder, and the fallback. Second grep shows only the `NEVER git add -A` prohibition text (no instruction telling the implementer to run `git add -A`). Read-through: confirm the old "Run git status before staging…then commit" wording is gone and replaced by the helper instruction.

- [ ] **Step 4: Commit**

```bash
git add skills/executing-dag-plans/implementer-prompt.md
git commit -m "feat(implementer-prompt): commit via git-commit-safe helper"
```

---

### Task 3: Executor injection note + agent hard-rule

**Files:**
- Modify: `skills/executing-dag-plans/SKILL.md` (§Execution model step 4 ~line 33-35; §Hard rules ~line 94-100)
- Modify: `agents/dag-implementer.md` (§Hard rules ~line 36-41)

**Interfaces:**
- Consumes: the helper (Task 1) and the `{git_commit_safe_path}` placeholder (Task 2).

- [ ] **Step 1: Note helper-path injection in §Execution model**

In `skills/executing-dag-plans/SKILL.md` §Execution model step 4 (the implementer-dispatch step), add a sentence:

```markdown
When constructing each implementer dispatch, substitute the absolute path to `skills/executing-dag-plans/git-commit-safe` into the prompt's `{git_commit_safe_path}` placeholder (resolve it from the plugin root). Implementers commit through this helper so concurrent dispatches in the same tick never race on the shared git index.
```

- [ ] **Step 2: Add a §Hard rules sentence**

In `skills/executing-dag-plans/SKILL.md` §Hard rules, append a bullet:

```markdown
- ALL implementer commits go through `git-commit-safe` (atomic-mutex + path-scoped commit). The dispatch MUST inject `{git_commit_safe_path}`. This is what prevents `index.lock` contention and cross-task stage-bundling when multiple implementers commit concurrently.
```

- [ ] **Step 3: Update the dag-implementer commit hard-rule**

In `agents/dag-implementer.md` §Hard rules, add a bullet (keep the existing "Do not skip tests / Do not commit with red tests" rules):

```markdown
- Commit via the injected `git-commit-safe` helper with EXPLICIT paths from your task's `files:` list — never `git add -A`/`git add .`, never a bare `git commit`. Concurrent implementers share one git index; the helper serializes the commit and scopes it to your files.
```

- [ ] **Step 4: Verify**

Run:
```bash
grep -nE "git-commit-safe|git_commit_safe_path" skills/executing-dag-plans/SKILL.md agents/dag-implementer.md
```
Expected: matches in both files (injection note + hard rule in SKILL.md; commit hard-rule in dag-implementer.md). Read-through: confirm the injection instruction and the agent hard-rule are consistent with the implementer-prompt usage from Task 2.

- [ ] **Step 5: Commit**

```bash
git add skills/executing-dag-plans/SKILL.md agents/dag-implementer.md
git commit -m "docs(executing-dag-plans): document git-commit-safe injection + agent rule"
```

---

## Self-Review (completed by plan author)

**Spec coverage** — every spec §Architecture row maps to a task: helper → T1; implementer-prompt → T2; SKILL.md → T3; dag-implementer.md → T3; both shell tests → T1. Spec §The helper (mutex/stale-lock/path-scoped/-m-before-`--`/trap) is fully encoded in T1 Step 4's code + Global Constraints. Spec §Error handling (usage exit 2, mutex-timeout exit 1, propagate git failure) is in the helper code. Spec §Testing (concurrent + stale-lock) = T1 Steps 1–2; behavioral checks are covered by the executable tests. Spec §Implementer-prompt change = T2. Spec §path injection = T2 (placeholder) + T3 (executor fills it).

**Placeholder scan** — all code is complete and literal (helper + both tests given in full). No TBD/TODO/"handle errors" hand-waving. The one templated token `{git_commit_safe_path}` is an intentional prompt placeholder, defined in T2 and filled per T3.

**Type/contract consistency** — the helper interface `git-commit-safe "<msg>" <path>...`, the lock path `"$(git rev-parse --git-dir)/dag-commit.lock"`, `git commit --only -m "$msg" -- "$@"` (with `-m` before `--`), and exit codes (0/1/2) are used identically across T1's helper, T1's tests, T2's prompt text + fallback snippet, and T3's docs.

**Note on file overlap with PR #1** — T2/T3 edit `implementer-prompt.md` and `executing-dag-plans/SKILL.md`, which the token-optimization PR also edits. These branches are independent; whichever merges second resolves the textual overlap. Flagged for the merge, not a plan defect.

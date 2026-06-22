# Git Commit-Race Remedy for Parallel Implementers — Design Spec

**Date:** 2026-06-22
**Skills targeted:** `parallel-dag-execution:executing-dag-plans` (implementer dispatch + commit discipline). Plus a new committed helper script and a shell test.

**Relationship to other specs:** Orthogonal to the merged-review spec (`2026-06-22-merged-review-design.md`) and the token-optimization work (PR #1). This is execution *safety*, not review *cost*. It can be implemented independently and in any order relative to those.

## Goal

Eliminate git commit races among the parallel implementer subagents the executor dispatches per tick, with a lightweight, no-architecture-change remedy: a race-safe commit helper that serializes only the commit instant and scopes each commit to its own task's files.

## Why

The executor dispatches multiple implementer subagents in the same tick — that concurrency is the plugin's whole value. But all those subagents share **one** git index (`.git/index`) and **one** HEAD on the working branch. Two failure modes result:

1. **Index-lock contention.** Two `git add`/`git commit` invocations at once → `fatal: Unable to create '.git/index.lock': File exists`. One implementer's commit hard-fails.
2. **Stage bundling.** Implementer A stages its files, B stages its files, then A runs `git commit` — A's commit silently captures B's staged files too, because the index is global. The current `git add <explicit paths>` + "verify only your files are staged" discipline (`executing-dag-plans/implementer-prompt.md`) reduces but does not eliminate this: the index itself is shared, so a concurrent stage between A's add and A's commit re-introduces the bundle.

Both are real, intermittent, and worsen as tick width grows. The file-scope contract guarantees parallel tasks touch *disjoint files* — but it does nothing about the *shared index*, which is the actual contended resource.

## Why this remedy (Option 3), not the alternatives

- **Per-task worktree isolation (Option 2):** each implementer in its own worktree/branch, controller integrates serially. Bulletproof and allows truly parallel commits, but adds worktree setup cost (~hundreds of ms + disk per task) and an integration/merge step. Heavier than the problem warrants for the common case.
- **Controller-mediated serial commits (Option 1):** implementers don't commit; the controller commits each task serially. Race-free by construction, but changes the implementer contract, drops per-implementer commit authorship, and is less resumable (uncommitted work lost if the controller dies mid-tick).
- **Option 3 (this spec):** serialize only the commit *instant* (milliseconds) via an advisory mutex, and scope each commit to its own paths. Keeps the implementer contract, full parallelism of the expensive work (edits, test runs), and resumability. Eliminates both failure modes with near-zero overhead.

Options 1 and 2 are explicit non-goals here; either could be revisited as a follow-up if commit concurrency ever becomes extreme.

## Non-goals

- Worktree isolation; controller-mediated commits (above).
- Changing the parallel-dispatch model, the file-scope tripwire, or the `depends_on` contract.
- Changing what gets committed or commit-message conventions.
- Cross-shell support beyond POSIX `sh` / git-bash (the implementers run via the Bash tool in git-bash on this platform).

## Architecture

| File | Change |
|---|---|
| `skills/executing-dag-plans/git-commit-safe` | NEW POSIX `sh` helper. Acquires an atomic advisory mutex, runs a path-scoped commit, releases the mutex. |
| `skills/executing-dag-plans/implementer-prompt.md` | Replace the "`git add` explicit paths then commit" block with: commit via `git-commit-safe "<msg>" <path>...`. The executor injects the helper's absolute path (resolved from the plugin root) into the dispatch. |
| `skills/executing-dag-plans/SKILL.md` | §Execution model: note that implementer dispatch injects the `git-commit-safe` path; one sentence in §Hard rules that all implementer commits go through it. |
| `agents/dag-implementer.md` | Update the commit hard-rule to reference the race-safe helper (still explicit paths, never `git add -A`). |
| `tests/commit-safe/concurrent-commit.test.sh` | NEW executable test — forks N concurrent commits against a scratch repo, asserts all land with no lock errors and each commit contains only its own file. |
| `tests/commit-safe/stale-lock.test.sh` | NEW executable test — a stale mutex is broken and the commit still succeeds. |

**What stays the same:** the parallel-dispatch contract, file-scope tripwire, review chain, failure cascade, resumability, and every existing rule. The controller does not change its own behavior; only the implementers' commit step changes.

## The helper — `git-commit-safe`

**Interface:**
```
git-commit-safe "<commit message>" <path> [<path>...]
```
Commits ONLY the named paths, race-safely. Exit 0 on success; non-zero with a clear stderr message on mutex timeout or git failure.

**Behavior:**

1. **Atomic advisory mutex.** Lock path `"$(git rev-parse --git-dir)/dag-commit.lock"` (a *directory* — `mkdir` is atomic on POSIX, so it is a correct mutex with no TOCTOU window). Acquire by looping `mkdir` with a short sleep (~100 ms) up to a bounded timeout (~30 s / 300 tries). This serializes our commits at our *own* mutex, so we never collide on git's `index.lock`.
2. **Stale-lock breaking.** If the lock directory already exists AND its mtime is older than a threshold (60 s — far longer than any real commit), assume the holder died (e.g., killed implementer) and break it: `rmdir` then retry acquire. Prevents a dead implementer from wedging the whole run.
3. **Path-scoped commit.** Under the mutex, run `git commit --only -- <paths> -m "<msg>"`. `--only` commits the working-tree content of exactly the named paths, ignoring any other staged content — belt-and-suspenders against bundling even if the index has residue from an interrupted op. (No separate `git add` needed in `--only` mode.)
4. **Release.** `trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM` so the mutex is released even on error or interruption.

**Why both mutex and `--only`:** the mutex prevents concurrent index access (kills lock contention and interleaving); `--only` guarantees each commit captures only its task's files regardless of index state. Together they are fully race-safe.

**Path resolution / injection:** the helper ships in the plugin. The executor knows the plugin root, so when constructing each implementer dispatch it substitutes the helper's absolute path into the prompt (a new placeholder, analogous to how upstream-context and conventions are injected today). The implementer invokes that path. (Fallback documented in the implementer-prompt: if the helper path is unavailable, the implementer runs the equivalent inline `mkdir`-mutex + `git commit --only --` sequence — the prompt includes the snippet.)

## Implementer-prompt change

Replace the current project-conventions commit block:

> Use `git add` with EXPLICIT file paths matching the task's `files:` list. NEVER `git add -A`… Run `git status` before staging; verify ONLY your files are staged; then commit.

with:

> Commit via the race-safe helper: `git-commit-safe "<message>" <your task's files...>` (path injected above as `{git_commit_safe_path}`). It serializes against other concurrent implementers and commits ONLY your named paths. NEVER `git add -A`/`git add .`. Do not run a bare `git commit` — other implementers are committing concurrently and the shared index will bundle or lock-fail.

The "explicit paths, never `-A`" discipline is preserved and now enforced by the helper's interface (you must pass paths).

## Error handling

- **Mutex acquisition timeout** (lock held >30 s and not stale) → helper exits non-zero; the implementer surfaces it. The controller treats a commit failure like any tool failure for that task (the task did not reach a clean committed state → not DONE). No silent partial commit.
- **`git commit --only` fails** (nothing to commit, real conflict) → propagate the git exit code and stderr; implementer reports it.
- **Stale lock from a crashed holder** → auto-broken after the 60 s threshold; logged to stderr.

## Resumability

Unaffected. Implementers still commit per task; commits land on the working branch exactly as before, only serialized at the commit instant. The plan file remains the source of truth; a controller crash mid-tick loses only uncommitted in-flight work, same as today.

## Testing

This remedy — unlike the markdown-skill changes — has **genuinely executable** tests (it is a real shell script).

### `tests/commit-safe/concurrent-commit.test.sh`
1. Create a scratch git repo in a temp dir.
2. Create N (e.g. 12) distinct files, each owned by a "task".
3. Launch N background invocations of `git-commit-safe "task-i" file-i` concurrently (`&` + `wait`).
4. Assert: all N invocations exit 0; `git log --oneline` has N commits (plus the base); each commit's diff touches exactly its one file (no bundling); no `index.lock` error appeared in any invocation's stderr.

### `tests/commit-safe/stale-lock.test.sh`
1. Scratch repo; create the lock directory `"$(git rev-parse --git-dir)/dag-commit.lock"` and back-date its mtime beyond the 60 s threshold.
2. Run `git-commit-safe "msg" file`.
3. Assert: the stale lock is broken, the commit succeeds (exit 0, commit present), and the lock directory is gone afterward.

### Behavioral check (reasoned)
- A single-task tick behaves identically to today (mutex acquired uncontended, one commit).
- The helper never uses `git add -A`; it is impossible to bundle non-task files via the documented interface.

## Migration

None. Existing plans and the executor are unchanged except that implementer dispatches now route commits through the helper. No plan-format or schema change.

## Summary

| Mechanism | Effect | Cost |
|---|---|---|
| Atomic `mkdir` mutex around the commit instant | Serializes index access → no `index.lock` contention, no stage interleaving | Milliseconds per commit; parallel work (edits/tests) unaffected |
| `git commit --only -- <paths>` | Each commit captures only its task's files → no bundling | None |
| Stale-lock breaking (60 s) | A crashed implementer can't wedge the run | None on the happy path |

A small committed helper plus a one-block implementer-prompt change removes both git commit-race failure modes while preserving the parallel-dispatch model, the implementer contract, and resumability — and it is verified by real concurrent-commit shell tests, not just conformance reasoning.

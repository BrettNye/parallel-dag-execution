## Lens: charter conformance
## Charter: C:/Users/Brett/d2-runs/pde-d2-gate2/CLAUDE.md (read in full; no nested CLAUDE.md/AGENTS.md; no .claude/audit-charter.md; no docs/map.md or docs/conventions). Also read .gitattributes, .gitignore, .claude-plugin/plugin.json, README.md helper/fixture passages, and git history of plan-quality.md for how earlier heuristics landed.
## Downstream context: none beyond the plan itself (all 16 tasks pending, nothing landed since dc30ba0). The plan is the only consumer of the spec, so findings are labelled against the plan text.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Status |
|---|---|---|---|
| Extensionless scripts are listed in `.gitattributes` under an "Extensionless shell script" block with `text eol=lf` | task-verify-args body | .gitattributes (comment "# Extensionless shell script." followed by four `... text eol=lf` lines) | VERIFIED |
| `*.sh` already covered, so the new suite needs no `.gitattributes` line | task-verify-args (only the script is listed) | .gitattributes `*.sh text eol=lf` | VERIFIED |
| Each script has a suite at `tests/<suite>/<name>.test.sh`; `for t in tests/*/*.test.sh` picks it up | Context "Shape"; task-verify-args | CLAUDE.md "Running the tests"; ls tests/ shows plan-state/, commit-safe/, audit-stats/, resolve-declared-paths/ | VERIFIED |
| `CLAUDE.md` first Conventions bullet lists the four helper scripts, `git-commit-safe` among them | task-repo-docs | CLAUDE.md lines 5-9 (the bullet holds `skills/executing-dag-plans/git-commit-safe` at line 8) | VERIFIED |
| Suite shape: `ok`/`bad`/`chk`/`has`/`hasnt`, `ALTSH`, rg guard, `RESULT:` line | task-verify-args | tests/plan-state/plan-state.test.sh:1-16 (helpers and `ALTSH` at 7-14; rg guard at line 6) | VERIFIED |
| Existing assertion `usage lists rules 1-5 and 7-15` exists | task-tests-cmd | tests/plan-state/plan-state.test.sh:543 | VERIFIED |
| plan-state header line 4 says "rules 1-5 and 7-15"; header ends at `# Exit:` line | task-tests-cmd | skills/writing-dag-plans/plan-state:4 and :12 | VERIFIED |
| Every "S1-S16 / 7-15" enumeration outside docs/ is covered by a task | Context call 8 | rg across repo: README.md:11 (task-repo-docs), writing-dag-plans/SKILL.md:69 and :214 (task-writer), plan-quality.md:116 (task-s17), updating-dag-plans/SKILL.md:25 and :86 (task-updater), plan-format.md:265 (task-format), plan-state:4 and test:543 (task-tests-cmd). Left alone by design: commands/audit-plan.md:19 and auditing-artifacts/SKILL.md:223 | VERIFIED |
| Reviewer-prompt anchors exist (`## Implementation under review`, "MUST receive") | task-reviewer-prompts | spec-reviewer-prompt.md:14,78; merged-reviewer-prompt.md:8,80 | VERIFIED |
| Implementer prompt has `## Your output` after a template section | task-implementer-prompt | implementer-prompt.md:66 | VERIFIED |
| Executor step 4 contains the sentence "Mark it with `plan-state set <plan> <id> running`." and the two review-chain diagrams | task-exec-dispatch, task-exec-verify | skills/executing-dag-plans/SKILL.md:35 (sentence), :50-67 (diagrams), :72 (cap paragraph), :90 (ISSUES table row) | VERIFIED |
| `76ed77d^` is a commit (used in the empirical-unknown-1 criterion) | task-verify-tests | `git cat-file -t 76ed77d^` printed `commit` | VERIFIED |
| `.scratch/` is git-ignored (the criterion puts a plan there) | task-verify-tests | .gitignore (`.scratch/`) | VERIFIED |
| plan-state itself can run under dash/mawk/busybox (sketches use no gensub/strftime/asort/`\x`) | tasks 1-3 sketches | sketches read in plan lines 201-228, 312-336, 446-463: `index`, `substr`, `sub`, `in`, `SUBSEP`, `length` only | VERIFIED (sketches only, nothing built yet) |

### Findings

- **DEFERRED** · S17 is added with no fixture pair, though every earlier S-heuristic with a detection rule shipped one.
  - Artifact text: task-s17 `files:` is only `skills/writing-dag-plans/plan-quality.md`; "Test file: none (the `rg` checks above)."
  - Evidence: `git log` for plan-quality.md and the S16 commit stat show S16 landing with `tests/fixtures/visual-verification/should-warn/s16-ui-task-no-owner.md` and `.../should-pass/s16-ui-task-with-owner.md` (commit 65f48d9), S12-S15 with `tests/fixtures/acceptance-criteria/` (e6f69f1, b3ecc1e), S11 with `tests/fixtures/contracts/should-warn/s11-unanchored-contract.md`. README.md:108-115 describes `tests/fixtures/` as the home for rule fixtures. CLAUDE.md states no such requirement, and no test runner executes the fixtures (they are prompt-level, README.md:112), so nothing enforces it.
  - Concrete failure: S17's trigger and suppressor wording cannot be exercised by the blind fixture runs that tuned S12-S16, so a mis-firing S17 (for example firing on documentation-only `rg` criteria) will not be caught before it reaches users. Drift, not a build failure.
  - Resolution: the author may add a fixture task (should-warn and should-pass) or record in the plan that S17 ships unfixtured. Not required to proceed.

- **DEFERRED** · The new suite's `rg` dependency is not carried over explicitly.
  - Artifact text: task-verify-args "The suite follows `tests/plan-state/plan-state.test.sh`'s shape: `ok`, `bad`, `chk`, `has`, `hasnt` helpers ... a temporary directory removed on exit, `RESULT: N passed, M failed` at the end"; the task-verify-tail sketch pipes through `rg`, and an acceptance criterion in task-verify-args uses `od -c | rg -c`.
  - Evidence: CLAUDE.md "Running the tests": "a suite that uses it exits 2 when it is missing." plan-state.test.sh:6 implements this guard. The shape list in task-verify-args names helpers, the temp dir, `ALTSH` and `RESULT:`, but not the rg guard.
  - Concrete failure: an implementer who follows the listed shape writes a suite that uses `rg` without the `command -v rg` / exit 2 guard. On a machine without ripgrep it then fails with empty counts instead of one clear line. The `rg` use in the criterion text (not the suite) is a reviewer command, which is fine.
  - Resolution: add "and the `command -v rg` guard that exits 2" to the shape sentence, or say the suite must not use `rg`. Low cost either way.

- **DEFERRED** · `verify-tests` usage uses a fixed header line range, the pattern call 10 of this plan rejects for `plan-state`.
  - Artifact text: task-verify-args sketch `usage() { sed -n '3,5p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }`, against Context call 10 ("by address ... instead of a fixed line range, so the next added subcommand cannot silently drop the last line again").
  - Evidence: task-verify-tests criteria add `# Untracked files:` and `# Bash tool timeout:` lines to the same header, with no placement stated.
  - Concrete failure: if an implementer inserts them above the `# Exit:` continuation or the "never writes" line, the fixed range `3,5` silently truncates or pads the usage text. The "args: no arguments is usage" case only checks for `verify-tests <plan> <id>`, so it would not notice. Small and unenforced.
  - Resolution: either use the `sed -n '3,/^# Exit:/p'` form the plan already chose for `plan-state` (with the Exit lines contiguous), or state that the two new header lines go after the "It never writes" line.

### Checked, no finding
- `.gitattributes`: the plan puts the new extensionless script in the task that creates it and names the right block. The `git check-attr` and no-CR criteria match CLAUDE.md's rule. `tests/verify-tests/verify-tests.test.sh` needs no entry because `*.sh text eol=lf` covers it.
- Placement: `skills/executing-dag-plans/verify-tests` sits beside `git-commit-safe`, the suite is at `tests/verify-tests/`, and the glob in CLAUDE.md's test loop will run it. `verify-tests` finds `plan-state` by `../writing-dag-plans/plan-state` relative to its own directory, so it needs no PATH, plugin-manifest or `files:` registration. `.claude-plugin/plugin.json` lists no scripts.
- Reference implementations: the suite points at `tests/plan-state/plan-state.test.sh` (the repo's closest suite, with `ALTSH`), and the executor text points at how `plan-state` is already called from the plugin root (SKILL.md:30). The README, CLAUDE.md, `plan-quality.md`, `plan-format.md`, SKILL.md, updater and lens edits all carry exact anchor text that I confirmed exists at the cited locations.
- Enumerations: no S1-S16 or rules 7-15 string is left behind outside the deliberate exceptions in call 8. The `tests/fixtures/` and `commands/audit-plan.md` hits are fixture prose and an overlap claim that stays true.
- Portability: the sketches use only POSIX sh (`trap`, `wait`, `mktemp -d`, `${var#prefix}`, `$(( ))`) and awk functions in the CLAUDE.md allowed set. `verify-tests` does not call `rg`. `IFS= read -r` is specified for the trailing-space values. The `.scratch/` and `76ed77d^` references in the empirical-unknown criterion resolve.
- Commit/doc conventions: the repo-docs task puts `verify-tests` in CLAUDE.md's helper list as that file's own convention requires. Run order of the tasks puts the CLAUDE.md edit after the script exists.
- No `chmod`/mode instruction is given for the new script or suite. The index already holds mixed modes (audit-stats and every `.test.sh` are 100644, the other three helpers 100755), and every invocation in the plan goes through `sh <path>` or `bash <path>`, so this is not a defect.

### Out of lens
- The task-verify-tests sketch records `child=$!` from a `( cd "$tree" && sh -c ... ) &` subshell, so `kill "$child"` stops the subshell and may leave the `sh -c` grandchild running; the plan's call 6 says the trap "stops the `sh -c` process it started". Correctness, for the feasibility/ambiguity lens.
- Task-exec-verify hard-codes "about 85 s per run here" in executor skill text; a machine-specific timing in a shipped skill may be stale quickly. Ambiguity/maintainability lens.
- I ran no probes and wrote nothing in the repository other than this report.

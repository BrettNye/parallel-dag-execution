## Lens: grounding
## Charter: read root CLAUDE.md (POSIX helper conventions, LF/.gitattributes, suite shape, rg in tests). No .claude/audit-charter.md, no nested CLAUDE.md/AGENTS.md. Downstream context: the plan under audit is the only consumer of the spec, all 16 tasks are `pending`, no commits have landed since dc30ba0, so no finding below is STALE or already fixed downstream.

Probes (all outside the repo, scratch dirs under /tmp, removed afterwards; nothing was written in the tree):
- P1: `bash tests/plan-state/plan-state.test.sh` run from the repo (reads only; it makes its own mktemp dir). Result: `RESULT: 210 passed, 0 failed`, wall time `real 4m6s`.
- P2: `git archive HEAD` extracted to a scratch dir, `skills/writing-dag-plans/plan-state` replaced by `git show 76ed77d^:skills/writing-dag-plans/plan-state`, then the HEAD suite run there. This is what `verify-tests` would build as the before tree for the plan's empirical-unknown-1 criterion.
- P3: a scratch git repo: `git worktree add --detach`, then `git worktree prune`, then `git worktree list`.
- P4: scratch bash scripts that start `sh -c 'trap ... INT/TERM/HUP; sleep & wait' &` from a non-interactive bash and send signals. They also tested `kill` of a `( cd . && sleep N ) &` subshell pid.
- P5: `plan-state check` and `plan-state preflight` on the plan itself. Check exits 0. Preflight exits 0 with warnings only (see "Checked").

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Verdict |
|---|---|---|---|
| `plan-state` `usage()` prints a fixed range; header Exit line is line 12 | task-tests-cmd, call 10 | plan-state:22 (`sed -n '3,12p'`), :12 (`# Exit:`) | VERIFIED |
| Dispatch order: `[ "$#" -ge 2 ]`, then unreadable-plan check, then per-command arg count | task-tests-cmd error order | plan-state:23-25, :524-525 (`round` shows the pattern) | VERIFIED |
| `set` branch calls `emit "$1" "$2"`; `emit` takes SETID/SETST/RRID/RRVAL | task-base-sha | plan-state:530-533, :458-463 | VERIFIED (a 5th arg is a new addition) |
| `apply()` runs only in the second pass of a two-file awk call | task-base-sha sketch (`MODE=setq` over one file) | plan-state:365 (`FNR == 1 && NR != FNR { graph(); apply(); ...}`) | CONTRADICTED for the sketch (F6) |
| `round` inserts `review_rounds:` after `status:` with the same indent and CR | task-base-sha item 5 | plan-state:374-375 | VERIFIED |
| `addlist` strips `./` only for `files`; any other key goes to `fil[]` | task-tests-field (tests must bypass `addlist`) | plan-state:39-44 | VERIFIED (the sketch's early `return` for `tests` is needed) |
| Frontmatter values are `unq(stripc(...))`, so a quoted prefix keeps its trailing space | task-tests-field | plan-state:338 | VERIFIED |
| Existing suite helpers `ok bad chk has hasnt ps clean_plan ALTSH`, and case `usage lists rules 1-5 and 7-15` | task-tests-field, task-tests-cmd, task-verify-args | plan-state.test.sh:9-18, :24, :543 | VERIFIED |
| `clean_plan`: task-a done; task-c files hold `tests/hook.test.sh` | task-base-sha, task-tests-field fixtures | plan-state.test.sh:24-78 | VERIFIED |
| This repo's suites repeat `exit 0` | task-writer | plan-state.test.sh:83 and :90 (`chk "exit 0"`) | VERIFIED |
| `.gitattributes` has an "Extensionless shell script" block | task-verify-args | .gitattributes (last block, `# Extensionless shell script.`) | VERIFIED |
| `skills/executing-dag-plans/verify-tests`, `tests/verify-tests/` | task-verify-args | not on disk; `tests/` holds `plan-state`, `commit-safe` etc., no near-duplicate | VERIFIED as genuinely new |
| Step 4 of the executor has a sentence `Mark it with \`plan-state set <plan> <id> running\`.` | task-exec-dispatch | executor SKILL.md:35 | VERIFIED |
| Step 4 has a start "before **Dispatch in parallel:**" distinct from the `4. ` line | task-exec-dispatch | executor SKILL.md:35 (`4. **Dispatch in parallel:** ...` is one line) | CONTRADICTED (F5) |
| Resume resets `running` to `ready` | task-exec-dispatch, task-base-sha item 2 | executor SKILL.md:121 | VERIFIED |
| "`set` rewrites only the status line" | (not edited by any task) | executor SKILL.md:78 | becomes false after task-base-sha (F7) |
| Review-round cap paragraph and ISSUES table row exist | task-exec-verify | executor SKILL.md:72, :90 | VERIFIED |
| Two review-chain diagrams start with `implementer DONE` | task-exec-verify | executor SKILL.md:54, :64 | VERIFIED |
| "a plan-state suite takes about 85 s per run here" | task-exec-verify, Context | P1: 4m06s, 210 cases | CONTRADICTED (F4) |
| Implementer prompt has `## Your output` and `RED-THEN-GREEN (required` | task-implementer-prompt | implementer-prompt.md:66, :73 | VERIFIED |
| Spec reviewer prompt: "MUST receive" bullet list and `## Implementation under review` | task-reviewer-prompts | spec-reviewer-prompt.md:14, :78 | VERIFIED |
| Merged prompt: "MUST receive" sentence and `## Implementation under review` | task-reviewer-prompts | merged-reviewer-prompt.md:8, :80 | VERIFIED |
| `quality-reviewer-prompt.md` has no `verify_tests_output` | task-reviewer-prompts | not found by `rg -l 'tests:\|base_sha\|verify'` (hits only in quality-reviewer-prompt.md for other text) | UNVERIFIED in detail; the plan only asserts it stays unchanged |
| plan-format: insertion anchors (after `default_quality_reviewer_hint`, after `review_rounds`, `### Mixing implementers`, rules 15, `Rules #7–#15`, `enforces rules 1–5 and 7–15`) | task-format | plan-format.md:32, :109, :112, :261, :263, :265 | VERIFIED |
| No existing `^16. ` or `^17. ` lines in plan-format | task-format | `rg -n '^1[67]\. '` returned nothing | VERIFIED |
| plan-quality: `### S16`, `## Detection algorithm`, `Run soft heuristics S1-S16` (once) | task-s17 | plan-quality.md:104, :112, :116 | VERIFIED |
| writing SKILL: `S1-S16` at exactly two lines; step 3.5 then step 4; step 7 list ends `...verification owner**).` | task-writer | writing SKILL.md:69, :214, :126, :144 | VERIFIED |
| updating SKILL: `S1-S16` once; `rules 7–15` once; `No operation changes a task's \`review_rounds:\` field` | task-updater | updating SKILL.md:25, :86, :59 | VERIFIED |
| lenses-plan: `## \`verifiability\`` and `**No observable check at all**` | task-lens | lenses-plan.md:179, :186 | VERIFIED |
| README `(H1–H11 / S1–S16)` once; executing bullet has the preflight sentence | task-repo-docs | README.md:11-12 | VERIFIED |
| CLAUDE.md first Conventions bullet lists `git-commit-safe` | task-repo-docs | CLAUDE.md:7-9 | VERIFIED |
| Call 8 enumerates every place that lists S1–S16 / rules 7–15 | Context call 8 | `rg 'S1[-–]S16\|7[-–]15'` outside docs and fixtures: README:11, audit-plan.md:19, auditing SKILL.md:223, plan-state:4, plan-format:265, plan-quality:116, writing SKILL:69/214, updating SKILL:25/86, plus the suite's own assertion at plan-state.test.sh:543 | VERIFIED (complete) |
| `76ed77d^` is a commit; `.scratch/` is ignored | empirical-unknown-1 | `git rev-parse 76ed77d^` gives `1757d4db...`; `.gitignore` has `.scratch/` | VERIFIED |
| `round on "2" counts to 3` is red at `76ed77d^` | task-verify-tests unknown-1 (and `tests:` examples) | P2: PASS at base | CONTRADICTED (F1) |
| `git worktree prune` clears the registrations of a killed run | Context calls 5/7, KILL criterion | P3 | CONTRADICTED when the dir survives (F2) |
| An INT sent to a backgrounded `verify-tests` reaches its trap | signals INT criterion | P4 | CONTRADICTED under plain `&` from a non-interactive bash (F3) |
| `kill "$child"` stops the `sh -c` run | call 6, sketch at plan L720 | P4 | CONTRADICTED for the sketch (F8) |

### Findings

- **BLOCKING** · F1. The empirical-unknown-1 criterion names a case that is already green at the chosen `base_sha`, so the required `ok` cannot occur.
  - Artifact text: "`tests: [tests/plan-state/plan-state.test.sh :: round on \"2\" counts to 3]` and `base_sha:` set to the full SHA of `76ed77d^` (the commit before quoted `review_rounds` were rewritten), `verify-tests` prints `ok` for that entry and exits 0."
  - Evidence: P2. The HEAD suite run against plan-state from `76ed77d^` prints `PASS: round on "2" counts to 3` (output line 265), and fails only `round on "2" writes review_rounds: 3`, `round after "2" reaches the cap`, the `'2'` twins and `./lib/greet.sh in files: owns lib/greet.sh` (lines 266-273 of the run log). The old `round` already counted a quoted value to 3 and only wrote it back wrongly. The case is T31 at plan-state.test.sh:774, and the case that goes red is the next line, 775. The same example string is reused as the sample `tests:` entry in task-format and task-tests-field.
  - Concrete failure: `verify-tests` labels the entry `not-red` (passed in the before tree), prints `0 ok, 1 failed` and exits 1. The criterion "prints `ok` ... exits 0" fails, and the "this repo's suites need nothing untracked" conclusion cannot be shown. The implementer will chase a non-bug in `verify-tests`.
  - Resolution: name a case that is red at `76ed77d^`, such as `round on "2" writes review_rounds: 3` (FAIL at base, PASS at HEAD). Check it is unique in the file (the suite prints it once for `"2"` and once, with a different name, for `'2'`).

- **BLOCKING** · F2. The KILL criterion and call 7 rest on `git worktree prune` removing registrations, but prune only removes registrations whose working directory is gone.
  - Artifact text: "\"signals: KILL leaves a registration the next run prunes\": after `kill -KILL` of a running `verify-tests`, the next run in the same repository exits 0 or 1 normally and afterwards `git worktree list` shows only the main tree." Call 7: "the registrations are cleared by the next run's `git worktree prune` ... and a temporary directory is left under `${TMPDIR:-/tmp}`."
  - Evidence: P3, git 2.56.0.windows.1. After `worktree add` into a temp dir, `git worktree prune` leaves `git worktree list` at 2 lines. The registration goes only after `rm -rf` of the worktree directory and a second prune. The plan says the temp dir is left behind on KILL, and both worktrees live inside it (`$work/after`, `$work/before`), so their directories still exist.
  - Concrete failure: after a KILLed run, the next run's prune clears nothing. `git worktree list` still shows two extra trees, so the criterion fails as written. Real use leaks registrations in the shared repo's `.git/worktrees` until something deletes `$TMPDIR`. The spec's step 4 prune rationale ("clear registrations left by an earlier run that was killed") is true only after the directories are removed, for example by an OS temp cleaner. The spec is frozen, but this is new grounded evidence that the premise is partly false.
  - Resolution: undecidable as written. The author must choose between (a) rewording the criterion so the test first deletes the leaked temp directory (simulating the OS cleaner) and then shows the next run's prune clears the registration, and correcting call 7 to say so; or (b) giving `verify-tests` a way to remove stale registrations whose directories still exist (a design change that reopens the spec).

- **DEFERRED** · F3. The "INT mid-run cleans up" signal case cannot work if the test starts `verify-tests` with a plain `&`.
  - Artifact text: "\"signals: INT mid-run cleans up\" and \"signals: HUP mid-run cleans up\" do the same for INT and HUP." (the suite is `#!/usr/bin/env bash`, run non-interactively)
  - Evidence: P4. From a non-interactive bash script, `sh -c 'trap "echo INT >> log; exit 2" INT; sleep 4 & wait' &` followed by `kill -INT $!` logs nothing under sh, dash or bash. The same shape logs `TERM` and `HUP` correctly. Adding `set -m` before the `&` makes the INT trap fire. POSIX: a signal ignored on entry to a non-interactive shell cannot be trapped.
  - Concrete failure: the first INT test written the obvious way fails, and the implementer spends a fix round finding the cause. This is a test-harness hazard, not a defect in `verify-tests`.
  - Resolution: the criterion or implementation notes should say the suite must start `verify-tests` in a way that leaves INT default, such as `set -m`. Opus tier may find it unaided, hence DEFERRED.

- **DEFERRED** · F4. The "about 85 s per run" figure is not what this machine measures.
  - Artifact text: "a plan-state suite takes about 85 s per run here, and the check runs it twice." Also "an explicit `timeout` of 600000 ms".
  - Evidence: P1: `bash tests/plan-state/plan-state.test.sh` took real 4m06s here (210 passed). Two runs plus two worktree builds come to about 8.5 min, leaving about 1.5 min under the 600000 ms ceiling, which is also the Bash tool's maximum. The figure originates in the frozen spec (design L314-315), so this is a plan-text provenance issue.
  - Concrete failure: on a slow host, a task that names plan-state cases hits the timeout, which counts as exit 2 and halts the run. The empirical-unknown-1 acceptance run (two plan-state suite runs) will not finish inside the default Bash timeout either; the implementer must know to use a long timeout or background it.
  - Resolution: the plan can add a note that the criterion needs an explicit long timeout. The 85 s figure should be restated as host-dependent (4 min measured on Windows/Git Bash).

- **DEFERRED** · F5. task-exec-dispatch's insertion point cannot be both "before **Dispatch in parallel:**" and "after the line starting `4. `".
  - Artifact text: "put this paragraph at the start of step 4's text, before \"**Dispatch in parallel:**\" is described" versus the criterion "the paragraph sits inside step 4 (after the line starting `4. ` and before the line starting `5. `)" with `rg -c '^\s*\*\*Mark running first\.\*\*'`.
  - Evidence: executor SKILL.md:35 is `4. **Dispatch in parallel:** for each ready task, dispatch ...`, one line. Its continuation paragraphs are at lines 37, 39 and 41, indented three spaces. Nothing in step 4 precedes "Dispatch in parallel".
  - Concrete failure: the prose placement is impossible. Placing the paragraph after line 35 (indented) satisfies the `rg` criterion but sits after "Dispatch in parallel", while "4. **Mark running first.** ..." fails the `^\s*\*\*Mark` regex. A reviewer comparing prose with criterion can raise ISSUES.
  - Resolution: the author must pick the placement (for example, "the first indented paragraph under the `4. ` line") and drop the "before Dispatch in parallel" wording.

- **DEFERRED** · F6. Two sketches would not run as written. Both are labelled illustrative.
  - (a) task-base-sha's `awk -v MODE=setq ... "$PROG" "$plan"` passes the plan once. `apply()` is invoked only from the second-pass rule `FNR == 1 && NR != FNR` (plan-state:365), so `apply()` never runs with one file. The implementer must call `graph(); apply()` from `END` or pass the plan twice, and `exit 2` from `apply()` must still print the existing refusal messages.
  - (b) task-tests-field's fixture awk inserts `tests:` right after the `  - tests/hook.test.sh` item in task-c (plan L233). That item sits in the middle of `files:` (plan-state.test.sh:70-73), so the `one.txt` and `two.txt` items become `tests:` entries and `files:` keeps one item. The `has` assertion still passes, but the fixture is sloppy.
  - Resolution: none needed beyond a note that the sketches are not run-ready.

- **DEFERRED** · F7. A stale sentence in the executor will no longer be true after task-base-sha lands.
  - Artifact text: (absent: no task edits it)
  - Evidence: executor SKILL.md:78: "`set` rewrites only the status line, so the count survives the resume reset of `running` to `ready`." After this plan, `set ... running` also inserts `base_sha:`.
  - Concrete failure: a misleading sentence only. The `review_rounds` conclusion still holds. task-exec-dispatch or task-exec-verify, both of which own that file, could correct it.

- **DEFERRED** · F8. In the sketch at plan L720, `$!` names the subshell, so `kill "$child"` does not stop the test command.
  - Artifact text: "# run one file: (cd \"$tree\" && sh -c \"$cmd\" </dev/null >\"$out\" 2>&1) & child=$!; wait \"$child\"" and call 6, "The trap stops the `sh -c` process it started before removing the worktrees."
  - Evidence: P4. After `kill` of the pid of `( cd . && sleep 31 ... ) &`, `ps -ef` still showed `sleep 31` processes (3 entries on this MSYS host). The grandchild survives.
  - Concrete failure: after an interrupt the suite process keeps running with its cwd inside a worktree. The trap's `worktree remove --force` or `rm -rf` can fail on Windows, which gives `cleanup failed` instead of a clean `interrupted`, or leaves the temp dir and a stray process. The "TMPDIR is empty" assertions in the TERM/INT/HUP cases can then fail.
  - Resolution: the implementer needs to start the test command so that `$!` is the `sh -c` itself (`cd` first, then `sh -c ... &`), or kill the process group. This is an implementation detail for task-verify-tests.

- **DEFERRED** · F9. The reviewer agents' own "You receive" lists are not updated.
  - Artifact text: task-reviewer-prompts `files:` covers only the two prompt templates.
  - Evidence: agents/dag-spec-reviewer.md:9-13 and agents/dag-merged-reviewer.md:12-16 each list three inputs (task spec, commit SHA, files list) with no mention of a check output or red-to-green report.
  - Concrete failure: none to execution (the prompt carries the section), but the agent text and the prompt template disagree about what the reviewer receives. This may be a spec decision; I did not reopen it.

### Checked, no finding
- All 16 tasks' `files:` paths: existing ones exist, new ones (`verify-tests`, `tests/verify-tests/verify-tests.test.sh`) have no near-duplicate. `plan-state check` on the plan exits 0, so rule 4 holds: the plan-state chain, the `verify-tests` chain and the executor SKILL.md pair are all ordered.
- `plan-state preflight` exits 0 with warnings only. The P3 warnings are for fixture and sketch paths in code blocks (`$tmp/...`, `t/a.sh`, `t/demo.test.sh`), not real citations. One P4 warning (task-format reads the plan-state suite path in its example while task-tests-field changes it) is harmless: both are warnings and the example is only a string.
- Every grep-count acceptance criterion's anchor in the doc tasks (S1-S16 once per file, `7–15` once, `^16. `/`^17. ` absent today, `Named tests` absent today, `verify_tests_output` absent today) matches the current files. The "after" counts of `S1-S16` becoming nothing and `S1-S17` equalling the stated numbers are consistent with the occurrence list in the grounding table.
- Call 8's split between places that change and places that stay (`auditing-artifacts/SKILL.md:223`, `commands/audit-plan.md:19`) matches the current text.
- `verify-tests`'s header numbering (`sed -n '3,5p'`) fits the sketched 6-line header: usage on line 3, the two Exit lines on 4-5.
- Error order for `plan-state tests` (usage, then cannot read, then id count) matches the existing top-of-script flow at plan-state:23-25 and `round`'s `[ "$#" -eq 1 ] || usage`.
- `git worktree add --detach`, `worktree remove --force` and `rev-parse --show-toplevel` work with git 2.56 here. `git check-attr eol` and the `od -c | rg -c '\\r'` check are well formed.
- Plan-level default handling: `fm`/`fmset` are filled for frontmatter keys (plan-state:338), so an absent key versus an empty value can be told apart as the task requires.

### Out of lens
- `verify-tests` is POSIX-claimed but `mktemp -d` without a template is not in POSIX; plan-state already does the same at plan-state:459, so this is consistent with the repo. No action.

## Lens: dag-integrity
## Charter: C:/Users/Brett/d2-runs/pde-d2-gate2/CLAUDE.md (read). No .claude/audit-charter.md, no nested CLAUDE.md. No downstream artifact beyond this plan (all 16 tasks pending, nothing landed since dc30ba0).

Probes run: read-only `sh skills/writing-dag-plans/plan-state check <plan>` and `... preflight <plan>` against the plan, from the repo root (no writes in the tree). `git cat-file -t 76ed77d` and `git check-ignore -v .scratch/x` (read-only).

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Result |
|---|---|---|---|
| Every `depends_on` id exists; no cycle | task YAML blocks, L144-L1388 | `plan-state check` on the plan: exit 0, no output (rules 1-5, 7-15, mermaid) | VERIFIED |
| Mermaid edges equal the `depends_on` lists | L26-L33 vs YAML | read both: 8 edges, same set (exec-verify has two incoming, repo-docs one) | VERIFIED |
| Roots share no `files:` entry | roots: exec-dispatch, implementer-prompt, reviewer-prompts, format, s17, writer, updater, lens | each owns a distinct path; the only repeated paths are within chains (plan-state + suite x3; verify-tests + suite x3; executing SKILL.md x2) | VERIFIED |
| Chain `files:` repeats are ordered | plan-state chain L26-L28; verify chain L28-L30; SKILL.md L31 | edges tests-field -> base-sha -> tests-cmd, verify-args -> verify-tests -> verify-tail, exec-dispatch -> exec-verify | VERIFIED |
| Cross-chain: verify-args consumes `plan-state tests` | L534 | verify-args -> tests-cmd edge (L28); the suite's `no named tests` case needs the command | VERIFIED |
| exec-verify and repo-docs depend on verify-args only for the path in their text | L957, L1384 | preflight P2 is the guard (executing SKILL.md L39 describes P2: a missing path another task creates with no dependency path); the edges are what keep P2 quiet | VERIFIED |
| `.gitattributes` has the "Extensionless shell script" block to extend | L83, L518-L520 | `.gitattributes` bottom block lists the four scripts | VERIFIED |
| "S1-S16" / "7-15" consumers are all in some task's `files:` | Context call 8 | rg over the tree (symbol sweep) and read of the five files: README.md:11, writing SKILL.md:69,214, plan-quality.md:116, plan-format.md:265, updating SKILL.md:25,86, plan-state:4, plan-state.test.sh:543 are each owned (task-repo-docs, task-writer, task-s17, task-format, task-updater, task-tests-cmd). auditing SKILL.md:223 and commands/audit-plan.md:19 are deliberately unchanged (call 8) | VERIFIED |
| `plan-state set ... running` consumers outside the plan | task-base-sha | rg `running` across skills/commands/agents: the only caller is executing-dag-plans/SKILL.md L35 and L121, both owned by exec-dispatch (exec-dispatch edits L35; L121's resume reset is `set ready`, unaffected) | VERIFIED |
| `76ed77d` and `.scratch/` exist as the empirical-unknown criterion assumes | L795 | `git cat-file -t 76ed77d` = commit; `.gitignore:16 .scratch/` | VERIFIED |
| `single_threaded` / empty `files:` | whole plan | no task declares `single_threaded`; no task has empty `files:` (the doc-only tasks each list a path) | VERIFIED |

### Findings

- **DEFERRED** · Preflight prints a P4 warning that task-format "reads" the plan-state suite while task-tests-field changes it. It is a false positive from an example string.
  - Artifact text: task-format's body (L1158-L1159) carries the schema example `tests/plan-state/plan-state.test.sh :: round on "2" counts to 3`.
  - Evidence: `plan-state preflight` on the plan prints `P4: warning: task-format reads tests/plan-state/plan-state.test.sh while task-tests-field, which can run at the same time, changes it`, exit 0. task-format edits only `skills/writing-dag-plans/plan-format.md` and never reads or runs the suite. The executor prints warnings and proceeds (executing SKILL.md L39).
  - Concrete failure: none. It costs a noisy warning at each run and resume, and it could mask a real P4 among the 13 P3 warnings.
  - Resolution: leave it, or have the author give the format example a path that is not a real file. Do not add an edge: that would serialise the format task behind a three-task chain for nothing.

- **UNVERIFIABLE** · Whether the executor that runs this plan loads `plan-state` and `SKILL.md` from a different copy than the one the tasks edit.
  - Artifact text: "The executor that runs it is the plugin as it was before this plan, which ignores `tests:`" (Context, call 1).
  - Evidence: executing SKILL.md L30 says `plan-state` is "under the plugin root"; L37 says implementers share one working tree and index (they commit through `git-commit-safe`). Nothing in the repo shows whether the plugin root of the running controller is this working tree or an installed copy.
  - Concrete failure, if the plugin root is this tree: the controller calls `plan-state check`, `ready` and `set` on every tick while the plan-state chain tasks, which run in parallel with the eight root tasks, rewrite `skills/writing-dag-plans/plan-state` in the shared tree. A half-written edit makes the next `check` fail or mis-parse, and the controller halts or writes a bad `set`. After task-base-sha lands, the controller's `set ... running` also starts writing `base_sha:` lines into this plan. That is harmless here, since no task has `tests:`.
  - What I'd need: the harness's plugin install path for the run. If it is a separate copy, nothing needs to change. If it is this tree, the plan-state chain needs serialising against controller calls, which is outside what the DAG can express.

### Checked, no finding
- Cycles, dangling ids and renamed tasks: none. `plan-state check` exits 0 and every `depends_on` resolves.
- File-scope races: no two tasks that can run together share a `files:` path. The `plan-state check` tripwire (rule 4) passes on the plan as written.
- Declared `files:` against the tree: each path the table lists as ABSENT is claimed net-new by a create task (verify-tests, its suite) and the rest EXIST. `.gitattributes` is owned only by task-verify-args, and the CLAUDE.md rule requires it at script creation.
- Understated `files:`: none found. task-tests-cmd's header and `usage()` change and the `usage lists rules 1-5 and 7-15` suite assertion are inside plan-state and its suite. task-exec-verify's diagram, review-cap and table edits are all in executing SKILL.md.
- Contract surfaces: the `{verify_tests_output}` placeholder is fixed in Context and used identically by task-exec-verify (producer text) and task-reviewer-prompts (consumer). The five label names, the `(before)` and `(after)` headers, and the rule 16 and 17 message texts are restated by task-format, task-tests-field and task-base-sha. They are literally identical wherever they recur, and the spec is frozen, so I see no drift.
- Symbol-change fallout: the rules count (S1-S16 to S1-S17, rules 7-15 to 7-17) has every consumer owned, apart from the two intentional leaves in call 8. The `set ... running` behaviour change has its only caller owned by task-exec-dispatch.
- False edges: tests-field -> base-sha -> tests-cmd and the verify chain serialise on a shared script and suite, so they are real. exec-verify and repo-docs depend on verify-args to satisfy preflight P2, so they are justified. The edge on tests-cmd -> verify-args is real because the verify-args suite exercises `plan-state tests`. exec-dispatch -> exec-verify shares SKILL.md. I found no gratuitous serialisation.
- Chain-versus-roots parallelism: the eight roots touch none of the chain's files, so the wide start of the DAG is safe.

### Out of lens
- task-exec-dispatch's instruction puts the "Mark running first" paragraph "at the start of step 4's text, before 'Dispatch in parallel:'", but its criterion uses `^\s*\*\*Mark running first\.\*\*` and "after the line starting `4. `". The two read as the same paragraph only if it goes on its own line after `4. `. That is a verifiability and wording matter for another lens.

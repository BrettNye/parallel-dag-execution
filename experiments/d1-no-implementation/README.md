# D1 experiment tools

Tools for `docs/superpowers/specs/2026-11-12-d1-no-implementation-experiment-design.md`
in parallel-dag-execution. They live outside the repo until the report is written, so
neither arm's sessions can read them; they move to `experiments/d1-no-implementation/`
with the report.

| File | What it does |
|---|---|
| `pin-plugin.sh <repo> <commit> <dest-parent>` | Plain export of the plugin at one commit, loaded by both arms with `--plugin-dir`. |
| `run-arm.sh <label> <worktree> <plugin-dir> <plan> <budget-usd>` | One headless invocation of the executor on an arm's plan (`claude -p`, Opus controller, auto permissions, no prompts, cost cap). Prints the session id. |
| `measure.cjs <manifest.json> [--json]` | Tokens, estimated $, controller share, elapsed and active time, and run events per arm and stage; the B/A ratios the decision rule uses. Never prints message content. Test: `node test/measure.test.cjs`. |
| `hidden-check.sh <worktree>` | Every test suite at the worktree's HEAD under mawk, gawk (Debian, dash) and busybox (Alpine). Needs Docker. |
| `blind-review-prompt.md` | The blind final review, and how to score it. |

## Verified (2026-11-12)

- Headless `claude -p` waits for a background subagent and returns its result (probe:
  70 s, $0.015).
- `measure.cjs`: fixture test 21/21; on the probe session it reports about $0.014
  against the CLI's $0.0147 (prices are list-price estimates).
- On the prerequisites run (interactive, 6 tasks): $4.01, controller $3.07, active 20m,
  0 interventions, every reviewer verdict line read.
- `hidden-check.sh` on the repo at a771ddd: 12/12 (4 suites x 3 awks).

## Procedure

1. `pin-plugin.sh` at the commit the pilot starts from. Raise Claude Code's
   `cleanupPeriodDays` so no transcript is deleted before it is measured.
2. Write the pilot spec, pass gate 1. Record session ids per stage in `manifest.json`
   from here on.
3. Plan A: write it, keep the round-1 draft. Plan B: a fresh subagent converts that draft
   (each `## Implementation` becomes `## Contracts`: signatures only), adds
   `implementation: contracts-only`, and nothing else; check the diff by hand.
4. Gate 2 on each: round 1 twice (`gate2-r1a`, `gate2-r1b`); fixes from the first draw
   only (`fix-r1`), by a fresh session per arm; later rounds once (`gate2-r2`, ...).
   B's fixes may add what, never how; tag the others `needs-implementation`. Check B's
   diff by hand at READY.
   Draw 2 of round 1 runs in a throwaway worktree at the same draft commit
   (`git worktree add --detach <dir> <draft sha>`), never in the arm worktree: the
   audit appends an `## Audit record` to the plan and short-circuits on an unchanged
   hash, so a second run in place would be neither independent nor a full audit.
5. One worktree per arm off the same base. `run-arm.sh A ...`, then `run-arm.sh B ...`,
   same day. Budget each at twice A's estimated cost.
6. `hidden-check.sh` on both worktrees; blind review on both.
7. `node measure.cjs manifest.json`; write the report; merge the winner.

Manifest stage names: `plan-writing`, `conversion`, `gate2-r1a`, `gate2-r1b`, `fix-r1`,
`gate2-r2`, `fix-r2`, ..., `execution`. Only `gate2-*` stages count toward the gate-2
line of the decision rule; every stage except `gate2-r1b` counts toward the pipeline.

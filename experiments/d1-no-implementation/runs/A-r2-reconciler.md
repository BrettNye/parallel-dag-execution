## Verdict: NOT READY, 1 blocking

The plan has one blocker. task-round, the root of the DAG, has a CRLF test case that cannot pass on this machine. It sits in task-round's original text, unchanged since 0c4eac5, not in anything round 1's fixes added. Round 1 had listed this exact case as "Solid" without running it. The fix is about 5 lines inside task-round and adds no tasks, files or edges.

The full reconciliation is at `C:/Users/Brett/workspace/scratch/pde-d1-a/docs/superpowers/plans/.audit/2026-11-12-preflight-and-review-cap-dag.md/reconciliation.md`. That directory is gitignored. Nothing else in the repo was written, and my probe directory is deleted.

- **World-claims:** checked against ground-truth Table 1. No lens claim contradicts a row; the ABSENT rows are fixture text inside the plan. Table 2 is empty, so it grounded nothing.
- **Downstream:** all 10 tasks are `pending`, and nothing touching skills/, tests/ or README.md has landed since the plan was written. Nothing is STALE, and no fix is time-critical.

### Blocking finding

**R2-B1 (task-round): the CRLF acceptance case cannot pass here.** The plan says `round` keeps CRLF (L95-97), and its test expects the inserted line to end in `\r` and every line to keep its `\r` (L197-199).
- **Why it fails:** the gawk here (MSYS 5.4.1) drops `\r` when it reads a file, so the emit path the plan prescribes (L149-150) writes everything back as LF. The insert step takes its line ending from `$0` (L145-146), which has already lost the `\r`. The script's existing line-ending detection (plan-state:212) never fires on this machine.
- **How I verified it:** grounding found it with a probe. I reproduced it on the unmodified repo script, outside the repo: a 382-line CRLF plan run through `plan-state render` went from 382 `\r` to 0, under both sh and dash. With `-v BINMODE=3` added to the emit awk call, all 382 survived.
- **The test side has the same problem:** `sed`, `grep` and plain `awk` also drop `\r` here. So the suite's `has` helper (grep) and the T22 snippet's awk extraction would report failure even on a correct file. `head`, `tail`, `tr`, `wc`, `rg` and `awk -v BINMODE=3` keep the bytes.
- **Consequence:** the implementer gets a red case that no `round` built along the plan's lines can fix. task-round is the only root, so if it fails or is reported BLOCKED, all nine other tasks are skipped. Weakening the case instead would drop a test the spec requires (spec L212-213).

### Joint resolutions

- **R (task-round; required: R.1 and R.2)**
  - R.1: put `-v BINMODE=3` on the emit awk call only, with one sentence of reason. Other awks treat it as an unused variable.
  - R.2: in the CRLF case, check bytes with tools that keep `\r`: the count of `\r` (via `tr -cd` and `wc -c`) must equal `wc -l`, and the inserted line is taken with `awk -v BINMODE=3` or `head | tail`. Do not use grep, sed, plain awk or `has` for this case.
  - R.3 (recommended): rewrite the whole `review_rounds` line instead of using `sub()`. This closes a gap where a quoted `"2"` is read correctly but never rewritten. It depends on R.1 to keep the `\r`.
  - R.4 (carried D4): show `-v CAP` on the `check` awk call.
  - Growth: about +5 lines (R.1-R.2), about +8 with R.3-R.4.
- **P (preflight chain awk; recommended, about +6 lines)**
  - P.1: the `editverb` resume becomes `rest = substr(rest, RSTART + RLENGTH - 1)`. My probe gives the expected 0, 0, 0 for the three negated cases and 1 for "...update", "Updated" and "do not edit or change".
  - P.2: `run_check` ends with `return "$rc"`, and the `check)` branch becomes `run_check; exit $?`.
  - P.3: `run_check` keeps `-v CAP`.
  - P.4 (new): `preflight()` calls `ancestors()`.
  - P.5 (new): the names list becomes "Taken, among others", and core gets the same `rg -nw` check the other two tasks have.
- **D (acceptance criteria; recommended, about +4 lines)**
  - D.1: state the Mixed fixture's edges (`task-d` depends on `task-x` and `task-s`).
  - D.2: every "prints no line" case also asserts exit 0.
  - D.3 (new): the rename text citing an absent `lib/greet.sh:4` gives exit 1, with the P1 warning printed before the P3 error. I checked this case can occur, because P1 has no existence condition.
- **E (the EU-A criterion; recommended, about +3 lines)**
  - Print one `NOTE:` per missing awk, have the task's report name which awks ran, and say that a `NOTE:` outcome leaves EU-A open.
  - You choose between (a) the in-suite subset, with the record saying EU-A is only partly settled, and (b) the whole suite run under an awk shim. Neither settles EU-A on this machine.
- **F (audit record; about +4 lines):** record what actually landed in 24ae3ce (A.1-A.4 and B.1). List D1, D2, D4, D6 and D7 under "Deferred, open" unless P and D are applied.

**How the resolutions interact:**
- R.1 and R.3 are coupled: R.3 needs R.1 to keep `\r`.
- R.1 also makes `set` and `render` keep CRLF on this machine, where today they silently convert to LF. No test or caller depends on the LF output, and it fixes a latent bug. The mermaid block also becomes CRLF.
- Preflight cannot pick up a stray `\r`, because its text comes from the CR-stripped `line`.
- R.4 and P.2/P.3 touch the same awk call, so the CAP flag must move with the branch. An earlier test catches it if it doesn't.
- P.4 is safe after check-first. P.4 with D.1/D.2 makes the tests stronger.
- R.1 adds two items to EU-A: whether mawk and busybox accept `BINMODE`, and whether busybox exits 1 on a fatal error.
- Every other pair was checked and is benign; the full list is in the file.

### Contradictions and how I settled them

1. **Can the CRLF case pass?** Verifiability, and round 1's Solid list, said task-round's criteria hold. Grounding said the CRLF case cannot pass. Grounding is right: it actually ran the case, while verifiability only asked whether the test could fail. I reproduced the failure myself.
2. **How serious is the `editverb` bug?** Grounding and coherence said BLOCKING. Five lenses agreed on the facts, and so does my probe. I ruled DEFERRED (carried from round 1's D2): it is the same evidence as round 1, the plan's prose and test state the right behaviour, and the failure is a loud test failure inside the task's own files.
3. **Must `preflight()` call `ancestors()`?** Grounding flagged it; context-sufficiency and dag-integrity cleared it. Grounding traced both ends: plan-state:117 is the only call, and core's outline omits it. It stays DEFERRED because the existing `hasnt` tests fail loudly.
4. **Is the "Taken" names list a problem?** Grounding called it harmless; three lenses deferred it. No current name collides. Ambiguity found a silent mode the others missed: reusing an existing array corrupts data with no error. DEFERRED.
5. **Should the reviewer prompts mention the cap?** Charter (out of lens) said yes; coverage said no. Coverage is right: spec L186-187 limits that documentation to the executor skill and the implementer prompt. No defect.
6. **Can the Mixed fixture pass for the wrong reason?** Ambiguity said yes. I read plan-state:123: the rule 4 line names both tasks, so a test that follows the AC's "names `task-s`, not `task-d`" fails. DEFERRED, carried as D6.

### Downgrade log

| Lens | Claim | Proposed | Final | Why |
|---|---|---|---|---|
| grounding | `editverb` counts negated verbs | BLOCKING | DEFERRED, carried D2 | Repeats round 1's D2 on the same evidence; the plan's prose and test are correct and the failure is loud. Grounding itself suggested the downgrade. |
| coherence | same `editverb` bug | BLOCKING | DEFERRED, carried D2 | Duplicate of the row above. |
| ambiguity (out of lens) | busybox exiting 1 on a fatal error would read as "cap reached" | none | EMPIRICAL-UNKNOWN, folded into EU-A | Cannot be checked here. |
| charter (out of lens) | reviewer prompts omit the cap | none | DEFERRED, no defect | Spec L186-187 sets the scope; widening it would reopen the frozen spec. |
| coherence | alternative fix: run preflight before the reset | none | out of scope | Spec L138-139 fixes the order. |
| several (out of lens) | D1, D4, D6, D7, D13, D14 again | none | DEFERRED, carried | Your rule for repeats of round-1 deferrals. |

No finding was deleted or promoted, and no world-claim was downgraded.

### Deferred

**Carried from round 1:**
- D1: `run_check` must `return`, not `exit "$rc"` (plan-state:360).
- D2: the `editverb` resume. The fix is verified (P.1).
- D4: no `-v CAP` on the `check` awk call.
- D6: the Mixed fixture's edges are not stated.
- D7: the "prints no line" cases assert no exit code.
- D13 and D14: the exit-2 mapping in `emit`, and its test that cannot fail under dash.

**New in round 2:**
- R2-D3: a quoted `review_rounds` passes the check but is never rewritten, so the cap never triggers. Only a hand edit can cause it.
- R2-D5: `preflight()` must call `ancestors()`.
- R2-D6: the "Taken" names list is partial, and core relies on it alone.
- R2-D7: the cap's exit rule is written out three times (the SKILL.md paragraph, the table row and the implementer prompt), against CLAUDE.md's "once" rule.
- R2-D8: no test separates "by check id" order from "errors first" order.
- R2-D9: the EU-A criterion can pass without settling EU-A. Four lenses converged on this.
- R2-D10: the audit record says resolutions A and B were "proposed" without saying what landed, and omits five open items.
- R2-D11: the reviewer prompts don't mention the cap. No defect against the spec.
- R2-D12: the exec-preflight text says "change no task's status" right after a step that resets `running` tasks. Scope it to "preflight changes no task's status".

### Empirical unknowns

- **EU-A (carried, open): does the new awk run under mawk and busybox awk?** Owner: task-preflight-edit.
  - Settle it by running `PATH="$shim:$PATH" bash tests/plan-state/plan-state.test.sh` with a shim `awk` that runs `exec mawk "$@"`, then again with `exec busybox awk "$@"`. Each run must end `RESULT: N passed, 0 failed`.
  - Added this round: whether `-v BINMODE=3` is accepted, and whether busybox exits 1 on a runtime fatal, which `round` would pass on as "cap reached".
  - Neither awk is installed here, so EU-A stays open after this plan runs on this machine.
- **EU1 (carried):** owned by task-round's unwritable-plan case. No change.

### Growth

`Artifact growth: +0 tasks · +0 files newly in scope · +0 dependency edges · ~+5 lines (blocking only) / ~+30 lines (with all recommended clusters)`

- **Blocking count:** round 1 had 3, round 2 has 1. It is falling.
- **Plan size:** 932 lines at 0c4eac5, 993 at 24ae3ce (+61, about 30 of them the audit record).
- **Where the blocker lives:** in original task-round text, not in anything round 1's fixes added.
- **What round 1's fixes added text for:** three DEFERRED findings this round: R2-D6 (the names list), R2-D8 (the new P3-before-P4 case) and R2-D9 (the EU-A criterion). The names list and the EU-A wording were written by round 1's reconciliation itself.

The accretion signal does not fire. Even so, a full 8-lens round 3 is unlikely to pay for itself. A targeted re-check of task-round (grounding plus verifiability), re-running the CRLF probe against the edited text, would settle the blocker.
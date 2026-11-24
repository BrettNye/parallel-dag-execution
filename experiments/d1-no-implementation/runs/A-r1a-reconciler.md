## Verdict: NOT READY, 3 blocking

All three blockers are in the `plan-state` chain (task-preflight-core, task-preflight-declared, task-preflight-edit). Fixing them means editing text inside existing tasks. No tasks, files or dependency edges are added. Nothing is STALE: all 10 tasks are `pending`, HEAD is the plan (0c4eac5), and no code has landed. This is the plan's first audit round; it has no `## Audit record`.

I checked world-claims against the supplied ground-truth table. No lens claim contradicts a row, and every ABSENT row (`lib/gone.sh`, `lib/two.sh`, `data/v1.d`, `lib/made.sh`, `lib/greet.sh` and the rest) is a test fixture name in the plan, not a claimed repo file.

What I ran myself: three gawk probes in a `mktemp -d` outside the repo (results below), and reads of `skills/writing-dag-plans/plan-state` (L1-130, L200-371), the spec (L28-36, L48-54, L98-130, L160-222), `skills/executing-dag-plans/SKILL.md:112-122`, `skills/executing-dag-plans/implementer-prompt.md:124-150` and `skills/writing-dag-plans/SKILL.md:155`. I wrote nothing in the repo.

---

### Blocking findings

**B1. The awk name `ms` is already a scalar in `PROG`. The plan's `note()` uses it as an array, so `preflight` crashes on its first finding.**
- Plan text (task-preflight-core, L326): `function note(t, p, c, level, msg) { if (level > lv[t, p, c]) { lv[t, p, c] = level; ms[t, p, c] = msg } }`
- Evidence, combined from both lenses: `ms` is the mermaid-start scalar at plan-state:84, :223, :241, :243 and :247. Every mode shares the one `PROG` string (plan-state:26-260).
  - Grounding probed it under gawk and got `fatal: attempt to use scalar 'ms' as an array`.
  - Charter traced the same lines by grep and a full read of the script.
  - `lv` is safe, because in `tree()` it is only a local parameter (plan-state:192).
- Scope correction from my own probe (gawk 5.4.1):
  - The clash is not caught when the program is parsed. A program with this `note()` plus `{ if (!ms) ms = FNR }` runs with rc=0 when `note()` is never called. It dies with exit 2 only once `note()` runs after `ms` has become a scalar.
  - So under gawk, `check`, `set` and `render` keep working. `preflight` dies with exit 2 and the fatal message on stderr on every plan that produces a finding, because check-first guarantees a mermaid block and so a scalar `ms`.
  - mawk types names statically, so it may reject the whole program and break every command (charter's claim). That is unverified because mawk is not installed; it is folded into EU-A.
- What goes wrong: an implementer who follows the plan's code exactly fails the plan's own sample test (T23, L341-344) and every P2/P3/P4/P1 test that expects a line. The real-plan test's "stderr is empty" check (L385) also fails. The three later `plan-state` tasks all call `note()`.
- Fix: in Joint resolution A.
- Found by: grounding, charter. Independent evidence (one probe, one grep plus read), so they corroborate each other.

**B2. `cands()` reads `RSTART`/`RLENGTH` after calling `addc()`, but `addc()` → `norm()` → `match()` overwrites them, so `preflight` loops forever.** (Promoted from coherence's DEFERRED.)
- Plan text (task-preflight-core, L321-323): `while (match(rest, word)) { addc(t, substr(rest, RSTART, RLENGTH)); rest = substr(rest, RSTART + RLENGTH) }` and the prose branch `if (l !~ /[ \t]/) addc(t, l); rest = substr(rest, RSTART + RLENGTH)`. `norm()` at L307 calls `match(c, /:[0-9]+(-[0-9]+)?$/)`. task-preflight-edit L528-529 repeats the pattern: `addc(...); off += RSTART + RLENGTH - 1`.
- Evidence: coherence reasoned from POSIX awk semantics without running anything. I ran it: the plan's `norm()` and the `cands` loop, verbatim, under gawk 5.4.1, with a guard that stops after 20 iterations.
  - On `sed -n 4p lib/a.sh more` the loop re-adds `sed` forever.
  - On `cat lib/a.sh:4 next` it loops on `cat`.
  - Cause: when the candidate has no `:N` suffix, `match()` leaves `RSTART`=0 and `RLENGTH`=-1, so `substr(rest, -1)` returns all of `rest`, and the loop never advances.
- What goes wrong: every `preflight` run whose unfinished tasks contain any fenced line, or any backticked span without a suffix, never terminates. That covers the benign fixture (L352-356), the real-plan cases (L380-386) and every later task's fixture.
  - A hang gives no failure message, unlike B1. A dispatched implementer sits until its timeout without a message pointing at the cause.
  - When a candidate does have a suffix, the loop advances by the wrong amount instead.
- Fix: in Joint resolution A.
- Found by: coherence. My probe supplied the execution evidence. Coherence's DEFERRED rested on "a test-first implementer hits it at once"; a hang with no message does not hold up that reasoning, and the failure is at least as severe as B1's.

**B3. task-preflight-declared has an acceptance criterion no fixture can meet: P2 and P3 can never fire on the same path.**
- Plan text: L484 "For one path that draws both P2 and P3 lines in a task, P2 prints first." The prose behind it, L427-429: "Order within a path stays by check id, so a P2 line comes before a P3 or P4 line for the same path."
- Evidence, combined from three lenses:
  - P2 needs the path absent and declared by another task (L412-413; code at L435: `if (kind[p] != "absent" || !(p in dcl)) return`).
  - P3's absent branch needs "no task declares it" (L258). Its other branch needs the path to exist (L260).
  - P4 needs the path to exist (L422, L445).
  - `dcl` counts every task's `files:` whatever its status (L234-235). The task's own `files:` are skipped before any check runs (L257).
  - So P2 excludes P3 and P4 on any one path. The spec does not require this ordering case: its fixture list (spec L205-210) asks for P3 and P2 on different paths in one run.
- What goes wrong: an implementer can only write a test that proves nothing, report BLOCKED, or bend P3 to fire on declared absent paths. Bending P3 doubles the output on every plan where one task creates a file another cites (ambiguity's third outcome).
  - Under `review_mode: split` (L401), the spec reviewer returns ISSUES on the missing case, round after round.
  - If the review cap is live, the third fix round fails the task. The failure cascades to task-preflight-edit and then to task-exec-preflight, task-writer, task-updater and task-readme. If the cap is not live, the loop has no bound.
- Fix: in Joint resolution B. Dropping the bullet does not reopen the frozen spec.
- Found by: verifiability, coherence and ambiguity. All three reasoned from the plan text. That evidence is complete for this claim, which is entirely internal to the plan, and nothing downstream can make it STALE.

---

### Joint resolutions

**A. Fix the awk code in the three preflight tasks together** (resolves B1, B2, and DEFERRED D1-D5).
Owning tasks: task-round (L131 area, CAP), task-preflight-core (L272-273, L283-333), task-preflight-edit (L522-539). Make all of these edits together:
1. **B1, core L326:** rename the message array to a name not already in `PROG`, e.g. `pfmsg[t, p, c]`. Add one sentence listing the program's globals that are taken: `ms`, `me`, `l`, `k`, `line`, `info`, `cur`, `nt`, `fence`, and the function names `st`, `inset`, `err`, `viol`, `graph`, `ancestors`, `check`, `ready`, `tree`. Every later task must check its new names against that list.
2. **B2, core L321-323:** in both branches of `cands`, save the match position in locals right after `match()` (e.g. `s = RSTART; n = RLENGTH`) and use only those locals for the substring and for advancing.
3. **D3/B2, edit L528-529:** compute the prefix and the offset from the same saved locals, not from `RSTART`/`RLENGTH` after `addc`. If the edit task keeps `off += RSTART + RLENGTH - 1`, B2 comes back in the next task.
4. **D3, edit:** `addc` gains a parameter for the prefix (`function addc(t, raw, pre,   p)`) and stores `cpre[t, nc[t]] = pre`. Today the third argument lands in the local `p` and is overwritten.
5. **D2, edit L536:** after a negated match, resume after the verb (`rest = substr(rest, RSTART + RLENGTH - 1)`), not at `RSTART + 1`. The AC at L562-564 already states the right behaviour.
6. **D1, core L272-273:** say that `run_check` returns its code rather than ending in `exit "$rc"` (plan-state:360), and that the `check)` branch becomes `run_check; exit $?`.
7. **D4, round and core:** show `-v CAP="$CAP"` on the `check` awk call, both in task-round and in core's `run_check`.

Growth: about +8 lines of plan text inside existing tasks. No new tasks, files or edges.

**B. Fix the P2/P4 acceptance criteria in task-preflight-declared** (resolves B3, plus DEFERRED D6 and D7).
1. **B3:** delete L484. Change L427-429 to say P2 never shares a path with P3 or P4. In its place, add a pair that can actually occur together, from ambiguity's suggestion:
   - Case: existing two-line `lib/two.sh` is declared by a root task `task-w` (`pending`), and `task-x` cites `lib/two.sh:5`.
   - Expected: exit 1, the P3 "past the end" error prints before the P4 warning.
   - Why it is reachable: P3's existing-path branch (L260) has no declarer condition, and P4 needs an existing path that a concurrent task declares.
   - Optional, from verifiability: add a P1-before-P2 case in task-preflight-edit.
2. **D6 (Mixed, L475-476):** state the edge: "`task-d` depends on `task-x` and `task-s`". Without an edge between the two declarers, rule 4 (plan-state:119-124) fails `check` first. With the reverse edge, `task-s` becomes a descendant and the case turns into a warning.
3. **D7 (L468-471, L482-483):** every "prints no line" case also asserts exit 0. A failed `check` (exit 1) or a crash (exit 2) cannot then pass it as an empty result.

Growth: about +4 lines.

**C. Make the core and edit fixtures able to fail** (DEFERRED D8-D12; optional, recommended while editing A).
- Write fixture text verbatim in single backticks inside a code block. This fixes L354 and L565, where the double-backtick Markdown can be copied in a form no candidate is read from.
- Add a case that depends on the normalization strip: absent `` `lib/gone.sh:4.` `` (period inside the backticks) gives a P3 error showing `lib/gone.sh:4`; and `` `./lib/new.sh:9` `` with `lib/new.sh` in the task's own `files:` prints nothing.
- Add exclusion negatives: `` `src/*.ts` `` and `` `../up/x.md:3` `` print nothing.
- Add a file with no final newline cited at its last line, which must print nothing.
- Say "each citation in its own run" for L362-364.
- Say the `:0` test is numeric ("N is 0").
- Assert that usage output still contains `Exit:` with the new wording.

Growth: about +10 lines.

**D. The write-failure path** (DEFERRED D13-D15). The author chooses between two options:
- Keep the exit-2 mapping inside `emit`, and add a Context line saying `set` and `render` now also exit 2 on a write failure, on purpose.
- Or confine the mapping to `round`.

In either case, run the unwritable-plan case as `bash "$SCRIPT" round ...`. Under dash, a failed redirection already exits 2, so the test proves nothing there. The two options trade a uniform exit code against the spec anti-goal at L50-53. Nothing in the evidence decides between them.

**E. A test that the count survives a restart** (DEFERRED D16): add a task-round case that runs `round`, `set ready`, `set running`, then `round`, which must print `2`. Add one `round` case on a task that is not first in the file, and assert task-a's block is unchanged. Growth: about +3 lines.

---

### Resolution interactions

- **A.1 (rename `ms`) with A.2 (save the match position):** same code block, different names. Benign.
- **A.2 with A.3 and A.4 (the edit task's offset and `addc` parameter):** coupled. If only A.2 lands, task-preflight-edit's `off += RSTART + RLENGTH - 1` brings the clobbering back. They must land as one edit.
- **A.6 (`run_check` returns) with A.7 (`-v CAP` on the check call):** the CAP flag belongs on the awk call inside `run_check`, not only in task-round's `check)` branch. Benign if both are written into core.
  - Under `set -eu`, `run_check || exit 1` turns off `set -e` inside the function body. The existing body already uses `|| rc=$?`, so nothing new becomes possible.
  - `check)` as `run_check; exit $?` exits with the same code as today.
- **A.5 (resume after the negated verb) with the L564 case `Do not edit the header; update`:** after skipping `edit`, the rest of the line is ` the header; update `, the prefix before `update` is not negated, and the function returns 1. Benign.
- **B.1 (new P3+P4 case) with A.1:** two checks on one path need the renamed message array to hold two entries. B depends on A, and the plan's existing order (core before declared) already guarantees that. Benign.
- **B.2 (Mixed edge) with P2's descendant test (L440):** with `task-d → task-s`, `task-s` is neither `task-x` nor its ancestor nor its descendant, so the result is an error naming `task-s`, as the case expects. Benign.
- **B.3 (assert exit 0) with check-first:** exit 0 needs a fixture with no other error-level citation. Fine with the fixtures as described. Benign, but the fixture helper (`pf_plan`, L340) must not add any.
- **C (more fixture paths) with D20 (the plan fails its own preflight):** each new absent path written in a code fence in this plan adds a P3 hit when `preflight` runs over this plan while the chain tasks are unfinished. Harmless for this run, because preflight only runs automatically after the chain is `done`. It would show up if the author reset a chain task and re-ran the updater.
- **D (keep or confine the mapping) with the bash-only test:** either choice keeps the bash test meaningful. Benign.
- **E (restart test) with D:** E runs `set`'s write path with `RRID` empty. The new lines in the write path are guarded by `RRID != ""` (L145-146), so they do not fire. Benign.
- **EU-A (mawk AC) with A.1:** if mawk does reject mixed scalar/array use when it reads the program, the old `ms` would break every command under mawk. The rename fixes that, and the EU-A criterion is what would catch a repeat. They complement each other.

### Artifact growth

`Artifact growth: +0 tasks · +0 files newly in scope · +0 dependency edges · ~+12 lines (blocking only: A.1-A.4 and B.1) / ~+30 lines (with the recommended A.5-A.7, B.2-B.3, C, E)`

This is the plan's first audit round, so there is no round-over-round trend. Everything stays inside existing task bodies.

---

### Contradictions between lenses

1. **The scope of the `ms` clash.** Grounding: gawk rejects it while parsing the program, so `check`, `ready`, `set` and every other mode fail (probe quoted). Charter: gawk rejects it at parse time (from the language rule; it did not run anything). My probe: under gawk 5.4.1, an uncalled `note()` runs fine (rc=0), and calling it after `ms` became a scalar is a runtime fatal (rc=2). Both lenses are right that the finding is BLOCKING, but wrong about its reach under gawk. Their test program probably called `note()`. Resolution: under gawk only `preflight` breaks; mawk is open (EU-A). What I read: plan-state:84, :223, :241-247 and my probe output.
2. **Context-sufficiency's hand-off check against coherence's `addc` finding.** Context-sufficiency (Checked): "The names that task-preflight-declared and task-preflight-edit rely on all match core's sketch." Coherence (DEFERRED): edit's 3-argument `addc` call does not fit core's `function addc(t, raw,   p)`. Coherence is right: L315 versus L528-529. Context-sufficiency checked the named list (`kind`, `dcl`, `note`, `cite`, `cp`/`cs`) and not `addc`'s signature.
3. **Ambiguity's "each path-rule clause has a discriminating AC" against verifiability's untested clauses.** Ambiguity (Checked) says the path rule and its exclusions each have a discriminating AC at L357-376. Verifiability (DEFERRED) says no fixture has `*`, `../`, `://`, `./`, a fenced `# ` line or a file without a final newline. Verifiability is right: the fixtures at L352-388 contain none of those. Ambiguity's own strip finding (D8) partly contradicts its clean bill.
4. **Coverage's "G4 full" against verifiability's "Goal 4 has no test".** These look opposed but answer different questions: coverage asks who owns the requirement, verifiability asks whether a test exists. Both are right. The spec's test list (L211-214) does not ask for a restart test, so D16 stays DEFERRED.
5. **Charter declined to raise `run_check` (Checked); coherence flagged it out of lens.** Same fact (plan-state:360 ends `exit "$rc"`), different decision about raising it. Recorded as D1: DEFERRED, because every positive P3 test fails at once with no output and that points straight at the cause.
6. **Verifiability's BLOCKING on the "prints no line" P2 tests** has no opposing lens, but I downgraded it after reading `check()`: plan-state:82-126 does not compare mermaid edges with `depends_on`. See the downgrade log.

### Stale vs defect

Every finding below is a **DEFECT** (or a non-defect, where noted). None is **STALE**. Downstream: the audited plan is the only consumer of the spec, all tasks are `pending`, and nothing has landed.
- B1, B2, B3: DEFECT.
- D1-D20: DEFECT, except D18 (executor SKILL.md:118), which I judged **no defect** after reading (see Deferred).

### Deferred

**awk code in the plan (all fixed by Joint A):**
- D1. `run_check` must `return`, not `exit "$rc"` (core L272-273; plan-state:360). From charter and coherence.
- D2. `editverb` counts negated verbs. The loop resumes at `RSTART + 1` (edit L536). Grounding and coherence probed it; ambiguity traced it. The AC at L563 states the right behaviour, and the spec leaves negation to the builder (spec L221-222). Three lenses agree.
- D3. edit's `addc(t, raw, prefix)` call does not fit core's `addc(t, raw,   p)`, so `cpre` is never set and P1 never fires. Coherence. (Its offset arithmetic is part of B2.)
- D4. The `check` awk call has no `-v CAP`. With CAP unset, rule 15 flags valid values 1-3. The task-round AC "prints nothing for … 3" catches it. Grounding.
- D5. The plan's new globals were only partly checked against `PROG` (charter's grep found no other collision). Folded into A.1's list of taken names.

**task-preflight-declared acceptance criteria (Joint B):**
- D6. The Mixed fixture fails `check` with rule 4 unless the edge between the two declarers is stated (L475-476; plan-state:119-124). Context-sufficiency.
- D7. The "prints no line" P2/P4 cases do not assert an exit code (L468-471, L482-483). Downgraded from BLOCKING; see the log. Verifiability.

**core and edit fixtures (Joint C):**
- D8. No case depends on the trailing-punctuation strip or on the leading-`./` strip. `` `lib/two.sh.` `` passes either way (L352-356). Verifiability and ambiguity agree.
- D9. The exclusions, a fenced `# ` line, an exact `files:` match without `/`, and a file with no final newline have no case (L232, L241-247, L253-254). Verifiability.
- D10. The double-backtick fixtures can be copied in a form no candidate is read from (L354, L565). Ambiguity.
- D11. The six line-range citations of one path need separate runs, because of the one-line-per-(task, path, check) rule (L362-364 against L266-268). Context-sufficiency.
- D12. "`:0`" can be read as a string or as a number (L261-262). The wording comes from spec L103. Ambiguity.
- D17. Neither header edit asserts that the `Exit:` line still prints (L108-109, L275-278, L206-207). Verifiability.

**Write path (Joint D):**
- D13. The `emit` mapping also changes `set` and `render` on a write failure (L117-118, L149-158 against spec L50-53). No caller branches on the code. Coverage.
- D14. The unwritable-plan test cannot fail where `sh` is dash, which already exits 2 (L200-204). Verifiability probed it.
- D15. `cat "$tmpf" > "$plan"` truncates the file before writing, so "leaves the bytes as they were" holds only when opening the file fails, not when a write fails partway. The spec's test (L214) covers only an unwritable plan. Context-sufficiency, out of lens.

**task-round (Joint E):**
- D16. Goal 4 (the count survives a restart) has no test, and `round` is only exercised on the first task in the file (L111-112, L184-205). Verifiability, with ambiguity noting it out of lens.

**Documentation and scope:**
- D18. Coverage (out of lens) noted that executor SKILL.md:118 says "NEVER mutate `running` … tasks via this skill" while `round` writes into a running task. After reading the line, I judge it **no defect**. The rule protects statuses ("managed by the dispatch loop only"); `round` changes `review_rounds`, not the status, and the dispatch loop is what runs it. It is recorded here so it is not lost.
- D19. Doc edits the spec does not list: the README's Testing paragraph, the updater's "rules 7–12" → "7–15", and task-readme waiting on task-preflight-edit (L846-847, L898, L914-916). They are accurate. Coverage.
- D21. The P2 warning message departs from the spec table's single P2 message (L418-420 against spec L102). No consumer matches on message text. Record that it is deliberate. Coverage.
- D22. writing-dag-plans SKILL.md:155 "rules 1-8, 11-12" is already out of date and is left untouched. An optional one-line fix in task-writer. Charter.
- D23. The implementer-prompt insertion "after the first sentence" (L683-684) puts a paragraph between "…PLUS the issue list:" (implementer-prompt.md:128) and the tier note and fence that follow. The file already has one line in between. A readability issue only. Coherence, out of lens.
- D24. `round` writes through `emit`, which always redraws the mermaid block (plan-state:243), so a `round` on a plan with a stale block changes more than one field. `set` already behaves this way. Verifiability, out of lens.

**Plan's own text:**
- D20. The plan fails its own `preflight` while its chain tasks are unfinished: the code-fence fixtures at L341, L344, L458-460 and L548 give P3 errors. Harmless for this run. Dag-integrity.

### Empirical unknowns

- **EU-A. mawk and busybox awk.** Merges grounding's EMPIRICAL-UNKNOWN, verifiability's DEFERRED (no mawk/busybox coverage), and charter's unconfirmed mawk/busybox behaviour for B1.
  - The question: does the new awk run the same under them? That covers dynamic-regex `match` loops, `"\047"` inside a regex string, `getline < PFTAB` in END, `(t, u) in anc`, `tolower`, and mixed scalar/array use of one name. CLAUDE.md requires mawk and busybox.
  - Neither is installed on this host (gawk 5.4.1 only, per verifiability's and grounding's checks).
  - Owner: task-preflight-edit. It is last in the `plan-state` chain, so all the new awk exists by then, and its `files:` include the suite.
  - Settling command: `PATH="$shimdir:$PATH" bash tests/plan-state/plan-state.test.sh`, where `$shimdir/awk` runs `mawk "$@"` (and again with `busybox awk "$@"`). The run must end `RESULT: N passed, 0 failed`.
  - Acceptance criterion to add to task-preflight-edit: "When `mawk` or `busybox` is on PATH, the suite's `$ALTSH` cases also run with it as `awk` and pass; when neither is present the suite prints one `NOTE:` line, as it does for dash (tests/plan-state/plan-state.test.sh:7)."
- **EU1 (the git-root probe)** is the spec's known item. It already belongs to task-round's unwritable-plan case (L200-204), which handles it with a `NOTE:` line, and needs no new criterion.

### Downgrade log

| Lens | Claim | Proposed | Final | Reason |
|---|---|---|---|---|
| verifiability | The only tests of P2's ancestor exemption are "prints no line" cases with no exit code, so an ancestor-blind P2 passes the whole suite | BLOCKING | DEFERRED (D7) | The failure needs two separate mistakes: a fixture edit that breaks `check` (the global `sed` self-loop) and an ancestor-blind P2. `check()` does not compare mermaid edges with `depends_on` (plan-state:82-126), so a correctly added edge passes `check`. The existing assertion `hasnt lib/made.sh` then fails an ancestor-blind P2, because its error line names `lib/made.sh`. The weakness is real, so the exit-0 assertion is folded into Joint B. |
| grounding, charter | The `ms` clash fails every command (gawk catches it while parsing) | BLOCKING | BLOCKING (unchanged severity, narrower reach) | My probe: under gawk 5.4.1 it is a runtime fatal only when `note()` runs, so only `preflight` breaks. The every-command claim is moved to EU-A for mawk. |
| verifiability | No mawk/busybox coverage | DEFERRED | EMPIRICAL-UNKNOWN (EU-A) | Merged with grounding's identical empirical unknown. Changed category, not lowered. |

**Promotions:**

| Lens | Claim | Proposed | Final | Reason |
|---|---|---|---|---|
| coherence | `cands` reads a clobbered `RSTART`/`RLENGTH` | DEFERRED | BLOCKING (B2) | My probe confirms the loop never ends. Coherence's DEFERRED rested on "a test-first implementer hits it at once", but a hang gives no failure message, and every `preflight` fixture and both real-plan cases hit it. Same failure class as B1, with worse diagnosis. |

All other DEFERRED findings keep the lens's severity. Out-of-lens notes from coverage (D18), coherence (D1, D23), context-sufficiency (D15), verifiability (D24) and ambiguity (D2, D16) carried no severity and were assigned DEFERRED (D18: no defect). No finding was deleted.

### Unverifiable

- **mawk and busybox behaviour of the `ms` clash and the new awk** (charter's "mawk rejects it as a type clash"). It could not be settled because neither awk is installed here. It would take running the suite under each, which is EU-A.

### Solid (do not touch)

- **DAG.** The mermaid block matches the `depends_on:` lists (10 edges). The graph is acyclic with a single root, and no `depends_on` points to a missing task. Every pair of tasks sharing a file is ordered: the 4-task `plan-state` chain, and exec-cap → exec-preflight on SKILL.md. All other `files:` are unique. There are no false or missing edges and no understated `files:`. T22-T25 are free test numbers. (dag-integrity, charter, coherence)
- **Coverage.** Every spec requirement and constraint has an owning task, including J9 (the real-plan case) and EU1 (the root probe). There are no orphan tasks. The updater's added "Add task" trigger is within spec Goal 2. No task touches `plan-quality.md`, as the H8 clause requires. (coverage)
- **Anchors in the repo.** Every anchor the doc tasks edit exists exactly as quoted, en dashes included. The `rg` counts hold today: 12 numbered lines in the executor SKILL, 15 writer steps, 3 `ISSUES → re-dispatch implementer` lines. Each "failing check before the change" prints nothing today. No test reads the doc files. (grounding, verifiability, context-sufficiency, ambiguity, charter)
- **Code the plan builds on.** `emit` is the one write path (plan-state:324-329). `set` rewrites only the status line (:245). Rule 11's root expression appears at :336 and :351. `ancestors()`, `inset()`, `stl[]`, `has[]` and `val[]` exist as described. The suite helpers `ps`, `chk`, `has`, `hasnt`, `clean_plan`, `$ALTSH` and `$REPO` exist. Both real plans pass `check` and are entirely `done`. (all lenses)
- **Charter.** The plan's code uses no `gensub`, `strftime`, `asort`, `\x` or bash-only syntax. No new extensionless file, so `.gitattributes` needs no change. Each script task pairs the script with its suite. (charter)
- **task-round.** The order of refusals is total and every step has its own test. The pending-at-3 case tells a status check apart from a value check. The CRLF case checks every line. Rule 15 has both negative and positive cases. (verifiability, ambiguity)
- **Shared contracts.** The cap contract (CAP=3, `round`, `review_rounds`, rule 15, exit 0/1/2, the message text) and the preflight contract (P1-P4 levels, line format, check-first, the finding key) are stated the same way in all 10 tasks. (coherence, context-sufficiency)
- **Workload.** task-preflight-core is the largest task but has no natural split point. The serial chains are forced by shared files, and the doc tasks fan out as early as possible. (context-sufficiency)

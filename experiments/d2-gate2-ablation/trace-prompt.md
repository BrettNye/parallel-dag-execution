# Finding trace prompt

Dispatch one fresh `general-purpose` subagent on Opus 5.5 after all six runs, their hidden
checks and their blind reviews are done. Build its inputs first:

- **Findings:** every BLOCKING finding gate 2 fixed between S0 and S2, from the
  reconciliation files of each round, numbered F1, F2, ... with the round that fixed it.
- **Runs:** the blind-review letters (`runs/blind-key.txt`), never arm names. For each run,
  copy its evidence into `runs/trace/<L>/`, renamed by letter: its execution transcripts
  (`exec-1.jsonl`, ...), its preflight output if it halted, its hidden-check output, its
  blind review, and `git diff <base>..<head> -- . ':(exclude)<plan>'` as `diff.patch`.
  Give the tracer those paths only: no branch names, worktree paths or project-dir paths,
  which carry a run id the run map ties to an arm.
- **Which runs lacked which fix:** computed by you from the snapshot each run used (S0 runs
  lack every fix; S1 runs lack fixes from round 2 on; S2 runs lack none). Give the tracer
  only the list of (finding, letter) pairs to judge.

```
You are tracing what happened to known plan defects in runs that were executed without
the fix. You are told nothing about why the runs differ, and you must not guess.

Findings: {findings}        (each: id, claim, the plan text it was about, the fix made)
Runs: {runs}                (each: letter and its evidence directory, holding the
                             transcripts, preflight output, hidden-check output, blind
                             review and diff.patch)
Pairs to judge: {pairs}     (each: finding id, run letter)

For each pair, read the run's evidence and assign exactly one outcome:
- caught-by-preflight: the run's preflight output names the defect.
- caught-by-review: a per-task reviewer's ISSUES verdict raised it and the fix landed.
- broke-run: the affected task went BLOCKED, failed, or asked NEEDS_CONTEXT because of it.
- shipped: the defect is in the final branch (show the file and line, or the hidden-check
  or blind-review line that shows it).
- didnt-matter: none of the above; the implementer did the right thing anyway, or the
  defect had no effect.
When two apply, take the first in this list.

Give one line of evidence per pair: a file:line, or a quote from a transcript of at most
20 words with its path. Do not modify any file.

Output one table: finding | run | outcome | evidence. Then one line per finding with its
outcomes across runs.
```

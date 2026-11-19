# Finding trace result

The tracer was one fresh general-purpose Opus subagent, given `findings.md` and the evidence
directories by letter only. Brett spot-checked F3·U, F5·R and F1·T on 2026-11-18, and all three
held.

| finding | run | outcome | evidence |
|---|---|---|---|
| F1 | U | didnt-matter | U/exec-1-subagents/agent-a1ca87e05b36f04cd.jsonl: "Concern: the case the spec names, `round on "2" counts to 3`, came out not-red, exit 1, not ok. That is correct". Header U/diff.patch:213. DONE_WITH_CONCERNS. |
| F2 | U | didnt-matter | U/diff.patch:1182 `rm -rf "$td"/*  # the leaked temporary directory, as a tmp cleaner would remove it` before the next run, which expects `[3:0:1:empty]` (1186). Cleanup removes only `$work/after` and `$work/before`. |
| F3 | U | shipped | U/diff.patch:118 `+If your task's YAML block has a tests: list` is the only implementer-prompt.md hunk. Nothing adds `tests:` to MUST-receive or renders it in `## Task spec`. |
| F4 | U | didnt-matter | U/diff.patch:282 `if (!(f[i] in seen)) print "R " f[i]`: test files are never restored. No suite case pins it. |
| F5 | U | didnt-matter | U/diff.patch:282: test files are kept out of the restore list, so they are never deleted. No suite case pins it. |
| F1 | T | didnt-matter | T/diff.patch:199 `gave "ok" for 'round on "2" writes review_rounds: 3' and "not-red" for 'round on "2" counts to 3'`. DONE_WITH_CONCERNS. |
| F2 | T | didnt-matter | T/diff.patch:1229 `rm -rf "$TMPDIR"/*` before the next run, which expects `3:0:1:empty` (1232). |
| F3 | T | shipped | T/diff.patch:118: the same single hunk. Blob 9b26219 is identical to U's. |
| F4 | T | didnt-matter | T/diff.patch:271 `if (!(fl[i] in seen)) print fl[i] > p`: test files are excluded from restore. No pinning case. |
| F5 | T | didnt-matter | T/diff.patch:271, 277-283: only the non-test list is restored or deleted. No pinning case. |
| F5 | R | didnt-matter | R/diff.patch:307 `if (!(fl[i] in num)) print fl[i]`: test files are never deleted. No case for a new suite file. |
| F5 | P | didnt-matter | P/diff.patch:286 `[ "$is_test" -eq 1 ] && continue` comes before the delete at 290. No case for a new suite file. |

## Ruling: F4/F5 and the missing regression case

Brett ruled on 2026-11-18 that F4 and F5 are didnt-matter where the code is right but the
suite case that pins it is missing. The spec's "shipped" means the bug is in the final branch,
and here it isn't.

The missing case is real, though, and it is the visible cost of skipping round 2:
- the F5 case "new suite file is kept in the before tree" is in both full branches (Q, S) and in
  neither round1 branch (R, P);
- the F4 case "new case passing on old code is not-red" is in R, P, Q and S, and not in U or T.

## Corrections to the tracer's report

- It said no run had the F5 case. Both full runs (Q, S) do; it was asked about U, T, R and P only.
- It read the first line of some Q and S transcripts by accident, and used nothing from them.

Review of review-Z, 402d20b..d988421 (plan excluded). Suites pass under dash+gawk (plan-state 204/0, rdp 91/0, commit-safe both). mawk/busybox not installed locally.
[Important] [correctness] skills/writing-dag-plans/plan-state:185 — ownfile/decls/fset compare raw files: entries with ./-stripped candidates; files: [./lib/x.sh] + cite lib/x.sh:3 gives P3 error and P1 warning against own file — normalize files: entries with norm.
[Important] [tests] tests/plan-state/plan-state.test.sh:532 — sentence-final path case cannot fail if norm stops stripping punctuation — add cases whose result depends on the strip.
[Suggestion] [tests] tests/plan-state/plan-state.test.sh:452 — rg -c new ripgrep dependency — use grep -c.
[Suggestion] [tests] tests/plan-state/plan-state.test.sh:726 — pfrun | rg same rg dependency — use grep -F.
[Suggestion] [tests] tests/plan-state/plan-state.test.sh:530 — no tests for exclusions, ./ strip, exact files: match.
[Suggestion] [spec] skills/writing-dag-plans/plan-state:563 — round writes through emit, redraws mermaid — write only the field or document.
[Suggestion] [spec] skills/writing-dag-plans/plan-state:226 — P2 warning wording differs from the spec's table shape.
[Suggestion] [correctness] skills/writing-dag-plans/plan-state:154 — NAME=path and $var/path words become candidates; ~20 noise P3 warnings on seams plan.
[Suggestion] [correctness] skills/writing-dag-plans/plan-state:363 — fences only at column 0; indented code blocks read as prose.
[Suggestion] [spec] skills/executing-dag-plans/spec-reviewer-prompt.md:100 — reviewer re-dispatch notes (also quality :117, merged :106) don't mention the cap.
TOTAL: 2 Important, 8 Suggestion

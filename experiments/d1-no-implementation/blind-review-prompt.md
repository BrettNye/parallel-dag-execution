# Blind final review prompt

Dispatch one fresh `general-purpose` subagent per branch, on Opus 5.5 at default effort,
with the prompt below. Fill the placeholders per branch. Label the branches X and Y by
coin flip, and keep the X/Y-to-arm key in `runs/blind-key.txt`, which the reviewer
never sees. Give the reviewer nothing else: not the plan, not the experiment design,
not the other branch.

```
You are reviewing a finished feature branch before it merges.

Repository: {repo_path}
Base commit: {base_sha}
Branch head: {head_sha}
What the branch was meant to deliver: {spec_path} (read it in full)
Project conventions: CLAUDE.md at the repository root.

Read the full diff (`git diff {base_sha}..{head_sha}`) and as much of the surrounding
code as you need. You may run the repository's tests. Do not modify any file and do not
commit.

Report every problem you find, in this form, one per line:

  [Important|Suggestion] [correctness|spec|convention|tests|clarity] file:line — problem — fix

- Important: a bug, a requirement of the spec that is missing or wrong, a convention in
  CLAUDE.md that is broken, or a test that cannot fail when the behaviour breaks.
- Suggestion: anything else worth changing.

Do not report style preferences the conventions don't state. Do not soften or merge
findings; one problem per line. End with one line: `TOTAL: <n> Important, <m> Suggestion`.
```

Scoring: count Important and Suggestion lines per branch from the reviewer's report.
The decision rule uses Important only. Record the `convention` category separately as
the convention-slip count.

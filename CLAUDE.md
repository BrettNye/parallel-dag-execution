# parallel-dag-execution

A Claude Code plugin: skills, agents and commands that write, audit and execute DAG plans.

## Conventions

- The helper scripts (`skills/writing-dag-plans/plan-state`,
  `skills/executing-dag-plans/git-commit-safe`,
  `skills/auditing-artifacts/resolve-declared-paths`) are POSIX sh and awk. They must
  run under dash as well as bash, and under gawk, mawk and busybox awk: no bash-only
  syntax, no gawk-only functions (`gensub`, `strftime`, `asort`), no `\x` escapes in awk.
- Line endings are LF. An extensionless script must be listed in `.gitattributes` with
  `text eol=lf`.
- Each script has a suite under `tests/<suite>/`. Run a test file with
  `bash tests/<suite>/<file>.test.sh`; it ends with `RESULT: N passed, M failed` or a
  `PASS` line, and exits non-zero on failure.
- Skills and prompts are written in plain words. Rules state what to do and why, once.
- Commits use conventional prefixes (feat, fix, docs, test, refactor, chore); the body
  says why.

## Running the tests

```bash
for t in tests/*/*.test.sh; do bash "$t" || exit 1; done
```

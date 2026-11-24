# Functional suite prompt

Dispatch one fresh `general-purpose` subagent on Opus 5.5 after the E3 spec has passed gate
1 and before any plan exists. Give it this prompt and nothing else: not a plan, not a branch,
not this experiment's design. Fill the placeholders.

```
You are writing an acceptance test suite for a feature that has not been built yet. The
suite will later be run against several independent implementations of it. You will not
see any of them.

Spec: {spec_path} (read it in full; it is the only source of truth)
Repository: {repo_path}, at commit {base_sha}. Read it to learn how commands are invoked
and how the existing suites in tests/ are written. Do not modify it.
Write the suite into: {suite_dir}

Rules:
- Test only behaviour the spec pins down: commands, arguments, exit codes, and output.
  Never test internals, file layout inside a script, or wording the spec does not fix.
- Where the spec leaves a behaviour open, do not guess. List it at the end of your report
  under "not tested: spec leaves open", one line each, with the spec line.
- Each case names the spec line it tests, in its case name: `chk "L42: ..." ...`.
- Write bash files named <topic>.test.sh in the style of the repository's suites: ok, bad,
  chk helpers; each case prints "  PASS: <name>" or "  FAIL: <name> ..."; the file ends
  with `echo "RESULT: $passes passed, $fails failed"` and exits non-zero on any failure.
- Each file runs with the root of a working copy as the current directory. Build any
  fixture under a temporary directory and remove it at exit. Call the repository's
  scripts by their path from the root (e.g. `sh skills/writing-dag-plans/plan-state`).
- Use only POSIX tools plus bash, git and rg. No network.
- The feature does not exist at {base_sha}, so every case should fail there. Run the suite
  once at {base_sha} and report any case that passes: it tests nothing new.

Report: the files you wrote, the number of cases per file, the cases that passed at
{base_sha}, and the "not tested" list.
```

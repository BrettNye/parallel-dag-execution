You are converting one DAG plan into a contracts-only plan. Work only on the file named
below, in the current repository. Do not read any other plan, spec, or audit file.

Plan file: {plan}

The plan format's rule 14 (skills/writing-dag-plans/plan-format.md, "Contracts-only plans")
defines the target: a plan whose frontmatter sets `implementation: contracts-only`, where
each task without `is_wiring_task: true` has a `## Contracts` section and no
`## Implementation` section. A `## Contracts` section holds signatures only: function names
and arguments, command usage, exit codes, output and file formats. No function bodies, no
test code. Fenced code blocks are allowed for the signatures.

Make exactly these changes and nothing else:

1. Add `implementation: contracts-only` to the frontmatter, after the last existing key.
2. In each task that has a `## Implementation` section, replace that heading with
   `## Contracts`, and replace the section's content with what it states about interfaces:
   - keep: names and arguments of functions, commands and subcommands; usage lines; exit
     codes; exact output lines and message formats; file and field formats; names of new
     fields, rules and files; which existing file or section something goes in.
   - remove: function bodies, algorithms, code that implements behaviour, test code and
     failing-test blocks, step-by-step instructions on how to write the code, and idioms.
   - When a code block mixes both, keep only the signature lines (for awk or sh: the
     function or command line with its arguments) and the literal output formats.
   - If a section states nothing about interfaces, it becomes one line saying so, e.g.
     "No new interface: the change is internal to `<file>`."
3. Leave every other line of the file byte-for-byte as it is: frontmatter keys, the mermaid
   block, Context, task titles, YAML blocks, prose before the section, acceptance
   criteria, and `Test file:` lines. Wiring tasks stay as they are.

Then:

- Run `sh skills/writing-dag-plans/plan-state check {plan}` and fix only your own
  conversion until it prints nothing.
- List, without fixing them, any lines outside the converted sections that now refer to
  content you removed (for example "the failing test above" or "Block 2").

Report: the number of tasks converted, the number of wiring tasks left alone, the
plan-state result, and the dangling-reference list (or "none"). Do not commit.

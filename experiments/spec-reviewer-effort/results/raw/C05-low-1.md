APPROVED. I checked commit 17c408cf against Steps 1-9 of the spec using `git show` on the listed files only.

- **plan-format.md:** All of the following match the spec.
  - The three plan-level frontmatter keys are present with the exact comments, plus the "all three are optional" sentence.
  - The two new per-task fields are added after `model_hint`, and the `model_hint` comment now states its fallback chain.
  - The `## Tier resolution` section sits between the per-task frontmatter schema and the per-task body structure. It has the verbatim resolver, the three roles with the intentional naming asymmetry, and the "NOT an error" note.
  - Rules #7 and #8 are verbatim, followed by the line that they use the same refusal format as rules 1-6.
- **Should-refuse fixtures:** All three are correct. Each has its EXPECTED comment on line 1 and the single bad value the spec calls for (`model_hint: medium`, `default_spec_reviewer_hint: pro`, `quality_reviewer_hint: 0`).
- **Should-pass fixtures:** All five are correct. Each has the right EXPECTED comment and the right hints. `clean-mixed-tiers` has two tasks, the mermaid nodes and the edge `task-1 --> task-2`, `depends_on: [task-1]`, and a test-file line for each task.
- **Over-build:** None found. The commit touches only the nine listed files.

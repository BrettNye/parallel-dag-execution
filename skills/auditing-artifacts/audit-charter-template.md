# Audit charter template

Copy to `.claude/audit-charter.md` in a repo that wants one. **Optional** — the
lenses already read the repo's own `CLAUDE.md`, convention docs, and boundary
docs, and perform well on those alone.

## Grow it from audit records — do not author it up front

This is the load-bearing instruction. A charter written in one sitting duplicates
the convention docs, drifts out of date, and then **contradicts the code** — at
which point lenses correctly report the contradiction as a finding and the charter
has become a churn generator. That is the exact failure this design exists to
remove.

Every section has a natural source in audit output (see `SKILL.md` step 10):

- A DEFERRED finding accepted for the second time → **frozen decision**.
- A severity the reconciler corrected because enforcement was assumed rather than
  read → **enforcement map** row.
- A finding class that recurs across plans → **recurring bug class**.
- A `charter`-lens complaint that a task named no reference file → **reference
  implementation** row.

Start empty, or start with only the enforcement map — the one section that
immediately changes verdicts. Let the rest accumulate.

Add a charter entry only for what the repo's other documents structurally cannot
hold:

1. **Enforcement reality** — which conventions are actually enforced, and by what.
2. **Recurring bug classes** — the mistakes this repo makes repeatedly.
3. **Named per-layer reference implementations** — the one right file to mirror.
4. **Repo-wide frozen decisions** — settled questions, with their reasons.

Keep it short. A charter that duplicates the convention docs will go stale and
start contradicting them, at which point it is worse than absent. Cite code, not
prose — a charter entry with no `file:line` is the same unverifiable assertion the
lenses exist to catch.

---

```markdown
# Audit charter — <repo>

## Enforcement map

What is actually enforced, and by what. A lens grades an unenforced convention as
DEFERRED, so getting this wrong changes verdicts.

| Rule | Enforced by | Consequence if violated |
|---|---|---|
| e.g. layer boundaries | `eslint.config.mjs:17` depConstraints — **currently `*`/`*`, i.e. NOT enforced** | drift only, no CI failure |
| e.g. migration snapshots | `nx run <app>:check-migrations`, a `dependsOn` of `test` | surfaces as a confusing test failure |

## Hard invariants

Rules that must never be violated, each with the code that demonstrates it and
the concrete failure if broken.

- **<invariant>** — `<file:line>`. Breaking it: <what fails, and whether anything
  catches it>.

## Named reference implementations, per layer

The reference varies by layer, so name one per layer. "Follow the existing
pattern" is not actionable, and pointing at a spec instead of code is not either.

| Layer | Mirror this | Not this |
|---|---|---|
| e.g. API module | `src/<domain>/<domain>.module.ts` | <the outlier that looks similar> |

## Recurring bug classes

Mistakes this repo has made more than once. For each: the tell, the check, and
why the usual verification misses it. These are the highest-value entries in the
file, because they are exactly what a generic auditor cannot know.

- **<name>** — Tell: <what it looks like in a spec or plan>. Check: <the concrete
  command or grep>. Why tests miss it: <mechanism>.

## Frozen decisions (repo-wide)

Settled questions. A lens may challenge one only with new grounded evidence that
it is factually wrong — never because it would have chosen differently.

- **DECIDED:** <what> — because <why> — <date>

## Verification gotchas

Commands that can report success while having failed, and what to run instead.

- `<command>` — <how it lies> → use `<alternative>` instead.
```

---

## Notes

- **Where a charter entry and the code disagree, the code wins**, and the stale
  entry is itself a finding. Lenses are instructed to report that.
- The `charter` lens reads this file; other lenses read it for their own concern
  (e.g. `verifiability` uses the verification gotchas, `grounding` uses the
  recurring bug classes). Write for all of them, not just one.
- If this file does not exist, lenses proceed and say so once. Absence is not an
  error.

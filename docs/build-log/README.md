# Build log

How plans 2 and 3 were actually built, kept because the commits say *what*
changed and these say *why*. Nothing here is current documentation: the design
is `docs/superpowers/specs/2026-09-19-goblinps-design.md` and the plans are in
`docs/superpowers/plans/`. Read those first; read this when you want to know
why a decision went the way it did.

These files lived at `.superpowers/sdd/` while the work was in flight, so paths
written inside them point there. That directory is gitignored scratch space and
is reused by later plans; this copy is the permanent one.

## What each kind of file is

| File | What it is |
|---|---|
| `progress.md` | **The ledger. Start here.** Every ruling made while the plan ran, with the reasoning and an "if wrong" escape hatch. This is the file worth keeping. |
| `task-N-brief.md` | What an implementer subagent was told to build. Long, because a brief carries the full intended content of every file it touches. |
| `task-N-report.md` | What that subagent reported back, with its test counts. |
| `*-review*.md` | A reviewer's findings and verdict, rated Critical / Important / Minor. |
| `implementer-common.md`, `reviewer-constraints.md` | The rules every subagent on that plan worked under. |

## The reviews, in order

- `2026-09-19-goblinps-planner-window/final-fix-report.md` — plan 2.
- `2026-09-19-goblinps-ground-crossings/final-fix-review.md` — plan 3's fix
  wave, re-reviewed after its implementer was interrupted before reporting.
- `2026-09-20-overnight-review.md` — an adversarial review of work done
  unattended overnight. Approved with minors; both Important findings were
  real and were fixed in `1903f13`.

## The diffs are not here

Each workspace also held `review-<A>..<B>.diff` files. They are left out
because every one is reproducible, and its own filename is the command:

```bash
git diff <A>..<B>
```

All those commits are on `main`, so nothing is lost. Keeping them would have
put 536 KB of the repository back inside the repository.

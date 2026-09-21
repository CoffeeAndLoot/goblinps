# Build log

How plans 2 to 6 were actually built, kept because the commits say *what*
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
- `2026-09-20-dash-unit/final-review.md` — plan 4's whole-branch review, and
  `final-fix-report.md` beside it. Six defects in that plan were caught by
  review rather than by tests, every one because a reviewer ran the code
  instead of reading it. `progress.md` holds the eleven rulings made while
  it executed, including why the compass had to read `Trip.ROTATION_SIGN`.
- `2026-09-20-planner-art/final-review.md` — plan 6's whole-branch review,
  with `fix-brief.md` and `fix-report.md` beside it. One Critical: the planner
  screen's scenery was drawn, cropped correctly, and **invisible**, because an
  opaque panel sat at the same rectangle two frame levels above it — the same
  fault the branch had just fixed one level up, reproduced one level down. Its
  closing line is the lesson: nothing on that branch asserted a texture was
  *visible*, only where it was and how big. `progress.md` holds 23 rulings,
  including the two places my own ruling R18 walked past the bug it was
  standing next to.
- `2026-09-20-dash-second-design/final-review.md` — plan 5's whole-branch
  review, with `fix-brief.md`, `fix-report.md` and `re-review.md` beside it.
  Three Important findings, all of them things the tests could not see: an
  opaque rectangle the device frame drew under its own round art, a device
  size that was the one layout number still hand-typed, and a fake-frame
  harness that mis-parsed `SetPoint`'s three-argument form — which meant the
  regression test guarding this branch's worst finding passed on garbage.
  `progress.md` holds the rulings, including the one the fixer talked me out
  of.

## The diffs are not here

Each workspace also held `review-<A>..<B>.diff` files. They are left out
because every one is reproducible, and its own filename is the command:

```bash
git diff <A>..<B>
```

All those commits are on `main`, so nothing is lost. Keeping them would have
put 536 KB of the repository back inside the repository.

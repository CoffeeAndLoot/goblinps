### Task 5: look at it, and say what was built

**Files:**
- Modify: `CLAUDE.md`, `docs/manual-test-checklist.md`,
  `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`,
  `GoblinPS/GoblinPS.toc` (version)

- [ ] **Step 1: Composite the strip from the shipped art, and look at it**

This is the spec's "a composite of the strip from the real art at its
geometry, looked at". It is a verification, not a deliverable: write the
script in the session's scratchpad, not the repo. With Pillow, at 650x416:
paste `GoblinPS/Media/planner-frame-wide.tga` (cropped by its `Art.lua`
coordinates) full size; then, for a six-stop route (crest, ride, flight,
ride, zeppelin, signpost) and for an eleven-stop route, paste each badge TGA
scaled to 58.5 px centred at the positions Task 4's test computes, each leg's
`line-solid`/`line-dashed` TILED at 104x13 px from centre to centre, and
`line-dot` at 13 px mid-leg. Save both PNGs to the scratchpad and **look at
them** with the Read tool. Check: badges sit on the line's centre, the first
leg solid and the rest dashed, no dash bunched at a seam, the end badges clear
the brass, eleven stops fit without overlapping. Anything wrong is a Task 4
fix, found before the user's game time is spent on it. Record what you saw in
the ledger.

- [ ] **Step 2: The checklist**

In `docs/manual-test-checklist.md`, add a section after "A trip survives
everything except Stop (plan 7)":

```markdown
## The planner as designed (plan 8)

Needs a full game restart, not `/reload`: the TOC gained `Strip.lua`.

- [ ] `/gps` opens one wide window: one search box, the screen, Start Route.
      No From, no Here, no Wide/Tall button, no step list
- [ ] With nothing picked, the screen shows the two status lines and no strip
- [ ] Brill to Orgrimmar reads crest, boot or horseshoe, zeppelin, signpost;
      the first leg solid, the rest dashed, a glowing dot mid-leg; the badges
      sit on the line, not above or below it
- [ ] Hover each badge: the step, its time, and its detail line where it has
      one; a zeppelin says it includes the wait
- [ ] A long route (try a far city on the other continent) shows every stop;
      when they crowd, the names go and the tooltips still say everything
- [ ] A leg into a zone above your level: its tooltip detail is amber and the
      amber line under the strip names that stop; the line itself is not
      coloured and no badge changes (the skull is day 2)
- [ ] The total under the strip reads like "~15 min · free"
- [ ] Type in the box: the results list drops over the screen and the amber
      line stays visible under it
- [ ] Start Route closes the planner and opens the dash; `/gps` mid-trip
      shows the trip's destination in the box
- [ ] `/gps selftest` lists the fifteen strip textures, all `ok`
- [ ] Nothing reads past the brass or overlaps: names under the end badges
      stay on the glass
```

In the plan 2 "Planner window" section, and any line that names the tall
layout, From, Here or the step list, add one line under the section heading:
`Superseded by plan 8: the window has one box, one layout and no step list.`
Do not delete the history.

- [ ] **Step 3: `CLAUDE.md` and the spec**

- Status paragraph: "plans 1 to 7 are built" becomes "plans 1 to 8 are
  built"; replace the sentence beginning "Next: plan 8, the planner rebuilt
  to the mockup" through "is unaffected." with: "Plan 8, built 2026-09-21,
  rebuilt the planner to the mockup: one search box, the route strip drawn by
  the pure `Strip.lua`, a tooltip on every stop, wide only. **Plan 8 has not
  been run in the client.**"
- Layout block: add `GoblinPS/Strip.lua           # pure: the route strip as data -- badges, spacing, tooltips, solid/dashed legs`
  after the `Route.lua` line, and change the `Planner.lua` comment to
  `# the window; draws Strip.lua's layout and decides nothing; no coordinate
  is hand-typed here -- every position comes from ns.Data.ArtGeometry.planner.wide`.
- The spec's plan 8 heading gets a line under it: "Built 2026-09-21 -- not yet
  run in the client."

- [ ] **Step 4: Version**

`GoblinPS/GoblinPS.toc`: `## Version: 2026.09.21.5` becomes
`## Version: 2026.09.21.6` (or the next free number for the day).

- [ ] **Step 5: Run every gate, then commit**

All five gates green.

```
git add CLAUDE.md docs/manual-test-checklist.md docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md GoblinPS/GoblinPS.toc
git commit -m "Docs: plan 8 built, and what to walk in game" -m "The checklist gains the planner-as-designed section and marks the old two-box window superseded; CLAUDE.md names Strip.lua and says plan 8 has not been run in the client." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

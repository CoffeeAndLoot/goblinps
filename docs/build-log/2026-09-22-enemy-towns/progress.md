# SDD ledger — plan: docs/superpowers/plans/2026-09-22-goblinps-enemy-towns.md

Spec: docs/superpowers/specs/2026-09-22-goblinps-enemy-towns-design.md (to be revised by Task 1 to the owner's ruling). Worktree D:\goblinps-wt\enemy, branch enemy-towns-build from enemy-towns.
Pre-flight: the plan author built all six tasks in a scratch worktree and ran every gate; counts Lua 471->472->477->479->497->505, Python 70->74.
Ruling: owner ruled 2026-09-22 that a place is hostile only when its faction is known (enemy flight masters + tools/town-factions.csv marks); the generator stops inferring; Data/Hostile.lua dropped — costs if wrong: unmarked hostile towns route straight through until marked.
Ruling: plan rulings accepted (capital = hostile place named after its own zone; radius constants in Graph.lua; flight master named before marked town; bounding-box pre-check) — measured against real data — costs if wrong: an odd warning name or a circle a little small or large.
Task 1: dispatched (sonnet)
Task 1: minor (deferred, fix in final wave): read_town_factions opens the sheet as utf-8, not utf-8-sig; an Excel re-save with a BOM would fail loudly on the header
Task 1: complete (commits 8174c04..eedfe3c, review clean)
Task 2: dispatched (base eedfe3c, haiku)
Task 2: reviewed by the controller directly (16-line pure function, diff read in full: clamped projection correct; tests cover ends, middle, past ends, degenerate, continent) 
Task 2: complete (commits eedfe3c..d9b09d9)
Task 3: dispatched (base d9b09d9, sonnet)
Task 3: reviewed by the controller directly (data file + loaders + a check shown failing on planted rows)
Task 3: complete (commits d9b09d9..e519376)
Task 4: dispatched (base e519376, opus)
Task 4: review Approved as a faithful build; 2 Important plan-mandated defects:
Task 4: Ruling: the circle exemption applies only when the inside end is START, HEARTH, DEST or a stopover; crossing ends and flight-master stops get the plain segment test — the spec's "either end" let an Alliance walk cross Orgrimmar uncharged via its gates (reviewer's real-data probe) — costs if wrong: a route may be charged for leaving a gate the player wanted.
Task 4: Ruling: the penalty is a routing cost, never shown — edges keep real `seconds`, Dijkstra runs on `cost = seconds + penalty`, the result carries `cost` for the hearth-saving and hint comparisons; tidy's too-short rule exempts danger steps — putting it in `seconds` showed a phantom 10 min in totals, tooltips, the ETA and hints — costs if wrong: hearth/hint comparisons use cost where they should use time, or vice versa.
Task 4: minor (deferred): isCapital is a prefix match; a marked town that is also an enemy flight master is listed twice; the hostile sort would raise on a nil map
Task 4: fix round 1 dispatched (resume implementer)
Task 4: fix round 1/5 (2 addressed, 1 new open — hearth bar compared on cost; commits c89ac15..66cd06d)
Task 4: Ruling: the hearthstone bar compares real seconds (plain.seconds - best.seconds >= bar), never cost — the setting promises minutes saved; on cost the penalty alone could spend the stone on a slower trip — costs if wrong: a hearth that would dodge a town is refused and the route warns instead.
Task 4: fix round 2 dispatched (resume implementer)
Task 4: fix round 2/5 (1 addressed, 0 open; commits 66cd06d..d3bb896)
Task 4: minor (deferred): bar 0 now means "no slower" (ties included) where Core.lua:399 and the plan-9 spec say "faster"; ties are unreachable on real data; reconcile wording in the docs task
Task 4: complete (commits e519376..d3bb896, 2 fix rounds)
Task 5: dispatched (base d3bb896, opus)
Task 5: minor (deferred): FACTION {A=Alliance,H=Horde} duplicated in Route.lua:229 and Planner.lua:290
Task 5: Ruling: a hostile destination takes the one amber line under the strip first (as the plan says) — the line was already one-at-a-time; chat still prints every note — costs if wrong: a flight-path hint is hidden in the window on a trip into an enemy town.
Task 5: complete (commits d3bb896..c0a91ac, review clean)
Task 6: dispatched (base c0a91ac, sonnet)
Task 6: done (6a6e812); covered by the final whole-branch review
Final review: dispatched (base 238f0b799e9b7227f25da75ef3d34bb10988dfef, opus)
Final review: 3 Important (START exemption too coarse; crossing charged twice; turning-point "into") + minors
Ruling: head-away exemption replaces the chosen-end rule for the near end (any stop p is exempt from h when the leg never comes closer than p); far end exempt only for DEST or a stopover — fixes the edge-of-town replan and the double gate charge (reviewer scratch-probed both) — costs if wrong: a leg leaving a town sideways past its centre by <1 yd goes uncharged.
Final: one fix wave dispatched
Final review: fix wave d4d7add + CLAUDE.md rule; re-review all addressed, no new Critical/Important. Residual minors: turnsBack true on two rough legs (harmless), a/b-order ambiguity (wording only), CLAUDE.md long line, a turned-back crossing still charges cross seconds and shows its warn.

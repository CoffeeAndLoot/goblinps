# SDD ledger — plan: docs/superpowers/plans/2026-09-19-goblinps-ground-crossings.md

Spec: docs/superpowers/specs/2026-09-19-goblinps-design.md (decisions 15-19). Branch: ground-crossings, from planner-window 11b29bb.

Ruling: branched from `planner-window`, not `main` — plan 2 is built and reviewed but the user has not yet confirmed the click fix in game, so it is unmerged; plan 3 rewrites the same files (Planner, Core, API) and cannot sensibly start from main — if wrong: plans 2 and 3 merge to main together, a fast-forward either way.
Ruling: plain branch, not a worktree — the game junction targets D:\goblinps\GoblinPS.

## Pre-flight scan

All plan code was run together in a scratch copy before the plan was written: 160 Lua tests, luacheck 0 warnings. Cumulative counts checked in scratch: 122 -> 130 (Task 1) -> 155 (Task 2) -> 160 (Task 3). Every changed file is given in full, so there are no edit anchors to miss.

| Pair / task | Produces vs consumes | Found |
|---|---|---|
| T1 run.lua -> T2, T3 | lists Crossings, Zones, Travel modules and test_travel, test_crossings suites; skips missing files | consistent |
| T1 Travel -> T2 Route.StepDetail, T3 Core | For(level) -> {speed, walk}; Dangerous(range, level) | names and shapes match both callers |
| T2 Graph -> T2 Route | edge fields zone, walk, rough; stop fields zones, warn | Route.Find and tidy copy all three; StepDetail reads step.zone and step.to.zones/warn |
| T2 Route.Plan fallback | retries with opts.rough only when the first plan is nil | guarded against recursion by `opts.rough` |
| T2 Links.lua | Islands removed | no remaining reader: Graph no longer has landOf; test_data's helper removed in the same task |
| T2 configs | .luacheckrc exempts Crossings.lua line length; both configs gain UnitLevel (used in T3) | harmless early declaration |
| T2 -> T3 | places must carry `map` | Core.here() and Search places always do; test fixtures updated in T2 |
| T3 API.Level -> Core -> Planner | plan.level used by StepDetail in chat and rows | consistent; test_ui stubs API.Level |
| T3 TOC | adds Data\Crossings.lua, Data\Zones.lua, Travel.lua before Search/Graph; version 2026.09.19.3 | load order satisfies load-time captures (none new) |
| T4 docs | spec sentences are hard-wrapped | dispatch note: replace whole sentence, re-wrap that paragraph only |
| each task, self | tests vs code | each ran green in scratch |

Plan-mandated items a reviewer may flag: crossing coordinates are estimates from memory (spec decision 15 and the checklist own this); six rows are `unverified` guesses for Forever's new zones; Travel's mount levels are unconfirmed (spec decision 17).

Scan clean.

## Progress
Task 1-2: implemented 11b29bb..47f9dcf (a83551c, 47f9dcf); all 15 files byte-identical to the verified copy; Lua 155/0; review dispatched. Note: the implementer's commit trailer names the model that wrote it (Claude Sonnet 5), which is accurate.
Task 3: implementer dispatched in parallel (touches disjoint files)
Task 2: review finding (Important, contested): "Un'Goro Crater does not border Silithus; the row should be Tanaris-Silithus". Ruling: the row stands — in the classic world Silithus is entered by the ramp in Un'Goro's north-west corner and has no land border with Tanaris; the Forever Atlas's crossings table lists the same pair ("ungoro","silithus","the north-west ramp"). The finding conflicts with the plan's data, which the evidence supports — if wrong: one row to change, and the in-game checklist gets an explicit line for this ramp so it is walked either way.
Task 2: minor (deferred to the final wave): Dijkstra's tie-break depends on pairs() order, which could differ between the desktop Lua and the client; break ties by key.
Task 2: minor (deferred): Route.Hint does not special-case a "better" plan that is itself rough; unlikely, harmless.
Task 1: complete (commits 11b29bb..a83551c, review clean)
Task 2: complete (commits a83551c..47f9dcf, review approved; 1 contested finding parked with ruling)
Task 3: implemented 47f9dcf..587b3cd, byte-identical to the verified copy; Lua 160/0, luacheck 0; lua-language-server reports 2 warnings at Planner.lua:46 (need-check-nil, undefined-field plan.level) — a plan defect (the prototype was linted but not run through lls); goes into the fix round. Review in progress.
Task 4: complete (commits 587b3cd..a188c47, review clean)
Task 3: review (sonnet) — spec OK; "needs fixes" solely for the known lls warnings on plan.level; row geometry verified to fit in both layouts (34 px band above the hint); UnitLevel returns a non-nil number and 0 means on foot; hint compares like with like. Minors: chat colours hard-coded (dim drifted 1/255), PlanRoute comment lacks `level`, colour assertions compare one channel.
Ruling: fix the lls warnings by building plan.level into the table and reading it nil-safely; chat colours come from Widgets.COLOR via Widgets.ChatColor; Dijkstra ties broken by key (deferred Task 2 minor) — all one round.
Ruling: the scoped re-review of this small fix round is folded into the final whole-branch review, which is told to verify each ruling — it is past 23:30 and the final review reads the same diff on a stronger model — if wrong: the final review's single fix wave absorbs anything missed.
Task 3: fix round 1/5 dispatched (brief task-3-fix-brief.md), FIX_BASE a188c47
Task 3: fix round 1/5 applied (commit 051e935): Lua 162/0 (controller re-ran), luacheck 0, lls clean. Re-review folded into the final review.
Task 3: complete (commits 47f9dcf..051e935, pending the final review's check of the fix rulings)

## Final review (opus): "ready to merge with fixes" — 0 Critical, 4 Important, 9 Minor. 72 real trips planned: routes right, no missing classic border, no rough steps; ~5 ms per Graph.Build. Agrees the Un'Goro-Silithus row stands. Fix-round rulings R1-R4: all ADDRESSED.
Ruling: crossing names must read the same both ways; ~30 rows renamed to landmarks or neutral pair names (list in the fix brief); all three Timbermaw rows share one name because it is one place and the detail line says where it leads, so name uniqueness is NOT required — if wrong: names are data.
Ruling: optional `cross` seconds on a row, paid on every edge arriving at that crossing (tunnels, lifts, Blackrock); values are estimates for the in-game pass.
Ruling: `unverified` is shown ("crossing not confirmed", amber) and pinned by a test; Orgrimmar's west gate is marked unverified too, since every Horde route north depends on it and it fails silently if wrong — costs an amber line on most Horde routes until the user walks it.
Ruling: a hazard or an unconfirmed note replaces the level clause on the detail line, so the important part is never what the client truncates; a real-data test caps the detail at 66 characters.
Ruling: overflow shows the final step in the last row; Graph's duplicate mount speed constant removed in favour of Travel.
Ruling: "arriving at the crossing counts as arriving in a zone destination" stands (spec decision 15); the cross time makes the total honest for tunnels.
Deferred: amber saturating for very low characters; per-zone detour multiplier for mountain zones; "near the shared edge" row check; Sardor Isle ferry. Noted for the user: an untracked AGENTS.md sits in the repo root (not ours; never staged).
Final review: fix wave dispatched (brief final-fix-brief.md), FIX_BASE 051e935

## Scoped re-review of the final fix wave (2026-09-20)

The fix-wave implementer was interrupted before writing `final-fix-report.md`, so nothing had checked commits
981e045, 8399fe6, ed9e8ba. Dispatched a scoped re-review (brief `final-fix-review-brief.md`, diff
`review-051e935..ed9e8ba.diff`). Verdict: **approved** — 0 Critical, 0 Important, 1 Minor. All nine F-items done.
Report: `final-fix-review.md`.

Minor (closed, not deferred): no row in `Data/Crossings.lua` sets both `warn` and `unverified`, so the real-data test
never reaches the branch in `Route.StepDetail` that orders the two notes. Closed in 2e250e7 with two hand-built steps,
verified RED by swapping the blocks.

Plan 3 is **executed**. Gates at close: Lua 170/0, Python 18 OK, luacheck 0 warnings, lua-language-server clean.

Also landed on this branch, outside the plan: b9cf04b the real addon icon, 8bb5e4c the minimap button dropping
Blizzard's tracking border, 1a0fb1d the spec's route-strip decision.

## Rulings I made during this plan

1. Branched from `planner-window`, not `main`: plan 2 is unmerged pending the user's in-game click test, and plan 3
   rewrites the same files. Plans 2 and 3 merge to main together.
2. The Un'Goro Crater to Silithus row stands. A reviewer claimed they do not border; Silithus is entered by the ramp in
   Un'Goro's north-west corner and has no land border with Tanaris. Added an explicit checklist line so it is walked.
3. Crossing names must read the same in both directions; the detail line gives the direction. Name uniqueness is NOT
   required: all three Timbermaw rows share one name because it is one place.
4. Optional `cross` seconds on a row, paid once per traversal. Values are estimates until timed in game.
5. `unverified` is shown as "crossing not confirmed" in amber and pinned by a test. Orgrimmar's west gate is marked
   unverified: every Horde route north depends on it and it fails silently if the coordinates are wrong.
6. A hazard or an unconfirmed note replaces the level clause on the detail line, so the important part is never what
   the client truncates. A real-data test caps the detail at 66 characters.
7. The scoped re-review of fix round 1 was folded into the final review. The final review's own fix wave got the
   separate re-review above.

## Deferred, not lost

Amber saturating for very low characters; a per-zone detour multiplier for mountain zones; tightening the crossing row
check to "near the shared edge"; Sardor Isle's ferry.

## Still unverified in game (blocks the merge to main)

Orgrimmar's west gate FIRST, then every other crossing's coordinates, the `cross` seconds, the mount levels and speeds,
the zone level ranges, and plan 2's destination-dropdown click. See `docs/manual-test-checklist.md`.

## Overnight, unattended (2026-09-20, 01:36 to 02:30)

The user went to bed with open-ended permission to keep working. Nine commits, b09ba4c..1903f13, none pushed.

- Crossing plausibility: a border can only lie where two zones' world rectangles overlap, so a point outside that overlap is provably misplaced. 50 of 56 rows are inside both; 6 are not. `tools/survey_crossings.lua` ranks them, a test pins the count, and the checklist now says which six to walk first. Verified RED by swapping x and y on the Mor'shan Rampart (2520 yards).
- `/gps probe zones`: `API.ZoneLevels` wraps `C_Map.GetMapLevels`, which is what draws the range on Blizzard's own world map. Replaces reading sixty zone tooltips by hand. Verified in source, NOT in game; the probe counts answers and says "dead on this build" rather than reading silence as agreement, because `isUndiscovered` set exactly that trap. The DB2 route was tried first and is a dead end on this build.
- 39 TGA exports untracked (50 MB of build output at ten times the shipped size); `export_tga.py` and the PNGs stay.
- Checklist gained a suggested order for the next session.

Ruling: no `tools/make_art.py` yet. Plan 4 is unwritten, the shipped size per part depends on layout that does not exist, and `/gps selftest` already answers the only urgent question (whether this client loads a Pillow-written TGA) through the existing `Media/icon` line — if wrong: the tool is an afternoon's work whenever plan 4 starts.

### Self-review, since nobody was watching

Commits b09ba4c..987ce18 were put through an adversarial review (`overnight-review.md`): **approved with minors, 0 Critical, 2 Important, 4 Minor.** The reviewer independently re-derived the crossing geometry from raw data, mutated a coordinate to confirm the test catches it, and regenerated all 39 TGAs.

Both Important findings were real and are fixed in 1903f13:
1. The probe tests never exercised the fourth case (we list a zone, the client is silent), and the comment claimed otherwise. **The first fix for this did not work**: with one unlisted and one lost zone, swapping the two counters prints the same sentence, and the test passed a deliberate swap. Made the counts differ; the swap now fails.
2. `Core.probeZones` wrote a diagnostic dump into `GoblinPSDB` while `Prefs.lua` promised that table held preferences only. Header updated to name the key, its owner, and why it is not a separate saved variable.

Over-reach, accepted: the checklist's start-here list asserted what blocks the merge. That is the owner's call; reworded as a suggested order.

Still the owner's to decide: whether to merge plans 2 and 3 to main. The branch is a clean fast-forward, 41 commits ahead, no divergence.

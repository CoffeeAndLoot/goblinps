# SDD ledger — plan: docs/superpowers/plans/2026-09-21-goblinps-planner-as-designed.md

Spec: docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md (Plan 8 section). Branch: planner-as-designed, from main 08655fe.

## Pre-flight scan

| pair / task | produces vs consumes | finding |
|---|---|---|
| T1 -> T3 | T1 adds "Strip" to test_ui load list; T3 rewrites test_ui planner block | disjoint hunks, ok |
| T1 -> T4 | Strip.Layout returns stops/legs/labels/spacing/warning; T4 drawStrip reads spacing, warning, stops[].x/badge/label/tooltip, legs[].from/to/style/mid | names agree |
| T2 -> T3 | T2 camel keys toBox, resultsList, screen, stripTrack, totalLine, hintLine, notesLine, knownLine, goButton, interior; T3 ApplyLayout reads exactly these | agree |
| T2 -> T4 | T2 ships line-* at 128x16 unpadded (cw/ch 128/16, l=0 r=1); T4 tile = thick*cw/ch and whole-texture check | agree |
| T3 -> T4 | T3 Refresh/build/ui table; T4 inserts into Refresh (hint block replaced), build (strip after backdrop), ui.strip | T4 text names the exact hint block T3 writes; ok |
| T2/T3 Art.lua | T2 must NOT regenerate; T3 regenerates | stated in both tasks |
| T5 | reads all; docs only + TOC version | ok |
| T1 self | 13 tests vs Strip.lua code; fake_world data for hazard/no-warning cases traced by hand | consistent |
| T2 self | tests vs make_art/check_art edits; PARTS count 29-1+15=43 | consistent |
| T3 self | deleted/changed tests vs removed widgets; new idle test stubs Dash.Destination (earlier Start Route left a trip) | consistent |
| T4 self | tests assume Delta route step 3 is a ride (to West Dock); traced from the old row test (rows 4-5 zeppelin, ride) | plausible, implementer to confirm |
| T5 self | composite is scratch-only, not committed | ok |

No conflicts needing a ruling before Task 1.
Task 1: dispatched (base 08655fe, haiku)
Ruling: Task 1 test 'shows at each stop how you got there' uses kind 'portal', and Route.StepText errors on an unknown kind — spec says an unknown kind wears node-ring and is 'never an error', so Strip guards locally: a step kind it does not know gets a tooltip of the stop's short name and its time, without calling Route.StepText/StepDetail; Route is not changed (out of scope) — costs if wrong: an unknown kind's tooltip is terser than a known one's.
Task 1: minor (deferred): Strip.lua tooltipFor repeats FormatTime in both branches and restates the known-kind test that badgeFor encodes; an isKnownKind helper would tighten it
Task 1: complete (commits 08655fe..d1bfd17, review clean)
Task 2: dispatched (base d1bfd17, sonnet)
Task 2: ⚠️ resolved: Lua 324 vs brief's 323 is the Task 1 ruling's extra test, expected
Task 2: minor (deferred): check_art.planner_geometry_holds still loops PLANNER_FRAMES.items() for one entry (harmless vestige)
Task 2: complete (commits d1bfd17..39e6feb, review clean)
Task 3: dispatched (base 39e6feb, opus)
Task 3: deviations accepted — backdrop tests now trim height (screen ~3.3:1 is wider than 2.5:1 scenery); leftover grep hits only the mandated negative asserts; `if plan and routed` narrowing
Task 3: ⚠️ resolved: checklist update is Task 5
Task 3: minor (deferred): test_ui.lua:802 FreshPlanner.ApplyLayout("wide") leftover argument
Task 3: minor (deferred): notes/hint now single truncating lines (~490 px); add a checklist line to watch for cut-off notes
Task 3: minor (deferred): stale comments naming removed controls — Widgets.lua:111-112 (Here/GO widths), 185, 270; Core.lua:125 "only GO explains itself"
Task 3: minor (deferred): fake_frames.lua:44 comment cites removed results.owner
Task 3: minor (deferred): coverCrop comment says "losing its sides" but new geometry trims top/bottom
Task 3: minor (deferred): idle test asserts notes:IsShown() with empty text (weak)
Task 3: complete (commits 39e6feb..f6e2cdc, review clean)
Task 4: dispatched (base f6e2cdc, opus)
Task 4: deviation accepted — `if plan and routed and g` narrowing
Task 4: minor (deferred): test reads line-dashed part for the solid leg's texcoord check (passes only because both are 128x16)
Task 4: minor (deferred): line/dot tests pin x only, not anchor, relative frame or y
Task 4: minor (deferred): stripMetrics indexes ArtGeometry.planner.strip unguarded
Task 4: complete (commits f6e2cdc..0e61a64, review clean)
Task 5: dispatched (base 0e61a64, sonnet)
Task 5: controller looked at strip-6.png and strip-11-zoom.png: badges on the line, solid then dashed, eleven stops fit, ends clear of brass
Task 5: complete (commits 0e61a64..1d2d1c0, review clean)
Final review: dispatched (base 08655fe, opus)
Final review: 2 Important (leg tests pin x only; stripMetrics unguarded) + sweep; one fix wave dispatched
Ruling: skip insetting badge hit areas (final-review minor 3) — SetHitRectInsets is flagged IsProtectedFunction on this build and the project keeps clear of anything combat-lockdown-adjacent; instead a checklist line asks for a 13-stop hover check — costs if wrong: overlapping hover on 11+ stop routes.
Ruling: keep the plan's single warning line priority (final-review minor 2) — it is the user-approved spec's one amber line; surfacing that flights were left out on a hazardous route is raised to the user as a follow-up — costs if wrong: a fresh character on a hazardous route is not told flights were omitted.
Ruling: keep the square no-art fallback (final-review minor 4) — already ruled in the plan; costs a square marker when both the icon and node-ring fail.
Final review: fix wave 775df25, re-review all addressed, no new breakage

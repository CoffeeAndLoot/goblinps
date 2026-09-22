# Final review fix wave (plan 10) -- worktree D:\goblinps-wt\towns

## Must fix
I1. GoblinPS/Planner.lua ~337: the wheel delta is used as a size (`r.offset - delta`). Use its sign only, as every Blizzard scroll handler on this build does (ScrollFrameTemplate_OnMouseWheel, HybridScrollFrame_OnMouseWheel, ScrollControllerMixin): step = -1 for delta > 0, +1 for delta < 0; return early on 0. Test: Fake.Wheel(ui.results, -3) moves exactly one row; Fake.Wheel(ui.results, 0.5) moves one row toward the start and leaves an integer offset.

## Sweep
M1. Search.lua ~187-189: correct Exact's tie-order comment to match before() -- usable first, then kind (stop, town, zone), then lowest nodeID/townID.
M3. Search.Find rank 3 (a zone-name match): inside rank 3, put flight stops before towns, then alphabetical, so `/gps to westfall` and Enter on a zone name land on the zone's flight stop (Sentinel Hill), not its alphabetically first village (Moonbrook). Add a test; revert test_crossings.lua ~368 to route to Westfall by zone name if that is what it did before plan 10 (read its history: `git log -p -- test/test_crossings.lua`), otherwise leave it and add the new test only.
M4. test/run.lua ~11-12: load Towns where the TOC does (before Links), so the "loaded in TOC order" comment is true.
M5. Planner.lua ~368-369 (browse): add a one-line comment that the second showResults is needed in the client when the box already has focus (SetFocus then fires no OnEditFocusGained).
M7. tools/build_graph.py ~269: `map_id, _ = _town_zone(...)` (drop the unused `how`), or use it in the skip message; keep Python tests green.
M8. docs/manual-test-checklist.md ~544-549: the wheel-over-a-row check appears twice; keep one.
Also: Search.lua ~101 (Inns row drops a town of its name): add one line to the comment that the match is by name in any zone, and every real drop today is in the same zone.

Gates: all five green (Lua at 469 now; expect +2 or +3). Commit "Final review fixes: the wheel steps one row, zone names land on a stop, and a sweep" ending "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>".

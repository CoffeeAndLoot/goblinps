# Final review fix wave (plan 8) — every item below, one commit per group is fine

## Must fix
I1. test/test_ui.lua ~925-942 ("joins the stops with a solid first leg and dashed after..."): pin the line and dot the way the badge test (~911-923) pins badges. For each leg:
    - line.points[1][1] == "LEFT", line.points[1][2] == ui.frame, line.points[1][5] ≈ -t.cy.
    - dot.points[1][1] == "CENTER", dot.points[1][2] == ui.frame, dot.points[1][5] ≈ -t.cy.
    - The dot's width and height ≈ t.thick.
    Also read the texcoord check's part from the leg's own style: line-solid for leg 1, line-dashed after.
I2. GoblinPS/Planner.lua ~39: stripMetrics indexes ns.Data.ArtGeometry.planner.strip without a guard. If Art.lua lacks `strip`, every /gps open throws. Draw the strip only when both the wide geometry and planner.strip exist; otherwise hide it and leave the rest of the window working. Add a test that nils ns.Data.ArtGeometry.planner.strip, calls Planner.Refresh() with a routed plan, asserts no error and that ui.strip is hidden, then restores the table.

## Sweep (stale words, no behaviour change)
S1. GoblinPS/Widgets.lua:111-112 — the comment gives 65 px for "Here" and 135 for "GO". Reword it for today: one "button" part drawn at whatever width the geometry gives Start Route.
    Lines ~185 and ~270 — keep the dated history ("Seen in the client 2026-09-21 ...") but fix any sentence that describes today's controls as Tall/Here/GO.
S2. GoblinPS/Core.lua:125 "only GO explains itself" -> "only Start Route explains itself".
S3. GoblinPS/Planner.lua coverCrop comment (~330) "Losing its sides is intended" -> say the crop loses whichever overflows (with today's ~3.3:1 screen, the top and bottom), and that this is intended.
S4. test/fake_frames.lua:44 cites `results.owner` as an example of instance data; pick a field that still exists (e.g. `row.item`, `strip.badges`).
S5. test/test_ui.lua:~802 `FreshPlanner.ApplyLayout("wide")` -> `FreshPlanner.ApplyLayout()`.
S6. docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md ~327-330: the paragraph saying the desk art tooling is red until plan 8 adapts it. Mark it past tense and say plan 8 adapted it (green).
S7. docs/manual-test-checklist.md plan 3 section (~261-265), which asks for step rows and "... and N more steps": add the same one-line "Superseded by plan 8: ..." note used elsewhere. Do not delete the history.
S8. CLAUDE.md:39 and :94: any present-tense "GO" naming today's button -> "Start Route". Leave dated history alone.
S9. docs/manual-test-checklist.md, plan 8 section, add two lines:
    "- [ ] The names under the two end badges read in full (they get about 65 px); note any that truncate, e.g. "You are here" or a long destination"
    "- [ ] A 13-stop route: rings may touch and each badge's hover area overlaps its neighbour's; note whether the right tooltip comes up"

All five gates green (Lua starts at 329 and should gain 1). Commit message e.g. "Final review fixes: pin the strip's legs, guard its geometry, sweep stale words", ending with "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>". Never stage AGENTS.md.

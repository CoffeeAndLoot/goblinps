# Final review fix wave (plan 11) -- worktree D:\goblinps-wt\enemy

## Ruling (controller, 2026-09-22) replacing the Task 4 exemption rule
A leg p->q and a hostile circle h:
- The START end p is exempt from h when the leg heads away: Distance(p,h) <= SegmentDistance(p,q,h) + 1 (the leg never comes closer to the centre than where it starts). This applies to ANY stop p inside the circle -- START, HEARTH, a stopover, a crossing end, a flight master -- so leaving a gate or a camp outward is not charged, but a replan from the edge of a town that cuts through its centre is.
- The FAR end q is exempt only when q is DEST (going there on purpose) or a stopover deliberately placed inside the circle (as today).
- Otherwise the plain test applies (SegmentDistance(p,q,h) <= radius -> charged).
Why: (1) standing 145 yd from Silverwind the replan walked 0 yd from its centre uncharged (START exemption covered the whole leg); (2) a crossing inside a circle was charged twice (in and out), making detours of up to 20 min (Brill -> The Sepulcher went 412 s -> 1136 s through level-51 Western Plaguelands).
Expected (reviewer's scratch probe): from 145 yd and 100 yd inside Silverwind the route walks out and round (~710 s); Brill -> The Sepulcher (Alliance, level 20) back to ~412 s with one charge, "passes Undercity (Horde)"; the Orgrimmar real-data test still passes. Update the tests that pin the old rule (test_graph ~363-375 and the three the reviewer names), keep their intent, and add:
  - START inside a circle, leg heading away: not charged; leg cutting through the centre: charged
  - a crossing inside a circle: charged once on the way in, not on the way out
  - Brill -> The Sepulcher real-data: pin what it does now (seconds and the danger name)
Update the spec section 2 exemption text to this rule ("Revised 2026-09-22 after the final review").

## Must fix
I2. Route.lua ~275 (StepDetail) says "into <other zone>" for a one-ended crossing the route only touches and turns back from (176 steps on real data; the Talondeep route's only amber line reads "the Ashenvale-Felwood road: into Felwood · level 48-55" for a level 15 who never enters Felwood). Mark such a step (in Route.Find or tidy: a ride to a one-ended crossing whose NEXT ground step stays in the same zone as this step) and have StepDetail say "in <zone>" with that zone's levels instead. Pin it in the Talondeep real-data test, and update the plan 11 checklist item to the amber line the player really sees.
M1. tools/build_graph.py ~247: open the sheet with encoding "utf-8-sig"; add a Python test with a BOM.
M2. tools/build_graph.py ~258: skip rows whose zone and town are both blank; add a test.
M3. spec (worktree) lines ~43 and ~72: they still say the Talondeep route "goes through with the warning" / expect "passes Silverwind Refuge"; make them say what it does (goes round), matching the manual checklist.
M4. Core.lua ~402: "0 always takes the fastest route" -> "0 uses it whenever it is no slower".
M5. docs/later.md: add "- **The dash says nothing when a replan brings in danger.** A replan that adds a 'passes X' leg or a hostile destination shows no warning on the dash (Dash.lua ~621); the player follows the dash, so a short banner would help."
M6. docs/manual-test-checklist.md, plan 11 radius item: add that the Undercity's 400-yard capital circle reaches the Tirisfal-Silverpine road -- check whether that is too wide.

All five gates green (Lua at 515 now). Commit "Final review fixes: head-away exemption, turning points say in, and a sweep" ending "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>". Never discard files; never work around a blocked command.

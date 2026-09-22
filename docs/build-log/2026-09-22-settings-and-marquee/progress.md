# SDD ledger — plan: docs/superpowers/plans/2026-09-22-goblinps-settings-and-marquee.md

Spec: docs/superpowers/specs/2026-09-21-goblinps-settings-and-marquee-design.md. Branch settings-and-marquee from main b45d078. Owner asleep; overnight run, no merge, no push.

## Pre-flight scan
| pair / task | produces vs consumes | finding |
|---|---|---|
| T1 -> T2 | Marquee.New/Advance/HOLD/STEP/GAP | agree |
| T2 -> T5 | fake GetUnboundedStringWidth, Fake.CHAR_WIDTH | agree |
| T3 -> T4 | Prefs.HEARTH_MINUTES/ARRIVE/Step/Reset/ArriveRadii, Core.Arrive/SetArrive/ResetSettings | names agree |
| T3 TOC order | Prefs reads Trip.ARRIVE at load: Trip.lua precedes Prefs.lua in TOC and run.lua | agree (TOC: Trip then Known then Prefs) |
| T4 -> T6 | Settings.lua, Marquee.lua in TOC -> restart note | T6 covers |
| T5 self | Search.Candidates public; fit/list width vs results rows | consistent |
| T2 self | slot from geometry x explicit frame width; test forbids reading fs width | consistent |
| every task | spec rulings 1-12 plus plan rulings 1-10 | carried to the final message |

Ruling: plan rulings 1-10 accepted as written — they fill spec gaps without contradicting it — costs if wrong: small UI behaviours the owner can flip.
Task 1: dispatched (base 9f8bba8, haiku)
Task 1: minor (deferred): commit attribution says Haiku rather than the brief's Opus line (cosmetic)
Task 1: complete (commits 9f8bba8..e04dcf2, review clean)
Task 2: dispatched (base e04dcf2, sonnet)
Task 2: minor (deferred): a distance/ETA too long for its slot would restart every 0.5 s tick and never scroll (HOLD 1.5 s); only a comment records the assumption
Task 2: minor (deferred): no test covers the no-geometry slot fallback
Task 2: note for Task 6 checklist: a scrolling line may show the client's "..." at its right edge while it scrolls; look at it in game
Task 2: complete (commits e04dcf2..d08e317, review clean)
Task 3: dispatched (base d08e317, sonnet)
Task 3: complete (commits d08e317..bf18501, review clean)
Task 4: dispatched (base bf18501, opus)
Task 4: ⚠️ resolved: docs/later.md "dress the settings panel" entry is Task 6
Task 4: minor (deferred): one Escape closes panel and planner together (UISpecialFrames closes all at once); a test label overstates "panel's alone"
Task 4: minor (deferred): /gps hearth takes off-grid minutes (2.5, 45) the panel then shows rounded / jumps to 30
Task 4: minor (deferred): a FreshPlanner's OnHide calls the shared Settings.Close (test-only)
Task 4: minor (deferred): API.lua comment example version 2026.09.22.1 vs TOC 2026.09.21.6 (Task 6 bumps it)
Task 4: complete (commits bf18501..da278fb, review clean)
Task 5: dispatched (base da278fb, sonnet)
Task 5: fix round 1/5 (2 addressed, 0 open — cap test could not fail; no fallback test; commits 371abe4..50bb3f9; mutation check confirmed)
Task 5: complete (commits da278fb..50bb3f9, review clean after round 1)
Task 6: dispatched (base 50bb3f9, sonnet)
Task 6: done (948fff5); task review and final review dispatched together
Final review: 1 Important (results list draws over settings panel: same strata, lower panel level) + minors; one fix wave dispatched
Ruling: skip final-review minor 2 (Marquee builds two strings per frame while scrolling) — garbage, not a measured cost; YAGNI until seen in game — costs if wrong: a little GC churn while a line scrolls.
Final review: fix wave 452b59a, re-review all addressed, no new Critical/Important
Final: parked — Planner.showResults calls the test-only Settings.Debug() to learn if the panel is shown (nil-safe) — Ruling: works today; a one-line Settings.IsShown() is the tidy fix, left for the owner since the process allows one fix wave — costs if wrong: a future Debug() change silently breaks the guard.
Final: parked — Planner.OpenSettings (/gps settings) does not dismiss an open results list first (pre-existing path; panel now draws over it) — Ruling: narrow trigger, non-blocking — costs if wrong: the list's edge outside the panel stays clickable after /gps settings.

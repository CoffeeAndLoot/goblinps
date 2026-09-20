# Final-review fix wave — GoblinPS planner window

Repo `D:\goblinps`, branch `planner-window` (checked out). Commands and commit rules: `implementer-common.md` in this
folder (ignore its "transcribe byte-for-byte" paragraph: this changes behaviour, test-first where a desktop test can see
it). Smallest change that satisfies each ruling. Two commits:

    git commit -m "Planner: bounded messages, GO re-plans, guarded saved position" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
    git commit -m "Docs: checklist gaps and stale spec lines" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"

Current state: Lua `113 passed, 0 failed`, Python 18 OK, luacheck 0 warnings, lua-language-server clean. Keep all green.
Read each file before changing it.

## Commit 1: code

**C1. Messages must stay inside the window (Important).** `GoblinPS/Planner.lua`: `ui.total` has one anchor and no wrap,
and `Planner.Refresh` puts whole sentences in it when there are no steps, so they draw over GO and past the frame.
Rulings:
- `ui.notes` (already width-constrained on the green screen) shows ALL of the plan's notes joined with two spaces,
  whether or not there are steps. With no plan it is empty.
- `ui.total` shows only the total (`~N min  fare`) when there are steps, else the empty string. Also bound it: add a
  second anchor so it cannot run under GO (`total:SetPoint("RIGHT", go, "LEFT", -8, 0)` after `go` exists; create `go`
  before `total` if you need to).
- Let `ui.notes` wrap onto a second line: `SetWordWrap(true)` on that one FontString (keep `W.Text`'s default false).
- Update the smoke tests that asserted a sentence in `ui.total` (the "cannot tell where you are" test) to assert it in
  `ui.notes` and an empty `ui.total`. Add a smoke test for the zero-step zone case: standing in Westland with
  Westland as the destination, rows are empty, `ui.notes` contains `You're already at Westland.`, `ui.total` is empty
  and GO is disabled.

**C2. GO plans from where you are now (Important).** "Use your hearthstone, then press GO again" never changes because
GO reads a stale plan. Ruling: the GO handler becomes `dismiss(); replan(); ns.Core.Go(state.plan)`. Smoke test: plan
a route, move the fake player (change the scripted `where`) so the first step differs, press GO, and assert the pin
and the "Pin set" line are for the NEW first step and the rows were refreshed.

**C3. Guard the saved position (Minor, cheap, the failure is a window that never opens again).** `GoblinPS/Prefs.lua`
`Prefs.Position`: return nil unless `point` is a string and `x`, `y` are numbers (and `relativePoint`, when present,
is a string; otherwise fall back to `point`). Tests in `test/test_prefs.lua` for a hostile entry (`point = 5`, `x = "a"`,
a non-table entry), plus hostile `recents` / `positions` / `minimap` / `minimap.hide` values through `Prefs.Init`
(it already guards them; pin that).

**C4. Self-test info line.** `GoblinPS/SelfTest.lua`: `report(ns.Core.KnownCount() >= 0, ...)` cannot fail. Print it with
`say("flight paths learned: " .. n)` instead so it is not counted as a check.

**C5. Minimap button answers the left button only.** `GoblinPS/MinimapButton.lua`: `RegisterForClicks("LeftButtonUp")`.
(Direct writes to `MinimapPrefs().angle` / `.hide` stay: ruled acceptable.) If the strict fake needs nothing new, fine.

**C6. Give the steps more room until the map exists.** `GoblinPS/Planner.lua`: make the wide layout's screen share a
named constant `SCREEN_SHARE = 0.42` (was the literal `0.56`) with a comment that plan 3 (the schematic map) will
revisit it. Update any smoke assertion that depended on the old width (none should).

**C7. Honest comments in the smoke test.** At the top of `test/test_ui.lua` add two comment lines: the tests share one
planner and run in order (a later test may rely on an earlier one); `Self-test passed.` cannot be reached on the
desktop because the fake defines no font objects, so the happy path is checked in game.

Run the Lua tests, luacheck and `lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json`. Commit 1.

## Commit 2: documents

**D1. `docs/manual-test-checklist.md`.**
- In `## Routing core (plan 1)`, the first item says `/gps` prints the two usage lines. Append to that item's note:
  `Since plan 2, /gps opens the planner; /gps help (any unknown word) prints five usage lines.`
- In `## Probes to run before any code`, the item about `TAXI_NODE_STATUS_CHANGED`: append
  `(Moot: isUndiscovered is dead on this build. GoblinPS registers TAXIMAP_OPENED only; do not add this event.)`
- In `## Planner window (plan 2)`, add these items (after the GO items unless noted):
  - `- [ ] With no destination, and with a destination that has no route, GO is grey and does nothing`
  - `- [ ] Pick the zone you are standing in: no steps, GO grey, the screen says "You're already at <zone>."`
  - `- [ ] GO, ride part of the way, GO again: the pin moves to the step that is first from where you now stand`
  - `- [ ] Step 1 is the hearthstone: GO says to use it; use it, press GO again: the pin is set for the next step`
  - `- [ ] Open the planner inside an instance with a destination set: the screen says it cannot tell where you are, the text stays inside the window, GO is grey`
  - `- [ ] Every message on the green screen wraps or truncates inside the screen; nothing draws over GO or past the frame, in both layouts`
  - `- [ ] /reload with the planner open: it stays closed afterwards (by design); /gps reopens it where it was`
  - `- [ ] A second character on the same account: its "Flight paths known" is its own; layout, window position, recents and the minimap button angle are shared`
  - `- [ ] Right-clicking the minimap button does nothing; left-click opens the planner`

**D2. The spec, `docs/superpowers/specs/2026-09-19-goblinps-design.md`.**
- Where it says the planner re-plans on `TAXI_NODE_STATUS_CHANGED`: say instead that it re-plans when the start or
  destination changes, when GO is pressed, and when a flight master visit teaches it a new path (`TAXIMAP_OPENED`).
- Failure handling, the no-route bullet: replace the promised text with what the addon says:
  `No route: "No route found to <place>." and, when knowing more flight paths would help, the "Discover ..." line.`
- Anywhere the spec still lists `TAXI_NODE_STATUS_CHANGED` as something to register or verify, mark it not used.

**D3. `CLAUDE.md`.** The heading `## Intended layout (from the sibling projects; nothing exists yet)` becomes
`## Layout`. In "Rules that are easy to break" add one bullet:
`- Text in the window must be bounded: give every FontString two horizontal anchors (or a width) and decide wrap or truncate. A one-anchor FontString fed a sentence draws over its neighbours and past the frame.`

Run the Lua tests and luacheck once more. Commit 2.

## Report

Write `D:\goblinps\.superpowers\sdd\2026-09-19-goblinps-planner-window\final-fix-report.md`: per item what changed
(file:line), RED then GREEN evidence for each new test, final counts, lint and language-server results, and anything
you could not do or chose differently, with why. If a ruling proves impossible or breaks something it did not
anticipate, STOP and report BLOCKED with specifics. You cannot run the game client; claim nothing about in-game
behaviour.

Then reply with ONLY: Status, the commits (short SHA + subject), a one-line test summary, concerns, the report path.

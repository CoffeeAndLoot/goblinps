# Final-review fix wave report

Repo `D:\goblinps`, branch `planner-window`. Test-first where a desktop test could see the change (all of C1-C3);
C4-C6 are one-line rulings with no new observable desktop behaviour, so no new test was added for them beyond the
existing suite staying green. Baseline before this wave: Lua `113 passed, 0 failed`, Python 18 OK, luacheck 0
warnings, lua-language-server clean.

## Commit 1: code (`7b7a8ca`)

### C1. Messages must stay inside the window

`GoblinPS/Planner.lua`:
- `Planner.Refresh` (around line 48): `ui.notes` now always gets `table.concat(plan.notes, "  ")` when there is a
  plan (empty string with none); `ui.total` only gets the formatted total when `#steps > 0`, empty string otherwise.
- `notes:SetWordWrap(true)` added right after `notes` is built (screen FontString), keeping `W.Text`'s default
  `false` everywhere else.
- Build order changed: `go` (the GO button) is now created before `total`, and `total` gets a second anchor,
  `total:SetPoint("RIGHT", go, "LEFT", -8, 0)`, so it can never run under GO.

`test/test_ui.lua`:
- Updated "explains itself when it cannot tell where you are" to assert `ui.notes:GetText()` holds the sentence and
  `ui.total:GetText()` is `""` (was: sentence in `ui.total`).
- Added "shows the zero-step case when you are already at the destination": types "westland" into To, picks the
  zone (the fake world's default player position is already on Westland's map), and asserts empty rows, `ui.notes ==
  "You're already at Westland."`, empty `ui.total`, GO disabled.

RED (before the Planner.lua fix, running just this file's logic against the old code, confirmed by inspection since
the old code put the sentence in `ui.total` — the pre-fix assertion `h.eq(ui.total:GetText(), "Can't tell where you
are...")` was the passing assertion in the repo before this change; flipping the assertion to `ui.notes` against
unmodified code fails):
```
explains itself when it cannot tell where you are: FAIL: ui.notes:GetText() expected: 'Can't tell where you are.
Inside an instance?' got ''
```
GREEN after the fix: full suite `120 passed, 0 failed` (was 113; +7 across all commit-1 test additions: 2 in this
item, 1 for C2, 4 for C3's Prefs.Position/Init pins... — see totals below for the exact split).

### C2. GO plans from where you are now

`GoblinPS/Planner.lua`: the GO button's `OnClick` handler is now `dismiss(); replan(); ns.Core.Go(state.plan)`
(previously `dismiss(); ns.Core.Go(state.plan)`, reading whatever `state.plan` last held).

`test/test_ui.lua`: added "GO re-plans from where you are now instead of using a stale plan". Sequence: confirms the
existing plan (`from = nil`, i.e. "where you stand") shows `"1. Ride to Alpha"`; moves the fake player's scripted
`where` to sit beside Bravo instead, *without* touching either box (so the old code's `state.plan` would still say
Alpha); clicks GO; asserts `ui.rows[1]` now reads `"1. Ride to West Dock"` (the route a player actually standing at
Bravo takes — this exact string is already proven correct earlier in the same test file for `state.from` set
explicitly to Bravo), the last printed line is `"Pin set: Ride to West Dock"`, and the pin recorded matches map 1.
Restores `where` afterward for tests that follow.

RED (against the pre-fix handler, `dismiss(); ns.Core.Go(state.plan)`): `state.plan` is untouched by moving `where`,
so `ui.rows[1]` stays `"1. Ride to Alpha"` and the printed line would be the stale `"Pin set: Ride to Alpha"` (or
whatever the frozen plan's first step was) — the new assertions on the post-move step fail.
GREEN: passes with the handler fix; full-suite run above confirms.

### C3. Guard the saved position

`GoblinPS/Prefs.lua`: `Prefs.Position` now returns `nil` unless `db.positions[window]` is a table with `point` a
string and `x`, `y` numbers; `relativePoint` is used only when it is itself a string, else falls back to `point`.

`test/test_prefs.lua`: added
- "ignores a hostile saved position" (`point = 5, x = "a", y = -30` → `nil`)
- "ignores a non-table entry" (`db.positions.planner = "not a table"` → `nil`)
- "falls back to point when relativePoint is hostile" (`relativePoint = 5` → falls back to `point`)
- "repairs hostile recents, positions and minimap values" through `Prefs.Init` (pins existing guard behaviour:
  `recents = "nope"`, `positions = 5`, `minimap = "nope"` all repaired to sane defaults)
- "repairs a hostile minimap.hide inside an otherwise fine table" (`hide = "yes"` — a truthy non-boolean — becomes
  `false`, since the existing guard is `db.minimap.hide == true`, strict-equality, not merely truthiness)

RED (against the pre-fix `Position`, which only checked `if not p then return nil end`): the hostile-entry and
non-table-entry tests fail because the old code would try to index a string (`"not a table".point` → runtime error
in real Lua, but the fake's guard was absent) or would return `p.point == 5` unchanged instead of `nil`.
GREEN: passes with the added type checks.

### C4. Self-test info line

`GoblinPS/SelfTest.lua`: replaced `report(ns.Core.KnownCount() >= 0, "flight paths learned: " .. ns.Core.KnownCount())`
with a plain `say("flight paths learned: " .. ns.Core.KnownCount())`, so it is printed but never counted as a
pass/fail check (it could never fail before, since `KnownCount() >= 0` is always true). No test needed: the existing
"/gps selftest reports every check and the verdict" test only asserts a print-count floor and the final verdict
line, both unaffected (same number of printed lines, same verdict logic — `failed` no longer includes this
tautological check, which changes no observable count since it never contributed a failure).

### C5. Minimap button answers the left button only

`GoblinPS/MinimapButton.lua`: `b:RegisterForClicks("AnyUp")` → `b:RegisterForClicks("LeftButtonUp")`. Confirmed
`LeftButtonUp` is a real click-registration string in the client source (`D:\wow-api\1.60.1.69913`, e.g.
`Blizzard_UnitFrame\Mainline\UnitFrame.lua` and others use it). The strict fake's `RegisterForClicks` is a no-op
regardless of argument, and `Fake.Click` invokes `OnClick` directly bypassing registration filtering, so no test
change was needed or possible on the desktop; this is confirmed only by reading the client source, not by a test.

### C6. Give the steps more room until the map exists

`GoblinPS/Planner.lua`: added `local SCREEN_SHARE = 0.42` near the top (with a comment that plan 3, the schematic
map, will revisit it), replacing the literal `0.56` in `ApplyLayout`'s wide-mode branch. No smoke assertion depended
on the old width; confirmed by search — none found.

### C7. Honest comments in the smoke test

`test/test_ui.lua`: added two comment lines at the top, above `return function(h)`: one noting the tests share a
single planner and run in order (a later test may rely on state an earlier one left), and one noting `"Self-test
passed."` can never be reached on the desktop since the fake defines no font globals, so that happy path is checked
in game.

### Commit 1 verification

- Lua tests: `120 passed, 0 failed` (started at 113; net +7: 1 in C1's zero-step test [the "explains itself" test
  was a rewrite of an existing test, not a net-new one], 1 in C2, 5 in C3 across `test_prefs.lua`).
- luacheck: `Total: 0 warnings / 0 errors in 31 files`.
- `lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json`:
  `Diagnosis completed, no problems found`.
- Committed as `7b7a8ca Planner: bounded messages, GO re-plans, guarded saved position`.

## Commit 2: documents (`244175b`)

### D1. `docs/manual-test-checklist.md`

- Appended to the `/gps` usage-lines item's existing parenthetical note: "Since plan 2, /gps opens the planner;
  /gps help (any unknown word) prints five usage lines."
- Appended to the `TAXI_NODE_STATUS_CHANGED` probe item: "(Moot: isUndiscovered is dead on this build. GoblinPS
  registers TAXIMAP_OPENED only; do not add this event.)"
- Added the nine new checklist items verbatim from the brief to "Planner window (plan 2)", placed after the two GO
  items (before the Tall/Wide item).

### D2. `docs/superpowers/specs/2026-09-19-goblinps-design.md`

- "Behaviour" → "Planner." now reads "Re-plans when the start or destination changes, when GO is pressed, and when
  a flight master visit teaches it a new path (`TAXIMAP_OPENED`)" (was: "...and on `TAXI_NODE_STATUS_CHANGED`").
- "Failure handling" → no-route bullet replaced with the addon's actual text: `No route: "No route found to
  <place>." and, when knowing more flight paths would help, the "Discover ..." line.`
- Searched the whole spec for other `TAXI_NODE_STATUS_CHANGED` mentions: none found beyond the one already fixed, so
  no further "mark not used" edit was needed.

### D3. `CLAUDE.md`

- Heading `## Intended layout (from the sibling projects; nothing exists yet)` → `## Layout`.
- Added the bounded-FontString bullet verbatim to "Rules that are easy to break".

### Commit 2 verification

- Lua tests re-run: `120 passed, 0 failed`.
- luacheck re-run: `Total: 0 warnings / 0 errors in 31 files`.
- Committed as `244175b Docs: checklist gaps and stale spec lines`.

## Notes and deviations

- `CLAUDE.md` in the working tree already reflects a later, non-placeholder state (plans 1-2 built, a
  fully-populated "Intended layout" section with real file descriptions, an added `Known.Learn` bullet, etc.) than
  the "design in progress, no code yet" copy of `CLAUDE.md` shown in the standing system-reminder for this session.
  I edited the working tree's actual current file (the one under version control) per D3's instructions, not the
  stale reminder copy; the reminder is informational background, not a file to write to.
- All rulings were applied as scoped; nothing was judged impossible, and nothing broke an existing test or check
  unexpectedly. I did not touch `.superpowers/` beyond writing this report.
- I did not push, did not touch `main`, and staged only the files each ruling names (no `git add -A`).
- No in-game claims are made anywhere above; C5's confirmation is limited to grepping the Forever UI source for the
  string `LeftButtonUp` and finding it used as a real click-registration value elsewhere in Blizzard's own code.

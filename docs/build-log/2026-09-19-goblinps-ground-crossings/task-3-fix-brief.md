# Fix round 1 — GoblinPS ground crossings (Task 3, plus one deferred minor from Task 2)

Repo `D:\goblinps`, branch `ground-crossings` (checked out). Commands and commit rules: `implementer-common.md` in this
folder (ignore its "transcribe byte-for-byte" paragraph: this round changes code). Smallest change per ruling. One commit:

    git commit -m "Ground crossings: zero language-server warnings, steady tie-breaks, one palette" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"

Current state: Lua `160 passed, 0 failed`, Python 18 OK, luacheck 0 warnings, lua-language-server **2 warnings** at
`GoblinPS/Planner.lua:46` (`need-check-nil` and `undefined-field` on `plan.level`). Read each file before changing it.

## R1. lua-language-server must report no problems (Important)

`Core.PlanRoute` builds `local plan = { to = to, notes = {} }` and only later assigns `plan.level`, so the language server
sees a table with no `level` field, and `Planner.Refresh` reads `plan.level` where `plan` may be nil as far as it can tell.
Rulings:
- `GoblinPS/Core.lua`: set the level when the table is built: `local plan = { to = to, notes = {}, level = API.Level() }`,
  delete the later `plan.level = API.Level()` line, and keep `ns.Travel.For(plan.level)`. Update the doc comment above
  `Core.PlanRoute` to list `level` (the character's level, or nil) alongside `result`, `hint`, `notes`.
- `GoblinPS/Planner.lua` `Planner.Refresh`: read the level once near the top, nil-safe:
  `local level = plan and plan.level or nil`, and pass `level` to `ns.Route.StepDetail`.
- If the language server still complains about the field, add a `---@class` / `---@field` annotation for the plan table
  in `Core.lua` rather than suppressing the diagnostic. Do not add `---@diagnostic disable`.
- Verify: `lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json`
  prints `Diagnosis completed, no problems found`.

## R2. One palette for chat and window (Minor)

`Core.lua` hard-codes `|cfff0b54a` and `|cff9c8f6d`; the second has already drifted one unit from `Widgets.COLOR.dim`.
Ruling: add to `GoblinPS/Widgets.lua` a pure helper `Widgets.ChatColor(name)` that returns the `|cffRRGGBB` escape for a
`Widgets.COLOR` entry (each channel `math.floor(v * 255 + 0.5)`, formatted `%02x`), and use
`ns.Widgets.ChatColor(warn and "amber" or "dim")` in `Core.lua`'s `routeTo`. `Core.lua` loads after `Widgets.lua` in the
TOC and calls it inside a function, so there is no load-order problem; in `test/test_ui.lua` the module list already loads
`Widgets` before `Core`. Add a unit assertion (in `test/test_ui.lua`, anywhere suitable) that
`ns.Widgets.ChatColor("amber") == "|cfff0b54a"` and that the dim escape equals what the formula gives for
`Widgets.COLOR.dim`.

## R3. Tighter colour assertions (Minor)

In `test/test_ui.lua`'s "ground steps in the window" block, compare all three channels of `row.detail.color` against
the palette entry, not only the first.

## R4. Dijkstra must not depend on hash order (Minor, deferred from the Task 2 review)

`GoblinPS/Route.lua` `shortest`: the scan `for key, d in pairs(dist)` picks the first minimum it meets, so two stops
that tie could be taken in a different order on the desktop Lua and in the game client. Ruling: break ties by key:
`if not done[key] and (d < best or (d == best and bestKey and key < bestKey)) then`. Add a test in
`test/test_route.lua`: build a tiny graph by hand (a table with `stops` and `edges`) where START reaches DEST through
two different middle stops at exactly equal cost, call `Route.Find` several times, and assert it always goes through the
stop whose key sorts first.

## Report

Append a section "Fix round 1" to `D:\goblinps\.superpowers\sdd\2026-09-19-goblinps-ground-crossings\task-3-report.md`:
per ruling what changed (file:line), RED then GREEN for each new test that can fail first, final Lua count, luacheck and
lua-language-server output. If a ruling proves impossible or breaks something it did not anticipate, STOP and report
BLOCKED with specifics. You cannot run the game client; claim nothing about in-game behaviour. Do not stage anything
under `.superpowers/`. Do not push.

Then reply with ONLY: Status, the commit (short SHA + subject), a one-line test summary, concerns, the report path.

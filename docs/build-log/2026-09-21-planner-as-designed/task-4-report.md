# Task 4 report: draw the route strip, a tooltip on every stop

Status: DONE
Commit: 0e61a64 Planner: draw the route strip, a tooltip on every stop

## What was done
1. `test/fake_frames.lua`: dropped `SetOwner`/`AddLine` from `ALLOWED_NOOP`; `SetTexture(path, wrapH, wrapV)` records both wrap modes; `GameTooltip` is now a modelled tooltip (SetOwner resets `lines`, AddLine keeps text and colour). The suite stayed green at 316 after this step.
2. `test/test_ui.lua`: added the brief's "the route strip" block (13 tests) verbatim, directly after the "the planner window" block.
3. `GoblinPS/Widgets.lua`: added `Widgets.ShowTooltip(owner, lines)` verbatim before `return Widgets`.
4. `GoblinPS/Planner.lua`: added `SPRITE`, `stripMetrics`, the pooled `badge`/`leg`, `wear`, `drawLine` and `drawStrip` after `geo()`; the strip layout and draw in `Refresh` after `local routed`; the warning-first hint block; the `strip` frame in `build()` after the backdrop block; `strip = strip` in `ui`.

## RED / GREEN evidence
Lua suite command:
`python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"`

- After Step 1: `316 passed, 0 failed`.
- RED (tests added, no implementation): `315 passed, 14 failed`. The 13 new tests failed with `attempt to index field 'strip' (a nil value)` and `attempt to call field 'ShowTooltip' (a nil value)`. The 14th failure was the existing "/gps to still prints a route in chat :: uses the same planner as the window", a cascade: a strip test that errors partway through never resets the shared planner state (e.g. `state.plan`/`level`). It passes once the strip exists.
- GREEN: `329 passed, 0 failed` (316 + 13).

Other gates:
- `python -m unittest discover -s test/tools`: `Ran 55 tests ... OK`.
- `python tools/check_art.py`: `47 pass, 0 with problems, 0 not drawn yet`.
- luacheck (PowerShell): `Total: 0 warnings / 0 errors in 40 files`.
- lua-language-server (PowerShell): `Diagnosis completed, no problems found` (after the narrowing below).

## Files changed
- D:\goblinps\GoblinPS\Planner.lua
- D:\goblinps\GoblinPS\Widgets.lua
- D:\goblinps\test\fake_frames.lua
- D:\goblinps\test\test_ui.lua

## Deviations from the brief
- `Planner.Refresh`: the brief's `if routed and g then` is `if plan and routed and g then`. As brief-written, the language server reported `need-check-nil` and `undefined-field level` on `plan.level`; this is the same narrowing Task 3 used for `if plan and routed then`. No behaviour change (`routed` already implies `plan`).
- None otherwise. The Delta route's badge list matched the brief's expectation (third step is a ride), so no test expectation changed.

## Concerns
- Verified in source only; nothing here has been run in the client. Worth checking in game: tiled `REPEAT` line parts rendering as dashes (not a stretched bar), badge sprite size against the ring art, label truncation at the two ends, and GameTooltip anchoring over badges.

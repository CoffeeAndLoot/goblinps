# Task 1 report: Whose pin, and which trip

## Status: DONE

## Commit

`d611db9` — "Remember whose map pin it is, and save the trip in progress"

Files: `GoblinPS/API.lua`, `GoblinPS/Core.lua`, `GoblinPS/Prefs.lua`,
`test/test_prefs.lua`, `test/test_ui.lua` (5 files changed, 161 insertions,
1 deletion). `AGENTS.md` (untracked, belongs to Codex) was left unstaged.

## What was done

Followed the brief verbatim:

- `test/test_ui.lua`: added the fake `waypoint`/`waypointClears` state and the
  `ClearWaypoint`/`WaypointIs` entries on the fake `ns.API` beside `SetWaypoint`
  (Step 1); added the `"the trip in progress"` describe block after
  `"remembering flight paths"` and before `print = realPrint` (Step 2).
- `test/test_prefs.lua`: added the "gives the saved trips a home..." test
  beside the existing `known` test (Step 2).
- `GoblinPS/API.lua`: added `API.ClearWaypoint()` and `API.WaypointIs(map, x, y)`
  directly after `API.SetWaypoint`, calling `C_Map.ClearUserWaypoint` /
  `C_Map.GetUserWaypoint` (Step 4).
- `GoblinPS/Prefs.lua`: added `db.trips = type(db.trips) == "table" and db.trips or {}`
  beside the `known` line, and extended the header comment with the `trips`
  line (Step 5).
- `GoblinPS/Core.lua`: replaced `Core.PinStep` with a version that records
  `lastPin`; added `Core.ClearPin` (clears only if `API.WaypointIs` still
  matches `lastPin`); added `tripSlot`, `Core.SaveTrip`, `Core.SavedTripName`,
  `Core.ClearTrip`; added `Core.SaveTrip(plan.to)` at the end of `Core.Go`,
  after `ns.Dash.Start(plan)` (Step 6).

## Gates run

- Lua suite: **297 passed, 0 failed** (baseline 291 → 297 as expected).
- `python -m unittest discover -s test/tools`: **51 run, 8 failing** (6
  failures + 2 errors), matching the new baseline given mid-task — the
  planner-geometry art tooling mismatch from commit `6ebb83c`, unrelated to
  this task and explicitly out of scope. Did not touch `tools/`,
  `test/tools/`, or `images/parts/`.
- `python tools/check_art.py`: **47 pass, 6 with problems, 0 not drawn yet**,
  matching the new baseline for the same reason.
- luacheck (PowerShell): **0 warnings / 0 errors** across 38 files.
- lua-language-server `--check` (PowerShell): **no problems found**.
- Did not run `tools/make_art.py`, per the mid-task instruction.

## Concerns

- The brief's commit message template used the attribution line
  `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. This session's
  attribution reminder specifies `Claude Sonnet 5` (the actual model running
  this session) and says it takes precedence, so the commit uses
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` instead of the
  brief's literal text. Flagging in case the difference matters for this
  project's convention.
- No other concerns. All interfaces (`API.ClearWaypoint`, `API.WaypointIs`,
  `Core.PinStep`, `Core.ClearPin`, `Core.SaveTrip`, `Core.SavedTripName`,
  `Core.ClearTrip`) match the brief's specified signatures exactly, ready for
  Tasks 2 and 3.

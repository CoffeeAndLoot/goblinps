# Task 5 report: making it drive

Commit: `d3548db` "Dash unit: advance, recalculate and arrive"

## Files changed, with line numbers

### `GoblinPS/Dash.lua`

- Line 125: `Dash.TICK = 0.5`.
- Lines 127-129: local `yards(d)` formatter.
- Lines 134-142: local `aimArrow(pos, step)` — hides the arrow when
  `Trip.ArrowAngle` returns nil (unknown facing), otherwise rotates and shows it.
- Lines 144-151: local `finish()` — sets "Arrived.", blanks next/distance/eta,
  hides the arrow, and clears `state.plan`, `state.index`, `state.best`.
- Lines 153-213: `function Dash.Tick(event)` — reads `ns.Core.Here()` and
  `ns.API.OnTaxi()`, calls `ns.Trip.Check`, and acts on the verdict:
  - `pause` (170-173): "Waiting...", blank eta, hide arrow, change nothing else.
  - `advance` (175-183): finishes on the last step, otherwise
    `state.index, state.best = state.index + 1, nil` (line 180), refreshes, and
    calls `ns.Core.PinStep` on the new current step.
  - `recalculate` (185-198): replans via `ns.Core.PlanRoute(state.plan.to, pos)`.
    A non-empty result restarts the plan at step 1 with `state.best = nil`
    (line 188). See "zero-step case" below for the added `elseif`.
  - otherwise "stay" (201-212): measures distance, updates `state.best`,
    aims the arrow, and sets the ETA from `Trip.Remaining`.
- Lines 84-94 (inside `build()`): after `ns.Core.CloseOnEscape`, an `OnUpdate`
  script accumulates `elapsed` and calls `Dash.Tick("tick")` every
  `Dash.TICK` seconds (87-93), then `ns.API.OnTripEvent(function(kind)
  Dash.Tick(kind) end)` (94) registers the trip-event callback. Both are
  inside `build()`, which the previous task's review confirmed runs exactly
  once (guarded by `if not ui then build() ... end` in `Dash.Start`).

### `GoblinPS/Core.lua`

- Added `function Core.PinStep(step)` (the pin/arrow setter, pulled out of
  `Core.Go` so the dash can call it again on every advance) — returns false
  for a nil step, a hearth step, or a step whose target has no `.map`.
- Rewrote `function Core.Go(plan)` to call `Core.PinStep(step)` instead of
  inlining the `SetWaypoint` call, and to end with `ns.Dash.Start(plan)`,
  handing the plan to the dash unit.

### `GoblinPS/Planner.lua`

- In the GO button's handler, after `ns.Core.Go(state.plan)`: assigns
  `local plan = state.plan` and hides the planner frame when
  `ui.frame:IsShown() and plan and plan.result and #plan.result.steps > 0`.
  (Written through a local rather than repeated `state.plan.result` field
  chains — see "one lint fix" below for why.)

### `test/test_ui.lua`

- Fixture fix (lines ~496-509): the shared dash-test `plan` was missing
  `to` and each step's target was missing `map`. See "brief defect" below.
- Appended `h.describe("the dash unit drives the trip", ...)` (9 tests, the
  8 from the brief plus the zero-step-recalculation test) directly after
  the existing `h.describe("the dash unit", ...)` block, inside the same
  `do ... end` so it shares the `Dash` and `plan` locals, per the brief.
- Two small edits to pre-existing tests in "the planner window" describe,
  to reopen the planner after GO now closes it — see "test regression" below.
- Added a `---@type number|nil, boolean, function[]` annotation on the
  `facing, onTaxi, tripCallbacks` declaration — see "one lint fix" below.

## RED then GREEN

RED (Step 2, before implementing `Dash.Tick`), all 9 new tests failing the
same way:

```
210 passed, 9 failed
FAIL: the dash unit drives the trip :: advances when you reach the step's target
    test/test_ui.lua:572: attempt to call field 'Tick' (a nil value)
... (same error, one per new test, 9 total)
```

After implementing Dash.lua/Core.lua/Planner.lua and fixing the fixture
(below), first GREEN attempt surfaced one regression from the new
GO-closes-the-planner behaviour:

```
218 passed, 1 failed
FAIL: the planner window :: closes and reopens without rebuilding
    test/test_ui.lua:282: expected a falsy value, got "true"
```

After fixing that (below), final GREEN:

```
219 passed, 0 failed
```

## Two defects found and fixed beyond the brief's literal text

1. **Brief's test fixture was incomplete for this task's new requirement.**
   The shared `plan` fixture (written for task 4, unchanged since) had step
   targets with only `name, c, x, y` — no `map`. Task 5's pin test
   ("moves Blizzard's pin onto each new step, not just the first") needs
   `Core.PinStep` to succeed on step 2, and `Core.PinStep` refuses any step
   whose target lacks `.map` (correctly — a real step from `Graph.lua` always
   carries one). Copied verbatim, that test would pass state.index checks but
   never see `#pins` grow, since `PinStep` would bail out silently. I added
   `map = 1` to each step's `to` table and `to = ns.Search.Exact(ns.Data,
   "Westland", "H")` to the plan itself (the destination a recalculation
   replans towards, exactly as `Core.PlanRoute` always sets it in production).
   This is a fixture-only fix; no production logic changed for it.

2. **GO closing the planner regressed two pre-existing tests.** "GO drops a
   pin on the first step" and "GO re-plans from where you are now instead of
   using a stale plan" both click GO on a plan with steps, which now (as
   specified) hides the planner. Neither test previously depended on the
   frame's visibility, so the click itself didn't fail — but a later test,
   "closes and reopens without rebuilding", assumes the frame starts shown
   and fails once it doesn't. I added a `SlashCmdList.GOBLINPS("")` after
   each `Fake.Click(ui.go)` to reopen the planner (exactly what a player
   would do with `/gps`, per the brief's own "/gps reopens the planner
   without ending the trip"), restoring the pre-existing assumption for the
   tests that follow. Test logic and assertions are otherwise untouched.

3. **One lint-only fix, not a logic bug.** lua-language-server flagged
   `state.plan.result` (accessed via a repeated field chain rather than a
   local) as `undefined-field` in the new Planner.lua code, even though the
   identical pattern via a local (`local plan = state.plan; plan.result`)
   in `Planner.Refresh` was already clean — a known narrowing limitation for
   chained field access vs. locals. Rewrote to go through a local, matching
   the codebase's existing style. Separately, the brief's own verbatim test
   text (`facing = nil` after `local facing, onTaxi, tripCallbacks = 0,
   false, {}`) tripped a `cast-local-type` warning, since `facing`'s
   inferred type was plain `number` with no way to hold `nil` for the "facing
   unknown" case the test (correctly) exercises. Added a
   `---@type number|nil, boolean, function[]` annotation on that
   pre-existing declaration line — it does not change behaviour, only tells
   the checker `facing` is allowed to be nil, matching what
   `ns.API.PlayerFacing()` genuinely returns.

## The zero-step recalculation case

Handled inside the existing `recalculate` branch of `Dash.Tick`
(`GoblinPS/Dash.lua` lines 185-198):

```lua
if verdict == "recalculate" then
    local replanned = ns.Core.PlanRoute(state.plan.to, pos)
    if replanned.result and #replanned.result.steps > 0 then
        state.plan, state.index, state.best = replanned, 1, nil
        ui.next:SetText("Recalculating...")
        Dash.Refresh()
    elseif replanned.result then
        finish()
    end
    return
end
```

A `replanned.result` that exists but has zero steps (the only way to reach
it is a replan that finds the player already at their destination) now
takes the same `finish()` path that advancing past the last step takes,
instead of falling through and leaving the previous step's text stale on
screen. A genuinely-nil `replanned.result` (no route at all) is left as
before — out of this task's stated scope, and a different, pre-existing
question about what a live recalculation should do when Core.PlanRoute
cannot find any route.

Test added: `test/test_ui.lua`, "finishes the trip when a recalculation
finds nothing left to plan" (in the new `h.describe("the dash unit drives
the trip", ...)` block). It stands the player near the current ride step's
target to establish a small `state.best`, then far enough away to cross
`Trip.STRAY_YARDS` and trigger `"recalculate"`. The plan's `to` (added to
the fixture, see defect 1) is the "Westland" zone, which is exactly the
zone the fake player always stands in on map 1 — `Graph.Build` prices a
same-zone ride to a zone destination at 0 seconds (`GoblinPS/Graph.lua`
lines 138-156), so `Route.Plan`'s tidy pass always drops it as
too-short, giving a real, deterministic zero-step replan without needing a
literal coordinate match. Asserts `ui.step:GetText() == "Arrived."` and
`state.plan` is falsy.

## Trip event registered exactly once

`ns.API.OnTripEvent(function(kind) Dash.Tick(kind) end)` is at
`GoblinPS/Dash.lua` line 94, inside `build()`, right after
`ns.Core.CloseOnEscape(f, "GoblinPSDash")`. `build()` itself is only ever
called from `Dash.Start` behind `if not ui then build() ... end`
(`GoblinPS/Dash.lua` lines 89-98), which the previous task's review already
verified runs once. `Dash.Start` is called on every GO press and by the
tests repeatedly; `ui` stays non-nil after the first call, so `build()`
(and the registration inside it) does not run again.

## `state.best` cleared on every advance and every recalculate

- Advance, non-final step: `GoblinPS/Dash.lua` line 180 —
  `state.index, state.best = state.index + 1, nil`.
- Advance, final step: routed through `finish()` (line 177 calls it), which
  sets `state.best = nil` at line 150.
- Recalculate, non-empty replan: line 188 —
  `state.plan, state.index, state.best = replanned, 1, nil`.
- Recalculate, zero-step replan: routed through `finish()` (line 196),
  again clearing `state.best` at line 150.

Every path out of `advance` and `recalculate` clears it; no path leaves the
old `best` in place for a new step or a new plan.

## Final counts

- Lua tests: **219 passed, 0 failed** (210 baseline + 9 new).
- luacheck: **0 warnings / 0 errors in 39 files**.
- lua-language-server: `Diagnosis completed, no problems found` (exit 0,
  empty results array).

## Notes

- Nothing pushed; branch `dash-unit` unchanged apart from local commits.
- `AGENTS.md` (untracked, Codex's) was left out of `git add` and remains
  untracked after the commit.
- No in-game claims are made anywhere above; everything here is desktop
  Lua-test and static-analysis evidence only.

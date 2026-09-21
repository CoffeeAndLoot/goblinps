# Trips That Survive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A trip on the dash ends only when the player presses Stop, and
survives Escape, a hidden interface, a `/reload` and a logout.

**Architecture:** The dash stops treating "hidden" as "over": it comes off
Escape's list and its `OnHide` no longer ends the trip. `Dash.Stop` becomes the
one place a trip ends, and so the one place the saved trip and the map pin are
cleared. The destination is saved by name in the account-wide `GoblinPSDB`,
keyed by character; on login it is looked up again and the dash replans from
wherever the player stands, as every route does.

**Tech Stack:** Plain Lua 5.1 against the Blizzard API on WoW Forever beta
build 1.60.1.69913 (interface `16001`), no libraries. Tests run on the desktop
through `lupa`.

**Spec:** `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`,
section "Plan 7". Read it first.

## Global Constraints

- **No libraries.** Plain Lua 5.1. **No Blizzard frame templates.** **No secure
  code.**
- **`API.lua` is the only file that calls Blizzard game APIs.** Every new
  `C_Map` call goes through a new `API` function. `Dash.lua` and `Core.lua`
  never touch `C_Map` directly.
- **Never use `SavedVariablesPerCharacter`.** On build 1.60.1.69913 it is
  written and never loaded (verified in game 2026-09-21). Per-character data
  lives in the account-wide `GoblinPSDB`, keyed by `API.CharacterKey()`.
- **Only Stop ends a trip.** Nothing else -- not Escape, not hiding the
  interface, not arriving, not a reload -- may end it or clear its save.
- **Clear only a map pin that is still ours.** A waypoint the player set must
  survive a trip ending.
- **Chat messages are plain and say what happened.** No jokes in them.
- **Never read a size from a frame that only inherits one**, and **a test that
  checks how big a thing is cannot tell you it is in the wrong place.** (Not
  expected to arise here; they bind every UI change in this project.)
- **Zero luacheck warnings, zero language-server warnings, no lint
  suppression.** A new WoW global goes in both `.luacheckrc` and `.luarc.json`.
- **Calendar versions in the TOC only.** This plan ships `2026.09.21.4`.

## Gates — every task runs all of these before committing

```bash
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```

```bash
python -m unittest discover -s test/tools
```

```bash
python tools/check_art.py
```

luacheck and lua-language-server, **from PowerShell, never Git Bash** -- through
Git Bash the language server mis-scopes the workspace root and reports over a
hundred bogus warnings:

```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
$env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\lls.json
```

**Baseline to match or beat: 291 Lua tests, 51 Python tests, `check_art`
47 / 0 / 0, luacheck 0 warnings in 38 files, language server clean.**

`test/test_ui.lua`'s tests share one planner and one dash and **run in order**:
every new test must leave the player's position, the dash, the saved trips and
the pin as it found them.

## File structure

| File | Responsibility | Task |
|---|---|---|
| `GoblinPS/API.lua` | Two new calls: clear the pin, and ask whether the pin is at a given point | 1 |
| `GoblinPS/Prefs.lua` | Guarantees `GoblinPSDB.trips` is a table | 1 |
| `GoblinPS/Core.lua` | Remembers our pin and clears only it; saves, reads and clears the trip; starting a route saves it; login resumes it | 1, 3 |
| `GoblinPS/Dash.lua` | Off Escape; hiding no longer ends a trip; Stop and arrival clear; resuming | 2, 3 |
| `GoblinPS/Planner.lua` | Opened mid-trip, shows the trip's destination | 3 |
| `GoblinPS/GoblinPS.toc` | Version | 3 |
| `.luacheckrc`, `.luarc.json` | `GoblinPSDash` stops being a global | 2 |
| `test/test_ui.lua`, `test/test_prefs.lua` | Tests | 1, 2, 3 |
| `docs/`, `CLAUDE.md` | Checklist, status, rules | 4 |

---

### Task 1: Whose pin, and which trip

**Files:**
- Modify: `GoblinPS/API.lua`
- Modify: `GoblinPS/Prefs.lua`
- Modify: `GoblinPS/Core.lua`
- Test: `test/test_prefs.lua`, `test/test_ui.lua`

**Interfaces:**
- Produces, for Tasks 2 and 3:

```lua
API.ClearWaypoint()            -- removes the user waypoint, if the client can
API.WaypointIs(map, x, y)      -- true when the user waypoint is at exactly that point
Core.PinStep(step)             -- unchanged signature; now also remembers the pin as ours
Core.ClearPin()                -- clears the pin only if it is still the one PinStep set
Core.SaveTrip(place)           -- place: a Search item with a .name
Core.SavedTripName()           -- this character's saved destination name, or nil
Core.ClearTrip()               -- forgets this character's saved trip
```

`GoblinPSDB.trips = { ["Name-Realm"] = { to = "<place name>" } }`.

- [ ] **Step 1: Give the test API a waypoint to own**

In `test/test_ui.lua`, beside the existing `local pins, loginCallbacks = {}, {}`,
add the user waypoint the fake client holds:

```lua
    -- The one user waypoint the client holds, as { map, x, y }, and how many
    -- times it has been cleared.
    local waypoint, waypointClears = nil, 0
```

Replace the `SetWaypoint` entry in `ns.API` and add two more:

```lua
        SetWaypoint = function(map, x, y)
            pins[#pins + 1] = { map, x, y }
            waypoint = { map, x, y }
            return true
        end,
        ClearWaypoint = function()
            waypoint = nil
            waypointClears = waypointClears + 1
        end,
        WaypointIs = function(map, x, y)
            return waypoint ~= nil and waypoint[1] == map and waypoint[2] == x and waypoint[3] == y
        end,
```

- [ ] **Step 2: Write the failing tests**

In `test/test_prefs.lua`, beside the existing `known` test:

```lua
        h.it("gives the saved trips a home and keeps the one it has", function()
            h.eq(type(Prefs.Init(nil).trips), "table")
            local kept = { ["A-B"] = { to = "Orgrimmar" } }
            h.eq(Prefs.Init({ trips = kept }).trips, kept)
            h.eq(type(Prefs.Init({ trips = "junk" }).trips), "table", "a hostile value is repaired")
        end)
```

In `test/test_ui.lua`, a new describe block placed **after** the
`"remembering flight paths"` block and before the final `print = realPrint`:

```lua
    h.describe("the trip in progress", function()
        local Core = ns.Core
        local step = { kind = "ride", to = { name = "Gate", map = 1, mx = 0.5, my = 0.5 } }
        -- These tests run at the end of the file, after tests that move the
        -- player, and `standAt` is local to the dash block, out of reach here.
        -- Anything that plans starts from where the file itself starts:
        -- beside Alpha, in Westland.
        local function home()
            where.map, where.mx, where.my = 1, 0.89, 0.9
        end

        h.it("clears the map pin it set", function()
            h.truthy(Core.PinStep(step))
            local before = waypointClears
            Core.ClearPin()
            h.eq(waypoint, nil, "our pin is gone")
            h.eq(waypointClears, before + 1)
        end)

        h.it("leaves a pin the player set in its place", function()
            -- A waypoint dropped mid-trip is the player's. Ending the trip
            -- must not take it with it.
            Core.PinStep(step)
            waypoint = { 9, 0.25, 0.75 }
            local before = waypointClears
            Core.ClearPin()
            h.eq(waypointClears, before, "the player's pin was not ours to clear")
            h.eq(waypoint[1], 9)
            waypoint = nil
        end)

        h.it("forgets the pin once cleared, so a second clear touches nothing", function()
            Core.PinStep(step)
            Core.ClearPin()
            waypoint = { 1, 0.5, 0.5 } -- the player puts one back on the very same spot
            local before = waypointClears
            Core.ClearPin()
            h.eq(waypointClears, before, "nothing of ours is left to clear")
            waypoint = nil
        end)

        h.it("saves the trip under this character, and only this one", function()
            Core.SaveTrip({ name = "Delta" })
            h.eq(Core.SavedTripName(), "Delta")
            h.eq(GoblinPSDB.trips[character].to, "Delta", "in the account-wide save")
            character = "Other-Test Realm"
            h.eq(Core.SavedTripName(), nil, "another character has no trip")
            character = "Tester-Test Realm"
            Core.ClearTrip()
            h.eq(Core.SavedTripName(), nil)
        end)

        h.it("saves the destination when a route starts", function()
            -- Start Route is the one deliberate way to change destination.
            home()
            local plan = ns.Core.PlanRoute(ns.Search.Exact(ns.Data, "Delta", "H"))
            h.truthy(plan.result and #plan.result.steps > 0, "sanity: a route to Delta")
            Core.Go(plan)
            h.eq(Core.SavedTripName(), "Delta")
            Core.ClearTrip()
            ns.Dash.Stop()
            Core.ClearPin()
        end)
    end)
```

- [ ] **Step 3: Run to verify they fail**

Run the Lua suite. Expected: FAIL -- `Prefs.Init(nil).trips` is nil, and
`attempt to call field 'ClearPin' (a nil value)`.

- [ ] **Step 4: The two client calls**

In `GoblinPS/API.lua`, directly after `API.SetWaypoint`:

```lua
-- Remove the user waypoint. Present on build 1.60.1.69913
-- (MapDocumentation.lua); Blizzard's own WaypointLocationDataProvider.lua
-- calls it.
function API.ClearWaypoint()
    if C_Map and C_Map.ClearUserWaypoint then
        C_Map.ClearUserWaypoint()
    end
end

-- True when the user waypoint sits at this map and position. Blizzard's own
-- map code reads a waypoint as `uiMapID` and `position.x` / `.y`, the same 0..1
-- fractions SetWaypoint was handed, so a waypoint we set compares equal.
function API.WaypointIs(map, x, y)
    if not (C_Map and C_Map.GetUserWaypoint) then
        return false
    end
    local point = C_Map.GetUserWaypoint()
    if not (point and point.position) then
        return false
    end
    return point.uiMapID == map
        and math.abs(point.position.x - x) < 1e-4
        and math.abs(point.position.y - y) < 1e-4
end
```

- [ ] **Step 5: The trips table**

In `GoblinPS/Prefs.lua`'s `Prefs.Init`, beside the `known` line:

```lua
    db.trips = type(db.trips) == "table" and db.trips or {}
```

and extend the header comment's list of what the table holds with one line:
`trips`: each character's trip in progress, as
`{ ["Name-Realm"] = { to = "<place name>" } }`, owned by Core.lua, account-wide
for the same reason as `known`.

- [ ] **Step 6: Our pin, and the saved trip**

In `GoblinPS/Core.lua`, replace `Core.PinStep` with:

```lua
-- The pin PinStep last set, as { map, x, y }, so that only our own pin is
-- ever cleared: a waypoint the player drops mid-trip is theirs.
local lastPin

-- Blizzard's map pin and on-screen arrow for one step. Spec decision 3 puts
-- the pin on the step you are ON, so the dash calls this again each time it
-- advances, not only when GO is pressed. Quiet: only GO explains itself.
function Core.PinStep(step)
    if not step or step.kind == "hearth" or not step.to.map then
        return false
    end
    if API.SetWaypoint(step.to.map, step.to.mx, step.to.my) then
        lastPin = { step.to.map, step.to.mx, step.to.my }
        return true
    end
    return false
end

-- Clear the map pin, but only if it is still the one we set.
function Core.ClearPin()
    if lastPin and API.WaypointIs(lastPin[1], lastPin[2], lastPin[3]) then
        API.ClearWaypoint()
    end
    lastPin = nil
end

-- ---- the trip in progress, which outlives a reload ----
--
-- Only the destination's name is saved: the player may be anywhere when they
-- come back, and every route starts where they stand, so resuming is planning
-- again. Account-wide, under this character, because this build never loads
-- per-character saves. See Prefs.lua.

local function tripSlot()
    local key = API.CharacterKey()
    return key and prefs().trips, key
end

function Core.SaveTrip(place)
    local trips, key = tripSlot()
    if trips and place and place.name then
        trips[key] = { to = place.name }
    end
end

function Core.SavedTripName()
    local trips, key = tripSlot()
    local trip = trips and trips[key]
    return type(trip) == "table" and trip.to or nil
end

function Core.ClearTrip()
    local trips, key = tripSlot()
    if trips then
        trips[key] = nil
    end
end
```

In `Core.Go`, save the destination as the trip starts. After
`ns.Dash.Start(plan)` add:

```lua
    Core.SaveTrip(plan.to)
```

- [ ] **Step 7: Run the tests to verify they pass**

Run the Lua suite. Expected: green, 297 passed.

- [ ] **Step 8: Lint**

Run luacheck and the language server from PowerShell. Expected: zero warnings.

- [ ] **Step 9: Commit**

```bash
git add GoblinPS/API.lua GoblinPS/Prefs.lua GoblinPS/Core.lua test/test_prefs.lua test/test_ui.lua
git commit -m "Remember whose map pin it is, and save the trip in progress" -m "Only a pin GoblinPS set is ever cleared, so a waypoint the player drops mid-trip survives. The trip's destination is saved by name in the account-wide save under this character, since this build never loads per-character saves." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Only Stop ends a trip

**Files:**
- Modify: `GoblinPS/Dash.lua`
- Modify: `.luacheckrc`, `.luarc.json`
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `Core.ClearPin()`, `Core.ClearTrip()` (Task 1).
- Produces, for Task 3: `Dash.Stop()` ends the trip and clears the saved trip
  and our pin; `Dash.Tick` does nothing while the dash is hidden.

**Why this task rewrites a test.** `test/test_ui.lua` has a block,
`"the dash unit and Escape"`, asserting that hiding the dash ends the trip --
"the trip must not outlive the window it belongs to". That was the right rule
while hiding was the only way a trip ended. It is the rule this plan reverses.
Its real concern survives: a hidden trip must never replan or move pins behind
the player's back. So the block is rewritten, not deleted, and that concern
keeps a test.

- [ ] **Step 1: Write the failing tests**

Replace the whole `h.describe("the dash unit and Escape", ...)` block in
`test/test_ui.lua` with:

```lua
        h.describe("the dash unit and Escape", function()
            h.it("stays off Escape's list, so Escape never ends a trip", function()
                -- Escape is pressed constantly: to close bags, clear a target,
                -- open the game menu. It used to close the dash and end the
                -- trip with it. The dash is a heads-up display, like the
                -- minimap, not a dialog.
                Dash.Start(plan)
                for _, name in ipairs(UISpecialFrames) do
                    h.truthy(name ~= "GoblinPSDash", "the dash must not be on Escape's list")
                end
                Dash.Stop()
            end)

            h.it("keeps the trip when the dash is hidden some other way", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                ui.frame:Hide()
                h.truthy(state.plan, "hiding is not stopping")
                -- But a hidden trip must not move on behind the player's back:
                -- standing on the first step's target would advance it.
                standAt(0, 0)
                Dash.Tick("tick")
                h.eq(state.index, 1, "nothing moves while the dash is hidden")
                ui.frame:Show()
                Dash.Tick("tick")
                h.eq(state.index, 2, "and it picks up again once shown")
                standAt(1000, 1100)
                Dash.Stop()
            end)

            h.it("ends the trip on Stop, clearing the saved trip and our pin", function()
                Dash.Start(plan)
                ns.Core.SaveTrip(plan.to)
                ns.Core.PinStep({ kind = "ride", to = { name = "Gate", map = 1, mx = 0.5, my = 0.5 } })
                Dash.Stop()
                local ui, state = Dash.Debug()
                h.falsy(state.plan)
                h.falsy(ui.frame:IsShown())
                h.eq(ns.Core.SavedTripName(), nil, "a stopped trip does not come back after a reload")
                h.eq(waypoint, nil, "our pin is cleared")
            end)

            h.it("clears our pin on arrival, and keeps saying Arrived", function()
                local oneStep = { level = 60, to = plan.to, result = { seconds = 60, steps = {
                    { kind = "ride", seconds = 60,
                      to = { name = "the North Gate", c = 1, x = 0, y = 0, map = 1, mx = 0.5, my = 0.5 } },
                } } }
                Dash.Start(oneStep)
                ns.Core.PinStep(oneStep.result.steps[1])
                standAt(0, 0)
                Dash.Tick("tick")
                local ui = Dash.Debug()
                h.eq(ui.steps[1]:GetText(), "Arrived.")
                h.truthy(ui.frame:IsShown(), "Arrived. stays up until Stop")
                h.eq(waypoint, nil, "the pin at the destination is cleared")
                standAt(1000, 1100)
                Dash.Stop()
            end)
        end)
```

Also, in the test `"still ends the trip when the button is clicked"`, change
only the assertion message `"clicking Stop ends the trip, as Escape does"` to
`"clicking Stop ends the trip"`. Escape no longer does.

Every new test ends with `Dash.Stop()`. The two that move the player end, just
before it, with `standAt(1000, 1100)` -- the position the file starts at,
beside Alpha -- so no later test inherits a player standing on a step's
target.

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: FAIL -- the dash is still on Escape's list,
hiding clears `state.plan`, and Stop leaves the saved trip and the pin.

- [ ] **Step 3: Take the dash off Escape, and stop ending the trip on hide**

In `GoblinPS/Dash.lua`'s `build()`:

- Delete the `f:SetScript("OnHide", ...)` script and the comment block above
  it. Nothing now ends a trip on hide.
- Delete `ns.Core.CloseOnEscape(f, "GoblinPSDash")`.

- [ ] **Step 4: Stop is the one end**

Replace `Dash.Stop` and the comment above it with:

```lua
-- Stop is the one action that ends a trip. Nothing else does -- not Escape,
-- not hiding the interface, not arriving, not a reload -- so it is also the
-- one place the saved trip and our map pin are cleared.
function Dash.Stop()
    state.plan, state.index, state.best, state.banner = nil, nil, nil, nil
    ns.Core.ClearTrip()
    ns.Core.ClearPin()
    if ui then
        ui.frame:Hide()
    end
end
```

- [ ] **Step 5: Arrival clears our pin**

In `finish()`, after `ui.arrow:Hide()`, add:

```lua
    -- There is nowhere left to point. The trip is not over -- only Stop ends
    -- it -- but a pin on the spot you are standing on says nothing.
    ns.Core.ClearPin()
```

- [ ] **Step 6: A hidden dash does not tick**

In `Dash.Tick`, change the first guard from

```lua
    if not ui or not state.plan then
```

to

```lua
    -- Hidden (only something other than Stop can do that now): hold still,
    -- so a trip never replans or moves the map pin where nobody can see.
    if not ui or not state.plan or not ui.frame:IsShown() then
```

- [ ] **Step 7: `GoblinPSDash` is no longer a global**

It only existed so Escape's list could name it. Remove `"GoblinPSDash"` from
the globals list in both `.luacheckrc` and `.luarc.json`.

- [ ] **Step 8: Run the tests to verify they pass**

Run the Lua suite. Expected: green, 300 passed -- the Escape block went from
one test to four. Every existing dash test must still pass; if one relied on
hiding ending the trip, its read may change and its assertion may not --
except the Escape block this task deliberately rewrote.

- [ ] **Step 9: Lint**

Run luacheck and the language server from PowerShell. Expected: zero warnings.

- [ ] **Step 10: Commit**

```bash
git add GoblinPS/Dash.lua .luacheckrc .luarc.json test/test_ui.lua
git commit -m "Only Stop ends a trip" -m "The dash comes off Escape's list and hiding it no longer ends the trip, so pressing Escape to close a bag cannot kill the route. Stop clears the saved trip and our map pin; arriving clears the pin and keeps Arrived showing. A hidden dash holds still rather than replanning where nobody can see." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Resume after a reload

**Files:**
- Modify: `GoblinPS/Dash.lua`
- Modify: `GoblinPS/Core.lua`
- Modify: `GoblinPS/Planner.lua`
- Modify: `GoblinPS/GoblinPS.toc` (version `2026.09.21.4`)
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: everything Tasks 1 and 2 produced.
- Produces:

```lua
Dash.Resume(place)     -- show the dash and plan to `place` once the client knows where you are
Dash.Destination()     -- the running or resuming trip's destination place, or nil
Core.ResumeTrip()      -- on login: resume this character's saved trip, or say why not
```

- [ ] **Step 1: Write the failing tests**

In `test/test_ui.lua`, add to the `"the trip in progress"` describe block from
Task 1, after its last test:

```lua
        local delta = ns.Search.Exact(ns.Data, "Delta", "H")

        -- A reload as this client performs it: the account-wide save comes
        -- back through a real serialise-and-load, the per-character one does
        -- not come back at all.
        local function reload()
            local function copy(t)
                if type(t) ~= "table" then return t end
                local out = {}
                for k, v in pairs(t) do out[k] = copy(v) end
                return out
            end
            GoblinPSDB, GoblinPSCharDB = copy(GoblinPSDB), nil
        end

        h.it("waits for a position before resuming, then plans from it", function()
            home()
            where.map = nil -- loading, or an instance: the client cannot say
            ns.Dash.Resume(delta)
            local ui, state = ns.Dash.Debug()
            h.truthy(ui.frame:IsShown(), "the dash comes back straight away")
            h.eq(ns.Dash.Destination(), delta)
            ns.Dash.Tick("tick")
            h.falsy(state.plan, "no position, no plan yet")
            home()
            ns.Dash.Tick("tick")
            h.truthy(state.plan, "planned from where you stand")
            h.eq(state.plan.to, delta)
            h.eq(state.index, 1)
            h.truthy(waypoint, "the first step is pinned")
            ns.Dash.Stop()
        end)

        h.it("shows Arrived when you resume at the destination", function()
            home()
            local westland = ns.Search.Exact(ns.Data, "Westland", "H")
            ns.Dash.Resume(westland) -- home() is in Westland
            ns.Dash.Tick("tick")
            local ui, state = ns.Dash.Debug()
            h.eq(ui.steps[1]:GetText(), "Arrived.")
            h.falsy(state.plan)
            ns.Dash.Stop()
        end)

        h.it("resumes this character's saved trip at login", function()
            home()
            Core.SaveTrip(delta)
            reload()
            Core.ResumeTrip()
            h.eq(ns.Dash.Destination() and ns.Dash.Destination().name, "Delta")
            ns.Dash.Tick("tick")
            local _, state = ns.Dash.Debug()
            h.truthy(state.plan, "the trip is running again")
            ns.Dash.Stop()
        end)

        h.it("resumes nothing for a character with no saved trip", function()
            Core.SaveTrip(delta)
            character = "Other-Test Realm"
            ns.Dash.Stop() -- as a fresh login finds it
            Core.ResumeTrip()
            local ui = ns.Dash.Debug()
            h.falsy(ui.frame:IsShown(), "another character's trip is not this one's")
            character = "Tester-Test Realm"
            Core.ClearTrip()
        end)

        h.it("drops a trip whose destination no longer exists, and says so", function()
            GoblinPSDB.trips[character] = { to = "Atlantis" }
            local from = #printed
            Core.ResumeTrip()
            h.eq(Core.SavedTripName(), nil, "the unresolvable trip is dropped")
            local said = table.concat(printed, "\n", from + 1, #printed)
            h.truthy(said:find("Couldn't resume your trip to Atlantis", 1, true),
                     "never silently")
        end)

        h.it("opens the planner on the running trip's destination", function()
            home()
            local _, pstate = ns.Planner.Debug()
            local pui = ns.Planner.Debug()
            if pui and pui.frame:IsShown() then ns.Planner.Toggle() end
            local keptTo = pstate and pstate.to
            if pstate then pstate.to = nil end
            ns.Dash.Resume(delta)
            ns.Planner.Toggle()
            pui, pstate = ns.Planner.Debug()
            h.eq(pstate.to, delta, "the planner shows where the trip is going")
            h.eq(pui.toBox:GetText(), "Delta")
            ns.Planner.Toggle()
            pstate.to = keptTo
            ns.Dash.Stop()
        end)
```

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: FAIL -- `attempt to call field 'Resume' (a nil value)`.

- [ ] **Step 3: Resuming, in the dash**

In `GoblinPS/Dash.lua`, lift the build-and-position block out of `Dash.Start`
into a local so `Dash.Resume` can share it:

```lua
local function ensureBuilt()
    if ui then
        return
    end
    build()
    local p = ns.Core.Position("dash")
    ui.frame:ClearAllPoints()
    if p then
        ui.frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    else
        ui.frame:SetPoint("CENTER", UIParent, "CENTER", -260, 0)
    end
end
```

`Dash.Start` calls `ensureBuilt()` where its inline block was, and also clears
`state.resume` alongside the other fields it resets -- a new route replaces a
resume in progress:

```lua
    state.plan, state.index, state.best, state.banner, state.resume = plan, 1, nil, nil, nil
```

`Dash.Stop` clears `state.resume` too:

```lua
    state.plan, state.index, state.best, state.banner, state.resume = nil, nil, nil, nil, nil
```

Add, after `Dash.Stop`:

```lua
-- Carry on with a trip saved before a reload or a logout. Every route starts
-- where you stand, so resuming is planning again -- as soon as the client can
-- say where that is.
function Dash.Resume(place)
    ensureBuilt()
    state.plan, state.index, state.best, state.banner = nil, nil, nil, nil
    state.resume = place
    ui.steps[1]:SetText("Resuming your trip to " .. ns.Search.ShortName(place.name) .. "...")
    ui.steps[2]:SetText("")
    ui.steps[3]:SetText("")
    ui.destination:SetText("")
    ui.distance:SetText("")
    ui.eta:SetText("")
    ui.arrow:Hide()
    ui.frame:Show()
end

-- Where the running trip, or the one resuming, is headed.
function Dash.Destination()
    return state.plan and state.plan.to or state.resume
end
```

Add, above `Dash.Tick`:

```lua
-- One try at resuming. No position yet (still loading, or in an instance):
-- keep waiting. A position but no route: say so and stop trying, but keep the
-- saved trip -- only Stop ends a trip.
local function tryResume()
    if not ns.Core.Here() then
        ui.distance:SetText("Waiting...")
        return
    end
    local place = state.resume
    state.resume = nil
    local plan = ns.Core.PlanRoute(place)
    local steps = plan.result and plan.result.steps
    if not steps then
        ui.steps[1]:SetText(plan.notes[#plan.notes] or ("No route found to " .. place.name .. "."))
        return
    end
    if #steps == 0 then
        finish()
        return
    end
    state.plan, state.index, state.best, state.banner = plan, 1, nil, nil
    Dash.Refresh()
    ns.Core.PinStep(steps[1])
end
```

and change `Dash.Tick`'s opening guard (as Task 2 left it) into three lines, so
a resume is tried before the "no trip" early return:

```lua
    if not ui or not ui.frame:IsShown() then
        return
    end
    if state.resume then
        tryResume()
        return
    end
    if not state.plan then
        return
    end
```

`finish` and `tryResume` must both be defined above `Dash.Tick`, and `finish`
above `tryResume`. Move them if they are not.

- [ ] **Step 4: Resuming at login**

In `GoblinPS/Core.lua`, add after `Core.ClearTrip`:

```lua
-- On login: carry on with this character's saved trip. The destination is
-- looked up again by name; if a patch renamed it, drop the trip and say so --
-- never silently.
function Core.ResumeTrip()
    local name = Core.SavedTripName()
    if not name then
        return
    end
    local place = Search.Exact(ns.Data, name, API.Faction())
    if not place then
        Core.ClearTrip()
        say(("Couldn't resume your trip to %s: that place isn't in GoblinPS's data any more."):format(name))
        return
    end
    ns.Dash.Resume(place)
end
```

and call it from the existing login hook:

```lua
API.OnLogin(function()
    ns.MinimapButton.Initialize()
    Core.ResumeTrip()
end)
```

`API.OnLogin` fires on `PLAYER_LOGIN`, after saved variables load, which is
the moment `GoblinPSDB` holds the saved trip.

- [ ] **Step 5: The planner, opened mid-trip**

In `GoblinPS/Planner.lua`'s `Planner.Toggle`, in the branch that shows the
window, before `replan()`:

```lua
        -- Opened mid-trip with nothing of its own picked: show where the trip
        -- is going, so the planner knows where you're at.
        if not state.to then
            local trip = ns.Dash.Destination()
            if trip then
                state.to = trip
                ui.toBox:SetText(trip.name)
                W.UpdatePlaceholder(ui.toBox)
            end
        end
```

- [ ] **Step 6: Version**

Set `## Version: 2026.09.21.4` in `GoblinPS/GoblinPS.toc`.

- [ ] **Step 7: Run the tests to verify they pass**

Run the Lua suite. Expected: green, 306 passed; every existing test still
passing.

- [ ] **Step 8: Lint**

Run luacheck and the language server from PowerShell. Expected: zero warnings.

- [ ] **Step 9: Commit**

```bash
git add GoblinPS/Dash.lua GoblinPS/Core.lua GoblinPS/Planner.lua GoblinPS/GoblinPS.toc test/test_ui.lua
git commit -m "Resume a trip after a reload or a logout" -m "At login the saved destination is looked up again by name and the dash replans from wherever the player stands, as soon as the client can say where that is. At the destination it shows Arrived. A destination a patch renamed is dropped with a chat line, never silently. The planner, opened mid-trip, shows where the trip is going." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Documents

**Files:**
- Modify: `docs/manual-test-checklist.md`
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`

- [ ] **Step 1: The checklist**

Add a section to `docs/manual-test-checklist.md`, above
`## Flight paths survive a reload`:

```
## A trip survives everything except Stop (plan 7)

Built 2026-09-21; not yet run in the client. The dash used to end its trip
whenever it was hidden, so pressing Escape -- which players do constantly --
killed the route, and a reload or logout always lost it.

- [ ] With a trip running, press Escape: the dash stays up and keeps going
- [ ] Alt+Z twice: the interface hides and comes back, and the trip carries on
- [ ] `/reload` mid-trip: the dash comes back, replans from where you stand,
      and puts the map pin on the first step
- [ ] Log out and back in mid-trip: the same
- [ ] Press Stop: the dash goes, the map pin clears, and a `/reload` brings
      nothing back
- [ ] Arrive: the dash says "Arrived." and stays up until Stop; the map pin
      at the destination clears
- [ ] Drop your own map pin mid-trip, then arrive or press Stop: your pin is
      still there
- [ ] Open `/gps` mid-trip: the search box shows the trip's destination
- [ ] Log in a second character: no trip comes back for it
```

Search the checklist for any line that says Escape ends a trip or closes the
dash, and correct it to the new rule.

- [ ] **Step 2: CLAUDE.md**

Update the status paragraph: plan 7 built, a trip ends only on Stop and
survives a reload, **not yet run in the client**; next is plan 8, the planner
rebuilt to the mockup. Keep the existing hard line: do not write that plan 7
has run in the client.

Add to "Rules that are easy to break":

```
- **Only Stop ends a trip.** Escape, hiding the interface, arriving and a
  reload must never end it or clear its save. The dash is not on
  `UISpecialFrames`, its `OnHide` does nothing to the trip, and `Dash.Stop` is
  the one place the saved trip (`GoblinPSDB.trips["Name-Realm"]`) and the map
  pin are cleared. It clears only a pin GoblinPS set: a waypoint the player
  dropped mid-trip is theirs.
```

- [ ] **Step 3: The spec**

At the top of plan 7's section in
`docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`, add one
line: `Built 2026-09-21 -- not yet run in the client.`

- [ ] **Step 4: Commit**

```bash
git add docs/ CLAUDE.md
git commit -m "Docs: a trip survives everything except Stop" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Notes for the reviewer

- **Only Stop ends a trip.** Look for any path -- `OnHide`, Escape, arrival,
  a failed replan, a failed resume -- that clears `state.plan`'s saved trip or
  calls `Core.ClearTrip` other than `Dash.Stop`. Arrival and a no-route resume
  may leave the dash with nothing to do; neither may clear the save.
- **Only our pin.** `Core.ClearPin` must compare before clearing, and forget
  `lastPin` afterwards. A test pins each half.
- **Every client call through `API.lua`.** `C_Map` must not appear in
  `Dash.lua` or `Core.lua`.
- **Ordering in `test_ui.lua`.** New tests restore the position, the dash, the
  saved trips and the pin. A test that passes alone and fails in the suite, or
  the reverse, is an ordering leak.
- **The rewritten Escape test** keeps its original concern -- a hidden trip
  must not move on unseen -- as its own assertion. Check that survived.

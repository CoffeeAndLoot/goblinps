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


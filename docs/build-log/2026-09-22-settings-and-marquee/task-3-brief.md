### Task 3: the arrival radii, from the save to `Trip.Check`

**Files:**
- Modify: `GoblinPS/Prefs.lua` (header comment, constants, `Prefs.Init`, three new functions)
- Modify: `GoblinPS/Trip.lua:12-26` (`Trip.Check`)
- Modify: `GoblinPS/Core.lua:51-52` (four accessors)
- Modify: `GoblinPS/Dash.lua` (`Dash.Tick` hands the radii to `Trip.Check`)
- Modify: `test/test_prefs.lua`, `test/test_trip.lua`, `test/test_ui.lua`

**Interfaces:**
- Consumes: `ns.Trip.ARRIVE` (= `{ ride = 40, fly = 150, zeppelin = 800,
  boat = 800, tram = 800, hearth = 300 }`), loaded before `Prefs.lua` in the
  TOC and in both test loaders.
- Produces, for Task 4:
  - `Prefs.HEARTH_MINUTES = { min = 0, max = 30, step = 1 }`
  - `Prefs.ARRIVE[key] = { default, min, max, step, kinds }` for
    `key` in `ride`, `fly`, `transport`, `hearth`
  - `Prefs.Step(value, range, direction)` -> number, `direction` is 1 or -1
  - `Prefs.Reset(db)`, `Prefs.ArriveRadii(db)` -> `{ [tripKind] = yards }`
  - `db.arrive = { ride, fly, transport, hearth }` (yards), always valid after `Prefs.Init`
  - `Core.Arrive(key)` -> yards, `Core.SetArrive(key, yards)`,
    `Core.ArriveRadii()` -> `{ [tripKind] = yards }`, `Core.ResetSettings()`
  - `Trip.Check(step, state)` reads `state.arrive[step.kind]` when given.

- [ ] **Step 1: Write the failing tests**

In `test/test_trip.lua`, inside `h.describe("Trip.Check", ...)`, after
"advances a boat that docked":

```lua
        h.it("judges arrival by the radius it is handed", function()
            local ride = { kind = "ride", to = target }
            local pos = at(1000, 8970) -- 30 yards out
            h.eq(Trip.Check(ride, { pos = pos, event = "tick", arrive = { ride = 20 } }), "stay")
            h.eq(Trip.Check(ride, { pos = pos, event = "tick", arrive = { ride = 40 } }), "advance")
        end)
        h.it("falls back to Trip.ARRIVE for a kind it is not handed", function()
            local boat = { kind = "boat", to = target }
            local pos = at(1500, 9000) -- 500 yards out
            h.eq(Trip.Check(boat, { pos = pos, event = "zone", arrive = { ride = 20 } }), "advance",
                 "800 yards by default")
            h.eq(Trip.Check(boat, { pos = pos, event = "zone", arrive = { boat = 300 } }), "stay")
        end)
```

In `test/test_prefs.lua`, directly before the final `end`:

```lua
    h.describe("the arrival radii", function()
        local ARRIVE = loaded.ns.Trip.ARRIVE
        h.it("default to Trip's own radii", function()
            local db = Prefs.Init(nil)
            h.eq(db.arrive.ride, ARRIVE.ride)
            h.eq(db.arrive.fly, ARRIVE.fly)
            h.eq(db.arrive.transport, ARRIVE.zeppelin)
            h.eq(db.arrive.hearth, ARRIVE.hearth)
            for key, range in pairs(Prefs.ARRIVE) do
                for _, kind in ipairs(range.kinds) do
                    h.eq(range.default, ARRIVE[kind], key .. " covers " .. kind .. " at Trip's radius")
                end
            end
        end)
        h.it("keep an in-range value the player chose", function()
            local db = Prefs.Init({ arrive = { ride = 20, transport = 100 } })
            h.eq(db.arrive.ride, 20)
            h.eq(db.arrive.transport, 100, "the floor itself is allowed")
            h.eq(db.arrive.fly, 150, "a missing one is filled in")
        end)
        h.it("repair hostile and out-of-range values", function()
            local db = Prefs.Init({ arrive = { ride = "near", fly = 5, transport = 5000, hearth = 0 / 0 } })
            h.eq(db.arrive.ride, 40, "not a number")
            h.eq(db.arrive.fly, 150, "under the floor")
            h.eq(db.arrive.transport, 800, "over the ceiling")
            h.eq(db.arrive.hearth, 300, "NaN")
            h.eq(Prefs.Init({ arrive = "junk" }).arrive.ride, 40, "a hostile table is replaced")
        end)
        h.it("fan the one transport value out to zeppelin, boat and tram", function()
            local db = Prefs.Init({ arrive = { transport = 300 } })
            local radii = Prefs.ArriveRadii(db)
            h.eq(radii.zeppelin, 300)
            h.eq(radii.boat, 300)
            h.eq(radii.tram, 300)
            h.eq(radii.ride, 40)
            h.eq(radii.fly, 150)
            h.eq(radii.hearth, 300)
        end)
        h.it("Reset puts the hearthstone and every radius back", function()
            local db = Prefs.Init({ hearthSaving = 0,
                                    arrive = { ride = 20, fly = 50, transport = 100, hearth = 1000 } })
            Prefs.Reset(db)
            h.eq(db.hearthSaving, Prefs.HEARTH_SAVING_DEFAULT)
            for key, range in pairs(Prefs.ARRIVE) do
                h.eq(db.arrive[key], range.default, key)
            end
        end)
    end)

    h.describe("Prefs.Step", function()
        h.it("moves by the range's step and clamps at both ends", function()
            local ride = Prefs.ARRIVE.ride
            h.eq(Prefs.Step(40, ride, 1), 50)
            h.eq(Prefs.Step(40, ride, -1), 30)
            h.eq(Prefs.Step(200, ride, 1), 200, "the ceiling")
            h.eq(Prefs.Step(10, ride, -1), 10, "the floor")
            h.eq(Prefs.Step(45, Prefs.HEARTH_MINUTES, -1), 30, "a value /gps hearth set above the range comes in")
            h.eq(Prefs.Step(nil, ride, -1), 10, "a value it cannot read starts from the floor")
        end)
    end)
```

In `test/test_ui.lua`, inside `h.describe("the dash unit drives the trip", ...)`,
after "advances when you reach the step's target":

```lua
            h.it("judges arrival by the player's own radius", function()
                ns.Core.SetArrive("ride", 20)
                Dash.Start(plan)
                local _, state = Dash.Debug()
                standAt(30, 0)
                Dash.Tick("tick")
                h.eq(state.index, 1, "30 yards out is not there at 20")
                ns.Core.SetArrive("ride", 40)
                Dash.Tick("tick")
                h.eq(state.index, 2, "and is at 40")
                ns.Core.ResetSettings()
                h.eq(ns.Core.Arrive("ride"), 40)
            end)
```

- [ ] **Step 2: Run the Lua gate to see them fail**

Expected: the Trip test "judges arrival by the radius it is handed" fails
(the default 40 advances at 30 yards); the Prefs tests fail on
`db.arrive` / `Prefs.ARRIVE` being nil; the UI test fails on
`ns.Core.SetArrive` being nil. "falls back to Trip.ARRIVE" passes already.

- [ ] **Step 3: `GoblinPS/Trip.lua`**

Replace the state comment and the arrival line of `Trip.Check`:

```lua
-- state: pos = { c, x, y } or nil (instances); onTaxi = bool; event =
-- "tick" | "landed" | "zone"; best = closest the player has been to the
-- step's target so far, tracked by the caller; arrive = { [kind] = yards },
-- the player's own radii (Prefs.ArriveRadii), or nil for Trip.ARRIVE's.
-- Returns "advance", "recalculate", "stay" or "pause".
function Trip.Check(step, state)
    if not state.pos then
        return "pause"
    end
    if state.onTaxi then
        return "stay"
    end
    local d = ns.Geo.Distance(state.pos, step.to)
    local radius = state.arrive and state.arrive[step.kind] or Trip.ARRIVE[step.kind]
    if d <= radius then
        return "advance"
    end
```

(the rest of the function is unchanged). Change the comment above
`Trip.ARRIVE` to: `-- Yards from a step's target that count as "arrived", unless the player
-- chose their own (Prefs.ARRIVE takes its defaults from here).`

- [ ] **Step 4: `GoblinPS/Prefs.lua`**

In the header comment, after the `trips` paragraph, add:

```lua
-- `arrive`: the player's arrival radii in yards, { ride, fly, transport,
-- hearth }, set from the settings panel and repaired here.
```

After `Prefs.HEARTH_SAVING_DEFAULT = 300   -- five minutes`, add:

```lua
-- The settings panel's hearthstone row, in whole minutes. `/gps hearth` takes
-- any number of minutes; only the panel's buttons keep to this range.
Prefs.HEARTH_MINUTES = { min = 0, max = 30, step = 1 }

-- How close counts as arriving, per setting, in yards. The defaults are
-- Trip.ARRIVE's own, so the rule and the panel cannot disagree; `kinds` is
-- the Trip step kinds each setting covers. One value serves boat, zeppelin
-- and tram: all three arrive when you step off at a dock. Its floor is 100
-- yards because several dock coordinates are still estimates, and a radius
-- tighter than the error in the data would never let a trip advance. The
-- 800-yard default stays until a dock is measured in game.
local ARRIVE = ns.Trip.ARRIVE
Prefs.ARRIVE = {
    ride      = { default = ARRIVE.ride, min = 10, max = 200, step = 10, kinds = { "ride" } },
    fly       = { default = ARRIVE.fly, min = 50, max = 500, step = 25, kinds = { "fly" } },
    transport = { default = ARRIVE.zeppelin, min = 100, max = 1000, step = 50,
                  kinds = { "zeppelin", "boat", "tram" } },
    hearth    = { default = ARRIVE.hearth, min = 100, max = 1000, step = 50, kinds = { "hearth" } },
}
```

In `Prefs.Init`, directly before `return db`:

```lua
    -- Arrival radii. A hostile, missing or out-of-range value (NaN included:
    -- it is the one number unequal to itself) falls back to its default. The
    -- panel can only set values inside the range, so one outside it was
    -- never the player's choice.
    db.arrive = type(db.arrive) == "table" and db.arrive or {}
    for key, range in pairs(Prefs.ARRIVE) do
        local v = db.arrive[key]
        if type(v) ~= "number" or v ~= v or v < range.min or v > range.max then
            db.arrive[key] = range.default
        end
    end
```

After `Prefs.Init`, add:

```lua
-- One press of a settings button: `value` moved one step up (direction 1) or
-- down (-1), clamped into the range. A value it cannot read starts from the
-- floor.
function Prefs.Step(value, range, direction)
    local v = (type(value) == "number" and value or range.min) + direction * range.step
    return math.max(range.min, math.min(range.max, v))
end

-- Reset to defaults: the hearthstone's saving and every arrival radius.
function Prefs.Reset(db)
    db.hearthSaving = Prefs.HEARTH_SAVING_DEFAULT
    db.arrive = {}
    for key, range in pairs(Prefs.ARRIVE) do
        db.arrive[key] = range.default
    end
end

-- The radii by Trip step kind, for Trip.Check: each setting fanned out to
-- the kinds it covers.
function Prefs.ArriveRadii(db)
    local out = {}
    for key, range in pairs(Prefs.ARRIVE) do
        for _, kind in ipairs(range.kinds) do
            out[kind] = db.arrive[key]
        end
    end
    return out
end
```

- [ ] **Step 5: `GoblinPS/Core.lua`**

After `function Core.SetHearthSaving(seconds) prefs().hearthSaving = seconds end`, add:

```lua
function Core.Arrive(key) return prefs().arrive[key] end
function Core.SetArrive(key, yards) prefs().arrive[key] = yards end
-- The player's radii by Trip step kind; the dash hands this to Trip.Check.
function Core.ArriveRadii() return Prefs.ArriveRadii(prefs()) end
function Core.ResetSettings() Prefs.Reset(prefs()) end
```

- [ ] **Step 6: `GoblinPS/Dash.lua`**

In `Dash.Tick`, the `Trip.Check` call becomes:

```lua
    local verdict = ns.Trip.Check(step, {
        pos = pos, onTaxi = ns.API.OnTaxi(), event = event, best = state.best,
        arrive = ns.Core.ArriveRadii(),
    })
```

- [ ] **Step 7: Run every gate**

Lua: expected `373 passed, 0 failed` (364 + 2 Trip + 6 Prefs + 1 UI). Python
and art green. luacheck and the language server from PowerShell: zero warnings.

- [ ] **Step 8: Commit**

```
git add GoblinPS/Prefs.lua GoblinPS/Trip.lua GoblinPS/Core.lua GoblinPS/Dash.lua test/test_prefs.lua test/test_trip.lua test/test_ui.lua
git commit -m "Arrival radii: saved, repaired, and read by Trip.Check" -m "GoblinPSDB.arrive holds ride, fly, transport and hearth radii with ranges and Trip.ARRIVE's defaults; Prefs.Init repairs hostile values, Prefs.Step clamps a button press, and the dash hands Trip.Check the player's radii with transport fanned out to zeppelin, boat and tram. Trip stays pure and falls back to its own." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---


### Task 5: Making it drive

**Files:**
- Modify: `GoblinPS/Dash.lua`
- Modify: `GoblinPS/Core.lua`
- Modify: `GoblinPS/Planner.lua`
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `Trip.Check`, `Trip.Bearing`, `Trip.ArrowAngle`, `Trip.DistanceTo`, `Trip.Remaining` (task 2); `API.PlayerFacing`, `API.OnTaxi`, `API.OnTripEvent`, `Core.Here` (task 3); `Dash.Start`, `Dash.Stop`, `Dash.Refresh` (task 4).
- Produces: `Dash.Tick(event)`, called by the frame's own OnUpdate and by trip events. Pressing GO closes the planner and opens the dash.

The rules, all of which `Trip.Check` already decides:

- **advance** moves to the next step; on the last step the journey is over: say "Arrived" and stop.
- **recalculate** replans from where the player now stands and starts again at step 1.
- **pause** means the client will not say where the player is, usually an instance. Say "Waiting..." and change nothing.
- **stay** redraws distance, time left and the arrow.

Two things `Trip.Check` needs that only the caller can keep: `state.best`, the closest the player has been to this step's target, which is how straying is noticed; and whether the player is on a taxi.

Ticking every frame is wasteful and jittery. Tick on a timer of `Dash.TICK` seconds, and immediately on a trip event.

- [ ] **Step 1: Write the failing tests**

Append to `test/test_ui.lua`, beside the dash tests from task 4.

`test/test_ui.lua` already scripts where the player stands: its `where` table
feeds `PlayerMapPosition`, which `Core.Here` reads through. Use that rather
than inventing a new seam, and add two locals beside `level` for the facts
task 3 introduced:

```lua
    local facing, onTaxi = 0, false
```

wired into the scripted `ns.API` as:

```lua
        PlayerFacing = function() return facing end,
        OnTaxi = function() return onTaxi end,
        OnTripEvent = function(callback) tripCallbacks[#tripCallbacks + 1] = callback end,
```

The fake world's maps are 10000 yards square, with `world x = 10000 - my * 10000`
and `world y = 10000 - mx * 10000`. A helper keeps that arithmetic out of every
test, and keeps `Core.Here` and `Geo.ToWorld` in the path being exercised:

```lua
    -- Stand the player at a world position on map 1.
    local function standAt(x, y)
        where.map, where.mx, where.my = 1, (10000 - y) / 10000, (10000 - x) / 10000
    end
```

The steps in `plan` all target world `(0, 0)` on continent 1, so `standAt(0, 0)`
is "arrived" and larger values are further away.

```lua
    h.describe("the dash unit drives the trip", function()
        h.it("advances when you reach the step's target", function()
            Dash.Start(plan)
            local ui, state = Dash.Debug()
            standAt(5000, 0); facing = 0
            Dash.Tick("tick")
            h.eq(state.index, 1, "still on the way")
            standAt(10, 0)
            Dash.Tick("tick")
            h.eq(state.index, 2, "arriving moves on")
            h.eq(ui.step:GetText(), "Zeppelin to East Dock")
        end)

        h.it("moves Blizzard's pin onto each new step, not just the first", function()
            Dash.Start(plan)
            local _, state = Dash.Debug()
            local before = #pins
            standAt(10, 0)
            Dash.Tick("tick")
            h.eq(state.index, 2)
            h.truthy(#pins > before, "the spec puts the pin on the step you are on")
        end)

        h.it("says Arrived and stops at the end", function()
            Dash.Start(plan)
            local ui, state = Dash.Debug()
            state.index = #plan.result.steps
            standAt(0, 0)
            Dash.Tick("tick")
            h.eq(ui.step:GetText(), "Arrived.")
            h.falsy(state.plan, "the trip is over")
        end)

        h.it("shows the distance and the time left while travelling", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            standAt(700, 0)
            Dash.Tick("tick")
            h.eq(ui.distance:GetText(), "700 yd")
            h.truthy(ui.eta:GetText():find("min", 1, true), ui.eta:GetText())
        end)

        h.it("turns the arrow toward the step and hides it when facing is unknown", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            standAt(-100, 0); facing = 0
            Dash.Tick("tick")
            h.truthy(ui.arrow:IsShown())
            h.eq(ui.arrow.rotation, 0, "the target is due north of us and we face north")
            facing = nil
            Dash.Tick("tick")
            h.falsy(ui.arrow:IsShown(), "never point somewhere we cannot work out")
            facing = 0
        end)

        h.it("does not advance or stray while on a zeppelin", function()
            Dash.Start(plan)
            local _, state = Dash.Debug()
            state.index = 2
            onTaxi = true
            standAt(0, 0)
            Dash.Tick("tick")
            h.eq(state.index, 2, "aboard, arriving at the target means nothing")
            onTaxi = false
        end)

        h.it("waits, without losing the trip, when the client will not place you", function()
            Dash.Start(plan)
            local ui, state = Dash.Debug()
            where.map = nil
            Dash.Tick("tick")
            h.eq(ui.distance:GetText(), "Waiting...")
            h.truthy(state.plan, "an instance must not end the trip")
            where.map, where.mx, where.my = 1, 0.89, 0.9
        end)

        h.it("does nothing at all when no trip is running", function()
            Dash.Stop()
            standAt(10, 0)
            Dash.Tick("tick")           -- must not error
            h.falsy(Dash.Debug().frame:IsShown())
        end)
    end)
```

Leave `where` as the other tests expect it when your block finishes; the suite
shares one planner and runs in order.

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: FAIL, `Dash.Tick` is nil.

- [ ] **Step 3: Implement the tick**

In `GoblinPS/Dash.lua`, add above `Dash.Debug`:

```lua
Dash.TICK = 0.5        -- seconds between checks; every frame is jitter, not accuracy

local function yards(d)
    return ("%d yd"):format(math.floor(d + 0.5))
end

-- Point the arrow at the current step, or hide it. The client can decline to
-- say which way the player faces, and an arrow pointing the wrong way is worse
-- than no arrow at all.
local function aimArrow(pos, step)
    local angle = ns.Trip.ArrowAngle(ns.Trip.Bearing(pos, step.to), ns.API.PlayerFacing())
    if not angle then
        ui.arrow:Hide()
        return
    end
    ui.arrow:SetRotation(angle)
    ui.arrow:Show()
end

local function finish()
    ui.step:SetText("Arrived.")
    ui.next:SetText("")
    ui.distance:SetText("")
    ui.eta:SetText("")
    ui.arrow:Hide()
    state.plan, state.index, state.best = nil, nil, nil
end

-- One look at where the player is against the step they are on. `event` is
-- "tick", "zone" or "landed" and is handed straight to Trip.Check.
function Dash.Tick(event)
    if not ui or not state.plan then
        return
    end
    local steps = state.plan.result.steps
    local step = steps[state.index]
    if not step then
        return
    end
    local pos = ns.Core.Here()
    local verdict = ns.Trip.Check(step, {
        pos = pos, onTaxi = ns.API.OnTaxi(), event = event, best = state.best,
    })

    if verdict == "pause" then
        ui.distance:SetText("Waiting...")
        ui.eta:SetText("")
        ui.arrow:Hide()
        return
    end
    if verdict == "advance" then
        if state.index >= #steps then
            finish()
            return
        end
        state.index, state.best = state.index + 1, nil
        Dash.Refresh()
        ns.Core.PinStep(steps[state.index])   -- the pin follows the step you are on
        return
    end
    if verdict == "recalculate" then
        local replanned = ns.Core.PlanRoute(state.plan.to, pos)
        if replanned.result and #replanned.result.steps > 0 then
            state.plan, state.index, state.best = replanned, 1, nil
            ui.next:SetText("Recalculating...")
            Dash.Refresh()
        end
        return
    end

    local d = ns.Trip.DistanceTo(pos, step)
    if d then
        state.best = math.min(state.best or d, d)
        ui.distance:SetText(yards(d))
        aimArrow(pos, step)
    else
        ui.distance:SetText("")
        ui.arrow:Hide()
    end
    local travel = ns.Travel.For(state.plan.level)
    local left = ns.Trip.Remaining(state.plan.result, state.index, pos, travel.speed)
    ui.eta:SetText(left and ns.Route.FormatTime(left) or "")
end
```

In `build()`, after the frame is made, drive it:

```lua
    local since = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        since = since + elapsed
        if since >= Dash.TICK then
            since = 0
            Dash.Tick("tick")
        end
    end)
    ns.API.OnTripEvent(function(kind) Dash.Tick(kind) end)
```

Register the trip event **once**, inside `build()`, not on every `Start`.

In `GoblinPS/Core.lua`, make GO start a trip. Replace the body of `Core.Go`:

```lua
-- Blizzard's map pin and on-screen arrow for one step. Spec decision 3 puts
-- the pin on the step you are ON, so the dash calls this again each time it
-- advances, not only when GO is pressed. Quiet: only GO explains itself.
function Core.PinStep(step)
    if not step or step.kind == "hearth" or not step.to.map then
        return false
    end
    return API.SetWaypoint(step.to.map, step.to.mx, step.to.my) and true or false
end

-- Go: pin the first step, say what happened, and hand the plan to the dash
-- unit, which takes over from here.
function Core.Go(plan)
    local step = plan and plan.result and plan.result.steps[1]
    if not step then
        return
    end
    if step.kind == "hearth" then
        say("Use your hearthstone, then press GO again.")
    elseif Core.PinStep(step) then
        say("Pin set: " .. Route.StepText(step) .. ".")
    else
        say("Can't put a map pin there. " .. Route.StepText(step) .. ".")
    end
    ns.Dash.Start(plan)
end
```

In `GoblinPS/Planner.lua`, close the planner when GO starts the trip. In the GO button's handler, after `ns.Core.Go(state.plan)`:

```lua
        if ui.frame:IsShown() and state.plan and state.plan.result
           and #state.plan.result.steps > 0 then
            ui.frame:Hide()
        end
```

The Garmin model: plan the route, then drive. `/gps` reopens the planner without ending the trip.

- [ ] **Step 4: Run to verify they pass**

Run the Lua suite. Expected: green.

- [ ] **Step 5: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 6: Commit**

```bash
git add GoblinPS/Dash.lua GoblinPS/Core.lua GoblinPS/Planner.lua test/
git commit -m "Dash unit: advance, recalculate and arrive" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---


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


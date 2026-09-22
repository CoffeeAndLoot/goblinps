### Task 5: saying so -- the amber detail line and the hostile-destination note

**Files:**
- Modify: `GoblinPS/Route.lua` (`passes` and `Route.HostileNote` before
  `levels`, line 210; `Route.StepDetail`, lines 217-259)
- Modify: `GoblinPS/Core.lua` (`Core.PlanRoute`, lines 115-131)
- Modify: `GoblinPS/Planner.lua` (`Planner.Refresh`, lines 228-231)
- Test: `test/test_route.lua`, `test/test_strip.lua`, `test/test_ui.lua`,
  `test/test_crossings.lua` (one expectation)

**Interfaces:**
- Consumes: `step.danger = { name, f }` (Task 4), `Graph.HostileAt` (Task 4),
  `step.to.stopover` (Task 4).
- Produces:
  - `Route.StepDetail(data, step, level)`: a ride step with `danger` returns
    `"<in|into zone> · passes <name> (<Alliance|Horde>)"` plus any hazard and
    unconfirmed note after it, and `warn = true`; the level range is left
    out. A rough step with `danger` returns `"passes <name> (<faction>)", true`.
    An unconfirmed stopover says "stopover not confirmed".
  - `Route.HostileNote(place) -> "<name> is an Alliance town: its guards will
    attack you."` (or "a Horde town").
  - `Core.PlanRoute(to, from)`'s plan gains `hostile` (that note, or nil),
    and the note is also `plan.notes[1]`.
  - `Planner.Refresh` shows `plan.hostile` on the warning line before
    anything else. `Strip.Layout` is unchanged: it already turns an amber
    detail into the tooltip's third line and the first one into
    `layout.warning`.

- [ ] **Step 1: Write the failing Route tests**

Insert into `test/test_route.lua` directly after the end of "says only the
crossing is unconfirmed when it carries no hazard":

```lua
            h.eq(text, "into Eastland · crossing not confirmed")
            h.eq(warn, true)
        end)
```

this block:

```lua
        h.it("names the enemy town a leg passes, in amber, in place of the level range", function()
            local step = { kind = "ride", zone = 1, to = { name = "Bravo, Westland" },
                           danger = { name = "Keep", f = "A" } }
            local text, warn = Route.StepDetail(world, step, 60)
            h.eq(text, "in Westland · passes Keep (Alliance)")
            h.eq(warn, true)
            step.danger.f = "H"
            h.eq((Route.StepDetail(world, step, 60)), "in Westland · passes Keep (Horde)")
        end)
        h.it("says so even on a step that arrives at the zone itself, and before a crossing's hazard", function()
            local keep = { name = "Keep", f = "A" }
            h.eq((Route.StepDetail(world, { kind = "ride", zone = 1, to = { name = "Westland" }, danger = keep }, 60)),
                 "in Westland · passes Keep (Alliance)")
            local gate = { name = "the test gate", zones = { 1, 2 }, warn = "trolls on the bridge" }
            h.eq((Route.StepDetail(world, { kind = "ride", zone = 1, to = gate, danger = keep }, 60)),
                 "into Eastland · passes Keep (Alliance) · trolls on the bridge")
        end)
        h.it("names the town a rough straight line passes, having no zone to name", function()
            local step = { kind = "ride", rough = true, to = { name = "Lostland" },
                           danger = { name = "Keep", f = "H" } }
            local text, warn = Route.StepDetail(world, step, 5)
            h.eq(text, "passes Keep (Horde)")
            h.eq(warn, true)
        end)
        h.it("says a stopover, not a crossing, is unconfirmed", function()
            local stop = { name = "the north road", map = 1, stopover = true, unverified = true }
            local text, warn = Route.StepDetail(world, { kind = "ride", zone = 1, to = stop }, 60)
            h.eq(text, "in Westland · stopover not confirmed")
            h.eq(warn, true)
        end)
```

Insert into `test/test_route.lua` directly before

```lua
    h.describe("Route text", function()
```

this block:

```lua
    h.describe("Route.HostileNote", function()
        h.it("warns of a destination whose guards will attack, with the right article", function()
            h.eq(Route.HostileNote({ name = "Silverwind Refuge", f = "A" }),
                 "Silverwind Refuge is an Alliance town: its guards will attack you.")
            h.eq(Route.HostileNote({ name = "Splintertree Post", f = "H" }),
                 "Splintertree Post is a Horde town: its guards will attack you.")
        end)
    end)
```

- [ ] **Step 2: Write the failing Strip test**

Insert into `test/test_strip.lua` directly before

```lua
        h.it("wears the walk or ride badge through a tunnel, and says through in the tooltip", function()
```

this block:

```lua
        h.it("turns the enemy town a leg passes amber and names it as the warning", function()
            local leg = step("ride", "Splintertree Post, Ashenvale",
                             { zone = 1, danger = { name = "Silverwind Refuge", f = "A" } })
            local layout = Strip.Layout(data, { leg }, OPTS)
            local detail = layout.stops[2].tooltip[3]
            h.eq(detail.text, "in Westland · passes Silverwind Refuge (Alliance)")
            h.eq(detail.amber, true)
            h.eq(layout.warning, "Splintertree Post: in Westland · passes Silverwind Refuge (Alliance)")
        end)
```

- [ ] **Step 3: Write the failing planner and chat tests**

In `test/test_ui.lua`, insert directly after the end of "draws no strip
without a route":

```lua
            h.truthy(ui.notes:IsShown())
            pickTo("delt")
            h.truthy(ui.strip:IsShown())
        end)
```

a blank line and this block:

```lua
        h.it("warns under the strip, before anything else, when the destination is an enemy town", function()
            -- Echo is an Alliance flight master and the fake player is Horde.
            -- Westland is made a 70-80 zone for the test, so the route's own
            -- steps are amber too and the note has to win the line.
            local savedZone = ns.Data.Zones[1]
            ns.Data.Zones[1] = { 70, 80 }
            local ok, err = pcall(function()
                local ui = pickTo("echo")
                local _, state = Planner.Debug()
                local note = "Echo is an Alliance town: its guards will attack you."
                h.eq(state.plan.hostile, note)
                h.eq(state.plan.notes[1], note, "and first among the notes, for /gps to")
                h.truthy(ui.strip:IsShown(), "it is still a route")
                h.eq(ui.hint:GetText(), note)
            end)
            ns.Data.Zones[1] = savedZone -- put the fixture back even when an assertion failed
            local ui = pickTo("delt")
            local _, state = Planner.Debug()
            h.truthy(ok, err)
            h.eq(state.plan.hostile, nil, "Delta is nobody's enemy")
            h.falsy(ui.hint:GetText():find("guards", 1, true))
        end)
```

The fixture is put back before any assertion outside the `pcall` runs, so a
failure here cannot leak Westland's 70-80 range into the `/gps probe zones`
tests after it.

In `test/test_ui.lua`, insert directly after the end of "takes a zone's name
to the first place in it, all the way there":

```lua
            h.truthy(saw, "the route goes on past the East Dock to Delta")
        end)
```

this block:

```lua
        h.it("says first when the destination is an enemy town", function()
            local from = #printed
            SlashCmdList.GOBLINPS("to echo")
            h.truthy(printed[from + 1]:find("Echo is an Alliance town: its guards will attack you.", 1, true),
                     printed[from + 1])
            h.truthy(printed[from + 2]:find("To Echo: ", 1, true), printed[from + 2])
        end)
```

- [ ] **Step 4: Update the one real route whose detail line changes**

In `test/test_crossings.lua`, in "explains each ground step and warns a
low-level character", replace

```lua
            h.eq(text, "into Winterspring · Timbermaw furbolgs attack without reputation")
```

with

```lua
            -- The line from the Ashenvale-Felwood road to the tunnels runs past
            -- Talonbranch Glade, an Alliance flight master, and there is no way
            -- round it: the town comes first, so the hazard is what gets cut.
            h.eq(text, "into Winterspring · passes Talonbranch Glade (Alliance) · Timbermaw furbolgs attack without "
                 .. "reputation")
```

- [ ] **Step 5: Run the Lua gate to see them fail**

Expected: `496 passed, 9 failed`: the four new `Route.StepDetail` tests
(the danger is not worded yet, and the stopover still says "crossing not
confirmed"), `Route.HostileNote` (`attempt to call field 'HostileNote'`),
the new Strip test, "explains each ground step and warns a low-level
character", "warns under the strip, before anything else, when the
destination is an enemy town" and "says first when the destination is an
enemy town". Nothing else fails.

- [ ] **Step 6: `GoblinPS/Route.lua`, the words**

Insert directly before

```lua
local function levels(range)
```

this block:

```lua
local FACTION = { A = "Alliance", H = "Horde" }

-- "passes Silverwind Refuge (Alliance)"
local function passes(danger)
    return "passes " .. danger.name .. " (" .. FACTION[danger.f] .. ")"
end

-- The plan note for a destination inside an enemy town's circle (Graph.HostileAt).
function Route.HostileNote(place)
    return ("%s is %s %s town: its guards will attack you."):format(
        place.name, place.f == "A" and "an" or "a", FACTION[place.f])
end
```

Replace the head of `Route.StepDetail` and its comment,

```lua
-- character's level, the crossing carries a hazard note, or it is
-- unconfirmed. Other step kinds have no detail ("", false). A hazard or an
-- unconfirmed note replaces the level range on the line (never both: the
-- line does not wrap, and the hazard is the part that must not be cut off).
function Route.StepDetail(data, step, level)
    if WAITS[step.kind] then
        return "includes the average wait", false
    end
    if step.kind ~= "ride" or not step.zone then
        return "", false
    end
```

with

```lua
-- character's level, the leg passes an enemy town, the crossing carries a
-- hazard note, or it is unconfirmed. Other step kinds have no detail ("",
-- false). An enemy town, a hazard or an unconfirmed note replaces the level
-- range on the line (never both: the line does not wrap, and the warning is
-- the part that must not be cut off), the enemy town first.
function Route.StepDetail(data, step, level)
    if WAITS[step.kind] then
        return "includes the average wait", false
    end
    if step.kind ~= "ride" then
        return "", false
    end
    if not step.zone then
        -- A rough straight line has no zone to name, but may still pass a town.
        if step.danger then
            return passes(step.danger), true
        end
        return "", false
    end
```

Replace the rest of `Route.StepDetail`,

```lua
        if places[zone] and ns.Search.ShortName(step.to.name) == places[zone].name then
            return "", false
        end
    end
    local warn = ns.Travel.Dangerous(zones[zone], level)
    if step.to.warn or step.to.unverified then
        warn = true
    else
        text = text .. levels(zones[zone])
    end
    if step.to.warn then
        text = text .. " · " .. step.to.warn
    end
    if step.to.unverified then
        text = text .. " · crossing not confirmed"
    end
    return text, warn
end
```

with

```lua
        if places[zone] and ns.Search.ShortName(step.to.name) == places[zone].name and not step.danger then
            return "", false
        end
    end
    local warn = ns.Travel.Dangerous(zones[zone], level)
    if step.danger or step.to.warn or step.to.unverified then
        warn = true
    else
        text = text .. levels(zones[zone])
    end
    if step.danger then
        text = text .. " · " .. passes(step.danger)
    end
    if step.to.warn then
        text = text .. " · " .. step.to.warn
    end
    if step.to.unverified then
        text = text .. (step.to.stopover and " · stopover not confirmed" or " · crossing not confirmed")
    end
    return text, warn
end
```

- [ ] **Step 7: `GoblinPS/Core.lua`, the note**

In the comment above `Core.PlanRoute`, insert directly after

```lua
--   notes   plain lines for the player; the last one explains a missing route
```

these two lines:

```lua
--   hostile the note, also first in notes, when the destination stands in an
--           enemy town (Graph.HostileAt); the planner puts it first under the strip
```

In `Core.PlanRoute`, insert directly after

```lua
        plan.notes[1] = "Can't tell where you are. Inside an instance?"
        return plan
    end
```

this block (the notes are still empty here, so the note is the first):

```lua
    local enemy = ns.Graph.HostileAt(ns.Data, faction, to)
    if enemy then
        plan.hostile = Route.HostileNote(enemy)
        plan.notes[#plan.notes + 1] = plan.hostile
    end
```

- [ ] **Step 8: `GoblinPS/Planner.lua`, the warning line**

In `Planner.Refresh`, replace

```lua
        -- One amber line under the strip. What the player must know first
        -- wins: a stop in a dangerous place, then a note about the route
        -- itself, then a flight path worth discovering.
        if layout and layout.warning then
```

with

```lua
        -- One amber line under the strip. What the player must know first
        -- wins: a destination whose guards will attack, then a stop in a
        -- dangerous place, then a note about the route itself, then a flight
        -- path worth discovering.
        if plan.hostile then
            hint = plan.hostile
        elseif layout and layout.warning then
```

- [ ] **Step 9: Run every gate**

Lua `505 passed, 0 failed` (497 + 8). Python `Ran 74 tests`, `OK`. Art
green. luacheck and the language server: zero warnings.

- [ ] **Step 10: Commit**

```
git add GoblinPS/Route.lua GoblinPS/Core.lua GoblinPS/Planner.lua test/test_route.lua test/test_strip.lua test/test_ui.lua test/test_crossings.lua
git commit -m "Say so: the leg that passes an enemy town, and a destination that is one" -m "A ride step with danger reads 'passes Silverwind Refuge (Alliance)' in amber on its detail line, in place of the level range and before a crossing's hazard, so it reaches the tooltip and the line under the strip; a rough line says it alone, and an unconfirmed stopover says so as a stopover. A destination inside an enemy town's circle gets 'Silverwind Refuge is an Alliance town: its guards will attack you.', first among the notes for /gps to and first on the planner's warning line. The walk from Tirisfal to Mount Hyjal now names Talonbranch Glade on its way to the Timbermaw tunnels." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---


# GoblinPS Ground Crossings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ground travel goes zone by zone through named crossings, so a character with no flight paths gets real turns ("Walk to the Mor'shan Rampart, into Ashenvale") instead of one straight line to a zone's centre; steps say Walk or Ride by level; dangerous zones and crossings are flagged in amber.

**Architecture:** A hand-written `Data/Crossings.lua` (56 rows: two zones, a name, one map point, an optional hazard) and `Data/Zones.lua` (level ranges). `Graph` adds a ride edge only between two points in the same zone; a crossing belongs to both of its zones, so Dijkstra chains zones through crossings. Cities are zones and their gates are crossings; an island is a zone with no crossing, which retires the `Islands` table and the 800-yard transfer rule. `Travel` turns the character's level into a speed and walk-or-ride, from settings in one place. If no chain of crossings reaches the destination, `Route.Plan` falls back to the old straight line and labels it. The planner's step rows become two lines.

**Tech Stack:** Lua 5.1 on the WoW Forever client (1.60.1.69913, interface 16001), no libraries. Tests through lupa; luacheck and lua-language-server at zero warnings.

**Spec:** `docs/superpowers/specs/2026-09-19-goblinps-design.md`, decisions 15 to 19. Read it and `CLAUDE.md` first.

**This is plan 3 of 5.** Plan 4 is the dash unit (the arrow that walks these steps), plan 5 the schematic map.

## Global Constraints

- Plain Lua 5.1, **no libraries**, **no secure code**, no Blizzard frame templates in the window.
- Pure modules (`Geo`, `Travel`, `Search`, `Graph`, `Route`, `Trip`, `Known`, `Prefs`) touch no Blizzard global. `GoblinPS/API.lua` is the only file that calls Blizzard game APIs and registers game-data events. The one API this plan adds is `UnitLevel` (checked in `D:\wow-api\1.60.1.69913`, `UnitDocumentation.lua`). No new events.
- Generated files under `GoblinPS/Data/` (`Places`, `Nodes`, `Flights`) are never edited. `Links.lua`, `Inns.lua`, `Crossings.lua`, `Zones.lua` are hand-written.
- Mount levels and speeds are **unconfirmed** for Forever: they live only in `GoblinPS/Travel.lua` as named settings, and nothing else may hard-code them.
- Crossing coordinates are estimates until checked in game; crossings for Forever's new zones carry `unverified = true`.
- The route is always the fastest; danger only warns (amber), never reroutes.
- A hole in the crossings table must never produce "No route": the labelled straight-line fallback covers it.
- Route text stays plain. Every FontString in the window is bounded (two horizontal anchors or a width).
- Two planner layouts, one set of widgets.
- luacheck and lua-language-server stay at zero warnings; a new global goes in both `.luacheckrc` and `.luarc.json`.
- Version `2026.09.19.3`, written only in the TOC.
- Commit after each task with the trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` as a second `-m`. Do not push.

**Commands** (run from `D:\goblinps`):

Lua tests:

```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```

Python tests: `python -m unittest discover -s test/tools`

luacheck (PowerShell):

```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
$env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
```

Starting point: `122 passed, 0 failed`, luacheck `0 warnings / 0 errors`.

All code in this plan was run together in a scratch copy before the plan was written: 160 Lua tests pass and luacheck is clean. Every file a task changes is given **in full**: replace the whole file with the listing. If a count or output differs from what a step expects, stop and report; do not edit code to force a match.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `GoblinPS/Travel.lua` | create, pure | level to speed and walk-or-ride; the settings; "is this zone dangerous" |
| `GoblinPS/Data/Crossings.lua` | create, hand-written | 56 zone-to-zone crossings, city gates included |
| `GoblinPS/Data/Zones.lua` | create, hand-written | level range per zone |
| `GoblinPS/Graph.lua` | replace | ride edges only inside a zone; crossings; speed; rough mode |
| `GoblinPS/Route.lua` | replace | fallback plan, Walk/Ride/"toward" text, `Route.StepDetail` |
| `GoblinPS/Data/Links.lua` | replace | the `Islands` table is removed |
| `GoblinPS/API.lua` | replace | `API.Level()` |
| `GoblinPS/Core.lua` | replace | passes speed and walk; prints step details in chat |
| `GoblinPS/Planner.lua` | replace | two-line step rows with an amber warning |
| `GoblinPS/GoblinPS.toc`, `.luacheckrc`, `.luarc.json`, `test/run.lua` | replace | new files, `UnitLevel`, version |
| `test/fake_world.lua`, `test/fake_frames.lua` | replace | a crossing, a walled-off zone, level ranges; the fake records text colour |
| `test/test_travel.lua`, `test/test_crossings.lua` | create | settings; every crossing row, connectivity, real routes |
| `test/test_graph.lua`, `test/test_route.lua`, `test/test_data.lua`, `test/test_ui.lua` | replace | updated and extended |

Shapes added by this plan:

- **Crossing row:** `{ a, b, name, map, mx, my, warn?, faction?, unverified? }`. In the graph it becomes a stop with `zones = { a, b }` and `warn`.
- **Ride edge / step:** gains `zone` (the UiMap the leg is walked in), `walk` (true on foot) and `rough` (true for a fallback straight line).
- **`opts` for `Graph.Build` / `Route.Plan`:** gains `speed` (yards per second), `walk` and, internally, `rough`.

---

### Task 1: `Travel`

**Files:**
- Create: `GoblinPS/Travel.lua`, `test/test_travel.lua`
- Replace: `test/run.lua`

**Interfaces:**
- Produces: `ns.Travel.For(level) -> { speed, walk }` (nil level means on foot); `ns.Travel.Dangerous(range, level) -> bool`; settings `Travel.WALK_YARDS_PER_SECOND`, `Travel.MOUNTS` (list of `{ level, yardsPerSecond }`, lowest first), `Travel.WARN_LEVELS_ABOVE`.

- [ ] **Step 1: Replace `test/run.lua`** (it lists every module and suite of this plan and skips files that do not exist yet)

```lua
-- Run from the repository root through lupa (see CLAUDE.md).
local harness = dofile("test/harness.lua")

-- Same (addonName, ns) the client passes, loaded in TOC order into one ns.
-- API.lua and Core.lua touch Blizzard globals, so they are not loaded here.
local modules = {
    { "Geo",     "GoblinPS/Geo.lua" },
    { "Places",  "GoblinPS/Data/Places.lua" },
    { "Nodes",   "GoblinPS/Data/Nodes.lua" },
    { "Flights", "GoblinPS/Data/Flights.lua" },
    { "Links",   "GoblinPS/Data/Links.lua" },
    { "Inns",    "GoblinPS/Data/Inns.lua" },
    { "Crossings", "GoblinPS/Data/Crossings.lua" },
    { "Zones",   "GoblinPS/Data/Zones.lua" },
    { "Travel",  "GoblinPS/Travel.lua" },
    { "Search",  "GoblinPS/Search.lua" },
    { "Graph",   "GoblinPS/Graph.lua" },
    { "Route",   "GoblinPS/Route.lua" },
    { "Trip",    "GoblinPS/Trip.lua" },
    { "Known",   "GoblinPS/Known.lua" },
    { "Prefs",   "GoblinPS/Prefs.lua" },
}

local ns = {}
local loaded = { ns = ns }
for i = 1, #modules do
    local name, path = modules[i][1], modules[i][2]
    local f = io.open(path, "r")
    if f then
        f:close()
        loaded[name] = assert(loadfile(path))("GoblinPS", ns)
    end
end

local suites = {
    "test/test_geo.lua",
    "test/test_search.lua",
    "test/test_graph.lua",
    "test/test_route.lua",
    "test/test_trip.lua",
    "test/test_known.lua",
    "test/test_prefs.lua",
    "test/test_travel.lua",
    "test/test_crossings.lua",
    "test/test_ui.lua",
    "test/test_data.lua",
}

for i = 1, #suites do
    local f = io.open(suites[i], "r")
    if f then
        f:close()
        dofile(suites[i])(harness, loaded)
    end
end

os.exit(harness.run())
```

- [ ] **Step 2: Write the failing test `test/test_travel.lua`**

```lua
return function(h, loaded)
    local Travel = loaded.ns.Travel

    h.describe("Travel.For", function()
        h.it("walks below the first mount level", function()
            local t = Travel.For(1)
            h.eq(t.speed, Travel.WALK_YARDS_PER_SECOND)
            h.eq(t.walk, true)
        end)
        h.it("rides the first mount from its level", function()
            local first = Travel.MOUNTS[1]
            h.eq(Travel.For(first.level - 1).walk, true)
            h.eq(Travel.For(first.level).walk, false)
            h.eq(Travel.For(first.level).speed, first.yardsPerSecond)
        end)
        h.it("rides the fastest mount the level allows", function()
            local last = Travel.MOUNTS[#Travel.MOUNTS]
            h.eq(Travel.For(last.level).speed, last.yardsPerSecond)
            h.eq(Travel.For(last.level + 10).speed, last.yardsPerSecond)
        end)
        h.it("treats an unknown level as on foot", function()
            h.eq(Travel.For(nil).walk, true)
        end)
        h.it("follows the settings, so the definitive numbers are a two-line change", function()
            local saved = Travel.MOUNTS
            Travel.MOUNTS = { { level = 20, yardsPerSecond = 9 } }
            h.eq(Travel.For(20).speed, 9)
            h.eq(Travel.For(19).walk, true)
            Travel.MOUNTS = saved
        end)
    end)

    h.describe("Travel.Dangerous", function()
        h.it("warns when the zone starts well above the character", function()
            h.eq(Travel.Dangerous({ 48, 55 }, 1), true)
            h.eq(Travel.Dangerous({ 10, 25 }, 1), true)
        end)
        h.it("does not warn inside the margin", function()
            h.eq(Travel.Dangerous({ 10, 25 }, 10 - Travel.WARN_LEVELS_ABOVE), false)
            h.eq(Travel.Dangerous({ 1, 10 }, 1), false)
            h.eq(Travel.Dangerous({ 48, 55 }, 60), false)
        end)
        h.it("never warns without a range or a level", function()
            h.eq(Travel.Dangerous(nil, 5), false)
            h.eq(Travel.Dangerous({ 48, 55 }, nil), false)
        end)
    end)
end
```

- [ ] **Step 3: Run the Lua tests.** Expected: the eight new tests fail (`Travel` is nil); the other 122 pass.

- [ ] **Step 4: Write `GoblinPS/Travel.lua`**

```lua
local _, ns = ...

-- Pure: how fast this character covers ground, and the settings behind it.
-- THE NUMBERS ARE NOT CONFIRMED for WoW Forever: the mount levels come from
-- press coverage. They live here, in one place, so the definitive answer is a
-- two-line change. Level stands in for "has a mount" on purpose: the riding
-- skill and mount list APIs are unverified on this client.
local Travel = {}
ns.Travel = Travel

Travel.WALK_YARDS_PER_SECOND = 7
Travel.MOUNTS = {               -- lowest level first
    { level = 40, yardsPerSecond = 11.2 }, -- a 60% mount
    { level = 60, yardsPerSecond = 14 },   -- a 100% mount
}
Travel.WARN_LEVELS_ABOVE = 5    -- a zone that starts this far above you gets an amber warning

-- level nil (unknown) is treated as on foot: the safe, slower guess.
-- Returns { speed = yards per second, walk = true when on foot }.
function Travel.For(level)
    local speed, walk = Travel.WALK_YARDS_PER_SECOND, true
    for _, mount in ipairs(Travel.MOUNTS) do
        if level and level >= mount.level then
            speed, walk = mount.yardsPerSecond, false
        end
    end
    return { speed = speed, walk = walk }
end

-- Is a zone with this { low, high } range dangerous for this level?
function Travel.Dangerous(range, level)
    if not range or not level then
        return false
    end
    return range[1] > level + Travel.WARN_LEVELS_ABOVE
end

return Travel
```

- [ ] **Step 5: Run the Lua tests.** Expected: `130 passed, 0 failed`. luacheck: `0 warnings / 0 errors`.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Travel.lua test/test_travel.lua test/run.lua
git commit -m "Add travel settings: walk or ride by level" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Zone-by-zone ground travel

One task because the data, the graph and the route text only make sense together, and one set of tests covers them.

**Files:**
- Create: `GoblinPS/Data/Crossings.lua`, `GoblinPS/Data/Zones.lua`, `test/test_crossings.lua`
- Replace: `GoblinPS/Graph.lua`, `GoblinPS/Route.lua`, `GoblinPS/Data/Links.lua`, `test/fake_world.lua`, `test/test_graph.lua`, `test/test_route.lua`, `test/test_data.lua`, `.luacheckrc`, `.luarc.json`

**Interfaces:**
- Consumes: `ns.Travel` (Task 1), `ns.Geo`, `ns.Search`.
- Produces:
  - `ns.Data.Crossings`, `ns.Data.Zones[uiMapID] = { low, high }`
  - `ns.Graph.Build(data, opts)`: ride edges only between points that share a zone; crossing stops keyed `"x<index>"` with `zones` and `warn`; `opts.speed`, `opts.walk`, `opts.rough`; `ns.Graph.RideSeconds(a, b, speed)`. `Graph.TRANSFER_YARDS` and the `Islands` table no longer exist.
  - `ns.Route.Plan(data, opts)`: plans through crossings, and only if that finds nothing, once more in rough mode. `ns.Route.StepText(step)`: "Walk to" / "Ride to" / "Walk toward X (no mapped path)". `ns.Route.StepDetail(data, step, level) -> text, warn`.
- Places given to the router must now carry `map` (their zone): a place with no `map` has no ground edges.

- [ ] **Step 1: Replace `test/fake_world.lua`**

```lua
-- A tiny two-continent world. Both maps are 10000 x 10000 yards, so a map
-- coord converts as: world x = 10000 - my * 10000, world y = 10000 - mx * 10000.
local function world()
    return {
        Places = {
            [1] = { name = "Westland", c = 1, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.2, ay = 0.5 },
            [2] = { name = "Eastland", c = 0, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.8, ay = 0.5 },
            [3] = { name = "Isle", c = 1, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.5, ay = 0.1 },
            [4] = { name = "Northland", c = 1, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.2, ay = 0.2 },
            [5] = { name = "Lostland", c = 1, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.3, ay = 0.8 },
        },
        -- Ground travel is zone by zone. Westland (1) and Northland (4) are joined
        -- by one crossing. Isle (3) and Lostland (5) have none: Isle is an island
        -- (its two stops still ride to each other), Lostland is a hole in the table.
        Crossings = {
            { a = 1, b = 4, name = "the North Gate", map = 1, mx = 0.5, my = 0.02, warn = "trolls on the bridge" },
        },
        -- { low, high } level range per zone
        Zones = { [1] = { 1, 10 }, [4] = { 30, 40 } },
        Nodes = {
            [1] = { name = "Alpha, Westland", f = "H", c = 1, x = 1000, y = 1000, map = 1, mx = 0.9, my = 0.9 },
            [2] = { name = "Bravo, Westland", f = "H", c = 1, x = 1000, y = 9000, map = 1, mx = 0.1, my = 0.9 },
            [3] = { name = "Charlie, Westland", f = "N", c = 1, x = 5000, y = 9000, map = 1, mx = 0.1, my = 0.5 },
            [4] = { name = "Delta, Eastland", f = "H", c = 0, x = 5000, y = 5000, map = 2, mx = 0.5, my = 0.5 },
            [5] = { name = "Echo, Westland", f = "A", c = 1, x = 9000, y = 9000, map = 1, mx = 0.1, my = 0.1 },
            [6] = { name = "Foxtrot, Isle", f = "N", c = 1, x = 5000, y = 5000, map = 3, mx = 0.5, my = 0.5 },
            [7] = { name = "Golf, Isle", f = "N", c = 1, x = 5000, y = 5300, map = 3, mx = 0.5, my = 0.47 },
            [8] = { name = "Hotel, Northland", f = "N", c = 1, x = 9000, y = 5000, map = 4, mx = 0.5, my = 0.1 },
        },
        -- { from, to, copper, seconds }
        Flights = {
            { 1, 2, 100, 250 }, { 2, 1, 100, 250 },
            { 2, 3, 50, 125 }, { 3, 2, 50, 125 },
        },
        Docks = {
            west_dock = { name = "West Dock", map = 1, mx = 0.05, my = 0.9 }, -- world 1000, 9500
            east_dock = { name = "East Dock", map = 2, mx = 0.45, my = 0.5 }, -- world 5000, 5500
        },
        Inns = {
            ["Delta Harbour Inn"] = { stop = "Delta" },                 -- an inn beside a flight stop
            ["Quiet Hollow"] = { map = 1, mx = 0.25, my = 0.5 },        -- a town with no flight master
            ["Nowhere Inn"] = { map = 99, mx = 0.5, my = 0.5 },         -- a map we do not have
            ["Loop Inn"] = { stop = "Loop Inn" },                       -- names itself as its own stop
        },
        Links = {
            { from = "west_dock", to = "east_dock", kind = "zeppelin", minutes = 4, faction = "H" },
        },
    }
end

return world
```

- [ ] **Step 2: Replace `test/test_graph.lua`**

```lua
return function(h, loaded)
    local Graph = loaded.ns.Graph
    local world = dofile("test/fake_world.lua")()

    local nearAlpha = { name = "You", c = 1, x = 1000, y = 1100, map = 1 }
    local nearDelta = { name = "Delta Inn", c = 0, x = 5000, y = 5100, map = 2 }

    h.describe("Graph.Build", function()
        h.it("keeps a flight only when both ends are known", function()
            local g = Graph.Build(world, { faction = "H", known = { [1] = true }, from = nearAlpha, to = nearDelta })
            h.truthy(g.stops.f1)
            h.falsy(g.stops.f2)
            for _, e in ipairs(g.edges.f1 or {}) do
                h.truthy(e.kind ~= "fly", "no flight out of a lone known node")
            end
        end)
        h.it("drops the other faction's stops and links", function()
            local g = Graph.Build(world, { faction = "A", known = { [1] = true, [5] = true },
                                           from = nearAlpha, to = nearDelta })
            h.falsy(g.stops.f1)
            h.truthy(g.stops.f5)
            h.falsy(g.stops.west_dock)
        end)
        h.it("places a dock from its map coords", function()
            local g = Graph.Build(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta })
            h.eq(g.stops.west_dock.c, 1)
            h.truthy(math.abs(g.stops.west_dock.x - 1000) < 0.001)
            h.truthy(math.abs(g.stops.west_dock.y - 9500) < 0.001)
        end)
        h.it("joins a flight master to a dock in the same town", function()
            local g = Graph.Build(world, { faction = "H", known = { [2] = true }, from = nearAlpha, to = nearDelta })
            local found
            for _, e in ipairs(g.edges.f2) do
                found = found or (e.to == "west_dock" and e.kind == "ride")
            end
            h.truthy(found, "Bravo to West Dock is 500 yards")
        end)
        h.it("links run both ways", function()
            local g = Graph.Build(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta })
            h.eq(g.edges.west_dock[1].to, "east_dock")
            h.eq(g.edges.east_dock[1].to, "west_dock")
            h.eq(g.edges.west_dock[1].seconds, 240)
        end)
        h.it("adds the hearthstone only when offered", function()
            local opts = { faction = "H", known = {}, from = nearAlpha, to = nearDelta }
            h.falsy(Graph.Build(world, opts).stops.HEARTH)
            opts.hearth = { name = "Delta Inn", c = 0, x = 5000, y = 5050, map = 2 }
            local g = Graph.Build(world, opts)
            h.truthy(g.stops.HEARTH)
            h.eq(g.edges.START[1].kind, "hearth")
        end)
    end)

    h.describe("Graph.Build: a zone with no crossing is an island", function()
        local fromIsle = { name = "You", c = 1, x = 5000, y = 4900, map = 3 }
        local toMainland = { name = "Mainland Dest", c = 1, x = 5000, y = 5100, map = 1 }

        local function rideEdgeTo(edges, from, to)
            for _, e in ipairs(edges[from] or {}) do
                if e.to == to and e.kind == "ride" then
                    return true
                end
            end
            return false
        end

        h.it("never rides from START to a stop on a different landmass", function()
            local g = Graph.Build(world, { faction = "H", known = { [1] = true, [6] = true, [7] = true },
                                           from = fromIsle, to = toMainland })
            h.truthy(rideEdgeTo(g.edges, "START", "f6"), "START to the island stop should ride")
            h.falsy(rideEdgeTo(g.edges, "START", "f1"), "START to the mainland stop should not ride")
        end)
        h.it("never rides from a stop to DEST across landmasses", function()
            local g = Graph.Build(world, { faction = "H", known = { [1] = true, [6] = true, [7] = true },
                                           from = fromIsle, to = toMainland })
            h.truthy(rideEdgeTo(g.edges, "f1", "DEST"), "the mainland stop to DEST should ride")
            h.falsy(rideEdgeTo(g.edges, "f6", "DEST"), "the island stop to DEST should not ride")
        end)
        h.it("never rides between stops on different landmasses", function()
            local g = Graph.Build(world, { faction = "H", known = { [1] = true, [6] = true, [7] = true },
                                           from = fromIsle, to = toMainland })
            h.falsy(rideEdgeTo(g.edges, "f1", "f6"), "mainland to island should not ride")
            h.falsy(rideEdgeTo(g.edges, "f6", "f1"), "island to mainland should not ride")
        end)
        h.it("still rides between two stops on the same island", function()
            local g = Graph.Build(world, { faction = "H", known = { [6] = true, [7] = true },
                                           from = fromIsle, to = toMainland })
            h.truthy(rideEdgeTo(g.edges, "f6", "f7"), "two island stops should still ride to each other")
        end)
        h.it("pins the ride-time arithmetic", function()
            h.eq(Graph.RideSeconds({ c = 1, x = 0, y = 0 }, { c = 1, x = 1120, y = 0 }), 130)
        end)
    end)

    h.describe("crossings", function()
        local nearAlphaHere = { name = "You", c = 1, x = 1000, y = 1100, map = 1 }
        local hotel = { name = "Hotel", c = 1, x = 9000, y = 5000, map = 4 }
        local function edgeTo(g, from, to)
            for _, e in ipairs(g.edges[from] or {}) do
                if e.to == to then
                    return e
                end
            end
        end
        local function gateKey(g)
            for key, stop in pairs(g.stops) do
                if stop.zones then
                    return key
                end
            end
        end

        h.it("makes a crossing a stop that belongs to both of its zones", function()
            local g = Graph.Build(world, { faction = "H", known = {}, from = nearAlphaHere, to = hotel })
            local gate = g.stops[gateKey(g)]
            h.eq(gate.name, "the North Gate")
            h.eq(gate.zones[1], 1)
            h.eq(gate.zones[2], 4)
            h.eq(gate.warn, "trolls on the bridge")
            h.truthy(math.abs(gate.x - 9800) < 0.001 and math.abs(gate.y - 5000) < 0.001)
        end)
        h.it("rides only inside a zone, so the next zone is reached through the crossing", function()
            local g = Graph.Build(world, { faction = "H", known = { [8] = true }, from = nearAlphaHere, to = hotel })
            local gate = gateKey(g)
            h.falsy(edgeTo(g, "START", "f8"), "no straight line into another zone")
            h.falsy(edgeTo(g, "START", "DEST"), "no straight line into another zone")
            h.eq(edgeTo(g, "START", gate).zone, 1)
            h.eq(edgeTo(g, gate, "f8").zone, 4)
            h.eq(edgeTo(g, gate, "DEST").zone, 4)
        end)
        h.it("times the ground at the speed it is given and marks walking", function()
            local opts = { faction = "H", known = {}, from = nearAlphaHere, to = hotel, speed = 7, walk = true }
            local g = Graph.Build(world, opts)
            local e = edgeTo(g, "START", gateKey(g))
            h.eq(e.walk, true)
            h.truthy(math.abs(e.seconds - Graph.RideSeconds(g.stops.START, g.stops[gateKey(g)], 7)) < 0.001)
            h.truthy(e.seconds > Graph.RideSeconds(g.stops.START, g.stops[gateKey(g)]))
        end)
        h.it("adds straight lines only in rough mode, and flags them", function()
            local lost = { name = "Lostland", kind = "zone", c = 1, x = 5000, y = 5000, map = 5 }
            local opts = { faction = "H", known = {}, from = nearAlphaHere, to = lost }
            h.falsy(edgeTo(Graph.Build(world, opts), "START", "DEST"))
            opts.rough = true
            local e = edgeTo(Graph.Build(world, opts), "START", "DEST")
            h.eq(e.rough, true)
            h.eq(e.zone, nil)
        end)
        h.it("a place with no zone has no ground edges at all", function()
            local nowhere = { name = "You", c = 1, x = 1000, y = 1100 }
            local g = Graph.Build(world, { faction = "H", known = { [1] = true }, from = nowhere, to = hotel })
            h.eq(g.edges.START, nil)
        end)
    end)
end
```

- [ ] **Step 3: Replace `test/test_route.lua`**

```lua
return function(h, loaded)
    local Graph, Route = loaded.ns.Graph, loaded.ns.Route
    local world = dofile("test/fake_world.lua")()

    local nearAlpha = { name = "You", c = 1, x = 1000, y = 1100, map = 1 }
    local nearDelta = { name = "Delta Inn", c = 0, x = 5000, y = 5100, map = 2 }
    local nearCharlie = { name = "Charlie Field", c = 1, x = 5000, y = 9100, map = 1 }

    local function kinds(result)
        local out = {}
        for i, s in ipairs(result.steps) do
            out[i] = s.kind
        end
        return table.concat(out, ",")
    end

    h.describe("Route.Plan", function()
        h.it("chains ride, flight, transfer, zeppelin and ride", function()
            local r = Route.Plan(world, { faction = "H", known = { [1] = true, [2] = true, [4] = true },
                                          from = nearAlpha, to = nearDelta })
            h.eq(kinds(r), "ride,fly,ride,zeppelin,ride")
            h.eq(r.copper, 100)
            h.eq(r.steps[2].to.nodeID, 2)
            h.eq(r.steps[4].seconds, 240)
        end)
        h.it("merges a chain of flights into one step", function()
            local r = Route.Plan(world, { faction = "H", known = { [1] = true, [2] = true, [3] = true },
                                          from = nearAlpha, to = nearCharlie })
            h.eq(kinds(r), "ride,fly,ride")
            h.eq(r.steps[2].to.nodeID, 3)
            h.eq(r.steps[2].seconds, 375)
            h.eq(r.steps[2].copper, 150)
            h.eq(#r.raw, 4)
        end)
        h.it("drops a ride too short to mention", function()
            local r = Route.Plan(world, { faction = "H", known = { [1] = true, [2] = true },
                                          from = { name = "You", c = 1, x = 1000, y = 1010 },
                                          to = { name = "Bravo Gate", c = 1, x = 1000, y = 8990 } })
            h.eq(kinds(r), "fly")
        end)
        h.it("rides the whole way when no flight is known", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = nearCharlie })
            h.eq(kinds(r), "ride")
        end)
        h.it("returns nil when the other continent cannot be reached", function()
            h.eq(Route.Plan(world, { faction = "A", known = { [5] = true }, from = nearAlpha, to = nearDelta }), nil)
        end)
        h.it("uses the hearthstone when it is offered", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta,
                                          hearth = { name = "Delta Inn", c = 0, x = 5000, y = 5050, map = 2 } })
            h.eq(r.steps[1].kind, "hearth")
            h.eq(r.steps[1].seconds, Graph.HEARTH_SECONDS)
        end)
        h.it("ignores the hearthstone when it is not offered", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta })
            h.eq(kinds(r), "ride,zeppelin,ride")
        end)
    end)

    h.describe("a zone destination", function()
        local westland = loaded.ns.Search.Find(world, "westland", "H", 1)[1]
        h.it("is reached at the first stop inside the zone", function()
            local r = Route.Plan(world, { faction = "H", known = { [4] = true }, from = nearDelta, to = westland })
            h.eq(kinds(r), "ride,zeppelin")
            h.eq(r.steps[2].to.key, "west_dock")
        end)
        h.it("has no steps when you already stand in it", function()
            local inWestland = { name = "You", c = 1, x = 1000, y = 1100, map = 1, mx = 0.89, my = 0.9 }
            local r = Route.Plan(world, { faction = "H", known = {}, from = inWestland, to = westland })
            h.eq(#r.steps, 0)
        end)
        h.it("still rides to an exact stop in that zone", function()
            local charlie = loaded.ns.Search.Find(world, "charlie", "H", 1)[1]
            local inWestland = { name = "You", c = 1, x = 1000, y = 1100, map = 1, mx = 0.89, my = 0.9 }
            local r = Route.Plan(world, { faction = "H", known = {}, from = inWestland, to = charlie })
            h.eq(kinds(r), "ride")
        end)
    end)

    h.describe("ground travel through crossings", function()
        local northland = loaded.ns.Search.Find(world, "northland", "H", 1)[1]
        local hotel = loaded.ns.Search.Find(world, "hotel", "H", 1)[1]
        local lostland = loaded.ns.Search.Find(world, "lostland", "H", 1)[1]

        h.it("reaches the next zone at its crossing", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = northland })
            h.eq(kinds(r), "ride")
            h.eq(Route.StepText(r.steps[1]), "Ride to the North Gate")
            h.falsy(r.steps[1].rough)
        end)
        h.it("goes on from the crossing to an exact stop", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = hotel })
            h.eq(kinds(r), "ride,ride")
            h.eq(Route.StepText(r.steps[2]), "Ride to Hotel")
            h.eq(r.steps[1].zone, 1)
            h.eq(r.steps[2].zone, 4)
        end)
        h.it("says Walk on foot and takes longer", function()
            local riding = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = hotel })
            local walking = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = hotel,
                                                speed = 7, walk = true })
            h.eq(Route.StepText(walking.steps[1]), "Walk to the North Gate")
            h.truthy(math.abs(walking.seconds - riding.seconds * 11.2 / 7) < 0.01)
        end)
        h.it("falls back to a labelled straight line when the crossings table has a hole", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = lostland })
            h.truthy(r, "a hole in the table must not mean no route")
            h.eq(kinds(r), "ride")
            h.eq(r.steps[1].rough, true)
            h.eq(Route.StepText(r.steps[1]), "Ride toward Lostland (no mapped path)")
            local walking = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = lostland,
                                                speed = 7, walk = true })
            h.eq(Route.StepText(walking.steps[1]), "Walk toward Lostland (no mapped path)")
        end)
        h.it("never uses a straight line when a chain of crossings exists", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = hotel })
            for _, s in ipairs(r.steps) do
                h.falsy(s.rough)
            end
        end)
    end)

    h.describe("Route.StepDetail", function()
        local hotel = loaded.ns.Search.Find(world, "hotel", "H", 1)[1]
        local r = Route.Plan(world, { faction = "H", known = { [1] = true, [2] = true }, from = nearAlpha, to = hotel })
        h.it("says which zone a crossing leads into, its levels and its hazard", function()
            local gateStep
            for _, s in ipairs(r.steps) do
                if s.to.zones then
                    gateStep = s
                end
            end
            local text, warn = Route.StepDetail(world, gateStep, 35)
            h.eq(text, "into Northland · level 30-40 · trolls on the bridge")
            h.eq(warn, true)
        end)
        h.it("warns about a zone well above the character", function()
            local last = r.steps[#r.steps]
            local text, warn = Route.StepDetail(world, last, 5)
            h.eq(text, "in Northland · level 30-40")
            h.eq(warn, true)
            local _, calm = Route.StepDetail(world, last, 35)
            h.eq(calm, false)
        end)
        h.it("has nothing to say about a flight, a link or a rough line", function()
            local text, warn = Route.StepDetail(world, { kind = "fly", to = { name = "Bravo" } }, 5)
            h.eq(text, "")
            h.eq(warn, false)
            text = Route.StepDetail(world, { kind = "ride", rough = true, to = { name = "Lostland" } }, 5)
            h.eq(text, "")
        end)
        h.it("copes with a zone that has no level range", function()
            local text, warn = Route.StepDetail(world, { kind = "ride", zone = 3, to = { name = "Foxtrot" } }, 5)
            h.eq(text, "in Isle")
            h.eq(warn, false)
        end)
    end)

    h.describe("Route.Hint", function()
        local opts = { faction = "H", known = {}, from = nearAlpha, to = nearDelta }
        h.it("names the missing flight stops and the saving", function()
            local hint = Route.Hint(world, opts, Route.Plan(world, opts))
            h.eq(table.concat(hint.names, ","), "Alpha,Bravo")
            h.truthy(hint.seconds > 600)
            h.eq(Route.HintText(hint), "Discover Alpha and Bravo to save ~11 min")
        end)
        h.it("stays quiet when the saving is small", function()
            local o = { faction = "H", known = { [1] = true, [2] = true, [4] = true },
                        from = nearAlpha, to = nearDelta }
            h.eq(Route.Hint(world, o, Route.Plan(world, o)), nil)
        end)
        h.it("stays quiet when nothing would help", function()
            local o = { faction = "A", known = {}, from = nearAlpha, to = nearDelta }
            h.eq(Route.Hint(world, o, nil), nil)
        end)
        h.it("names two stops and says how many more when the better route needs three", function()
            local o = { faction = "H", known = {}, from = nearAlpha, to = nearCharlie }
            local hint = Route.Hint(world, o, Route.Plan(world, o))
            h.eq(table.concat(hint.names, ","), "Alpha,Bravo")
            h.eq(hint.more, 1)
            h.eq(Route.HintText(hint), "Discover Alpha, Bravo and 1 more to save ~11 min")
        end)
    end)

    h.describe("Route text", function()
        h.it("formats time and money", function()
            h.eq(Route.FormatTime(20), "~1 min")
            h.eq(Route.FormatTime(840), "~14 min")
            h.eq(Route.FormatMoney(0), "free")
            h.eq(Route.FormatMoney(110), "1s 10c")
            h.eq(Route.FormatMoney(12005), "1g 20s 5c")
        end)
        h.it("writes plain steps", function()
            local r = Route.Plan(world, { faction = "H", known = { [1] = true, [2] = true, [4] = true },
                                          from = nearAlpha, to = nearDelta })
            h.eq(Route.StepText(r.steps[1]), "Ride to Alpha")
            h.eq(Route.StepText(r.steps[2]), "Fly to Bravo")
            h.eq(Route.StepText(r.steps[4]), "Zeppelin to East Dock (~4 min incl. wait)")
            h.eq(Route.StepText(r.steps[5]), "Ride to Delta Inn")
        end)
        h.it("words a hint with no existing route", function()
            h.eq(Route.HintText({ names = { "Ratchet" } }), "Discover Ratchet to open a route")
        end)
        h.it("words a hint with no existing route and more stops than shown", function()
            h.eq(Route.HintText({ names = { "Alpha", "Bravo" }, more = 2 }),
                 "Discover Alpha, Bravo and 2 more to open a route")
        end)
    end)
end
```

- [ ] **Step 4: Replace `test/test_data.lua`**

```lua
-- Integrity of the shipped data: generated tables and the hand-written links.
return function(h, loaded)
    local ns = loaded.ns
    local data = ns.Data

    local function findNode(prefix)
        for id, n in pairs(data.Nodes) do
            if n.name:find(prefix, 1, true) == 1 then
                return id, n
            end
        end
    end

    local function allKnown()
        local known = {}
        for id in pairs(data.Nodes) do
            known[id] = true
        end
        return known
    end

    local function placeOf(n)
        return { name = n.name, c = n.c, x = n.x, y = n.y, map = n.map, mx = n.mx, my = n.my }
    end


    h.describe("shipped data", function()
        h.it("has every table", function()
            for _, name in ipairs({ "Places", "Nodes", "Flights", "Docks", "Links" }) do
                h.truthy(data and data[name], name .. " is missing")
            end
        end)
        h.it("has flights only between nodes that exist", function()
            for _, f in ipairs(data.Flights) do
                h.truthy(data.Nodes[f[1]] and data.Nodes[f[2]], "flight " .. f[1] .. "->" .. f[2])
                h.truthy(f[4] > 0, "flight time")
            end
        end)
        h.it("puts every node on a known map", function()
            for id, n in pairs(data.Nodes) do
                h.truthy(data.Places[n.map], "node " .. id .. " map")
            end
        end)
        h.it("can place every dock a link uses", function()
            for _, link in ipairs(data.Links) do
                for _, id in ipairs({ link.from, link.to }) do
                    local d = data.Docks[id]
                    h.truthy(d, "dock " .. id)
                    h.truthy(ns.Geo.ToWorld(data.Places, d.map, d.mx, d.my), "dock " .. id .. " map")
                end
            end
        end)
        h.it("gives every link sane fields", function()
            for _, link in ipairs(data.Links) do
                h.truthy(link.minutes > 0, link.from .. " minutes")
                h.truthy(link.faction == "A" or link.faction == "H" or link.faction == "N", link.from .. " faction")
            end
        end)
        h.it("never lets a ride undercut a link: its docks are in different zones, or the ride is slower", function()
            for _, link in ipairs(data.Links) do
                local a, b = data.Docks[link.from], data.Docks[link.to]
                local ac, ax, ay = ns.Geo.ToWorld(data.Places, a.map, a.mx, a.my)
                local bc, bx, by = ns.Geo.ToWorld(data.Places, b.map, b.mx, b.my)
                local pa, pb = { c = ac, x = ax, y = ay }, { c = bc, x = bx, y = by }
                local ok = ac ~= bc or a.map ~= b.map
                    or ns.Graph.RideSeconds(pa, pb) > link.minutes * 60
                h.truthy(ok, link.from .. " to " .. link.to .. " is within riding range of the link")
            end
        end)
        h.it("puts every dock in a zone you can walk out of or fly from", function()
            local reachable = {}
            for _, x in ipairs(data.Crossings) do
                reachable[x.a], reachable[x.b] = true, true
            end
            for _, n in pairs(data.Nodes) do
                reachable[n.map] = true
            end
            for id, d in pairs(data.Docks) do
                h.truthy(reachable[d.map], id .. " is in a zone with no crossing and no flight master")
            end
        end)
    end)

    h.describe("the inn list", function()
        h.it("resolves every row for the faction that can use it", function()
            for bind in pairs(data.Inns) do
                local found = ns.Search.Exact(data, bind, "H") or ns.Search.Exact(data, bind, "A")
                h.truthy(found, bind .. " does not resolve")
            end
        end)
        h.it("only lists names Search cannot already find", function()
            local without = {}
            for k, v in pairs(data) do
                without[k] = v
            end
            without.Inns = nil
            for bind in pairs(data.Inns) do
                h.falsy(ns.Search.Exact(without, bind, nil), bind .. " already resolves; drop the row")
            end
        end)
        h.it("finds the binds met in game", function()
            h.eq(ns.Search.Exact(data, "The Crossroads", "H").nodeID, 25)
            h.eq(ns.Search.Exact(data, "Brill", "H").kind, "inn")
        end)
    end)

    h.describe("a real route", function()
        h.it("takes a Horde character from Thunder Bluff to Undercity by zeppelin", function()
            local _, tb = findNode("Thunder Bluff")
            local _, uc = findNode("Undercity")
            local r = ns.Route.Plan(data, { faction = "H", known = allKnown(), from = placeOf(tb), to = placeOf(uc) })
            h.truthy(r, "no route")
            local kinds = {}
            for i, s in ipairs(r.steps) do
                kinds[i] = s.kind
            end
            -- out of Orgrimmar by its gate, to the tower, across, and in through the ruins
            h.eq(table.concat(kinds, ","), "fly,ride,ride,zeppelin,ride,ride")
            h.eq(ns.Route.StepText(r.steps[1]), "Fly to Orgrimmar")
            h.eq(ns.Route.StepText(r.steps[2]), "Ride to Orgrimmar's front gate")
            h.eq(ns.Route.StepText(r.steps[3]), "Ride to Orgrimmar Zeppelin Tower")
            h.eq(ns.Route.StepText(r.steps[5]), "Ride to the Ruins of Lordaeron")
        end)
        h.it("takes an Alliance character from Stormwind to Ironforge", function()
            local _, sw = findNode("Stormwind")
            local _, ironforge = findNode("Ironforge")
            local r = ns.Route.Plan(data, { faction = "A", known = allKnown(),
                                            from = placeOf(sw), to = placeOf(ironforge) })
            h.truthy(r, "no route")
            h.eq(ns.Route.StepText(r.steps[2]), "Tram to Ironforge Tram Station (~2 min incl. wait)")
        end)
        h.it("takes an Alliance character across water to Teldrassil, not a ride", function()
            local darkshore = ns.Search.Find(data, "Darkshore", "A", 1)[1]
            local teldrassil = ns.Search.Find(data, "Teldrassil", "A", 1)[1]
            h.truthy(darkshore, "no Darkshore zone")
            h.truthy(teldrassil, "no Teldrassil zone")
            local r = ns.Route.Plan(data, { faction = "A", known = {}, from = darkshore, to = teldrassil })
            h.truthy(r, "no route")
            local kinds = {}
            for i, s in ipairs(r.steps) do
                kinds[i] = s.kind
            end
            local hasBoat = false
            for _, k in ipairs(kinds) do
                hasBoat = hasBoat or k == "boat"
            end
            h.truthy(hasBoat, "route should include a boat: " .. table.concat(kinds, ","))
            h.falsy(#kinds == 1 and kinds[1] == "ride", "route should not be a single ride across water")
        end)
    end)
end
```

- [ ] **Step 5: Write `test/test_crossings.lua`**

```lua
-- The hand-written crossings over the real shipped data: every row is sane,
-- every continent's zones connect, and the routes that prompted the feature
-- come out zone by zone.
return function(h, loaded)
    local ns = loaded.ns
    local data = ns.Data

    -- Zones that are meant to have no land path to the rest of their continent.
    -- Teldrassil and Darnassus connect to each other and to nothing else: boat only.
    local ISLANDS = { [1438] = true, [1457] = true }
    -- How far outside a zone's map rectangle a crossing point may sit (share of
    -- the rectangle's size). Rectangles are generous and overlap; this only
    -- catches a point typed into the wrong zone or with x and y swapped.
    local SLACK = 0.10

    local function near(map, c, x, y)
        local p = data.Places[map]
        local dx, dy = (p.x1 - p.x0) * SLACK, (p.y1 - p.y0) * SLACK
        return p.c == c and x >= p.x0 - dx and x <= p.x1 + dx and y >= p.y0 - dy and y <= p.y1 + dy
    end

    h.describe("the crossings table", function()
        h.it("has sane rows", function()
            for i, x in ipairs(data.Crossings) do
                local label = "crossing " .. i .. " (" .. tostring(x.name) .. ")"
                h.truthy(data.Places[x.a] and data.Places[x.b], label .. ": unknown zone")
                h.truthy(x.a ~= x.b, label .. ": joins a zone to itself")
                h.truthy(x.map == x.a or x.map == x.b, label .. ": its point is on neither zone's map")
                h.truthy(type(x.name) == "string" and x.name ~= "" and not x.name:find(","),
                         label .. ": needs a name without a comma")
                h.truthy(x.warn == nil or #x.warn <= 48, label .. ": warn must be short")
                h.eq(data.Places[x.a].c, data.Places[x.b].c, label .. ": zones on different continents")
            end
        end)
        h.it("puts every point in or beside both of its zones", function()
            for i, x in ipairs(data.Crossings) do
                local c, wx, wy = ns.Geo.ToWorld(data.Places, x.map, x.mx, x.my)
                h.truthy(c, "crossing " .. i .. " cannot be placed")
                h.truthy(near(x.a, c, wx, wy) and near(x.b, c, wx, wy),
                         "crossing " .. i .. " (" .. x.name .. ") is not near both " .. data.Places[x.a].name
                         .. " and " .. data.Places[x.b].name)
            end
        end)
        h.it("lists each pair of zones once", function()
            local seen = {}
            for _, x in ipairs(data.Crossings) do
                local key = math.min(x.a, x.b) .. "-" .. math.max(x.a, x.b)
                h.falsy(seen[key], key .. " is listed twice")
                seen[key] = true
            end
        end)
        h.it("connects every zone on a continent, bar the islands", function()
            local group = {}
            local function find(z)
                while group[z] ~= z do
                    z = group[z]
                end
                return z
            end
            for map in pairs(data.Places) do
                group[map] = map
            end
            for _, x in ipairs(data.Crossings) do
                group[find(x.a)] = find(x.b)
            end
            local root = {}
            for map, p in pairs(data.Places) do
                if not ISLANDS[map] then
                    root[p.c] = root[p.c] or find(map)
                    h.eq(find(map), root[p.c], p.name .. " has no chain of crossings to the rest of its continent")
                end
            end
        end)
        h.it("keeps the islands islands", function()
            for _, x in ipairs(data.Crossings) do
                h.eq(ISLANDS[x.a] == true, ISLANDS[x.b] == true, x.name .. " joins an island to the mainland")
            end
        end)
        h.it("has a level range only for zones that exist", function()
            for map, range in pairs(data.Zones) do
                h.truthy(data.Places[map], "zone " .. map .. " is not a known place")
                h.truthy(range[1] <= range[2], "zone " .. map .. " range is backwards")
            end
        end)
    end)

    local function place(text, faction)
        return ns.Search.Find(data, text, faction, 1)[1]
    end

    local function texts(result)
        local out = {}
        for i, s in ipairs(result.steps) do
            out[i] = ns.Route.StepText(s)
        end
        return out
    end

    h.describe("real routes on the ground", function()
        h.it("walks a new undead from Tirisfal to Mount Hyjal zone by zone", function()
            local walker = ns.Travel.For(1)
            local r = ns.Route.Plan(data, { faction = "H", known = {}, speed = walker.speed, walk = walker.walk,
                                            from = place("Tirisfal", "H"), to = place("Mount Hyjal", "H") })
            h.truthy(r, "no route")
            local t = texts(r)
            h.eq(t[1], "Walk to Undercity Zeppelin Tower")
            h.truthy(t[2]:find("Zeppelin to Orgrimmar Zeppelin Tower", 1, true))
            -- through Orgrimmar and out of its west gate: faster than round by the Southfury bridge
            h.eq(t[3], "Walk to Orgrimmar's front gate")
            h.eq(t[4], "Walk to Orgrimmar's west gate")
            h.eq(t[5], "Walk to the Mor'shan Rampart")
            h.eq(t[6], "Walk to the road into Felwood")
            h.eq(t[7], "Walk to the Timbermaw Hold tunnels")
            h.eq(t[8], "Walk to Darkwhisper Gorge")
            h.eq(#t, 8)
            for _, s in ipairs(r.steps) do
                h.falsy(s.rough, "no step may fall back to a straight line")
            end
        end)
        h.it("explains each ground step and warns a low-level character", function()
            local walker = ns.Travel.For(1)
            local r = ns.Route.Plan(data, { faction = "H", known = {}, speed = walker.speed, walk = walker.walk,
                                            from = place("Tirisfal", "H"), to = place("Mount Hyjal", "H") })
            local text, warn = ns.Route.StepDetail(data, r.steps[1], 1)
            h.eq(text, "in Tirisfal Glades · level 1-10")
            h.eq(warn, false)
            text, warn = ns.Route.StepDetail(data, r.steps[5], 1)
            h.eq(text, "into Ashenvale · level 18-30")
            h.eq(warn, true)
            text, warn = ns.Route.StepDetail(data, r.steps[7], 60)
            h.eq(text, "into Winterspring · level 53-60 · Timbermaw furbolgs attack without reputation")
            h.eq(warn, true)
            text, warn = ns.Route.StepDetail(data, r.steps[2], 1)
            h.eq(text, "")
            h.eq(warn, false)
        end)
        h.it("is slower on foot than on a mount", function()
            local from, to = place("Durotar", "H"), place("Ashenvale", "H")
            local foot, mount = ns.Travel.For(1), ns.Travel.For(60)
            local a = ns.Route.Plan(data, { faction = "H", known = {}, from = from, to = to,
                                            speed = foot.speed, walk = foot.walk })
            local b = ns.Route.Plan(data, { faction = "H", known = {}, from = from, to = to,
                                            speed = mount.speed, walk = mount.walk })
            h.truthy(a.seconds > b.seconds * 1.9)
            h.truthy(ns.Route.StepText(b.steps[1]):find("^Ride to"))
        end)
        h.it("still needs the boat for Teldrassil", function()
            local r = ns.Route.Plan(data, { faction = "A", known = {}, from = place("Darkshore", "A"),
                                            to = place("Teldrassil", "A") })
            local sawBoat = false
            for _, s in ipairs(r.steps) do
                sawBoat = sawBoat or s.kind == "boat"
                h.falsy(s.rough)
            end
            h.truthy(sawBoat)
        end)
        h.it("leaves a city by its gate", function()
            local r = ns.Route.Plan(data, { faction = "A", known = {}, from = place("Stormwind City", "A"),
                                            to = place("Westfall", "A") })
            local t = texts(r)
            h.eq(t[1], "Ride to the Stormwind gates")
            h.eq(t[2], "Ride to the Westfall bridge")
            h.eq(#t, 2)
        end)
    end)
end
```

- [ ] **Step 6: Run the Lua tests.** Expected: many failures (no crossings in the graph, no `Route.StepDetail`, `data.Crossings` is nil). That is the RED; record the counts.

- [ ] **Step 7: Write `GoblinPS/Data/Crossings.lua`**

```lua
-- HAND-WRITTEN. Where you can walk from one zone into the next. Ground travel
-- happens inside one zone at a time; a crossing is a named point that belongs
-- to both of its zones, so the router chains zones through these rows. Cities
-- are zones too, and their gates are crossings. A zone with no row here (or
-- only a row to its own city) is an island: boats and flights only.
--
--   a, b    the two zones (UiMap IDs; names in the trailing comment)
--   name    what the step says: "Walk to <name>"; include "the" where it reads better
--   map, mx, my   the point, as map coords (0..1) on ONE of the two zones.
--           APPROXIMATE: written from memory of the classic world, corrected in
--           game from docs/manual-test-checklist.md, like the dock positions.
--   warn    optional, short: shown in amber on the step's detail line
--   unverified = true   Forever's new zones: the crossing itself is a guess
--
-- Which zones border which, the place names and the level ranges are facts
-- about Blizzard's game; the Forever Atlas fan site's table was used as a
-- checklist of those facts. The rows, wording and coordinates here are our own. test/test_crossings.lua checks every row and that each continent's
-- zones all connect (bar the islands listed there).
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Crossings = {
    -- Kalimdor: cities
    { a = 1454, b = 1411, name = "Orgrimmar's front gate", map = 1411, mx = 0.455, my = 0.120 }, -- Orgrimmar, Durotar
    { a = 1454, b = 1413, name = "Orgrimmar's west gate", map = 1454, mx = 0.170, my = 0.630 },  -- Orgrimmar, The Barrens
    { a = 1456, b = 1412, name = "the Thunder Bluff lifts", map = 1412, mx = 0.385, my = 0.310 }, -- Thunder Bluff, Mulgore
    { a = 1457, b = 1438, name = "the Darnassus gate", map = 1438, mx = 0.365, my = 0.540 },     -- Darnassus, Teldrassil
    -- Kalimdor: zones
    { a = 1411, b = 1413, name = "the Southfury bridge", map = 1411, mx = 0.345, my = 0.425 },   -- Durotar, The Barrens
    { a = 1413, b = 1412, name = "the pass into Mulgore", map = 1412, mx = 0.685, my = 0.605 },  -- The Barrens, Mulgore
    { a = 1413, b = 1440, name = "the Mor'shan Rampart", map = 1413, mx = 0.485, my = 0.055 },   -- The Barrens, Ashenvale
    { a = 1413, b = 1442, name = "the Stonetalon pass", map = 1413, mx = 0.345, my = 0.280 },    -- The Barrens, Stonetalon Mountains
    { a = 1413, b = 1445, name = "the road into Dustwallow", map = 1413, mx = 0.495, my = 0.785 }, -- The Barrens, Dustwallow Marsh
    { a = 1413, b = 1441, name = "the Great Lift", map = 1413, mx = 0.440, my = 0.910 },         -- The Barrens, Thousand Needles
    { a = 1441, b = 1444, name = "the road into Feralas", map = 1441, mx = 0.085, my = 0.115 },  -- Thousand Needles, Feralas
    { a = 1441, b = 1446, name = "the pass into Tanaris", map = 1446, mx = 0.510, my = 0.220 },  -- Thousand Needles, Tanaris
    { a = 1446, b = 1449, name = "the ramp into Un'Goro", map = 1446, mx = 0.270, my = 0.520 },  -- Tanaris, Un'Goro Crater
    { a = 1449, b = 1451, name = "the ramp into Silithus", map = 1449, mx = 0.295, my = 0.220 }, -- Un'Goro Crater, Silithus
    { a = 1444, b = 1443, name = "the road into Desolace", map = 1444, mx = 0.450, my = 0.080 }, -- Feralas, Desolace
    { a = 1443, b = 1442, name = "the road into Stonetalon", map = 1443, mx = 0.535, my = 0.040 }, -- Desolace, Stonetalon Mountains
    { a = 1442, b = 1440, name = "the Talondeep Path", map = 1440, mx = 0.420, my = 0.710 },     -- Stonetalon Mountains, Ashenvale
    { a = 1440, b = 1439, name = "the road into Darkshore", map = 1440, mx = 0.285, my = 0.140 }, -- Ashenvale, Darkshore
    { a = 1440, b = 1448, name = "the road into Felwood", map = 1440, mx = 0.555, my = 0.280 },  -- Ashenvale, Felwood
    { a = 1440, b = 1447, name = "the road into Azshara", map = 1440, mx = 0.945, my = 0.470 },  -- Ashenvale, Azshara
    { a = 1448, b = 1452, name = "the Timbermaw Hold tunnels", map = 1448, mx = 0.650, my = 0.080, -- Felwood, Winterspring
      warn = "Timbermaw furbolgs attack without reputation" },
    { a = 1448, b = 1450, name = "the Timbermaw tunnel to Moonglade", map = 1450, mx = 0.360, my = 0.720, -- Felwood, Moonglade
      warn = "Timbermaw furbolgs attack without reputation" },
    { a = 1452, b = 2482, name = "Darkwhisper Gorge", map = 1452, mx = 0.590, my = 0.840, unverified = true }, -- Winterspring, Mount Hyjal
    { a = 1452, b = 1450, name = "the Timbermaw tunnel to Moonglade", map = 1452, mx = 0.270, my = 0.350, -- Winterspring, Moonglade
      warn = "Timbermaw furbolgs attack without reputation" },
    -- Blizzard has said Shen'dralas is entered from Desolace by the Valley of Bones; the point is a guess.
    { a = 1443, b = 2652, name = "the Valley of Bones", map = 1443, mx = 0.550, my = 0.850, unverified = true }, -- Desolace, Shen'dralas

    -- Eastern Kingdoms: cities
    { a = 1458, b = 1420, name = "the Ruins of Lordaeron", map = 1420, mx = 0.619, my = 0.648 }, -- Undercity, Tirisfal Glades
    { a = 1453, b = 1429, name = "the Stormwind gates", map = 1429, mx = 0.320, my = 0.490 },    -- Stormwind City, Elwynn Forest
    { a = 1455, b = 1426, name = "the gates of Ironforge", map = 1426, mx = 0.530, my = 0.350 }, -- Ironforge, Dun Morogh
    -- Eastern Kingdoms: zones
    { a = 1420, b = 1421, name = "the road into Silverpine", map = 1420, mx = 0.540, my = 0.740 }, -- Tirisfal Glades, Silverpine Forest
    { a = 1420, b = 1422, name = "the Bulwark", map = 1420, mx = 0.835, my = 0.690 },            -- Tirisfal Glades, Western Plaguelands
    { a = 1421, b = 1424, name = "the road into Hillsbrad", map = 1421, mx = 0.655, my = 0.780 }, -- Silverpine Forest, Hillsbrad Foothills
    { a = 1424, b = 1416, name = "the road into Alterac", map = 1424, mx = 0.550, my = 0.130 },  -- Hillsbrad Foothills, Alterac Mountains
    { a = 1424, b = 1417, name = "Thoradin's Wall", map = 1417, mx = 0.200, my = 0.290 },        -- Hillsbrad Foothills, Arathi Highlands
    { a = 1424, b = 1425, name = "the road into the Hinterlands", map = 1425, mx = 0.070, my = 0.470 }, -- Hillsbrad Foothills, The Hinterlands
    { a = 1416, b = 1422, name = "the road to Chillwind Camp", map = 1422, mx = 0.430, my = 0.850 }, -- Alterac Mountains, Western Plaguelands
    { a = 1422, b = 1423, name = "the Thondroril River bridge", map = 1423, mx = 0.070, my = 0.430 }, -- Western Plaguelands, Eastern Plaguelands
    { a = 1417, b = 1437, name = "the Thandol Span", map = 1417, mx = 0.445, my = 0.880 },       -- Arathi Highlands, Wetlands
    { a = 1437, b = 1432, name = "the Dun Algaz tunnels", map = 1432, mx = 0.250, my = 0.100 },  -- Wetlands, Loch Modan
    { a = 1432, b = 1426, name = "the Valley of Kings gates", map = 1432, mx = 0.200, my = 0.630 }, -- Loch Modan, Dun Morogh
    { a = 1432, b = 1418, name = "the road into the Badlands", map = 1432, mx = 0.470, my = 0.780 }, -- Loch Modan, Badlands
    { a = 1418, b = 1427, name = "the pass into Searing Gorge", map = 1418, mx = 0.060, my = 0.610 }, -- Badlands, Searing Gorge
    { a = 1427, b = 1428, name = "Blackrock Mountain", map = 1427, mx = 0.350, my = 0.840,        -- Searing Gorge, Burning Steppes
      warn = "through Blackrock Mountain" },
    { a = 1428, b = 1433, name = "the pass into Redridge", map = 1428, mx = 0.780, my = 0.850 }, -- Burning Steppes, Redridge Mountains
    { a = 1433, b = 1429, name = "the Three Corners road", map = 1429, mx = 0.930, my = 0.720 }, -- Redridge Mountains, Elwynn Forest
    { a = 1433, b = 1431, name = "the bridge into Duskwood", map = 1431, mx = 0.940, my = 0.100 }, -- Redridge Mountains, Duskwood
    { a = 1429, b = 1436, name = "the Westfall bridge", map = 1429, mx = 0.210, my = 0.800 },    -- Elwynn Forest, Westfall
    { a = 1429, b = 1431, name = "the bridge south of Goldshire", map = 1431, mx = 0.445, my = 0.070 }, -- Elwynn Forest, Duskwood
    { a = 1436, b = 1431, name = "the road into Duskwood", map = 1431, mx = 0.080, my = 0.630 }, -- Westfall, Duskwood
    { a = 1431, b = 1434, name = "the road into Stranglethorn", map = 1434, mx = 0.380, my = 0.030 }, -- Duskwood, Stranglethorn Vale
    { a = 1431, b = 1430, name = "the road into Deadwind Pass", map = 1430, mx = 0.170, my = 0.500 }, -- Duskwood, Deadwind Pass
    { a = 1430, b = 1435, name = "the road into the Swamp of Sorrows", map = 1435, mx = 0.030, my = 0.600 }, -- Deadwind Pass, Swamp of Sorrows
    { a = 1435, b = 1419, name = "the road into the Blasted Lands", map = 1419, mx = 0.520, my = 0.080 }, -- Swamp of Sorrows, Blasted Lands
    -- Riverglades: a turnoff on the Redridge road to the Burning Steppes is reported. Blizzard has said it also
    -- borders the Burning Steppes, the Swamp of Sorrows and the Badlands; where you cross is not known yet.
    { a = 1433, b = 2548, name = "the Riverglades turnoff", map = 1433, mx = 0.550, my = 0.150, unverified = true }, -- Redridge Mountains, Riverglades
    { a = 1428, b = 2548, name = "the Riverglades border", map = 1428, mx = 0.950, my = 0.500, unverified = true }, -- Burning Steppes, Riverglades
    { a = 1435, b = 2548, name = "the Riverglades border", map = 1435, mx = 0.500, my = 0.030, unverified = true }, -- Swamp of Sorrows, Riverglades
    { a = 1418, b = 2548, name = "the Riverglades border", map = 1418, mx = 0.500, my = 0.950, unverified = true }, -- Badlands, Riverglades
}
```

- [ ] **Step 8: Write `GoblinPS/Data/Zones.lua`**

```lua
-- HAND-WRITTEN. The level range of each zone, for the amber warning on a step
-- that takes a low-level character somewhere dangerous. { low, high }.
-- Classic ranges; Forever may have shifted some (check against the in-game
-- map's zone tooltip and correct here). A zone not listed (cities, zones whose
-- range is not known yet) never warns.
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Zones = {
    -- Kalimdor
    [1411] = { 1, 10 },   -- Durotar
    [1412] = { 1, 10 },   -- Mulgore
    [1438] = { 1, 10 },   -- Teldrassil
    [1413] = { 10, 25 },  -- The Barrens
    [1439] = { 10, 20 },  -- Darkshore
    [1442] = { 15, 27 },  -- Stonetalon Mountains
    [1440] = { 18, 30 },  -- Ashenvale
    [1441] = { 25, 35 },  -- Thousand Needles
    [1443] = { 30, 40 },  -- Desolace
    [1445] = { 35, 45 },  -- Dustwallow Marsh
    [1444] = { 40, 50 },  -- Feralas
    [1446] = { 40, 50 },  -- Tanaris
    [1447] = { 45, 55 },  -- Azshara
    [1448] = { 48, 55 },  -- Felwood
    [1449] = { 48, 55 },  -- Un'Goro Crater
    [1452] = { 53, 60 },  -- Winterspring
    [1450] = { 55, 60 },  -- Moonglade
    [1451] = { 55, 60 },  -- Silithus
    [2482] = { 60, 60 },  -- Mount Hyjal
    -- Eastern Kingdoms
    [1420] = { 1, 10 },   -- Tirisfal Glades
    [1426] = { 1, 10 },   -- Dun Morogh
    [1429] = { 1, 10 },   -- Elwynn Forest
    [1421] = { 10, 20 },  -- Silverpine Forest
    [1436] = { 10, 20 },  -- Westfall
    [1432] = { 10, 20 },  -- Loch Modan
    [1433] = { 15, 25 },  -- Redridge Mountains
    [1431] = { 18, 30 },  -- Duskwood
    [1424] = { 20, 30 },  -- Hillsbrad Foothills
    [1437] = { 20, 30 },  -- Wetlands
    [1416] = { 30, 40 },  -- Alterac Mountains
    [1417] = { 30, 40 },  -- Arathi Highlands
    [1434] = { 30, 45 },  -- Stranglethorn Vale
    [1418] = { 35, 45 },  -- Badlands
    [1435] = { 35, 45 },  -- Swamp of Sorrows
    [2548] = { 35, 45 },  -- Riverglades
    [1425] = { 40, 50 },  -- The Hinterlands
    [1427] = { 43, 50 },  -- Searing Gorge
    [1419] = { 45, 55 },  -- Blasted Lands
    [1428] = { 50, 58 },  -- Burning Steppes
    [1422] = { 51, 58 },  -- Western Plaguelands
    [1423] = { 53, 60 },  -- Eastern Plaguelands
    [1430] = { 55, 60 },  -- Deadwind Pass
}
```

- [ ] **Step 9: Replace `GoblinPS/Data/Links.lua`**

```lua
-- HAND-WRITTEN. Boats, zeppelins and the tram: nothing in Blizzard's tables
-- describes them. Later, zone-to-zone ground crossings go here too, as more
-- rows, not a redesign.
--
-- Dock positions are map coords (0..1) on a zone map and are APPROXIMATE:
-- each one is checked in game from docs/manual-test-checklist.md.
-- minutes = the ride plus about half the loop, the average wait. Estimates
-- until timed in game.
-- Every link runs both ways. faction: "A", "H" or "N" (both).
--
-- Not listed until confirmed in game (see the spec): Stormwind Harbor to
-- Auberdine, Menethil to Southshore to Auberdine, Steamwheedle to Powderfuse.
--
-- Sardor Isle (Feathermoon Stronghold) shares Feralas's map (1444), and ground
-- travel is per map, so the isle counts as part of Feralas -- a short swim --
-- and its ferry (Feathermoon <-> Forgotten Coast) is left out: a ride inside
-- the zone would always undercut it. It returns if zones ever get sub-areas.
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Docks = {
    org_zep      = { name = "Orgrimmar Zeppelin Tower", map = 1411, mx = 0.509, my = 0.140 }, -- measured in game
    uc_zep       = { name = "Undercity Zeppelin Tower", map = 1420, mx = 0.608, my = 0.587 }, -- measured in game
    gromgol_zep  = { name = "Grom'gol Zeppelin Tower",  map = 1434, mx = 0.315, my = 0.295 },
    menethil     = { name = "Menethil Harbor Docks",    map = 1437, mx = 0.050, my = 0.600 },
    auberdine    = { name = "Auberdine Docks",          map = 1439, mx = 0.328, my = 0.420 },
    theramore    = { name = "Theramore Docks",          map = 1445, mx = 0.715, my = 0.564 },
    rutheran     = { name = "Rut'theran Village Docks", map = 1438, mx = 0.549, my = 0.968 },
    bootybay     = { name = "Booty Bay Docks",          map = 1434, mx = 0.259, my = 0.731 },
    ratchet      = { name = "Ratchet Docks",            map = 1413, mx = 0.637, my = 0.386 },
    tram_sw      = { name = "Stormwind Tram Station",   map = 1453, mx = 0.640, my = 0.080 },
    tram_if      = { name = "Ironforge Tram Station",   map = 1455, mx = 0.768, my = 0.512 },
}

ns.Data.Links = {
    { from = "org_zep",     to = "uc_zep",      kind = "zeppelin", minutes = 4, faction = "H" },
    { from = "org_zep",     to = "gromgol_zep", kind = "zeppelin", minutes = 4, faction = "H" },
    { from = "uc_zep",      to = "gromgol_zep", kind = "zeppelin", minutes = 4, faction = "H" },
    { from = "menethil",    to = "auberdine",   kind = "boat",     minutes = 4, faction = "A" },
    { from = "menethil",    to = "theramore",   kind = "boat",     minutes = 4, faction = "A" },
    { from = "auberdine",   to = "rutheran",    kind = "boat",     minutes = 3, faction = "A" },
    { from = "bootybay",    to = "ratchet",     kind = "boat",     minutes = 4, faction = "N" },
    { from = "tram_sw",     to = "tram_if",     kind = "tram",     minutes = 2, faction = "A" },
}
```

- [ ] **Step 10: Replace `GoblinPS/Graph.lua`**

```lua
local _, ns = ...

-- Pure: turns the data plus what this character can use into stops and
-- weighted edges. Never touches a Blizzard global.
--
-- Ground travel goes zone by zone. A ride edge joins two points only when
-- they are in the same zone (the same UiMap); a crossing is a point that
-- belongs to both of its zones, so the router chains zones through crossings.
-- Cities are zones and their gates are crossings. A zone with no crossing is
-- an island: links and flights only.
local Graph = {}
ns.Graph = Graph

-- Used when the caller gives no speed: a 60% mount (7 yd/s run speed x 1.6).
-- Core passes the character's real speed from Travel.For(level).
Graph.RIDE_YARDS_PER_SECOND = 11.2
Graph.RIDE_DETOUR = 1.3            -- roads are not straight lines
Graph.HEARTH_SECONDS = 20          -- cast plus loading screen

local function legal(stopFaction, faction)
    return not stopFaction or stopFaction == "N" or stopFaction == faction
end

-- Seconds on the ground between two world positions at a speed in yards per
-- second (default: the 60% mount); math.huge across continents.
function Graph.RideSeconds(a, b, speed)
    return ns.Geo.Distance(a, b) * Graph.RIDE_DETOUR / (speed or Graph.RIDE_YARDS_PER_SECOND)
end

local function addEdge(edges, from, to, edge)
    local list = edges[from]
    if not list then
        list = {}
        edges[from] = list
    end
    edge.to = to
    edge.copper = edge.copper or 0
    list[#list + 1] = edge
end

local function stopFrom(key, p)
    return { key = key, nodeID = p.nodeID, name = p.name, c = p.c, x = p.x, y = p.y,
             map = p.map, mx = p.mx, my = p.my }
end

local function dockStop(data, stops, id)
    if stops[id] then
        return stops[id]
    end
    local d = data.Docks[id]
    if not d then
        return nil
    end
    local c, x, y = ns.Geo.ToWorld(data.Places, d.map, d.mx, d.my)
    if not c then
        return nil
    end
    stops[id] = { key = id, name = d.name, c = c, x = x, y = y, map = d.map, mx = d.mx, my = d.my }
    return stops[id]
end

-- Is this point in zone `map`? A crossing is in both of its zones.
local function inZone(point, map)
    if point.zones then
        return point.zones[1] == map or point.zones[2] == map
    end
    return point.map ~= nil and point.map == map
end

-- The zone two points share, or nil.
local function sharedZone(p, q)
    if p.zones then
        return (inZone(q, p.zones[1]) and p.zones[1]) or (inZone(q, p.zones[2]) and p.zones[2]) or nil
    end
    return p.map and inZone(q, p.map) and p.map or nil
end

-- opts: faction "A"/"H"; known = { [nodeID] = true }; from and to are world
-- places { name, c, x, y, map, mx, my } (to may carry kind = "zone"); hearth
-- is one too, or nil; speed = ground yards per second and walk = true when on
-- foot (both from Travel.For); rough = true adds the old straight lines
-- across a whole continent, flagged rough, for when no chain of crossings
-- reaches the destination.
-- Returns { stops = { [key] = stop }, edges = { [key] = { edge, ... } } }
-- with the special keys START, DEST and HEARTH. A ride edge carries zone (the
-- UiMap it is walked in), walk and, in rough mode, rough.
function Graph.Build(data, opts)
    local stops, edges = {}, {}
    local faction, known, speed = opts.faction, opts.known or {}, opts.speed

    for id, n in pairs(data.Nodes) do
        if known[id] and legal(n.f, faction) then
            local key = "f" .. id
            stops[key] = stopFrom(key, n)
            stops[key].nodeID = id
        end
    end
    for _, f in ipairs(data.Flights) do
        local a, b = "f" .. f[1], "f" .. f[2]
        if stops[a] and stops[b] then
            addEdge(edges, a, b, { kind = "fly", seconds = f[4], copper = f[3] })
        end
    end
    for _, link in ipairs(data.Links) do
        if legal(link.faction, faction) then
            local a, b = dockStop(data, stops, link.from), dockStop(data, stops, link.to)
            if a and b then
                addEdge(edges, a.key, b.key, { kind = link.kind, seconds = link.minutes * 60 })
                addEdge(edges, b.key, a.key, { kind = link.kind, seconds = link.minutes * 60 })
            end
        end
    end
    for i, x in ipairs(data.Crossings or {}) do
        if legal(x.faction, faction) then
            local c, wx, wy = ns.Geo.ToWorld(data.Places, x.map, x.mx, x.my)
            if c then
                local key = "x" .. i
                stops[key] = { key = key, name = x.name, c = c, x = wx, y = wy, map = x.map, mx = x.mx, my = x.my,
                               zones = { x.a, x.b }, warn = x.warn }
            end
        end
    end

    stops.START = stopFrom("START", opts.from)
    stops.DEST = stopFrom("DEST", opts.to)
    if opts.hearth then
        stops.HEARTH = stopFrom("HEARTH", opts.hearth)
        addEdge(edges, "START", "HEARTH", { kind = "hearth", seconds = Graph.HEARTH_SECONDS })
    end

    local keys = {}
    for key in pairs(stops) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    -- A zone destination means "anywhere in the zone": a point already in it
    -- has arrived, so its leg to DEST costs nothing (Route drops a leg that
    -- short). A stop or an exact spot is travelled to as usual.
    local zoneMap = opts.to.kind == "zone" and opts.to.map or nil

    for _, pk in ipairs(keys) do
        for _, qk in ipairs(keys) do
            -- Nothing leaves DEST; nothing but the hearthstone arrives at HEARTH; nothing arrives at START.
            if pk ~= qk and pk ~= "DEST" and qk ~= "START" and qk ~= "HEARTH" then
                local p, q = stops[pk], stops[qk]
                local zone = sharedZone(p, q)
                if zone then
                    local seconds = Graph.RideSeconds(p, q, speed)
                    if qk == "DEST" and zoneMap and inZone(p, zoneMap) then
                        seconds = 0
                    end
                    addEdge(edges, pk, qk, { kind = "ride", seconds = seconds, zone = zone, walk = opts.walk })
                elseif opts.rough and p.c == q.c and (pk == "START" or pk == "HEARTH" or qk == "DEST") then
                    addEdge(edges, pk, qk, { kind = "ride", seconds = Graph.RideSeconds(p, q, speed),
                                             walk = opts.walk, rough = true })
                end
            end
        end
    end

    return { stops = stops, edges = edges }
end

return Graph
```

- [ ] **Step 11: Replace `GoblinPS/Route.lua`**

```lua
local _, ns = ...

-- Pure: shortest path by seconds, the "discover X" hint, and the plain text.
local Route = {}
ns.Route = Route

Route.MIN_RIDE_SECONDS = 5   -- shorter rides mean "you are already there"
Route.HINT_MIN_SECONDS = 120 -- only mention a saving worth having

-- Dijkstra with a linear scan; the graph has about a hundred stops.
local function shortest(graph)
    local dist, prev, done = { START = 0 }, {}, {}
    while true do
        local best, bestKey = math.huge, nil
        for key, d in pairs(dist) do
            if not done[key] and d < best then
                best, bestKey = d, key
            end
        end
        if not bestKey or bestKey == "DEST" then
            break
        end
        done[bestKey] = true
        for _, e in ipairs(graph.edges[bestKey] or {}) do
            local nd = best + e.seconds
            if nd < (dist[e.to] or math.huge) then
                dist[e.to] = nd
                prev[e.to] = { from = bestKey, edge = e }
            end
        end
    end
    return dist.DEST and prev or nil
end

-- One "Fly to X" per flight master visit; drop rides too short to mention.
local function tidy(raw)
    local steps = {}
    for _, s in ipairs(raw) do
        local last = steps[#steps]
        local tooShort = s.kind == "ride" and s.seconds < Route.MIN_RIDE_SECONDS
        if last and last.kind == "fly" and s.kind == "fly" and last.to.key == s.from.key then
            last.to = s.to
            last.seconds = last.seconds + s.seconds
            last.copper = last.copper + s.copper
        elseif not tooShort then
            steps[#steps + 1] = { kind = s.kind, from = s.from, to = s.to, seconds = s.seconds,
                                  copper = s.copper, zone = s.zone, walk = s.walk, rough = s.rough }
        end
    end
    return steps
end

-- Returns { steps, raw, seconds, copper } or nil when there is no route.
-- A step is { kind, from = stop, to = stop, seconds, copper }.
function Route.Find(graph)
    local prev = shortest(graph)
    if not prev then
        return nil
    end
    local raw, key = {}, "DEST"
    while prev[key] do
        local p = prev[key]
        table.insert(raw, 1, { kind = p.edge.kind, from = graph.stops[p.from], to = graph.stops[key],
                               seconds = p.edge.seconds, copper = p.edge.copper,
                               zone = p.edge.zone, walk = p.edge.walk, rough = p.edge.rough })
        key = p.from
    end
    local seconds, copper = 0, 0
    for _, s in ipairs(raw) do
        seconds, copper = seconds + s.seconds, copper + s.copper
    end
    return { steps = tidy(raw), raw = raw, seconds = seconds, copper = copper }
end

-- Zone by zone through crossings. Only when no such route exists, once more
-- with the old straight lines, whose steps come back flagged rough: a hole in
-- the crossings table must never turn into "no route".
function Route.Plan(data, opts)
    local result = Route.Find(ns.Graph.Build(data, opts))
    if result or opts.rough then
        return result
    end
    local again = {}
    for k, v in pairs(opts) do
        again[k] = v
    end
    again.rough = true
    return Route.Find(ns.Graph.Build(data, again))
end

-- Would knowing every flight path help? Returns { names = { first two short
-- names }, more = count of further unknown stops beyond those two (0 if
-- none), seconds = saved or nil when there was no route at all }, or nil
-- when it would not.
function Route.Hint(data, opts, result)
    local all, o = {}, {}
    for id in pairs(data.Nodes) do
        all[id] = true
    end
    for k, v in pairs(opts) do
        o[k] = v
    end
    o.known = all
    local better = Route.Plan(data, o)
    if not better then
        return nil
    end
    if result and result.seconds - better.seconds < Route.HINT_MIN_SECONDS then
        return nil
    end
    local all_names, seen, known = {}, {}, opts.known or {}
    for _, s in ipairs(better.raw) do
        if s.kind == "fly" then
            for _, stop in ipairs({ s.from, s.to }) do
                if not known[stop.nodeID] and not seen[stop.nodeID] then
                    seen[stop.nodeID] = true
                    all_names[#all_names + 1] = ns.Search.ShortName(stop.name)
                end
            end
        end
    end
    if #all_names == 0 then
        return nil
    end
    local names = {}
    for i = 1, math.min(2, #all_names) do
        names[i] = all_names[i]
    end
    return { names = names, more = math.max(0, #all_names - 2),
             seconds = result and (result.seconds - better.seconds) or nil }
end

local VERB = {
    ride = "Ride to", fly = "Fly to", zeppelin = "Zeppelin to",
    boat = "Boat to", tram = "Tram to", hearth = "Hearthstone to",
}
local WAITS = { zeppelin = true, boat = true, tram = true }

function Route.FormatTime(seconds)
    return "~" .. math.max(1, math.floor(seconds / 60 + 0.5)) .. " min"
end

function Route.FormatMoney(copper)
    if copper <= 0 then
        return "free"
    end
    local parts = {}
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

-- Plain and glanceable. No jokes in the directions.
function Route.StepText(step)
    if step.kind == "ride" then
        local verb = step.walk and "Walk" or "Ride"
        if step.rough then
            return verb .. " toward " .. ns.Search.ShortName(step.to.name) .. " (no mapped path)"
        end
        return verb .. " to " .. ns.Search.ShortName(step.to.name)
    end
    local text = VERB[step.kind] .. " " .. ns.Search.ShortName(step.to.name)
    if WAITS[step.kind] then
        text = text .. " (" .. Route.FormatTime(step.seconds) .. " incl. wait)"
    end
    return text
end

local function levels(range)
    if not range then
        return ""
    end
    return " · level " .. (range[1] == range[2] and range[1] or (range[1] .. "-" .. range[2]))
end

-- The small line under a ground step: where it takes you and what to expect.
-- Returns text, warn. warn is true when the zone starts well above the
-- character's level or the crossing carries a hazard note. Other step kinds
-- have no detail ("", false).
function Route.StepDetail(data, step, level)
    if step.kind ~= "ride" or not step.zone then
        return "", false
    end
    local places, zones = data.Places or {}, data.Zones or {}
    local gate = step.to.zones
    local zone = step.zone
    local text
    if gate then
        zone = gate[1] == step.zone and gate[2] or gate[1]   -- the zone being entered
        text = "into " .. (places[zone] and places[zone].name or "the next zone")
    else
        text = "in " .. (places[zone] and places[zone].name or "this zone")
    end
    text = text .. levels(zones[zone])
    local warn = ns.Travel.Dangerous(zones[zone], level)
    if step.to.warn then
        text, warn = text .. " · " .. step.to.warn, true
    end
    return text, warn
end

function Route.HintText(hint)
    local more = hint.more or 0
    local who
    if #hint.names == 1 then
        who = hint.names[1]
    elseif more > 0 then
        who = hint.names[1] .. ", " .. hint.names[2] .. " and " .. more .. " more"
    else
        who = hint.names[1] .. " and " .. hint.names[2]
    end
    if hint.seconds then
        return "Discover " .. who .. " to save " .. Route.FormatTime(hint.seconds)
    end
    return "Discover " .. who .. " to open a route"
end

return Route
```

- [ ] **Step 12: Replace `.luacheckrc`** (exempts the one-row-per-line crossings file from the line-length rule; declares `UnitLevel` for Task 3)

```lua
std = "lua51"
max_line_length = 120
self = false
globals = {
    "SLASH_GOBLINPS1", "SlashCmdList", "GoblinPSDB", "GoblinPSCharDB",
    "GoblinPS_OnAddonCompartmentClick", "UISpecialFrames",
    "GoblinPSMinimapButton", "GoblinPSPlanner",
}
read_globals = {
    "print",
    "UnitFactionGroup", "GetBindLocation", "UnitLevel",
    "C_TaxiMap", "C_Map", "C_Item", "C_SuperTrack", "UiMapPoint",
    "CreateFrame", "Enum",
    "UIParent", "Minimap", "GameTooltip", "GetCursorPosition",
}
files["GoblinPS/Data/Places.lua"] = { max_line_length = false }
files["GoblinPS/Data/Nodes.lua"] = { max_line_length = false }
files["GoblinPS/Data/Flights.lua"] = { max_line_length = false }
-- Hand-written, one crossing per line with its zone names as a trailing comment.
files["GoblinPS/Data/Crossings.lua"] = { max_line_length = false }
-- The UI smoke test installs a fake frame API into the globals.
files["test/fake_frames.lua"] = { globals = { "print" } }
files["test/test_ui.lua"] = { globals = { "print" } }
```

- [ ] **Step 13: Replace `.luarc.json`**

```json
{
  "runtime.version": "Lua 5.1",
  "workspace.ignoreDir": [".remember", ".superpowers", "tools", "docs"],
  "diagnostics.globals": [
    "SLASH_GOBLINPS1", "SlashCmdList", "GoblinPSDB", "GoblinPSCharDB",
    "GoblinPS_OnAddonCompartmentClick", "UISpecialFrames", "GoblinPSMinimapButton", "GoblinPSPlanner",
    "UnitFactionGroup", "GetBindLocation", "UnitLevel",
    "C_TaxiMap", "C_Map", "C_Item", "C_SuperTrack", "UiMapPoint",
    "CreateFrame", "Enum",
    "UIParent", "Minimap", "GameTooltip", "GetCursorPosition"
  ]
}
```

- [ ] **Step 14: Run the Lua tests.** Expected: `155 passed, 0 failed`. The addon's TOC does not list the new data files until Task 3; the desktop runner loads them itself.

- [ ] **Step 15: Run luacheck.** Expected: `Total: 0 warnings / 0 errors`.

- [ ] **Step 16: Commit**

```
git add GoblinPS/Data/Crossings.lua GoblinPS/Data/Zones.lua GoblinPS/Data/Links.lua GoblinPS/Graph.lua GoblinPS/Route.lua test/fake_world.lua test/test_graph.lua test/test_route.lua test/test_data.lua test/test_crossings.lua .luacheckrc .luarc.json
git commit -m "Ground travel goes zone by zone through named crossings" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Level, chat details and two-line step rows

**Files:**
- Replace: `GoblinPS/API.lua`, `GoblinPS/Core.lua`, `GoblinPS/Planner.lua`, `GoblinPS/GoblinPS.toc`, `test/fake_frames.lua`, `test/test_ui.lua`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: `ns.API.Level() -> number or nil`; `Core.PlanRoute`'s answer gains `level`, and its options carry `speed` and `walk`; `/gps to` prints each ground step's detail line under it; planner rows gain `row.detail` (a second, smaller line, amber when `Route.StepDetail` says warn). `Planner.MAX_ROWS` is 8.

- [ ] **Step 1: Replace `test/fake_frames.lua`** (the fake now records the colour a FontString was given)

```lua
-- A tiny stand-in for the WoW frame API, enough to build the GoblinPS windows
-- on the desktop and poke at them. It proves OUR code paths run (no nil
-- calls, no bad field names, the right text lands in the right widget). It
-- proves nothing about how Blizzard's real frames behave: that is what
-- docs/manual-test-checklist.md is for.
local Fake = {}

-- Paths for which SetTexture below reports failure, the way a texture the
-- client cannot find would. Tests add and remove entries; empty by default.
Fake.missingTextures = {}

-- Real widget methods our code calls beyond the ones modelled as full
-- methods below, each checked against the client source. Anything else is a
-- misspelt or invented call, and the fake raises instead of quietly doing
-- nothing, so a bad widget call fails on the desktop instead of only in game.
local ALLOWED_NOOP = {
    SetAllPoints = true, SetColorTexture = true, SetTexCoord = true, SetAlpha = true,
    SetJustifyH = true, SetWordWrap = true, SetFontObject = true,
    SetTextInsets = true, SetMaxLetters = true, SetAutoFocus = true, EnableMouse = true,
    SetMovable = true, SetClampedToScreen = true, RegisterForDrag = true, RegisterForClicks = true,
    StartMoving = true, StopMovingOrSizing = true, SetFrameStrata = true, SetFrameLevel = true,
    SetHighlightTexture = true, RegisterEvent = true, SetOwner = true, AddLine = true,
}

local Region = {}
Region.__index = function(_, key)
    local method = Region[key]
    if method then
        return method
    end
    if ALLOWED_NOOP[key] then
        return function() end
    end
    -- Blizzard's own widget methods are always PascalCase (SetPoint,
    -- GetText, ...); anything shaped like one that we have not modelled or
    -- allow-listed is a misspelt or invented call, so raise. A lowercase key
    -- is the addon's own instance data (row.item, results.owner, ...), not
    -- yet set on this object: real frames answer that with plain nil too.
    if key:match("^%u") then
        error("fake_frames: unknown widget method '" .. key .. "'", 2)
    end
    return nil
end

local function new(kind, parent)
    return setmetatable({ kind = kind, parent = parent, shown = true, text = "", scripts = {}, points = {},
                          width = 0, height = 0 }, Region)
end

function Region:CreateTexture() return new("Texture", self) end
function Region:CreateFontString() return new("FontString", self) end
function Region:SetText(text) self.text = text or "" end
function Region:GetText() return self.text end
function Region:SetTextColor(r, g, b) self.color = { r, g, b } end
function Region:Show() self.shown = true end
function Region:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Region:SetShown(shown) self.shown = shown and true or false end
function Region:IsShown() return self.shown end
-- The real client answers from the cursor; tests set frame.mouseOver by hand.
function Region:IsMouseOver() return self.mouseOver == true end
function Region:SetScript(name, fn) self.scripts[name] = fn end
function Region:GetScript(name) return self.scripts[name] end
function Region:SetSize(w, h) self.width, self.height = w, h end
function Region:SetWidth(w) self.width = w end
function Region:SetHeight(h) self.height = h end
function Region:GetWidth() return self.width end
function Region:GetHeight() return self.height end
function Region:ClearAllPoints()
    self.points = {}
    self.lastPoint = nil
end

-- Normalises every SetPoint overload down to the five values the real
-- GetPoint returns (point, relativeTo, relativePoint, x, y), so a
-- save/restore round trip can be asserted the way the client really answers.
function Region:SetPoint(...)
    local n = select("#", ...)
    local point, relativeTo, relativePoint, x, y
    if n <= 1 then
        point = ...
        x, y = 0, 0
    elseif n == 2 then
        point, relativeTo = ...
        x, y = 0, 0
    elseif n == 3 then
        point, x, y = ...
    elseif n == 4 then
        point, relativeTo, x, y = ...
    else
        point, relativeTo, relativePoint, x, y = ...
    end
    local p = { point, relativeTo, relativePoint or point, x, y }
    self.points[#self.points + 1] = p
    self.lastPoint = p
end

-- Always the last point set, matching how the addon only ever keeps one
-- anchor (ClearAllPoints then a single SetPoint).
function Region:GetPoint()
    local p = self.lastPoint or { "CENTER", nil, "CENTER", 0, 0 }
    return p[1], p[2], p[3], p[4], p[5]
end

function Region:SetEnabled(enabled) self.enabled = enabled end

-- The real SetTexture returns a documented success bool.
function Region:SetTexture(path)
    self.texture = path
    return path ~= nil and not Fake.missingTextures[path]
end
function Region:GetTexture() return self.texture end
function Region:GetCenter() return 100, 100 end
function Region:GetEffectiveScale() return 1 end
function Region:ClearFocus()
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end

-- Test helpers: act like the player.
function Fake.Type(editBox, text)
    editBox:SetText(text)
    editBox.scripts.OnTextChanged(editBox, true)
end
function Fake.Click(button)
    button.scripts.OnClick(button, "LeftButton")
end
function Fake.MouseDown(frame)
    frame.scripts.OnMouseDown(frame, "LeftButton")
end

-- Installs the globals the UI files use. Returns a table of what was printed.
function Fake.Install()
    local printed = {}
    _G.CreateFrame = function(kind, name, parent)
        local f = new(kind, parent)
        if name then _G[name] = f end
        return f
    end
    _G.UIParent = new("Frame")
    _G.Minimap = new("Frame")
    _G.Minimap.width = 140
    _G.GameTooltip = new("GameTooltip")
    _G.UISpecialFrames = {}
    _G.GetCursorPosition = function() return 150, 100 end
    _G.SlashCmdList = {}
    _G.print = function(text) printed[#printed + 1] = text end
    Fake.missingTextures = {}
    return printed
end

return Fake
```

- [ ] **Step 2: Replace `test/test_ui.lua`**

```lua
-- Smoke test of the window code against test/fake_frames.lua. It catches our
-- own mistakes (nil calls, wrong fields, text in the wrong widget). Real frame
-- behaviour is checked in game from docs/manual-test-checklist.md.
-- These tests share one planner and run in order: a later test may rely on
-- state an earlier one left behind.
-- "Self-test passed." can never be reached on the desktop, since the fake
-- defines no font objects; that happy path is checked in game instead.
return function(h)
    local Fake = dofile("test/fake_frames.lua")
    local realPrint = print
    local printed = Fake.Install()

    -- A private addon namespace over the fake world, with a scripted API.
    local ns = { Data = dofile("test/fake_world.lua")() }
    local where = { map = 1, mx = 0.89, my = 0.9 } -- world 1000, 1100: beside Alpha
    local pins, loginCallbacks = {}, {}
    local level = 60 -- mounted, so ground steps say Ride
    ns.API = {
        Faction = function() return "H" end,
        Level = function() return level end,
        PlayerMapPosition = function() return where.map, where.mx, where.my end,
        HearthBindName = function() return nil end,
        TaxiNodes = function() return {} end,
        OpenTaxiNodes = function() return {} end,
        OnTaxiMapOpened = function() end,
        OnLogin = function(callback) loginCallbacks[#loginCallbacks + 1] = callback end,
        SetWaypoint = function(map, x, y)
            pins[#pins + 1] = { map, x, y }
            return true
        end,
        SelfCheck = function() return { { name = "Fake.API", present = true } } end,
    }
    for _, file in ipairs({ "Geo", "Travel", "Search", "Graph", "Route", "Trip", "Known", "Prefs",
                            "Widgets", "Planner", "MinimapButton", "SelfTest", "Core" }) do
        assert(loadfile("GoblinPS/" .. file .. ".lua"))("GoblinPS", ns)
    end
    GoblinPSDB, GoblinPSCharDB = nil, { known = { [1] = true, [2] = true, [4] = true } }

    local Planner = ns.Planner

    h.describe("the planner window", function()
        h.it("opens from the slash command with both layouts' widgets built once", function()
            SlashCmdList.GOBLINPS("")
            local ui = Planner.Debug()
            h.truthy(ui.frame:IsShown())
            h.eq(ui.frame:GetWidth(), Planner.SIZE.wide[1])
            h.eq(ui.known:GetText(), "Flight paths known: 3")
            h.eq(UISpecialFrames[1], "GoblinPSPlanner")
        end)

        h.it("the strict fake raises for a widget method it does not model", function()
            local ui = Planner.Debug()
            local ok, err = pcall(function() return ui.frame.NotAWidgetMethod end)
            h.falsy(ok)
            h.truthy(tostring(err):find("unknown widget method", 1, true))
        end)

        h.it("dragging saves point, relativePoint, x and y", function()
            local ui = Planner.Debug()
            ui.frame:SetPoint("TOP", UIParent, "BOTTOM", 5, -20)
            ui.frame.scripts.OnDragStart(ui.frame)
            ui.frame.scripts.OnDragStop(ui.frame)
            local p = GoblinPSDB.positions.planner
            h.eq(p.point, "TOP")
            h.eq(p.relativePoint, "BOTTOM")
            h.eq(p.x, 5)
            h.eq(p.y, -20)
        end)

        h.it("offers matches as you type and plans when you pick one", function()
            local ui, state = Planner.Debug()
            Fake.Type(ui.toBox, "delt")
            h.truthy(ui.results:IsShown())
            h.eq(ui.results.rows[1].label:GetText(), "Delta  (flight stop)")
            Fake.Click(ui.results.rows[1])
            h.falsy(ui.results:IsShown())
            h.eq(state.to.nodeID, 4)
            h.eq(ui.toBox:GetText(), "Delta")
            h.eq(ui.rows[1].left:GetText(), "1. Ride to Alpha")
            h.eq(ui.rows[2].left:GetText(), "2. Fly to Bravo")
            h.eq(ui.rows[2].right:GetText(), "~4 min  1s")
            h.eq(ui.rows[4].left:GetText(), "4. Zeppelin to East Dock (~4 min incl. wait)")
            h.eq(ui.rows[5].left:GetText(), "5. Ride to Delta")
            h.eq(ui.rows[6].left:GetText(), "")
            h.eq(ui.total:GetText(), "~10 min  1s")
            h.truthy(ui.go.enabled)
        end)

        h.it("clicking Here dismisses the open results list", function()
            local ui = Planner.Debug()
            Fake.Type(ui.toBox, "delt")
            h.truthy(ui.results:IsShown())
            Fake.Click(ui.here)
            h.falsy(ui.results:IsShown())
        end)

        h.it("a mouse-down on the frame body also dismisses the open results list", function()
            local ui = Planner.Debug()
            Fake.Type(ui.toBox, "delt")
            h.truthy(ui.results:IsShown())
            Fake.MouseDown(GoblinPSPlanner)
            h.falsy(ui.results:IsShown())
        end)

        h.it("a click on the list still lands when the client drops edit focus on mouse-down", function()
            -- Seen in game: clicking a row closed the list and picked nothing. The box lost focus on
            -- mouse-down, the list hid, and the row was gone before the click completed.
            local ui, state = Planner.Debug()
            Fake.Type(ui.toBox, "charl")
            ui.results.mouseOver = true          -- the cursor is on the list...
            ui.toBox:ClearFocus()                -- ...when the box loses focus
            h.truthy(ui.results:IsShown(), "the list must survive focus loss while the mouse is on it")
            Fake.Click(ui.results.rows[1])
            ui.results.mouseOver = false
            h.eq(state.to.nodeID, 3)
            h.falsy(ui.results:IsShown())
            -- put the destination back for the tests that follow
            Fake.Type(ui.toBox, "delt")
            Fake.Click(ui.results.rows[1])
            h.eq(state.to.nodeID, 4)
        end)

        h.it("focus loss with the mouse elsewhere still closes the list", function()
            local ui = Planner.Debug()
            Fake.Type(ui.toBox, "delt")
            h.truthy(ui.results:IsShown())
            ui.toBox:ClearFocus()
            h.falsy(ui.results:IsShown())
            ui.toBox:SetText("Delta")
        end)

        h.it("remembers the destination and offers it when the box is empty", function()
            local ui = Planner.Debug()
            h.eq(GoblinPSDB.recents[1], "Delta")
            Fake.Type(ui.toBox, "")
            h.eq(ui.results.rows[1].label:GetText(), "Delta  (flight stop)")
        end)

        h.it("offers the next real recent when the newest one no longer resolves", function()
            local ui = Planner.Debug()
            table.insert(GoblinPSDB.recents, 1, "Ghost Town")
            ui.toBox:SetText("")
            ui.toBox.scripts.OnEditFocusGained(ui.toBox)
            h.eq(ui.results.rows[1].label:GetText(), "Delta  (flight stop)")
            table.remove(GoblinPSDB.recents, 1)
        end)

        h.it("plans from another place", function()
            local ui, state = Planner.Debug()
            Fake.Type(ui.fromBox, "brav")
            Fake.Click(ui.results.rows[1])
            h.eq(state.from.nodeID, 2)
            h.eq(ui.rows[1].left:GetText(), "1. Ride to West Dock")
        end)

        h.it("GO drops a pin on the first step", function()
            local ui = Planner.Debug()
            Fake.Click(ui.go)
            h.eq(#pins, 1)
            h.eq(pins[1][1], 1)
            h.truthy(printed[#printed]:find("Pin set: Ride to West Dock", 1, true))
        end)

        h.it("switches layout with one set of widgets and saves the choice", function()
            local ui = Planner.Debug()
            local rowsBefore = ui.rows
            Fake.Click(ui.layoutButton)
            h.eq(ui.frame:GetWidth(), Planner.SIZE.tall[1])
            h.eq(ui.frame:GetHeight(), Planner.SIZE.tall[2])
            h.eq(GoblinPSDB.layout, "tall")
            h.eq(ui.layoutButton.label:GetText(), "Wide")
            h.truthy(ui.rows == rowsBefore, "the same row widgets")
            h.eq(ui.rows[1].left:GetText(), "1. Ride to West Dock")
        end)

        h.it("Here plans from where you stand again", function()
            local ui, state = Planner.Debug()
            Fake.Click(ui.here)
            h.eq(state.from, nil)
            h.eq(ui.fromBox:GetText(), "")
            h.eq(ui.rows[1].left:GetText(), "1. Ride to Alpha")
        end)

        h.it("shows the plan's notes on the screen when the route has steps", function()
            local ui = Planner.Debug()
            local originalHearthBindName = ns.API.HearthBindName
            ns.API.HearthBindName = function() return "Nowhere Inn Bind" end
            Fake.Click(ui.here)
            h.truthy(ui.notes:GetText():find("Hearth: unknown inn", 1, true))
            ns.API.HearthBindName = originalHearthBindName
            Fake.Click(ui.here)
            h.eq(ui.notes:GetText(), "")
        end)

        h.it("shows an overflow row for a route longer than MAX_ROWS", function()
            local ui, state = Planner.Debug()
            local savedMax, savedPlan = Planner.MAX_ROWS, state.plan
            Planner.MAX_ROWS = 3
            local steps = {}
            for i = 1, 5 do
                steps[i] = { kind = "ride", to = { name = "Stop " .. i }, seconds = 60, copper = 0 }
            end
            state.plan = { to = { name = "Stop 5" }, notes = {}, result = { steps = steps, seconds = 300, copper = 0 } }
            Planner.Refresh()
            h.eq(ui.rows[3].left:GetText(), "... and 3 more steps")
            Planner.MAX_ROWS = savedMax
            state.plan = savedPlan
            Planner.Refresh()
        end)

        h.it("explains itself when it cannot tell where you are", function()
            local ui = Planner.Debug()
            where.map = nil
            Fake.Click(ui.here)
            h.eq(ui.rows[1].left:GetText(), "")
            h.eq(ui.notes:GetText(), "Can't tell where you are. Inside an instance?")
            h.eq(ui.total:GetText(), "")
            h.falsy(ui.go.enabled)
            where.map = 1
            Fake.Click(ui.here)
            h.truthy(ui.go.enabled)
        end)

        h.it("GO re-plans from where you are now instead of using a stale plan", function()
            local ui = Planner.Debug()
            h.eq(ui.rows[1].left:GetText(), "1. Ride to Alpha")
            -- The player moves without touching either box: the planner's
            -- last plan (from near Alpha) is now stale.
            where.mx, where.my = 0.1, 0.9 -- right beside Bravo now
            Fake.Click(ui.go)
            h.eq(ui.rows[1].left:GetText(), "1. Ride to West Dock")
            h.truthy(printed[#printed]:find("Pin set: Ride to West Dock", 1, true))
            h.eq(pins[#pins][1], 1)
            where.mx, where.my = 0.89, 0.9 -- restore for the tests that follow
        end)

        h.it("shows the zero-step case when you are already at the destination", function()
            local ui, state = Planner.Debug()
            Fake.Type(ui.toBox, "westland")
            Fake.Click(ui.results.rows[1])
            h.eq(state.to.name, "Westland")
            h.eq(ui.rows[1].left:GetText(), "")
            h.eq(ui.notes:GetText(), "You're already at Westland.")
            h.eq(ui.total:GetText(), "")
            h.falsy(ui.go.enabled)
        end)

        h.it("closes and reopens without rebuilding", function()
            local ui = Planner.Debug()
            SlashCmdList.GOBLINPS("")
            h.falsy(ui.frame:IsShown())
            SlashCmdList.GOBLINPS("")
            h.truthy(ui.frame:IsShown())
            h.truthy(Planner.Debug() == ui)
        end)
    end)

    h.describe("ground steps in the window", function()
        local amber, dim = ns.Widgets.COLOR.amber, ns.Widgets.COLOR.dim
        local function pickTo(text)
            local ui = Planner.Debug()
            Fake.Type(ui.toBox, text)
            Fake.Click(ui.results.rows[1])
            return ui
        end

        h.it("shows each ground step's zone and levels on a second line", function()
            local ui = pickTo("hotel")
            h.eq(ui.rows[1].left:GetText(), "1. Ride to the North Gate")
            h.eq(ui.rows[1].detail:GetText(), "into Northland · level 30-40 · trolls on the bridge")
            h.eq(ui.rows[2].left:GetText(), "2. Ride to Hotel")
            h.eq(ui.rows[2].detail:GetText(), "in Northland · level 30-40")
            h.eq(ui.rows[3].detail:GetText(), "")
        end)
        h.it("turns the detail amber for a hazard and leaves it dim otherwise", function()
            local ui = Planner.Debug()
            h.eq(ui.rows[1].detail.color[1], amber[1])   -- the crossing carries a hazard note
            h.eq(ui.rows[2].detail.color[1], dim[1])     -- level 60 in a 30-40 zone
        end)
        h.it("says Walk and warns about the zone for a low-level character", function()
            level = 1
            local ui = pickTo("hotel")
            h.eq(ui.rows[1].left:GetText(), "1. Walk to the North Gate")
            h.eq(ui.rows[2].left:GetText(), "2. Walk to Hotel")
            h.eq(ui.rows[2].detail.color[1], amber[1])
            level = 60
        end)
        h.it("labels a straight line when the crossings table has a hole", function()
            local ui = pickTo("lostland")
            h.eq(ui.rows[1].left:GetText(), "1. Ride toward Lostland (no mapped path)")
            h.eq(ui.rows[1].detail:GetText(), "")
            pickTo("delt")
        end)
        h.it("prints the detail under each step in chat too", function()
            local from = #printed
            SlashCmdList.GOBLINPS("to hotel")
            local saw = false
            for i = from + 1, #printed do
                saw = saw or printed[i]:find("into Northland", 1, true) ~= nil
            end
            h.truthy(saw)
        end)
    end)

    h.describe("the minimap button and the compartment", function()
        h.it("appears at login at the saved angle, and hides on request", function()
            h.eq(#loginCallbacks, 1)
            loginCallbacks[1]()
            h.truthy(GoblinPSMinimapButton:IsShown())
            SlashCmdList.GOBLINPS("minimap")
            h.falsy(GoblinPSMinimapButton:IsShown())
            h.eq(GoblinPSDB.minimap.hide, true)
            SlashCmdList.GOBLINPS("minimap")
            h.truthy(GoblinPSMinimapButton:IsShown())
        end)
        h.it("dragging stores the angle from the cursor", function()
            GoblinPSMinimapButton.scripts.OnDragStart(GoblinPSMinimapButton)
            GoblinPSMinimapButton.scripts.OnUpdate(GoblinPSMinimapButton)
            GoblinPSMinimapButton.scripts.OnDragStop(GoblinPSMinimapButton)
            h.eq(GoblinPSDB.minimap.angle, 0) -- cursor is due east of the fake minimap's centre
        end)
        h.it("the compartment entry toggles the planner", function()
            local ui = Planner.Debug()
            local before = ui.frame:IsShown()
            GoblinPS_OnAddonCompartmentClick()
            h.eq(ui.frame:IsShown(), not before)
        end)
    end)

    h.describe("/gps selftest", function()
        h.it("reports every check and the verdict", function()
            local from = #printed
            SlashCmdList.GOBLINPS("selftest")
            h.truthy(#printed - from >= 5)
            h.truthy(printed[#printed]:find("Self%-test"))
        end)

        -- The desktop fake defines none of the client's font globals, so the
        -- font checks always fail here even with no missing texture; that is
        -- unrelated to this fix and pre-dates it. What this proves is the
        -- one thing the ruling is about: a texture the fake is told to
        -- reject adds exactly one more FAIL, for that path, to the count.
        h.it("fails when a texture cannot load", function()
            local badPath = ns.SelfTest.TEXTURES[1]

            SlashCmdList.GOBLINPS("selftest")
            local before = tonumber(printed[#printed]:match("(%d+) failed")) or 0

            Fake.missingTextures[badPath] = true
            local from = #printed
            SlashCmdList.GOBLINPS("selftest")
            Fake.missingTextures[badPath] = nil

            local sawFail = false
            for i = from + 1, #printed do
                if printed[i]:find("FAIL", 1, true) and printed[i]:find(badPath, 1, true) then
                    sawFail = true
                end
            end
            h.truthy(sawFail)
            h.eq(tonumber(printed[#printed]:match("(%d+) failed")), before + 1)
        end)
    end)

    h.describe("/gps to still prints a route in chat", function()
        h.it("uses the same planner as the window", function()
            local from = #printed
            SlashCmdList.GOBLINPS("to delta")
            h.truthy(printed[from + 1]:find("To Delta: ~10 min, 1s", 1, true))
            h.truthy(printed[from + 2]:find("1. Ride to Alpha", 1, true))
        end)
    end)

    print = realPrint
end
```

- [ ] **Step 3: Run the Lua tests.** Expected: failures in the window suite (`attempt to call field 'Level'`, no `row.detail`). That is the RED.

- [ ] **Step 4: Replace `GoblinPS/API.lua`**

```lua
local _, ns = ...

-- The ONLY file that calls Blizzard game APIs (C_*, unit, item, map
-- functions). Everything is defensive: a missing API or an odd return means
-- "unknown", never an error. Core.lua additionally touches Blizzard globals
-- to register the slash command (SLASH_*, SlashCmdList) and print to chat.
local API = {}
ns.API = API

local CONTINENT_MAPS = { 1414, 1415 } -- Kalimdor, Eastern Kingdoms
local HEARTHSTONE = 6948
local REAL_COOLDOWN_SECONDS = 30      -- longer than any global cooldown

-- "A", "H" or nil.
function API.Faction()
    local group = UnitFactionGroup("player")
    if group == "Alliance" then
        return "A"
    elseif group == "Horde" then
        return "H"
    end
    return nil
end

-- The character's level, or nil. Travel.For turns it into walk-or-ride.
function API.Level()
    return UnitLevel and UnitLevel("player") or nil
end

-- Every flight node the client lists, for /gps probe: { { nodeID, name }, ... }.
-- Its isUndiscovered flag is dead on build 1.60.1.69913 (false for every
-- node), so this says nothing about what the character has discovered.
function API.TaxiNodes()
    local out = {}
    if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then
        return out
    end
    for _, map in ipairs(CONTINENT_MAPS) do
        for _, info in ipairs(C_TaxiMap.GetTaxiNodesForMap(map) or {}) do
            out[#out + 1] = { nodeID = info.nodeID, name = info.name }
        end
    end
    return out
end

-- The nodes on the open flight master's map: { { nodeID, name, flyable } }.
-- This is the one moment the client tells the truth: flyable is true for the
-- node you stand at and every node you can fly to. Covers the current
-- continent only. Empty when no flight map is open.
function API.OpenTaxiNodes()
    local out = {}
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and Enum and Enum.FlightPathState) then
        return out
    end
    local getTaxiMapID = rawget(_G, "GetTaxiMapID")
    local map = (getTaxiMapID and getTaxiMapID()) or C_Map.GetBestMapForUnit("player")
    if not map then
        return out
    end
    for _, info in ipairs(C_TaxiMap.GetAllTaxiNodes(map) or {}) do
        out[#out + 1] = { nodeID = info.nodeID, name = info.name,
                          flyable = info.state ~= Enum.FlightPathState.Unreachable }
    end
    return out
end

-- Blizzard's own map pin plus the on-screen arrow. False when this client or
-- this map cannot take a pin.
function API.SetWaypoint(map, x, y)
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end
    if not (map and x and y) or (C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(map)) then
        return false
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    return true
end

-- Calls back once, when the character is in the world and saved variables
-- have loaded.
function API.OnLogin(callback)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN") -- verified in the forever source
    frame:SetScript("OnEvent", callback)
end

-- Calls back every time a flight master's map opens.
function API.OnTaxiMapOpened(callback)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TAXIMAP_OPENED") -- verified in the forever source and in game
    frame:SetScript("OnEvent", callback)
end

-- The player's position on the nearest map we have data for: uiMapID, x, y
-- (0..1). Nil inside instances, on a map we do not know, or when the client
-- reports the origin (an unset position, not a real spot on the map).
local PARENT_HOP_LIMIT = 10 -- generous; a real map hierarchy is a handful deep

function API.PlayerMapPosition(places)
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo and C_Map.GetPlayerMapPosition) then
        return nil
    end
    local map = C_Map.GetBestMapForUnit("player")
    local hops = 0
    while map and map ~= 0 and not places[map] and hops < PARENT_HOP_LIMIT do
        local info = C_Map.GetMapInfo(map)
        map = info and info.parentMapID
        hops = hops + 1
    end
    if not map or map == 0 or not places[map] then
        return nil
    end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then
        return nil
    end
    local x, y = pos:GetXY()
    if x == 0 and y == 0 then
        return nil
    end
    return map, x, y
end

-- The hearthstone's bind name, or nil when it is missing or on cooldown.
-- Absent means absent: the router never waits for it.
function API.HearthBindName()
    if not (C_Item and C_Item.GetItemCount and C_Item.GetItemCooldown) then
        return nil
    end
    if C_Item.GetItemCount(HEARTHSTONE) == 0 then
        return nil
    end
    local start, duration = C_Item.GetItemCooldown(HEARTHSTONE)
    if start and start > 0 and duration and duration > REAL_COOLDOWN_SECONDS then
        return nil
    end
    return GetBindLocation()
end

-- For /gps selftest: every client API this file leans on, and whether it is
-- there. { { name, present }, ... }
function API.SelfCheck()
    local checks = {
        { "C_TaxiMap.GetAllTaxiNodes", C_TaxiMap and C_TaxiMap.GetAllTaxiNodes },
        { "C_TaxiMap.GetTaxiNodesForMap", C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap },
        { "Enum.FlightPathState", Enum and Enum.FlightPathState },
        { "C_Map.GetBestMapForUnit", C_Map and C_Map.GetBestMapForUnit },
        { "C_Map.GetPlayerMapPosition", C_Map and C_Map.GetPlayerMapPosition },
        { "C_Map.SetUserWaypoint", C_Map and C_Map.SetUserWaypoint },
        { "UiMapPoint.CreateFromCoordinates", UiMapPoint and UiMapPoint.CreateFromCoordinates },
        { "C_SuperTrack.SetSuperTrackedUserWaypoint", C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint },
        { "C_Item.GetItemCooldown", C_Item and C_Item.GetItemCooldown },
        { "GetBindLocation", GetBindLocation },
        { "UnitFactionGroup", UnitFactionGroup },
        { "UnitLevel", UnitLevel },
    }
    local out = {}
    for i, check in ipairs(checks) do
        out[i] = { name = check[1], present = check[2] ~= nil and check[2] ~= false }
    end
    return out
end

return API
```

- [ ] **Step 5: Replace `GoblinPS/Core.lua`**

```lua
local _, ns = ...

-- Glue: saved variables, route planning for both the chat command and the
-- planner window, the slash command and the addon compartment entry.
local API, Geo, Search, Route, Known, Prefs = ns.API, ns.Geo, ns.Search, ns.Route, ns.Known, ns.Prefs

local Core = {}
ns.Core = Core

local function say(text)
    print("|cff6fe08aGoblinPS|r " .. text)
end
Core.Say = say

-- ---- saved variables; looked up lazily because they load after this file ----

-- This character's discovered flight paths, learned at flight masters.
local function knownStore()
    GoblinPSCharDB = GoblinPSCharDB or {}
    GoblinPSCharDB.known = GoblinPSCharDB.known or {}
    return GoblinPSCharDB.known
end

-- Account-wide preferences.
local function prefs()
    GoblinPSDB = Prefs.Init(GoblinPSDB)
    return GoblinPSDB
end

function Core.KnownCount() return Known.Count(knownStore()) end
function Core.Faction() return API.Faction() end
function Core.Recents() return prefs().recents end
function Core.Remember(name) Prefs.Remember(prefs(), name) end
function Core.Layout() return prefs().layout end
function Core.ToggleLayout() return Prefs.ToggleLayout(prefs()) end
function Core.Position(window) return Prefs.Position(prefs(), window) end
function Core.SavePosition(window, point, relativePoint, x, y)
    Prefs.SavePosition(prefs(), window, point, relativePoint, x, y)
end
function Core.MinimapPrefs() return prefs().minimap end

-- Escape closes a frame only through its global name.
function Core.CloseOnEscape(frame, globalName)
    _G[globalName] = frame
    table.insert(UISpecialFrames, globalName)
end

-- ---- planning ----

local function here()
    local map, mx, my = API.PlayerMapPosition(ns.Data.Places)
    local c, x, y = Geo.ToWorld(ns.Data.Places, map, mx, my)
    if not c then
        return nil
    end
    return { name = "You", c = c, x = x, y = y, map = map, mx = mx, my = my }
end

-- Plans a route to a place (from Search), from another place or, when from is
-- nil, from where the player stands. Always returns a table:
--   result  Route.Plan's answer, or nil
--   hint    Route.Hint's answer, or nil
--   notes   plain lines for the player; the last one explains a missing route
function Core.PlanRoute(to, from)
    local plan = { to = to, notes = {} }
    local faction = API.Faction()
    if not faction then
        plan.notes[1] = "Pick a faction first."
        return plan
    end
    from = from or here()
    if not from then
        plan.notes[1] = "Can't tell where you are. Inside an instance?"
        return plan
    end
    local bindName = API.HearthBindName()
    local bind = bindName and Search.Exact(ns.Data, bindName, faction) or nil
    if bindName and not bind then
        plan.notes[#plan.notes + 1] = "Hearth: unknown inn (" .. bindName .. "), left out."
    end
    local known = knownStore()
    if not next(known) then
        plan.notes[#plan.notes + 1] =
            "Visit a flight master so GoblinPS can learn your flight paths. Until then, no flights."
    end

    plan.level = API.Level()
    local travel = ns.Travel.For(plan.level)
    local opts = { faction = faction, known = known, from = from, to = to, hearth = bind,
                   speed = travel.speed, walk = travel.walk }
    plan.result = Route.Plan(ns.Data, opts)
    if not plan.result then
        plan.notes[#plan.notes + 1] = "No route found to " .. to.name .. "."
    elseif #plan.result.steps == 0 then
        plan.notes[#plan.notes + 1] = "You're already at " .. to.name .. "."
        return plan
    end
    plan.hint = Route.Hint(ns.Data, opts, plan.result)
    return plan
end

-- Go: for now, Blizzard's map pin and arrow on the first step you travel to.
-- The dash unit takes this over in a later plan.
function Core.Go(plan)
    local step = plan and plan.result and plan.result.steps[1]
    if not step then
        return
    end
    if step.kind == "hearth" then
        say("Use your hearthstone, then press GO again.")
    elseif step.to.map and API.SetWaypoint(step.to.map, step.to.mx, step.to.my) then
        say("Pin set: " .. Route.StepText(step) .. ".")
    else
        say("Can't put a map pin there. " .. Route.StepText(step) .. ".")
    end
end

local function routeTo(text)
    local dest = Search.Find(ns.Data, text, API.Faction(), 1)[1]
    if not dest then
        say('No place matches "' .. text .. '".')
        return
    end
    local plan = Core.PlanRoute(dest)
    for _, note in ipairs(plan.notes) do
        say(note)
    end
    local steps = plan.result and plan.result.steps or {}
    if #steps > 0 then
        say("To " .. dest.name .. ": " .. Route.FormatTime(plan.result.seconds) .. ", "
            .. Route.FormatMoney(plan.result.copper))
        for i, step in ipairs(steps) do
            say(i .. ". " .. Route.StepText(step))
            local detail, warn = Route.StepDetail(ns.Data, step, plan.level)
            if detail ~= "" then
                say("     " .. (warn and "|cfff0b54a" or "|cff9c8f6d") .. detail .. "|r")
            end
        end
    end
    if plan.hint then
        say(Route.HintText(plan.hint))
    end
end

-- Do the client's flight node IDs and names match our generated table, and
-- how many flight paths has this character taught us so far?
local function probe()
    local nodes = API.TaxiNodes()
    local missing, renamed = 0, 0
    for _, node in ipairs(nodes) do
        local ours = ns.Data.Nodes[node.nodeID]
        if not ours then
            missing = missing + 1
            say("not in our data: " .. tostring(node.nodeID) .. " " .. tostring(node.name))
        elseif ours.name ~= node.name then
            renamed = renamed + 1
            say("name differs: " .. node.nodeID .. " ours '" .. ours.name .. "' client '" .. tostring(node.name) .. "'")
        end
    end
    say(("Client lists %d flight nodes. %d not in our data, %d named differently.")
        :format(#nodes, missing, renamed))
    say(("Learned from flight masters so far: %d flight paths."):format(Core.KnownCount()))
end

-- The only moment the client says which flight paths are discovered.
API.OnTaxiMapOpened(function()
    local store = knownStore()
    local added = Known.Learn(store, API.OpenTaxiNodes())
    if added > 0 then
        say(("Learned %d flight path%s here (%d known)."):format(added, added == 1 and "" or "s", Known.Count(store)))
        ns.Planner.Replan()
    end
end)

API.OnLogin(function()
    ns.MinimapButton.Initialize()
end)

local function slash(msg)
    local command, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" then
        ns.Planner.Toggle()
    elseif command == "to" and rest ~= "" then
        routeTo(rest)
    elseif command == "probe" then
        probe()
    elseif command == "selftest" then
        ns.SelfTest.Run(say)
    elseif command == "minimap" then
        ns.MinimapButton.SetHidden(not Core.MinimapPrefs().hide)
        say(Core.MinimapPrefs().hide and "Minimap button hidden. /gps minimap shows it again."
            or "Minimap button shown.")
    else
        say("/gps              open the planner")
        say("/gps to <place>   print a route in chat")
        say("/gps minimap      show or hide the minimap button")
        say("/gps probe        check the flight path data against the client")
        say("/gps selftest     check textures and fonts")
    end
end

SLASH_GOBLINPS1 = "/gps"
SlashCmdList.GOBLINPS = slash

-- Named in the TOC's AddonCompartmentFunc line.
function GoblinPS_OnAddonCompartmentClick()
    ns.Planner.Toggle()
end

return Core
```

- [ ] **Step 6: Replace `GoblinPS/Planner.lua`**

```lua
local _, ns = ...

-- The big device: From and To boxes, the green screen, the step list, the
-- total, the hint and Go. One set of widgets; ApplyLayout only moves them.
-- The schematic map and the dash unit arrive in later plans: for now the
-- screen shows what the device knows, and Go drops Blizzard's map pin on
-- the first step.
local Planner = {}
ns.Planner = Planner

local W = ns.Widgets

Planner.SIZE = { wide = { 660, 400 }, tall = { 390, 600 } }
Planner.MAX_ROWS = 8 -- each step is two lines: the step, then its detail
Planner.MAX_RESULTS = 8
local PAD, HEADER, INPUTS, FOOTER, ROW, STEP_ROW = 10, 30, 26, 64, 18, 32
-- The wide layout's screen keeps this share of the window width; plan 3 (the
-- schematic map) will revisit it once the map needs room too.
local SCREEN_SHARE = 0.42

local ui          -- built on first open
local state = {}  -- from = place or nil ("where you stand"), to = place, plan = Core.PlanRoute's answer

local function stepLine(i, step)
    local cost = ns.Route.FormatTime(step.seconds)
    if step.copper > 0 then
        cost = cost .. "  " .. ns.Route.FormatMoney(step.copper)
    end
    return i .. ". " .. ns.Route.StepText(step), cost
end

-- Paint whatever state.plan holds.
function Planner.Refresh()
    if not ui then
        return
    end
    local plan = state.plan
    local steps = plan and plan.result and plan.result.steps or {}
    for i = 1, Planner.MAX_ROWS do
        local row, step = ui.rows[i], steps[i]
        local left, right, detail, warn = "", "", "", false
        if step and i == Planner.MAX_ROWS and #steps > Planner.MAX_ROWS then
            left = "... and " .. (#steps - i + 1) .. " more steps"
        elseif step then
            left, right = stepLine(i, step)
            detail, warn = ns.Route.StepDetail(ns.Data, step, plan.level)
        end
        row.left:SetText(left)
        row.right:SetText(right)
        row.detail:SetText(detail)
        local c = W.COLOR[warn and "amber" or "dim"]
        row.detail:SetTextColor(c[1], c[2], c[3])
    end

    local total, hint, notes = "", "", ""
    if plan then
        notes = table.concat(plan.notes, "  ")
    end
    if plan and #steps > 0 then
        total = ns.Route.FormatTime(plan.result.seconds) .. "  " .. ns.Route.FormatMoney(plan.result.copper)
    end
    if plan and plan.hint then
        hint = ns.Route.HintText(plan.hint)
    end
    ui.total:SetText(total)
    ui.hint:SetText(hint)
    ui.notes:SetText(notes)
    W.SetButtonEnabled(ui.go, #steps > 0)

    local known = ns.Core.KnownCount()
    ui.known:SetText(known == 0 and "No flight paths yet: open a flight map."
        or ("Flight paths known: " .. known))
end

local function replan()
    state.plan = state.to and ns.Core.PlanRoute(state.to, state.from) or nil
    Planner.Refresh()
end

-- ---- the results list under whichever box has focus ----

local function hideResults()
    ui.results:Hide()
    ui.results.owner = nil
end

-- Puts the results list away and drops focus from both boxes: used wherever
-- clicking something other than a result row should end the search.
local function dismiss()
    ui.fromBox:ClearFocus()
    ui.toBox:ClearFocus()
    hideResults()
end

local function pick(box, item)
    hideResults()
    if box == ui.toBox then
        state.to = item
        ns.Core.Remember(item.name)
    else
        state.from = item
    end
    box:SetText(item.name)
    box:ClearFocus()
    W.UpdatePlaceholder(box)
    replan()
end

-- Matches for the text; with an empty To box, the recent destinations.
local function candidatesFor(box)
    local text = box:GetText()
    if text ~= "" then
        return ns.Search.Find(ns.Data, text, ns.Core.Faction(), Planner.MAX_RESULTS)
    end
    local out = {}
    if box == ui.toBox then
        for _, name in ipairs(ns.Core.Recents()) do
            out[#out + 1] = ns.Search.Exact(ns.Data, name, ns.Core.Faction())
        end
    end
    return out
end

local function showResults(box)
    local items = candidatesFor(box)
    if #items == 0 then
        hideResults()
        return
    end
    for i = 1, Planner.MAX_RESULTS do
        local row, item = ui.results.rows[i], items[i]
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            row.label:SetText(item.name .. (item.kind == "zone" and "" or "  (flight stop)"))
        end
    end
    ui.results.owner = box
    ui.results:ClearAllPoints()
    ui.results:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
    ui.results:SetSize(box:GetWidth(), math.min(#items, Planner.MAX_RESULTS) * ROW + 4)
    ui.results:Show()
end

local function wireBox(box)
    box:SetScript("OnTextChanged", function(self, userInput)
        W.UpdatePlaceholder(self)
        if userInput then
            showResults(self)
        end
    end)
    box:SetScript("OnEditFocusGained", showResults)
    box:SetScript("OnEditFocusLost", function(self)
        -- The client drops edit focus on mouse-down, before a click on a row
        -- completes. With the cursor on the list, leave it for that click.
        if ui.results.owner == self and not ui.results:IsMouseOver() then
            hideResults()
        end
    end)
    box:SetScript("OnEnterPressed", function(self)
        local first = candidatesFor(self)[1]
        if first then
            pick(self, first)
        else
            self:ClearFocus()
        end
    end)
    box:SetScript("OnEscapePressed", function(self)
        hideResults()
        self:ClearFocus()
    end)
end

-- ---- layout: the only thing that differs between wide and tall ----

function Planner.ApplyLayout(mode)
    if not ui then
        return
    end
    local size = Planner.SIZE[mode] or Planner.SIZE.wide
    local f = ui.frame
    f:SetSize(size[1], size[2])

    ui.screen:ClearAllPoints()
    ui.side:ClearAllPoints()
    local top = -(HEADER + INPUTS + PAD)
    if mode == "tall" then
        ui.screen:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, top)
        ui.screen:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, top)
        ui.screen:SetHeight(190)
        ui.side:SetPoint("TOPLEFT", ui.screen, "BOTTOMLEFT", 0, -PAD)
        ui.side:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
    else
        ui.screen:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, top)
        ui.screen:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
        ui.screen:SetWidth(math.floor(size[1] * SCREEN_SHARE))
        ui.side:SetPoint("TOPLEFT", ui.screen, "TOPRIGHT", PAD, 0)
        ui.side:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
    end
    ui.layoutButton.label:SetText(mode == "tall" and "Wide" or "Tall")
end

-- ---- construction ----

local function build()
    local f = W.Panel(UIParent, "body", "brass", 3)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        ns.Core.SavePosition("planner", point, relativePoint, x, y)
    end)
    f:SetScript("OnMouseDown", dismiss)
    f:Hide()

    local stripe = f:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", 3, -3)
    stripe:SetPoint("TOPRIGHT", -3, -3)
    stripe:SetHeight(4)
    stripe:SetColorTexture(W.COLOR.hazard[1], W.COLOR.hazard[2], W.COLOR.hazard[3], 1)

    local title = W.Text(f, "amber", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, -11)
    title:SetText("GoblinPS")
    local tagline = W.Text(f, "dim", "GameFontDisableSmall")
    tagline:SetPoint("LEFT", title, "RIGHT", 8, -1)
    tagline:SetText("Accuracy not guaranteed. No refunds.")

    local close = W.Button(f, "X", 20, 18, function()
        dismiss()
        f:Hide()
    end)
    close:SetPoint("TOPRIGHT", -PAD, -10)
    local layoutButton = W.Button(f, "Tall", 44, 18, function()
        dismiss()
        Planner.ApplyLayout(ns.Core.ToggleLayout())
    end)
    layoutButton:SetPoint("RIGHT", close, "LEFT", -6, 0)

    local fromBox = W.EditBox(f, 150, 20, "From: where you stand")
    fromBox:SetPoint("TOPLEFT", PAD, -(HEADER + 4))
    local toBox = W.EditBox(f, 170, 20, "To: city, zone or flight stop")
    toBox:SetPoint("LEFT", fromBox, "RIGHT", 6, 0)
    local here = W.Button(f, "Here", 40, 20, function()
        dismiss()
        state.from = nil
        ui.fromBox:SetText("")
        W.UpdatePlaceholder(ui.fromBox)
        replan()
    end)
    here:SetPoint("LEFT", toBox, "RIGHT", 6, 0)

    local screen = W.Panel(f, "screen", "steel", 2)
    local notes = W.Text(screen, "dim")
    notes:SetPoint("TOPLEFT", 8, -8)
    notes:SetPoint("TOPRIGHT", -8, -8)
    notes:SetWordWrap(true)
    local known = W.Text(screen, "green")
    known:SetPoint("BOTTOMLEFT", 8, 8)
    known:SetPoint("BOTTOMRIGHT", -8, 8)
    local device = W.Text(screen, "green", "GameFontNormalHuge", "CENTER")
    device:SetPoint("CENTER")
    device:SetText("GoblinPS")
    device:SetAlpha(0.25)

    local side = W.Panel(f, "steel", "steel", 1)
    local rows = {}
    for i = 1, Planner.MAX_ROWS do
        local row = { left = W.Text(side, "green"), right = W.Text(side, "dim", nil, "RIGHT"),
                      detail = W.Text(side, "dim", "GameFontDisableSmall") }
        row.left:SetPoint("TOPLEFT", 8, -(6 + (i - 1) * STEP_ROW))
        row.right:SetPoint("TOPRIGHT", -8, -(6 + (i - 1) * STEP_ROW))
        row.left:SetPoint("TOPRIGHT", row.right, "TOPLEFT", -6, 0)
        row.detail:SetPoint("TOPLEFT", 22, -(6 + (i - 1) * STEP_ROW + 14))
        row.detail:SetPoint("TOPRIGHT", -8, -(6 + (i - 1) * STEP_ROW + 14))
        rows[i] = row
    end
    local hint = W.Text(side, "amber")
    hint:SetPoint("BOTTOMLEFT", 8, FOOTER - 18)
    hint:SetPoint("BOTTOMRIGHT", -8, FOOTER - 18)
    local go = W.Button(side, "GO", 56, 24, function()
        dismiss()
        replan()
        ns.Core.Go(state.plan)
    end)
    go:SetPoint("BOTTOMRIGHT", -8, 8)
    local total = W.Text(side, "green", "GameFontNormal")
    total:SetPoint("BOTTOMLEFT", 8, 12)
    total:SetPoint("RIGHT", go, "LEFT", -8, 0)

    local results = W.Panel(f, "steel", "brass", 1)
    results:SetFrameStrata("DIALOG")
    results:EnableMouse(true)
    results:Hide()
    results.rows = {}
    for i = 1, Planner.MAX_RESULTS do
        local row = CreateFrame("Button", nil, results)
        row:SetHeight(ROW)
        row:SetPoint("TOPLEFT", 2, -(2 + (i - 1) * ROW))
        row:SetPoint("TOPRIGHT", -2, -(2 + (i - 1) * ROW))
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(row)
        hover:SetColorTexture(1, 1, 1, 0.15)
        row.label = W.Text(row, "green")
        row.label:SetPoint("LEFT", 6, 0)
        row.label:SetPoint("RIGHT", -6, 0)
        row:SetScript("OnClick", function(self) pick(results.owner, self.item) end)
        results.rows[i] = row
    end

    ui = { frame = f, fromBox = fromBox, toBox = toBox, screen = screen, side = side, rows = rows,
           hint = hint, total = total, go = go, here = here, known = known, results = results,
           layoutButton = layoutButton, notes = notes }
    wireBox(fromBox)
    wireBox(toBox)
    f:SetScript("OnHide", hideResults)
    ns.Core.CloseOnEscape(f, "GoblinPSPlanner")
end

function Planner.Toggle()
    if not ui then
        build()
        local p = ns.Core.Position("planner")
        ui.frame:ClearAllPoints()
        if p then
            ui.frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
        else
            ui.frame:SetPoint("CENTER")
        end
        Planner.ApplyLayout(ns.Core.Layout())
    end
    if ui.frame:IsShown() then
        ui.frame:Hide()
    else
        ui.frame:Show()
        replan()
    end
end

-- Called when something the route depends on changed (a flight path learned).
function Planner.Replan()
    if ui and ui.frame:IsShown() then
        replan()
    end
end

-- For the desktop smoke test only.
function Planner.Debug()
    return ui, state
end

return Planner
```

- [ ] **Step 7: Replace `GoblinPS/GoblinPS.toc`**

```
## Interface: 16001
## Title: GoblinPS
## Notes: Goblin Positioning System. The fastest route from where you stand. Accuracy not guaranteed. No refunds.
## Author: CoffeeAndLoot
## X-Website: https://github.com/CoffeeAndLoot/goblinps
## IconTexture: Interface\AddOns\GoblinPS\Media\icon
## Version: 2026.09.19.3
## SavedVariables: GoblinPSDB
## SavedVariablesPerCharacter: GoblinPSCharDB
## AddonCompartmentFunc: GoblinPS_OnAddonCompartmentClick

API.lua
Geo.lua
Data\Places.lua
Data\Nodes.lua
Data\Flights.lua
Data\Links.lua
Data\Inns.lua
Data\Crossings.lua
Data\Zones.lua
Travel.lua
Search.lua
Graph.lua
Route.lua
Trip.lua
Known.lua
Prefs.lua
Widgets.lua
Planner.lua
MinimapButton.lua
SelfTest.lua
Core.lua
```

- [ ] **Step 8: Run the Lua tests.** Expected: `160 passed, 0 failed`.

- [ ] **Step 9: Run luacheck** (`Total: 0 warnings / 0 errors`) **and the language server:**

```
lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json
```

Expected: `Diagnosis completed, no problems found`. Report anything else verbatim; do not change this plan's code to silence it.

- [ ] **Step 10: Commit**

```
git add GoblinPS/API.lua GoblinPS/Core.lua GoblinPS/Planner.lua GoblinPS/GoblinPS.toc test/fake_frames.lua test/test_ui.lua
git commit -m "Walk or ride by level; step details in chat and in the planner" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Documents

**Files:**
- Modify: `docs/manual-test-checklist.md`, `docs/superpowers/specs/2026-09-19-goblinps-design.md`, `CLAUDE.md`, `docs/research/2026-09-19-api-and-data-findings.md`

Read each file in full before editing. Make the listed changes and nothing else; when a sentence to change is hard-wrapped across lines, replace the whole sentence and re-wrap only that paragraph to about 78 columns, keeping its indentation.

- [ ] **Step 1: Add this section to the end of `docs/manual-test-checklist.md`**

```markdown
## Ground crossings (plan 3)

Restart the game first: the TOC changed.

- [ ] On a character below level 40 with no flight paths, plan to a zone two
      or more zones away: every ground step says "Walk to ..." and names a
      crossing; none says "(no mapped path)"
- [ ] The undead start: `/gps to mount hyjal` from Tirisfal gives the zeppelin,
      Orgrimmar's front gate, Orgrimmar's west gate, the Mor'shan Rampart, the
      road into Felwood, the Timbermaw Hold tunnels, Darkwhisper Gorge
- [ ] In the planner each ground step has a second, smaller line ("into
      Ashenvale · level 18-30"); it is amber when the zone is well above the
      character's level or the crossing has a hazard, dim otherwise
- [ ] `/gps to` prints the same detail line under each ground step in chat
- [ ] Both layouts: the two-line rows fit, nothing overlaps the hint, the
      total or GO; a route longer than 8 steps ends "... and N more steps"
- [ ] On a level 40+ character the steps say "Ride to ..." and the times are
      shorter. **Record the level at which this character got its first mount
      and its speed**, and the same for the fast mount: `GoblinPS/Travel.lua`
      holds guesses (40 and 60) until then
- [ ] GO on a crossing step puts Blizzard's pin on the crossing
- [ ] **Walk each crossing you pass and check its point.** Stand in the
      gateway, run
      `/run print(C_Map.GetBestMapForUnit("player"), C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit("player"),"player"):GetXY())`
      and compare with the row in `GoblinPS/Data/Crossings.lua`; correct the
      row if it is off by more than 0.03. Record the ones checked here
- [ ] Orgrimmar's west gate: confirm it opens into the Barrens and where
- [ ] New zones, all `unverified = true` in the table: Darkwhisper Gorge into
      Mount Hyjal, the Valley of Bones into Shen'dralas, the Riverglades
      turnoff from Redridge and its borders with the Burning Steppes, the
      Swamp of Sorrows and the Badlands. Record the real crossings
- [ ] Any step that says "(no mapped path)": record from where to where; a
      crossing row is missing
- [ ] Teldrassil still needs the boat; a Darnassus character leaves by "the
      Darnassus gate"
```

- [ ] **Step 2: Correct the spec** (`docs/superpowers/specs/2026-09-19-goblinps-design.md`):
  - In the "`Graph` (pure)" bullet, the sentence saying that from plan 3 "the Feathermoon ferry returns as an ordinary link" is wrong. Replace that clause so the sentence says: the `Islands` table and the 800-yard transfer rule are deleted, and the travel speed comes in with the options; then add the sentence: `Sardor Isle shares Feralas's map, and ground travel is per map, so the isle still counts as part of Feralas and its ferry stays out (a ride inside the zone would always undercut it).`
  - In the "Hand-written for ground travel (plan 3)" list, replace the `Data/Crossings.lua` bullet's sentences about the atlas (from "The atlas fan site has a similar table" to "are our own.") with: `Which zones border which, the place names and the level ranges are facts about Blizzard's game; the Forever Atlas fan site's table served as a checklist of those facts and supplied four crossings the first draft missed. The rows, the wording and every coordinate are our own; the atlas's prose, drawn zone shapes and code are its author's and are not used.` Change "about 55 rows" to "56 rows".
  - In decision 15, after the list of city gates, nothing changes. In "Still to verify in game", the bullet about crossing coordinates: append `Shen'dralas is entered from Desolace by the Valley of Bones (stated by Blizzard); Riverglades also borders the Burning Steppes, the Swamp of Sorrows and the Badlands (stated by Blizzard, crossing points unknown).`
  - In the status paragraph at the top, change `2 planner window (built)` to `2 planner window (built), 3 ground crossings with walk-or-ride by level (built)` and remove the now-duplicated `3 ground crossings with walk-or-ride by level,` that follows, so the list still reads 1 to 5 in order.

- [ ] **Step 3: Update `CLAUDE.md`.**
  - Status paragraph: say plans 1 to 3 are built (routing core, planner window, ground crossings); next is plan 4, the dash unit, then plan 5, the schematic map. Keep the sentence that the product is a GPS.
  - In the layout block, add after the `Data/Inns.lua` line:

```
GoblinPS/Data/Crossings.lua  # HAND-WRITTEN: zone-to-zone crossings and city gates (coords are estimates until walked)
GoblinPS/Data/Zones.lua      # HAND-WRITTEN: level range per zone, for the amber warnings
GoblinPS/Travel.lua          # pure: walk or ride by level; the ONLY place mount levels and speeds live (unconfirmed)
```

  - Under "Rules that are easy to break", add:

```markdown
- Ground travel is per zone: a ride edge joins two points only when they
  share a UiMap, and a crossing belongs to both of its zones. Every place
  handed to the router needs its `map`. A missing crossing shows up as a step
  labelled "(no mapped path)"; add the row to `Data/Crossings.lua`, do not
  loosen the rule. `test/test_crossings.lua` checks every row and that each
  continent's zones all connect.
```

- [ ] **Step 4: Correct `docs/research/2026-09-19-api-and-data-findings.md`.** In the "Forever Atlas" section, replace the sentence that begins `**No license**, so all rights reserved:` (through `its own browser route planner, which cannot know a character's flight paths.` stays) with: `The site has **no license**, which covers its author's own work: the prose, the hand-drawn zone shapes and the code. None of that is used. The facts it records (which zones border which, place names, level ranges, which routes Blizzard has announced) are facts about Blizzard's game and are used freely, as a checklist against our own tables.`

- [ ] **Step 5: Run the Lua tests and luacheck once more** (`160 passed, 0 failed`, `0 warnings`), then commit

```
git add docs CLAUDE.md
git commit -m "Docs: ground crossings checklist, spec corrections, atlas facts" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 6: Hand over.** In your report: the desktop work is verified; nothing in this plan has run in the game client; the user must restart the game (the TOC changed) and work through `## Ground crossings (plan 3)`. Do not claim any of those checks pass.

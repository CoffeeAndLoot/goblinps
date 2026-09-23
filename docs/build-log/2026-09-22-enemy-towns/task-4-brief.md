### Task 4: the graph charges a leg past an enemy town, and bends through stopovers

**Files:**
- Modify: `GoblinPS/Graph.lua` (constants after line 18; four functions after
  `legal`, line 24; the `Graph.Build` comment, lines 97-101; the stopovers
  after the crossings loop, line 149; the pair loop, lines 170-188)
- Modify: `GoblinPS/Route.lua` (`tidy`, lines 47-49; `Route.Find`'s comment
  and `raw`, lines 56-57 and 66-69)
- Test: `test/test_graph.lua` (a new block at the end),
  `test/test_crossings.lua` (three new tests before "leaves a city by its
  gate"; two existing tests follow the new data)

**Interfaces:**
- Consumes: `Geo.SegmentDistance` (Task 2), `Geo.Distance`, `Geo.ToWorld`,
  `Search.ShortName`, `data.Towns[].f` (Task 1), `data.Stopovers` (Task 3;
  may be nil: the fake world has none).
- Produces:
  - `Graph.HOSTILE_SECONDS = 600`, `Graph.HOSTILE_RADIUS = 150`,
    `Graph.CAPITAL_RADIUS = 400`.
  - `Graph.Hostile(data, faction) -> { { name, f, c, x, y, map, radius, rank }, ... }`,
    rank 1 a flight master, 2 a marked town; sorted by `rank`, `name`, `map`,
    `x`, `y`; `{}` when `faction` is nil.
  - `Graph.HostileAt(data, faction, point) -> hostile place | nil`: the first
    whose circle (`<= radius`) holds the world point.
  - A ride edge from `Graph.Build` (shared-zone or rough) may carry
    `danger = { name, f }`, its `seconds` already including
    `Graph.HOSTILE_SECONDS`. Fly, link, hearth and through edges never do.
  - Stops `s1`, `s2`... from `data.Stopovers`, each
    `{ key, name, c, x, y, map, mx, my, unverified, stopover = true }`.
  - `Route.Find(graph)`'s `raw` rows and `steps` carry `danger` from the
    edge. Task 5 words it.

- [ ] **Step 1: Write the failing graph tests**

In `test/test_graph.lua`, the file ends

```lua
            h.falsy(edgeTo(g, "x2", "DEST"), "the near mouth is in another zone")
        end)
    end)
end
```

Insert directly before that final `end` a blank line and this block (so the
new `h.describe` sits inside the returned function, after the last one):

```lua
    h.describe("enemy towns", function()
        -- A world of its own on continent 7. Every zone is 10000 yards square,
        -- so map coords convert as world x = 10000 - my * 10000,
        -- y = 10000 - mx * 10000. Keep, an Alliance flight master, stands at
        -- world (5000, 5000) in Vale (20), right on the straight line from
        -- West (5000, 9000) to East (5000, 1000). Hill (21) shares the
        -- continent and no crossing; Castle City (22) is a capital's zone.
        local function vale()
            return {
                Places = {
                    [20] = { name = "Vale", c = 7, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.5, ay = 0.5 },
                    [21] = { name = "Hill", c = 7, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.5, ay = 0.5 },
                    [22] = { name = "Castle City", c = 7, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.5, ay = 0.5 },
                },
                Nodes = {
                    [1] = { name = "Keep, Vale", f = "A", c = 7, x = 5000, y = 5000, map = 20, mx = 0.5, my = 0.5 },
                },
                Flights = {}, Links = {}, Crossings = {},
            }
        end
        local west = { name = "West", c = 7, x = 5000, y = 9000, map = 20 }
        local east = { name = "East", c = 7, x = 5000, y = 1000, map = 20 }
        local function edge(g, a, b, kind)
            for _, e in ipairs(g.edges[a] or {}) do
                if e.to == b and (not kind or e.kind == kind) then
                    return e
                end
            end
        end
        local function straight(w, faction, from, to, extra)
            local opts = { faction = faction, known = {}, from = from, to = to }
            for k, v in pairs(extra or {}) do
                opts[k] = v
            end
            return edge(Graph.Build(w, opts), "START", "DEST")
        end
        local function names(list)
            local out = {}
            for i, place in ipairs(list) do
                out[i] = place.name .. " " .. place.radius
            end
            return table.concat(out, ", ")
        end
        local function near(a, b) return math.abs(a - b) < 0.001 end

        h.it("lists the other side's flight master, 150 yards round, and nothing to its own side", function()
            local list = Graph.Hostile(vale(), "H")
            h.eq(names(list), "Keep 150")
            h.eq(list[1].f, "A")
            h.eq(list[1].c, 7)
            h.truthy(near(list[1].x, 5000) and near(list[1].y, 5000))
            h.eq(#Graph.Hostile(vale(), "A"), 0)
            h.eq(#Graph.Hostile(vale(), nil), 0, "with no faction, nothing is hostile")
        end)
        h.it("never counts a neutral stop, a town with no faction, or your own side's town", function()
            local w = vale()
            w.Nodes[1].f = "N"
            w.Towns = { [7] = { name = "Mill", c = 7, x = 3000, y = 3000, map = 20, mx = 0.7, my = 0.7 },
                        [8] = { name = "Camp", f = "H", c = 7, x = 2000, y = 2000, map = 20, mx = 0.8, my = 0.8 } }
            h.eq(names(Graph.Hostile(w, "H")), "")
        end)
        h.it("counts a town the owner marked, after the flight masters", function()
            local w = vale()
            w.Towns = { [7] = { name = "Mill", c = 7, x = 3000, y = 3000, map = 20, mx = 0.7, my = 0.7 },
                        [8] = { name = "Abbey", f = "A", c = 7, x = 2000, y = 2000, map = 20, mx = 0.8, my = 0.8 },
                        [9] = { name = "Fort", f = "A", c = 7, x = 1000, y = 1000, map = 20, mx = 0.9, my = 0.9 } }
            h.eq(names(Graph.Hostile(w, "H")), "Keep 150, Abbey 150, Fort 150",
                 "the flight master, then the marked towns by name; Mill is not marked")
        end)
        h.it("names a leg after the surer of two enemy places it passes, not the first by name", function()
            local w = vale()
            w.Towns = { [8] = { name = "Cave", f = "A", c = 7, x = 5000, y = 6000, map = 20, mx = 0.4, my = 0.5 } }
            h.eq(straight(w, "H", west, east).danger.name, "Keep", "a flight master is surer than a marked town")
        end)
        h.it("skips an enemy flight master whose name one of your own shares: that town is neutral", function()
            local w = vale()
            w.Nodes[2] = { name = "Keep, Vale", f = "H", c = 7, x = 5050, y = 5000, map = 20, mx = 0.5, my = 0.495 }
            h.eq(names(Graph.Hostile(w, "H")), "")
        end)
        h.it("draws a capital's circle 400 yards round: the place named after its own zone", function()
            local w = vale()
            w.Nodes[3] = { name = "Castle, Castle City", f = "A", c = 7, x = 8000, y = 8000, map = 22,
                           mx = 0.2, my = 0.2 }
            h.eq(names(Graph.Hostile(w, "H")), "Castle 400, Keep 150")
        end)
        h.it("finds the hostile place a point stands in, and none outside every circle", function()
            h.eq(Graph.HostileAt(vale(), "H", { c = 7, x = 5100, y = 5000 }).name, "Keep")
            h.eq(Graph.HostileAt(vale(), "H", { c = 7, x = 5151, y = 5000 }), nil)
            h.eq(Graph.HostileAt(vale(), "A", { c = 7, x = 5000, y = 5000 }), nil, "not to its own side")
        end)
        h.it("charges a leg through an enemy town ten minutes more and names the town on it", function()
            local e = straight(vale(), "H", west, east)
            h.eq(e.kind, "ride")
            h.eq(e.danger.name, "Keep")
            h.eq(e.danger.f, "A")
            h.truthy(near(e.seconds, Graph.RideSeconds(west, east) + 600))
        end)
        h.it("counts a leg that passes right at the radius, and not one a yard wider", function()
            local w = vale()
            w.Nodes[1].x = 5150
            h.eq(straight(w, "H", west, east).danger.name, "Keep")
            w.Nodes[1].x = 5151
            local e = straight(w, "H", west, east)
            h.eq(e.danger, nil)
            h.truthy(near(e.seconds, Graph.RideSeconds(west, east)), "and no penalty")
        end)
        h.it("leaves the leg alone for the side whose town it is", function()
            local e = straight(vale(), "A", west, east)
            h.eq(e.danger, nil)
            h.truthy(near(e.seconds, Graph.RideSeconds(west, east)))
        end)
        h.it("exempts a leg that starts or ends inside the circle: you are there, or going there", function()
            local gate = { name = "Keep Gate", c = 7, x = 5000, y = 5100, map = 20 }
            h.eq(straight(vale(), "H", west, gate).danger, nil, "going there on purpose")
            h.eq(straight(vale(), "H", gate, east).danger, nil, "leaving it")
        end)
        h.it("never charges a flight, a boat, the hearthstone or a tunnel's passage, even over the town", function()
            local w = vale()
            w.Nodes[4] = { name = "Westfort, Vale", f = "H", c = 7, x = 5000, y = 9000, map = 20, mx = 0.1, my = 0.5 }
            w.Nodes[5] = { name = "Eastfort, Vale", f = "H", c = 7, x = 5000, y = 1000, map = 20, mx = 0.9, my = 0.5 }
            w.Flights = { { 4, 5, 100, 90 } }
            -- Two docks 3000 yards either side of Keep, joined by a boat.
            w.Docks = { west_dock = { name = "West Dock", map = 20, mx = 0.2, my = 0.5 },
                        east_dock = { name = "East Dock", map = 20, mx = 0.8, my = 0.5 } }
            w.Links = { { from = "west_dock", to = "east_dock", kind = "boat", minutes = 2 } }
            -- A tunnel from Vale into Hill, its mouths 1000 yards either side of Keep.
            w.Crossings = { { a = 20, b = 21, name = "the Keep tunnel", map = 20, mx = 0.5, my = 0.4,
                              far = { map = 21, mx = 0.5, my = 0.6 } } }
            local inn = { name = "Eastfort Inn", c = 7, x = 5000, y = 1100, map = 20 }
            local g = Graph.Build(w, { faction = "H", known = { [4] = true, [5] = true }, from = west, to = east,
                                       hearth = inn })
            local fly = edge(g, "f4", "f5", "fly")
            h.eq(fly.seconds, 90)
            h.eq(fly.danger, nil)
            h.eq(edge(g, "f4", "f5", "ride").danger.name, "Keep", "riding the same line is charged")
            local boat = edge(g, "west_dock", "east_dock", "boat")
            h.eq(boat.seconds, 120)
            h.eq(boat.danger, nil)
            local hearth = edge(g, "START", "HEARTH", "hearth")
            h.eq(hearth.seconds, Graph.HEARTH_SECONDS)
            h.eq(hearth.danger, nil)
            local through = edge(g, "x1", "x1far")
            h.eq(through.through, true)
            h.eq(through.danger, nil)
            h.truthy(near(through.seconds, Graph.RideSeconds(g.stops.x1, g.stops.x1far)))
        end)
        h.it("tests a rough straight line the same way", function()
            local over = { name = "Over The Hill", c = 7, x = 5000, y = 1000, map = 21 }
            local e = straight(vale(), "H", west, over, { rough = true })
            h.eq(e.rough, true)
            h.eq(e.danger.name, "Keep")
            h.truthy(near(e.seconds, Graph.RideSeconds(west, over) + 600))
        end)
        h.it("adds a stopover as an ordinary point in its zone, and the route goes round through it", function()
            local w = vale()
            -- world (5400, 5000): 400 yards north of Keep, clear of its circle
            w.Stopovers = { { name = "the north road", map = 20, mx = 0.5, my = 0.46 },
                            { name = "on no map", map = 99, mx = 0.5, my = 0.5 } }
            local g = Graph.Build(w, { faction = "H", known = {}, from = west, to = east })
            local s = g.stops.s1
            h.eq(s.name, "the north road")
            h.eq(s.map, 20)
            h.eq(s.zones, nil, "one zone only, like a tunnel's mouth")
            h.truthy(near(s.x, 5400) and near(s.y, 5000))
            h.eq(g.stops.s2, nil, "a stopover on a map we do not have is left out")
            h.eq(edge(g, "START", "s1").danger, nil)
            h.eq(edge(g, "s1", "DEST").danger, nil)
            local r = loaded.ns.Route.Find(g)
            h.eq(#r.steps, 2)
            h.eq(r.steps[1].to.key, "s1")
            h.eq(loaded.ns.Route.StepText(r.steps[1]), "Ride to the north road")
            h.eq(r.steps[2].to.key, "DEST")
            h.eq(r.steps[1].danger, nil)
            h.eq(r.steps[2].danger, nil)
        end)
        h.it("still goes straight through with no way round, the danger on its step", function()
            local r = loaded.ns.Route.Find(Graph.Build(vale(), { faction = "H", known = {}, from = west, to = east }))
            h.eq(#r.steps, 1)
            h.eq(r.steps[1].danger.name, "Keep")
            h.eq(r.raw[1].danger.name, "Keep")
        end)
    end)
```

- [ ] **Step 2: Write the failing real-data tests**

Insert into `test/test_crossings.lua` directly before

```lua
        h.it("leaves a city by its gate", function()
```

this block:

```lua
        -- The owner's route on 2026-09-22: from the Talondeep Path's Ashenvale
        -- mouth, measured in game at 42.3, 71.1, the straight line to
        -- Splintertree Post runs 97 yards from Silverwind Refuge (50.1, 66.2),
        -- whose guards killed a level 15 Horde player there more than once.
        local function fromTalondeep(faction)
            local c, x, y = ns.Geo.ToWorld(data.Places, 1440, 0.423, 0.711)
            local walker = ns.Travel.For(15)
            return { faction = faction, known = {}, speed = walker.speed, walk = walker.walk,
                     from = { name = "You", c = c, x = x, y = y, map = 1440, mx = 0.423, my = 0.711 },
                     to = ns.Search.Exact(data, "Splintertree Post", faction) }
        end
        local function straightLine(opts)
            for _, e in ipairs(ns.Graph.Build(data, opts).edges.START) do
                if e.to == "DEST" then
                    return e
                end
            end
        end
        h.it("charges the Horde's straight line past Silverwind Refuge, and walks it round by the north", function()
            local opts = fromTalondeep("H")
            local line = straightLine(opts)
            h.eq(line.danger and line.danger.name, "Silverwind Refuge")
            h.eq(line.danger.f, "A")
            local silverwind
            for _, enemy in ipairs(ns.Graph.Hostile(data, "H")) do
                if enemy.name == "Silverwind Refuge" then
                    silverwind = enemy
                end
            end
            h.truthy(silverwind, "tools/town-factions.csv marks Silverwind Refuge Alliance")
            local r = ns.Route.Plan(data, opts)
            -- 307 seconds longer on foot than the straight line, inside its ten
            -- minutes; the way by the Mor'shan Rampart passes Silverwing Grove.
            h.eq(table.concat(texts(r), " / "), "Walk to the Ashenvale-Felwood road / Walk to Splintertree Post")
            for _, s in ipairs(r.steps) do
                h.eq(s.danger, nil)
                h.truthy(ns.Geo.SegmentDistance(s.from, s.to, silverwind) > silverwind.radius,
                         ns.Route.StepText(s) .. " passes Silverwind Refuge")
            end
        end)
        h.it("walks the Alliance straight there: nothing on that line is hostile to it", function()
            for _, enemy in ipairs(ns.Graph.Hostile(data, "A")) do
                h.truthy(enemy.name ~= "Silverwind Refuge", "Silverwind Refuge is hostile to the Alliance")
            end
            local opts = fromTalondeep("A")
            h.eq(straightLine(opts).danger, nil)
            local r = ns.Route.Plan(data, opts)
            h.eq(table.concat(texts(r), " / "), "Walk to Splintertree Post")
            h.eq(r.steps[1].danger, nil)
        end)
        h.it("counts the other side's flight masters and marked towns, and draws capitals wider", function()
            local function summary(faction)
                local stops, towns, capitals = 0, 0, {}
                for _, enemy in ipairs(ns.Graph.Hostile(data, faction)) do
                    if enemy.rank == 1 then
                        stops = stops + 1
                    else
                        towns = towns + 1
                    end
                    if enemy.radius == ns.Graph.CAPITAL_RADIUS then
                        capitals[#capitals + 1] = enemy.name
                    end
                end
                table.sort(capitals)
                return stops, towns, table.concat(capitals, ", ")
            end
            local marked = { A = 0, H = 0 }
            for _, t in pairs(data.Towns) do
                if t.f then
                    marked[t.f] = marked[t.f] + 1
                end
            end
            local stops, towns, capitals = summary("H")
            h.eq(stops, 24, "32 Alliance flight masters less the 8 split neutral towns")
            h.eq(towns, marked.A, "every town the owner marked Alliance, and no other")
            h.truthy(towns > 0, "a count of nothing proves nothing")
            h.eq(capitals, "Ironforge, Stormwind", "Darnassus has no flight master and is not marked")
            stops, towns, capitals = summary("A")
            h.eq(stops, 23, "31 Horde flight masters less the same 8")
            h.eq(towns, marked.H, "every town the owner marked Horde, and no other")
            h.eq(capitals, "Orgrimmar, Thunder Bluff, Undercity")
        end)
```

- [ ] **Step 3: Bring two existing real routes up to the marked towns**

In "walks a new undead from Tirisfal to Mount Hyjal zone by zone", replace

```lua
            h.eq(t[5], "Walk to the Mor'shan Rampart")
            h.eq(t[6], "Walk to the Ashenvale-Felwood road")
            h.eq(t[7], "Walk to the Timbermaw Hold tunnels")
            h.eq(t[8], "Walk to Darkwhisper Gorge")
            h.eq(t[9], "Walk to Summit of Eternity", "on to a place in Mount Hyjal, not stopping at its border")
            h.eq(#t, 9)
```

with

```lua
            h.eq(t[5], "Walk to the Mor'shan Rampart")
            -- Round by the Darkshore road: the straight line from the rampart to
            -- the Felwood road passes Silverwing Outpost, which the owner marked
            -- Alliance in tools/town-factions.csv.
            h.eq(t[6], "Walk to the Ashenvale-Darkshore road")
            h.eq(t[7], "Walk to the Ashenvale-Felwood road")
            h.eq(t[8], "Walk to the Timbermaw Hold tunnels")
            h.eq(t[9], "Walk to Darkwhisper Gorge")
            h.eq(t[10], "Walk to Summit of Eternity", "on to a place in Mount Hyjal, not stopping at its border")
            h.eq(#t, 10)
```

In "explains each ground step and warns a low-level character", the tunnel
and Hyjal steps move down one; replace

```lua
            text, warn = ns.Route.StepDetail(data, r.steps[7], 60)
            h.eq(text, "into Winterspring · Timbermaw furbolgs attack without reputation")
            h.eq(warn, true)
            text, warn = ns.Route.StepDetail(data, r.steps[8], 60)
            h.eq(text, "into Mount Hyjal · crossing not confirmed")
```

with

```lua
            text, warn = ns.Route.StepDetail(data, r.steps[8], 60)
            h.eq(text, "into Winterspring · Timbermaw furbolgs attack without reputation")
            h.eq(warn, true)
            text, warn = ns.Route.StepDetail(data, r.steps[9], 60)
            h.eq(text, "into Mount Hyjal · crossing not confirmed")
```

Replace the tunnel test's first line,

```lua
        h.it("goes through the Talondeep Path from Sun Rock Retreat to Splintertree Post", function()
```

with

```lua
        -- Zoram'gar Outpost, not Splintertree Post: from Sun Rock the way to
        -- Splintertree now stays out of Ashenvale's marked Alliance south, down
        -- the Stonetalon pass and up through the Mor'shan Rampart.
        h.it("goes through the Talondeep Path from Sun Rock Retreat to Zoram'gar Outpost", function()
```

and in the same test replace

```lua
            local to = ns.Search.Exact(data, "Splintertree Post", "H")
            h.truthy(to, "no Splintertree Post")
```

with

```lua
            local to = ns.Search.Exact(data, "Zoram'gar Outpost", "H")
            h.truthy(to, "no Zoram'gar Outpost")
```

The rest of that test (the approach to the Stonetalon mouth, the step
through, "into Ashenvale") holds unchanged: from Sun Rock Retreat the route
to Zoram'gar Outpost is the Talondeep Path, through it, then Zoram'gar.

- [ ] **Step 4: Run the Lua gate to see them fail**

Expected: `479 passed, 18 failed`. Failing: in "enemy towns", the six that
call `Graph.Hostile` or `Graph.HostileAt` (`attempt to call field 'Hostile'
(a nil value)`) and the seven that read `danger` or `g.stops.s1` ("names a
leg after the surer...", "charges a leg...", "counts a leg that passes right
at the radius...", "never charges a flight, a boat...", "tests a rough
straight line...", "adds a stopover...", "still goes straight through...":
`attempt to index ... (a nil value)`); in "real routes on the ground", the
three new ones and the two brought up to date in Step 3 (with no penalty the
walk to Hyjal still takes the old nine steps). Two new graph tests already
pass, as they should with no penalty at all: "leaves the leg alone for the
side whose town it is" and "exempts a leg that starts or ends inside the
circle"; so does the tunnel test, now to Zoram'gar Outpost.

- [ ] **Step 5: `GoblinPS/Graph.lua`, the constants**

Insert directly after

```lua
Graph.HEARTH_SECONDS = 20          -- cast plus loading screen
```

this block:

```lua
-- A ride leg that passes an enemy town costs this much more: a penalty, not
-- a ban, so the router goes round whenever a way round is within ten minutes
-- and a destination is never made unreachable. The two radii are guesses
-- until walked: the closest reading at Silverwind Refuge, where the guards
-- killed a level 15 Horde player on 2026-09-22, was about 40 yd from its map
-- label, so 150 errs wide.
Graph.HOSTILE_SECONDS = 600
Graph.HOSTILE_RADIUS = 150         -- yards around an enemy town or flight master
Graph.CAPITAL_RADIUS = 400         -- yards around an enemy capital's
```

- [ ] **Step 6: `GoblinPS/Graph.lua`, the hostile places**

Insert directly after

```lua
local function legal(stopFaction, faction)
    return not stopFaction or stopFaction == "N" or stopFaction == faction
end
```

a blank line and this block:

```lua
-- A capital is the one place named after the zone it stands in: "Orgrimmar"
-- in Orgrimmar, "Stormwind" in Stormwind City, and the town Darnassus in
-- Darnassus once tools/town-factions.csv marks it. Moonglade's two flight
-- masters are named so too, but they are twins (see Graph.Hostile), so never
-- hostile.
local function isCapital(data, name, map)
    local zone = data.Places[map]
    return zone ~= nil and zone.name:find(name, 1, true) == 1
end

-- Every place whose guards attack this faction, as { name, f, c, x, y, map,
-- radius, rank }: only places whose faction is known. Two sources, surest
-- first:
--   rank 1  the other side's flight masters, bar one whose short name a stop
--           this faction may use shares (Booty Bay, Gadgetzan, Everlook...:
--           the town is neutral, only its flight masters are split);
--   rank 2  the other side's towns, by the `f` Data/Towns.lua carries, which
--           comes only from the owner's marks in tools/town-factions.csv.
-- A place with no faction, or "N", is nobody's enemy. No faction, no list.
-- Sorted by rank, then name, map and position: when a leg passes two, it is
-- named after the surer one, and always the same one.
function Graph.Hostile(data, faction)
    local list = {}
    if not faction then
        return list
    end
    local usable = {}
    for _, n in pairs(data.Nodes) do
        if legal(n.f, faction) then
            usable[ns.Search.ShortName(n.name)] = true
        end
    end
    local function add(name, f, place, rank)
        if f and not legal(f, faction) then
            list[#list + 1] = { name = name, f = f, c = place.c, x = place.x, y = place.y, map = place.map,
                                rank = rank, radius = isCapital(data, name, place.map) and Graph.CAPITAL_RADIUS
                                    or Graph.HOSTILE_RADIUS }
        end
    end
    for _, n in pairs(data.Nodes) do
        local name = ns.Search.ShortName(n.name)
        if not usable[name] then
            add(name, n.f, n, 1)
        end
    end
    for _, t in pairs(data.Towns or {}) do
        add(t.name, t.f, t, 2)
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.name ~= b.name then return a.name < b.name end
        if a.map ~= b.map then return a.map < b.map end
        if a.x ~= b.x then return a.x < b.x end
        return a.y < b.y
    end)
    return list
end

-- The first hostile place whose circle holds this world point, or nil. The
-- planner warns when a destination is one.
function Graph.HostileAt(data, faction, point)
    for _, h in ipairs(Graph.Hostile(data, faction)) do
        if ns.Geo.Distance(point, h) <= h.radius then
            return h
        end
    end
    return nil
end

-- The first of these hostile places (one continent's, in Graph.Hostile's
-- order) that the straight leg p->q passes within its radius of, as
-- { name, f }; nil when none does. A place is ignored when either end of the
-- leg is inside its circle: you are already there, or going there on purpose.
local function dangerOn(hostile, p, q)
    local Geo = ns.Geo
    local x0, x1 = math.min(p.x, q.x), math.max(p.x, q.x)
    local y0, y1 = math.min(p.y, q.y), math.max(p.y, q.y)
    for _, h in ipairs(hostile or {}) do
        local r = h.radius
        -- The box round the leg, widened by r, is a cheap no for most places:
        -- it halves what the test costs Graph.Build (measured 2026-09-22).
        local near = h.x >= x0 - r and h.x <= x1 + r and h.y >= y0 - r and h.y <= y1 + r
        if near and Geo.SegmentDistance(p, q, h) <= r and Geo.Distance(p, h) > r and Geo.Distance(q, h) > r then
            return { name = h.name, f = h.f }
        end
    end
    return nil
end
```

- [ ] **Step 7: `GoblinPS/Graph.lua`, the `Graph.Build` comment**

Replace

```lua
-- with the special keys START, DEST and HEARTH. A ride edge carries zone (the
-- UiMap it is walked in), walk and, in rough mode, rough. The edge between the
-- two ends of a two-ended crossing also carries through = true, and its zone
-- is the one being entered.
```

with

```lua
-- with the special keys START, DEST and HEARTH. A ride edge carries zone (the
-- UiMap it is walked in), walk, danger ({ name, f }: the enemy town its
-- straight line passes, already priced in at Graph.HOSTILE_SECONDS) and, in
-- rough mode, rough. The edge between the two ends of a two-ended crossing
-- also carries through = true, and its zone is the one being entered; it is
-- one passage, never charged for a town. Data/Stopovers.lua rows are stops
-- keyed "s1", "s2"...
```

- [ ] **Step 8: `GoblinPS/Graph.lua`, the stopovers**

Insert directly after the end of the crossings loop in `Graph.Build`,

```lua
                near.zones, near.cross = { x.a, x.b }, x.cross
                stops[key] = near
            end
        end
    end
```

this block:

```lua
    -- A stopover is an ordinary point in one zone, like a tunnel's mouth: the
    -- pair loop below joins it to every other point in its zone, so a ride
    -- can bend through it round an enemy town.
    for i, s in ipairs(data.Stopovers or {}) do
        local c, x, y = ns.Geo.ToWorld(data.Places, s.map, s.mx, s.my)
        if c then
            local key = "s" .. i
            stops[key] = { key = key, name = s.name, c = c, x = x, y = y, map = s.map, mx = s.mx, my = s.my,
                           unverified = s.unverified, stopover = true }
        end
    end
```

- [ ] **Step 9: `GoblinPS/Graph.lua`, the pair loop**

Replace

```lua
    for _, pk in ipairs(keys) do
        for _, qk in ipairs(keys) do
            -- Nothing leaves DEST; nothing but the hearthstone arrives at HEARTH; nothing arrives at START.
            if pk ~= qk and pk ~= "DEST" and qk ~= "START" and qk ~= "HEARTH" then
                local p, q = stops[pk], stops[qk]
                local zone = sharedZone(p, q)
                if zone then
                    local seconds = Graph.RideSeconds(p, q, speed)
                    if q.cross then
                        seconds = seconds + q.cross
                    end
                    if qk == "DEST" and zoneMap and inZone(p, zoneMap) then
                        seconds = 0
                    end
                    addEdge(edges, pk, qk, { kind = "ride", seconds = seconds, zone = zone, walk = opts.walk })
                elseif opts.rough and p.c == q.c and (pk == "START" or pk == "HEARTH" or qk == "DEST") then
                    addEdge(edges, pk, qk, { kind = "ride", seconds = Graph.RideSeconds(p, q, speed),
                                             walk = opts.walk, rough = true })
```

with

```lua
    -- The enemy's towns, by continent: a leg is only ever tested against its own.
    local hostile = {}
    for _, h in ipairs(Graph.Hostile(data, faction)) do
        hostile[h.c] = hostile[h.c] or {}
        table.insert(hostile[h.c], h)
    end

    for _, pk in ipairs(keys) do
        for _, qk in ipairs(keys) do
            -- Nothing leaves DEST; nothing but the hearthstone arrives at HEARTH; nothing arrives at START.
            if pk ~= qk and pk ~= "DEST" and qk ~= "START" and qk ~= "HEARTH" then
                local p, q = stops[pk], stops[qk]
                local zone = sharedZone(p, q)
                if zone then
                    local seconds, danger = Graph.RideSeconds(p, q, speed), nil
                    if q.cross then
                        seconds = seconds + q.cross
                    end
                    if qk == "DEST" and zoneMap and inZone(p, zoneMap) then
                        seconds = 0   -- already in the zone: no leg is ridden, so none passes anything
                    else
                        danger = dangerOn(hostile[p.c], p, q)
                    end
                    if danger then
                        seconds = seconds + Graph.HOSTILE_SECONDS
                    end
                    addEdge(edges, pk, qk, { kind = "ride", seconds = seconds, zone = zone, walk = opts.walk,
                                             danger = danger })
                elseif opts.rough and p.c == q.c and (pk == "START" or pk == "HEARTH" or qk == "DEST") then
                    local danger = dangerOn(hostile[p.c], p, q)
                    addEdge(edges, pk, qk, { kind = "ride", walk = opts.walk, rough = true, danger = danger,
                                             seconds = Graph.RideSeconds(p, q, speed)
                                                 + (danger and Graph.HOSTILE_SECONDS or 0) })
```

The three `end`s and `return { stops = stops, edges = edges }` after it stay
as they are.

- [ ] **Step 10: `GoblinPS/Route.lua`, carry `danger` onto the step**

In `tidy`, replace

```lua
                                  through = s.through }
```

with

```lua
                                  through = s.through, danger = s.danger }
```

Above `Route.Find`, replace

```lua
-- also carries zone, walk, rough and through (the passage of a two-ended crossing).
```

with

```lua
-- also carries zone, walk, rough, through (the passage of a two-ended
-- crossing) and danger ({ name, f }: the enemy town its straight line passes).
```

In `Route.Find`, replace

```lua
                               through = p.edge.through })
```

with

```lua
                               through = p.edge.through, danger = p.edge.danger })
```

- [ ] **Step 11: Run every gate**

Lua `497 passed, 0 failed` (479 + 18). Every other existing test still
passes: the step detail does not print `danger` until Task 5. Python `Ran 74
tests`, `OK`. Art green. luacheck and the language server: zero warnings.

- [ ] **Step 12: Commit**

```
git add GoblinPS/Graph.lua GoblinPS/Route.lua test/test_graph.lua test/test_crossings.lua
git commit -m "Graph: a ride leg past a known enemy town costs ten minutes more" -m "Graph.Hostile builds this faction's enemy places from the other side's flight masters (bar the eight split neutral towns) and the other side's towns marked in tools/town-factions.csv, flight masters first, 150 yards round or 400 for a capital (the place named after its own zone). Every ride edge, rough ones too, that passes a circle neither of its ends is inside gains Graph.HOSTILE_SECONDS and danger = { name, f }; flights, links, the hearthstone and a tunnel's through leg never do. Stopovers are ordinary one-zone stops. On the real data the Horde's straight line from the Talondeep Path to Splintertree Post carries Silverwind Refuge, and the route goes round by the Ashenvale-Felwood road; the walk to Hyjal goes round Silverwing Outpost, and the tunnel test now goes to Zoram'gar Outpost." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---


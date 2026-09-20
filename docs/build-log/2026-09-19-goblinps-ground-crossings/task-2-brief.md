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


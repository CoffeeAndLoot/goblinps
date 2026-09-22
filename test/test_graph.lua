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
        h.it("adds a crossing's own passage time to the leg that arrives at it", function()
            -- A tiny world of its own: a tunnel between two zones that takes 90
            -- seconds to walk even though the point is one for both zones.
            local tunnel = {
                Places = {
                    [10] = { name = "Near", c = 9, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.5, ay = 0.5 },
                    [11] = { name = "Far", c = 9, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.5, ay = 0.5 },
                },
                Crossings = { { a = 10, b = 11, name = "Slow Tunnel", map = 10, mx = 0.5, my = 0.5, cross = 90 } },
                Nodes = {}, Flights = {}, Links = {},
            }
            local from = { name = "You", c = 9, x = 0, y = 0, map = 10 }
            local to = { name = "There", c = 9, x = 5000, y = 5000, map = 11 }
            local g = Graph.Build(tunnel, { faction = "H", known = {}, from = from, to = to })
            local edge
            for _, e in ipairs(g.edges.START or {}) do
                if e.to == "x1" then
                    edge = e
                end
            end
            h.truthy(edge, "no edge from START to the crossing")
            local plain = Graph.RideSeconds(from, g.stops.x1)
            h.truthy(math.abs(edge.seconds - (plain + 90)) < 0.001)
        end)
    end)

    h.describe("a crossing with two ends", function()
        -- The fake world's Deep Tunnel: row 2, a mouth in Westland (1) at
        -- world (9600, 9600) and one in Northland (4) at (9600, 9200).
        local from = { name = "You", c = 1, x = 9000, y = 9900, map = 1 }
        local camp = { name = "Deep Camp", c = 1, x = 9000, y = 9000, map = 4 }
        local function edgeTo(g, a, b)
            for _, e in ipairs(g.edges[a] or {}) do
                if e.to == b then
                    return e
                end
            end
        end

        h.it("builds two stops, each an ordinary point in one zone", function()
            local g = Graph.Build(world, { faction = "H", known = {}, from = from, to = camp })
            local near, far = g.stops.x2, g.stops.x2far
            h.truthy(near and far, "one stop per end, keyed x2 and x2far")
            h.eq(near.map, 1)
            h.eq(far.map, 4)
            h.eq(near.zones, nil, "an end belongs to one zone only")
            h.eq(far.zones, nil, "an end belongs to one zone only")
            h.eq(near.name, "the Deep Tunnel")
            h.eq(far.name, "the Deep Tunnel")
            h.truthy(math.abs(near.x - 9600) < 0.001 and math.abs(near.y - 9600) < 0.001, "Westland mouth")
            h.truthy(math.abs(far.x - 9600) < 0.001 and math.abs(far.y - 9200) < 0.001, "Northland mouth")
            h.falsy(g.stops.x1far, "a one-ended row still builds one stop")
            h.truthy(g.stops.x1.zones, "and that stop still belongs to both zones")
        end)
        h.it("joins its ends with a through edge each way, priced at the ride between them", function()
            local g = Graph.Build(world, { faction = "H", known = {}, from = from, to = camp, speed = 7, walk = true })
            local there, back = edgeTo(g, "x2", "x2far"), edgeTo(g, "x2far", "x2")
            h.truthy(there and back, "one edge each way")
            local ride = Graph.RideSeconds(g.stops.x2, g.stops.x2far, 7)
            for _, e in ipairs({ there, back }) do
                h.eq(e.kind, "ride")
                h.eq(e.through, true)
                h.eq(e.walk, true)
                h.truthy(math.abs(e.seconds - ride) < 0.001)
            end
            h.eq(there.zone, 4, "the zone being entered")
            h.eq(back.zone, 1, "the zone being entered")
        end)
        h.it("prices the through edge at cross when the row gives one, and only there", function()
            local w = dofile("test/fake_world.lua")()
            w.Crossings[2].cross = 45
            local g = Graph.Build(w, { faction = "H", known = {}, from = from, to = camp })
            h.eq(edgeTo(g, "x2", "x2far").seconds, 45)
            h.eq(edgeTo(g, "x2far", "x2").seconds, 45)
            local approach = edgeTo(g, "START", "x2")
            h.truthy(math.abs(approach.seconds - Graph.RideSeconds(from, g.stops.x2)) < 0.001,
                     "cross is not added again on the leg that arrives at an end")
            h.falsy(approach.through)
        end)
        h.it("gives both ends the row's warning and unverified flag", function()
            local w = dofile("test/fake_world.lua")()
            w.Crossings[2].warn, w.Crossings[2].unverified = "bats", true
            local g = Graph.Build(w, { faction = "H", known = {}, from = from, to = camp })
            for _, key in ipairs({ "x2", "x2far" }) do
                h.eq(g.stops[key].warn, "bats", key)
                h.eq(g.stops[key].unverified, true, key)
                h.eq(g.stops[key].cross, nil, key .. ": cross lives on the through edge, never on a stop")
            end
        end)
        h.it("rides to each end only inside that end's zone", function()
            local g = Graph.Build(world, { faction = "H", known = {}, from = from, to = camp })
            h.eq(edgeTo(g, "START", "x2").zone, 1)
            h.falsy(edgeTo(g, "START", "x2far"), "the far mouth is in another zone")
            h.eq(edgeTo(g, "x2far", "DEST").zone, 4)
            h.falsy(edgeTo(g, "x2", "DEST"), "the near mouth is in another zone")
        end)
    end)
end

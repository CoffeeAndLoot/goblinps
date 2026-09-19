return function(h, loaded)
    local Graph = loaded.ns.Graph
    local world = dofile("test/fake_world.lua")()

    local nearAlpha = { name = "You", c = 1, x = 1000, y = 1100 }
    local nearDelta = { name = "Delta Inn", c = 0, x = 5000, y = 5100 }

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
            opts.hearth = { name = "Delta Inn", c = 0, x = 5000, y = 5050 }
            local g = Graph.Build(world, opts)
            h.truthy(g.stops.HEARTH)
            h.eq(g.edges.START[1].kind, "hearth")
        end)
    end)

    h.describe("Graph.Build: landmasses", function()
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
end

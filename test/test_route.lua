return function(h, loaded)
    local Graph, Route = loaded.ns.Graph, loaded.ns.Route
    local world = dofile("test/fake_world.lua")()

    local nearAlpha = { name = "You", c = 1, x = 1000, y = 1100 }
    local nearDelta = { name = "Delta Inn", c = 0, x = 5000, y = 5100 }
    local nearCharlie = { name = "Charlie Field", c = 1, x = 5000, y = 9100 }

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
                                          hearth = { name = "Delta Inn", c = 0, x = 5000, y = 5050 } })
            h.eq(r.steps[1].kind, "hearth")
            h.eq(r.steps[1].seconds, Graph.HEARTH_SECONDS)
        end)
        h.it("ignores the hearthstone when it is not offered", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta })
            h.eq(kinds(r), "ride,zeppelin,ride")
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
    end)
end

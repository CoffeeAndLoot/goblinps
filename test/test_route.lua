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

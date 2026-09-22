return function(h, loaded)
    local Graph, Route = loaded.ns.Graph, loaded.ns.Route
    local world = dofile("test/fake_world.lua")()

    local nearAlpha = { name = "You", c = 1, x = 1000, y = 1100, map = 1 }
    local nearDelta = { name = "Delta Inn", c = 0, x = 5000, y = 5100, map = 2 }
    local nearCharlie = { name = "Charlie Field", c = 1, x = 5000, y = 9100, map = 1 }

    -- Graph's kind == "zone" rule serves a zone that holds no place, the only
    -- zone Search offers; these tests build one by hand, the centre of the
    -- zone, as Search does, to test the rule on zones that do have places.
    local function zone(map)
        local c, x, y = loaded.ns.Geo.ToWorld(world.Places, map, 0.5, 0.5)
        return { kind = "zone", name = world.Places[map].name, c = c, x = x, y = y, map = map, mx = 0.5, my = 0.5 }
    end

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

    -- The graph prices the hearthstone at HEARTH_SECONDS, the cast and the
    -- loading screen. It cannot price the half-hour cooldown, so left alone the
    -- router will spend the stone to save seconds. opts.hearthSaving is the
    -- least it must save to be worth taking.
    h.describe("the hearthstone has to earn its cooldown", function()
        -- Measured against this fake world: binding at y=2000 saves about 85
        -- seconds off the 1261s plain route, and y=5000 saves about 433. A
        -- five-minute bar should reject the first and keep the second.
        local pennyworth = { name = "Alpha Inn", c = 1, x = 1000, y = 2000, map = 1 }
        local worthIt = { name = "Charlie Inn", c = 1, x = 1000, y = 5000, map = 1 }
        local BAR = 300

        h.it("takes a saving of seconds when nothing is asked of it", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta,
                                          hearth = pennyworth })
            h.eq(r.steps[1].kind, "hearth", "with no threshold the old behaviour stands")
        end)
        h.it("refuses a saving smaller than the threshold and routes without it", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta,
                                          hearth = pennyworth, hearthSaving = BAR })
            h.truthy(r, "refusing the hearthstone must not mean no route")
            h.falsy(r.steps[1].kind == "hearth", "85 seconds is not worth a half-hour cooldown")
            local free = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta })
            h.eq(r.seconds, free.seconds, "it must fall back to the plain route, not a worse one")
        end)
        h.it("still takes a saving that clears the threshold", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta,
                                          hearth = worthIt, hearthSaving = BAR })
            h.eq(r.steps[1].kind, "hearth", "seven minutes is worth the cooldown")
        end)
        h.it("never turns a route into no route, whatever the threshold", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta,
                                          hearth = worthIt, hearthSaving = 1000000 })
            h.truthy(r, "an impossible threshold must still leave the plain route")
            h.falsy(r.steps[1].kind == "hearth")
        end)
    end)

    h.describe("Route.Find tie-breaking", function()
        h.it("always goes through the stop whose key sorts first when two routes tie exactly", function()
            local graph = {
                stops = {
                    START = { key = "START", name = "Start" },
                    DEST = { key = "DEST", name = "Dest" },
                    mid_a = { key = "mid_a", name = "Mid A" },
                    mid_b = { key = "mid_b", name = "Mid B" },
                },
                edges = {
                    START = {
                        -- mid_b listed first: an insertion-order tie-break would pick it
                        -- (the wrong stop); only a key-based tie-break always picks mid_a.
                        { to = "mid_b", kind = "ride", seconds = 10, copper = 0 },
                        { to = "mid_a", kind = "ride", seconds = 10, copper = 0 },
                    },
                    mid_a = { { to = "DEST", kind = "ride", seconds = 10, copper = 0 } },
                    mid_b = { { to = "DEST", kind = "ride", seconds = 10, copper = 0 } },
                },
            }
            for _ = 1, 5 do
                local r = Route.Find(graph)
                h.truthy(r, "a route must be found")
                h.eq(r.raw[1].to.key, "mid_a")
            end
        end)
    end)

    h.describe("an enemy flight stop", function()
        h.it("is ridden to, never flown to: the Horde may not use an Alliance flight master", function()
            -- A flight Charlie -> Echo would win by far if Graph let the Horde take it.
            local w = dofile("test/fake_world.lua")()
            w.Flights[#w.Flights + 1] = { 3, 5, 10, 10 }
            local echo = loaded.ns.Search.Find(w, "echo", "H", 1)[1]
            h.eq(echo.enemy, "A")
            local r = Route.Plan(w, { faction = "H", known = { [1] = true, [2] = true, [3] = true, [5] = true },
                                      from = nearAlpha, to = echo })
            h.truthy(r, "an enemy stop is still somewhere to go")
            for _, s in ipairs(r.steps) do
                h.falsy(s.kind == "fly" and s.to.nodeID == 5, "a flight lands at the enemy stop")
            end
            h.eq(r.steps[#r.steps].kind, "ride")
            local alliance = Route.Plan(w, { faction = "A", known = { [3] = true, [5] = true },
                                             from = nearCharlie, to = echo })
            h.eq(kinds(alliance), "ride,fly", "the check can fail: the Alliance does fly there")
        end)
    end)

    h.describe("a zone destination", function()
        local westland = zone(1)
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
        local northland = zone(4)
        local hotel = loaded.ns.Search.Find(world, "hotel", "H", 1)[1]
        local lostland = zone(5)

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
        h.it("goes to a two-ended crossing, then through it, then on", function()
            local from = { name = "You", c = 1, x = 9000, y = 9900, map = 1 }
            local camp = { name = "Deep Camp", c = 1, x = 9000, y = 9000, map = 4 }
            local r = Route.Plan(world, { faction = "H", known = {}, from = from, to = camp })
            h.eq(kinds(r), "ride,ride,ride")
            h.eq(Route.StepText(r.steps[1]), "Ride to the Deep Tunnel")
            h.eq(Route.StepText(r.steps[2]), "Ride through the Deep Tunnel")
            h.eq(Route.StepText(r.steps[3]), "Ride to Deep Camp")
            h.falsy(r.steps[1].through)
            h.eq(r.steps[2].through, true)
            h.eq(r.steps[2].to.map, 4, "the through step ends at the far mouth")
            h.eq(Route.StepDetail(world, r.steps[1], 5), "in Westland · level 1-10")
            local text, warn = Route.StepDetail(world, r.steps[2], 5)
            h.eq(text, "into Northland · level 30-40")
            h.eq(warn, true)
            local walking = Route.Plan(world, { faction = "H", known = {}, from = from, to = camp,
                                                speed = 7, walk = true })
            h.eq(Route.StepText(walking.steps[1]), "Walk to the Deep Tunnel")
            h.eq(Route.StepText(walking.steps[2]), "Walk through the Deep Tunnel")
        end)
        h.it("never drops a through step as too short to mention", function()
            local w = dofile("test/fake_world.lua")()
            w.Crossings[2].cross = 1
            local from = { name = "You", c = 1, x = 9000, y = 9900, map = 1 }
            local camp = { name = "Deep Camp", c = 1, x = 9000, y = 9000, map = 4 }
            local r = Route.Plan(w, { faction = "H", known = {}, from = from, to = camp })
            h.eq(Route.StepText(r.steps[2]), "Ride through the Deep Tunnel")
            h.eq(r.steps[2].seconds, 1)
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
        h.it("says which zone a crossing leads into and its hazard: not its levels, so the hazard is never cut off",
             function()
            local gateStep
            for _, s in ipairs(r.steps) do
                if s.to.zones then
                    gateStep = s
                end
            end
            local text, warn = Route.StepDetail(world, gateStep, 35)
            h.eq(text, "into Northland · trolls on the bridge")
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
        h.it("does not say the obvious when the step arrives at the zone itself", function()
            local text, warn = Route.StepDetail(world, { kind = "ride", zone = 1, to = { name = "Westland" } }, 60)
            h.eq(text, "")
            h.eq(warn, false)
        end)
        -- No row in Data/Crossings.lua carries both today, so the real-data test
        -- cannot reach this ordering. Level 60 keeps the zone itself calm, so
        -- the amber can only be coming from the crossing.
        h.it("puts the hazard before the unconfirmed note when a crossing has both", function()
            local gate = { name = "the test gate", zones = { 1, 2 }, warn = "trolls on the bridge", unverified = true }
            local text, warn = Route.StepDetail(world, { kind = "ride", zone = 1, to = gate }, 60)
            h.eq(text, "into Eastland · trolls on the bridge · crossing not confirmed")
            h.eq(warn, true)
        end)
        h.it("says only the crossing is unconfirmed when it carries no hazard", function()
            local gate = { name = "the test gate", zones = { 1, 2 }, unverified = true }
            local text, warn = Route.StepDetail(world, { kind = "ride", zone = 1, to = gate }, 60)
            h.eq(text, "into Eastland · crossing not confirmed")
            h.eq(warn, true)
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
            h.eq(Route.StepText(r.steps[4]), "Zeppelin to East Dock")
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

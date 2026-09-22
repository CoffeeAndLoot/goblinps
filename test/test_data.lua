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
            h.eq(ns.Search.Exact(data, "Brill", "H").kind, "town")
            h.eq(ns.Search.Exact(data, "Gallows' End Tavern", "H").name, "Brill", "the inn building is its town")
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
            h.eq(ns.Route.StepText(r.steps[2]), "Tram to Ironforge Tram Station")
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

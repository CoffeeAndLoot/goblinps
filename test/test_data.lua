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
            -- Without the generated towns too: a row that names one of them
            -- still earns its place, because hand-written data wins -- it
            -- says what the name is ("Theramore Isle" is the Theramore stop,
            -- "Kharanos" the inn town) and keeps the town from being offered
            -- a second time.
            local without = {}
            for k, v in pairs(data) do
                without[k] = v
            end
            without.Inns, without.Towns = nil, nil
            for bind in pairs(data.Inns) do
                h.falsy(ns.Search.Exact(without, bind, nil), bind .. " already resolves; drop the row")
            end
        end)
        h.it("finds the binds met in game", function()
            h.eq(ns.Search.Exact(data, "The Crossroads", "H").nodeID, 25)
            h.eq(ns.Search.Exact(data, "Brill", "H").kind, "town")
            h.eq(ns.Search.Exact(data, "Gallows' End Tavern", "H").name, "Brill", "the inn building is its town")
            h.eq(ns.Search.Exact(data, "Stormwind City", "A").name, "Stormwind", "a bind reported as the zone")
        end)
    end)

    h.describe("the places the planner offers", function()
        h.it("offers a zone only where it holds no stop and no inn town, and these are all of them", function()
            local zones = {}
            for _, item in ipairs(ns.Search.Candidates(data, "H")) do
                if item.kind == "zone" then
                    zones[#zones + 1] = item.name
                end
            end
            table.sort(zones)
            -- A new town row or flight stop in one of these makes this fail:
            -- take the zone off the list, since it is only a search word now.
            h.eq(table.concat(zones, ", "), "Alterac Mountains, Shen'dralas")
        end)
        h.it("leaves no zone that cannot be picked", function()
            local reached = {}
            for _, item in ipairs(ns.Search.Candidates(data, "H")) do
                reached[item.map] = true
            end
            for map, place in pairs(data.Places) do
                h.truthy(reached[map], place.name .. " (" .. map .. ") has no candidate at all")
            end
        end)
    end)

    h.describe("the towns table", function()
        local towns, count = data.Towns, 0
        for _ in pairs(towns or {}) do
            count = count + 1
        end

        h.it("loads, generated from the game's AreaPOI table", function()
            h.eq(count, 150, "207 on the two continents with a town icon; 9 event markers, 5 unplaced, 43 duplicates")
        end)
        h.it("puts every town inside its own zone's rectangle, with every field", function()
            for id, t in pairs(towns) do
                local p = data.Places[t.map]
                h.truthy(p, "town " .. id .. " " .. tostring(t.name) .. " has no zone")
                h.eq(t.c, p.c, t.name .. " is on its zone's continent")
                h.truthy(p.x0 <= t.x and t.x <= p.x1 and p.y0 <= t.y and t.y <= p.y1,
                         t.name .. " lies outside " .. p.name)
                h.truthy(t.mx >= 0 and t.mx <= 1 and t.my >= 0 and t.my <= 1, t.name .. " map coords")
                local c, x, y = ns.Geo.ToWorld(data.Places, t.map, t.mx, t.my)
                h.truthy(c == t.c and math.abs(x - t.x) < 10 and math.abs(y - t.y) < 10,
                         t.name .. ": its map coords and world coords are one point")
                h.truthy(t.f == nil or t.f == "A" or t.f == "H", t.name .. " faction")
            end
        end)
        h.it("never repeats a flight stop in the stop's own zone", function()
            local stops = {}
            for _, n in pairs(data.Nodes) do
                stops[ns.Search.ShortName(n.name):lower():gsub("^the%s+", "") .. "@" .. n.map] = true
            end
            for _, t in pairs(towns) do
                h.falsy(stops[t.name:lower():gsub("^the%s+", "") .. "@" .. t.map], t.name .. " is a flight stop")
            end
        end)
        h.it("makes Darnassus, Kharanos and Sentinel Hill places, not zones", function()
            for _, name in ipairs({ "Darnassus", "Kharanos", "Sentinel Hill" }) do
                for _, faction in ipairs({ "A", "H" }) do
                    local place = ns.Search.Exact(data, name, faction)
                    h.truthy(place, name .. " cannot be found by the " .. faction)
                    h.truthy(place.kind ~= "zone", name .. " is still only a zone")
                end
            end
            h.eq(ns.Search.Exact(data, "Sentinel Hill", "H").nodeID, 4, "the stop, not a town beside it")
        end)

        h.it("gives a town a faction only where the owner marked one", function()
            -- tools/town-factions.csv, and nothing else: no faction is guessed
            -- from nearby flight masters any more. test/tools/test_build_graph.py
            -- checks the whole sheet against this file.
            local byName = {}
            for _, t in pairs(towns) do
                byName[t.name] = t
            end
            h.eq(byName["Silverwind Refuge"].f, "A", "marked Alliance")
            h.eq(byName["Warsong Labor Camp"].f, "H", "marked Horde")
            for _, name in ipairs({ "Irontree Cavern", "Maraudon", "Falfarren River" }) do
                h.eq(byName[name].f, nil, name .. " is not marked, so it has no faction")
            end
            h.eq(ns.Search.Exact(data, "Silverwind Refuge", "H").enemy, "A", "the Horde's list says (Alliance)")
            h.eq(ns.Search.Exact(data, "Irontree Cavern", "H").enemy, nil, "and a cave is nobody's enemy")
        end)
    end)

    h.describe("no place offered twice", function()
        -- Stronger than "no two of one name within 300 yards": two rows with
        -- one name and one zone would read the same at any distance. The two
        -- ends of a tunnel share a name 217 yards apart (Timbermaw Hold) but
        -- not a zone, and are two places.
        h.it("never offers two rows that read the same", function()
            for _, faction in ipairs({ "A", "H" }) do
                local seen, rows = {}, 0
                for _, item in ipairs(ns.Search.Candidates(data, faction)) do
                    local label = item.name .. " @ " .. tostring(item.zone)
                    h.falsy(seen[label], faction .. ": " .. label .. " is offered twice")
                    seen[label] = true
                    rows = rows + 1
                end
                h.truthy(rows > 200, "a check that saw no rows proves nothing")
            end
        end)
        h.it("hides the other faction's stop where one of your own has its name", function()
            for _, name in ipairs({ "Booty Bay", "Gadgetzan", "Everlook" }) do
                local found = ns.Search.Find(data, name, "H")
                h.eq(found[1].name, name)
                h.eq(found[1].enemy, nil, name .. ": the Horde's own stop")
                h.truthy(not found[2] or found[2].name ~= name, name .. " is offered twice to the Horde")
            end
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

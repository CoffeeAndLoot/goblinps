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

    -- A border can only lie where the two zones' rectangles overlap, so a
    -- crossing has to sit on that overlap. `near` above asks a similar
    -- question but pads each rectangle by a tenth of its own size first, and a
    -- tenth of the Barrens is over a thousand yards. The two are
    -- complementary, not redundant, and the proof is that all 56 rows pass
    -- `near` today while six fail this: measuring against the unpadded overlap
    -- in yards catches what a share of a huge rectangle cannot. The worst row
    -- today is 250 (the Timbermaw tunnels, on the Felwood side), and a digit
    -- typed wrong in a map coordinate moves a point by thousands, so 300
    -- catches typos while tolerating estimates nobody has walked yet.
    local EDGE_YARDS = 300

    local function distToRect(x0, x1, y0, y1, x, y)
        local dx = math.max(x0 - x, 0, x - x1)
        local dy = math.max(y0 - y, 0, y - y1)
        return math.sqrt(dx * dx + dy * dy)
    end

    -- Yards from a point to the area the two zones share; math.huge when their
    -- rectangles do not meet at all, which would mean an invented border.
    local function fromSharedEdge(a, b, c, x, y)
        local p, q = data.Places[a], data.Places[b]
        if p.c ~= c or q.c ~= c then
            return math.huge
        end
        local x0, x1 = math.max(p.x0, q.x0), math.min(p.x1, q.x1)
        local y0, y1 = math.max(p.y0, q.y0), math.min(p.y1, q.y1)
        if x0 > x1 or y0 > y1 then
            return math.huge
        end
        return distToRect(x0, x1, y0, y1, x, y)
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
                h.truthy(x.cross == nil or (type(x.cross) == "number" and x.cross > 0),
                         label .. ": cross must be a positive number")
                h.eq(data.Places[x.a].c, data.Places[x.b].c, label .. ": zones on different continents")
            end
        end)
        h.it("names read the same whichever way you are going", function()
            for _, x in ipairs(data.Crossings) do
                for _, zoneID in ipairs({ x.a, x.b }) do
                    local zoneName = data.Places[zoneID].name
                    h.falsy(x.name:find(" into " .. zoneName, 1, true),
                            x.name .. ": reads only one direction (into " .. zoneName .. ")")
                    h.falsy(x.name:find(" to " .. zoneName, 1, true),
                            x.name .. ": reads only one direction (to " .. zoneName .. ")")
                end
            end
        end)
        h.it("marks exactly the unverified rows: the new zones and Orgrimmar's west gate", function()
            local expected = {
                ["1413-1454"] = true, -- Orgrimmar's west gate
                ["1452-2482"] = true, -- Darkwhisper Gorge, into Mount Hyjal
                ["1443-2652"] = true, -- the Valley of Bones, into Shen'dralas
                ["1433-2548"] = true, -- the Riverglades turnoff
                ["1428-2548"] = true, -- the Riverglades-Burning Steppes border
                ["1435-2548"] = true, -- the Riverglades-Swamp border
                ["1418-2548"] = true, -- the Riverglades-Badlands border
            }
            local count = 0
            for _, x in ipairs(data.Crossings) do
                local key = math.min(x.a, x.b) .. "-" .. math.max(x.a, x.b)
                if x.unverified then
                    count = count + 1
                end
                h.eq(x.unverified == true, expected[key] == true, key .. " (" .. x.name .. ") unverified flag is wrong")
            end
            h.eq(count, 7)
        end)
        h.it("has the right number of crossings at these pinch points", function()
            local counts = {}
            for _, x in ipairs(data.Crossings) do
                counts[x.a] = (counts[x.a] or 0) + 1
                counts[x.b] = (counts[x.b] or 0) + 1
            end
            local expect = {
                [1449] = 2, -- Un'Goro Crater
                [1451] = 1, -- Silithus
                [1450] = 2, -- Moonglade
                [1445] = 1, -- Dustwallow Marsh
                [1438] = 1, -- Teldrassil
                [1419] = 1, -- Blasted Lands
                [1457] = 1, -- Darnassus
                [1447] = 1, -- Azshara
            }
            for map, n in pairs(expect) do
                h.eq(counts[map] or 0, n, data.Places[map].name .. " should have " .. n .. " crossing(s)")
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
        h.it("puts every point on the strip its two zones share", function()
            local worst, worstName, offenders = 0, nil, 0
            for i, x in ipairs(data.Crossings) do
                local c, wx, wy = ns.Geo.ToWorld(data.Places, x.map, x.mx, x.my)
                local away = fromSharedEdge(x.a, x.b, c, wx, wy)
                h.truthy(away < math.huge, "crossing " .. i .. " (" .. x.name .. "): "
                         .. data.Places[x.a].name .. " and " .. data.Places[x.b].name
                         .. " do not touch, so this border cannot exist")
                h.truthy(away <= EDGE_YARDS, "crossing " .. i .. " (" .. x.name .. ") is "
                         .. math.floor(away) .. " yards from where " .. data.Places[x.a].name
                         .. " and " .. data.Places[x.b].name .. " meet")
                if away > 0 then
                    offenders = offenders + 1
                end
                if away > worst then
                    worst, worstName = away, x.name
                end
            end
            -- Pinned so that correcting a point in game shows up as a failure
            -- here, which is the prompt to update these numbers and the list in
            -- docs/manual-test-checklist.md.
            h.eq(offenders, 6, "rows sit off the shared edge (worst: " .. tostring(worstName)
                 .. " at " .. math.floor(worst) .. " yards). If you have just corrected a crossing"
                 .. " in game then this number is MEANT to change: update it here and the table"
                 .. " under 'Which crossings to check first' in docs/manual-test-checklist.md")
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
            h.eq(t[6], "Walk to the Ashenvale-Felwood road")
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
            h.eq(text, "into Winterspring · Timbermaw furbolgs attack without reputation")
            h.eq(warn, true)
            text, warn = ns.Route.StepDetail(data, r.steps[8], 60)
            h.eq(text, "into Mount Hyjal · crossing not confirmed")
            h.eq(warn, true)
            text, warn = ns.Route.StepDetail(data, r.steps[2], 1)
            h.eq(text, "")
            h.eq(warn, false)
        end)
        h.it("keeps every crossing's detail line short enough not to be cut off", function()
            for _, x in ipairs(data.Crossings) do
                for _, from in ipairs({ x.a, x.b }) do
                    local to = (from == x.a) and x.b or x.a
                    local step = { kind = "ride", zone = from,
                                   to = { zones = { x.a, x.b }, warn = x.warn, unverified = x.unverified,
                                          name = x.name } }
                    local text = ns.Route.StepDetail(data, step, nil)
                    h.truthy(#text <= 66, x.name .. " into " .. data.Places[to].name
                              .. ": detail is " .. #text .. " bytes: " .. text)
                end
            end
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

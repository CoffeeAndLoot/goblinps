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

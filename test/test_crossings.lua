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
    -- A two-ended crossing (a tunnel, a lift) has a mouth in each zone. The
    -- Talondeep Path, the longest so far, is about 440 yards mouth to mouth;
    -- ends further apart than this are a typo, not a tunnel.
    local ENDS_YARDS = 1500

    -- Is the world point inside zone `map`'s own rectangle, unpadded?
    local function inside(map, c, x, y)
        local p = data.Places[map]
        return p.c == c and x >= p.x0 and x <= p.x1 and y >= p.y0 and y <= p.y1
    end

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
                if x.far then
                    local other = x.map == x.a and x.b or x.a
                    h.eq(x.far.map, other, label .. ": its far end must be on the other zone's map")
                    h.truthy(type(x.far.mx) == "number" and type(x.far.my) == "number",
                             label .. ": its far end needs mx and my")
                end
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
        h.it("puts every one-ended point in or beside both of its zones", function()
            for i, x in ipairs(data.Crossings) do
                local c, wx, wy = ns.Geo.ToWorld(data.Places, x.map, x.mx, x.my)
                h.truthy(c, "crossing " .. i .. " cannot be placed")
                if not x.far then
                    h.truthy(near(x.a, c, wx, wy) and near(x.b, c, wx, wy),
                             "crossing " .. i .. " (" .. x.name .. ") is not near both " .. data.Places[x.a].name
                             .. " and " .. data.Places[x.b].name)
                end
            end
        end)
        h.it("puts each end of a two-ended crossing inside its own zone, near the other end", function()
            local twoEnded = 0
            for i, x in ipairs(data.Crossings) do
                if x.far then
                    twoEnded = twoEnded + 1
                    local label = "crossing " .. i .. " (" .. x.name .. ")"
                    local c, wx, wy = ns.Geo.ToWorld(data.Places, x.map, x.mx, x.my)
                    local fc, fx, fy = ns.Geo.ToWorld(data.Places, x.far.map, x.far.mx, x.far.my)
                    h.truthy(c and inside(x.map, c, wx, wy),
                             label .. ": its end is not inside " .. data.Places[x.map].name)
                    h.truthy(fc and inside(x.far.map, fc, fx, fy),
                             label .. ": its far end is not inside " .. data.Places[x.far.map].name)
                    local yards = ns.Geo.Distance({ c = c, x = wx, y = wy }, { c = fc, x = fx, y = fy })
                    h.truthy(yards <= ENDS_YARDS, label .. ": its ends are " .. math.floor(yards) .. " yards apart")
                end
            end
            h.eq(twoEnded, 1, "the Talondeep Path is the only two-ended row so far")
        end)
        -- A two-ended row's mouths each sit in their own zone, not on the
        -- border, so this rule is for one-ended rows only.
        h.it("puts every one-ended point on the strip its two zones share", function()
            local worst, worstName, offenders = 0, nil, 0
            for i, x in ipairs(data.Crossings) do
                local c, wx, wy = ns.Geo.ToWorld(data.Places, x.map, x.mx, x.my)
                local away = x.far and 0 or fromSharedEdge(x.a, x.b, c, wx, wy)   -- the test above takes those
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

    -- The first place the search offers for the text, as /gps to picks it: a
    -- zone's name finds a town or flight stop in that zone, never the zone.
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
            -- Round by the Darkshore road: the straight line from the rampart to
            -- the Felwood road passes Silverwing Outpost, which the owner marked
            -- Alliance in tools/town-factions.csv.
            h.eq(t[6], "Walk to the Ashenvale-Darkshore road")
            h.eq(t[7], "Walk to the Ashenvale-Felwood road")
            h.eq(t[8], "Walk to the Timbermaw Hold tunnels")
            h.eq(t[9], "Walk to Darkwhisper Gorge")
            h.eq(t[10], "Walk to Summit of Eternity", "on to a place in Mount Hyjal, not stopping at its border")
            h.eq(#t, 10)
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
            text, warn = ns.Route.StepDetail(data, r.steps[8], 60)
            h.eq(text, "into Winterspring · Timbermaw furbolgs attack without reputation")
            h.eq(warn, true)
            text, warn = ns.Route.StepDetail(data, r.steps[9], 60)
            h.eq(text, "into Mount Hyjal · crossing not confirmed")
            h.eq(warn, true)
            -- The zeppelin step. Its figure is padded by the average wait, and
            -- saying so is the only detail a link step carries; the minutes
            -- themselves belong in the planner's own column, not in the text.
            text, warn = ns.Route.StepDetail(data, r.steps[2], 1)
            h.eq(text, "includes the average wait")
            h.eq(warn, false)
        end)
        h.it("keeps every crossing's detail line short enough not to be cut off", function()
            for _, x in ipairs(data.Crossings) do
                for _, from in ipairs({ x.a, x.b }) do
                    local to = (from == x.a) and x.b or x.a
                    local step = { kind = "ride", zone = from,
                                   to = { zones = { x.a, x.b }, warn = x.warn, unverified = x.unverified,
                                          name = x.name } }
                    if x.far then
                        -- the step through it, which ends at the mouth in the zone being entered
                        step = { kind = "ride", zone = to, through = true,
                                 to = { map = to, warn = x.warn, unverified = x.unverified, name = x.name } }
                    end
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
        -- Zoram'gar Outpost, not Splintertree Post: from Sun Rock the way to
        -- Splintertree now stays out of Ashenvale's marked Alliance south, down
        -- the Stonetalon pass and up through the Mor'shan Rampart.
        h.it("goes through the Talondeep Path from Sun Rock Retreat to Zoram'gar Outpost", function()
            local sunRock
            for _, n in pairs(data.Nodes) do
                if n.name:find("Sun Rock Retreat", 1, true) == 1 then
                    sunRock = n
                end
            end
            h.truthy(sunRock, "no Sun Rock Retreat flight master")
            local from = { name = "You", c = sunRock.c, x = sunRock.x, y = sunRock.y,
                           map = sunRock.map, mx = sunRock.mx, my = sunRock.my }
            local to = ns.Search.Exact(data, "Zoram'gar Outpost", "H")
            h.truthy(to, "no Zoram'gar Outpost")
            local r = ns.Route.Plan(data, { faction = "H", known = {}, from = from, to = to })
            h.truthy(r, "no route")
            local t = texts(r)
            local at
            for i, line in ipairs(t) do
                if line == "Ride through the Talondeep Path" then
                    at = i
                end
            end
            h.truthy(at, "no step through the Talondeep Path: " .. table.concat(t, " / "))
            h.eq(t[at - 1], "Ride to the Talondeep Path", "the approach to the Stonetalon mouth")
            h.eq(r.steps[at - 1].to.map, 1442, "the approach ends at the Stonetalon mouth")
            h.eq(r.steps[at].to.map, 1440, "the through step ends at the Ashenvale mouth")
            h.truthy(ns.Route.StepDetail(data, r.steps[at], 60):find("^into Ashenvale"))
            for _, s in ipairs(r.steps) do
                h.falsy(s.rough)
            end
        end)
        -- The owner's route on 2026-09-22: from the Talondeep Path's Ashenvale
        -- mouth, measured in game at 42.3, 71.1, the straight line to
        -- Splintertree Post runs 97 yards from Silverwind Refuge (50.1, 66.2),
        -- whose guards killed a level 15 Horde player there more than once.
        local function fromTalondeep(faction)
            local c, x, y = ns.Geo.ToWorld(data.Places, 1440, 0.423, 0.711)
            local walker = ns.Travel.For(15)
            return { faction = faction, known = {}, speed = walker.speed, walk = walker.walk,
                     from = { name = "You", c = c, x = x, y = y, map = 1440, mx = 0.423, my = 0.711 },
                     to = ns.Search.Exact(data, "Splintertree Post", faction) }
        end
        local function straightLine(opts)
            for _, e in ipairs(ns.Graph.Build(data, opts).edges.START) do
                if e.to == "DEST" then
                    return e
                end
            end
        end
        h.it("charges the Horde's straight line past Silverwind Refuge, and walks it round by the north", function()
            local opts = fromTalondeep("H")
            local line = straightLine(opts)
            h.eq(line.danger and line.danger.name, "Silverwind Refuge")
            h.eq(line.danger.f, "A")
            local silverwind
            for _, enemy in ipairs(ns.Graph.Hostile(data, "H")) do
                if enemy.name == "Silverwind Refuge" then
                    silverwind = enemy
                end
            end
            h.truthy(silverwind, "tools/town-factions.csv marks Silverwind Refuge Alliance")
            local r = ns.Route.Plan(data, opts)
            -- 307 seconds longer on foot than the straight line, inside its ten
            -- minutes; the way by the Mor'shan Rampart passes Silverwing Grove.
            h.eq(table.concat(texts(r), " / "), "Walk to the Ashenvale-Felwood road / Walk to Splintertree Post")
            for _, s in ipairs(r.steps) do
                h.eq(s.danger, nil)
                h.truthy(ns.Geo.SegmentDistance(s.from, s.to, silverwind) > silverwind.radius,
                         ns.Route.StepText(s) .. " passes Silverwind Refuge")
            end
        end)
        h.it("walks the Alliance straight there: nothing on that line is hostile to it", function()
            for _, enemy in ipairs(ns.Graph.Hostile(data, "A")) do
                h.truthy(enemy.name ~= "Silverwind Refuge", "Silverwind Refuge is hostile to the Alliance")
            end
            local opts = fromTalondeep("A")
            h.eq(straightLine(opts).danger, nil)
            local r = ns.Route.Plan(data, opts)
            h.eq(table.concat(texts(r), " / "), "Walk to Splintertree Post")
            h.eq(r.steps[1].danger, nil)
        end)
        h.it("counts the other side's flight masters and marked towns, and draws capitals wider", function()
            local function summary(faction)
                local stops, towns, capitals = 0, 0, {}
                for _, enemy in ipairs(ns.Graph.Hostile(data, faction)) do
                    if enemy.rank == 1 then
                        stops = stops + 1
                    else
                        towns = towns + 1
                    end
                    if enemy.radius == ns.Graph.CAPITAL_RADIUS then
                        capitals[#capitals + 1] = enemy.name
                    end
                end
                table.sort(capitals)
                return stops, towns, table.concat(capitals, ", ")
            end
            local marked = { A = 0, H = 0 }
            for _, t in pairs(data.Towns) do
                if t.f then
                    marked[t.f] = marked[t.f] + 1
                end
            end
            local stops, towns, capitals = summary("H")
            h.eq(stops, 24, "32 Alliance flight masters less the 8 split neutral towns")
            h.eq(towns, marked.A, "every town the owner marked Alliance, and no other")
            h.truthy(towns > 0, "a count of nothing proves nothing")
            h.eq(capitals, "Ironforge, Stormwind", "Darnassus has no flight master and is not marked")
            stops, towns, capitals = summary("A")
            h.eq(stops, 23, "31 Horde flight masters less the same 8")
            h.eq(towns, marked.H, "every town the owner marked Horde, and no other")
            h.eq(capitals, "Orgrimmar, Thunder Bluff, Undercity")
        end)
        -- The reviewer's walk on 2026-09-22: an Alliance level 15 from the
        -- Orgrimmar zeppelin tower to Astranaar went in at the front gate and
        -- out at the west gate with no word of Orgrimmar, because every leg had
        -- a gate inside the capital's circle and a gate was exempt.
        h.it("never walks the Alliance through Orgrimmar unwarned: a gate is on the way, not the goal", function()
            local c, x, y = ns.Geo.ToWorld(data.Places, 1411, 0.509, 0.140)
            local walker = ns.Travel.For(15)
            local opts = { faction = "A", known = {}, speed = walker.speed, walk = walker.walk,
                           from = { name = "You", c = c, x = x, y = y, map = 1411, mx = 0.509, my = 0.140 },
                           to = ns.Search.Exact(data, "Astranaar", "A") }
            local orgrimmar
            for _, enemy in ipairs(ns.Graph.Hostile(data, "A")) do
                if enemy.name == "Orgrimmar" then
                    orgrimmar = enemy
                end
            end
            h.truthy(orgrimmar, "Orgrimmar's flight master is Horde")
            h.eq(ns.Graph.HostileAt(data, "A", opts.from), nil, "the tower stands outside the circle")
            local r = ns.Route.Plan(data, opts)
            -- It goes round, by the Southfury bridge: about 105 seconds longer
            -- on foot than through the capital, well inside its ten minutes.
            h.eq(table.concat(texts(r), " / "),
                 "Walk to the Southfury bridge / Walk to the Mor'shan Rampart / Walk to Astranaar")
            for _, s in ipairs(r.steps) do
                h.eq(s.danger, nil)
                h.truthy(ns.Geo.SegmentDistance(s.from, s.to, orgrimmar) > orgrimmar.radius,
                         ns.Route.StepText(s) .. " passes Orgrimmar")
            end
        end)
        h.it("leaves a city by its gate", function()
            local r = ns.Route.Plan(data, { faction = "A", known = {}, from = place("Stormwind City", "A"),
                                            to = place("Westfall", "A") })
            local t = texts(r)
            h.eq(t[1], "Ride to the Stormwind gates")
            h.eq(t[2], "Ride to the Westfall bridge")
            h.eq(t[3], "Ride to Sentinel Hill", "on to a place in Westfall, not stopping at its border")
            h.eq(#t, 3)
        end)
    end)
end

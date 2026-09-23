local _, ns = ...

-- Pure: turns the data plus what this character can use into stops and
-- weighted edges. Never touches a Blizzard global.
--
-- Ground travel goes zone by zone. A ride edge joins two points only when
-- they are in the same zone (the same UiMap); a crossing is a point that
-- belongs to both of its zones, so the router chains zones through crossings.
-- A tunnel or a lift is a crossing with two ends, one ordinary point in each
-- zone, joined by a "through" edge each way, so no arrow points through rock.
-- Cities are zones and their gates are crossings. A zone with no crossing is
-- an island: links and flights only.
local Graph = {}
ns.Graph = Graph

-- Core passes the character's real speed from Travel.For(level).
Graph.RIDE_DETOUR = 1.3            -- roads are not straight lines
Graph.HEARTH_SECONDS = 20          -- cast plus loading screen

-- A ride leg that passes an enemy town costs this much more: a penalty, not
-- a ban, so the router goes round whenever a way round is within ten minutes
-- and a destination is never made unreachable. The two radii are guesses
-- until walked: the closest reading at Silverwind Refuge, where the guards
-- killed a level 15 Horde player on 2026-09-22, was about 40 yd from its map
-- label, so 150 errs wide.
Graph.HOSTILE_SECONDS = 600
Graph.HOSTILE_RADIUS = 150         -- yards around an enemy town or flight master
Graph.CAPITAL_RADIUS = 400         -- yards around an enemy capital's

-- nil means open to both: only crossings and links carry a faction at all,
-- and most crossings have none.
local function legal(stopFaction, faction)
    return not stopFaction or stopFaction == "N" or stopFaction == faction
end

-- A capital is the one place named after the zone it stands in: "Orgrimmar"
-- in Orgrimmar, "Stormwind" in Stormwind City, and the town Darnassus in
-- Darnassus once tools/town-factions.csv marks it. Moonglade's two flight
-- masters are named so too, but they are twins (see Graph.Hostile), so never
-- hostile.
local function isCapital(data, name, map)
    local zone = data.Places[map]
    return zone ~= nil and zone.name:find(name, 1, true) == 1
end

-- Every place whose guards attack this faction, as { name, f, c, x, y, map,
-- radius, rank }: only places whose faction is known. Two sources, surest
-- first:
--   rank 1  the other side's flight masters, bar one whose short name a stop
--           this faction may use shares (Booty Bay, Gadgetzan, Everlook...:
--           the town is neutral, only its flight masters are split);
--   rank 2  the other side's towns, by the `f` Data/Towns.lua carries, which
--           comes only from the owner's marks in tools/town-factions.csv.
-- A place with no faction, or "N", is nobody's enemy. No faction, no list.
-- Sorted by rank, then name, map and position: when a leg passes two, it is
-- named after the surer one, and always the same one.
function Graph.Hostile(data, faction)
    local list = {}
    if not faction then
        return list
    end
    local usable = {}
    for _, n in pairs(data.Nodes) do
        if legal(n.f, faction) then
            usable[ns.Search.ShortName(n.name)] = true
        end
    end
    local function add(name, f, place, rank)
        if f and not legal(f, faction) then
            list[#list + 1] = { name = name, f = f, c = place.c, x = place.x, y = place.y, map = place.map,
                                rank = rank, radius = isCapital(data, name, place.map) and Graph.CAPITAL_RADIUS
                                    or Graph.HOSTILE_RADIUS }
        end
    end
    for _, n in pairs(data.Nodes) do
        local name = ns.Search.ShortName(n.name)
        if not usable[name] then
            add(name, n.f, n, 1)
        end
    end
    for _, t in pairs(data.Towns or {}) do
        add(t.name, t.f, t, 2)
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.name ~= b.name then return a.name < b.name end
        if a.map ~= b.map then return a.map < b.map end
        if a.x ~= b.x then return a.x < b.x end
        return a.y < b.y
    end)
    return list
end

-- The first hostile place whose circle holds this world point, or nil. The
-- planner warns when a destination is one.
function Graph.HostileAt(data, faction, point)
    for _, h in ipairs(Graph.Hostile(data, faction)) do
        if ns.Geo.Distance(point, h) <= h.radius then
            return h
        end
    end
    return nil
end

-- Is this the far end of a leg the player chose to go to: where they are
-- going (DEST), or a stopover the owner placed? Only such an end, inside a
-- circle, excuses the leg that arrives there. A gate, a tunnel mouth or a
-- flight master is only on the way: exempting those let an Alliance walk go
-- in at Orgrimmar's front gate and out at its west gate unwarned (review,
-- 2026-09-22).
local function chosen(stop)
    return stop.key == "DEST" or stop.stopover == true
end

-- The first of these hostile places (one continent's, in Graph.Hostile's
-- order) that the straight leg p->q passes within its radius of, as
-- { name, f }; nil when none does. A place is ignored when:
--   the leg starts inside its circle and heads away, never coming more than
--     a yard nearer its centre than where it starts -- whatever the stop, so
--     leaving a camp, an inn or a gate outward is free, but a replan from the
--     edge of a town that cuts through it is not (final review, 2026-09-22);
--   or the leg ends inside it at a chosen stop: you are going there on purpose.
local function dangerOn(hostile, p, q)
    local Geo = ns.Geo
    local x0, x1 = math.min(p.x, q.x), math.max(p.x, q.x)
    local y0, y1 = math.min(p.y, q.y), math.max(p.y, q.y)
    for _, h in ipairs(hostile or {}) do
        local r = h.radius
        -- The box round the leg, widened by r, is a cheap no for most places:
        -- it halves what the test costs Graph.Build (measured 2026-09-22).
        local near = h.x >= x0 - r and h.x <= x1 + r and h.y >= y0 - r and h.y <= y1 + r
        if near then
            local closest = Geo.SegmentDistance(p, q, h)
            local start = Geo.Distance(p, h)
            if closest <= r and not (start <= r and start <= closest + 1)
                    and not (chosen(q) and Geo.Distance(q, h) <= r) then
                return { name = h.name, f = h.f }
            end
        end
    end
    return nil
end

-- Seconds on the ground between two world positions at a speed in yards per
-- second (default: the slowest mount in Travel.lua, the one place mount
-- speed lives); math.huge across continents.
function Graph.RideSeconds(a, b, speed)
    return ns.Geo.Distance(a, b) * Graph.RIDE_DETOUR / (speed or ns.Travel.MOUNTS[1].yardsPerSecond)
end

local function addEdge(edges, from, to, edge)
    local list = edges[from]
    if not list then
        list = {}
        edges[from] = list
    end
    edge.to = to
    edge.copper = edge.copper or 0
    -- What the router minimises: the real seconds, plus the penalty on a leg
    -- past an enemy town. The penalty steers; it is never shown as time.
    edge.cost = edge.seconds + (edge.danger and Graph.HOSTILE_SECONDS or 0)
    list[#list + 1] = edge
end

local function stopFrom(key, p)
    return { key = key, nodeID = p.nodeID, name = p.name, c = p.c, x = p.x, y = p.y,
             map = p.map, mx = p.mx, my = p.my }
end

local function dockStop(data, stops, id)
    if stops[id] then
        return stops[id]
    end
    local d = data.Docks[id]
    if not d then
        return nil
    end
    local c, x, y = ns.Geo.ToWorld(data.Places, d.map, d.mx, d.my)
    if not c then
        return nil
    end
    stops[id] = { key = id, name = d.name, c = c, x = x, y = y, map = d.map, mx = d.mx, my = d.my }
    return stops[id]
end

-- A crossing's stop at one point, carrying the row's name, hazard and flag.
local function crossingStop(data, key, row, map, mx, my)
    local c, x, y = ns.Geo.ToWorld(data.Places, map, mx, my)
    if not c then
        return nil
    end
    return { key = key, name = row.name, c = c, x = x, y = y, map = map, mx = mx, my = my,
             warn = row.warn, unverified = row.unverified }
end

-- Is this point in zone `map`? A one-ended crossing is in both of its zones.
local function inZone(point, map)
    if point.zones then
        return point.zones[1] == map or point.zones[2] == map
    end
    return point.map ~= nil and point.map == map
end

-- The zone two points share, or nil.
local function sharedZone(p, q)
    if p.zones then
        return (inZone(q, p.zones[1]) and p.zones[1]) or (inZone(q, p.zones[2]) and p.zones[2]) or nil
    end
    return p.map and inZone(q, p.map) and p.map or nil
end

-- opts: faction "A"/"H"; known = { [nodeID] = true }; from and to are world
-- places { name, c, x, y, map, mx, my } (to may carry kind = "zone"); hearth
-- is one too, or nil; speed = ground yards per second and walk = true when on
-- foot (both from Travel.For); rough = true adds the old straight lines
-- across a whole continent, flagged rough, for when no chain of crossings
-- reaches the destination.
-- Returns { stops = { [key] = stop }, edges = { [key] = { edge, ... } } }
-- with the special keys START, DEST and HEARTH. A ride edge carries zone (the
-- UiMap it is walked in), walk, danger ({ name, f }: the enemy town its
-- straight line passes) and, in rough mode, rough. Every edge carries its
-- real seconds and a cost, the same plus Graph.HOSTILE_SECONDS on a danger
-- edge: the router minimises cost, the player is shown seconds. The edge
-- between the two ends of a two-ended crossing also carries through = true,
-- and its zone is the one being entered; it is one passage, never charged
-- for a town. Data/Stopovers.lua rows are stops keyed "s1", "s2"...
function Graph.Build(data, opts)
    local stops, edges = {}, {}
    local faction, known, speed = opts.faction, opts.known or {}, opts.speed

    for id, n in pairs(data.Nodes) do
        if known[id] and legal(n.f, faction) then
            local key = "f" .. id
            stops[key] = stopFrom(key, n)
            stops[key].nodeID = id
        end
    end
    for _, f in ipairs(data.Flights) do
        local a, b = "f" .. f[1], "f" .. f[2]
        if stops[a] and stops[b] then
            addEdge(edges, a, b, { kind = "fly", seconds = f[4], copper = f[3] })
        end
    end
    for _, link in ipairs(data.Links) do
        if legal(link.faction, faction) then
            local a, b = dockStop(data, stops, link.from), dockStop(data, stops, link.to)
            if a and b then
                addEdge(edges, a.key, b.key, { kind = link.kind, seconds = link.minutes * 60 })
                addEdge(edges, b.key, a.key, { kind = link.kind, seconds = link.minutes * 60 })
            end
        end
    end
    for i, x in ipairs(data.Crossings or {}) do
        if legal(x.faction, faction) then
            local key = "x" .. i
            local near = crossingStop(data, key, x, x.map, x.mx, x.my)
            if near and x.far then
                -- Two ends: each an ordinary point in its own zone, and the passage
                -- between them is the through edge, which alone carries `cross`.
                local far = crossingStop(data, key .. "far", x, x.far.map, x.far.mx, x.far.my)
                if far then
                    stops[key], stops[far.key] = near, far
                    local seconds = x.cross or Graph.RideSeconds(near, far, speed)
                    addEdge(edges, key, far.key, { kind = "ride", seconds = seconds, zone = far.map,
                                                   walk = opts.walk, through = true })
                    addEdge(edges, far.key, key, { kind = "ride", seconds = seconds, zone = near.map,
                                                   walk = opts.walk, through = true })
                end
            elseif near then
                near.zones, near.cross = { x.a, x.b }, x.cross
                stops[key] = near
            end
        end
    end

    -- A stopover is an ordinary point in one zone, like a tunnel's mouth: the
    -- pair loop below joins it to every other point in its zone, so a ride
    -- can bend through it round an enemy town.
    for i, s in ipairs(data.Stopovers or {}) do
        local c, x, y = ns.Geo.ToWorld(data.Places, s.map, s.mx, s.my)
        if c then
            local key = "s" .. i
            stops[key] = { key = key, name = s.name, c = c, x = x, y = y, map = s.map, mx = s.mx, my = s.my,
                           unverified = s.unverified, stopover = true }
        end
    end

    stops.START = stopFrom("START", opts.from)
    stops.DEST = stopFrom("DEST", opts.to)
    if opts.hearth then
        stops.HEARTH = stopFrom("HEARTH", opts.hearth)
        addEdge(edges, "START", "HEARTH", { kind = "hearth", seconds = Graph.HEARTH_SECONDS })
    end

    local keys = {}
    for key in pairs(stops) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    -- Only for a zone that holds no place (Search offers no other); a future quest destination is a point.
    -- A zone destination means "anywhere in the zone": a point already in it
    -- has arrived, so its leg to DEST costs nothing (Route drops a leg that
    -- short). A stop or an exact spot is travelled to as usual.
    local zoneMap = opts.to.kind == "zone" and opts.to.map or nil

    -- The enemy's towns, by continent: a leg is only ever tested against its own.
    local hostile = {}
    for _, h in ipairs(Graph.Hostile(data, faction)) do
        hostile[h.c] = hostile[h.c] or {}
        table.insert(hostile[h.c], h)
    end

    for _, pk in ipairs(keys) do
        for _, qk in ipairs(keys) do
            -- Nothing leaves DEST; nothing but the hearthstone arrives at HEARTH; nothing arrives at START.
            if pk ~= qk and pk ~= "DEST" and qk ~= "START" and qk ~= "HEARTH" then
                local p, q = stops[pk], stops[qk]
                local zone = sharedZone(p, q)
                if zone then
                    local seconds, danger = Graph.RideSeconds(p, q, speed), nil
                    if q.cross then
                        seconds = seconds + q.cross
                    end
                    if qk == "DEST" and zoneMap and inZone(p, zoneMap) then
                        seconds = 0   -- already in the zone: no leg is ridden, so none passes anything
                    else
                        danger = dangerOn(hostile[p.c], p, q)
                    end
                    addEdge(edges, pk, qk, { kind = "ride", seconds = seconds, zone = zone, walk = opts.walk,
                                             danger = danger })
                elseif opts.rough and p.c == q.c and (pk == "START" or pk == "HEARTH" or qk == "DEST") then
                    local danger = dangerOn(hostile[p.c], p, q)
                    addEdge(edges, pk, qk, { kind = "ride", seconds = Graph.RideSeconds(p, q, speed),
                                             walk = opts.walk, rough = true, danger = danger })
                end
            end
        end
    end

    return { stops = stops, edges = edges }
end

return Graph

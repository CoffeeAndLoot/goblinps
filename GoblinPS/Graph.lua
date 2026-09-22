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

-- nil means open to both: only crossings and links carry a faction at all,
-- and most crossings have none.
local function legal(stopFaction, faction)
    return not stopFaction or stopFaction == "N" or stopFaction == faction
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
-- UiMap it is walked in), walk and, in rough mode, rough. The edge between the
-- two ends of a two-ended crossing also carries through = true, and its zone
-- is the one being entered.
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

    for _, pk in ipairs(keys) do
        for _, qk in ipairs(keys) do
            -- Nothing leaves DEST; nothing but the hearthstone arrives at HEARTH; nothing arrives at START.
            if pk ~= qk and pk ~= "DEST" and qk ~= "START" and qk ~= "HEARTH" then
                local p, q = stops[pk], stops[qk]
                local zone = sharedZone(p, q)
                if zone then
                    local seconds = Graph.RideSeconds(p, q, speed)
                    if q.cross then
                        seconds = seconds + q.cross
                    end
                    if qk == "DEST" and zoneMap and inZone(p, zoneMap) then
                        seconds = 0
                    end
                    addEdge(edges, pk, qk, { kind = "ride", seconds = seconds, zone = zone, walk = opts.walk })
                elseif opts.rough and p.c == q.c and (pk == "START" or pk == "HEARTH" or qk == "DEST") then
                    addEdge(edges, pk, qk, { kind = "ride", seconds = Graph.RideSeconds(p, q, speed),
                                             walk = opts.walk, rough = true })
                end
            end
        end
    end

    return { stops = stops, edges = edges }
end

return Graph

local _, ns = ...

-- Pure: turns the data plus what this character can use into stops and
-- weighted edges. Never touches a Blizzard global.
local Graph = {}
ns.Graph = Graph

Graph.RIDE_YARDS_PER_SECOND = 11.2 -- a 100% mount; every ride time is a "~"
Graph.RIDE_DETOUR = 1.3            -- roads are not straight lines
Graph.TRANSFER_YARDS = 800         -- flight master to the dock in the same town, no further
Graph.HEARTH_SECONDS = 20          -- cast plus loading screen

local function legal(stopFaction, faction)
    return stopFaction == "N" or stopFaction == faction
end

local function rideSeconds(a, b)
    return ns.Geo.Distance(a, b) * Graph.RIDE_DETOUR / Graph.RIDE_YARDS_PER_SECOND
end

local function addEdge(edges, from, to, kind, seconds, copper)
    local list = edges[from]
    if not list then
        list = {}
        edges[from] = list
    end
    list[#list + 1] = { to = to, kind = kind, seconds = seconds, copper = copper or 0 }
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

-- opts: faction "A"/"H"; known = { [nodeID] = true }; from and to are world
-- places { name, c, x, y, map, mx, my }; hearth is one too, or nil.
-- Returns { stops = { [key] = stop }, edges = { [key] = { edge, ... } } }
-- with the special keys START, DEST and HEARTH.
function Graph.Build(data, opts)
    local stops, edges = {}, {}
    local faction, known = opts.faction, opts.known or {}

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
            addEdge(edges, a, b, "fly", f[4], f[3])
        end
    end
    for _, link in ipairs(data.Links) do
        if legal(link.faction, faction) then
            local a, b = dockStop(data, stops, link.from), dockStop(data, stops, link.to)
            if a and b then
                addEdge(edges, a.key, b.key, link.kind, link.minutes * 60)
                addEdge(edges, b.key, a.key, link.kind, link.minutes * 60)
            end
        end
    end

    local keys = {}
    for key in pairs(stops) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    for i = 1, #keys do
        for j = i + 1, #keys do
            local a, b = stops[keys[i]], stops[keys[j]]
            if ns.Geo.Distance(a, b) <= Graph.TRANSFER_YARDS then
                addEdge(edges, a.key, b.key, "ride", rideSeconds(a, b))
                addEdge(edges, b.key, a.key, "ride", rideSeconds(b, a))
            end
        end
    end

    stops.START = stopFrom("START", opts.from)
    stops.DEST = stopFrom("DEST", opts.to)
    local origins = { stops.START }
    if opts.hearth then
        stops.HEARTH = stopFrom("HEARTH", opts.hearth)
        addEdge(edges, "START", "HEARTH", "hearth", Graph.HEARTH_SECONDS)
        origins[2] = stops.HEARTH
    end
    for _, origin in ipairs(origins) do
        for _, key in ipairs(keys) do
            if stops[key].c == origin.c then
                addEdge(edges, origin.key, key, "ride", rideSeconds(origin, stops[key]))
            end
        end
        if origin.c == stops.DEST.c then
            addEdge(edges, origin.key, "DEST", "ride", rideSeconds(origin, stops.DEST))
        end
    end
    for _, key in ipairs(keys) do
        if stops[key].c == stops.DEST.c then
            addEdge(edges, key, "DEST", "ride", rideSeconds(stops[key], stops.DEST))
        end
    end

    return { stops = stops, edges = edges }
end

return Graph

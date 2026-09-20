local _, ns = ...

-- Pure lookup of destinations by name: flight stops and zones.
local Search = {}
ns.Search = Search

-- "Crossroads, The Barrens" -> "Crossroads"
function Search.ShortName(name)
    return (name:match("^([^,]+)") or name)
end

local function fromNode(id, n)
    return { kind = "stop", nodeID = id, name = Search.ShortName(n.name),
             c = n.c, x = n.x, y = n.y, map = n.map, mx = n.mx, my = n.my }
end

local function fromPlace(data, map, p)
    local c, x, y = ns.Geo.ToWorld(data.Places, map, 0.5, 0.5)
    return { kind = "zone", name = p.name, c = c, x = x, y = y, map = map, mx = 0.5, my = 0.5 }
end

local function legal(n, faction)
    return not faction or n.f == "N" or n.f == faction
end

-- Every candidate, zones first on a name tie so "Orgrimmar" means the city.
local function candidates(data, faction)
    local list = {}
    for map, p in pairs(data.Places) do
        list[#list + 1] = fromPlace(data, map, p)
    end
    for id, n in pairs(data.Nodes) do
        if legal(n, faction) then
            list[#list + 1] = fromNode(id, n)
        end
    end
    return list
end

-- Case-insensitive plain-text search. Names that start with the text come
-- first, then names that contain it; alphabetical inside each group.
function Search.Find(data, text, faction, limit)
    local needle = (text or ""):lower()
    if needle == "" then
        return {}
    end
    local ranked = {}
    for _, item in ipairs(candidates(data, faction)) do
        local at = item.name:lower():find(needle, 1, true)
        if at then
            item.rank = (at == 1) and 1 or 2
            ranked[#ranked + 1] = item
        end
    end
    table.sort(ranked, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.name ~= b.name then return a.name < b.name end
        return a.kind > b.kind
    end)
    local out = {}
    for i = 1, math.min(limit or 8, #ranked) do
        out[i] = ranked[i]
    end
    return out
end

-- The game says "The Crossroads" where the flight stop is "Crossroads".
local function plain(name)
    return ((name or ""):lower():gsub("^the%s+", ""))
end

-- Whole-name match, used for the hearthstone bind name. Nil when unknown.
-- A zone wins over a stop of the same name; faction nil means any.
function Search.Exact(data, name, faction)
    local needle = plain(name)
    if needle == "" then
        return nil
    end
    local best
    for bind, inn in pairs(data.Inns or {}) do
        if plain(bind) == needle then
            if inn.stop then
                return Search.Exact(data, inn.stop, faction)
            end
            local c, x, y = ns.Geo.ToWorld(data.Places, inn.map, inn.mx, inn.my)
            if c then
                return { kind = "inn", name = bind, c = c, x = x, y = y, map = inn.map, mx = inn.mx, my = inn.my }
            end
        end
    end
    for _, item in ipairs(candidates(data, faction)) do
        if plain(item.name) == needle then
            local better = not best or (item.kind == "zone" and best.kind ~= "zone")
                or (item.kind == best.kind and (item.nodeID or 0) < (best.nodeID or 0))
            if better then
                best = item
            end
        end
    end
    return best
end

return Search

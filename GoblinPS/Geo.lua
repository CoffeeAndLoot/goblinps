local _, ns = ...

-- Pure geometry. World positions are { c = continent, x = yards, y = yards }.
local Geo = {}
ns.Geo = Geo

-- Map coords (0..1) on a UiMap to continent and world yards. The inverse of
-- world_to_map in tools/build_graph.py: map x runs along world -y, map y
-- along world -x.
function Geo.ToWorld(places, map, mx, my)
    local p = places and places[map]
    if not p or not mx or not my then
        return nil
    end
    return p.c, p.x1 - my * (p.x1 - p.x0), p.y1 - mx * (p.y1 - p.y0)
end

-- Yards between two world positions; math.huge across continents.
function Geo.Distance(a, b)
    if not a or not b or a.c ~= b.c then
        return math.huge
    end
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- The closest of every crossing and dock to a world position (c, x, y),
-- compared in world yards on the same continent only. `data` is the data
-- root: Places (so each candidate's map coords can be converted the same way
-- as the player's own), Crossings and Docks. Returns { name, yards }, or nil
-- when nothing shares this continent -- the caller (Core.WhereLine) drops the
-- "nearest" part of the line in that case rather than naming something an
-- ocean away.
function Geo.Nearest(data, c, x, y)
    local best, bestYards

    local function consider(name, map, mx, my)
        local pc, px, py = Geo.ToWorld(data.Places, map, mx, my)
        if pc ~= c then
            return
        end
        local yards = Geo.Distance({ c = c, x = x, y = y }, { c = pc, x = px, y = py })
        if not bestYards or yards < bestYards then
            bestYards, best = yards, { name = name, yards = yards }
        end
    end

    for _, crossing in ipairs(data.Crossings or {}) do
        consider(crossing.name, crossing.map, crossing.mx, crossing.my)
    end
    for _, dock in pairs(data.Docks or {}) do
        consider(dock.name, dock.map, dock.mx, dock.my)
    end
    return best
end

return Geo

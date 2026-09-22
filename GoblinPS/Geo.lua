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

-- Yards from world position p to the straight segment a-b; math.huge unless
-- all three are on one continent. A ride leg is a straight line, so this is
-- how close one passes to a place.
function Geo.SegmentDistance(a, b, p)
    if not a or not b or not p or a.c ~= b.c or a.c ~= p.c then
        return math.huge
    end
    local dx, dy = b.x - a.x, b.y - a.y
    local t, length2 = 0, dx * dx + dy * dy
    if length2 > 0 then
        t = math.max(0, math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length2))
    end
    local ex, ey = a.x + t * dx - p.x, a.y + t * dy - p.y
    return math.sqrt(ex * ex + ey * ey)
end

-- The closest of every crossing (either end of a tunnel) and dock to a world position (c, x, y),
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
        local far = crossing.far   -- a tunnel's other mouth goes by the same name
        if far then
            consider(crossing.name, far.map, far.mx, far.my)
        end
    end
    for _, dock in pairs(data.Docks or {}) do
        consider(dock.name, dock.map, dock.mx, dock.my)
    end
    return best
end

return Geo

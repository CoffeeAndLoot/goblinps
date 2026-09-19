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

return Geo

-- Which crossing coordinates are most likely wrong?
--
-- Every row in GoblinPS/Data/Crossings.lua is an estimate until somebody walks
-- it, and there are 56 of them. Each zone carries a world rectangle from the
-- generator, and a border can only lie where two zones' rectangles overlap, so
-- a point outside that overlap is provably in the wrong place. This ranks the
-- rows by how far outside they sit, to say which ones deserve a detour first.
--
-- A row at 0 is NOT proved right: the rectangles are bounding boxes and they
-- overlap generously, so a point can sit inside both and still be in the wrong
-- gully. 0 only means nothing is detectably wrong from the desk.
--
-- Run from the repository root (see CLAUDE.md for the lupa incantation):
--   python -c "import lupa.lua51 as L; L.LuaRuntime().execute(open('tools/survey_crossings.lua').read())"

local ns = {}
for _, path in ipairs({
    "GoblinPS/Geo.lua",
    "GoblinPS/Data/Places.lua",
    "GoblinPS/Data/Crossings.lua",
}) do
    assert(loadfile(path), "run this from the repository root")("GoblinPS", ns)
end

local places, crossings = ns.Data.Places, ns.Data.Crossings

local function distToRect(x0, x1, y0, y1, x, y)
    local dx = math.max(x0 - x, 0, x - x1)
    local dy = math.max(y0 - y, 0, y - y1)
    return math.sqrt(dx * dx + dy * dy)
end

-- Yards from a point to the area two zones share; math.huge when their
-- rectangles never meet, which would mean the border is invented.
local function fromSharedEdge(a, b, c, x, y)
    local p, q = places[a], places[b]
    if not p or not q or p.c ~= c or q.c ~= c then
        return math.huge
    end
    local x0, x1 = math.max(p.x0, q.x0), math.min(p.x1, q.x1)
    local y0, y1 = math.max(p.y0, q.y0), math.min(p.y1, q.y1)
    if x0 > x1 or y0 > y1 then
        return math.huge
    end
    return distToRect(x0, x1, y0, y1, x, y)
end

-- Yards from a map point to its own zone's rectangle; math.huge when unplaceable.
local function fromOwnZone(map, mx, my)
    local c, x, y = ns.Geo.ToWorld(places, map, mx, my)
    local p = places[map]
    if not c then
        return math.huge
    end
    return distToRect(p.x0, p.x1, p.y0, p.y1, x, y)
end

-- A two-ended row (a tunnel, a lift: `far` set) has a mouth inside each zone,
-- not on the border, so each end is measured against its own zone instead.
local rows = {}
for i, r in ipairs(crossings) do
    local c, x, y = ns.Geo.ToWorld(places, r.map, r.mx, r.my)
    local away = c and fromSharedEdge(r.a, r.b, c, x, y) or math.huge
    if r.far then
        away = math.max(fromOwnZone(r.map, r.mx, r.my), fromOwnZone(r.far.map, r.far.mx, r.far.my))
    end
    rows[#rows + 1] = {
        i = i,
        name = r.name,
        a = places[r.a] and places[r.a].name or ("zone " .. tostring(r.a)),
        b = places[r.b] and places[r.b].name or ("zone " .. tostring(r.b)),
        away = away,
        unverified = r.unverified and true or false,
        twoEnded = r.far ~= nil,
    }
end

table.sort(rows, function(p, q)
    if p.away ~= q.away then
        return p.away > q.away
    end
    return p.i < q.i
end)

print("Crossings whose point is outside the area their two zones share")
print("(a two-ended row: whose ends are not each inside their own zone).")
print("")
print(string.format("| %9s | %-38s | %-45s | %s |", "Yards off", "Crossing", "Between", "Note"))
print(string.format("|%s|%s|%s|---|", string.rep("-", 11), string.rep("-", 40), string.rep("-", 47)))

local off = 0
for _, r in ipairs(rows) do
    if r.away > 0 then
        off = off + 1
        local note = r.unverified and "already flagged unverified" or ""
        if r.twoEnded then
            note = "two ends: an end is outside its own zone"
        elseif r.away == math.huge then
            note = "THESE ZONES DO NOT TOUCH: the border is invented"
        end
        print(string.format("| %9s | %-38s | %-45s | %s |",
            r.away == math.huge and "no border" or string.format("%.0f", r.away),
            r.name, r.a .. " and " .. r.b, note))
    end
end

print("")
print(string.format("%d of %d rows sit outside; the other %d are inside both zones,",
    off, #rows, #rows - off))
print("which means nothing is detectably wrong with them, not that they are right.")

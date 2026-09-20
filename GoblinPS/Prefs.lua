local _, ns = ...

-- Pure: the account-wide preferences table (GoblinPSDB). Preferences, recent
-- destinations and window positions only. Known flight paths live per
-- character in GoblinPSCharDB and are owned by Known.lua.
local Prefs = {}
ns.Prefs = Prefs

Prefs.MAX_RECENTS = 8
local LAYOUTS = { wide = "tall", tall = "wide" } -- each layout's other one

-- Returns db (or a new table) with every missing preference filled in.
function Prefs.Init(db)
    db = type(db) == "table" and db or {}
    if not LAYOUTS[db.layout] then
        db.layout = "wide"
    end
    db.recents = type(db.recents) == "table" and db.recents or {}
    db.positions = type(db.positions) == "table" and db.positions or {}
    db.minimap = type(db.minimap) == "table" and db.minimap or {}
    if type(db.minimap.angle) ~= "number" then
        db.minimap.angle = 215
    end
    db.minimap.hide = db.minimap.hide == true
    return db
end

function Prefs.ToggleLayout(db)
    db.layout = LAYOUTS[db.layout] or "wide"
    return db.layout
end

-- Newest first, no duplicates, capped.
function Prefs.Remember(db, name)
    if not name or name == "" then
        return
    end
    for i = #db.recents, 1, -1 do
        if db.recents[i] == name then
            table.remove(db.recents, i)
        end
    end
    table.insert(db.recents, 1, name)
    while #db.recents > Prefs.MAX_RECENTS do
        table.remove(db.recents)
    end
end

function Prefs.SavePosition(db, window, point, relativePoint, x, y)
    db.positions[window] = { point = point, relativePoint = relativePoint, x = x, y = y }
end

-- An entry saved before relativePoint existed is read as matching point.
-- A hostile or malformed entry (not a table, or point/x/y of the wrong
-- type) is treated as no saved position, never as a value to draw with.
function Prefs.Position(db, window)
    local p = db.positions[window]
    if type(p) ~= "table" or type(p.point) ~= "string" or type(p.x) ~= "number" or type(p.y) ~= "number" then
        return nil
    end
    local relativePoint = type(p.relativePoint) == "string" and p.relativePoint or p.point
    return { point = p.point, relativePoint = relativePoint, x = p.x, y = p.y }
end

return Prefs

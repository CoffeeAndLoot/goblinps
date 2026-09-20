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

function Prefs.SavePosition(db, window, point, x, y)
    db.positions[window] = { point = point, x = x, y = y }
end

function Prefs.Position(db, window)
    return db.positions[window]
end

return Prefs

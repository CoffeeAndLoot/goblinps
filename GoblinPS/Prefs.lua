local _, ns = ...

-- Pure: the account-wide preferences table (GoblinPSDB). Preferences, recent
-- destinations and window positions only. Known flight paths live per
-- character in GoblinPSCharDB and are owned by Known.lua.
--
-- One other key shares the table without belonging to this file: `probe`, the
-- dump from `/gps probe zones`, written and overwritten by Core.lua. It rides
-- here because SavedVariables is the only way to get a table too long for chat
-- onto the desktop, and a second saved variable would mean a TOC change and a
-- full client restart. It is diagnostic, never read back, and safe to delete.
-- Prefs.Init deliberately does not create or validate it.
local Prefs = {}
ns.Prefs = Prefs

Prefs.MAX_RECENTS = 8
Prefs.HEARTH_SAVING_DEFAULT = 300   -- five minutes
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
    -- The least the hearthstone must save to be worth its half-hour cooldown,
    -- in seconds. 0 means "always take the fastest route". A hostile or
    -- missing value falls back to the default rather than breaking planning.
    if type(db.hearthSaving) ~= "number" or db.hearthSaving < 0 then
        db.hearthSaving = Prefs.HEARTH_SAVING_DEFAULT
    end
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

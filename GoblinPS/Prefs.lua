local _, ns = ...

-- Pure: the account-wide preferences table (GoblinPSDB). Preferences, recent
-- destinations and window positions, plus `known`: each character's learned
-- flight paths, as { ["Name-Realm"] = { [nodeID] = true } }. That store is
-- owned by Known.lua and Core.lua; this file only guarantees it is a table.
-- `trips`: each character's trip in progress, as
-- { ["Name-Realm"] = { to = "<place name>" } }, owned by Core.lua,
-- account-wide for the same reason as `known`.
--
-- It is account-wide, not per character, so one save holds every character.
-- On build 1.60.1.69913 that choice buys nothing yet: verified in the client
-- 2026-09-21, this build writes SavedVariables files on every reload and
-- loads none of them back, account-wide or per character, GoblinPS's or any
-- other addon's. Everything here lasts one session until Blizzard fixes it.
--
-- One other key shares the table without belonging to this file: `probe`, the
-- dump from `/gps probe zones`, written and overwritten by Core.lua. It rides
-- here because SavedVariables is the only way to get a table too long for chat
-- onto the desktop, and a second saved variable would mean a TOC change and a
-- full client restart. It is diagnostic, never read back, and safe to delete.
-- Prefs.Init deliberately does not create or validate it.
--
-- `arrive`: the player's arrival radii in yards, { ride, fly, transport,
-- hearth }, set from the settings panel and repaired here.
local Prefs = {}
ns.Prefs = Prefs

Prefs.MAX_RECENTS = 8
Prefs.HEARTH_SAVING_DEFAULT = 300   -- five minutes

-- The settings panel's hearthstone row, in whole minutes. `/gps hearth` takes
-- any number of minutes; only the panel's buttons keep to this range.
Prefs.HEARTH_MINUTES = { min = 0, max = 30, step = 1 }

-- How close counts as arriving, per setting, in yards. The defaults are
-- Trip.ARRIVE's own, so the rule and the panel cannot disagree; `kinds` is
-- the Trip step kinds each setting covers. One value serves boat, zeppelin
-- and tram: all three arrive when you step off at a dock. Its floor is 100
-- yards because several dock coordinates are still estimates, and a radius
-- tighter than the error in the data would never let a trip advance. The
-- 800-yard default stays until a dock is measured in game.
local ARRIVE = ns.Trip.ARRIVE
Prefs.ARRIVE = {
    ride      = { default = ARRIVE.ride, min = 10, max = 200, step = 10, kinds = { "ride" } },
    fly       = { default = ARRIVE.fly, min = 50, max = 500, step = 25, kinds = { "fly" } },
    transport = { default = ARRIVE.zeppelin, min = 100, max = 1000, step = 50,
                  kinds = { "zeppelin", "boat", "tram" } },
    hearth    = { default = ARRIVE.hearth, min = 100, max = 1000, step = 50, kinds = { "hearth" } },
}

-- Returns db (or a new table) with every missing preference filled in.
function Prefs.Init(db)
    db = type(db) == "table" and db or {}
    -- The wide/tall switch is gone (plan 8). A save from before it still
    -- carries the choice; drop it rather than keep a key nothing reads.
    db.layout = nil
    db.recents = type(db.recents) == "table" and db.recents or {}
    db.positions = type(db.positions) == "table" and db.positions or {}
    db.minimap = type(db.minimap) == "table" and db.minimap or {}
    if type(db.minimap.angle) ~= "number" then
        db.minimap.angle = 215
    end
    db.minimap.hide = db.minimap.hide == true
    db.known = type(db.known) == "table" and db.known or {}
    db.trips = type(db.trips) == "table" and db.trips or {}
    -- The least the hearthstone must save to be worth its cooldown (an hour on
    -- build 1.60.1.69913, shorter with a guild's Hasty Hearth perk), in
    -- seconds. 0 means "always take the fastest route". A hostile or
    -- missing value falls back to the default rather than breaking planning.
    if type(db.hearthSaving) ~= "number" or db.hearthSaving < 0 then
        db.hearthSaving = Prefs.HEARTH_SAVING_DEFAULT
    end
    -- Arrival radii. A hostile, missing or out-of-range value (NaN included:
    -- it is the one number unequal to itself) falls back to its default. The
    -- panel can only set values inside the range, so one outside it was
    -- never the player's choice.
    db.arrive = type(db.arrive) == "table" and db.arrive or {}
    for key, range in pairs(Prefs.ARRIVE) do
        local v = db.arrive[key]
        if type(v) ~= "number" or v ~= v or v < range.min or v > range.max then
            db.arrive[key] = range.default
        end
    end
    return db
end

-- One press of a settings button: `value` moved one step up (direction 1) or
-- down (-1), clamped into the range. A value it cannot read starts from the
-- floor.
function Prefs.Step(value, range, direction)
    local v = (type(value) == "number" and value or range.min) + direction * range.step
    return math.max(range.min, math.min(range.max, v))
end

-- Reset to defaults: the hearthstone's saving and every arrival radius.
function Prefs.Reset(db)
    db.hearthSaving = Prefs.HEARTH_SAVING_DEFAULT
    db.arrive = {}
    for key, range in pairs(Prefs.ARRIVE) do
        db.arrive[key] = range.default
    end
end

-- The radii by Trip step kind, for Trip.Check: each setting fanned out to
-- the kinds it covers.
function Prefs.ArriveRadii(db)
    local out = {}
    for key, range in pairs(Prefs.ARRIVE) do
        for _, kind in ipairs(range.kinds) do
            out[kind] = db.arrive[key]
        end
    end
    return out
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

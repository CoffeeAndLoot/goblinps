local _, ns = ...

-- Pure lookup of destinations by name: flight stops and inn towns, never zones.
local Search = {}
ns.Search = Search

-- "Crossroads, The Barrens" -> "Crossroads"
function Search.ShortName(name)
    return (name:match("^([^,]+)") or name)
end

-- For a badge or the dash's small glass, not a sentence: ShortName, with a
-- crossing's leading lowercase "the " (Data/Crossings.lua writes them that
-- way so directions read as sentences, "Walk to the Mor'shan Rampart") cut.
-- A capital "The" is part of the name itself ("The Barrens") and stays;
-- match is exactly "^the " (case-sensitive, requires the trailing space) so
-- a name that merely starts with the letters, like "theramore", is untouched.
function Search.Label(name)
    return (Search.ShortName(name):gsub("^the ", "", 1))
end

-- The zone a place stands in, by name: a search word, never a destination.
local function zoneOf(data, map)
    local place = data.Places[map]
    return place and place.name
end

local function fromNode(data, id, n)
    return { kind = "stop", nodeID = id, name = Search.ShortName(n.name), zone = zoneOf(data, n.map),
             c = n.c, x = n.x, y = n.y, map = n.map, mx = n.mx, my = n.my }
end

-- An inn row with its own map position is a town; nil for one on a map we
-- do not have, or for a row that points at a stop or a town instead.
local function fromInn(data, bind, inn)
    if inn.stop or inn.town or not inn.map then
        return nil
    end
    local c, x, y = ns.Geo.ToWorld(data.Places, inn.map, inn.mx, inn.my)
    if not c then
        return nil
    end
    return { kind = "town", name = bind, zone = zoneOf(data, inn.map),
             c = c, x = x, y = y, map = inn.map, mx = inn.mx, my = inn.my }
end

local function legal(n, faction)
    return not faction or n.f == "N" or n.f == faction
end

-- Every destination the search can offer: every flight stop this faction may
-- use (nil means any) and every inn town. A destination is a place, never a
-- zone: a zone destination routed only to its border. The planner measures
-- its drop-down over this.
function Search.Candidates(data, faction)
    local list = {}
    for id, n in pairs(data.Nodes) do
        if legal(n, faction) then
            list[#list + 1] = fromNode(data, id, n)
        end
    end
    for bind, inn in pairs(data.Inns or {}) do
        list[#list + 1] = fromInn(data, bind, inn)
    end
    return list
end

-- Case-insensitive plain-text search. Names that start with the text come
-- first, then names that contain it, then places whose zone's name contains
-- it; alphabetical inside each group.
function Search.Find(data, text, faction, limit)
    local needle = (text or ""):lower()
    if needle == "" then
        return {}
    end
    local ranked = {}
    for _, item in ipairs(Search.Candidates(data, faction)) do
        local at = item.name:lower():find(needle, 1, true)
        if at then
            item.rank = (at == 1) and 1 or 2
        elseif item.zone and item.zone:lower():find(needle, 1, true) then
            item.rank = 3
        end
        if item.rank then
            ranked[#ranked + 1] = item
        end
    end
    table.sort(ranked, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.name ~= b.name then return a.name < b.name end
        return (a.nodeID or math.huge) < (b.nodeID or math.huge)
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

-- Whole-name match over the same places Find offers, used for the hearthstone
-- bind name, the recents and a saved trip. Nil when unknown, and for a zone.
-- A bind name that is an inn beside a stop, or an inn building in a town,
-- follows its row to that place. The lowest nodeID wins a name tie, a stop
-- before a town; faction nil means any. skipInns is internal: set on the
-- recursive call so an inn that (wrongly) names itself cannot recurse forever.
function Search.Exact(data, name, faction, skipInns)
    local needle = plain(name)
    if needle == "" then
        return nil
    end
    if not skipInns then
        for bind, inn in pairs(data.Inns or {}) do
            local target = inn.stop or inn.town
            if target and plain(bind) == needle then
                return Search.Exact(data, target, faction, true)
            end
        end
    end
    local best
    for _, item in ipairs(Search.Candidates(data, faction)) do
        if plain(item.name) == needle
            and (not best or (item.nodeID or math.huge) < (best.nodeID or math.huge)) then
            best = item
        end
    end
    return best
end

return Search

local _, ns = ...

-- Pure lookup of destinations by name: flight stops, towns (the game's own
-- AreaPOI table, Data/Towns.lua), hand-written inn towns, and a zone only
-- when it holds none of these.
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

local function legal(n, faction)
    return not faction or n.f == "N" or n.f == faction
end

-- enemy is the stop's faction letter when this faction may not fly from it.
-- It is still a place to go: Graph only refuses to fly there.
local function fromNode(data, id, n, faction)
    return { kind = "stop", nodeID = id, name = Search.ShortName(n.name), zone = zoneOf(data, n.map),
             enemy = not legal(n, faction) and n.f or nil,
             c = n.c, x = n.x, y = n.y, map = n.map, mx = n.mx, my = n.my }
end

local function fromZone(data, map, p)
    local c, x, y = ns.Geo.ToWorld(data.Places, map, 0.5, 0.5)
    return { kind = "zone", name = p.name, zone = p.name, c = c, x = x, y = y, map = map, mx = 0.5, my = 0.5 }
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

-- A generated town. Its faction is inferred (tools/build_graph.py) and often
-- absent; a town with none is nobody's enemy.
local function fromTown(data, id, t, faction)
    return { kind = "town", townID = id, name = t.name, zone = zoneOf(data, t.map),
             enemy = t.f and not legal(t, faction) and t.f or nil,
             c = t.c, x = t.x, y = t.y, map = t.map, mx = t.mx, my = t.my }
end

-- The game says "The Crossroads" where the flight stop is "Crossroads".
local function plain(name)
    return ((name or ""):lower():gsub("^the%s+", ""))
end

-- Every destination the search can offer: every flight stop, the other
-- faction's marked enemy (faction nil means none is), every town and every
-- inn town. A zone is offered only when it holds none of these, so that no
-- zone is out of reach; one that holds a place is only a search word,
-- because a zone destination routes to its border. The planner measures its
-- drop-down over this.
--
-- Two rows are never one place. An enemy stop that shares its name with a
-- stop this faction may use (Booty Bay, Gadgetzan, Everlook) is left out:
-- the usable one is the same town. A generated town whose name is a
-- hand-written inn row's is left out too: the hand-written row says what
-- that name is, whether a stop ("Theramore Isle") or an inn town
-- ("Kharanos"). The generator has already dropped every town that shares a
-- name and a zone with a flight stop.
function Search.Candidates(data, faction)
    local list, held, usable, written = {}, {}, {}, {}
    for _, n in pairs(data.Nodes) do
        if legal(n, faction) then
            usable[Search.ShortName(n.name)] = true
        end
    end
    for id, n in pairs(data.Nodes) do
        if legal(n, faction) or not usable[Search.ShortName(n.name)] then
            list[#list + 1] = fromNode(data, id, n, faction)
        end
    end
    for bind, inn in pairs(data.Inns or {}) do
        written[plain(bind)] = true
        list[#list + 1] = fromInn(data, bind, inn)
    end
    for id, t in pairs(data.Towns or {}) do
        if not written[plain(t.name)] then
            list[#list + 1] = fromTown(data, id, t, faction)
        end
    end
    for _, item in ipairs(list) do
        held[item.map] = true
    end
    for map, p in pairs(data.Places) do
        if not held[map] then
            list[#list + 1] = fromZone(data, map, p)
        end
    end
    return list
end

-- Which of two same-named places comes first: a place this faction may use,
-- then a stop, then a town, then a zone; among stops the lowest nodeID, among
-- towns the lowest townID (the two ends of a tunnel share a name).
local ORDER = { stop = 1, town = 2, zone = 3 }
local function before(a, b)
    local aEnemy, bEnemy = a.enemy ~= nil, b.enemy ~= nil
    if aEnemy ~= bEnemy then return bEnemy end
    if a.kind ~= b.kind then return ORDER[a.kind] < ORDER[b.kind] end
    return (a.nodeID or a.townID or 0) < (b.nodeID or b.townID or 0)
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
        return before(a, b)
    end)
    local out = {}
    for i = 1, math.min(limit or 8, #ranked) do
        out[i] = ranked[i]
    end
    return out
end

-- Whole-name match over the same places Find offers, used for the hearthstone
-- bind name, the recents and a saved trip. Nil when unknown, and for a zone
-- that holds places. A bind name that is an inn beside a stop, or an inn
-- building in a town, follows its row to that place. On a name tie a stop
-- this faction may use wins, then the lowest nodeID, then a town, then a
-- zone; faction nil means any. skipInns is internal: set on the
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
        if plain(item.name) == needle and (not best or before(item, best)) then
            best = item
        end
    end
    return best
end

return Search

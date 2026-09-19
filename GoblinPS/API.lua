local _, ns = ...

-- The ONLY file that calls Blizzard game APIs (C_*, unit, item, map
-- functions). Everything is defensive: a missing API or an odd return means
-- "unknown", never an error. Core.lua additionally touches Blizzard globals
-- to register the slash command (SLASH_*, SlashCmdList) and print to chat.
local API = {}
ns.API = API

local CONTINENT_MAPS = { 1414, 1415 } -- Kalimdor, Eastern Kingdoms
local HEARTHSTONE = 6948
local REAL_COOLDOWN_SECONDS = 30      -- longer than any global cooldown

-- "A", "H" or nil.
function API.Faction()
    local group = UnitFactionGroup("player")
    if group == "Alliance" then
        return "A"
    elseif group == "Horde" then
        return "H"
    end
    return nil
end

-- The client's view of the flight nodes: { { nodeID, name, known }, ... }.
-- Read live every time; never saved.
function API.TaxiNodes()
    local out = {}
    if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then
        return out
    end
    for _, map in ipairs(CONTINENT_MAPS) do
        for _, info in ipairs(C_TaxiMap.GetTaxiNodesForMap(map) or {}) do
            out[#out + 1] = { nodeID = info.nodeID, name = info.name, known = not info.isUndiscovered }
        end
    end
    return out
end

-- { [nodeID] = true } for every flight path this character has discovered.
-- If the in-game probe shows isUndiscovered is unreliable, only this function
-- changes (to recording C_TaxiMap.GetAllTaxiNodes at flight masters).
function API.KnownNodes()
    local known = {}
    for _, node in ipairs(API.TaxiNodes()) do
        if node.known then
            known[node.nodeID] = true
        end
    end
    return known
end

-- The player's position on the nearest map we have data for: uiMapID, x, y
-- (0..1). Nil inside instances, on a map we do not know, or when the client
-- reports the origin (an unset position, not a real spot on the map).
local PARENT_HOP_LIMIT = 10 -- generous; a real map hierarchy is a handful deep

function API.PlayerMapPosition(places)
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo and C_Map.GetPlayerMapPosition) then
        return nil
    end
    local map = C_Map.GetBestMapForUnit("player")
    local hops = 0
    while map and map ~= 0 and not places[map] and hops < PARENT_HOP_LIMIT do
        local info = C_Map.GetMapInfo(map)
        map = info and info.parentMapID
        hops = hops + 1
    end
    if not map or map == 0 or not places[map] then
        return nil
    end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then
        return nil
    end
    local x, y = pos:GetXY()
    if x == 0 and y == 0 then
        return nil
    end
    return map, x, y
end

-- The hearthstone's bind name, or nil when it is missing or on cooldown.
-- Absent means absent: the router never waits for it.
function API.HearthBindName()
    if not (C_Item and C_Item.GetItemCount and C_Item.GetItemCooldown) then
        return nil
    end
    if C_Item.GetItemCount(HEARTHSTONE) == 0 then
        return nil
    end
    local start, duration = C_Item.GetItemCooldown(HEARTHSTONE)
    if start and start > 0 and duration and duration > REAL_COOLDOWN_SECONDS then
        return nil
    end
    return GetBindLocation()
end

return API

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

-- THROWAWAY PROBE (2026-09-19): isUndiscovered is dead on this build, so we
-- need to see what the client exposes while a flight master's map is open.
-- `/gps taxiprobe` arms it; it prints on TAXIMAP_OPENED. Delete once
-- KnownNodes is rebuilt on the answer.
local probeFrame
function API.StartTaxiProbe(say)
    if probeFrame then
        say("Taxi probe already armed. Open a flight master's map.")
        return
    end
    local function call(name, ...)
        local fn = _G[name]
        if not fn then
            return "missing"
        end
        local ok, result = pcall(fn, ...)
        return ok and tostring(result) or ("error: " .. tostring(result))
    end
    local function dump(label)
        local getTaxiMapID = rawget(_G, "GetTaxiMapID")
        local taxiMap = getTaxiMapID and getTaxiMapID() or nil
        say(label .. " GetTaxiMapID=" .. tostring(taxiMap) .. " NumTaxiNodes=" .. call("NumTaxiNodes")
            .. " bestMap=" .. tostring(C_Map.GetBestMapForUnit("player")))
        for _, map in ipairs({ taxiMap or false, 1414, 1415, 947, C_Map.GetBestMapForUnit("player") or false }) do
            if map then
                local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, map)
                local counts, line = {}, {}
                for _, n in ipairs(ok and nodes or {}) do
                    counts[n.state] = (counts[n.state] or 0) + 1
                    line[#line + 1] = n.nodeID .. ":" .. tostring(n.state)
                end
                say(("GetAllTaxiNodes(%s) ok=%s n=%d current=%s reachable=%s unreachable=%s"):format(
                    tostring(map), tostring(ok), #line, tostring(counts[0]), tostring(counts[1]), tostring(counts[2])))
                for i = 1, #line, 15 do
                    say("  " .. table.concat(line, " ", i, math.min(i + 14, #line)))
                end
            end
        end
        local legacy = tonumber(call("NumTaxiNodes")) or 0
        local types = {}
        for i = 1, legacy do
            types[#types + 1] = call("TaxiNodeName", i) .. "=" .. call("TaxiNodeGetType", i)
        end
        for i = 1, #types, 4 do
            say("  legacy " .. table.concat(types, " | ", i, math.min(i + 3, #types)))
        end
    end
    probeFrame = CreateFrame("Frame")
    probeFrame:RegisterEvent("TAXIMAP_OPENED")
    probeFrame:SetScript("OnEvent", function(_, _, system)
        dump("TAXIMAP_OPENED system=" .. tostring(system) .. " (now)")
        C_Timer.After(0.5, function()
            dump("(0.5s later)")
        end)
    end)
    say("Taxi probe armed. Open a flight master's map, then screenshot the chat.")
end

return API

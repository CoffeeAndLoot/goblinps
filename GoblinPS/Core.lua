local _, ns = ...

-- Slash commands. For now the whole addon is "/gps to <place>" printed in
-- chat; the planner window and dash unit come in the next plan.
local API, Geo, Search, Route, Known = ns.API, ns.Geo, ns.Search, ns.Route, ns.Known

local function say(text)
    print("|cff6fe08aGoblinPS|r " .. text)
end

-- This character's discovered flight paths, remembered between flight master
-- visits (saved per character). Looked up lazily: saved variables load after
-- this file runs.
local function knownStore()
    GoblinPSCharDB = GoblinPSCharDB or {}
    GoblinPSCharDB.known = GoblinPSCharDB.known or {}
    return GoblinPSCharDB.known
end

local function here()
    local map, mx, my = API.PlayerMapPosition(ns.Data.Places)
    local c, x, y = Geo.ToWorld(ns.Data.Places, map, mx, my)
    if not c then
        return nil
    end
    return { name = "You", c = c, x = x, y = y, map = map, mx = mx, my = my }
end

local function routeTo(text)
    local faction = API.Faction()
    if not faction then
        say("Pick a faction first.")
        return
    end
    local dest = Search.Find(ns.Data, text, faction, 1)[1]
    if not dest then
        say('No place matches "' .. text .. '".')
        return
    end
    local from = here()
    if not from then
        say("Can't tell where you are. Inside an instance?")
        return
    end
    local bindName = API.HearthBindName()
    local bind = bindName and Search.Exact(ns.Data, bindName, faction) or nil
    if bindName and not bind then
        say("Hearth: unknown inn (" .. bindName .. "), left out.")
    end

    local known = knownStore()
    if not next(known) then
        say("Visit a flight master so GoblinPS can learn your flight paths. Until then, no flights.")
    end

    local opts = { faction = faction, known = known, from = from, to = dest, hearth = bind }
    local result = Route.Plan(ns.Data, opts)
    if result and #result.steps == 0 then
        say("You're already at " .. dest.name .. ".")
        return
    end
    if result then
        say("To " .. dest.name .. ": " .. Route.FormatTime(result.seconds) .. ", " .. Route.FormatMoney(result.copper))
        for i, step in ipairs(result.steps) do
            say(i .. ". " .. Route.StepText(step))
        end
    else
        say("No route found to " .. dest.name .. ".")
    end
    local hint = Route.Hint(ns.Data, opts, result)
    if hint then
        say(Route.HintText(hint))
    end
end

-- Do the client's flight node IDs and names match our generated table, and
-- how many flight paths has this character taught us so far?
local function probe()
    local nodes = API.TaxiNodes()
    local missing, renamed = 0, 0
    for _, node in ipairs(nodes) do
        local ours = ns.Data.Nodes[node.nodeID]
        if not ours then
            missing = missing + 1
            say("not in our data: " .. tostring(node.nodeID) .. " " .. tostring(node.name))
        elseif ours.name ~= node.name then
            renamed = renamed + 1
            say("name differs: " .. node.nodeID .. " ours '" .. ours.name .. "' client '" .. tostring(node.name) .. "'")
        end
    end
    say(("Client lists %d flight nodes. %d not in our data, %d named differently.")
        :format(#nodes, missing, renamed))
    say(("Learned from flight masters so far: %d flight paths."):format(Known.Count(knownStore())))
end

-- The only moment the client says which flight paths are discovered.
API.OnTaxiMapOpened(function()
    local store = knownStore()
    local added = Known.Learn(store, API.OpenTaxiNodes())
    if added > 0 then
        say(("Learned %d flight path%s here (%d known)."):format(added, added == 1 and "" or "s", Known.Count(store)))
    end
end)

SLASH_GOBLINPS1 = "/gps"
SlashCmdList.GOBLINPS = function(msg)
    local command, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "to" and rest ~= "" then
        routeTo(rest)
    elseif command == "probe" then
        probe()
    else
        say("/gps to <place>   plan a route from where you stand")
        say("/gps probe        check the flight path data against the client")
    end
end

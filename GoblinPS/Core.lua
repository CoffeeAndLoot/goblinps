local _, ns = ...

-- Slash commands. For now the whole addon is "/gps to <place>" printed in
-- chat; the planner window and dash unit come in the next plan.
local API, Geo, Search, Route = ns.API, ns.Geo, ns.Search, ns.Route

local function say(text)
    print("|cff6fe08aGoblinPS|r " .. text)
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
    local bind = bindName and Search.Exact(ns.Data, bindName) or nil
    if bindName and not bind then
        say("Hearth: unknown inn (" .. bindName .. "), left out.")
    end

    local opts = { faction = faction, known = API.KnownNodes(), from = from, to = dest, hearth = bind }
    local result = Route.Plan(ns.Data, opts)
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

-- Answers the design's open questions in one command: does the client report
-- discovered flight paths, and do its node IDs match our generated table?
local function probe()
    local nodes = API.TaxiNodes()
    local known, missing, renamed = 0, 0, 0
    for _, node in ipairs(nodes) do
        if node.known then
            known = known + 1
        end
        local ours = ns.Data.Nodes[node.nodeID]
        if not ours then
            missing = missing + 1
            say("not in our data: " .. tostring(node.nodeID) .. " " .. tostring(node.name))
        elseif ours.name ~= node.name then
            renamed = renamed + 1
            say("name differs: " .. node.nodeID .. " ours '" .. ours.name .. "' client '" .. tostring(node.name) .. "'")
        end
    end
    say(("Client reports %d flight nodes, %d known. %d not in our data, %d named differently.")
        :format(#nodes, known, missing, renamed))
end

SLASH_GOBLINPS1 = "/gps"
SlashCmdList.GOBLINPS = function(msg)
    local command, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
    if command == "to" and rest ~= "" then
        routeTo(rest)
    elseif command == "probe" then
        probe()
    else
        say("/gps to <place>   plan a route from where you stand")
        say("/gps probe        check the flight path data against the client")
    end
end

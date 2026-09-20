local _, ns = ...

-- Glue: saved variables, route planning for both the chat command and the
-- planner window, the slash command and the addon compartment entry.
local API, Geo, Search, Route, Known, Prefs = ns.API, ns.Geo, ns.Search, ns.Route, ns.Known, ns.Prefs

local Core = {}
ns.Core = Core

local function say(text)
    print("|cff6fe08aGoblinPS|r " .. text)
end
Core.Say = say

-- ---- saved variables; looked up lazily because they load after this file ----

-- This character's discovered flight paths, learned at flight masters.
local function knownStore()
    GoblinPSCharDB = GoblinPSCharDB or {}
    GoblinPSCharDB.known = GoblinPSCharDB.known or {}
    return GoblinPSCharDB.known
end

-- Account-wide preferences.
local function prefs()
    GoblinPSDB = Prefs.Init(GoblinPSDB)
    return GoblinPSDB
end

function Core.KnownCount() return Known.Count(knownStore()) end
function Core.Faction() return API.Faction() end
function Core.Recents() return prefs().recents end
function Core.Remember(name) Prefs.Remember(prefs(), name) end
function Core.Layout() return prefs().layout end
function Core.ToggleLayout() return Prefs.ToggleLayout(prefs()) end
function Core.Position(window) return Prefs.Position(prefs(), window) end
function Core.SavePosition(window, point, relativePoint, x, y)
    Prefs.SavePosition(prefs(), window, point, relativePoint, x, y)
end
function Core.MinimapPrefs() return prefs().minimap end
function Core.HearthSaving() return prefs().hearthSaving end
function Core.SetHearthSaving(seconds) prefs().hearthSaving = seconds end

-- Escape closes a frame only through its global name.
function Core.CloseOnEscape(frame, globalName)
    _G[globalName] = frame
    table.insert(UISpecialFrames, globalName)
end

-- ---- planning ----

local function here()
    local map, mx, my = API.PlayerMapPosition(ns.Data.Places)
    local c, x, y = Geo.ToWorld(ns.Data.Places, map, mx, my)
    if not c then
        return nil
    end
    return { name = "You", c = c, x = x, y = y, map = map, mx = mx, my = my }
end

-- Where the player stands, as a place the router understands. Nil inside an
-- instance, where the client gives no useful position.
function Core.Here() return here() end

-- Plans a route to a place (from Search), from another place or, when from is
-- nil, from where the player stands. Always returns a table:
--   result  Route.Plan's answer, or nil
--   hint    Route.Hint's answer, or nil
--   notes   plain lines for the player; the last one explains a missing route
--   level   the character's level, or nil
function Core.PlanRoute(to, from)
    local plan = { to = to, notes = {}, level = API.Level() }
    local faction = API.Faction()
    if not faction then
        plan.notes[1] = "Pick a faction first."
        return plan
    end
    from = from or here()
    if not from then
        plan.notes[1] = "Can't tell where you are. Inside an instance?"
        return plan
    end
    local bindName = API.HearthBindName()
    local bind = bindName and Search.Exact(ns.Data, bindName, faction) or nil
    if bindName and not bind then
        plan.notes[#plan.notes + 1] = "Hearth: unknown inn (" .. bindName .. "), left out."
    end
    local known = knownStore()
    if not next(known) then
        plan.notes[#plan.notes + 1] =
            "Visit a flight master so GoblinPS can learn your flight paths. Until then, no flights."
    end

    local travel = ns.Travel.For(plan.level)
    local opts = { faction = faction, known = known, from = from, to = to, hearth = bind,
                   speed = travel.speed, walk = travel.walk,
                   hearthSaving = prefs().hearthSaving }
    plan.result = Route.Plan(ns.Data, opts)
    if not plan.result then
        plan.notes[#plan.notes + 1] = "No route found to " .. to.name .. "."
    elseif #plan.result.steps == 0 then
        plan.notes[#plan.notes + 1] = "You're already at " .. to.name .. "."
        return plan
    end
    plan.hint = Route.Hint(ns.Data, opts, plan.result)
    return plan
end

-- Go: for now, Blizzard's map pin and arrow on the first step you travel to.
-- The dash unit takes this over in a later plan.
function Core.Go(plan)
    local step = plan and plan.result and plan.result.steps[1]
    if not step then
        return
    end
    if step.kind == "hearth" then
        say("Use your hearthstone, then press GO again.")
    elseif step.to.map and API.SetWaypoint(step.to.map, step.to.mx, step.to.my) then
        say("Pin set: " .. Route.StepText(step) .. ".")
    else
        say("Can't put a map pin there. " .. Route.StepText(step) .. ".")
    end
end

local function routeTo(text)
    local dest = Search.Find(ns.Data, text, API.Faction(), 1)[1]
    if not dest then
        say('No place matches "' .. text .. '".')
        return
    end
    local plan = Core.PlanRoute(dest)
    for _, note in ipairs(plan.notes) do
        say(note)
    end
    local steps = plan.result and plan.result.steps or {}
    if #steps > 0 then
        say("To " .. dest.name .. ": " .. Route.FormatTime(plan.result.seconds) .. ", "
            .. Route.FormatMoney(plan.result.copper))
        for i, step in ipairs(steps) do
            say(i .. ". " .. Route.StepText(step) .. "  " .. Route.FormatTime(step.seconds))
            local detail, warn = Route.StepDetail(ns.Data, step, plan.level)
            if detail ~= "" then
                say("     " .. ns.Widgets.ChatColor(warn and "amber" or "dim") .. detail .. "|r")
            end
        end
    end
    if plan.hint then
        say(Route.HintText(plan.hint))
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
    say(("Learned from flight masters so far: %d flight paths."):format(Core.KnownCount()))
end

-- Data/Zones.lua is hand-written from Classic and drives the amber warnings,
-- so a range Forever moved warns at the wrong level. The client draws its own
-- range on the world map, so ask it for all of them at once instead of reading
-- sixty tooltips. The full answer goes to GoblinPSDB.probe.zones, because it is
-- too long to read in chat and SavedVariables can be opened on the desktop.
local function probeZones()
    local places, zones = ns.Data.Places, ns.Data.Zones
    local maps = {}
    for map in pairs(places) do
        maps[#maps + 1] = map
    end
    table.sort(maps)

    local dump, answered, differ, unlisted, lost, shown = {}, 0, 0, 0, 0, 0
    for _, map in ipairs(maps) do
        local low, high = API.ZoneLevels(map)
        local ours = zones[map]
        dump[#dump + 1] = {
            map = map, name = places[map].name,
            clientLow = low, clientHigh = high,
            ourLow = ours and ours[1] or nil, ourHigh = ours and ours[2] or nil,
        }
        if low then
            answered = answered + 1
            if not ours then
                unlisted = unlisted + 1
            elseif ours[1] ~= low or ours[2] ~= high then
                differ = differ + 1
                if shown < 12 then
                    shown = shown + 1
                    say(("%s: ours %d-%d, client %d-%d"):format(places[map].name, ours[1], ours[2], low, high))
                end
            end
        elseif ours then
            lost = lost + 1
        end
    end

    prefs().probe = { zones = dump }
    if answered == 0 then
        say("C_Map.GetMapLevels answered for no zone at all: it is dead on this build, like isUndiscovered.")
        return
    end
    if shown < differ then
        say(("... and %d more that differ."):format(differ - shown))
    end
    say(("%d of %d zones have a range from the client: %d differ from ours, "):format(answered, #maps, differ)
        .. ("%d we do not list, %d we list and it does not."):format(unlisted, lost))
    say("Full table saved to GoblinPSDB.probe.zones; log out to write SavedVariables.")
end

-- The only moment the client says which flight paths are discovered.
API.OnTaxiMapOpened(function()
    local store = knownStore()
    local added = Known.Learn(store, API.OpenTaxiNodes())
    if added > 0 then
        say(("Learned %d flight path%s here (%d known)."):format(added, added == 1 and "" or "s", Known.Count(store)))
        ns.Planner.Replan()
    end
end)

API.OnLogin(function()
    ns.MinimapButton.Initialize()
end)

local function slash(msg)
    local command, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" then
        ns.Planner.Toggle()
    elseif command == "to" and rest ~= "" then
        routeTo(rest)
    elseif command == "probe" and rest:lower() == "zones" then
        probeZones()
    elseif command == "probe" then
        probe()
    elseif command == "selftest" then
        ns.SelfTest.Run(say)
    elseif command == "hearth" then
        local minutes = tonumber(rest)
        if rest == "" or not minutes or minutes < 0 then
            say(("Hearthstone: used only when it saves at least %s."):format(
                Route.FormatTime(Core.HearthSaving())))
            say("/gps hearth <minutes>   change it; 0 always takes the fastest route")
        else
            Core.SetHearthSaving(math.floor(minutes * 60 + 0.5))
            if minutes == 0 then
                say("Hearthstone: always used when it is faster, however small the saving.")
            else
                say(("Hearthstone: used only when it saves at least %s."):format(
                    Route.FormatTime(Core.HearthSaving())))
            end
            ns.Planner.Replan()
        end
    elseif command == "minimap" then
        ns.MinimapButton.SetHidden(not Core.MinimapPrefs().hide)
        say(Core.MinimapPrefs().hide and "Minimap button hidden. /gps minimap shows it again."
            or "Minimap button shown.")
    else
        say("/gps              open the planner")
        say("/gps to <place>   print a route in chat")
        say("/gps minimap      show or hide the minimap button")
        say("/gps probe        check the flight path data against the client")
        say("/gps hearth <min>  how much the hearthstone must save to be used")
        say("/gps probe zones  check the zone level ranges against the client")
        say("/gps selftest     check textures and fonts")
    end
end

SLASH_GOBLINPS1 = "/gps"
SlashCmdList.GOBLINPS = slash

-- Named in the TOC's AddonCompartmentFunc line.
function GoblinPS_OnAddonCompartmentClick()
    ns.Planner.Toggle()
end

return Core

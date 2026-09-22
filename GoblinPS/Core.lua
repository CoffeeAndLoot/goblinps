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

-- Account-wide preferences.
local function prefs()
    GoblinPSDB = Prefs.Init(GoblinPSDB)
    return GoblinPSDB
end

-- This character's discovered flight paths, learned at flight masters, kept in
-- the account-wide save under "Name-Realm". On build 1.60.1.69913 no save
-- loads back (see Prefs.lua), so this starts empty every session until a
-- flight master's map fills it.
local function knownStore()
    local key = API.CharacterKey()
    if not key then
        -- The client cannot yet say who is logged in. Hand back a table that
        -- is never saved rather than file paths under a key that is not this
        -- character's.
        return {}
    end
    local all = prefs().known
    if type(all[key]) ~= "table" then
        all[key] = {}
    end
    return all[key]
end

function Core.KnownCount() return Known.Count(knownStore()) end
function Core.Faction() return API.Faction() end
function Core.Recents() return prefs().recents end
function Core.Remember(name) Prefs.Remember(prefs(), name) end
function Core.Position(window) return Prefs.Position(prefs(), window) end
function Core.SavePosition(window, point, relativePoint, x, y)
    Prefs.SavePosition(prefs(), window, point, relativePoint, x, y)
end
function Core.MinimapPrefs() return prefs().minimap end
function Core.HearthSaving() return prefs().hearthSaving end
function Core.SetHearthSaving(seconds) prefs().hearthSaving = seconds end
function Core.Arrive(key) return prefs().arrive[key] end
function Core.SetArrive(key, yards) prefs().arrive[key] = yards end
-- The player's radii by Trip step kind; the dash hands this to Trip.Check.
function Core.ArriveRadii() return Prefs.ArriveRadii(prefs()) end
function Core.ResetSettings() Prefs.Reset(prefs()) end
-- The dash's scrolling text: its name, and seconds per character (nil for off).
function Core.Scroll() return prefs().scroll end
-- A name not in Prefs.SCROLL is ignored: the panel could not have set it.
function Core.SetScroll(name)
    if Prefs.ScrollIndex(name) then
        prefs().scroll = name
    end
end
function Core.ScrollStep() return Prefs.SCROLL_STEP[prefs().scroll] end

-- Escape closes a frame only through its global name.
function Core.CloseOnEscape(frame, globalName)
    _G[globalName] = frame
    table.insert(UISpecialFrames, globalName)
end

-- One line to copy while walking a crossing or dock: the zone, its UiMap ID,
-- the map coords the way the in-game map shows them, the subzone and the
-- nearest known crossing or dock. Pure past the two API calls: everything
-- else is Geo, so this is exercised in the UI fake test alongside the rest of
-- Core, not the frame-free pure suite (Core.lua cannot load without ns.API).
function Core.WhereLine()
    local map, mx, my = API.PlayerMapPosition(ns.Data.Places)
    if not map then
        return "GoblinPS: can't tell where you are."
    end
    local place = ns.Data.Places[map]
    local line = ("%s (%d) %.1f, %.1f"):format(place.name, map, mx * 100, my * 100)

    local subzone = API.SubZone()
    if subzone and subzone ~= place.name then
        line = line .. " · " .. subzone
    end

    local c, x, y = Geo.ToWorld(ns.Data.Places, map, mx, my)
    local near = c and Geo.Nearest(ns.Data, c, x, y)
    if near then
        line = line .. (" · nearest: %s, %d yd"):format(near.name, math.floor(near.yards + 0.5))
    end
    return line
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
--   hostile the note, also first in notes, when the destination stands in an
--           enemy town (Graph.HostileAt); the planner puts it first under the strip
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
    local enemy = ns.Graph.HostileAt(ns.Data, faction, to)
    if enemy then
        plan.hostile = Route.HostileNote(enemy)
        plan.notes[#plan.notes + 1] = plan.hostile
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

-- The pin PinStep last set, as { map, x, y }, so that only our own pin is
-- ever cleared: a waypoint the player drops mid-trip is theirs.
local lastPin

-- Blizzard's map pin and on-screen arrow for one step. Spec decision 3 puts
-- the pin on the step you are ON, so the dash calls this again each time it
-- advances, not only when Start Route is pressed. Quiet: only Start Route
-- explains itself.
function Core.PinStep(step)
    if not step or step.kind == "hearth" or not step.to.map then
        return false
    end
    if API.SetWaypoint(step.to.map, step.to.mx, step.to.my) then
        lastPin = { step.to.map, step.to.mx, step.to.my }
        return true
    end
    return false
end

-- Clear the map pin, but only if it is still the one we set.
function Core.ClearPin()
    if lastPin and API.WaypointIs(lastPin[1], lastPin[2], lastPin[3]) then
        API.ClearWaypoint()
    end
    lastPin = nil
end

-- ---- the trip in progress, which outlives a reload ----
--
-- Only the destination's name is saved: the player may be anywhere when they
-- come back, and every route starts where they stand, so resuming is planning
-- again. Account-wide, under this character, because this build never loads
-- per-character saves. See Prefs.lua.

local function tripSlot()
    local key = API.CharacterKey()
    return key and prefs().trips, key
end

function Core.SaveTrip(place)
    local trips, key = tripSlot()
    if trips and place and place.name then
        trips[key] = { to = place.name }
    end
end

function Core.SavedTripName()
    local trips, key = tripSlot()
    local trip = trips and trips[key]
    return type(trip) == "table" and trip.to or nil
end

function Core.ClearTrip()
    local trips, key = tripSlot()
    if trips then
        trips[key] = nil
    end
end

-- On login: carry on with this character's saved trip. The destination is
-- looked up again by name; if a patch renamed it, drop the trip and say so --
-- never silently.
function Core.ResumeTrip()
    local name = Core.SavedTripName()
    if not name then
        return
    end
    local place = Search.Exact(ns.Data, name, API.Faction())
    if not place then
        Core.ClearTrip()
        say(("Couldn't resume your trip to %s: that place isn't in GoblinPS's data any more."):format(name))
        return
    end
    ns.Dash.Resume(place)
end

-- Go: pin the first step, say what happened, and hand the plan to the dash
-- unit, which takes over from here.
function Core.Go(plan)
    local step = plan and plan.result and plan.result.steps[1]
    if not step then
        return
    end
    if step.kind == "hearth" then
        say("Use your hearthstone, then press Start Route again.")
    elseif Core.PinStep(step) then
        say("Pin set: " .. Route.StepText(step) .. ".")
    else
        say("Can't put a map pin there. " .. Route.StepText(step) .. ".")
    end
    ns.Dash.Start(plan)
    Core.SaveTrip(plan.to)
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

-- Said at login when this character knows no flight paths, which on this
-- build is every login: it loads no saved data, so routes would quietly skip
-- every flight until a flight master's map is opened. Silent once saves load.
function Core.NoteFlightPaths()
    if Core.KnownCount() == 0 then
        say("No flight paths known this session: open any flight master's map. "
            .. "This beta build doesn't load saved data, so it forgets them on every reload.")
    end
end

API.OnLogin(function()
    ns.MinimapButton.Initialize()
    Core.NoteFlightPaths()
    Core.ResumeTrip()
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
                say("Hearthstone: always used whenever it is no slower, however small the saving.")
            else
                say(("Hearthstone: used only when it saves at least %s."):format(
                    Route.FormatTime(Core.HearthSaving())))
            end
            ns.Planner.Replan()
            ns.Settings.Refresh()   -- an open panel shows the new value
        end
    elseif command == "settings" then
        ns.Planner.OpenSettings()
    elseif command == "minimap" then
        ns.MinimapButton.SetHidden(not Core.MinimapPrefs().hide)
        say(Core.MinimapPrefs().hide and "Minimap button hidden. /gps minimap shows it again."
            or "Minimap button shown.")
    elseif command == "where" then
        ns.MinimapButton.ShowWhere()
    else
        say("/gps              open the planner")
        say("/gps to <place>   print a route in chat")
        say("/gps minimap      show or hide the minimap button")
        say("/gps probe        check the flight path data against the client")
        say("/gps hearth <min>  how much the hearthstone must save to be used")
        say("/gps settings     open the settings panel")
        say("/gps probe zones  check the zone level ranges against the client")
        say("/gps selftest     check textures and fonts")
        say("/gps where        copy your position, to correct crossings and docks")
    end
end

SLASH_GOBLINPS1 = "/gps"
SlashCmdList.GOBLINPS = slash

-- Named in the TOC's AddonCompartmentFunc line.
function GoblinPS_OnAddonCompartmentClick()
    ns.Planner.Toggle()
end

return Core

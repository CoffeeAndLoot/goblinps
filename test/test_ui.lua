-- Smoke test of the window code against test/fake_frames.lua. It catches our
-- own mistakes (nil calls, wrong fields, text in the wrong widget). Real frame
-- behaviour is checked in game from docs/manual-test-checklist.md.
-- These tests share one planner and run in order: a later test may rely on
-- state an earlier one left behind.
-- "Self-test passed." can never be reached on the desktop, since the fake
-- defines no font objects; that happy path is checked in game instead.
return function(h)
    local Fake = dofile("test/fake_frames.lua")
    local realPrint = print
    local printed = Fake.Install()

    -- A private addon namespace over the fake world, with a scripted API.
    local ns = { Data = dofile("test/fake_world.lua")() }
    -- Data/Art.lua is generated, real game data (like Places or Nodes), not a
    -- fixture to fake; load it the same way the client does, before the UI
    -- files that draw it.
    assert(loadfile("GoblinPS/Data/Art.lua"))("GoblinPS", ns)
    local where = { map = 1, mx = 0.89, my = 0.9 } -- world 1000, 1100: beside Alpha
    local pins, loginCallbacks = {}, {}
    local level = 60 -- mounted, so ground steps say Ride
    ---@type number|nil, boolean, function[]
    local facing, onTaxi, tripCallbacks = 0, false, {}
    -- What the client claims each zone's level range is, for /gps probe zones.
    -- All four cases the command has to tell apart: Westland (1) matches
    -- Data.Zones, Northland (4) disagrees with it, Isle (3) and Eastland (2)
    -- have ranges we do not list, and Lostland (5) is one we list that the
    -- client says nothing about. Two zones are unlisted and only one is lost
    -- on purpose: with both at one, swapping the two counters in the summary
    -- would print the same sentence and no test would notice.
    local clientLevels = { [1] = { 1, 10 }, [4] = { 25, 35 }, [3] = { 15, 20 }, [2] = { 5, 9 } }
    ns.API = {
        Faction = function() return "H" end,
        Level = function() return level end,
        ZoneLevels = function(map)
            local range = clientLevels[map]
            if not range then
                return nil
            end
            return range[1], range[2]
        end,
        PlayerMapPosition = function() return where.map, where.mx, where.my end,
        HearthBindName = function() return nil end,
        TaxiNodes = function() return {} end,
        OpenTaxiNodes = function() return {} end,
        OnTaxiMapOpened = function() end,
        OnLogin = function(callback) loginCallbacks[#loginCallbacks + 1] = callback end,
        PlayerFacing = function() return facing end,
        OnTaxi = function() return onTaxi end,
        OnTripEvent = function(callback) tripCallbacks[#tripCallbacks + 1] = callback end,
        SetWaypoint = function(map, x, y)
            pins[#pins + 1] = { map, x, y }
            return true
        end,
        SelfCheck = function() return { { name = "Fake.API", present = true } } end,
    }
    for _, file in ipairs({ "Geo", "Travel", "Search", "Graph", "Route", "Trip", "Known", "Prefs",
                            "Widgets", "Planner", "Dash", "MinimapButton", "SelfTest", "Core" }) do
        assert(loadfile("GoblinPS/" .. file .. ".lua"))("GoblinPS", ns)
    end
    GoblinPSDB, GoblinPSCharDB = nil, { known = { [1] = true, [2] = true, [4] = true } }

    local Planner = ns.Planner

    h.describe("Widgets.ChatColor", function()
        h.it("matches the formula for the palette entry, in chat and in the window", function()
            h.eq(ns.Widgets.ChatColor("amber"), "|cfff0b54a")
            local dim = ns.Widgets.COLOR.dim
            local expect = ("|cff%02x%02x%02x"):format(
                math.floor(dim[1] * 255 + 0.5), math.floor(dim[2] * 255 + 0.5), math.floor(dim[3] * 255 + 0.5))
            h.eq(ns.Widgets.ChatColor("dim"), expect)
        end)
    end)

    h.describe("the planner window", function()
        h.it("opens from the slash command with both layouts' widgets built once", function()
            SlashCmdList.GOBLINPS("")
            local ui = Planner.Debug()
            h.truthy(ui.frame:IsShown())
            h.eq(ui.frame:GetWidth(), Planner.SIZE.wide[1])
            h.eq(ui.known:GetText(), "Flight paths known: 3")
            h.eq(UISpecialFrames[1], "GoblinPSPlanner")
        end)

        h.it("the strict fake raises for a widget method it does not model", function()
            local ui = Planner.Debug()
            local ok, err = pcall(function() return ui.frame.NotAWidgetMethod end)
            h.falsy(ok)
            h.truthy(tostring(err):find("unknown widget method", 1, true))
        end)

        h.it("dragging saves point, relativePoint, x and y", function()
            local ui = Planner.Debug()
            ui.frame:SetPoint("TOP", UIParent, "BOTTOM", 5, -20)
            ui.frame.scripts.OnDragStart(ui.frame)
            ui.frame.scripts.OnDragStop(ui.frame)
            local p = GoblinPSDB.positions.planner
            h.eq(p.point, "TOP")
            h.eq(p.relativePoint, "BOTTOM")
            h.eq(p.x, 5)
            h.eq(p.y, -20)
        end)

        h.it("offers matches as you type and plans when you pick one", function()
            local ui, state = Planner.Debug()
            Fake.Type(ui.toBox, "delt")
            h.truthy(ui.results:IsShown())
            h.eq(ui.results.rows[1].label:GetText(), "Delta  (flight stop)")
            Fake.Click(ui.results.rows[1])
            h.falsy(ui.results:IsShown())
            h.eq(state.to.nodeID, 4)
            h.eq(ui.toBox:GetText(), "Delta")
            h.eq(ui.rows[1].left:GetText(), "1. Ride to Alpha")
            h.eq(ui.rows[2].left:GetText(), "2. Fly to Bravo")
            h.eq(ui.rows[2].right:GetText(), "~4 min  1s")
            h.eq(ui.rows[4].left:GetText(), "4. Zeppelin to East Dock")
            h.eq(ui.rows[5].left:GetText(), "5. Ride to Delta")
            h.eq(ui.rows[6].left:GetText(), "")
            h.eq(ui.total:GetText(), "~10 min  1s")
            h.truthy(ui.go.enabled)
        end)

        h.it("clicking Here dismisses the open results list", function()
            local ui = Planner.Debug()
            Fake.Type(ui.toBox, "delt")
            h.truthy(ui.results:IsShown())
            Fake.Click(ui.here)
            h.falsy(ui.results:IsShown())
        end)

        h.it("a mouse-down on the frame body also dismisses the open results list", function()
            local ui = Planner.Debug()
            Fake.Type(ui.toBox, "delt")
            h.truthy(ui.results:IsShown())
            Fake.MouseDown(GoblinPSPlanner)
            h.falsy(ui.results:IsShown())
        end)

        h.it("a click on the list still lands when the client drops edit focus on mouse-down", function()
            -- Seen in game: clicking a row closed the list and picked nothing. The box lost focus on
            -- mouse-down, the list hid, and the row was gone before the click completed.
            local ui, state = Planner.Debug()
            Fake.Type(ui.toBox, "charl")
            ui.results.mouseOver = true          -- the cursor is on the list...
            ui.toBox:ClearFocus()                -- ...when the box loses focus
            h.truthy(ui.results:IsShown(), "the list must survive focus loss while the mouse is on it")
            Fake.Click(ui.results.rows[1])
            ui.results.mouseOver = false
            h.eq(state.to.nodeID, 3)
            h.falsy(ui.results:IsShown())
            -- put the destination back for the tests that follow
            Fake.Type(ui.toBox, "delt")
            Fake.Click(ui.results.rows[1])
            h.eq(state.to.nodeID, 4)
        end)

        h.it("focus loss with the mouse elsewhere still closes the list", function()
            local ui = Planner.Debug()
            Fake.Type(ui.toBox, "delt")
            h.truthy(ui.results:IsShown())
            ui.toBox:ClearFocus()
            h.falsy(ui.results:IsShown())
            ui.toBox:SetText("Delta")
        end)

        h.it("remembers the destination and offers it when the box is empty", function()
            local ui = Planner.Debug()
            h.eq(GoblinPSDB.recents[1], "Delta")
            Fake.Type(ui.toBox, "")
            h.eq(ui.results.rows[1].label:GetText(), "Delta  (flight stop)")
        end)

        h.it("offers the next real recent when the newest one no longer resolves", function()
            local ui = Planner.Debug()
            table.insert(GoblinPSDB.recents, 1, "Ghost Town")
            ui.toBox:SetText("")
            ui.toBox.scripts.OnEditFocusGained(ui.toBox)
            h.eq(ui.results.rows[1].label:GetText(), "Delta  (flight stop)")
            table.remove(GoblinPSDB.recents, 1)
        end)

        h.it("plans from another place", function()
            local ui, state = Planner.Debug()
            Fake.Type(ui.fromBox, "brav")
            Fake.Click(ui.results.rows[1])
            h.eq(state.from.nodeID, 2)
            h.eq(ui.rows[1].left:GetText(), "1. Ride to West Dock")
        end)

        h.it("GO drops a pin on the first step", function()
            local ui = Planner.Debug()
            Fake.Click(ui.go)
            h.falsy(ui.frame:IsShown(), "GO hands off to the dash and gets out of the way")
            SlashCmdList.GOBLINPS("") -- /gps reopens it, without ending the trip, for the tests that follow
            h.eq(#pins, 1)
            h.eq(pins[1][1], 1)
            h.truthy(printed[#printed]:find("Pin set: Ride to West Dock", 1, true))
        end)

        h.it("switches layout with one set of widgets and saves the choice", function()
            local ui = Planner.Debug()
            local rowsBefore = ui.rows
            Fake.Click(ui.layoutButton)
            h.eq(ui.frame:GetWidth(), Planner.SIZE.tall[1])
            h.eq(ui.frame:GetHeight(), Planner.SIZE.tall[2])
            h.eq(GoblinPSDB.layout, "tall")
            h.eq(ui.layoutButton.label:GetText(), "Wide")
            h.truthy(ui.rows == rowsBefore, "the same row widgets")
            h.eq(ui.rows[1].left:GetText(), "1. Ride to West Dock")
        end)

        h.it("Here plans from where you stand again", function()
            local ui, state = Planner.Debug()
            Fake.Click(ui.here)
            h.eq(state.from, nil)
            h.eq(ui.fromBox:GetText(), "")
            h.eq(ui.rows[1].left:GetText(), "1. Ride to Alpha")
        end)

        h.it("shows the plan's notes on the screen when the route has steps", function()
            local ui = Planner.Debug()
            local originalHearthBindName = ns.API.HearthBindName
            ns.API.HearthBindName = function() return "Nowhere Inn Bind" end
            Fake.Click(ui.here)
            h.truthy(ui.notes:GetText():find("Hearth: unknown inn", 1, true))
            ns.API.HearthBindName = originalHearthBindName
            Fake.Click(ui.here)
            h.eq(ui.notes:GetText(), "")
        end)

        h.it("shows an overflow row for a route longer than MAX_ROWS, with the last step always visible", function()
            local ui, state = Planner.Debug()
            local savedMax, savedPlan = Planner.MAX_ROWS, state.plan
            Planner.MAX_ROWS = 3
            local steps = {}
            for i = 1, 5 do
                steps[i] = { kind = "ride", to = { name = "Stop " .. i }, seconds = 60, copper = 0 }
            end
            state.plan = { to = { name = "Stop 5" }, notes = {}, result = { steps = steps, seconds = 300, copper = 0 } }
            Planner.Refresh()
            h.eq(ui.rows[1].left:GetText(), "1. Ride to Stop 1")
            h.eq(ui.rows[2].left:GetText(), "... and 3 more steps")
            h.eq(ui.rows[3].left:GetText(), "5. Ride to Stop 5")
            Planner.MAX_ROWS = savedMax
            state.plan = savedPlan
            Planner.Refresh()
        end)

        h.it("explains itself when it cannot tell where you are", function()
            local ui = Planner.Debug()
            where.map = nil
            Fake.Click(ui.here)
            h.eq(ui.rows[1].left:GetText(), "")
            h.eq(ui.notes:GetText(), "Can't tell where you are. Inside an instance?")
            h.eq(ui.total:GetText(), "")
            h.falsy(ui.go.enabled)
            where.map = 1
            Fake.Click(ui.here)
            h.truthy(ui.go.enabled)
        end)

        h.it("GO re-plans from where you are now instead of using a stale plan", function()
            local ui = Planner.Debug()
            h.eq(ui.rows[1].left:GetText(), "1. Ride to Alpha")
            -- The player moves without touching either box: the planner's
            -- last plan (from near Alpha) is now stale.
            where.mx, where.my = 0.1, 0.9 -- right beside Bravo now
            Fake.Click(ui.go)
            h.eq(ui.rows[1].left:GetText(), "1. Ride to West Dock")
            h.truthy(printed[#printed]:find("Pin set: Ride to West Dock", 1, true))
            h.eq(pins[#pins][1], 1)
            where.mx, where.my = 0.89, 0.9 -- restore for the tests that follow
            SlashCmdList.GOBLINPS("") -- GO hid the planner; /gps reopens it for the tests that follow
        end)

        h.it("shows the zero-step case when you are already at the destination", function()
            local ui, state = Planner.Debug()
            Fake.Type(ui.toBox, "westland")
            Fake.Click(ui.results.rows[1])
            h.eq(state.to.name, "Westland")
            h.eq(ui.rows[1].left:GetText(), "")
            h.eq(ui.notes:GetText(), "You're already at Westland.")
            h.eq(ui.total:GetText(), "")
            h.falsy(ui.go.enabled)
        end)

        h.it("closes and reopens without rebuilding", function()
            local ui = Planner.Debug()
            SlashCmdList.GOBLINPS("")
            h.falsy(ui.frame:IsShown())
            SlashCmdList.GOBLINPS("")
            h.truthy(ui.frame:IsShown())
            h.truthy(Planner.Debug() == ui)
        end)
    end)

    h.describe("ground steps in the window", function()
        local amber, dim = ns.Widgets.COLOR.amber, ns.Widgets.COLOR.dim
        local function pickTo(text)
            local ui = Planner.Debug()
            Fake.Type(ui.toBox, text)
            Fake.Click(ui.results.rows[1])
            return ui
        end

        h.it("shows each ground step's zone and levels on a second line", function()
            local ui = pickTo("hotel")
            h.eq(ui.rows[1].left:GetText(), "1. Ride to the North Gate")
            h.eq(ui.rows[1].detail:GetText(), "into Northland · trolls on the bridge")
            h.eq(ui.rows[2].left:GetText(), "2. Ride to Hotel")
            h.eq(ui.rows[2].detail:GetText(), "in Northland · level 30-40")
            h.eq(ui.rows[3].detail:GetText(), "")
        end)
        h.it("turns the detail amber for a hazard and leaves it dim otherwise", function()
            local ui = Planner.Debug()
            h.eq(ui.rows[1].detail.color[1], amber[1])   -- the crossing carries a hazard note
            h.eq(ui.rows[1].detail.color[2], amber[2])
            h.eq(ui.rows[1].detail.color[3], amber[3])
            h.eq(ui.rows[2].detail.color[1], dim[1])     -- level 60 in a 30-40 zone
            h.eq(ui.rows[2].detail.color[2], dim[2])
            h.eq(ui.rows[2].detail.color[3], dim[3])
        end)
        h.it("says Walk and warns about the zone for a low-level character", function()
            level = 1
            local ui = pickTo("hotel")
            h.eq(ui.rows[1].left:GetText(), "1. Walk to the North Gate")
            h.eq(ui.rows[2].left:GetText(), "2. Walk to Hotel")
            h.eq(ui.rows[2].detail.color[1], amber[1])
            h.eq(ui.rows[2].detail.color[2], amber[2])
            h.eq(ui.rows[2].detail.color[3], amber[3])
            level = 60
        end)
        h.it("labels a straight line when the crossings table has a hole", function()
            local ui = pickTo("lostland")
            h.eq(ui.rows[1].left:GetText(), "1. Ride toward Lostland (no mapped path)")
            h.eq(ui.rows[1].detail:GetText(), "")
            pickTo("delt")
        end)
        h.it("prints the detail under each step in chat too", function()
            local from = #printed
            SlashCmdList.GOBLINPS("to hotel")
            local saw = false
            for i = from + 1, #printed do
                saw = saw or printed[i]:find("into Northland", 1, true) ~= nil
            end
            h.truthy(saw)
        end)
    end)

    h.describe("/gps probe zones", function()
        local function rows()
            local by = {}
            for _, row in ipairs(GoblinPSDB.probe.zones) do
                by[row.map] = row
            end
            return by
        end

        h.it("saves every zone, whether the client answers for it or not", function()
            SlashCmdList.GOBLINPS("probe zones")
            local by = rows()
            h.eq(#GoblinPSDB.probe.zones, 5, "one row per zone in Places")
            -- agrees
            h.eq(by[1].ourLow, 1); h.eq(by[1].clientLow, 1); h.eq(by[1].clientHigh, 10)
            -- the client disagrees with our hand-written range
            h.eq(by[4].ourLow, 30); h.eq(by[4].ourHigh, 40)
            h.eq(by[4].clientLow, 25); h.eq(by[4].clientHigh, 35)
            -- the client has a range we never listed
            h.eq(by[3].ourLow, nil); h.eq(by[3].clientLow, 15)
            -- we have a row and the client says nothing: ours must survive the
            -- dump, so a silent client never reads as "delete our range"
            h.eq(by[5].ourLow, 20); h.eq(by[5].ourHigh, 25)
            h.eq(by[5].clientLow, nil); h.eq(by[5].clientHigh, nil)
            -- a second zone the client knows and we do not, so the two counts differ
            h.eq(by[2].ourLow, nil); h.eq(by[2].clientLow, 5)
        end)
        h.it("names the zones that differ and counts the rest", function()
            local from = #printed
            SlashCmdList.GOBLINPS("probe zones")
            local said = table.concat(printed, "\n", from + 1, #printed)
            h.truthy(said:find("Northland: ours 30-40, client 25-35", 1, true), "should name the disagreement")
            h.truthy(said:find("4 of 5 zones", 1, true), "should count the answers")
            h.truthy(said:find("1 differ", 1, true))
            h.truthy(said:find("2 we do not list", 1, true))
            h.truthy(said:find("1 we list and it does not", 1, true),
                     "the fourth case must be counted, and not swapped with the third")
        end)
        h.it("says so plainly when the client answers for no zone at all", function()
            local saved = clientLevels
            clientLevels = {}
            local from = #printed
            SlashCmdList.GOBLINPS("probe zones")
            local said = table.concat(printed, "\n", from + 1, #printed)
            h.truthy(said:find("dead on this build", 1, true),
                     "a silent API must be called out, not read as every zone matching")
            clientLevels = saved
        end)
    end)

    h.describe("/gps hearth", function()
        h.it("reports the current setting and the default is five minutes", function()
            local from = #printed
            SlashCmdList.GOBLINPS("hearth")
            local said = table.concat(printed, " ", from + 1, #printed)
            h.truthy(said:find("saves at least ~5 min", 1, true), said)
        end)
        h.it("takes minutes and stores seconds", function()
            SlashCmdList.GOBLINPS("hearth 12")
            h.eq(GoblinPSDB.hearthSaving, 720)
            local from = #printed
            SlashCmdList.GOBLINPS("hearth")
            h.truthy(table.concat(printed, " ", from + 1, #printed):find("~12 min", 1, true))
        end)
        h.it("zero means always take the fastest route, and says so plainly", function()
            local from = #printed
            SlashCmdList.GOBLINPS("hearth 0")
            h.eq(GoblinPSDB.hearthSaving, 0)
            h.truthy(table.concat(printed, " ", from + 1, #printed):find("however small", 1, true))
        end)
        h.it("refuses nonsense without changing the setting", function()
            SlashCmdList.GOBLINPS("hearth 5")
            SlashCmdList.GOBLINPS("hearth soon")
            h.eq(GoblinPSDB.hearthSaving, 300, "a word must not wipe the setting")
            SlashCmdList.GOBLINPS("hearth -3")
            h.eq(GoblinPSDB.hearthSaving, 300, "a negative must not be stored")
        end)
    end)

    h.describe("the minimap button and the compartment", function()
        h.it("appears at login at the saved angle, and hides on request", function()
            h.eq(#loginCallbacks, 1)
            loginCallbacks[1]()
            h.truthy(GoblinPSMinimapButton:IsShown())
            SlashCmdList.GOBLINPS("minimap")
            h.falsy(GoblinPSMinimapButton:IsShown())
            h.eq(GoblinPSDB.minimap.hide, true)
            SlashCmdList.GOBLINPS("minimap")
            h.truthy(GoblinPSMinimapButton:IsShown())
        end)
        h.it("dragging stores the angle from the cursor", function()
            GoblinPSMinimapButton.scripts.OnDragStart(GoblinPSMinimapButton)
            GoblinPSMinimapButton.scripts.OnUpdate(GoblinPSMinimapButton)
            GoblinPSMinimapButton.scripts.OnDragStop(GoblinPSMinimapButton)
            h.eq(GoblinPSDB.minimap.angle, 0) -- cursor is due east of the fake minimap's centre
        end)
        h.it("the compartment entry toggles the planner", function()
            local ui = Planner.Debug()
            local before = ui.frame:IsShown()
            GoblinPS_OnAddonCompartmentClick()
            h.eq(ui.frame:IsShown(), not before)
        end)
    end)

    h.describe("/gps selftest", function()
        h.it("reports every check and the verdict", function()
            local from = #printed
            SlashCmdList.GOBLINPS("selftest")
            h.truthy(#printed - from >= 5)
            h.truthy(printed[#printed]:find("Self%-test"))
        end)

        -- The desktop fake defines none of the client's font globals, so the
        -- font checks always fail here even with no missing texture; that is
        -- unrelated to this fix and pre-dates it. What this proves is the
        -- one thing the ruling is about: a texture the fake is told to
        -- reject adds exactly one more FAIL, for that path, to the count.
        h.it("fails when a texture cannot load", function()
            local badPath = ns.SelfTest.TEXTURES[1]

            SlashCmdList.GOBLINPS("selftest")
            local before = tonumber(printed[#printed]:match("(%d+) failed")) or 0

            Fake.missingTextures[badPath] = true
            local from = #printed
            SlashCmdList.GOBLINPS("selftest")
            Fake.missingTextures[badPath] = nil

            local sawFail = false
            for i = from + 1, #printed do
                if printed[i]:find("FAIL", 1, true) and printed[i]:find(badPath, 1, true) then
                    sawFail = true
                end
            end
            h.truthy(sawFail)
            h.eq(tonumber(printed[#printed]:match("(%d+) failed")), before + 1)
        end)
    end)

    h.describe("/gps to still prints a route in chat", function()
        h.it("uses the same planner as the window", function()
            local from = #printed
            SlashCmdList.GOBLINPS("to delta")
            h.truthy(printed[from + 1]:find("To Delta: ~10 min, 1s", 1, true))
            h.truthy(printed[from + 2]:find("1. Ride to Alpha", 1, true))
        end)
    end)

    -- Smoke test of the dash unit against test/fake_frames.lua. It catches our own
    -- mistakes: nil calls, text in the wrong widget, a FontString with one anchor.
    -- Real frame behaviour is checked in game from docs/manual-test-checklist.md.
    do
        local Dash = ns.Dash

        -- A real step's `to` always carries a map (Graph.stopFrom sets it from
        -- the stop data); task 5's pin test needs it too, so the fixture gets
        -- one. `plan.to` is the destination a recalculation replans towards,
        -- same as Core.PlanRoute always sets it; Westland is the zone the fake
        -- player already stands in, on purpose, for the zero-step test below.
        local plan = {
            level = 60,
            to = ns.Search.Exact(ns.Data, "Westland", "H"),
            result = {
                seconds = 600,
                steps = {
                    { kind = "ride", seconds = 200, to = { name = "the North Gate", c = 1, x = 0, y = 0, map = 1 } },
                    { kind = "zeppelin", seconds = 240, to = { name = "East Dock", c = 1, x = 0, y = 0, map = 1 } },
                    { kind = "ride", seconds = 160, to = { name = "Delta", c = 1, x = 0, y = 0, map = 1 } },
                },
            },
        }

        h.describe("the dash unit", function()
            h.it("opens on Start and shows the first step and the one after", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                h.truthy(ui.frame:IsShown())
                h.eq(state.index, 1)
                h.eq(ui.step:GetText(), "Ride to the North Gate")
                h.eq(ui.next:GetText(), "then Zeppelin to East Dock")
            end)
            h.it("says nothing follows the last step", function()
                local ui, state = Dash.Debug()
                state.index = 3
                Dash.Refresh()
                h.eq(ui.step:GetText(), "Ride to Delta")
                h.eq(ui.next:GetText(), "")
                state.index = 1
                Dash.Refresh()
            end)
            h.it("keeps the frame at the art's aspect ratio so it cannot render stretched", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            local g = ns.Data.ArtGeometry
            -- Seen in game 2026-09-20 (first design): a square frame carrying
            -- round art on a square texture drew as an oval. The second
            -- design's art is 1024x1280, not square, so squareness is no
            -- longer the property that matters -- but a frame whose own
            -- width:height ratio drifts from the art's still draws it
            -- stretched or squashed. Same defect, stated for the new shape.
            local w, h2 = ui.frame:GetWidth(), ui.frame:GetHeight()
            local artRatio = g.canvas.w / g.canvas.h
            h.truthy(math.abs((w / h2) - artRatio) < 0.01,
                     "the frame must keep the art's 1024x1280 aspect ratio")
        end)

        h.it("draws the three stacked layers at one square, as the art requires", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            -- dash2-glass, dash2-steps-screen, dash2-eta-screen and
            -- dash2-housing were drawn corner to corner on one 1024x1280
            -- canvas. Drawing any of them at a different size shifts it off
            -- the others. Seen in game 2026-09-20 (first design): the screen
            -- was 180 while the bezel was 200, and the compass vanished
            -- behind the brass.
            for _, name in ipairs({ "glass", "stepsScreen", "etaScreen", "housing" }) do
                h.eq(ui[name]:GetWidth(), ui.artLayer:GetWidth(), name .. " must match the art layer")
                h.eq(ui[name]:GetHeight(), ui.artLayer:GetHeight(), name .. " must match the art layer")
            end
        end)

        h.it("hides the square fallback colour once the round glass loads", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            -- The flat colour exists so a missing texture still leaves a
            -- readable device, but it is a rectangle: left showing behind
            -- round art it frames the device with a dark box.
            h.truthy(ui.glass, "this test is meaningless if the art did not load")
            h.falsy(ui.flat:IsShown(), "the square must go when the glass arrives")
        end)

        h.it("gives the step line room to wrap instead of cutting a stop name in half", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            -- "Walk to Undercity Zeppelin Tower" was truncated in game.
            h.eq(ui.step.wordWrap, true, "the step line wraps; every other line truncates")
            h.truthy(ui.step:GetHeight() >= 24, "and has the height for a second line")
            h.eq(ui.next.wordWrap, false, "the following step stays one line")
        end)

        h.it("every line of text is bounded", function()
                local ui = Dash.Debug()
                for _, name in ipairs({ "step", "next", "distance", "eta" }) do
                    local fs = ui[name]
                    h.truthy(fs.points and #fs.points >= 2,
                             name .. " needs two horizontal anchors or it will draw past the frame")
                end
            end)
            h.it("dragging saves the position", function()
                local ui = Dash.Debug()
                ui.frame:SetPoint("TOP", UIParent, "BOTTOM", 7, -11)
                ui.frame.scripts.OnDragStart(ui.frame)
                ui.frame.scripts.OnDragStop(ui.frame)
                local p = GoblinPSDB.positions.dash
                h.eq(p.point, "TOP")
                h.eq(p.relativePoint, "BOTTOM")
                h.eq(p.x, 7)
                h.eq(p.y, -11)
            end)
            h.it("Stop closes it", function()
                local ui = Dash.Debug()
                Dash.Stop()
                h.falsy(ui.frame:IsShown())
            end)
            h.it("Start with no steps does not open", function()
                Dash.Start({ result = { steps = {} } })
                h.falsy(Dash.Debug().frame:IsShown())
            end)

            h.it("lays the five shared layers on one rectangle", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                -- They were drawn corner to corner on one canvas: any that is
                -- sized differently is drawn somewhere the artist did not mean.
                for _, name in ipairs({ "glass", "stepsScreen", "etaScreen", "housing" }) do
                    h.truthy(ui[name], name .. " is missing")
                    h.eq(ui[name]:GetWidth(), ui.artLayer:GetWidth(), name .. " must fill the device")
                    h.eq(ui[name]:GetHeight(), ui.artLayer:GetHeight(), name .. " must fill the device")
                end
            end)

            h.it("makes the compass and the arrow square, because both turn", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                for _, name in ipairs({ "compass", "arrow" }) do
                    h.eq(ui[name]:GetWidth(), ui[name]:GetHeight(),
                         name .. " rotates about its own middle, so it must be square")
                end
            end)

            h.it("takes every position from the generated geometry, not from constants", function()
                local g = ns.Data.ArtGeometry
                h.truthy(g, "Task 1 must have written ns.Data.ArtGeometry")
                Dash.Start(plan)
                local ui = Dash.Debug()
                -- The compass is sized as a share of the device, so a change in
                -- the art reaches the layout by regenerating Art.lua.
                local expect = ui.artLayer:GetWidth() * g.compassCrop.share
                h.truthy(math.abs(ui.compass:GetWidth() - expect) < 1,
                         "the compass is sized from geometry.compassCrop.share")
            end)

            h.it("stacks the housing above the art and the text above the housing", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                h.truthy(ui.housingFrame:GetFrameLevel() > ui.artLayer:GetFrameLevel(),
                         "the housing covers the art")
                h.truthy(ui.content:GetFrameLevel() > ui.housingFrame:GetFrameLevel(),
                         "nothing the player reads is ever behind the chassis")
            end)
        end)

        -- Stand the player at a world position on map 1.
        local function standAt(x, y)
            where.map, where.mx, where.my = 1, (10000 - y) / 10000, (10000 - x) / 10000
        end

        h.describe("the dash unit drives the trip", function()
            h.it("advances when you reach the step's target", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                standAt(5000, 0); facing = 0
                Dash.Tick("tick")
                h.eq(state.index, 1, "still on the way")
                standAt(10, 0)
                Dash.Tick("tick")
                h.eq(state.index, 2, "arriving moves on")
                h.eq(ui.step:GetText(), "Zeppelin to East Dock")
            end)

            h.it("moves Blizzard's pin onto each new step, not just the first", function()
                Dash.Start(plan)
                local _, state = Dash.Debug()
                local before = #pins
                standAt(10, 0)
                Dash.Tick("tick")
                h.eq(state.index, 2)
                h.truthy(#pins > before, "the spec puts the pin on the step you are on")
            end)

            h.it("says Arrived and stops at the end", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                state.index = #plan.result.steps
                standAt(0, 0)
                Dash.Tick("tick")
                h.eq(ui.step:GetText(), "Arrived.")
                h.falsy(state.plan, "the trip is over")
            end)

            h.it("shows the distance and the time left while travelling", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                standAt(700, 0)
                Dash.Tick("tick")
                h.eq(ui.distance:GetText(), "700 yd")
                h.truthy(ui.eta:GetText():find("min", 1, true), ui.eta:GetText())
            end)

            h.it("turns the arrow toward the step and hides it when facing is unknown", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                standAt(-100, 0); facing = 0
                Dash.Tick("tick")
                h.truthy(ui.arrow:IsShown())
                h.eq(ui.arrow.rotation, 0, "the target is due north of us and we face north")
                facing = nil
                Dash.Tick("tick")
                h.falsy(ui.arrow:IsShown(), "never point somewhere we cannot work out")
                facing = 0
            end)

            h.it("turns the compass by our own facing, not by the arrow's bearing", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                -- The target sits at a bearing of pi/2 from here while we
                -- face 0, so the arrow (bearing - facing) and the compass
                -- (-facing) land on different values. If the two
                -- SetRotation calls in aimArrow were ever swapped, this
                -- test would catch it; the earlier "due north, facing
                -- north" case could not, since both formulas agree there.
                standAt(0, -100); facing = 0
                Dash.Tick("tick")
                h.eq(ui.arrow.rotation, math.pi / 2, "the arrow points at the bearing to the target")
                h.eq(ui.compass.rotation, 0, "the compass turns opposite our own facing")
                facing = 0
            end)

            h.it("turns the compass by Trip.ROTATION_SIGN too, so flipping it moves both together", function()
                -- The checklist tells a tester whose arrow turns the wrong
                -- way to "flip Trip.ROTATION_SIGN and nothing else". Facing
                -- 0 above cannot prove the compass honours that constant
                -- (both signs give -0), so this uses a facing the two signs
                -- actually disagree on.
                Dash.Start(plan)
                local ui = Dash.Debug()
                standAt(0, -100); facing = 0.4
                Dash.Tick("tick")
                h.eq(ui.compass.rotation, -0.4, "default sign turns opposite facing")
                local saved = ns.Trip.ROTATION_SIGN
                ns.Trip.ROTATION_SIGN = -1
                Dash.Tick("tick")
                h.eq(ui.compass.rotation, 0.4,
                     "flipping ROTATION_SIGN, the checklist's own remedy for the arrow, must flip the compass with it")
                ns.Trip.ROTATION_SIGN = saved
                facing = 0
            end)

            h.it("does not advance or stray while on a zeppelin", function()
                Dash.Start(plan)
                local _, state = Dash.Debug()
                state.index = 2
                onTaxi = true
                standAt(0, 0)
                Dash.Tick("tick")
                h.eq(state.index, 2, "aboard, arriving at the target means nothing")
                onTaxi = false
            end)

            h.it("waits, without losing the trip, when the client will not place you", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                where.map = nil
                Dash.Tick("tick")
                h.eq(ui.distance:GetText(), "Waiting...")
                h.truthy(state.plan, "an instance must not end the trip")
                where.map, where.mx, where.my = 1, 0.89, 0.9
            end)

            h.it("does nothing at all when no trip is running", function()
                Dash.Stop()
                standAt(10, 0)
                Dash.Tick("tick")           -- must not error
                h.falsy(Dash.Debug().frame:IsShown())
            end)

            -- The only way to reach a zero-step replan is a recalculation that
            -- finds the player already at their destination (plan.to here is
            -- Westland, the zone map 1 stands in, so PlanRoute always returns
            -- 0 steps for it). That must finish the trip like arriving at the
            -- last step does, not leave the old step's text stuck on screen.
            h.it("finishes the trip when a recalculation finds nothing left to plan", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                standAt(100, 0); facing = 0
                Dash.Tick("tick")
                h.eq(state.index, 1, "still short of arriving")
                standAt(1000, 0)
                Dash.Tick("tick")
                h.eq(ui.step:GetText(), "Arrived.", "a replan with nothing left to do ends the trip")
                h.falsy(state.plan, "the trip is over, not stuck on the old plan")
            end)

            h.it("clears the previous trip's distance and ETA when a new one starts", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                standAt(700, 0); facing = 0
                Dash.Tick("tick")
                h.truthy(ui.distance:GetText() ~= "", "sanity: a distance is showing")
                Dash.Stop()
                Dash.Start(plan)
                h.eq(ui.distance:GetText(), "", "a fresh trip must not show the last trip's distance")
                h.eq(ui.eta:GetText(), "", "nor its ETA")
            end)

            h.it("clears distance and ETA for the tick after an advance, not the old step's numbers", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                standAt(700, 0); facing = 0
                Dash.Tick("tick")
                h.truthy(ui.distance:GetText() ~= "", "sanity: a distance is showing")
                standAt(10, 0)
                Dash.Tick("tick") -- arrives and advances
                h.eq(state.index, 2)
                h.eq(ui.distance:GetText(), "", "the old step's distance must not sit under the new step's name")
                h.eq(ui.eta:GetText(), "", "nor its ETA")
            end)

            h.it("backs off after a replan finds no route, instead of retrying every tick", function()
                Dash.Start(plan)
                local calls = 0
                local original = ns.Core.PlanRoute
                ns.Core.PlanRoute = function(to, from)
                    calls = calls + 1
                    return { to = to or plan.to, from = from, notes = {} } -- no .result: no route found
                end
                -- The stub must be restored even if an assertion below
                -- fails, or a regression here would take down every dash
                -- test that plans a route after this one.
                local ok, err = pcall(function()
                    standAt(700, 0); facing = 0
                    Dash.Tick("tick") -- establishes state.best
                    standAt(100000, 0)
                    Dash.Tick("tick") -- strays: one failed replan attempt
                    h.eq(calls, 1)
                    Dash.Tick("tick") -- still exactly as far away: must not retry yet
                    h.eq(calls, 1, "a failed replan must back off, not re-run Dijkstra every tick")
                end)
                ns.Core.PlanRoute = original
                h.truthy(ok, err)
            end)

            h.it("shows Recalculating for the tick a stray is caught, and lets it go on the next one", function()
                -- A real reroute, driven through the real Core.PlanRoute over
                -- the fake world, the same way the final review measured it:
                -- straying on the ride to the North Gate crossing forces a
                -- second plan with a genuinely new `state.plan` table.
                local hotel = ns.Search.Find(ns.Data, "hotel", "H", 1)[1]
                where.map, where.mx, where.my = 1, 0.89, 0.9 -- near Alpha
                local hotelPlan = ns.Core.PlanRoute(hotel)
                h.eq(hotelPlan.result.steps[1].to.name, "the North Gate", "sanity: a real, ride-first route")

                Dash.Start(hotelPlan)
                local ui, state = Dash.Debug()
                -- The restore below must run even if an assertion fails, or
                -- a regression here would leave `where` corrupted for every
                -- dash test that follows.
                local ok, err = pcall(function()
                    standAt(9700, 5000); facing = 0 -- close to the North Gate: sets a small state.best
                    Dash.Tick("tick")
                    h.eq(state.index, 1, "not yet at the arrival radius")

                    standAt(0, 0) -- far enough that d > best + STRAY_YARDS
                    local before = state.plan
                    Dash.Tick("tick")
                    h.truthy(state.plan ~= before, "sanity: the plan really was replaced")
                    h.truthy(ui.next:GetText():find("Recalculating", 1, true),
                              "the player must see the banner on the tick the stray is caught")

                    Dash.Tick("tick") -- the very next tick, position unchanged
                    h.falsy(ui.next:GetText():find("Recalculating", 1, true),
                             "it must not persist once the new route is under way")
                end)
                where.mx, where.my = 0.89, 0.9 -- restore for the tests that follow
                h.truthy(ok, err)
            end)

            h.it("re-pins the replanned route's first step, not just the trip's very first one", function()
                local hotel = ns.Search.Find(ns.Data, "hotel", "H", 1)[1]
                where.map, where.mx, where.my = 1, 0.89, 0.9
                local hotelPlan = ns.Core.PlanRoute(hotel)
                Dash.Start(hotelPlan)
                -- Same reasoning as above: the restore must not be skippable
                -- by a failing assertion.
                local ok, err = pcall(function()
                    standAt(9700, 5000); facing = 0
                    Dash.Tick("tick")
                    local before = #pins
                    standAt(0, 0)
                    Dash.Tick("tick")
                    h.truthy(#pins > before, "a replan must re-pin its new first step, per spec decision 3")
                end)
                where.mx, where.my = 0.89, 0.9 -- restore for the tests that follow
                h.truthy(ok, err)
            end)
        end)

        h.describe("the dash unit and Escape", function()
            h.it("ends the trip like Stop does, so no hidden trip keeps ticking or replanning unseen", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                h.truthy(state.plan, "sanity: a trip is running")
                ui.frame:Hide() -- what UISpecialFrames does on Escape; Dash never sees the key itself
                h.falsy(state.plan, "the trip must not outlive the window it belongs to")
                standAt(10, 0)
                Dash.Tick("tick") -- must do nothing: no error, no resurrected trip
                h.falsy(state.plan)
                h.falsy(ui.frame:IsShown())
            end)
        end)

        h.describe("the dash art", function()
            h.it("lays every part on with the coordinates the tool generated", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                for _, pair in ipairs({ { ui.housing, "dash2-housing" }, { ui.glass, "dash2-glass" },
                                        { ui.compass, "dash2-compass" }, { ui.arrow, "arrow" },
                                        { ui.stepsScreen, "dash2-steps-screen" },
                                        { ui.etaScreen, "dash2-eta-screen" } }) do
                    local texture, name = pair[1], pair[2]
                    local art = ns.Data.Art[name]
                    h.truthy(art, name .. " is missing from the generated table")
                    h.eq(texture:GetTexture(), "Interface\\AddOns\\GoblinPS\\Media\\" .. art.file)
                    h.eq(texture.texCoord[1], art.l)
                    h.eq(texture.texCoord[2], art.r)
                end
            end)
            h.it("keeps a working device when a texture will not load", function()
                -- build() runs at most once per Dash module instance (guarded by
                -- `if not ui then build() end`), and the very first Dash.Start
                -- above already built the shared window while every texture
                -- loaded fine. Stop/Start again would rebuild nothing and
                -- exercise nothing new, so this loads a second, independent
                -- copy of the module to genuinely drive a fresh build with a
                -- texture that fails.
                Fake.missingTextures["Interface\\AddOns\\GoblinPS\\Media\\dash2-housing"] = true
                local FreshDash = assert(loadfile("GoblinPS/Dash.lua"))("GoblinPS", ns)
                FreshDash.Start(plan)
                local ui = FreshDash.Debug()
                h.truthy(ui.frame:IsShown(), "a missing texture must not take the window with it")
                h.truthy(ui.step:GetText() ~= "", "the directions must still be readable")
                h.falsy(ui.housing, "a texture that would not load must not be laid over the colour")
                Fake.missingTextures["Interface\\AddOns\\GoblinPS\\Media\\dash2-housing"] = nil
            end)
            h.it("keeps the flat placeholder when the arrow's own texture will not load", function()
                -- The arrow is the one part with no colour behind it -- it
                -- IS the content -- so unlike dash-body (which just leaves
                -- ui.bodyArt nil and the colour showing), a failed arrow
                -- texture must leave WHITE8X8 in place, not the failed path
                -- SetTexture leaves behind on its own.
                Fake.missingTextures["Interface\\AddOns\\GoblinPS\\Media\\arrow"] = true
                local FreshDash = assert(loadfile("GoblinPS/Dash.lua"))("GoblinPS", ns)
                FreshDash.Start(plan)
                local ui = FreshDash.Debug()
                h.truthy(ui.frame:IsShown(), "a missing arrow texture must not take the window with it")
                h.eq(ui.arrow:GetTexture(), "Interface\\Buttons\\WHITE8X8",
                     "a failed arrow texture must fall back to the flat placeholder")
                Fake.missingTextures["Interface\\AddOns\\GoblinPS\\Media\\arrow"] = nil
            end)
            h.it("the directions are never hidden behind the device", function()
                -- A child frame draws entirely above every draw layer of its
                -- parent, so the housing's frame must sit strictly above the
                -- art layer whose holes it lines up with, and the content
                -- that carries the text must sit strictly above the housing
                -- -- pinned by level, not by hoping draw layers and creation
                -- order line up on their own.
                Dash.Start(plan)
                local ui = Dash.Debug()
                h.truthy(ui.housingFrame:GetFrameLevel() > ui.artLayer:GetFrameLevel(),
                          "the housing must draw above the art layer so its holes line up with it")
                h.truthy(ui.content:GetFrameLevel() > ui.housingFrame:GetFrameLevel(),
                          "the text must draw above the housing or the chassis would hide it")
            end)
        end)
    end

    h.describe("the fake frames model what the dash needs", function()
        h.it("a texture can be rotated", function()
            local f = CreateFrame("Frame")
            local t = f:CreateTexture(nil, "ARTWORK")
            t:SetRotation(1.25)
            h.eq(t.rotation, 1.25, "the fake must record the angle so tests can read it")
        end)
        h.it("a texture records its coordinates, tint and layer", function()
            local f = CreateFrame("Frame")
            local t = f:CreateTexture(nil, "ARTWORK")
            t:SetTexCoord(0, 0.75, 0, 0.5)
            h.eq(t.texCoord[2], 0.75, "SetTexCoord must record, not be swallowed")
            h.eq(t.texCoord[4], 0.5)
            t:SetVertexColor(1, 0, 0, 1)
            h.eq(t.vertexColor[1], 1)
            t:SetDrawLayer("OVERLAY")
            h.eq(t.drawLayer, "OVERLAY")
        end)
    end)

    h.describe("SelfTest.lua without generated art", function()
        h.it("loads without hard-erroring when Data/Art.lua has not been generated yet", function()
            -- Dash.lua guards the same table with `ns.Data.Art and ...`
            -- (see the "keeps a working device" test above); SelfTest.lua
            -- must not be the one file that takes the whole addon load down
            -- because tools/build_graph.py has not run yet.
            local bareNs = { Data = {} }
            local ok, err = pcall(function()
                return assert(loadfile("GoblinPS/SelfTest.lua"))("GoblinPS", bareNs)
            end)
            h.truthy(ok, tostring(err))
            h.eq(type(bareNs.SelfTest and bareNs.SelfTest.Run), "function",
                 "the module must still publish Run even with no shipped art")
        end)
    end)

    print = realPrint
end

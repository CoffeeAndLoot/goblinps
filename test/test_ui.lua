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
    local where = { map = 1, mx = 0.89, my = 0.9 } -- world 1000, 1100: beside Alpha
    local pins, loginCallbacks = {}, {}
    local level = 60 -- mounted, so ground steps say Ride
    -- What the client claims each zone's level range is, for /gps probe zones.
    -- Westland matches Data.Zones, Northland disagrees, Isle has a range we do
    -- not list, and Lostland answers nothing though we do list it.
    local clientLevels = { [1] = { 1, 10 }, [4] = { 25, 35 }, [3] = { 15, 20 } }
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
        SetWaypoint = function(map, x, y)
            pins[#pins + 1] = { map, x, y }
            return true
        end,
        SelfCheck = function() return { { name = "Fake.API", present = true } } end,
    }
    for _, file in ipairs({ "Geo", "Travel", "Search", "Graph", "Route", "Trip", "Known", "Prefs",
                            "Widgets", "Planner", "MinimapButton", "SelfTest", "Core" }) do
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
            h.eq(ui.rows[4].left:GetText(), "4. Zeppelin to East Dock (~4 min incl. wait)")
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
            -- neither has one
            h.eq(by[2].ourLow, nil); h.eq(by[2].clientLow, nil)
        end)
        h.it("names the zones that differ and counts the rest", function()
            local from = #printed
            SlashCmdList.GOBLINPS("probe zones")
            local said = table.concat(printed, "\n", from + 1, #printed)
            h.truthy(said:find("Northland: ours 30-40, client 25-35", 1, true), "should name the disagreement")
            h.truthy(said:find("3 of 5 zones", 1, true), "should count the answers")
            h.truthy(said:find("1 differ", 1, true))
            h.truthy(said:find("1 we do not list", 1, true))
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

    print = realPrint
end

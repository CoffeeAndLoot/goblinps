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
    -- The one user waypoint the client holds, as { map, x, y }, and how many
    -- times it has been cleared.
    local waypoint, waypointClears = nil, 0
    local level = 60 -- mounted, so ground steps say Ride
    ---@type number|nil, boolean, function[]
    local facing, onTaxi, tripCallbacks = 0, false, {}
    -- Who is logged in, and the nodes an open flight master's map reports.
    local character, openNodes, taxiCallbacks = "Tester-Test Realm", {}, {}
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
        OpenTaxiNodes = function() return openNodes end,
        OnTaxiMapOpened = function(callback) taxiCallbacks[#taxiCallbacks + 1] = callback end,
        CharacterKey = function() return character end,
        OnLogin = function(callback) loginCallbacks[#loginCallbacks + 1] = callback end,
        PlayerFacing = function() return facing end,
        OnTaxi = function() return onTaxi end,
        OnTripEvent = function(callback) tripCallbacks[#tripCallbacks + 1] = callback end,
        SetWaypoint = function(map, x, y)
            pins[#pins + 1] = { map, x, y }
            waypoint = { map, x, y }
            return true
        end,
        ClearWaypoint = function()
            waypoint = nil
            waypointClears = waypointClears + 1
        end,
        WaypointIs = function(map, x, y)
            return waypoint ~= nil and waypoint[1] == map and waypoint[2] == x and waypoint[3] == y
        end,
        SelfCheck = function() return { { name = "Fake.API", present = true } } end,
    }
    for _, file in ipairs({ "Geo", "Travel", "Search", "Graph", "Route", "Strip", "Trip", "Known", "Prefs",
                            "Widgets", "Planner", "Dash", "MinimapButton", "SelfTest", "Core" }) do
        assert(loadfile("GoblinPS/" .. file .. ".lua"))("GoblinPS", ns)
    end
    -- Flight paths live in the account-wide save, one table per character.
    -- GoblinPSCharDB is nil because that is exactly what the client hands back:
    -- verified 2026-09-21, it writes the per-character save and never loads it.
    GoblinPSDB, GoblinPSCharDB = { known = { [character] = { [1] = true, [2] = true, [4] = true } } }, nil

    local Planner = ns.Planner
    local W = ns.Widgets

    h.describe("Widgets.ChatColor", function()
        h.it("matches the formula for the palette entry, in chat and in the window", function()
            h.eq(ns.Widgets.ChatColor("amber"), "|cfff0b54a")
            local dim = ns.Widgets.COLOR.dim
            local expect = ("|cff%02x%02x%02x"):format(
                math.floor(dim[1] * 255 + 0.5), math.floor(dim[2] * 255 + 0.5), math.floor(dim[3] * 255 + 0.5))
            h.eq(ns.Widgets.ChatColor("dim"), expect)
        end)
    end)

    h.describe("the shared placement helpers", function()
        local function device(w, h2)
            local f = CreateFrame("Frame", nil, UIParent)
            f:SetSize(w, h2)
            return f
        end

        h.it("places a rectangle corner to corner from the device's top left", function()
            local f = device(200, 100)
            local t = f:CreateTexture(nil, "ARTWORK")
            W.PlaceRect(t, f, { left = 0.1, top = 0.2, right = 0.6, bottom = 0.7 })
            h.eq(#t.points, 2, "two corners fully place a region")
            h.eq(t.points[1][1], "TOPLEFT")
            h.eq(t.points[1][3], "TOPLEFT", "offsets are from the device's corner")
            h.truthy(math.abs(t.points[1][4] - 20) < 0.01, "left 0.1 of 200")
            h.truthy(math.abs(t.points[1][5] + 20) < 0.01, "top 0.2 of 100, downward")
            h.eq(t.points[2][1], "BOTTOMRIGHT")
            h.truthy(math.abs(t.points[2][4] - 120) < 0.01, "right 0.6 of 200")
            h.truthy(math.abs(t.points[2][5] + 70) < 0.01, "bottom 0.7 of 100")
        end)

        h.it("hangs a line on its rect's centre, letting the font set the height", function()
            -- The artist's *_line rects are a few pixels tall: slots to sit on,
            -- not boxes to fit in. Anchoring one corner to corner crushes the
            -- text into a box it cannot fit.
            local f = device(200, 100)
            local fs = W.Text(f, "green")
            W.PlaceLine(fs, f, { left = 0.1, top = 0.4, right = 0.9, bottom = 0.44 })
            h.eq(#fs.points, 2, "two horizontal anchors, so it still truncates")
            h.eq(fs.points[1][1], "LEFT")
            h.eq(fs.points[2][1], "RIGHT")
            h.truthy(math.abs(fs.points[1][5] + 42) < 0.01, "centre of 0.40..0.44 of 100")
            h.eq(fs.points[1][5], fs.points[2][5], "both ends sit on one line")
        end)

        h.it("makes a circle square and sizes it from the device's width", function()
            -- A radius measured against two different axes stops being a
            -- circle. Width, always, on both layouts.
            local f = device(200, 100)
            local t = f:CreateTexture(nil, "ARTWORK")
            W.PlaceCircle(t, f, { cx = 0.5, cy = 0.25, r = 0.1 })
            h.eq(t:GetWidth(), t:GetHeight(), "a circle is drawn on a square")
            h.truthy(math.abs(t:GetWidth() - 40) < 0.01, "2 * 0.1 * 200")
            h.eq(t.points[1][1], "CENTER")
            h.truthy(math.abs(t.points[1][4] - 100) < 0.01)
            h.truthy(math.abs(t.points[1][5] + 25) < 0.01)
        end)

        h.it("never reads a size from a frame that only inherits one", function()
            -- The fault that reached the client on 2026-09-20. A frame sized
            -- by SetAllPoints has no resolved size until the layout pass, so
            -- every fraction would be multiplied by nothing.
            local f = device(200, 100)
            local child = CreateFrame("Frame", nil, f)
            child:SetAllPoints(f)
            local fs = W.Text(child, "green")
            W.PlaceLine(fs, f, { left = 0.1, top = 0.4, right = 0.9, bottom = 0.44 })
            h.truthy(fs.points[1][4] > 0, "measured the device, not the child")
        end)
    end)

    h.describe("the planner window", function()
        h.it("opens from the slash command", function()
            SlashCmdList.GOBLINPS("")
            local ui = Planner.Debug()
            h.truthy(ui.frame:IsShown())
            h.eq(ui.frame:GetWidth(), Planner.SIZE[1])
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
            local steps = state.plan.result.steps
            h.eq(#steps, 5)
            h.eq(ns.Route.StepText(steps[1]), "Ride to Alpha")
            h.eq(ns.Route.StepText(steps[2]), "Fly to Bravo")
            h.eq(ns.Route.StepText(steps[4]), "Zeppelin to East Dock")
            h.eq(ns.Route.StepText(steps[5]), "Ride to Delta")
            h.eq(ui.total:GetText(), "~10 min · 1s")
            h.truthy(ui.go.enabled)
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

        h.it("Start Route drops a pin on the first step", function()
            local ui = Planner.Debug()
            Fake.Click(ui.go)
            h.falsy(ui.frame:IsShown(), "GO hands off to the dash and gets out of the way")
            SlashCmdList.GOBLINPS("") -- /gps reopens it, without ending the trip, for the tests that follow
            h.eq(#pins, 1)
            h.eq(pins[1][1], 1)
            h.truthy(printed[#printed]:find("Pin set: Ride to Alpha", 1, true))
        end)

        h.it("puts the plan's notes on the warning line when the route has steps", function()
            local ui = Planner.Debug()
            local originalHearthBindName = ns.API.HearthBindName
            ns.API.HearthBindName = function() return "Nowhere Inn Bind" end
            Planner.Replan()
            h.truthy(ui.hint:GetText():find("Hearth: unknown inn", 1, true))
            h.falsy(ui.notes:IsShown(), "the idle status lines give way to the route")
            h.falsy(ui.known:IsShown())
            ns.API.HearthBindName = originalHearthBindName
            Planner.Replan()
            h.falsy(ui.hint:GetText():find("Hearth", 1, true))
        end)

        h.it("explains itself when it cannot tell where you are", function()
            local ui = Planner.Debug()
            where.map = nil
            Planner.Replan()
            h.eq(ui.notes:GetText(), "Can't tell where you are. Inside an instance?")
            h.truthy(ui.notes:IsShown(), "a status line says why there is no route")
            h.eq(ui.total:GetText(), "")
            h.falsy(ui.go.enabled)
            where.map = 1
            Planner.Replan()
            h.truthy(ui.go.enabled)
        end)

        h.it("Start Route re-plans from where you are now instead of using a stale plan", function()
            local ui, state = Planner.Debug()
            h.eq(ns.Route.StepText(state.plan.result.steps[1]), "Ride to Alpha")
            -- The player moves without touching either box: the planner's
            -- last plan (from near Alpha) is now stale.
            where.mx, where.my = 0.1, 0.9 -- right beside Bravo now
            Fake.Click(ui.go)
            h.eq(ns.Route.StepText(state.plan.result.steps[1]), "Ride to West Dock")
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
            h.eq(ui.notes:GetText(), "You're already at Westland.")
            h.truthy(ui.notes:IsShown())
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

        h.it("keeps the window at the art's exact aspect ratio", function()
            -- 1600x1024 is 25:16. The old 660x400 was 1.65, so the frame
            -- would have drawn about 6% too wide -- the fault that made the
            -- dash's first design render as an oval, which took a client run
            -- to see.
            local canvas = ns.Data.ArtGeometry.planner.wide.canvas
            h.truthy(math.abs(Planner.SIZE[1] / Planner.SIZE[2] - canvas.w / canvas.h) < 0.001,
                     "the window must keep the art's aspect ratio")
        end)

        h.it("carries no art of its own on the window frame", function()
            -- Widgets.Panel lays two opaque textures on the frame it makes and
            -- returns only the frame, so nothing can hide them. The planner
            -- art has transparent margins; an unhideable rectangle behind it
            -- boxes in a window that is not a rectangle. Fixed once on the
            -- dash already.
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.eq(#ui.frame.regions, 0,
                 "the window frame must own no regions; the fallback is its own frame")
            h.truthy(ui.flat, "and the fallback frame exists")
        end)

        h.it("hides the flat fallback once the frame art loads", function()
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.truthy(ui.frameArt, "the frame art loaded in the test fixture")
            h.falsy(ui.flat:IsShown(), "so the coloured rectangle goes")
        end)

        h.it("stacks the art under the content", function()
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.truthy(ui.content:GetFrameLevel() > ui.artLayer:GetFrameLevel(),
                     "nothing the player reads is ever behind the chassis")
            -- The results list rides above the screen and the side panel on
            -- its STRATA, not on its level. Its level (base + 3) only TIES
            -- with theirs -- they are children of content, one above it by
            -- default -- so a test asserting the level proves nothing about
            -- what actually carries the overlay. DIALOG does.
            h.eq(ui.results:GetFrameStrata(), "DIALOG",
                 "the search overlay covers what it drops over")
            h.truthy(ui.results:GetFrameLevel() <= ui.screen:GetFrameLevel(),
                     "and its level does not: at best it ties with the panels it covers")
        end)

        h.it("places the chrome from the geometry, in real pixels", function()
            -- Pin the position, not just the size: a test that checks how big
            -- a thing is cannot tell you it is in the wrong place.
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout()
            local ui = ns.Planner.Debug()
            local g = ns.Data.ArtGeometry.planner.wide
            local w = ui.frame:GetWidth()
            for _, name in ipairs({ "close", "gear" }) do
                local button, circ = ui[name], g[name .. "Button"]
                h.truthy(button, name .. " is missing")
                h.truthy(math.abs(button:GetWidth() - circ.r * 2 * w) < 1,
                         name .. " is sized from geometry." .. name .. "Button.r")
                h.truthy(math.abs(button.points[1][4] - circ.cx * w) < 1,
                         name .. " sits at geometry." .. name .. "Button.cx, got "
                         .. tostring(button.points[1][4]))
            end
            h.truthy(math.abs(ui.titlePlate.points[1][4] - g.titlePlate.left * w) < 1,
                     "the title plate starts where the geometry says")
        end)

        h.it("draws the screen's scenery where nothing opaque can cover it", function()
            -- The fault this pins: the backdrop was created on artLayer and
            -- placed at exactly g.screen -- directly beneath the `screen`
            -- panel, whose two colour fills are fully opaque and four frame
            -- levels higher. Byte-identical rects, so the scenery was drawn,
            -- cropped correctly, and never once seen. Every test on the
            -- branch passed because they all asked where it was and how big,
            -- and both were right. So ask the mechanism instead: whose frame
            -- is it on, at what layer, and is anything opaque over it there.
            --
            -- Since the owner's first look at plan 8 (2026-09-21) the scenery
            -- fills the frame's whole opening, so it sits at the back of the
            -- art layer and everything drawn over it must let it through.
            local ORDER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout()
            local ui = ns.Planner.Debug()
            h.truthy(ui.backdrop, "the backdrop texture exists")
            h.truthy(ui.backdrop.parent == ui.artLayer,
                     "the scenery sits on the art layer, behind the whole opening")
            h.eq(ui.backdrop.drawLayer, "BACKGROUND", "at the back of it")
            h.eq(ui.frameArt.parent, ui.backdrop.parent, "the chassis shares its frame")
            h.truthy(ORDER[ui.frameArt.drawLayer] > ORDER[ui.backdrop.drawLayer],
                     "and is drawn over it, hiding the edge the opening tucks under the brass")
            h.falsy(ui.panelArt:IsShown(), "the tiled backing is the fallback, and gives way")
            h.eq(#ui.screen.fills, 2, "the screen records both of its fills")
            for _, fill in ipairs(ui.screen.fills) do
                h.falsy(fill:IsShown(), "the screen's opaque fills let the scenery through")
            end
            -- The art layer's own regions only cover it from a layer at or
            -- above its own; every frame above the art layer covers it from
            -- any layer at all.
            for _, r in ipairs(ui.artLayer.regions) do
                if r ~= ui.backdrop and r ~= ui.frameArt then
                    local opaque = r.colorTexture and r.colorTexture[4] >= 1 and r:IsShown()
                    h.falsy(opaque and ORDER[r.drawLayer or "ARTWORK"] >= ORDER[ui.backdrop.drawLayer],
                            "an opaque fill on the art layer would hide it, layer " .. tostring(r.drawLayer))
                end
            end
            for _, frame in ipairs({ ui.content, ui.screen, ui.toBox, ui.go }) do
                for _, r in ipairs(frame.regions) do
                    local opaque = r.colorTexture and r.colorTexture[4] >= 1 and r:IsShown()
                    h.falsy(opaque, "a shown opaque fill over the art layer would hide the scenery, layer "
                            .. tostring(r.drawLayer))
                end
            end
        end)

        h.it("places the scenery at the frame's measured opening, in real pixels", function()
            -- Pin the position, not just the size.
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout()
            local ui = ns.Planner.Debug()
            local inner = ns.Data.ArtGeometry.planner.wide.interior
            local w, fh = ui.frame:GetWidth(), ui.frame:GetHeight()
            local p1, p2 = ui.backdrop.points[1], ui.backdrop.points[2]
            h.eq(#ui.backdrop.points, 2, "two corners, nothing else")
            h.truthy(p1[1] == "TOPLEFT" and p1[2] == ui.frame and p2[1] == "BOTTOMRIGHT" and p2[2] == ui.frame,
                     "anchored corner to corner on the window, which has a real size")
            h.truthy(math.abs(p1[4] - inner.left * w) < 0.5, "left edge at the opening, got " .. tostring(p1[4]))
            h.truthy(math.abs(-p1[5] - inner.top * fh) < 0.5, "top edge at the opening, got " .. tostring(-p1[5]))
            h.truthy(math.abs(p2[4] - inner.right * w) < 0.5, "right edge at the opening, got " .. tostring(p2[4]))
            h.truthy(math.abs(-p2[5] - inner.bottom * fh) < 0.5,
                     "bottom edge at the opening, got " .. tostring(-p2[5]))
        end)

        h.it("hides a control's flat fallback once its art loads, and keeps it when the art will not", function()
            -- Seen in the client 2026-09-21: a gold rectangle round Start
            -- Route and the search box. The art's rounded corners are
            -- transparent, so the flat colours left under it showed as a box,
            -- and the white hover rectangle would have flashed one too.
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            for _, control in ipairs({ { ui.go, 3, "Start Route" }, { ui.toBox, 2, "the search box" } }) do
                local c, want, name = control[1], control[2], control[3]
                h.truthy(c.slice, name .. " carries its art")
                h.eq(#c.fallback, want, name .. " records every fallback texture")
                for _, t in ipairs(c.fallback) do
                    h.falsy(t:IsShown(), name .. ": a fallback left shown boxes in the art, layer "
                            .. tostring(t.drawLayer))
                end
            end
            h.truthy(ui.go.fallback[3].drawLayer == "HIGHLIGHT", "the hover rectangle is one of them")

            local badPath = "Interface\\AddOns\\GoblinPS\\Media\\" .. ns.Data.Art["button"].file
            Fake.missingTextures[badPath] = true
            local b = W.Button(UIParent, "x", 120, 24)
            local slice = W.Stretch3(b, "button", 0.25, 1.0)
            Fake.missingTextures[badPath] = nil
            h.falsy(slice, "the art failed, as arranged")
            for _, t in ipairs(b.fallback) do
                h.truthy(t:IsShown(), "with no art the flat button stays whole, layer " .. tostring(t.drawLayer))
            end
        end)

        h.it("covers the frame's opening with the backdrop without distorting it", function()
            -- screen-backdrop is 2.5:1 scenery and the frame's opening is not.
            -- Stretching it to fit would squash the mountains; the answer is
            -- to crop the overflow, centred, inside the part's own texture
            -- coordinates. The measured opening is about 2.17:1, narrower
            -- than the scenery, so the overflow is width: the full height
            -- stays.
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout()
            local ui = ns.Planner.Debug()
            h.truthy(ui.backdrop, "the backdrop texture exists")
            local l, r, t, b = unpack(ui.backdrop.texCoord)
            local part = ns.Data.Art["screen-backdrop"]
            h.truthy(math.abs(t - part.t) < 0.0001 and math.abs(b - part.b) < 0.0001,
                     "an opening narrower than the scenery keeps its whole height")
            h.truthy(l >= part.l - 0.0001 and r <= part.r + 0.0001,
                     "the cover-crop stays inside the part's own padding crop")
            h.truthy(math.abs((l - part.l) - (part.r - r)) < 0.0001,
                     "the crop is centred: equal slivers off left and right")
            h.truthy(r - l < part.r - part.l,
                     "2.5:1 scenery in a 2.17:1 opening loses width")
        end)

        h.it("crops the backdrop by the shipped canvas's aspect, not the master PNG's", function()
            -- screen-backdrop's master PNG is 1600x640 (aspect 2.5), but it
            -- ships at 512x205 padded to a 512x256 canvas (aspect 2.4976).
            -- Close, not equal -- and using the master's pixel size instead
            -- of the shipped canvas's still lands a crop that is centred and
            -- inside bounds (the test above stays green either way), just
            -- the wrong SIZE. Centredness cannot catch that; only the
            -- magnitude can.
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout()
            local ui = ns.Planner.Debug()
            local part = ns.Data.Art["screen-backdrop"]
            local inner = ns.Data.ArtGeometry.planner.wide.interior
            local w, fh = ui.frame:GetWidth(), ui.frame:GetHeight()
            local boxW = (inner.right - inner.left) * w
            local boxH = (inner.bottom - inner.top) * fh
            local span = part.r - part.l
            local tall = part.b - part.t
            -- The correct domain: part.cw/part.ch are the padded canvas's own
            -- pixel size (what l/r/t/b are fractions OF), never the pre-scale
            -- master's.
            local partAspect = (part.cw * span) / (part.ch * tall)
            local boxAspect = boxW / boxH
            h.truthy(partAspect > boxAspect, "the scenery is wider than the opening, so width is trimmed")
            local wantKeep = span * (boxAspect / partAspect)
            local l, r = unpack(ui.backdrop.texCoord)
            h.truthy(math.abs((r - l) - wantKeep) < 0.001,
                     "trimmed span must match the shipped canvas's aspect: got "
                     .. tostring(r - l) .. ", wanted " .. tostring(wantKeep))
            -- The master's 1600x640 mixed with the padded canvas's fractions
            -- keeps a different width, so this test can tell the domains apart.
            local masterKeep = span * (boxAspect / ((1600 * span) / (640 * tall)))
            h.truthy(math.abs(wantKeep - masterKeep) > 0.01, "the master's size gives a different crop")
        end)

        h.it("tiles the panel backing behind every opening, not just the screen", function()
            -- Codex's placement note: "tile behind contents, clipped to
            -- interior opening." At exactly g.screen the tile would sit
            -- right where screen-backdrop goes and never be seen, while the
            -- side panel next to it kept its flat colour.
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout()
            local ui = ns.Planner.Debug()
            local g = ns.Data.ArtGeometry.planner.wide
            local frameW, frameH = ui.frame:GetWidth(), ui.frame:GetHeight()
            h.truthy(ui.panelArt, "the panel backing exists")
            local leftFrac = ui.panelArt.points[1][4] / frameW
            local topFrac = -ui.panelArt.points[1][5] / frameH
            local rightFrac = ui.panelArt.points[2][4] / frameW
            local bottomFrac = -ui.panelArt.points[2][5] / frameH
            for _, rect in ipairs({ g.screen, g.toBox, g.goButton }) do
                h.truthy(leftFrac <= rect.left + 0.001, "covers the rect's left")
                h.truthy(topFrac <= rect.top + 0.001, "covers the rect's top")
                h.truthy(rightFrac >= rect.right - 0.001, "covers the rect's right")
                h.truthy(bottomFrac >= rect.bottom - 0.001, "covers the rect's bottom")
            end
        end)

        h.it("keeps the tiled backing off the chassis's own ornament", function()
            -- The two plates are riveted to the chassis -- the brass crest at
            -- the top, the rail at the bottom -- rather than set into the
            -- opening. The artist's note for this part reads "tile behind
            -- contents, clipped to interior opening; no exterior background".
            -- The chassis is now drawn over the tile, so this checks the tile's
            -- own extent: it must stop at the opening, not climb onto the
            -- plates, while still backing every opening inside it.
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.truthy(ui.panelArt, "the panel backing exists")
            ns.Planner.ApplyLayout()
            local g = ns.Data.ArtGeometry.planner.wide
            local w, frameH = ui.frame:GetWidth(), ui.frame:GetHeight()
            local top = -ui.panelArt.points[1][5] / frameH
            local bottom = -ui.panelArt.points[2][5] / frameH
            h.truthy(top > g.titlePlate.top + 0.001,
                     "wide: the tile climbed onto the brass crest, top is " .. tostring(top))
            h.truthy(bottom < g.taglinePlate.bottom - 0.001,
                     "wide: the tile reached the bottom rail, bottom is " .. tostring(bottom))
            -- Shrinking it must not cost the openings it exists to back.
            local left = ui.panelArt.points[1][4] / w
            local right = ui.panelArt.points[2][4] / w
            for _, rect in ipairs({ g.screen, g.toBox, g.goButton }) do
                h.truthy(left <= rect.left + 0.001 and top <= rect.top + 0.001
                         and right >= rect.right - 0.001 and bottom >= rect.bottom - 0.001,
                         "wide: the tile must still cover every opening")
            end
        end)

        h.it("fills the frame's whole opening with the backing, drawn under the brass", function()
            -- Seen in the client 2026-09-21 against a plain sky: the backing
            -- was sized to the union of the controls, which sits inset from
            -- the frame's opening, so the world showed through on the left,
            -- the right and the bottom. It must fill the opening make_art.py
            -- measures from the frame's alpha -- and it can only do that if
            -- the chassis is drawn OVER it, because that box deliberately
            -- tucks a few pixels under the brass on every side.
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            ns.Planner.ApplyLayout()
            local inner = ns.Data.ArtGeometry.planner.wide.interior
            h.truthy(inner, "wide: the generated geometry carries the measured opening")
            local w, fh = ui.frame:GetWidth(), ui.frame:GetHeight()
            local p1, p2 = ui.panelArt.points[1], ui.panelArt.points[2]
            h.truthy(math.abs(p1[4] - inner.left * w) < 0.5,
                     "wide: the backing's left edge is not at the opening, got " .. tostring(p1[4] / w))
            h.truthy(math.abs(-p1[5] - inner.top * fh) < 0.5,
                     "wide: the backing's top edge is not at the opening, got " .. tostring(-p1[5] / fh))
            h.truthy(math.abs(p2[4] - inner.right * w) < 0.5,
                     "wide: the backing's right edge is not at the opening, got " .. tostring(p2[4] / w))
            h.truthy(math.abs(-p2[5] - inner.bottom * fh) < 0.5,
                     "wide: the backing's bottom edge is not at the opening, got " .. tostring(-p2[5] / fh))
            h.eq(ui.panelArt.parent, ui.frameArt.parent,
                 "backing and chassis share one frame, so their draw layers decide the order")
            local order = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4 }
            h.truthy(order[ui.frameArt.drawLayer] > order[ui.panelArt.drawLayer],
                     "the chassis must be drawn over the backing, not under it")
        end)

        h.it("lets the plates carry their own lettering, not a second copy", function()
            -- Both plates are drawn with their words in them: "GOBLINPS /
            -- Goblin Positioning System" and "Time is money, friend." Seen in
            -- the client 2026-09-21: the FontStrings drew "GoblinPS" and
            -- "Accuracy not guaranteed" on top of that lettering. The text is
            -- the fallback for a plate that did not load, nothing more.
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.truthy(ui.titlePlate and ui.taglinePlate, "both plates loaded in the fixture")
            h.falsy(ui.title:IsShown(), "the title plate already says GoblinPS")
            h.falsy(ui.tagline:IsShown(), "the tagline plate already carries its line")
        end)

        h.it("keeps the title in text when its plate will not load", function()
            local badPath = "Interface\\AddOns\\GoblinPS\\Media\\title-plate"
            Fake.missingTextures[badPath] = true
            local savedPlanner = ns.Planner
            local FreshPlanner = assert(loadfile("GoblinPS/Planner.lua"))("GoblinPS", ns)
            ns.Planner = savedPlanner
            local ok, err = pcall(function()
                FreshPlanner.Toggle()
                local ui = FreshPlanner.Debug()
                h.falsy(ui.titlePlate, "the plate failed, as arranged")
                h.truthy(ui.title:IsShown(), "so the window still says what it is")
                h.falsy(ui.tagline:IsShown(), "the tagline's own plate still loaded")
                FreshPlanner.Toggle()
            end)
            Fake.missingTextures[badPath] = nil
            assert(ok, err)
        end)

        h.it("labels a button on its shipped art in green, and dims it when disabled", function()
            -- Seen in the client 2026-09-21: GO kept the steel
            -- label meant for the flat brass face -- dark text on the shipped
            -- art's dark glass -- and could not be read.
            local function is(button, name)
                local want, got = W.COLOR[name], button.label.color
                return got ~= nil and math.abs(got[1] - want[1]) < 1e-6
                    and math.abs(got[2] - want[2]) < 1e-6 and math.abs(got[3] - want[3]) < 1e-6
            end
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            W.SetButtonEnabled(ui.go, false)
            h.truthy(is(ui.go, "dim"), "a disabled GO is dim")
            W.SetButtonEnabled(ui.go, true)
            h.truthy(is(ui.go, "green"), "an enabled GO is green")
            local plain = W.Button(UIParent, "x", 40, 20)
            W.SetButtonEnabled(plain, true)
            h.truthy(is(plain, "steel"), "with no art, the flat brass face keeps its steel label")
        end)

        h.it("gives a stretched control fixed end caps", function()
            -- One button part draws at 65 px for Here and 135 for GO. A single
            -- stretched texture squashes the caps at one width and stretches
            -- them at the other.
            local f = CreateFrame("Frame", nil, UIParent)
            f:SetSize(200, 40)
            -- button.png is 768x192, so a quarter of its width is a 192x192
            -- cap: aspect 1.
            local slice = W.Stretch3(f, "button", 0.25, 1.0)
            h.truthy(slice, "three-slice returns its pieces")
            h.eq(slice.left:GetWidth(), slice.right:GetWidth(),
                 "both caps draw at the same natural width")
            h.truthy(slice.middle.points and #slice.middle.points >= 2,
                     "the middle is anchored between the caps, so it takes the slack")
        end)

        h.it("sizes a three-slice's end caps from the height it is handed, never the frame's", function()
            -- Restretch3 takes the height as an argument on purpose. Once
            -- ApplyLayout has re-anchored a control corner to corner, that
            -- control ONLY INHERITS its size, and this project's oldest rule
            -- says never measure such a frame: GetHeight answers the stale
            -- explicit size until the client's layout pass, and answers 0 if
            -- there never was one. So the caller works the height out the same
            -- way PlaceRect works its offsets out -- from the geometry and the
            -- frame that really was given a size.
            local f = CreateFrame("Frame", nil, UIParent)
            f:SetSize(200, 40)
            local slice = W.Stretch3(f, "button", 0.25, 1.0)
            h.eq(slice.left:GetWidth(), 40, "the cap starts at the build-time height")
            W.Restretch3(f, 33.75)              -- the geometry's height, not the frame's 40
            h.eq(slice.left:GetWidth(), 33.75, "the left cap takes the height it was handed")
            h.eq(slice.right:GetWidth(), 33.75, "and so does the right")
            h.falsy(W.Restretch3(CreateFrame("Frame", nil, UIParent), 20),
                    "a control with no slice answers false rather than erroring")
        end)

        h.it("sizes every three-sliced control's caps from its own rect", function()
            -- The fault this pins: Restretch3 was wired in correctly and
            -- changed no number, because it measured the control -- which by
            -- then only inherited its size. Every cap stayed at its build-time
            -- width in both layouts: GO drew 24 where the wide geometry
            -- implies 32.50 and the tall 33.75, `here` 20 against 30.06, the
            -- two boxes 28.75 against 43.22, the layout button 18 against
            -- 22.34. Asserting through ApplyLayout with nothing set by hand is
            -- the only way to see that; a test that sets the height itself
            -- proves only that ApplyLayout made the call.
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            ns.Planner.ApplyLayout()
            local g = ns.Data.ArtGeometry.planner.wide
            local frameH = ui.frame:GetHeight()
            local checks = { { ui.go, g.goButton, "go" }, { ui.toBox, g.toBox, "toBox" } }
            for _, check in ipairs(checks) do
                local slice, rect, name = check[1].slice, check[2], check[3]
                h.truthy(slice, "wide: " .. name .. " carries no three-slice")
                local want = (rect.bottom - rect.top) * frameH * slice.capAspect
                for _, cap in ipairs({ { slice.left, "left" }, { slice.right, "right" } }) do
                    h.truthy(math.abs(cap[1]:GetWidth() - want) < 0.01,
                             "wide: " .. name .. "'s " .. cap[2] .. " cap is "
                             .. tostring(cap[1]:GetWidth()) .. ", the geometry implies "
                             .. tostring(want))
                end
            end
        end)

        h.it("swaps a stretched button's art to button-disabled instead of only tinting the face", function()
            -- SetButtonEnabled used to only tint button.face (BORDER), which
            -- a three-slice now sits over on the ARTWORK layer -- so once
            -- real art loads, a disabled control would still show its
            -- enabled texture with no visible change at all.
            local f = CreateFrame("Frame", nil, UIParent)
            f:SetSize(200, 40)
            f.face = f:CreateTexture(nil, "BORDER")
            local slice = W.Stretch3(f, "button", 0.25, 1.0)
            h.truthy(f.slice == slice, "Stretch3 records its pieces on the frame it decorates")

            W.SetButtonEnabled(f, false)
            local disabledPart = ns.Data.Art["button-disabled"]
            h.eq(slice.left:GetTexture(), "Interface\\AddOns\\GoblinPS\\Media\\" .. disabledPart.file,
                 "disabled must not still be showing the enabled texture")
            h.eq(slice.middle:GetTexture(), "Interface\\AddOns\\GoblinPS\\Media\\" .. disabledPart.file)
            h.eq(slice.right:GetTexture(), "Interface\\AddOns\\GoblinPS\\Media\\" .. disabledPart.file)

            W.SetButtonEnabled(f, true)
            local enabledPart = ns.Data.Art["button"]
            h.eq(slice.left:GetTexture(), "Interface\\AddOns\\GoblinPS\\Media\\" .. enabledPart.file,
                 "re-enabling swaps the art back")
            h.eq(slice.middle:GetTexture(), "Interface\\AddOns\\GoblinPS\\Media\\" .. enabledPart.file)
            h.eq(slice.right:GetTexture(), "Interface\\AddOns\\GoblinPS\\Media\\" .. enabledPart.file)
        end)

        h.it("lights a three-sliced button on hover and presses it while held", function()
            -- button-hover and button-pressed shipped with this branch and
            -- nothing drew them. reslice already existed for the disabled
            -- swap, so the states cost four scripts.
            local f = CreateFrame("Button", nil, UIParent)
            f:SetSize(200, 40)
            f.face = f:CreateTexture(nil, "BORDER")
            local slice = W.Stretch3(f, "button", 0.25, 1.0)
            W.WireButtonArt(f)
            local function art(name)
                return "Interface\\AddOns\\GoblinPS\\Media\\" .. ns.Data.Art[name].file
            end

            f.scripts.OnEnter(f)
            h.eq(slice.left:GetTexture(), art("button-hover"), "the cursor lights it")
            f.scripts.OnMouseDown(f)
            h.eq(slice.middle:GetTexture(), art("button-pressed"), "holding it presses it")
            f.scripts.OnMouseUp(f)
            h.eq(slice.right:GetTexture(), art("button-hover"),
                 "letting go with the cursor still on it goes back to lit, not to plain")
            f.scripts.OnLeave(f)
            h.eq(slice.left:GetTexture(), art("button"), "and leaving puts the plain art back")

            W.SetButtonEnabled(f, false)
            f.scripts.OnEnter(f)
            f.scripts.OnMouseDown(f)
            h.eq(slice.left:GetTexture(), art("button-disabled"),
                 "a disabled button answers neither hover nor press")
        end)

        h.it("leaves a stretched button's art alone when button-disabled will not load", function()
            -- A missing disabled state must never lose the button: keep
            -- showing whatever the slice already showed.
            local f = CreateFrame("Frame", nil, UIParent)
            f:SetSize(200, 40)
            f.face = f:CreateTexture(nil, "BORDER")
            local slice = W.Stretch3(f, "button", 0.25, 1.0)
            local enabledPart = ns.Data.Art["button"]
            local enabledPath = "Interface\\AddOns\\GoblinPS\\Media\\" .. enabledPart.file

            local badPath = "Interface\\AddOns\\GoblinPS\\Media\\" .. ns.Data.Art["button-disabled"].file
            Fake.missingTextures[badPath] = true
            W.SetButtonEnabled(f, false)
            Fake.missingTextures[badPath] = nil
            h.eq(slice.left:GetTexture(), enabledPath, "still showing the enabled art, not a failed swap")
        end)

        h.it("places every input, panel and footer line from the geometry", function()
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout()
            local ui = ns.Planner.Debug()
            local g = ns.Data.ArtGeometry.planner.wide
            local w = ui.frame:GetWidth()
            local checks = {
                { ui.toBox, g.toBox, "toBox" },
                { ui.screen, g.screen, "screen" },
                { ui.go, g.goButton, "goButton" },
            }
            for _, check in ipairs(checks) do
                local region, rect, name = check[1], check[2], check[3]
                h.truthy(region, "wide: " .. name .. " is missing")
                h.truthy(math.abs(region.points[1][4] - rect.left * w) < 1,
                         "wide: " .. name .. " starts at its rect's left, got "
                         .. tostring(region.points[1][4]))
            end
            -- The status and footer lines are lines, so they carry two
            -- horizontal anchors on one y, not four corners.
            for _, fs in ipairs({ ui.total, ui.hint, ui.notes, ui.known }) do
                h.eq(#fs.points, 2)
                h.eq(fs.points[1][5], fs.points[2][5], "both ends sit on one line")
            end
        end)

        h.it("keeps working when not one texture loads", function()
            -- Art is laid over colours. A beta patch that renames a file must
            -- leave a window the player can still route with.
            local restore = ns.Data.Art
            ns.Data.Art = nil
            local ok = pcall(function()
                ns.Planner.Toggle()
                ns.Planner.ApplyLayout()
            end)
            ns.Data.Art = restore
            h.truthy(ok, "building with no art at all must not error")
            local ui = ns.Planner.Debug()
            h.truthy(ui.flat:IsShown(), "and the flat fallback comes back")
        end)

        h.it("keeps a working window when one named texture will not load", function()
            -- The dash's tests fail exactly one part with Fake.missingTextures
            -- while the rest load, which is a stricter check than nilling
            -- ns.Data.Art wholesale above. screen-backdrop is an insert, not a
            -- stacked layer, so its own failure must not take anything else
            -- down with it.
            local badPath = "Interface\\AddOns\\GoblinPS\\Media\\screen-backdrop"
            Fake.missingTextures[badPath] = true
            -- loadfile re-runs `ns.Planner = Planner` as a side effect; every
            -- later test (and Core.lua's own slash handler) reaches the
            -- planner through ns.Planner directly, so put the real one straight
            -- back and drive this fresh copy only through its own local.
            local savedPlanner = ns.Planner
            local FreshPlanner = assert(loadfile("GoblinPS/Planner.lua"))("GoblinPS", ns)
            ns.Planner = savedPlanner
            local ok, err = pcall(function()
                FreshPlanner.Toggle()
                FreshPlanner.ApplyLayout()
            end)
            Fake.missingTextures[badPath] = nil
            h.truthy(ok, err)
            local ui = FreshPlanner.Debug()
            h.truthy(ui.frame:IsShown(), "a missing texture must not take the window with it")
            h.falsy(ui.backdrop, "a texture that would not load must not be laid over the colour")
            h.truthy(ui.panelArt:IsShown(), "the tiled backing stays, as the fallback")
            h.eq(#ui.screen.fills, 2, "the screen records both of its fills")
            for _, fill in ipairs(ui.screen.fills) do
                h.truthy(fill:IsShown(), "and the screen keeps its colours")
            end
            -- the rest of the window is still usable with the backdrop missing
            Fake.Type(ui.toBox, "delt")
            h.truthy(ui.results:IsShown(), "the control must still work")
        end)

        h.it("drops the results list over the screen", function()
            -- One shared list, spanning the search area: it serves whichever
            -- box has focus and the art has one opening for it.
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout()
            local ui = ns.Planner.Debug()
            local g = ns.Data.ArtGeometry.planner.wide
            local w = ui.frame:GetWidth()
            Fake.Type(ui.toBox, "delt")
            h.truthy(ui.results:IsShown(), "typing opens the list")
            h.eq(ui.results.points[1][2], ui.frame,
                 "anchored to the window, not to the box that has focus")
            h.truthy(math.abs(ui.results.points[1][4] - g.resultsList.left * w) < 1,
                     "and it sits where the geometry says")
            Fake.MouseDown(GoblinPSPlanner) -- put the list away for the test that follows
        end)

        h.it("keeps every result row inside the list's box", function()
            -- Client report 2026-09-21: typing "a" dropped 8 rows and two of
            -- them (Booty Bay, Brackenwall Village) hung below the list's
            -- panel, because showResults() always filled all MAX_RESULTS
            -- rows regardless of how tall the list's own box is.
            -- ROW mirrors Planner.lua's private row-height constant (18px);
            -- it has no other home to be read from.
            -- No Toggle() here: it flips the window's own shown/hidden state,
            -- which the tests after this one rely on to stay in step (Toggle
            -- hiding the frame is what fires OnHide's hideResults for the
            -- "opens the whole list from the dropdown button" test right
            -- after this one). ApplyLayout has already run in this suite.
            local ROW = 18
            local ui = ns.Planner.Debug()
            local g = ns.Data.ArtGeometry.planner.wide
            local listHeight = (g.resultsList.bottom - g.resultsList.top) * ui.frame:GetHeight()
            -- Real numbers at 416px: (109.69 - 4) / 18 floors to 5.
            h.eq(ui.results.fit, 5, "5 rows fit the 416px-tall window's list")
            Fake.Type(ui.toBox, "a") -- matches more than fit in the fake world
            h.truthy(ui.results:IsShown())
            local shown, hidden = 0, 0
            for i, row in ipairs(ui.results.rows) do
                if row:IsShown() then
                    shown = shown + 1
                    local bottom = 2 + i * ROW -- TOPLEFT offset (2 + (i-1)*ROW) plus the row's own height
                    h.truthy(bottom <= listHeight,
                              "row " .. i .. " bottom edge must stay inside the list's own height")
                else
                    hidden = hidden + 1
                end
            end
            h.eq(shown, ui.results.fit, "exactly fit rows are shown")
            h.eq(shown + hidden, Planner.MAX_RESULTS)
            Fake.MouseDown(GoblinPSPlanner) -- put the list away for the test that follows
        end)

        h.it("opens the whole list from the dropdown button", function()
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.truthy(ui.dropdown, "the socket beside To has a control in it")
            Fake.Click(ui.dropdown)
            h.truthy(ui.results:IsShown(), "browsing needs no typing")
            Fake.Click(ui.dropdown)
            h.falsy(ui.results:IsShown(), "and clicking again puts it away")
        end)

        h.it("is the mockup: no From, no Here, no layout switch, no step list", function()
            local ui = Planner.Debug()
            h.eq(ui.fromBox, nil)
            h.eq(ui.here, nil)
            h.eq(ui.layoutButton, nil)
            h.eq(ui.side, nil)
            h.eq(ui.rows, nil)
            h.eq(Planner.MAX_ROWS, nil)
            h.eq(ns.Core.Layout, nil)
            h.eq(ns.Data.ArtGeometry.planner.tall, nil, "the tall geometry no longer ships")
            h.eq(ns.Data.Art["planner-frame-tall"], nil, "nor the tall frame")
            h.eq(ui.go.label:GetText(), "Start Route")
        end)

        h.it("shows the idle status lines before a destination is picked", function()
            -- Start Route, a few tests up, left a trip running, and a fresh
            -- window seeds its box from a running trip (plan 7). Hide the trip
            -- from it rather than end it: later tests expect it.
            local savedPlanner, savedDestination = ns.Planner, ns.Dash.Destination
            ns.Dash.Destination = function() return nil end
            local FreshPlanner = assert(loadfile("GoblinPS/Planner.lua"))("GoblinPS", ns)
            ns.Planner = savedPlanner
            FreshPlanner.Toggle()
            ns.Dash.Destination = savedDestination
            local ui, state = FreshPlanner.Debug()
            h.eq(state.to, nil, "a fresh window with no trip to show has no destination")
            h.truthy(ui.notes:IsShown())
            h.truthy(ui.known:IsShown())
            h.eq(ui.known:GetText(), "Flight paths known: 3")
            h.eq(ui.total:GetText(), "")
            h.falsy(ui.go.enabled)
            FreshPlanner.Toggle()
        end)
    end)

    h.describe("the route strip", function()
        local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"
        local amber, dim = ns.Widgets.COLOR.amber, ns.Widgets.COLOR.dim
        local function art(name) return MEDIA .. ns.Data.Art[name].file end
        local function pickTo(text)
            local ui = Planner.Debug()
            Fake.Type(ui.toBox, text)
            Fake.Click(ui.results.rows[1])
            return ui
        end
        local function track()
            local ui = Planner.Debug()
            local g, s = ns.Data.ArtGeometry.planner.wide, ns.Data.ArtGeometry.planner.strip
            local w, fh = ui.frame:GetWidth(), ui.frame:GetHeight()
            return { left = g.stripTrack.left * w, right = g.stripTrack.right * w,
                     cy = (g.stripTrack.top + g.stripTrack.bottom) / 2 * fh,
                     ring = s.nodeDiameter * w, thick = s.lineThickness * w }
        end
        local function near(a, b) return math.abs(a - b) < 0.01 end

        h.it("draws one badge per stop, wearing how you get there", function()
            if not Planner.Debug().frame:IsShown() then
                SlashCmdList.GOBLINPS("")
            end
            local ui = pickTo("delt")
            h.truthy(ui.strip:IsShown())
            local want = { "icon-horde", "icon-ride", "icon-flight", "icon-ride", "icon-zeppelin",
                           "node-destination" }
            for i, name in ipairs(want) do
                local b = ui.strip.badges[i]
                h.truthy(b and b:IsShown(), "badge " .. i)
                h.eq(b.art:GetTexture(), art(name), "badge " .. i)
            end
        end)

        h.it("puts each badge where the layout says, in real pixels", function()
            local ui, t = Planner.Debug(), track()
            for i = 1, 6 do
                local b = ui.strip.badges[i]
                local p = b.points[1]
                h.eq(p[1], "CENTER")
                h.truthy(p[2] == ui.frame, "measured from the window, which has a real size")
                h.truthy(near(p[4], t.left + (i - 1) / 5 * (t.right - t.left)), "badge " .. i .. " x")
                h.truthy(near(p[5], -t.cy), "badge " .. i .. " y")
                h.truthy(near(b:GetWidth(), t.ring * 1.5), "the sprite is 1.5 times the visible ring")
                h.eq(b:GetWidth(), b:GetHeight())
            end
        end)

        h.it("joins the stops with a solid first leg and dashed after, tiled not stretched", function()
            local ui, t = Planner.Debug(), track()
            local length = (t.right - t.left) / 5
            for i = 1, 5 do
                local line = ui.strip.legs[i].line
                local style = i == 1 and "line-solid" or "line-dashed"
                h.eq(line:GetTexture(), art(style), "leg " .. i)
                h.eq(line.wrapH, "REPEAT", "a dash keeps its length on any leg")
                local part = ns.Data.Art[style]
                h.truthy(near(line.texCoord[2], length / (t.thick * part.cw / part.ch)),
                         "one tile per line-box times the part's own aspect")
                h.truthy(near(line:GetWidth(), length))
                h.truthy(near(line:GetHeight(), t.thick))
                h.eq(line.points[1][1], "LEFT")
                h.truthy(line.points[1][2] == ui.frame, "measured from the window, which has a real size")
                h.truthy(near(line.points[1][4], t.left + (i - 1) * length), "starts at its badge's centre")
                h.truthy(near(line.points[1][5], -t.cy))
                local dot = ui.strip.legs[i].dot
                h.eq(dot:GetTexture(), art("line-dot"))
                h.eq(dot.points[1][1], "CENTER")
                h.truthy(dot.points[1][2] == ui.frame, "measured from the window, which has a real size")
                h.truthy(near(dot.points[1][4], t.left + (i - 0.5) * length), "the dot sits mid-leg")
                h.truthy(near(dot.points[1][5], -t.cy))
                h.truthy(near(dot:GetWidth(), t.thick), "the dot's width and height match the leg's thickness")
                h.truthy(near(dot:GetHeight(), t.thick))
            end
        end)

        h.it("draws the line under the badges and the strip above the screen's fills", function()
            local ui = Planner.Debug()
            h.truthy(ui.strip.legs[1].line.parent == ui.strip, "the line is the strip's own texture")
            h.truthy(ui.strip.badges[1].parent == ui.strip, "each badge is a child frame over it")
            h.truthy(ui.strip.badges[1]:GetFrameLevel() > ui.strip:GetFrameLevel())
            h.truthy(ui.strip.parent == ui.screen, "and the strip is a child of the opaque screen")
            h.truthy(ui.strip:GetFrameLevel() > ui.screen:GetFrameLevel())
        end)

        h.it("names the stops while there is room, each name bounded", function()
            local ui = Planner.Debug()
            h.eq(ui.strip.badges[1].label:GetText(), "You are here")
            h.eq(ui.strip.badges[2].label:GetText(), "Alpha")
            for i = 1, 6 do
                local label = ui.strip.badges[i].label
                h.truthy(label:IsShown(), "91.8 px between stops is more than two 39 px rings")
                h.eq(#label.points, 2, "two horizontal anchors, so it truncates")
                h.eq(label.wordWrap, false)
            end
        end)

        h.it("drops every name into the tooltips when the stops crowd", function()
            local ui, state = Planner.Debug()
            local saved = state.plan
            local steps = {}
            for i = 1, 8 do
                steps[i] = { kind = "ride", to = { name = "Stop " .. i }, seconds = 60, copper = 0 }
            end
            state.plan = { to = { name = "Stop 8" }, notes = {}, level = 60,
                           result = { steps = steps, seconds = 480, copper = 0 } }
            Planner.Refresh()
            for i = 1, 9 do
                h.truthy(ui.strip.badges[i]:IsShown(), "every stop still shows")
                h.falsy(ui.strip.badges[i].label:IsShown(), "57 px between stops: names go")
            end
            state.plan = saved
            Planner.Refresh()
            h.falsy(ui.strip.badges[7]:IsShown(), "a shorter route hides the spare badges")
            h.falsy(ui.strip.badges[7].label:IsShown())
            h.falsy(ui.strip.legs[6].line:IsShown(), "and the spare legs")
            h.falsy(ui.strip.legs[6].dot:IsShown())
        end)

        h.it("shows a stop's lines on hover and puts them away on leave", function()
            local ui = Planner.Debug()
            local b = ui.strip.badges[3]
            b.scripts.OnEnter(b)
            h.truthy(GameTooltip.owner == b)
            h.truthy(GameTooltip:IsShown())
            h.eq(GameTooltip.lines[1].text, "Fly to Bravo")
            h.eq(GameTooltip.lines[2].text, "~4 min")
            b.scripts.OnLeave(b)
            h.falsy(GameTooltip:IsShown())
        end)

        h.it("turns a hazard's detail amber and names it on the warning line", function()
            local ui = pickTo("hotel")
            local b = ui.strip.badges[2]
            b.scripts.OnEnter(b)
            h.eq(GameTooltip.lines[1].text, "Ride to the North Gate")
            h.eq(GameTooltip.lines[3].text, "into Northland · trolls on the bridge")
            h.eq(GameTooltip.lines[3].color[1], amber[1])
            h.eq(GameTooltip.lines[3].color[2], amber[2])
            h.eq(GameTooltip.lines[3].color[3], amber[3])
            local last = ui.strip.badges[3]
            last.scripts.OnEnter(last)
            h.eq(GameTooltip.lines[3].text, "in Northland · level 30-40")
            h.eq(GameTooltip.lines[3].color[1], dim[1], "level 60 in a 30-40 zone is no warning")
            GameTooltip:Hide()
            h.eq(ui.hint:GetText(), "the North Gate: into Northland · trolls on the bridge")
        end)

        h.it("wears the boot and says Walk for a low-level character", function()
            level = 1
            local ui = pickTo("hotel")
            local b = ui.strip.badges[2]
            h.eq(b.art:GetTexture(), art("icon-walk"))
            b.scripts.OnEnter(b)
            h.eq(GameTooltip.lines[1].text, "Walk to the North Gate")
            GameTooltip:Hide()
            level = 60
        end)

        h.it("says so on the tooltip when the crossings table has a hole", function()
            local ui = pickTo("lostland")
            local b = ui.strip.badges[2]
            b.scripts.OnEnter(b)
            h.eq(GameTooltip.lines[1].text, "Ride toward Lostland (no mapped path)")
            h.eq(#GameTooltip.lines, 2, "a straight line has no zone detail")
            GameTooltip:Hide()
        end)

        h.it("keeps a readable strip when a badge's art will not load", function()
            local ui = pickTo("delt")
            Fake.missingTextures[art("icon-flight")] = true
            Planner.Refresh()
            h.eq(ui.strip.badges[3].art:GetTexture(), art("node-ring"), "the plain ring stands in")
            Fake.missingTextures[art("node-ring")] = true
            Planner.Refresh()
            h.falsy(ui.strip.badges[3].art:IsShown())
            h.truthy(ui.strip.badges[3].flat:IsShown(), "and failing that, a flat marker")
            Fake.missingTextures[art("icon-flight")] = nil
            Fake.missingTextures[art("node-ring")] = nil
            Planner.Refresh()
            h.truthy(ui.strip.badges[3].art:IsShown())
            h.falsy(ui.strip.badges[3].flat:IsShown())
        end)

        h.it("draws no strip without a route", function()
            local ui = pickTo("westland")
            h.falsy(ui.strip:IsShown(), "you're already there: words, not a strip")
            h.truthy(ui.notes:IsShown())
            pickTo("delt")
            h.truthy(ui.strip:IsShown())
        end)

        h.it("hides the strip rather than error when the strip geometry is missing", function()
            -- I2: stripMetrics indexed ns.Data.ArtGeometry.planner.strip with no
            -- guard, so an Art.lua shipped without that table threw on every
            -- routed /gps open. A routed plan must instead leave the rest of
            -- the window working with the strip simply hidden.
            local ui = pickTo("delt")
            h.truthy(ui.strip:IsShown(), "a routed plan normally shows it")
            local savedStrip = ns.Data.ArtGeometry.planner.strip
            ns.Data.ArtGeometry.planner.strip = nil
            local ok, err = pcall(Planner.Refresh)
            h.truthy(ok, err)
            h.falsy(ui.strip:IsShown(), "no strip geometry: hide it, not the whole window")
            h.truthy(ui.frame:IsShown(), "the rest of the window keeps working")
            ns.Data.ArtGeometry.planner.strip = savedStrip
            Planner.Refresh()
            h.truthy(ui.strip:IsShown(), "restored geometry, restored strip")
        end)

        h.it("W.ShowTooltip colours every line after the first, amber for a warning", function()
            local owner = CreateFrame("Button", nil, UIParent)
            W.ShowTooltip(owner, { { text = "Ride to X" }, { text = "~2 min" },
                                   { text = "careful", amber = true } })
            h.eq(GameTooltip.anchor, "ANCHOR_TOP")
            h.eq(GameTooltip.lines[1].color, nil, "the first line keeps the tooltip's own title colour")
            h.eq(GameTooltip.lines[2].color[1], dim[1])
            h.eq(GameTooltip.lines[3].color[1], amber[1])
            GameTooltip:Hide()
        end)
    end)

    h.describe("ground steps in chat", function()
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

    h.describe("the login notice about flight paths", function()
        h.it("says nothing when flight paths are known", function()
            local from = #printed
            ns.Core.NoteFlightPaths()
            h.eq(#printed, from)
        end)
        h.it("tells a character with none to open a flight master's map", function()
            character = "Fresh-Test Realm"
            local from = #printed
            ns.Core.NoteFlightPaths()
            h.eq(#printed, from + 1)
            h.truthy(printed[#printed]:find("open any flight master's map", 1, true))
            character = "Tester-Test Realm"
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
        local MEDIA_STOP = "Interface\\AddOns\\GoblinPS\\Media\\dash2-stop"

        -- `build()` runs at most once per Dash module instance (guarded by
        -- `if not ui then build() end`), so proving a texture-load fallback
        -- needs a genuinely fresh copy of the module, not Stop/Start again on
        -- the shared one. Shared by every "missing texture" test below.
        local function freshDash()
            return assert(loadfile("GoblinPS/Dash.lua"))("GoblinPS", ns)
        end

        -- Marks `path` as a texture the fake will refuse to load, runs `fn`,
        -- and unmarks it afterward even if an assertion inside `fn` raises --
        -- otherwise a failure here would leave the flag stuck true for every
        -- "missing texture" test that runs after it. Shared by all three.
        local function withMissingTexture(path, fn)
            Fake.missingTextures[path] = true
            local ok, err = pcall(fn)
            Fake.missingTextures[path] = nil
            h.truthy(ok, err)
        end

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
                h.eq(ui.steps[1]:GetText(), "Ride to the North Gate")
                h.eq(ui.steps[2]:GetText(), "Zeppelin to East Dock")
            end)
            h.it("says nothing follows the last step", function()
                local ui, state = Dash.Debug()
                state.index = 3
                Dash.Refresh()
                h.eq(ui.steps[1]:GetText(), "Ride to Delta")
                h.eq(ui.steps[2]:GetText(), "", "nothing follows the last step")
                h.eq(ui.steps[3]:GetText(), "")
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
            -- Cross-multiplied so this is an exact check, not a tolerance:
            -- w/h2 == canvas.w/canvas.h without dividing at all.
            h.eq(w * g.canvas.h, h2 * g.canvas.w,
                 "the frame must keep the art's 1024x1280 aspect ratio exactly")
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
            -- These fill their parent rather than carrying a size, so the
            -- question only has an answer once the client has laid the frame
            -- out. Saying so here is the point: build() must never read one.
            Fake.Layout()
            for _, name in ipairs({ "glass", "stepsScreen", "etaScreen", "housing" }) do
                h.eq(ui[name]:GetWidth(), ui.frame:GetWidth(), name .. " must match the art layer")
                h.eq(ui[name]:GetHeight(), ui.frame:GetHeight(), name .. " must match the art layer")
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

        h.it("gives the device frame no regions of its own, so every rectangle can be hidden", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            -- A frame's own textures go wherever the frame goes: the only way
            -- to take one off screen is to hide the frame, and this frame must
            -- stay shown for the whole trip. So a texture laid directly on it
            -- is a rectangle nothing can ever remove -- brass down both edges
            -- of art that is 39.65% transparent. Same fault as the one seen in
            -- game on 2026-09-20 and fixed in 2d58322.
            h.eq(#ui.frame.regions, 0,
                 "the device frame must carry no texture of its own; art goes on a child frame")
            h.truthy(#ui.flat.regions > 0,
                     "the fallback colour lives on its own frame, which is what makes it hideable")
        end)

        h.it("sits all three step lines on the centre of their third of the art's steps box", function()
            -- Second design: "Walk to Undercity Zeppelin Tower" no longer
            -- gets one wrapping line -- the panel gives it a short line of
            -- its own, sized by the artist's box, so every line truncates
            -- instead.
            --
            -- Each line is hung on the vertical centre of its third, LEFT and
            -- RIGHT, not stretched corner to corner: a third of this box is
            -- about 21 px and the client's fonts decide their own height, so
            -- pinning top AND bottom would squeeze the text into a rect the
            -- artist drew as a line to sit on, not a box to fit in.
            Dash.Start(plan)
            local ui = Dash.Debug()
            local g = ns.Data.ArtGeometry
            local box, third = g.stepsText, (g.stepsText.bottom - g.stepsText.top) / 3
            local w, h2 = ui.frame:GetWidth(), ui.frame:GetHeight()
            for i, fs in ipairs(ui.steps) do
                h.eq(fs.wordWrap, false, "line " .. i .. " truncates; the box has no room to wrap")
                local left, right = fs.points[1], fs.points[2]
                h.eq(left[1], "LEFT", "line " .. i .. " hangs by its left edge")
                h.eq(right[1], "RIGHT", "line " .. i .. " hangs by its right edge")
                h.truthy(math.abs(left[4] - box.left * w) < 1, "line " .. i .. " starts at stepsText.left")
                h.truthy(math.abs(right[4] - box.right * w) < 1, "line " .. i .. " ends at stepsText.right")
                local middle = (box.top + third * (i - 0.5)) * h2
                h.truthy(math.abs(-left[5] - middle) < 1,
                         "line " .. i .. " sits on the centre of its third of stepsText")
                h.eq(left[5], right[5], "line " .. i .. " is level: one line, not a wedge")
            end
        end)

        h.it("sits the destination, distance and ETA on their own centre lines too", function()
            -- The artist named these `destination_line` and `distance_line`:
            -- they are 6.8 and 5.9 px tall on this device, so corner to
            -- corner would crush a 10 and a 16 px font into nothing. Same
            -- treatment as the step lines, from the same helper.
            Dash.Start(plan)
            local ui = Dash.Debug()
            local g = ns.Data.ArtGeometry
            local w, h2 = ui.frame:GetWidth(), ui.frame:GetHeight()
            for _, pair in ipairs({ { ui.destination, g.destination, "destination" },
                                    { ui.distance, g.distance, "distance" },
                                    { ui.eta, g.etaText, "eta" } }) do
                local fs, rect, name = pair[1], pair[2], pair[3]
                local left, right = fs.points[1], fs.points[2]
                h.eq(left[1], "LEFT", name .. " hangs by its left edge")
                h.eq(right[1], "RIGHT", name .. " hangs by its right edge")
                h.truthy(math.abs(left[4] - rect.left * w) < 1, name .. " starts at its rect's left")
                h.truthy(math.abs(right[4] - rect.right * w) < 1, name .. " ends at its rect's right")
                h.truthy(math.abs(-left[5] - (rect.top + rect.bottom) / 2 * h2) < 1,
                         name .. " sits on the centre of its own line, not inside a 7 px box")
                h.eq(left[5], right[5], name .. " is level")
            end
        end)

        h.it("every line of text is bounded", function()
                local ui = Dash.Debug()
                for _, name in ipairs({ "destination", "distance", "eta" }) do
                    local fs = ui[name]
                    h.truthy(fs.points and #fs.points >= 2,
                             name .. " needs two horizontal anchors or it will draw past the frame")
                end
                for i, fs in ipairs(ui.steps) do
                    h.truthy(fs.points and #fs.points >= 2,
                             "steps[" .. i .. "] needs two horizontal anchors or it will draw past the frame")
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
            h.it("does not open a new trip under the old one's banner", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                state.banner = "Recalculating..."
                Dash.Refresh()
                h.eq(ui.steps[2]:GetText(), "", "sanity: the banner takes the panel for its one tick")
                -- A second Start before the next tick used to keep that
                -- banner: the new trip opened announcing the old one's
                -- replan, with all three step lines blanked behind it.
                Dash.Start(plan)
                h.falsy(state.banner, "a new trip starts with no banner of its own")
                h.eq(ui.steps[1]:GetText(), "Ride to the North Gate")
                h.eq(ui.steps[2]:GetText(), "Zeppelin to East Dock",
                     "the new trip's directions, not a blanked panel")
                Dash.Stop()   -- leave it closed, as the test before this one did
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
                -- Sized by filling their parent, so this needs the layout pass.
                Fake.Layout()
                for _, name in ipairs({ "glass", "stepsScreen", "etaScreen", "housing" }) do
                    h.truthy(ui[name], name .. " is missing")
                    h.eq(ui[name]:GetWidth(), ui.frame:GetWidth(), name .. " must fill the device")
                    h.eq(ui[name]:GetHeight(), ui.frame:GetHeight(), name .. " must fill the device")
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
                local expect = ui.frame:GetWidth() * g.compassCrop.share
                h.truthy(math.abs(ui.compass:GetWidth() - expect) < 1,
                         "the compass is sized from geometry.compassCrop.share")
            end)

            h.it("centres the compass and the arrow on the dial, in real pixels", function()
                -- Seen in the client 2026-09-20: both sat up and to the left,
                -- clear off the device, because the offsets were computed from
                -- a frame sized by SetAllPoints -- which has no size until the
                -- client lays it out, so both multiplications gave 0 and the
                -- CENTER landed on the device's top-left corner. The sizes
                -- were right, because those alone were read from the frame
                -- with an explicit SetSize. Pin the position, not just the
                -- size: a test that checks how big a thing is cannot tell you
                -- it is in the wrong place.
                local g = ns.Data.ArtGeometry
                Dash.Start(plan)
                local ui = Dash.Debug()
                local w, h2 = ui.frame:GetWidth(), ui.frame:GetHeight()
                for _, name in ipairs({ "compass", "arrow" }) do
                    local pt = ui[name].points[1]
                    h.eq(pt[1], "CENTER", name .. " turns about its own middle")
                    h.eq(pt[3], "TOPLEFT", name .. " is offset from the device's corner")
                    h.truthy(math.abs(pt[4] - g.glass.cx * w) < 1,
                             name .. " sits at the dial's x, got " .. tostring(pt[4]))
                    h.truthy(math.abs(pt[5] + g.glass.cy * h2) < 1,
                             name .. " sits at the dial's y, got " .. tostring(pt[5]))
                end
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
                h.eq(ui.steps[1]:GetText(), "Zeppelin to East Dock")
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
                h.eq(ui.steps[1]:GetText(), "Arrived.")
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
                -- The arrow was already showing before this second Tick, so
                -- aimArrow no longer snaps it -- Steer does the turning now.
                Dash.Tick("tick")
                Dash.Steer(1)
                h.truthy(math.abs(ui.compass.rotation - 0.4) < 1e-4,
                     "flipping ROTATION_SIGN, the checklist's own remedy for the arrow, must flip the compass with it")
                ns.Trip.ROTATION_SIGN = saved
                facing = 0
            end)

            h.it("turns the arrow between ticks as you turn", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                standAt(-100, 0); facing = 0
                Dash.Tick("tick")
                h.eq(ui.arrow.rotation, 0, "first sight snaps exactly")
                facing = 0.5
                Dash.Steer(0.016)
                local target = ns.Trip.ArrowAngle(ns.Trip.Bearing(ns.Core.Here(), plan.result.steps[1].to), facing)
                h.truthy(ui.arrow.rotation < 0 and ui.arrow.rotation > target,
                         "one frame should move toward the target but not all the way, got "
                         .. tostring(ui.arrow.rotation))
                Dash.Steer(1)
                h.truthy(math.abs(ui.arrow.rotation - target) < 1e-4, "a full second lands on the target")
                facing = 0
            end)

            h.it("never spins the long way round", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                standAt(100, 0); facing = 0
                Dash.Tick("tick")
                h.eq(ui.arrow.rotation, math.pi, "the target sits due south of us, so the arrow starts near +pi")
                -- Swings the target to just past -pi -- the same physical
                -- direction, on the other side of the wrap.
                facing = 2 * math.pi - 0.01
                Dash.Steer(0.05)
                h.truthy(math.abs(ui.arrow.rotation - math.pi) < 0.5,
                         "one small step must not swing the arrow the long way round, got "
                         .. tostring(ui.arrow.rotation))
                facing = 0
            end)

            h.it("does not steer while the arrow is hidden or no trip runs", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                standAt(-100, 0); facing = 0
                Dash.Tick("tick")
                h.truthy(ui.arrow:IsShown(), "sanity: the arrow is up before we hide it")
                ui.arrow:Hide()
                local before = ui.arrow.rotation
                facing = 1.2   -- a different target; Steer must not chase it while hidden
                Dash.Steer(1)
                h.eq(ui.arrow.rotation, before, "steering does nothing while the arrow is hidden")
                facing = 0
                Dash.Stop()
                Dash.Steer(1)   -- must not error with no trip running and the dash hidden
                h.falsy(Dash.Debug().frame:IsShown())
            end)

            h.it("glides, not snaps, when a step advances", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                standAt(-5000, 0); facing = 0
                Dash.Tick("tick")
                h.eq(ui.arrow.rotation, 0, "sanity: first sight snaps to step 1's target, due north")
                standAt(-20, 20)
                Dash.Tick("tick")
                h.eq(state.index, 2, "sanity: arriving moved the step index on")
                h.eq(ui.arrow.rotation, 0, "sanity: the advance tick itself does not move the arrow")
                Dash.Steer(0.016)
                local target = ns.Trip.ArrowAngle(ns.Trip.Bearing(ns.Core.Here(), plan.result.steps[2].to), facing)
                h.truthy(ui.arrow.rotation < 0 and ui.arrow.rotation > target,
                         "one frame after the advance should ease toward the new step's target but not reach it,"
                         .. " got " .. tostring(ui.arrow.rotation))
                Dash.Steer(1)
                h.truthy(math.abs(ui.arrow.rotation - target) < 1e-4, "a full second lands on the new target")
                facing = 0
            end)

            h.it("snaps when it comes back after a pause", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                standAt(-100, 0); facing = 0
                Dash.Tick("tick")
                h.truthy(ui.arrow:IsShown(), "sanity: the arrow is up before the pause")
                where.map = nil
                Dash.Tick("tick")
                h.falsy(ui.arrow:IsShown(), "no position pauses the trip and hides the arrow")
                standAt(-100, 0)
                Dash.Tick("tick")
                h.truthy(ui.arrow:IsShown())
                local target = ns.Trip.ArrowAngle(ns.Trip.Bearing(ns.Core.Here(), plan.result.steps[1].to), facing)
                h.eq(ui.arrow.rotation, target,
                     "coming back after a pause snaps exactly onto the target, no Steer needed")
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
                h.eq(ui.steps[1]:GetText(), "Arrived.", "a replan with nothing left to do ends the trip")
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
                    h.truthy(ui.steps[1]:GetText():find("Recalculating", 1, true),
                              "the player must see the banner on the tick the stray is caught")

                    Dash.Tick("tick") -- the very next tick, position unchanged
                    h.falsy(ui.steps[1]:GetText():find("Recalculating", 1, true),
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
            h.it("stays off Escape's list, so Escape never ends a trip", function()
                -- Escape is pressed constantly: to close bags, clear a target,
                -- open the game menu. It used to close the dash and end the
                -- trip with it. The dash is a heads-up display, like the
                -- minimap, not a dialog.
                Dash.Start(plan)
                for _, name in ipairs(UISpecialFrames) do
                    h.truthy(name ~= "GoblinPSDash", "the dash must not be on Escape's list")
                end
                Dash.Stop()
            end)

            h.it("keeps the trip when the dash is hidden some other way", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                ui.frame:Hide()
                h.truthy(state.plan, "hiding is not stopping")
                -- But a hidden trip must not move on behind the player's back:
                -- standing on the first step's target would advance it.
                standAt(0, 0)
                Dash.Tick("tick")
                h.eq(state.index, 1, "nothing moves while the dash is hidden")
                ui.frame:Show()
                Dash.Tick("tick")
                h.eq(state.index, 2, "and it picks up again once shown")
                standAt(1000, 1100)
                Dash.Stop()
            end)

            h.it("ends the trip on Stop, clearing the saved trip and our pin", function()
                Dash.Start(plan)
                ns.Core.SaveTrip(plan.to)
                ns.Core.PinStep({ kind = "ride", to = { name = "Gate", map = 1, mx = 0.5, my = 0.5 } })
                Dash.Stop()
                local ui, state = Dash.Debug()
                h.falsy(state.plan)
                h.falsy(ui.frame:IsShown())
                h.eq(ns.Core.SavedTripName(), nil, "a stopped trip does not come back after a reload")
                h.eq(waypoint, nil, "our pin is cleared")
            end)

            h.it("clears our pin on arrival, and keeps saying Arrived", function()
                local oneStep = { level = 60, to = plan.to, result = { seconds = 60, steps = {
                    { kind = "ride", seconds = 60,
                      to = { name = "the North Gate", c = 1, x = 0, y = 0, map = 1, mx = 0.5, my = 0.5 } },
                } } }
                Dash.Start(oneStep)
                ns.Core.PinStep(oneStep.result.steps[1])
                standAt(0, 0)
                Dash.Tick("tick")
                local ui = Dash.Debug()
                h.eq(ui.steps[1]:GetText(), "Arrived.")
                h.truthy(ui.frame:IsShown(), "Arrived. stays up until Stop")
                h.eq(waypoint, nil, "the pin at the destination is cleared")
                standAt(1000, 1100)
                Dash.Stop()
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
            h.it("stacks the layers in the order the artist stated", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                -- images/parts/dash2-notes.md: "Draw glass, compass, existing
                -- arrow, steps insert, ETA insert, then housing." Within one
                -- frame only the draw layer decides that, and both inserts
                -- used to sit at BACKGROUND, under everything. Nothing
                -- overlaps today, so this is the only thing that would catch
                -- a redraw that widened either insert.
                local rank = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
                local order = { "glass", "compass", "arrow", "stepsScreen", "etaScreen" }
                local last = 0
                for _, name in ipairs(order) do
                    local layer = ui[name].drawLayer
                    h.truthy(rank[layer], name .. " must name a real draw layer, got " .. tostring(layer))
                    h.truthy(rank[layer] >= last, name .. " draws after the part before it")
                    last = rank[layer]
                end
                h.truthy(rank[ui.stepsScreen.drawLayer] > rank[ui.arrow.drawLayer],
                         "the inserts go over the arrow, not under the glass")
                h.truthy(ui.housingFrame:GetFrameLevel() > ui.artLayer:GetFrameLevel(),
                         "and the housing goes over all of them")
            end)

            h.it("reads the geometry even when no part table shipped with it", function()
                -- The two are separate files' worth of answer: the parts table
                -- says which textures exist, the geometry says where things
                -- go. Gating the second on the first dropped the whole layout
                -- to its unplaced fallback while a good geometry sat unread.
                Dash.Stop()
                local savedArt = ns.Data.Art
                ns.Data.Art = nil
                local ok, err = pcall(function()
                    local FreshDash = freshDash()
                    FreshDash.Start(plan)
                    local ui = FreshDash.Debug()
                    local g = ns.Data.ArtGeometry
                    local expect = ui.frame:GetWidth() * g.stop.r * 2
                    h.truthy(math.abs(ui.stop:GetWidth() - expect) < 2,
                             "the button is still placed from the geometry, not from the 20x20 fallback")
                    h.truthy(math.abs(ui.destination.points[1][4] - g.destination.left * ui.frame:GetWidth()) < 1,
                             "and so is every line of text")
                end)
                ns.Data.Art = savedArt
                h.truthy(ok, err)
            end)

            h.it("keeps a working device when a texture will not load", function()
                -- build() runs at most once per Dash module instance (guarded by
                -- `if not ui then build() end`), and the very first Dash.Start
                -- above already built the shared window while every texture
                -- loaded fine. Stop/Start again would rebuild nothing and
                -- exercise nothing new, so this uses freshDash() (defined at
                -- the top of this block) to genuinely drive a fresh build with
                -- a texture that fails.
                withMissingTexture("Interface\\AddOns\\GoblinPS\\Media\\dash2-housing", function()
                    local FreshDash = freshDash()
                    FreshDash.Start(plan)
                    local ui = FreshDash.Debug()
                    h.truthy(ui.frame:IsShown(), "a missing texture must not take the window with it")
                    h.truthy(ui.steps[1]:GetText() ~= "", "the directions must still be readable")
                    h.falsy(ui.housing, "a texture that would not load must not be laid over the colour")
                end)
            end)
            h.it("keeps the flat placeholder when the arrow's own texture will not load", function()
                -- The arrow is the one part with no colour behind it -- it
                -- IS the content -- so unlike dash2-housing (which just
                -- leaves ui.housing nil and the fallback panel showing), a
                -- failed arrow texture must leave WHITE8X8 in place, not the
                -- failed path SetTexture leaves behind on its own.
                withMissingTexture("Interface\\AddOns\\GoblinPS\\Media\\arrow", function()
                    local FreshDash = freshDash()
                    FreshDash.Start(plan)
                    local ui = FreshDash.Debug()
                    h.truthy(ui.frame:IsShown(), "a missing arrow texture must not take the window with it")
                    h.eq(ui.arrow:GetTexture(), "Interface\\Buttons\\WHITE8X8",
                         "a failed arrow texture must fall back to the flat placeholder")
                end)
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

        h.describe("the dash unit's words and stop button", function()
            h.it("puts the current step's name and distance on the glass", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                standAt(700, 0)
                Dash.Tick("tick")
                h.eq(ui.destination:GetText(), "the North Gate",
                     "the glass names what the arrow points at, not the journey's end")
                h.eq(ui.distance:GetText(), "700 yd")
            end)

            h.it("shows the step you are on and the next two", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                h.eq(ui.steps[1]:GetText(), "Ride to the North Gate")
                h.eq(ui.steps[2]:GetText(), "Zeppelin to East Dock")
                h.eq(ui.steps[3]:GetText(), "Ride to Delta")
                state.index = 3
                Dash.Refresh()
                h.eq(ui.steps[1]:GetText(), "Ride to Delta")
                h.eq(ui.steps[2]:GetText(), "", "nothing follows the last step")
                h.eq(ui.steps[3]:GetText(), "")
                state.index = 1
                Dash.Refresh()
            end)

            h.it("bounds every line it draws", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                local lines = { ui.destination, ui.distance, ui.eta, ui.steps[1], ui.steps[2], ui.steps[3] }
                for i, fs in ipairs(lines) do
                    h.truthy(fs.points and #fs.points >= 2,
                             "line " .. i .. " needs two horizontal anchors or it draws past the frame")
                end
            end)

            h.it("gives the stop button its three states and puts it in the socket", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                local g = ns.Data.ArtGeometry
                h.eq(ui.stop:GetWidth(), ui.stop:GetHeight(), "the button is round art on a square")
                local expect = ui.frame:GetWidth() * g.stop.r * 2
                h.truthy(math.abs(ui.stop:GetWidth() - expect) < 2, "sized from geometry.stop.r")
                h.truthy(ui.stopNormal, "the unpressed cap")
                h.truthy(ui.stopPressed, "the pushed cap")
            end)

            h.it("crops the hover cap exactly as it crops the other two", function()
                Dash.Start(plan)
                local ui = Dash.Debug()
                -- Every shipped part sits on a padded power-of-two canvas and
                -- needs its generated coordinates to crop that padding away.
                -- The hover cap used to be handed to SetHighlightTexture as a
                -- bare path, which is only right while its art happens to
                -- fill its canvas -- an accident of this one part's size.
                local part = ns.Data.Art["dash2-stop-hover"]
                h.truthy(ui.stopHover, "the hover cap is a texture we own, not a path we hand over")
                h.eq(ui.stopHover:GetTexture(), "Interface\\AddOns\\GoblinPS\\Media\\" .. part.file)
                h.eq(ui.stopHover.texCoord[1], part.l)
                h.eq(ui.stopHover.texCoord[2], part.r)
                h.eq(ui.stopHover.texCoord[4], part.b)
                h.eq(ui.stopHover.drawLayer, "HIGHLIGHT", "a highlight texture draws on the highlight layer")
            end)

            h.it("still ends the trip when the button is clicked", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                h.truthy(state.plan)
                Fake.Click(ui.stop)
                h.falsy(ui.frame:IsShown())
                h.falsy(state.plan, "clicking Stop ends the trip")
            end)

            h.it("keeps a usable button when its art will not load", function()
                Dash.Stop()
                withMissingTexture(MEDIA_STOP, function()
                    local FreshDash = freshDash()
                    FreshDash.Start(plan)
                    h.truthy(FreshDash.Debug().stop, "a missing texture must not lose the button")
                end)
            end)

            h.it("keeps the text legible when the generated geometry is absent", function()
                -- Every `if g then placeLine(...) end` block had no `else`: with
                -- no generated geometry, destination/distance/steps/eta got
                -- no anchors at all, so SetText succeeded but nothing drew --
                -- silently, since only the compass/arrow/dial/stop button had
                -- a fallback. Build with Data.Art and ArtGeometry both nil
                -- (as they are before tools/build_graph.py has ever run) and
                -- pin that all six still get two anchors apiece.
                Dash.Stop()
                local savedArt, savedGeometry = ns.Data.Art, ns.Data.ArtGeometry
                ns.Data.Art, ns.Data.ArtGeometry = nil, nil
                local ok, err = pcall(function()
                    local FreshDash = freshDash()
                    FreshDash.Start(plan)
                    local ui = FreshDash.Debug()
                    local lines = { ui.destination, ui.distance, ui.steps[1], ui.steps[2], ui.steps[3], ui.eta }
                    for i, fs in ipairs(lines) do
                        h.truthy(fs.points and #fs.points >= 2,
                                 "line " .. i .. " needs two anchors even with no generated geometry")
                        -- Counting anchors is not enough: two anchors that
                        -- name nothing to hang from bound nothing. Each one
                        -- must state a real frame AND the point on it, and
                        -- the pair must be a left edge and a right edge or
                        -- the line is not bounded horizontally at all.
                        for j, want in ipairs({ "LEFT", "RIGHT" }) do
                            local anchor = fs.points[j]
                            h.eq(type(anchor[2]), "table",
                                 "line " .. i .. " anchor " .. j .. " must hang from a real frame")
                            h.truthy(type(anchor[3]) == "string" and anchor[3]:match("%u"),
                                     "line " .. i .. " anchor " .. j .. " must name a point on that frame")
                            h.truthy(anchor[1]:find(want, 1, true) and anchor[3]:find(want, 1, true),
                                     "line " .. i .. " anchor " .. j .. " must be its " .. want .. " edge")
                        end
                    end
                end)
                ns.Data.Art, ns.Data.ArtGeometry = savedArt, savedGeometry
                h.truthy(ok, err)
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

        h.it("leaves a malformed Data.Art entry out of the texture list instead of crashing", function()
            -- shippedArt()'s guard `type(part) == "table" and part.file` exists
            -- because a malformed generated entry once took the WHOLE suite
            -- down with it, not just one test, when pairs() reached it (see
            -- SelfTest.lua's comment on ns.Data.ArtGeometry once being nested
            -- here by mistake). SelfTest.TEXTURES is built once, at load time,
            -- so reusing the shared instance would prove nothing; this loads
            -- a private copy against a namespace sharing the real ns.Data.Art
            -- plus one bad entry. The restore runs even if an assertion above
            -- fails, so a broken guard here cannot poison every test after it.
            ns.Data.Art.malformed = { l = 0, r = 1, t = 0, b = 1 } -- generated-looking, but no .file
            local ok, err = pcall(function()
                local tempNs = { Data = ns.Data }
                local FreshSelfTest = assert(loadfile("GoblinPS/SelfTest.lua"))("GoblinPS", tempNs)
                local sawGood = false
                for _, path in ipairs(FreshSelfTest.TEXTURES) do
                    h.falsy(path:find("malformed", 1, true),
                            "an entry with no .file must not reach the texture list")
                    if path:find("dash2%-housing") then
                        sawGood = true
                    end
                end
                h.truthy(sawGood, "sanity: a well-formed entry still made it in")
            end)
            ns.Data.Art.malformed = nil
            h.truthy(ok, err)
        end)
    end)

    h.describe("remembering flight paths", function()
        -- A reload as this client performs it: the account-wide save comes
        -- back through a real serialise-and-load, the per-character one does
        -- not come back at all.
        local function reload()
            local function copy(t)
                if type(t) ~= "table" then return t end
                local out = {}
                for k, v in pairs(t) do out[k] = copy(v) end
                return out
            end
            GoblinPSDB, GoblinPSCharDB = copy(GoblinPSDB), nil
        end

        h.it("learns at a flight master into the account-wide save, under this character", function()
            openNodes = { { nodeID = 3, name = "Gamma", flyable = true } }
            h.eq(#taxiCallbacks, 1, "Core listens for the flight master's map")
            taxiCallbacks[1]()
            openNodes = {}
            h.truthy(GoblinPSDB.known and GoblinPSDB.known[character] and GoblinPSDB.known[character][3],
                     "the new path is filed under this character in the account save")
            h.eq(ns.Core.KnownCount(), 4)
        end)

        h.it("still knows them after a reload that drops the per-character save", function()
            -- Seen in the client 2026-09-21: right after a reload the planner
            -- said "No flight paths yet" while the save on disk held two, and
            -- only a flight master's map brought them back -- because this
            -- build writes per-character saves and never loads them.
            reload()
            h.eq(ns.Core.KnownCount(), 4, "a reload must not forget what a flight master taught")
            h.eq(GoblinPSCharDB, nil, "and nothing relies on the per-character save coming back")
        end)

        h.it("keeps each character's flight paths apart", function()
            -- Discovery is per character in the game, so a new character on
            -- the same account knows none of the first one's paths.
            character = "Other-Test Realm"
            h.eq(ns.Core.KnownCount(), 0, "a second character starts with nothing")
            character = "Tester-Test Realm"
            h.eq(ns.Core.KnownCount(), 4, "and the first keeps its own")
            GoblinPSDB.known[character][3] = nil -- leave the fixture as the other tests found it
        end)
    end)

    h.describe("the trip in progress", function()
        local Core = ns.Core
        local step = { kind = "ride", to = { name = "Gate", map = 1, mx = 0.5, my = 0.5 } }
        -- These tests run at the end of the file, after tests that move the
        -- player, and `standAt` is local to the dash block, out of reach here.
        -- Anything that plans starts from where the file itself starts:
        -- beside Alpha, in Westland.
        local function home()
            where.map, where.mx, where.my = 1, 0.89, 0.9
        end

        h.it("clears the map pin it set", function()
            h.truthy(Core.PinStep(step))
            local before = waypointClears
            Core.ClearPin()
            h.eq(waypoint, nil, "our pin is gone")
            h.eq(waypointClears, before + 1)
        end)

        h.it("leaves a pin the player set in its place", function()
            -- A waypoint dropped mid-trip is the player's. Ending the trip
            -- must not take it with it.
            Core.PinStep(step)
            waypoint = { 9, 0.25, 0.75 }
            local before = waypointClears
            Core.ClearPin()
            h.eq(waypointClears, before, "the player's pin was not ours to clear")
            h.eq(waypoint[1], 9)
            waypoint = nil
        end)

        h.it("forgets the pin once cleared, so a second clear touches nothing", function()
            Core.PinStep(step)
            Core.ClearPin()
            waypoint = { 1, 0.5, 0.5 } -- the player puts one back on the very same spot
            local before = waypointClears
            Core.ClearPin()
            h.eq(waypointClears, before, "nothing of ours is left to clear")
            waypoint = nil
        end)

        h.it("saves the trip under this character, and only this one", function()
            Core.SaveTrip({ name = "Delta" })
            h.eq(Core.SavedTripName(), "Delta")
            h.eq(GoblinPSDB.trips[character].to, "Delta", "in the account-wide save")
            character = "Other-Test Realm"
            h.eq(Core.SavedTripName(), nil, "another character has no trip")
            character = "Tester-Test Realm"
            Core.ClearTrip()
            h.eq(Core.SavedTripName(), nil)
        end)

        h.it("saves the destination when a route starts", function()
            -- Start Route is the one deliberate way to change destination.
            home()
            local plan = ns.Core.PlanRoute(ns.Search.Exact(ns.Data, "Delta", "H"))
            h.truthy(plan.result and #plan.result.steps > 0, "sanity: a route to Delta")
            Core.Go(plan)
            h.eq(Core.SavedTripName(), "Delta")
            Core.ClearTrip()
            ns.Dash.Stop()
            Core.ClearPin()
        end)

        h.it("replaces a running trip's saved destination when Start Route runs again", function()
            -- The test above only proves SaveTrip from no trip running; the
            -- spec also asks that Start Route replace a trip already going.
            home()
            local first = ns.Core.PlanRoute(ns.Search.Exact(ns.Data, "Delta", "H"))
            h.truthy(first.result and #first.result.steps > 0, "sanity: a route to Delta")
            Core.Go(first)
            h.eq(Core.SavedTripName(), "Delta")

            local second = ns.Core.PlanRoute(ns.Search.Exact(ns.Data, "Bravo", "H"))
            h.truthy(second.result and #second.result.steps > 0, "sanity: a route to Bravo")
            Core.Go(second)
            h.eq(Core.SavedTripName(), "Bravo", "Start Route replaces the running trip's saved destination")

            Core.ClearTrip()
            ns.Dash.Stop()
            Core.ClearPin()
        end)

        local delta = ns.Search.Exact(ns.Data, "Delta", "H")

        -- A reload as this client performs it: the account-wide save comes
        -- back through a real serialise-and-load, the per-character one does
        -- not come back at all.
        local function reload()
            local function copy(t)
                if type(t) ~= "table" then return t end
                local out = {}
                for k, v in pairs(t) do out[k] = copy(v) end
                return out
            end
            GoblinPSDB, GoblinPSCharDB = copy(GoblinPSDB), nil
        end

        h.it("waits for a position before resuming, then plans from it", function()
            home()
            where.map = nil -- loading, or an instance: the client cannot say
            ns.Dash.Resume(delta)
            local ui, state = ns.Dash.Debug()
            h.truthy(ui.frame:IsShown(), "the dash comes back straight away")
            h.eq(ns.Dash.Destination(), delta)
            ns.Dash.Tick("tick")
            h.falsy(state.plan, "no position, no plan yet")
            home()
            ns.Dash.Tick("tick")
            h.truthy(state.plan, "planned from where you stand")
            h.eq(state.plan.to, delta)
            h.eq(state.index, 1)
            h.truthy(waypoint, "the first step is pinned")
            ns.Dash.Stop()
        end)

        h.it("clears the stale Waiting... when a resume's position has no route", function()
            -- M1 from the final review: tryResume's no-route branch wrote the
            -- "No route found" line into steps[1] but never cleared
            -- ui.distance, so "Waiting..." (set while the position was still
            -- unknown) stuck around until Stop. This fixture's rough-route
            -- fallback reaches every zone on its two continents, so there is
            -- no real destination it cannot plan to; stub Core.PlanRoute for
            -- this one test instead, and restore it straight after.
            home()
            Core.SaveTrip(delta)
            local calls, realPlanRoute = 0, ns.Core.PlanRoute
            ns.Core.PlanRoute = function()
                calls = calls + 1
                return { to = delta, notes = { "No route found to Delta." }, level = 60 }
            end

            where.map = nil -- loading, or an instance: the client cannot say
            ns.Dash.Resume(delta)
            ns.Dash.Tick("tick")
            local ui, state = ns.Dash.Debug()
            h.eq(ui.distance:GetText(), "Waiting...", "sanity: still waiting with no position")

            home() -- position known now; the stub still finds no route
            ns.Dash.Tick("tick")
            ns.Dash.Tick("tick")
            ns.Dash.Tick("tick")

            ns.Core.PlanRoute = realPlanRoute
            h.eq(calls, 1, "the planner is asked only once across several ticks")
            h.eq(ui.steps[1]:GetText(), "No route found to Delta.")
            h.eq(ui.distance:GetText(), "", "Waiting... must not outlive the no-route message")
            h.falsy(state.plan, "no plan is running")
            h.eq(Core.SavedTripName(), "Delta", "only Stop ends a trip")

            ns.Dash.Stop()
        end)

        h.it("shows Arrived when you resume at the destination", function()
            home()
            local westland = ns.Search.Exact(ns.Data, "Westland", "H")
            ns.Dash.Resume(westland) -- home() is in Westland
            ns.Dash.Tick("tick")
            local ui, state = ns.Dash.Debug()
            h.eq(ui.steps[1]:GetText(), "Arrived.")
            h.falsy(state.plan)
            ns.Dash.Stop()
        end)

        h.it("resumes this character's saved trip at login", function()
            home()
            Core.SaveTrip(delta)
            reload()
            Core.ResumeTrip()
            local trip = ns.Dash.Destination()
            h.eq(trip and trip.name, "Delta")
            ns.Dash.Tick("tick")
            local _, state = ns.Dash.Debug()
            h.truthy(state.plan, "the trip is running again")
            ns.Dash.Stop()
        end)

        h.it("resumes nothing for a character with no saved trip", function()
            Core.SaveTrip(delta)
            character = "Other-Test Realm"
            ns.Dash.Stop() -- as a fresh login finds it
            Core.ResumeTrip()
            local ui = ns.Dash.Debug()
            h.falsy(ui.frame:IsShown(), "another character's trip is not this one's")
            character = "Tester-Test Realm"
            Core.ClearTrip()
        end)

        h.it("drops a trip whose destination no longer exists, and says so", function()
            GoblinPSDB.trips[character] = { to = "Atlantis" }
            local from = #printed
            Core.ResumeTrip()
            h.eq(Core.SavedTripName(), nil, "the unresolvable trip is dropped")
            local said = table.concat(printed, "\n", from + 1, #printed)
            h.truthy(said:find("Couldn't resume your trip to Atlantis", 1, true),
                     "never silently")
        end)

        h.it("opens the planner on the running trip's destination", function()
            home()
            local _, pstate = ns.Planner.Debug()
            local pui = ns.Planner.Debug()
            if pui and pui.frame:IsShown() then ns.Planner.Toggle() end
            local keptTo = pstate and pstate.to
            if pstate then pstate.to = nil end
            ns.Dash.Resume(delta)
            ns.Planner.Toggle()
            pui, pstate = ns.Planner.Debug()
            h.eq(pstate.to, delta, "the planner shows where the trip is going")
            h.eq(pui.toBox:GetText(), "Delta")
            ns.Planner.Toggle()
            pstate.to = keptTo
            ns.Dash.Stop()
        end)
    end)

    print = realPrint
end

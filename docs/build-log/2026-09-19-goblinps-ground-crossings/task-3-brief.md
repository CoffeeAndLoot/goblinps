### Task 3: Level, chat details and two-line step rows

**Files:**
- Replace: `GoblinPS/API.lua`, `GoblinPS/Core.lua`, `GoblinPS/Planner.lua`, `GoblinPS/GoblinPS.toc`, `test/fake_frames.lua`, `test/test_ui.lua`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: `ns.API.Level() -> number or nil`; `Core.PlanRoute`'s answer gains `level`, and its options carry `speed` and `walk`; `/gps to` prints each ground step's detail line under it; planner rows gain `row.detail` (a second, smaller line, amber when `Route.StepDetail` says warn). `Planner.MAX_ROWS` is 8.

- [ ] **Step 1: Replace `test/fake_frames.lua`** (the fake now records the colour a FontString was given)

```lua
-- A tiny stand-in for the WoW frame API, enough to build the GoblinPS windows
-- on the desktop and poke at them. It proves OUR code paths run (no nil
-- calls, no bad field names, the right text lands in the right widget). It
-- proves nothing about how Blizzard's real frames behave: that is what
-- docs/manual-test-checklist.md is for.
local Fake = {}

-- Paths for which SetTexture below reports failure, the way a texture the
-- client cannot find would. Tests add and remove entries; empty by default.
Fake.missingTextures = {}

-- Real widget methods our code calls beyond the ones modelled as full
-- methods below, each checked against the client source. Anything else is a
-- misspelt or invented call, and the fake raises instead of quietly doing
-- nothing, so a bad widget call fails on the desktop instead of only in game.
local ALLOWED_NOOP = {
    SetAllPoints = true, SetColorTexture = true, SetTexCoord = true, SetAlpha = true,
    SetJustifyH = true, SetWordWrap = true, SetFontObject = true,
    SetTextInsets = true, SetMaxLetters = true, SetAutoFocus = true, EnableMouse = true,
    SetMovable = true, SetClampedToScreen = true, RegisterForDrag = true, RegisterForClicks = true,
    StartMoving = true, StopMovingOrSizing = true, SetFrameStrata = true, SetFrameLevel = true,
    SetHighlightTexture = true, RegisterEvent = true, SetOwner = true, AddLine = true,
}

local Region = {}
Region.__index = function(_, key)
    local method = Region[key]
    if method then
        return method
    end
    if ALLOWED_NOOP[key] then
        return function() end
    end
    -- Blizzard's own widget methods are always PascalCase (SetPoint,
    -- GetText, ...); anything shaped like one that we have not modelled or
    -- allow-listed is a misspelt or invented call, so raise. A lowercase key
    -- is the addon's own instance data (row.item, results.owner, ...), not
    -- yet set on this object: real frames answer that with plain nil too.
    if key:match("^%u") then
        error("fake_frames: unknown widget method '" .. key .. "'", 2)
    end
    return nil
end

local function new(kind, parent)
    return setmetatable({ kind = kind, parent = parent, shown = true, text = "", scripts = {}, points = {},
                          width = 0, height = 0 }, Region)
end

function Region:CreateTexture() return new("Texture", self) end
function Region:CreateFontString() return new("FontString", self) end
function Region:SetText(text) self.text = text or "" end
function Region:GetText() return self.text end
function Region:SetTextColor(r, g, b) self.color = { r, g, b } end
function Region:Show() self.shown = true end
function Region:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Region:SetShown(shown) self.shown = shown and true or false end
function Region:IsShown() return self.shown end
-- The real client answers from the cursor; tests set frame.mouseOver by hand.
function Region:IsMouseOver() return self.mouseOver == true end
function Region:SetScript(name, fn) self.scripts[name] = fn end
function Region:GetScript(name) return self.scripts[name] end
function Region:SetSize(w, h) self.width, self.height = w, h end
function Region:SetWidth(w) self.width = w end
function Region:SetHeight(h) self.height = h end
function Region:GetWidth() return self.width end
function Region:GetHeight() return self.height end
function Region:ClearAllPoints()
    self.points = {}
    self.lastPoint = nil
end

-- Normalises every SetPoint overload down to the five values the real
-- GetPoint returns (point, relativeTo, relativePoint, x, y), so a
-- save/restore round trip can be asserted the way the client really answers.
function Region:SetPoint(...)
    local n = select("#", ...)
    local point, relativeTo, relativePoint, x, y
    if n <= 1 then
        point = ...
        x, y = 0, 0
    elseif n == 2 then
        point, relativeTo = ...
        x, y = 0, 0
    elseif n == 3 then
        point, x, y = ...
    elseif n == 4 then
        point, relativeTo, x, y = ...
    else
        point, relativeTo, relativePoint, x, y = ...
    end
    local p = { point, relativeTo, relativePoint or point, x, y }
    self.points[#self.points + 1] = p
    self.lastPoint = p
end

-- Always the last point set, matching how the addon only ever keeps one
-- anchor (ClearAllPoints then a single SetPoint).
function Region:GetPoint()
    local p = self.lastPoint or { "CENTER", nil, "CENTER", 0, 0 }
    return p[1], p[2], p[3], p[4], p[5]
end

function Region:SetEnabled(enabled) self.enabled = enabled end

-- The real SetTexture returns a documented success bool.
function Region:SetTexture(path)
    self.texture = path
    return path ~= nil and not Fake.missingTextures[path]
end
function Region:GetTexture() return self.texture end
function Region:GetCenter() return 100, 100 end
function Region:GetEffectiveScale() return 1 end
function Region:ClearFocus()
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end

-- Test helpers: act like the player.
function Fake.Type(editBox, text)
    editBox:SetText(text)
    editBox.scripts.OnTextChanged(editBox, true)
end
function Fake.Click(button)
    button.scripts.OnClick(button, "LeftButton")
end
function Fake.MouseDown(frame)
    frame.scripts.OnMouseDown(frame, "LeftButton")
end

-- Installs the globals the UI files use. Returns a table of what was printed.
function Fake.Install()
    local printed = {}
    _G.CreateFrame = function(kind, name, parent)
        local f = new(kind, parent)
        if name then _G[name] = f end
        return f
    end
    _G.UIParent = new("Frame")
    _G.Minimap = new("Frame")
    _G.Minimap.width = 140
    _G.GameTooltip = new("GameTooltip")
    _G.UISpecialFrames = {}
    _G.GetCursorPosition = function() return 150, 100 end
    _G.SlashCmdList = {}
    _G.print = function(text) printed[#printed + 1] = text end
    Fake.missingTextures = {}
    return printed
end

return Fake
```

- [ ] **Step 2: Replace `test/test_ui.lua`**

```lua
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
    ns.API = {
        Faction = function() return "H" end,
        Level = function() return level end,
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

        h.it("shows an overflow row for a route longer than MAX_ROWS", function()
            local ui, state = Planner.Debug()
            local savedMax, savedPlan = Planner.MAX_ROWS, state.plan
            Planner.MAX_ROWS = 3
            local steps = {}
            for i = 1, 5 do
                steps[i] = { kind = "ride", to = { name = "Stop " .. i }, seconds = 60, copper = 0 }
            end
            state.plan = { to = { name = "Stop 5" }, notes = {}, result = { steps = steps, seconds = 300, copper = 0 } }
            Planner.Refresh()
            h.eq(ui.rows[3].left:GetText(), "... and 3 more steps")
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
            h.eq(ui.rows[1].detail:GetText(), "into Northland · level 30-40 · trolls on the bridge")
            h.eq(ui.rows[2].left:GetText(), "2. Ride to Hotel")
            h.eq(ui.rows[2].detail:GetText(), "in Northland · level 30-40")
            h.eq(ui.rows[3].detail:GetText(), "")
        end)
        h.it("turns the detail amber for a hazard and leaves it dim otherwise", function()
            local ui = Planner.Debug()
            h.eq(ui.rows[1].detail.color[1], amber[1])   -- the crossing carries a hazard note
            h.eq(ui.rows[2].detail.color[1], dim[1])     -- level 60 in a 30-40 zone
        end)
        h.it("says Walk and warns about the zone for a low-level character", function()
            level = 1
            local ui = pickTo("hotel")
            h.eq(ui.rows[1].left:GetText(), "1. Walk to the North Gate")
            h.eq(ui.rows[2].left:GetText(), "2. Walk to Hotel")
            h.eq(ui.rows[2].detail.color[1], amber[1])
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
```

- [ ] **Step 3: Run the Lua tests.** Expected: failures in the window suite (`attempt to call field 'Level'`, no `row.detail`). That is the RED.

- [ ] **Step 4: Replace `GoblinPS/API.lua`**

```lua
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

-- The character's level, or nil. Travel.For turns it into walk-or-ride.
function API.Level()
    return UnitLevel and UnitLevel("player") or nil
end

-- Every flight node the client lists, for /gps probe: { { nodeID, name }, ... }.
-- Its isUndiscovered flag is dead on build 1.60.1.69913 (false for every
-- node), so this says nothing about what the character has discovered.
function API.TaxiNodes()
    local out = {}
    if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then
        return out
    end
    for _, map in ipairs(CONTINENT_MAPS) do
        for _, info in ipairs(C_TaxiMap.GetTaxiNodesForMap(map) or {}) do
            out[#out + 1] = { nodeID = info.nodeID, name = info.name }
        end
    end
    return out
end

-- The nodes on the open flight master's map: { { nodeID, name, flyable } }.
-- This is the one moment the client tells the truth: flyable is true for the
-- node you stand at and every node you can fly to. Covers the current
-- continent only. Empty when no flight map is open.
function API.OpenTaxiNodes()
    local out = {}
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and Enum and Enum.FlightPathState) then
        return out
    end
    local getTaxiMapID = rawget(_G, "GetTaxiMapID")
    local map = (getTaxiMapID and getTaxiMapID()) or C_Map.GetBestMapForUnit("player")
    if not map then
        return out
    end
    for _, info in ipairs(C_TaxiMap.GetAllTaxiNodes(map) or {}) do
        out[#out + 1] = { nodeID = info.nodeID, name = info.name,
                          flyable = info.state ~= Enum.FlightPathState.Unreachable }
    end
    return out
end

-- Blizzard's own map pin plus the on-screen arrow. False when this client or
-- this map cannot take a pin.
function API.SetWaypoint(map, x, y)
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end
    if not (map and x and y) or (C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(map)) then
        return false
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    return true
end

-- Calls back once, when the character is in the world and saved variables
-- have loaded.
function API.OnLogin(callback)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN") -- verified in the forever source
    frame:SetScript("OnEvent", callback)
end

-- Calls back every time a flight master's map opens.
function API.OnTaxiMapOpened(callback)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TAXIMAP_OPENED") -- verified in the forever source and in game
    frame:SetScript("OnEvent", callback)
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

-- For /gps selftest: every client API this file leans on, and whether it is
-- there. { { name, present }, ... }
function API.SelfCheck()
    local checks = {
        { "C_TaxiMap.GetAllTaxiNodes", C_TaxiMap and C_TaxiMap.GetAllTaxiNodes },
        { "C_TaxiMap.GetTaxiNodesForMap", C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap },
        { "Enum.FlightPathState", Enum and Enum.FlightPathState },
        { "C_Map.GetBestMapForUnit", C_Map and C_Map.GetBestMapForUnit },
        { "C_Map.GetPlayerMapPosition", C_Map and C_Map.GetPlayerMapPosition },
        { "C_Map.SetUserWaypoint", C_Map and C_Map.SetUserWaypoint },
        { "UiMapPoint.CreateFromCoordinates", UiMapPoint and UiMapPoint.CreateFromCoordinates },
        { "C_SuperTrack.SetSuperTrackedUserWaypoint", C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint },
        { "C_Item.GetItemCooldown", C_Item and C_Item.GetItemCooldown },
        { "GetBindLocation", GetBindLocation },
        { "UnitFactionGroup", UnitFactionGroup },
        { "UnitLevel", UnitLevel },
    }
    local out = {}
    for i, check in ipairs(checks) do
        out[i] = { name = check[1], present = check[2] ~= nil and check[2] ~= false }
    end
    return out
end

return API
```

- [ ] **Step 5: Replace `GoblinPS/Core.lua`**

```lua
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

-- Plans a route to a place (from Search), from another place or, when from is
-- nil, from where the player stands. Always returns a table:
--   result  Route.Plan's answer, or nil
--   hint    Route.Hint's answer, or nil
--   notes   plain lines for the player; the last one explains a missing route
function Core.PlanRoute(to, from)
    local plan = { to = to, notes = {} }
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

    plan.level = API.Level()
    local travel = ns.Travel.For(plan.level)
    local opts = { faction = faction, known = known, from = from, to = to, hearth = bind,
                   speed = travel.speed, walk = travel.walk }
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
            say(i .. ". " .. Route.StepText(step))
            local detail, warn = Route.StepDetail(ns.Data, step, plan.level)
            if detail ~= "" then
                say("     " .. (warn and "|cfff0b54a" or "|cff9c8f6d") .. detail .. "|r")
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
    elseif command == "probe" then
        probe()
    elseif command == "selftest" then
        ns.SelfTest.Run(say)
    elseif command == "minimap" then
        ns.MinimapButton.SetHidden(not Core.MinimapPrefs().hide)
        say(Core.MinimapPrefs().hide and "Minimap button hidden. /gps minimap shows it again."
            or "Minimap button shown.")
    else
        say("/gps              open the planner")
        say("/gps to <place>   print a route in chat")
        say("/gps minimap      show or hide the minimap button")
        say("/gps probe        check the flight path data against the client")
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
```

- [ ] **Step 6: Replace `GoblinPS/Planner.lua`**

```lua
local _, ns = ...

-- The big device: From and To boxes, the green screen, the step list, the
-- total, the hint and Go. One set of widgets; ApplyLayout only moves them.
-- The schematic map and the dash unit arrive in later plans: for now the
-- screen shows what the device knows, and Go drops Blizzard's map pin on
-- the first step.
local Planner = {}
ns.Planner = Planner

local W = ns.Widgets

Planner.SIZE = { wide = { 660, 400 }, tall = { 390, 600 } }
Planner.MAX_ROWS = 8 -- each step is two lines: the step, then its detail
Planner.MAX_RESULTS = 8
local PAD, HEADER, INPUTS, FOOTER, ROW, STEP_ROW = 10, 30, 26, 64, 18, 32
-- The wide layout's screen keeps this share of the window width; plan 3 (the
-- schematic map) will revisit it once the map needs room too.
local SCREEN_SHARE = 0.42

local ui          -- built on first open
local state = {}  -- from = place or nil ("where you stand"), to = place, plan = Core.PlanRoute's answer

local function stepLine(i, step)
    local cost = ns.Route.FormatTime(step.seconds)
    if step.copper > 0 then
        cost = cost .. "  " .. ns.Route.FormatMoney(step.copper)
    end
    return i .. ". " .. ns.Route.StepText(step), cost
end

-- Paint whatever state.plan holds.
function Planner.Refresh()
    if not ui then
        return
    end
    local plan = state.plan
    local steps = plan and plan.result and plan.result.steps or {}
    for i = 1, Planner.MAX_ROWS do
        local row, step = ui.rows[i], steps[i]
        local left, right, detail, warn = "", "", "", false
        if step and i == Planner.MAX_ROWS and #steps > Planner.MAX_ROWS then
            left = "... and " .. (#steps - i + 1) .. " more steps"
        elseif step then
            left, right = stepLine(i, step)
            detail, warn = ns.Route.StepDetail(ns.Data, step, plan.level)
        end
        row.left:SetText(left)
        row.right:SetText(right)
        row.detail:SetText(detail)
        local c = W.COLOR[warn and "amber" or "dim"]
        row.detail:SetTextColor(c[1], c[2], c[3])
    end

    local total, hint, notes = "", "", ""
    if plan then
        notes = table.concat(plan.notes, "  ")
    end
    if plan and #steps > 0 then
        total = ns.Route.FormatTime(plan.result.seconds) .. "  " .. ns.Route.FormatMoney(plan.result.copper)
    end
    if plan and plan.hint then
        hint = ns.Route.HintText(plan.hint)
    end
    ui.total:SetText(total)
    ui.hint:SetText(hint)
    ui.notes:SetText(notes)
    W.SetButtonEnabled(ui.go, #steps > 0)

    local known = ns.Core.KnownCount()
    ui.known:SetText(known == 0 and "No flight paths yet: open a flight map."
        or ("Flight paths known: " .. known))
end

local function replan()
    state.plan = state.to and ns.Core.PlanRoute(state.to, state.from) or nil
    Planner.Refresh()
end

-- ---- the results list under whichever box has focus ----

local function hideResults()
    ui.results:Hide()
    ui.results.owner = nil
end

-- Puts the results list away and drops focus from both boxes: used wherever
-- clicking something other than a result row should end the search.
local function dismiss()
    ui.fromBox:ClearFocus()
    ui.toBox:ClearFocus()
    hideResults()
end

local function pick(box, item)
    hideResults()
    if box == ui.toBox then
        state.to = item
        ns.Core.Remember(item.name)
    else
        state.from = item
    end
    box:SetText(item.name)
    box:ClearFocus()
    W.UpdatePlaceholder(box)
    replan()
end

-- Matches for the text; with an empty To box, the recent destinations.
local function candidatesFor(box)
    local text = box:GetText()
    if text ~= "" then
        return ns.Search.Find(ns.Data, text, ns.Core.Faction(), Planner.MAX_RESULTS)
    end
    local out = {}
    if box == ui.toBox then
        for _, name in ipairs(ns.Core.Recents()) do
            out[#out + 1] = ns.Search.Exact(ns.Data, name, ns.Core.Faction())
        end
    end
    return out
end

local function showResults(box)
    local items = candidatesFor(box)
    if #items == 0 then
        hideResults()
        return
    end
    for i = 1, Planner.MAX_RESULTS do
        local row, item = ui.results.rows[i], items[i]
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            row.label:SetText(item.name .. (item.kind == "zone" and "" or "  (flight stop)"))
        end
    end
    ui.results.owner = box
    ui.results:ClearAllPoints()
    ui.results:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
    ui.results:SetSize(box:GetWidth(), math.min(#items, Planner.MAX_RESULTS) * ROW + 4)
    ui.results:Show()
end

local function wireBox(box)
    box:SetScript("OnTextChanged", function(self, userInput)
        W.UpdatePlaceholder(self)
        if userInput then
            showResults(self)
        end
    end)
    box:SetScript("OnEditFocusGained", showResults)
    box:SetScript("OnEditFocusLost", function(self)
        -- The client drops edit focus on mouse-down, before a click on a row
        -- completes. With the cursor on the list, leave it for that click.
        if ui.results.owner == self and not ui.results:IsMouseOver() then
            hideResults()
        end
    end)
    box:SetScript("OnEnterPressed", function(self)
        local first = candidatesFor(self)[1]
        if first then
            pick(self, first)
        else
            self:ClearFocus()
        end
    end)
    box:SetScript("OnEscapePressed", function(self)
        hideResults()
        self:ClearFocus()
    end)
end

-- ---- layout: the only thing that differs between wide and tall ----

function Planner.ApplyLayout(mode)
    if not ui then
        return
    end
    local size = Planner.SIZE[mode] or Planner.SIZE.wide
    local f = ui.frame
    f:SetSize(size[1], size[2])

    ui.screen:ClearAllPoints()
    ui.side:ClearAllPoints()
    local top = -(HEADER + INPUTS + PAD)
    if mode == "tall" then
        ui.screen:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, top)
        ui.screen:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, top)
        ui.screen:SetHeight(190)
        ui.side:SetPoint("TOPLEFT", ui.screen, "BOTTOMLEFT", 0, -PAD)
        ui.side:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
    else
        ui.screen:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, top)
        ui.screen:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
        ui.screen:SetWidth(math.floor(size[1] * SCREEN_SHARE))
        ui.side:SetPoint("TOPLEFT", ui.screen, "TOPRIGHT", PAD, 0)
        ui.side:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
    end
    ui.layoutButton.label:SetText(mode == "tall" and "Wide" or "Tall")
end

-- ---- construction ----

local function build()
    local f = W.Panel(UIParent, "body", "brass", 3)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        ns.Core.SavePosition("planner", point, relativePoint, x, y)
    end)
    f:SetScript("OnMouseDown", dismiss)
    f:Hide()

    local stripe = f:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", 3, -3)
    stripe:SetPoint("TOPRIGHT", -3, -3)
    stripe:SetHeight(4)
    stripe:SetColorTexture(W.COLOR.hazard[1], W.COLOR.hazard[2], W.COLOR.hazard[3], 1)

    local title = W.Text(f, "amber", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, -11)
    title:SetText("GoblinPS")
    local tagline = W.Text(f, "dim", "GameFontDisableSmall")
    tagline:SetPoint("LEFT", title, "RIGHT", 8, -1)
    tagline:SetText("Accuracy not guaranteed. No refunds.")

    local close = W.Button(f, "X", 20, 18, function()
        dismiss()
        f:Hide()
    end)
    close:SetPoint("TOPRIGHT", -PAD, -10)
    local layoutButton = W.Button(f, "Tall", 44, 18, function()
        dismiss()
        Planner.ApplyLayout(ns.Core.ToggleLayout())
    end)
    layoutButton:SetPoint("RIGHT", close, "LEFT", -6, 0)

    local fromBox = W.EditBox(f, 150, 20, "From: where you stand")
    fromBox:SetPoint("TOPLEFT", PAD, -(HEADER + 4))
    local toBox = W.EditBox(f, 170, 20, "To: city, zone or flight stop")
    toBox:SetPoint("LEFT", fromBox, "RIGHT", 6, 0)
    local here = W.Button(f, "Here", 40, 20, function()
        dismiss()
        state.from = nil
        ui.fromBox:SetText("")
        W.UpdatePlaceholder(ui.fromBox)
        replan()
    end)
    here:SetPoint("LEFT", toBox, "RIGHT", 6, 0)

    local screen = W.Panel(f, "screen", "steel", 2)
    local notes = W.Text(screen, "dim")
    notes:SetPoint("TOPLEFT", 8, -8)
    notes:SetPoint("TOPRIGHT", -8, -8)
    notes:SetWordWrap(true)
    local known = W.Text(screen, "green")
    known:SetPoint("BOTTOMLEFT", 8, 8)
    known:SetPoint("BOTTOMRIGHT", -8, 8)
    local device = W.Text(screen, "green", "GameFontNormalHuge", "CENTER")
    device:SetPoint("CENTER")
    device:SetText("GoblinPS")
    device:SetAlpha(0.25)

    local side = W.Panel(f, "steel", "steel", 1)
    local rows = {}
    for i = 1, Planner.MAX_ROWS do
        local row = { left = W.Text(side, "green"), right = W.Text(side, "dim", nil, "RIGHT"),
                      detail = W.Text(side, "dim", "GameFontDisableSmall") }
        row.left:SetPoint("TOPLEFT", 8, -(6 + (i - 1) * STEP_ROW))
        row.right:SetPoint("TOPRIGHT", -8, -(6 + (i - 1) * STEP_ROW))
        row.left:SetPoint("TOPRIGHT", row.right, "TOPLEFT", -6, 0)
        row.detail:SetPoint("TOPLEFT", 22, -(6 + (i - 1) * STEP_ROW + 14))
        row.detail:SetPoint("TOPRIGHT", -8, -(6 + (i - 1) * STEP_ROW + 14))
        rows[i] = row
    end
    local hint = W.Text(side, "amber")
    hint:SetPoint("BOTTOMLEFT", 8, FOOTER - 18)
    hint:SetPoint("BOTTOMRIGHT", -8, FOOTER - 18)
    local go = W.Button(side, "GO", 56, 24, function()
        dismiss()
        replan()
        ns.Core.Go(state.plan)
    end)
    go:SetPoint("BOTTOMRIGHT", -8, 8)
    local total = W.Text(side, "green", "GameFontNormal")
    total:SetPoint("BOTTOMLEFT", 8, 12)
    total:SetPoint("RIGHT", go, "LEFT", -8, 0)

    local results = W.Panel(f, "steel", "brass", 1)
    results:SetFrameStrata("DIALOG")
    results:EnableMouse(true)
    results:Hide()
    results.rows = {}
    for i = 1, Planner.MAX_RESULTS do
        local row = CreateFrame("Button", nil, results)
        row:SetHeight(ROW)
        row:SetPoint("TOPLEFT", 2, -(2 + (i - 1) * ROW))
        row:SetPoint("TOPRIGHT", -2, -(2 + (i - 1) * ROW))
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(row)
        hover:SetColorTexture(1, 1, 1, 0.15)
        row.label = W.Text(row, "green")
        row.label:SetPoint("LEFT", 6, 0)
        row.label:SetPoint("RIGHT", -6, 0)
        row:SetScript("OnClick", function(self) pick(results.owner, self.item) end)
        results.rows[i] = row
    end

    ui = { frame = f, fromBox = fromBox, toBox = toBox, screen = screen, side = side, rows = rows,
           hint = hint, total = total, go = go, here = here, known = known, results = results,
           layoutButton = layoutButton, notes = notes }
    wireBox(fromBox)
    wireBox(toBox)
    f:SetScript("OnHide", hideResults)
    ns.Core.CloseOnEscape(f, "GoblinPSPlanner")
end

function Planner.Toggle()
    if not ui then
        build()
        local p = ns.Core.Position("planner")
        ui.frame:ClearAllPoints()
        if p then
            ui.frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
        else
            ui.frame:SetPoint("CENTER")
        end
        Planner.ApplyLayout(ns.Core.Layout())
    end
    if ui.frame:IsShown() then
        ui.frame:Hide()
    else
        ui.frame:Show()
        replan()
    end
end

-- Called when something the route depends on changed (a flight path learned).
function Planner.Replan()
    if ui and ui.frame:IsShown() then
        replan()
    end
end

-- For the desktop smoke test only.
function Planner.Debug()
    return ui, state
end

return Planner
```

- [ ] **Step 7: Replace `GoblinPS/GoblinPS.toc`**

```
## Interface: 16001
## Title: GoblinPS
## Notes: Goblin Positioning System. The fastest route from where you stand. Accuracy not guaranteed. No refunds.
## Author: CoffeeAndLoot
## X-Website: https://github.com/CoffeeAndLoot/goblinps
## IconTexture: Interface\AddOns\GoblinPS\Media\icon
## Version: 2026.09.19.3
## SavedVariables: GoblinPSDB
## SavedVariablesPerCharacter: GoblinPSCharDB
## AddonCompartmentFunc: GoblinPS_OnAddonCompartmentClick

API.lua
Geo.lua
Data\Places.lua
Data\Nodes.lua
Data\Flights.lua
Data\Links.lua
Data\Inns.lua
Data\Crossings.lua
Data\Zones.lua
Travel.lua
Search.lua
Graph.lua
Route.lua
Trip.lua
Known.lua
Prefs.lua
Widgets.lua
Planner.lua
MinimapButton.lua
SelfTest.lua
Core.lua
```

- [ ] **Step 8: Run the Lua tests.** Expected: `160 passed, 0 failed`.

- [ ] **Step 9: Run luacheck** (`Total: 0 warnings / 0 errors`) **and the language server:**

```
lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json
```

Expected: `Diagnosis completed, no problems found`. Report anything else verbatim; do not change this plan's code to silence it.

- [ ] **Step 10: Commit**

```
git add GoblinPS/API.lua GoblinPS/Core.lua GoblinPS/Planner.lua GoblinPS/GoblinPS.toc test/fake_frames.lua test/test_ui.lua
git commit -m "Walk or ride by level; step details in chat and in the planner" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---


### Task 5: The window

One task because the pieces only run together: `Core` wires the planner, the minimap button and the self-test, and one smoke suite covers them all.

**Files:**
- Create: `GoblinPS/Widgets.lua`, `GoblinPS/Planner.lua`, `GoblinPS/MinimapButton.lua`, `GoblinPS/SelfTest.lua`, `test/fake_frames.lua`, `test/test_ui.lua`
- Replace: `GoblinPS/Core.lua`, `GoblinPS/GoblinPS.toc`, `test/run.lua`, `.luacheckrc`, `.luarc.json`
- Modify: `GoblinPS/API.lua`

**Interfaces:**
- Consumes: everything from Tasks 1-4 and plan 1.
- Produces:
  - `ns.API.SetWaypoint(map, x, y) -> bool`, `ns.API.OnLogin(callback)`, `ns.API.SelfCheck() -> { { name, present }, ... }`
  - `ns.Core.PlanRoute(to, from) -> { to, notes = { ... }, result = Route result or nil, hint = Route hint or nil }` (`from` nil means where the player stands), `ns.Core.Go(plan)`, and small accessors: `KnownCount`, `Faction`, `Recents`, `Remember`, `Layout`, `ToggleLayout`, `Position`, `SavePosition`, `MinimapPrefs`, `CloseOnEscape(frame, globalName)`, `Say`
  - `ns.Planner.Toggle()`, `ns.Planner.Replan()`, `ns.Planner.ApplyLayout(mode)`, `ns.Planner.Refresh()`, `ns.Planner.Debug() -> ui, state` (tests only)
  - `ns.MinimapButton.Initialize()`, `ns.MinimapButton.SetHidden(bool)`; `ns.SelfTest.Run(say) -> bool`
  - global `GoblinPS_OnAddonCompartmentClick`, saved variables `GoblinPSDB` (account) and `GoblinPSCharDB` (character)
  - slash: `/gps` opens the planner; `/gps to <place>`, `/gps minimap`, `/gps probe`, `/gps selftest`

- [ ] **Step 1: Write the fake frame library `test/fake_frames.lua`**

```lua
-- A tiny stand-in for the WoW frame API, enough to build the GoblinPS windows
-- on the desktop and poke at them. It proves OUR code paths run (no nil
-- calls, no bad field names, the right text lands in the right widget). It
-- proves nothing about how Blizzard's real frames behave: that is what
-- docs/manual-test-checklist.md is for.
local Fake = {}

local Region = {}
Region.__index = function(_, key)
    return Region[key] or function() end -- any method we did not model is a no-op
end

local function new(kind, parent)
    return setmetatable({ kind = kind, parent = parent, shown = true, text = "", scripts = {}, points = {},
                          width = 0, height = 0 }, Region)
end

function Region:CreateTexture() return new("Texture", self) end
function Region:CreateFontString() return new("FontString", self) end
function Region:SetText(text) self.text = text or "" end
function Region:GetText() return self.text end
function Region:Show() self.shown = true end
function Region:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Region:SetShown(shown) self.shown = shown and true or false end
function Region:IsShown() return self.shown end
function Region:SetScript(name, fn) self.scripts[name] = fn end
function Region:GetScript(name) return self.scripts[name] end
function Region:SetSize(w, h) self.width, self.height = w, h end
function Region:SetWidth(w) self.width = w end
function Region:SetHeight(h) self.height = h end
function Region:GetWidth() return self.width end
function Region:GetHeight() return self.height end
function Region:ClearAllPoints() self.points = {} end
function Region:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Region:GetPoint(i)
    local p = self.points[i or 1] or { "CENTER", nil, "CENTER", 0, 0 }
    return p[1], p[2], p[3], p[4] or 0, p[5] or 0
end
function Region:SetEnabled(enabled) self.enabled = enabled end
function Region:SetTexture(path) self.texture = path end
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
    return printed
end

return Fake
```

- [ ] **Step 2: Write the failing smoke test `test/test_ui.lua`**

```lua
-- Smoke test of the window code against test/fake_frames.lua. It catches our
-- own mistakes (nil calls, wrong fields, text in the wrong widget). Real frame
-- behaviour is checked in game from docs/manual-test-checklist.md.
return function(h)
    local Fake = dofile("test/fake_frames.lua")
    local realPrint = print
    local printed = Fake.Install()

    -- A private addon namespace over the fake world, with a scripted API.
    local ns = { Data = dofile("test/fake_world.lua")() }
    local where = { map = 1, mx = 0.89, my = 0.9 } -- world 1000, 1100: beside Alpha
    local pins, loginCallbacks = {}, {}
    ns.API = {
        Faction = function() return "H" end,
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
    for _, file in ipairs({ "Geo", "Search", "Graph", "Route", "Trip", "Known", "Prefs",
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

        h.it("remembers the destination and offers it when the box is empty", function()
            local ui = Planner.Debug()
            h.eq(GoblinPSDB.recents[1], "Delta")
            Fake.Type(ui.toBox, "")
            h.eq(ui.results.rows[1].label:GetText(), "Delta  (flight stop)")
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

        h.it("explains itself when it cannot tell where you are", function()
            local ui = Planner.Debug()
            where.map = nil
            Fake.Click(ui.here)
            h.eq(ui.rows[1].left:GetText(), "")
            h.eq(ui.total:GetText(), "Can't tell where you are. Inside an instance?")
            h.falsy(ui.go.enabled)
            where.map = 1
            Fake.Click(ui.here)
            h.truthy(ui.go.enabled)
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

- [ ] **Step 3: Replace `test/run.lua`**

```lua
-- Run from the repository root through lupa (see CLAUDE.md).
local harness = dofile("test/harness.lua")

-- Same (addonName, ns) the client passes, loaded in TOC order into one ns.
-- API.lua and Core.lua touch Blizzard globals, so they are not loaded here.
local modules = {
    { "Geo",     "GoblinPS/Geo.lua" },
    { "Places",  "GoblinPS/Data/Places.lua" },
    { "Nodes",   "GoblinPS/Data/Nodes.lua" },
    { "Flights", "GoblinPS/Data/Flights.lua" },
    { "Links",   "GoblinPS/Data/Links.lua" },
    { "Inns",    "GoblinPS/Data/Inns.lua" },
    { "Search",  "GoblinPS/Search.lua" },
    { "Graph",   "GoblinPS/Graph.lua" },
    { "Route",   "GoblinPS/Route.lua" },
    { "Trip",    "GoblinPS/Trip.lua" },
    { "Known",   "GoblinPS/Known.lua" },
    { "Prefs",   "GoblinPS/Prefs.lua" },
}

local ns = {}
local loaded = { ns = ns }
for i = 1, #modules do
    local name, path = modules[i][1], modules[i][2]
    local f = io.open(path, "r")
    if f then
        f:close()
        loaded[name] = assert(loadfile(path))("GoblinPS", ns)
    end
end

local suites = {
    "test/test_geo.lua",
    "test/test_search.lua",
    "test/test_graph.lua",
    "test/test_route.lua",
    "test/test_trip.lua",
    "test/test_known.lua",
    "test/test_prefs.lua",
    "test/test_ui.lua",
    "test/test_data.lua",
}

for i = 1, #suites do
    local f = io.open(suites[i], "r")
    if f then
        f:close()
        dofile(suites[i])(harness, loaded)
    end
end

os.exit(harness.run())
```

- [ ] **Step 4: Run the Lua tests.** Expected: an error from `test/test_ui.lua` while loading (`GoblinPS/Widgets.lua` does not exist). That is the RED.

- [ ] **Step 5: Add three functions to `GoblinPS/API.lua`.** Insert this block immediately before the comment line `-- Calls back every time a flight master's map opens.`:

```lua
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

```

And replace the final line `return API` with:

```lua
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
    }
    local out = {}
    for i, check in ipairs(checks) do
        out[i] = { name = check[1], present = check[2] ~= nil and check[2] ~= false }
    end
    return out
end

return API
```

- [ ] **Step 6: Write `GoblinPS/Widgets.lua`**

```lua
local _, ns = ...

-- Plain controls in the Goblin Gadget palette. No Blizzard frame templates on
-- purpose: a template renamed by a beta patch cannot break the window. Art
-- textures, when they exist, are laid over these flat colours; a missing
-- texture just leaves the colour showing.
local Widgets = {}
ns.Widgets = Widgets

Widgets.COLOR = {
    brass  = { 0.72, 0.53, 0.23 },
    body   = { 0.23, 0.18, 0.11 },
    steel  = { 0.11, 0.10, 0.08 },
    screen = { 0.03, 0.12, 0.06 },
    green  = { 0.44, 0.88, 0.54 },
    amber  = { 0.94, 0.71, 0.29 },
    hazard = { 0.88, 0.44, 0.11 },
    dim    = { 0.61, 0.56, 0.43 },
}

local function rgb(name)
    local c = Widgets.COLOR[name] or Widgets.COLOR.dim
    return c[1], c[2], c[3]
end

-- A flat colour filling the whole frame.
function Widgets.Fill(frame, layer, color, alpha)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(frame)
    local r, g, b = rgb(color)
    t:SetColorTexture(r, g, b, alpha or 1)
    return t
end

-- A frame with a one-pixel-style border: an outer fill and an inset fill.
function Widgets.Panel(parent, fill, border, inset)
    local f = CreateFrame("Frame", nil, parent)
    Widgets.Fill(f, "BACKGROUND", border or "steel")
    local inner = f:CreateTexture(nil, "BORDER")
    inner:SetPoint("TOPLEFT", inset or 2, -(inset or 2))
    inner:SetPoint("BOTTOMRIGHT", -(inset or 2), inset or 2)
    local r, g, b = rgb(fill)
    inner:SetColorTexture(r, g, b, 1)
    return f
end

function Widgets.Text(parent, color, fontObject, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
    fs:SetTextColor(rgb(color or "green"))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

function Widgets.Button(parent, text, width, height, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    Widgets.Fill(b, "BACKGROUND", "steel")
    local face = b:CreateTexture(nil, "BORDER")
    face:SetPoint("TOPLEFT", 1, -1)
    face:SetPoint("BOTTOMRIGHT", -1, 1)
    face:SetColorTexture(rgb("brass"))
    b.face = face
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(face)
    hover:SetColorTexture(1, 1, 1, 0.18)
    b.label = Widgets.Text(b, "steel", "GameFontNormalSmall", "CENTER")
    b.label:SetPoint("CENTER")
    b.label:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- Buttons go grey and stop answering clicks; SetEnabled exists on Button.
function Widgets.SetButtonEnabled(button, enabled)
    button:SetEnabled(enabled)
    local r, g, b = rgb(enabled and "brass" or "dim")
    button.face:SetColorTexture(r, g, b, 1)
end

function Widgets.EditBox(parent, width, height, placeholder)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width, height)
    e:SetAutoFocus(false)
    e:SetFontObject("GameFontHighlightSmall")
    e:SetTextInsets(6, 6, 0, 0)
    e:SetMaxLetters(60)
    Widgets.Fill(e, "BACKGROUND", "brass")
    local inner = e:CreateTexture(nil, "BORDER")
    inner:SetPoint("TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", -1, 1)
    inner:SetColorTexture(rgb("steel"))
    e.placeholder = Widgets.Text(e, "dim", "GameFontDisableSmall")
    e.placeholder:SetPoint("LEFT", 6, 0)
    e.placeholder:SetText(placeholder or "")
    e:SetScript("OnEscapePressed", e.ClearFocus)
    return e
end

-- Show the grey hint only while the box is empty.
function Widgets.UpdatePlaceholder(editBox)
    editBox.placeholder:SetShown(editBox:GetText() == "")
end

return Widgets
```

- [ ] **Step 7: Write `GoblinPS/Planner.lua`**

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
Planner.MAX_ROWS = 12
Planner.MAX_RESULTS = 8
local PAD, HEADER, INPUTS, FOOTER, ROW = 10, 30, 26, 64, 18

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
        local left, right = "", ""
        if step and i == Planner.MAX_ROWS and #steps > Planner.MAX_ROWS then
            left = "... and " .. (#steps - i + 1) .. " more steps"
        elseif step then
            left, right = stepLine(i, step)
        end
        row.left:SetText(left)
        row.right:SetText(right)
    end

    local total, hint = "", ""
    if plan and #steps > 0 then
        total = ns.Route.FormatTime(plan.result.seconds) .. "  " .. ns.Route.FormatMoney(plan.result.copper)
    elseif plan then
        total = plan.notes[#plan.notes] or ""
    end
    if plan and plan.hint then
        hint = ns.Route.HintText(plan.hint)
    end
    ui.total:SetText(total)
    ui.hint:SetText(hint)
    W.SetButtonEnabled(ui.go, #steps > 0)

    local known = ns.Core.KnownCount()
    ui.known:SetText(known == 0 and "No flight paths learned yet. Open a flight master's map."
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
        ui.screen:SetWidth(math.floor(size[1] * 0.56))
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
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        ns.Core.SavePosition("planner", point, x, y)
    end)
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

    local close = W.Button(f, "X", 20, 18, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", -PAD, -10)
    local layoutButton = W.Button(f, "Tall", 44, 18, function()
        Planner.ApplyLayout(ns.Core.ToggleLayout())
    end)
    layoutButton:SetPoint("RIGHT", close, "LEFT", -6, 0)

    local fromBox = W.EditBox(f, 150, 20, "From: where you stand")
    fromBox:SetPoint("TOPLEFT", PAD, -(HEADER + 4))
    local toBox = W.EditBox(f, 170, 20, "To: city, zone or flight stop")
    toBox:SetPoint("LEFT", fromBox, "RIGHT", 6, 0)
    local here = W.Button(f, "Here", 40, 20, function()
        state.from = nil
        ui.fromBox:SetText("")
        W.UpdatePlaceholder(ui.fromBox)
        replan()
    end)
    here:SetPoint("LEFT", toBox, "RIGHT", 6, 0)

    local screen = W.Panel(f, "screen", "steel", 2)
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
        local row = { left = W.Text(side, "green"), right = W.Text(side, "dim", nil, "RIGHT") }
        row.left:SetPoint("TOPLEFT", 8, -(6 + (i - 1) * ROW))
        row.right:SetPoint("TOPRIGHT", -8, -(6 + (i - 1) * ROW))
        row.left:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
        rows[i] = row
    end
    local hint = W.Text(side, "amber")
    hint:SetPoint("BOTTOMLEFT", 8, FOOTER - 18)
    hint:SetPoint("BOTTOMRIGHT", -8, FOOTER - 18)
    local total = W.Text(side, "green", "GameFontNormal")
    total:SetPoint("BOTTOMLEFT", 8, 12)
    local go = W.Button(side, "GO", 56, 24, function() ns.Core.Go(state.plan) end)
    go:SetPoint("BOTTOMRIGHT", -8, 8)

    local results = W.Panel(f, "steel", "brass", 1)
    results:SetFrameStrata("DIALOG")
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
           layoutButton = layoutButton }
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
            ui.frame:SetPoint(p.point, UIParent, p.point, p.x, p.y)
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

- [ ] **Step 8: Write `GoblinPS/MinimapButton.lua`**

```lua
local _, ns = ...

-- A draggable button on the minimap's ring; click opens the planner. Hand
-- rolled like HealMe's (no LibDBIcon). The angle and the hidden flag live in
-- the account-wide preferences.
local MinimapButton = {}
ns.MinimapButton = MinimapButton

local ICON = "Interface\\AddOns\\GoblinPS\\Media\\icon"

local button

-- From the minimap's real size: a fixed radius of 80 is right only for the
-- default 140px minimap and lands inside a resized one.
local function ringRadius()
    local width = Minimap:GetWidth()
    if not width or width <= 0 then
        width = 140
    end
    return (width / 2) + 10
end

local function place()
    if not button then
        return
    end
    local angle = math.rad(ns.Core.MinimapPrefs().angle)
    local radius = ringRadius()
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function angleFromCursor()
    local mx, my = Minimap:GetCenter()
    if not mx then
        return nil
    end
    local scale = Minimap:GetEffectiveScale()
    local px, py = GetCursorPosition()
    return math.deg(math.atan2(py / scale - my, px / scale - mx))
end

local function whileDragging()
    local angle = angleFromCursor()
    if angle then
        ns.Core.MinimapPrefs().angle = angle
        place()
    end
end

local function showTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("GoblinPS")
    GameTooltip:AddLine("Click to open the planner.", 1, 1, 1)
    GameTooltip:AddLine("Drag to move this button.", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("May explode.", 0.88, 0.44, 0.11)
    GameTooltip:Show()
end

local function build()
    local b = CreateFrame("Button", "GoblinPSMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- trim so a square icon reads as round in the ring

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    b:SetScript("OnClick", function() ns.Planner.Toggle() end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", whileDragging)
        GameTooltip:Hide()
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", showTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Call once at PLAYER_LOGIN, when the minimap and saved variables exist.
function MinimapButton.Initialize()
    if button or not Minimap then
        return
    end
    button = build()
    place()
    button:SetShown(not ns.Core.MinimapPrefs().hide)

    -- The minimap can be resized in Edit Mode or by a UI scale change.
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:SetScript("OnEvent", place)
end

function MinimapButton.SetHidden(hidden)
    ns.Core.MinimapPrefs().hide = hidden and true or false
    if button then
        button:SetShown(not hidden)
    end
end

return MinimapButton
```

- [ ] **Step 9: Write `GoblinPS/SelfTest.lua`**

```lua
local _, ns = ...

-- /gps selftest: checks, in the real client, the few things the window leans
-- on that a beta patch could take away. The window uses no Blizzard frame
-- templates, so this is fonts, stock textures, our own art and the APIs
-- (API.SelfCheck lists those, since only API.lua touches game APIs).
local SelfTest = {}
ns.SelfTest = SelfTest

SelfTest.FONTS = {
    "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge", "GameFontNormalHuge",
    "GameFontHighlightSmall", "GameFontDisableSmall",
}
SelfTest.TEXTURES = {
    "Interface\\AddOns\\GoblinPS\\Media\\icon",
    "Interface\\Minimap\\MiniMap-TrackingBorder",
    "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
}
local COLOUR = { pass = "|cff6fe08aok|r  ", fail = "|cffe0501cFAIL|r" }

-- A texture that failed to load reports no file; GetTexture is nil then.
local function textureLoads(probe, path)
    probe:SetTexture(nil)
    probe:SetTexture(path)
    return probe:GetTexture() ~= nil
end

function SelfTest.Run(say)
    local failed = 0
    local function report(ok, text)
        if not ok then
            failed = failed + 1
        end
        say(COLOUR[ok and "pass" or "fail"] .. " " .. text)
    end

    for _, name in ipairs(SelfTest.FONTS) do
        report(_G[name] ~= nil, "font " .. name)
    end
    local holder = CreateFrame("Frame")
    local probe = holder:CreateTexture()
    for _, path in ipairs(SelfTest.TEXTURES) do
        report(textureLoads(probe, path), "texture " .. path)
    end
    for _, check in ipairs(ns.API.SelfCheck()) do
        report(check.present, "api " .. check.name)
    end
    report(ns.Core.KnownCount() >= 0, "flight paths learned: " .. ns.Core.KnownCount())

    say(failed == 0 and "Self-test passed." or ("Self-test: " .. failed .. " failed."))
    return failed == 0
end

return SelfTest
```

- [ ] **Step 10: Replace `GoblinPS/Core.lua`**

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
function Core.SavePosition(window, point, x, y) Prefs.SavePosition(prefs(), window, point, x, y) end
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

    local opts = { faction = faction, known = known, from = from, to = to, hearth = bind }
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

- [ ] **Step 11: Replace `GoblinPS/GoblinPS.toc`**

```
## Interface: 16001
## Title: GoblinPS
## Notes: Goblin Positioning System. The fastest route from where you stand. Accuracy not guaranteed. No refunds.
## Author: CoffeeAndLoot
## X-Website: https://github.com/CoffeeAndLoot/goblinps
## IconTexture: Interface\AddOns\GoblinPS\Media\icon
## Version: 2026.09.19.2
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

- [ ] **Step 12: Replace `.luacheckrc`**

```lua
std = "lua51"
max_line_length = 120
self = false
globals = {
    "SLASH_GOBLINPS1", "SlashCmdList", "GoblinPSDB", "GoblinPSCharDB",
    "GoblinPS_OnAddonCompartmentClick", "UISpecialFrames",
}
read_globals = {
    "print",
    "UnitFactionGroup", "GetBindLocation",
    "C_TaxiMap", "C_Map", "C_Item", "C_SuperTrack", "UiMapPoint",
    "CreateFrame", "Enum",
    "UIParent", "Minimap", "GameTooltip", "GetCursorPosition",
}
files["GoblinPS/Data/Places.lua"] = { max_line_length = false }
files["GoblinPS/Data/Nodes.lua"] = { max_line_length = false }
files["GoblinPS/Data/Flights.lua"] = { max_line_length = false }
-- The UI smoke test installs a fake frame API into the globals.
files["test/fake_frames.lua"] = { globals = { "print" } }
files["test/test_ui.lua"] = { globals = { "print" }, read_globals = { "GoblinPSMinimapButton" } }
```

- [ ] **Step 13: Replace `.luarc.json`**

```json
{
  "runtime.version": "Lua 5.1",
  "workspace.ignoreDir": [".remember", ".superpowers", "tools", "docs"],
  "diagnostics.globals": [
    "SLASH_GOBLINPS1", "SlashCmdList", "GoblinPSDB", "GoblinPSCharDB",
    "GoblinPS_OnAddonCompartmentClick", "UISpecialFrames", "GoblinPSMinimapButton",
    "UnitFactionGroup", "GetBindLocation",
    "C_TaxiMap", "C_Map", "C_Item", "C_SuperTrack", "UiMapPoint",
    "CreateFrame", "Enum",
    "UIParent", "Minimap", "GameTooltip", "GetCursorPosition"
  ]
}
```

- [ ] **Step 14: Run the Lua tests.** Expected: `103 passed, 0 failed`.

- [ ] **Step 15: Run luacheck** (`Total: 0 warnings / 0 errors`) **and the language server:**

```
lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json
```

Expected: `Diagnosis completed, no problems found`. Report anything else verbatim; do not "fix" code from this plan to silence it.

- [ ] **Step 16: Commit**

```
git add GoblinPS test .luacheckrc .luarc.json
git commit -m "Add the planner window, minimap button, compartment entry and self-test" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---


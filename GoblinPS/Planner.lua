local _, ns = ...

-- The big device: From and To boxes, the green screen, the step list, the
-- total, the hint and Go. One set of widgets; ApplyLayout only moves them.
-- The schematic map and the dash unit arrive in later plans: for now the
-- screen shows what the device knows, and Go drops Blizzard's map pin on
-- the first step.
local Planner = {}
ns.Planner = Planner

local W = ns.Widgets

-- The window's rectangle on screen. The art is 1600x1024 and 1024x1600, so
-- these keep those shapes exactly; everything inside is placed as a fraction
-- of them, from the geometry the art tool generates. Nothing here is a
-- measured guess.
Planner.SIZE = { wide = { 650, 416 }, tall = { 384, 600 } }
Planner.MAX_ROWS = 8 -- each step is two lines: the step, then its detail
Planner.MAX_RESULTS = 8
local PAD, HEADER, FOOTER, ROW, STEP_ROW = 10, 30, 64, 18, 32

local ui          -- built on first open
local state = {}  -- from = place or nil ("where you stand"), to = place, plan = Core.PlanRoute's answer

local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"

-- The active layout's geometry, or nil when the generated table is absent.
-- Gated on the geometry alone: whether the parts shipped is a different
-- question, and answering it here would drop the whole layout to its fallback
-- while a perfectly good geometry sat there unread.
local function geo(mode)
    local g = ns.Data.ArtGeometry and ns.Data.ArtGeometry.planner
    return g and g[mode or ns.Core.Layout()]
end

-- Lay a shipped part over `parent`, cropping the power-of-two padding away.
-- Returns nil when the part is missing or the texture will not load, and every
-- caller uses that: a missing texture must leave a working window.
local function art(parent, name, layer)
    local part = ns.Data.Art and ns.Data.Art[name]
    if not part then
        return nil
    end
    local t = parent:CreateTexture(nil, layer)
    if not t:SetTexture(MEDIA .. part.file) then
        t:Hide()
        return nil
    end
    t:SetTexCoord(part.l, part.r, part.t, part.b)
    t:SetAllPoints(parent)
    return t
end

local function stepLine(i, step)
    local cost = ns.Route.FormatTime(step.seconds)
    if step.copper > 0 then
        cost = cost .. "  " .. ns.Route.FormatMoney(step.copper)
    end
    return i .. ". " .. ns.Route.StepText(step), cost
end

-- Paint whatever state.plan holds. A route longer than MAX_ROWS shows its
-- first MAX_ROWS-2 steps, then an overflow row, then the FINAL step (with
-- its own detail) in the last row: the arrival must always be visible.
function Planner.Refresh()
    if not ui then
        return
    end
    local plan = state.plan
    local level = plan and plan.level or nil
    local steps = plan and plan.result and plan.result.steps or {}
    local overflow = #steps > Planner.MAX_ROWS
    local headCount = overflow and (Planner.MAX_ROWS - 2) or Planner.MAX_ROWS
    for i = 1, Planner.MAX_ROWS do
        local row = ui.rows[i]
        local left, right, detail, warn = "", "", "", false
        local step, number
        if overflow and i == Planner.MAX_ROWS - 1 then
            left = "... and " .. (#steps - headCount - 1) .. " more steps"
        elseif overflow and i == Planner.MAX_ROWS then
            step, number = steps[#steps], #steps
        elseif i <= headCount and steps[i] then
            step, number = steps[i], i
        end
        if step then
            left, right = stepLine(number, step)
            detail, warn = ns.Route.StepDetail(ns.Data, step, level)
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
    mode = (mode == "tall") and "tall" or "wide"
    local size = Planner.SIZE[mode]
    local f = ui.frame
    -- The explicit size first, before anything reads it: every helper below
    -- measures this frame, and a frame with no size measures 0.
    f:SetSize(size[1], size[2])

    local part = ns.Data.Art and ns.Data.Art["planner-frame-" .. mode]
    if part and ui.frameArt:SetTexture(MEDIA .. part.file) then
        ui.frameArt:SetTexCoord(part.l, part.r, part.t, part.b)
        ui.frameArt:Show()
        ui.flat:Hide()
    else
        ui.frameArt:Hide()
        ui.flat:Show()
    end

    local g = geo(mode)
    if g then
        if ui.titlePlate then
            W.PlaceRect(ui.titlePlate, f, g.titlePlate)
        end
        if ui.taglinePlate then
            W.PlaceRect(ui.taglinePlate, f, g.taglinePlate)
        end
        W.PlaceLine(ui.title, f, g.titlePlate)
        W.PlaceLine(ui.tagline, f, g.taglinePlate)
        W.PlaceCircle(ui.close, f, g.closeButton)
        W.PlaceCircle(ui.gear, f, g.gearButton)
        W.PlaceCircle(ui.dropdown, f, g.dropdownButton)
        W.PlaceRect(ui.layoutButton, f, g.layoutButton)
    end

    ui.layoutButton.label:SetText(mode == "tall" and "Wide" or "Tall")
end

-- ---- construction ----

local function build()
    -- Bare on purpose. A texture created on this frame could only be taken off
    -- screen by hiding the frame, and the window art has transparent margins,
    -- so an unhideable rectangle behind it boxes in a window that is not a
    -- rectangle. The dash unit shipped that fault once already.
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(Planner.SIZE.wide[1], Planner.SIZE.wide[2])
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

    local base = f:GetFrameLevel()

    -- The flat colour is the fallback for art that will not load. It is its
    -- own frame so it can be hidden as a unit the moment the real frame art
    -- arrives.
    local flat = W.Panel(f, "body", "brass", 3)
    flat:SetAllPoints(f)
    flat:SetFrameLevel(base)

    local artLayer = CreateFrame("Frame", nil, f)
    artLayer:SetAllPoints(f)
    artLayer:SetFrameLevel(base + 1)

    local content = CreateFrame("Frame", nil, f)
    content:SetAllPoints(f)
    content:SetFrameLevel(base + 2)

    -- The window's own chassis. ApplyLayout swaps the texture between the two
    -- frames, so create it empty here and let ApplyLayout fill it.
    local frameArt = artLayer:CreateTexture(nil, "BACKGROUND")
    frameArt:SetAllPoints(artLayer)

    -- The plates carry art but are NOT SetAllPoints to their parent: each sits
    -- in its own rect, which ApplyLayout places. That is the one difference
    -- from `art()` above, and it is why they cannot use it.
    local function plate(name)
        local part = ns.Data.Art and ns.Data.Art[name]
        if not part then
            return nil
        end
        local t = artLayer:CreateTexture(nil, "ARTWORK")
        if not t:SetTexture(MEDIA .. part.file) then
            t:Hide()
            return nil
        end
        t:SetTexCoord(part.l, part.r, part.t, part.b)
        return t
    end
    local titlePlate = plate("title-plate")
    local taglinePlate = plate("tagline-plate")

    local title = W.Text(content, "amber", "GameFontNormalLarge")
    title:SetText("GoblinPS")
    local tagline = W.Text(content, "dim", "GameFontDisableSmall")
    tagline:SetText("Accuracy not guaranteed. No refunds.")

    local close = CreateFrame("Button", nil, content)
    close:RegisterForClicks("LeftButtonUp")
    close:SetScript("OnClick", function()
        dismiss()
        f:Hide()
    end)
    local closeArt = art(close, "close", "ARTWORK")
    if not closeArt then
        W.Fill(close, "ARTWORK", "hazard")
    end
    local closeHover = ns.Data.Art and ns.Data.Art["close-hover"]
    if closeHover then
        close:SetHighlightTexture(MEDIA .. closeHover.file, "ADD")
    end

    -- The art has a socket beside the To box and the geometry places it, but
    -- no such control exists today: the results list only appears while you
    -- type. An empty socket reads as a fault, and a way to browse every
    -- destination without knowing its name is worth having, so the button
    -- opens the same list with an empty query.
    local dropdown = CreateFrame("Button", nil, content)
    dropdown:RegisterForClicks("LeftButtonUp")
    dropdown:SetScript("OnClick", function()
        if ui.results:IsShown() and ui.results.owner == ui.toBox then
            hideResults()
        else
            showResults(ui.toBox)
        end
    end)
    local dropdownArt = art(dropdown, "dropdown-button", "ARTWORK")
    if not dropdownArt then
        W.Fill(dropdown, "ARTWORK", "steel")
    end

    -- The gear opens settings, which is a later plan. It is drawn and placed
    -- now because the art has a socket for it and an empty socket reads as a
    -- fault; it says so when clicked rather than doing nothing.
    local gear = CreateFrame("Button", nil, content)
    gear:RegisterForClicks("LeftButtonUp")
    gear:SetScript("OnClick", function()
        ns.Core.Say("Settings are not built yet.")
    end)
    local gearArt = art(gear, "gear", "ARTWORK")
    if not gearArt then
        W.Fill(gear, "ARTWORK", "steel")
    end
    local gearHover = ns.Data.Art and ns.Data.Art["gear-hover"]
    if gearHover then
        gear:SetHighlightTexture(MEDIA .. gearHover.file, "ADD")
    end

    local layoutButton = W.Button(f, "Tall", 44, 18, function()
        dismiss()
        Planner.ApplyLayout(ns.Core.ToggleLayout())
    end)

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
        -- The Garmin model: plan the route, then drive. /gps reopens the
        -- planner without ending the trip.
        local plan = state.plan
        if ui.frame:IsShown() and plan and plan.result and #plan.result.steps > 0 then
            ui.frame:Hide()
        end
    end)
    go:SetPoint("BOTTOMRIGHT", -8, 8)
    local total = W.Text(side, "green", "GameFontNormal")
    total:SetPoint("BOTTOMLEFT", 8, 12)
    total:SetPoint("RIGHT", go, "LEFT", -8, 0)

    local results = W.Panel(f, "steel", "brass", 1)
    results:SetFrameStrata("DIALOG")
    results:SetFrameLevel(base + 3)
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

    ui = { frame = f, artLayer = artLayer, content = content, flat = flat, frameArt = frameArt,
           titlePlate = titlePlate, taglinePlate = taglinePlate, title = title, tagline = tagline,
           close = close, gear = gear, dropdown = dropdown,
           fromBox = fromBox, toBox = toBox, screen = screen, side = side, rows = rows,
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

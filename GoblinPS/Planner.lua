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
    local level = plan and plan.level or nil
    local steps = plan and plan.result and plan.result.steps or {}
    for i = 1, Planner.MAX_ROWS do
        local row, step = ui.rows[i], steps[i]
        local left, right, detail, warn = "", "", "", false
        if step and i == Planner.MAX_ROWS and #steps > Planner.MAX_ROWS then
            left = "... and " .. (#steps - i + 1) .. " more steps"
        elseif step then
            left, right = stepLine(i, step)
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

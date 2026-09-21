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
local ROW, STEP_ROW = 18, 32

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

-- Cover `rect` (in device fractions) with a part whose own aspect differs,
-- losing the overflow evenly off both sides rather than distorting the art.
-- The crop composes with the part's padding crop: the part's artwork lives in
-- l..r of its texture, so the cover-crop takes a centred sub-range of THAT,
-- never of 0..1. Getting this backwards crops the padding instead of the art.
--
-- The part's own aspect has to come from `cw`/`ch`, the padded canvas
-- make_art.py actually shipped -- NOT the pre-scale master PNG's size. l/r/t/b
-- are fractions of that shipped canvas, so mixing them with the master's
-- pixel size mixes two coordinate domains and crops the wrong amount while
-- staying centred and in bounds, which is exactly why that is easy to miss.
-- screen-backdrop's master is 1600x640 (aspect 2.5) but it ships at 512x205
-- padded to 512x256 (aspect 2.4976): close, not equal, and the padding shifts
-- it further still on a part whose canvas isn't square.
--
-- screen-backdrop is decorative scenery, not a map. Losing its sides is
-- intended. If the part carries no cw/ch (an older or hand-edited table),
-- this leaves the texture's coordinates alone rather than compute a crop
-- from nil.
local function coverCrop(texture, part, boxW, boxH)
    if not (part.cw and part.ch) then
        return
    end
    local span = part.r - part.l
    local tall = part.b - part.t
    local partAspect = (part.cw * span) / (part.ch * tall)
    local boxAspect = boxW / boxH
    if partAspect > boxAspect then
        -- The art is wider than the opening: keep a centred slice of width.
        local keep = span * (boxAspect / partAspect)
        local trim = (span - keep) / 2
        texture:SetTexCoord(part.l + trim, part.r - trim, part.t, part.b)
    else
        local keep = tall * (partAspect / boxAspect)
        local trim = (tall - keep) / 2
        texture:SetTexCoord(part.l, part.r, part.t + trim, part.b - trim)
    end
end

-- The union rect of every placed area in this layout's geometry: minimum
-- left and top, maximum right and bottom, over every key in `g` that has a
-- `left` field (a rect; `canvas` is pixels, not a device fraction, and the
-- circle keys have cx/cy/r instead, so both are skipped without naming
-- them). Used for the tiled panel backing, which sits behind every opening
-- rather than any one of them -- placed at the screen's own rect it would
-- sit exactly where screen-backdrop goes and never be seen.
local function boundingBox(g)
    local box
    for key, rect in pairs(g) do
        if key ~= "canvas" and type(rect) == "table" and rect.left then
            if not box then
                box = { left = rect.left, top = rect.top, right = rect.right, bottom = rect.bottom }
            else
                box.left = math.min(box.left, rect.left)
                box.top = math.min(box.top, rect.top)
                box.right = math.max(box.right, rect.right)
                box.bottom = math.max(box.bottom, rect.bottom)
            end
        end
    end
    return box
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
        W.PlaceRect(ui.fromBox, f, g.fromBox)
        W.PlaceRect(ui.toBox, f, g.toBox)
        W.PlaceRect(ui.here, f, g.hereButton)
        W.PlaceRect(ui.results, f, g.resultsList)
        W.PlaceRect(ui.screen, f, g.screen)
        W.PlaceRect(ui.side, f, g.sidePanel)
        W.PlaceRect(ui.go, f, g.goButton)
        W.PlaceLine(ui.total, f, g.totalLine)
        W.PlaceLine(ui.hint, f, g.hintLine)
        if ui.panelArt then
            W.PlaceRect(ui.panelArt, f, boundingBox(g))
        end
        if ui.backdrop then
            W.PlaceRect(ui.backdrop, f, g.screen)
            local backdropPart = ns.Data.Art and ns.Data.Art["screen-backdrop"]
            if backdropPart then
                coverCrop(ui.backdrop, backdropPart,
                          (g.screen.right - g.screen.left) * f:GetWidth(),
                          (g.screen.bottom - g.screen.top) * f:GetHeight())
            end
        end
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

    local backdrop = artLayer:CreateTexture(nil, "BORDER")
    local backdropPart = ns.Data.Art and ns.Data.Art["screen-backdrop"]
    if not (backdropPart and backdrop:SetTexture(MEDIA .. backdropPart.file)) then
        backdrop:Hide()
        backdrop = nil
    end

    -- The interior backing, genuinely tiled. That works only because this part
    -- ships unpadded: a 512x512 source at 256x256 is already a power of two,
    -- so its crop is the whole texture. Tiling a PADDED part would repeat the
    -- transparent padding along with the picture, which is why every other
    -- part in this window is stretched instead. check_art.py flags this one as
    -- tiling, meaning its four edges were drawn to meet.
    --
    -- SetHorizTile and SetVertTile are both present on build 1.60.1.69913
    -- (SimpleTextureBaseAPIDocumentation.lua) and Blizzard's own UI calls them.
    local panelArt = artLayer:CreateTexture(nil, "BACKGROUND")
    local panelPart = ns.Data.Art and ns.Data.Art["planner-panel"]
    local whole = panelPart and panelPart.l == 0 and panelPart.r == 1
                  and panelPart.t == 0 and panelPart.b == 1
    if whole and panelArt:SetTexture(MEDIA .. panelPart.file, "REPEAT", "REPEAT") then
        panelArt:SetHorizTile(true)
        panelArt:SetVertTile(true)
    elseif panelPart and panelArt:SetTexture(MEDIA .. panelPart.file) then
        -- Padded after all: stretch rather than repeat the padding.
        panelArt:SetTexCoord(panelPart.l, panelPart.r, panelPart.t, panelPart.b)
    else
        panelArt:Hide()
    end

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

    -- The three plain buttons all draw the same "button" part at a width the
    -- geometry, not this code, decides: 65 pixels for Here in the wide layout
    -- and 135 for GO in the tall one. A single stretched texture would
    -- squash those end caps at one width and stretch them at the other, so
    -- each gets its own three-slice art on top of its flat fallback.
    local BUTTON_CAP, BUTTON_CAP_ASPECT = 0.25, 1.0

    local layoutButton = W.Button(content, "Tall", 44, 18, function()
        dismiss()
        Planner.ApplyLayout(ns.Core.ToggleLayout())
    end)
    W.Stretch3(layoutButton, "button", BUTTON_CAP, BUTTON_CAP_ASPECT)

    local fromBox = W.EditBox(content, 150, 20, "From: where you stand")
    local toBox = W.EditBox(content, 170, 20, "To: city, zone or flight stop")
    local here = W.Button(content, "Here", 40, 20, function()
        dismiss()
        state.from = nil
        ui.fromBox:SetText("")
        W.UpdatePlaceholder(ui.fromBox)
        replan()
    end)
    W.Stretch3(here, "button", BUTTON_CAP, BUTTON_CAP_ASPECT)

    -- input-box.png is 1024x128, so 0.18 of its width is a 184x128 cap.
    local CAP, CAP_ASPECT = 0.18, 184 / 128
    local fromSlice = W.Stretch3(fromBox, "input-box", CAP, CAP_ASPECT)
    local toSlice = W.Stretch3(toBox, "input-box", CAP, CAP_ASPECT)

    local screen = W.Panel(content, "screen", "steel", 2)
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

    local side = W.Panel(content, "steel", "steel", 1)
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
    W.Stretch3(go, "button", BUTTON_CAP, BUTTON_CAP_ASPECT)
    local total = W.Text(side, "green", "GameFontNormal")

    local results = W.Panel(content, "steel", "brass", 1)
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
           close = close, gear = gear, dropdown = dropdown, backdrop = backdrop, panelArt = panelArt,
           fromBox = fromBox, toBox = toBox, screen = screen, side = side, rows = rows,
           hint = hint, total = total, go = go, here = here, known = known, results = results,
           layoutButton = layoutButton, notes = notes, fromSlice = fromSlice, toSlice = toSlice }
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

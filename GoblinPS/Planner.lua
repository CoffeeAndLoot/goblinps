local _, ns = ...

-- The planner: one search box, the green screen with the route strip in it,
-- the total and the warning under the strip, and Start Route. The route
-- always starts where you stand. One wide shape; every position comes from
-- the geometry the art tool generates.
local Planner = {}
ns.Planner = Planner

local W = ns.Widgets

-- The window's rectangle on screen. The frame art is 1600x1024, so this keeps
-- its 25:16 exactly; everything inside is placed as a fraction of it, from
-- the geometry the art tool generates. Nothing here is a measured guess.
Planner.SIZE = { 650, 416 }
Planner.MAX_RESULTS = 8
local ROW = 18

local ui          -- built on first open
local state = {}  -- to = place, plan = Core.PlanRoute's answer

local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"

-- The layout's geometry, or nil when the generated table is absent. Gated on
-- the geometry alone: whether the parts shipped is a different question.
local function geo()
    local g = ns.Data.ArtGeometry and ns.Data.ArtGeometry.planner
    return g and g.wide
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

-- Paint whatever state.plan holds. With a route, the idle status lines give
-- way to it; without one, they say why there is none.
function Planner.Refresh()
    if not ui then
        return
    end
    local plan = state.plan
    local steps = plan and plan.result and plan.result.steps or {}
    local routed = #steps > 0
    local notes = plan and table.concat(plan.notes, "  ") or ""
    local total, hint = "", ""
    if plan and routed then
        total = ns.Route.FormatTime(plan.result.seconds) .. " · " .. ns.Route.FormatMoney(plan.result.copper)
        -- One amber line under the strip. What the player must know first
        -- wins: a note about the route itself, then a flight path worth
        -- discovering. (Task 4 puts the level warning ahead of both.)
        if notes ~= "" then
            hint = notes
        elseif plan.hint then
            hint = ns.Route.HintText(plan.hint)
        end
    end
    ui.total:SetText(total)
    ui.hint:SetText(hint)
    ui.notes:SetText(notes)
    ui.notes:SetShown(not routed)
    ui.known:SetShown(not routed)
    W.SetButtonEnabled(ui.go, routed)

    local known = ns.Core.KnownCount()
    ui.known:SetText(known == 0 and "No flight paths yet: open a flight map."
        or ("Flight paths known: " .. known))
end

local function replan()
    state.plan = state.to and ns.Core.PlanRoute(state.to) or nil
    Planner.Refresh()
end

-- ---- the results list under the search box ----

local function hideResults()
    ui.results:Hide()
end

-- Puts the results list away and drops focus from the box: used wherever
-- clicking something other than a result row should end the search.
local function dismiss()
    ui.toBox:ClearFocus()
    hideResults()
end

local function pick(item)
    hideResults()
    state.to = item
    ns.Core.Remember(item.name)
    ui.toBox:SetText(item.name)
    ui.toBox:ClearFocus()
    W.UpdatePlaceholder(ui.toBox)
    replan()
end

-- Matches for the text; with an empty box, the recent destinations.
local function candidates()
    local text = ui.toBox:GetText()
    if text ~= "" then
        return ns.Search.Find(ns.Data, text, ns.Core.Faction(), Planner.MAX_RESULTS)
    end
    local out = {}
    for _, name in ipairs(ns.Core.Recents()) do
        out[#out + 1] = ns.Search.Exact(ns.Data, name, ns.Core.Faction())
    end
    return out
end

local function showResults()
    local items = candidates()
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
    ui.results:Show()
end

local function wireBox(box)
    box:SetScript("OnTextChanged", function(self, userInput)
        W.UpdatePlaceholder(self)
        if userInput then
            showResults()
        end
    end)
    box:SetScript("OnEditFocusGained", showResults)
    box:SetScript("OnEditFocusLost", function()
        -- The client drops edit focus on mouse-down, before a click on a row
        -- completes. With the cursor on the list, leave it for that click.
        if not ui.results:IsMouseOver() then
            hideResults()
        end
    end)
    box:SetScript("OnEnterPressed", function(self)
        local first = candidates()[1]
        if first then
            pick(first)
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

-- The two keys that live ON the chassis rather than in its opening: the title
-- plate is riveted to the brass crest, the tagline plate to the bottom rail.
-- Everything else in the geometry sits in the cut-out.
local ON_THE_CHASSIS = { titlePlate = true, taglinePlate = true }

-- The union rect of every placed area in the geometry: minimum left and top,
-- maximum right and bottom, over every key in `g` that has a `left` field (a
-- rect; `canvas` is pixels, not a device fraction, and the circle keys have
-- cx/cy/r instead, so both are skipped without naming them) and is not
-- ON_THE_CHASSIS.
--
-- Only the FALLBACK for the tiled panel backing now, used when the generated
-- geometry has no `interior`. The real placement is `g.interior`: the frame's
-- opening measured from its own alpha by tools/make_art.py. This union sits
-- inset from that opening, and seen in the client 2026-09-21 it let the world
-- show through on the left, the right and the bottom. The two plates stay
-- excluded because they are riveted to the chassis rather than set into the
-- opening.
local function boundingBox(g)
    local box
    for key, rect in pairs(g) do
        if key ~= "canvas" and not ON_THE_CHASSIS[key] and type(rect) == "table" and rect.left then
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

-- ---- placement ----

function Planner.ApplyLayout()
    if not ui then
        return
    end
    local f = ui.frame
    -- The explicit size first, before anything reads it: every helper below
    -- measures this frame, and a frame with no size measures 0.
    f:SetSize(Planner.SIZE[1], Planner.SIZE[2])

    local part = ns.Data.Art and ns.Data.Art["planner-frame-wide"]
    if part and ui.frameArt:SetTexture(MEDIA .. part.file) then
        ui.frameArt:SetTexCoord(part.l, part.r, part.t, part.b)
        ui.frameArt:Show()
        ui.flat:Hide()
    else
        ui.frameArt:Hide()
        ui.flat:Show()
    end

    local g = geo()
    if not g then
        return
    end
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
    W.PlaceRect(ui.toBox, f, g.toBox)
    W.PlaceRect(ui.results, f, g.resultsList)
    W.PlaceRect(ui.screen, f, g.screen)
    W.PlaceRect(ui.go, f, g.goButton)
    W.PlaceLine(ui.total, f, g.totalLine)
    W.PlaceLine(ui.hint, f, g.hintLine)
    W.PlaceLine(ui.notes, f, g.notesLine)
    W.PlaceLine(ui.known, f, g.knownLine)
    if ui.panelArt then
        -- The frame's opening, measured from its own alpha by make_art.py.
        -- Seen in the client 2026-09-21: sized to the controls instead,
        -- the backing stopped short of the brass and the world showed
        -- through on the left, the right and the bottom.
        W.PlaceRect(ui.panelArt, f, g.interior or boundingBox(g))
    end
    -- Both three-sliced controls have just been re-anchored corner to corner,
    -- so their end caps were measured against the height they had before.
    -- The new height CANNOT be read off the control: it only inherits its
    -- size now. Work it out from the same two things PlaceRect used -- the
    -- control's own rect and this frame, given an explicit size above.
    for _, pair in ipairs({ { ui.go, g.goButton }, { ui.toBox, g.toBox } }) do
        W.Restretch3(pair[1], (pair[2].bottom - pair[2].top) * f:GetHeight())
    end
    if ui.backdrop then
        -- Placed by its parent, not by the geometry, but the crop still
        -- needs the screen opening's pixel size.
        local backdropPart = ns.Data.Art and ns.Data.Art["screen-backdrop"]
        if backdropPart then
            coverCrop(ui.backdrop, backdropPart,
                      (g.screen.right - g.screen.left) * f:GetWidth(),
                      (g.screen.bottom - g.screen.top) * f:GetHeight())
        end
    end
end

-- ---- construction ----

local function build()
    -- Bare on purpose. A texture created on this frame could only be taken off
    -- screen by hiding the frame, and the window art has transparent margins,
    -- so an unhideable rectangle behind it boxes in a window that is not a
    -- rectangle. The dash unit shipped that fault once already.
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(Planner.SIZE[1], Planner.SIZE[2])
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

    -- The window's own chassis. ApplyLayout gives it the frame art, so create
    -- it empty here and let ApplyLayout fill it. It is on "BORDER", one layer
    -- above the tiled backing on "BACKGROUND", so the chassis is drawn OVER the
    -- backing: the backing's box tucks a few pixels under the brass on every
    -- side, and only the frame on top hides that.
    local frameArt = artLayer:CreateTexture(nil, "BORDER")
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
    -- Both plates are drawn with their words in them -- "GOBLINPS / Goblin
    -- Positioning System" and "Time is money, friend." -- so this text is the
    -- fallback for a plate that did not load. Seen in the client 2026-09-21:
    -- drawn anyway, it sat on top of the lettering.
    title:SetShown(not titlePlate)
    tagline:SetShown(not taglinePlate)

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
        if ui.results:IsShown() then
            hideResults()
        else
            showResults()
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

    -- Start Route draws the "button" part at a width the geometry, not this
    -- code, decides. A single stretched texture would squash its end caps, so
    -- it gets three-slice art on top of its flat fallback.
    local BUTTON_CAP, BUTTON_CAP_ASPECT = 0.25, 1.0

    local toBox = W.EditBox(content, 170, 20, "To: city, zone or flight stop")

    -- input-box.png is 1024x128, so 0.18 of its width is a 184x128 cap.
    local CAP, CAP_ASPECT = 0.18, 184 / 128
    local toSlice = W.Stretch3(toBox, "input-box", CAP, CAP_ASPECT)

    local screen = W.Panel(content, "screen", "steel", 2)

    -- The scenery belongs to the screen, not to the art layer behind it.
    -- W.Panel lays two fully opaque colour fills on the frame it makes, so a
    -- backdrop on artLayer at the same rect was drawn, cropped correctly and
    -- never once seen -- the same fault the window frame's own panel had, one
    -- level down. On the screen at "ARTWORK" it sits above those two fills
    -- (BACKGROUND and BORDER) and below the OVERLAY text drawn on it, which
    -- is this project's standing art-over-colours pattern. The fills stay
    -- exactly where they are and remain the fallback when the texture will
    -- not load. It fills its parent, so ApplyLayout never places it: the
    -- geometry already places the screen.
    local backdrop = screen:CreateTexture(nil, "ARTWORK")
    local backdropPart = ns.Data.Art and ns.Data.Art["screen-backdrop"]
    if backdropPart and backdrop:SetTexture(MEDIA .. backdropPart.file) then
        backdrop:SetAllPoints(screen)
    else
        backdrop:Hide()
        backdrop = nil
    end

    -- Four lines, all on the screen so they draw over its scenery (a string on
    -- `content` would sit under the screen, which is content's child). notes
    -- and known are the idle status lines and give way to the route; total
    -- and hint sit under the strip and stay.
    local notes = W.Text(screen, "dim")
    local known = W.Text(screen, "green")
    local total = W.Text(screen, "green", "GameFontNormal", "CENTER")
    local hint = W.Text(screen, "amber", nil, "CENTER")

    local go = W.Button(content, "Start Route", 120, 24, function()
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
    W.WireButtonArt(go)

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
        row:SetScript("OnClick", function(self) pick(self.item) end)
        results.rows[i] = row
    end

    ui = { frame = f, artLayer = artLayer, content = content, flat = flat, frameArt = frameArt,
           titlePlate = titlePlate, taglinePlate = taglinePlate, title = title, tagline = tagline,
           close = close, gear = gear, dropdown = dropdown, backdrop = backdrop, panelArt = panelArt,
           toBox = toBox, toSlice = toSlice, screen = screen, total = total, hint = hint,
           notes = notes, known = known, go = go, results = results }
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
        Planner.ApplyLayout()
    end
    if ui.frame:IsShown() then
        ui.frame:Hide()
    else
        -- Opened mid-trip with nothing of its own picked: show where the trip
        -- is going, so the planner knows where you're at.
        if not state.to then
            local trip = ns.Dash.Destination()
            if trip then
                state.to = trip
                ui.toBox:SetText(trip.name)
                W.UpdatePlaceholder(ui.toBox)
            end
        end
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

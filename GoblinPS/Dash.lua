local _, ns = ...

-- The dash unit: a small draggable device showing the step you are on, an
-- arrow that turns to point at it, how far is left and how long. Built on flat
-- colours; task 6 lays the art over them, and a texture that does not load
-- must leave this readable.
local Dash = {}
ns.Dash = Dash

local W = ns.Widgets

Dash.SIZE = { 200, 250 }
local PAD, SCREEN = 10, 180

local ui              -- built on first Start
local state = {}      -- plan, index, best (closest yet to the current target)

local function stepText(step)
    return step and ns.Route.StepText(step) or ""
end

-- Draws whatever is in `state`. Safe to call at any time.
function Dash.Refresh()
    if not ui or not state.plan then
        return
    end
    local steps = state.plan.result and state.plan.result.steps or {}
    local step = steps[state.index]
    if not step then
        return
    end
    ui.step:SetText(stepText(step))
    local following = steps[state.index + 1]
    ui.next:SetText(following and ("then " .. stepText(following)) or "")
end

local function build()
    local f = W.Panel(UIParent, "body", "brass", 3)
    f:SetSize(Dash.SIZE[1], Dash.SIZE[2])
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        ns.Core.SavePosition("dash", point, relativePoint, x, y)
    end)
    f:Hide()

    local screen = W.Panel(f, "screen", "steel", 2)
    screen:SetSize(SCREEN, SCREEN)
    screen:SetPoint("TOP", 0, -PAD)

    local arrow = screen:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(90, 90)
    arrow:SetPoint("CENTER")
    arrow:SetTexture("Interface\\Buttons\\WHITE8X8")
    arrow:SetVertexColor(unpack(W.COLOR.green))

    local distance = W.Text(f, "green", "GameFontNormalLarge", "CENTER")
    distance:SetPoint("TOPLEFT", screen, "BOTTOMLEFT", 0, -4)
    distance:SetPoint("TOPRIGHT", screen, "BOTTOMRIGHT", 0, -4)

    local eta = W.Text(f, "dim", "GameFontNormalSmall", "CENTER")
    eta:SetPoint("TOPLEFT", distance, "BOTTOMLEFT", 0, -2)
    eta:SetPoint("TOPRIGHT", distance, "BOTTOMRIGHT", 0, -2)

    local step = W.Text(f, "green", "GameFontNormalSmall", "CENTER")
    step:SetPoint("TOPLEFT", eta, "BOTTOMLEFT", 0, -6)
    step:SetPoint("TOPRIGHT", eta, "BOTTOMRIGHT", 0, -6)

    local following = W.Text(f, "dim", "GameFontHighlightSmall", "CENTER")
    following:SetPoint("TOPLEFT", step, "BOTTOMLEFT", 0, -2)
    following:SetPoint("TOPRIGHT", step, "BOTTOMRIGHT", 0, -2)

    local stop = W.Button(f, "Stop", 48, 20, function() Dash.Stop() end)
    stop:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    ui = { frame = f, screen = screen, arrow = arrow, distance = distance,
           eta = eta, step = step, next = following, stop = stop }
    ns.Core.CloseOnEscape(f, "GoblinPSDash")
end

-- Begin a trip. A plan with no steps is not a trip, and opens nothing.
function Dash.Start(plan)
    if not ui then
        build()
        local p = ns.Core.Position("dash")
        ui.frame:ClearAllPoints()
        if p then
            ui.frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
        else
            ui.frame:SetPoint("CENTER", UIParent, "CENTER", -260, 0)
        end
    end
    local steps = plan and plan.result and plan.result.steps or {}
    if #steps == 0 then
        return
    end
    state.plan, state.index, state.best = plan, 1, nil
    Dash.Refresh()
    ui.frame:Show()
end

function Dash.Stop()
    state.plan, state.index, state.best = nil, nil, nil
    if ui then
        ui.frame:Hide()
    end
end

-- For the desktop smoke test only.
function Dash.Debug()
    return ui, state
end

return Dash

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
local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"

local ui              -- built on first Start
local state = {}      -- plan, index, best (closest yet to the current target)

local function stepText(step)
    return step and ns.Route.StepText(step) or ""
end

-- Lay a generated part over a flat colour. Returns the texture, or nil when
-- the part is unknown or the file will not load, leaving the colour showing.
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

    local screenArt = art(screen, "dash-screen", "BACKGROUND")
    local compass = art(screen, "dash-compass", "BORDER")

    local arrow = screen:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(90, 90)
    arrow:SetPoint("CENTER")
    arrow:SetTexture("Interface\\Buttons\\WHITE8X8")
    arrow:SetVertexColor(unpack(W.COLOR.green))

    local arrowPart = ns.Data.Art and ns.Data.Art["arrow"]
    if arrowPart and arrow:SetTexture(MEDIA .. arrowPart.file) then
        arrow:SetTexCoord(arrowPart.l, arrowPart.r, arrowPart.t, arrowPart.b)
        arrow:SetVertexColor(1, 1, 1)
    end

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

    -- The ETA plate sits behind the time-left line, not over the whole
    -- device, so it is its own small frame rather than a part of `f`.
    local plate = CreateFrame("Frame", nil, f)
    plate:SetPoint("TOPLEFT", eta, "TOPLEFT", -6, 4)
    plate:SetPoint("BOTTOMRIGHT", eta, "BOTTOMRIGHT", 6, -4)
    local plateArt = art(plate, "dash-eta-plate", "BACKGROUND")
    eta:SetDrawLayer("OVERLAY")

    -- The body is drawn last and on top: it has a transparent hole the
    -- screen shows through.
    local bodyArt = art(f, "dash-body", "OVERLAY")

    ui = { frame = f, screen = screen, screenArt = screenArt, compass = compass, arrow = arrow,
           bodyArt = bodyArt, plateArt = plateArt, distance = distance,
           eta = eta, step = step, next = following, stop = stop }
    ns.Core.CloseOnEscape(f, "GoblinPSDash")

    local since = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        since = since + elapsed
        if since >= Dash.TICK then
            since = 0
            Dash.Tick("tick")
        end
    end)
    ns.API.OnTripEvent(function(kind) Dash.Tick(kind) end)
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

Dash.TICK = 0.5        -- seconds between checks; every frame is jitter, not accuracy

local function yards(d)
    return ("%d yd"):format(math.floor(d + 0.5))
end

-- Point the arrow at the current step, or hide it. The client can decline to
-- say which way the player faces, and an arrow pointing the wrong way is worse
-- than no arrow at all.
local function aimArrow(pos, step)
    local angle = ns.Trip.ArrowAngle(ns.Trip.Bearing(pos, step.to), ns.API.PlayerFacing())
    if not angle then
        ui.arrow:Hide()
        return
    end
    ui.arrow:SetRotation(angle)
    ui.arrow:Show()
    if ui.compass then
        ui.compass:SetRotation(-(ns.API.PlayerFacing() or 0))
    end
end

local function finish()
    ui.step:SetText("Arrived.")
    ui.next:SetText("")
    ui.distance:SetText("")
    ui.eta:SetText("")
    ui.arrow:Hide()
    state.plan, state.index, state.best = nil, nil, nil
end

-- One look at where the player is against the step they are on. `event` is
-- "tick", "zone" or "landed" and is handed straight to Trip.Check.
function Dash.Tick(event)
    if not ui or not state.plan then
        return
    end
    local steps = state.plan.result.steps
    local step = steps[state.index]
    if not step then
        return
    end
    local pos = ns.Core.Here()
    local verdict = ns.Trip.Check(step, {
        pos = pos, onTaxi = ns.API.OnTaxi(), event = event, best = state.best,
    })

    if verdict == "pause" then
        ui.distance:SetText("Waiting...")
        ui.eta:SetText("")
        ui.arrow:Hide()
        return
    end
    if verdict == "advance" then
        if state.index >= #steps then
            finish()
            return
        end
        state.index, state.best = state.index + 1, nil
        Dash.Refresh()
        ns.Core.PinStep(steps[state.index])   -- the pin follows the step you are on
        return
    end
    if verdict == "recalculate" then
        local replanned = ns.Core.PlanRoute(state.plan.to, pos)
        if replanned.result and #replanned.result.steps > 0 then
            state.plan, state.index, state.best = replanned, 1, nil
            ui.next:SetText("Recalculating...")
            Dash.Refresh()
        elseif replanned.result then
            -- The replan found nothing left to do: the player was already at
            -- the destination. That is arrival, not a plan to sit on quietly;
            -- finish() is the same path an advance past the last step takes,
            -- so the text never goes stale on an old, now-pointless step.
            finish()
        end
        return
    end

    local d = ns.Trip.DistanceTo(pos, step)
    if d then
        state.best = math.min(state.best or d, d)
        ui.distance:SetText(yards(d))
        aimArrow(pos, step)
    else
        ui.distance:SetText("")
        ui.arrow:Hide()
    end
    local travel = ns.Travel.For(state.plan.level)
    local left = ns.Trip.Remaining(state.plan.result, state.index, pos, travel.speed)
    ui.eta:SetText(left and ns.Route.FormatTime(left) or "")
end

-- For the desktop smoke test only.
function Dash.Debug()
    return ui, state
end

return Dash

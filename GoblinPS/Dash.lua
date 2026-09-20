local _, ns = ...

-- The dash unit: a small draggable device showing the step you are on, an
-- arrow that turns to point at it, how far is left and how long. Built on flat
-- colours; task 6 lays the art over them, and a texture that does not load
-- must leave this readable.
local Dash = {}
ns.Dash = Dash

local W = ns.Widgets

-- Seen in game 2026-09-20: the body art is a round device on a square
-- texture, so the frame that carries it must be square too or it renders as
-- an oval. DEVICE is that square; the frame is DEVICE wide and tall enough
-- for the device plus a band of text under it, which also keeps the art off
-- the directions.
Dash.SIZE = { 220, 348 }
local PAD, DEVICE = 10, 200
local SCREEN = DEVICE - 20
local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"

local ui              -- built on first Start
local state = {}      -- plan, index, best (closest yet to the current target)

local function stepText(step)
    return step and ns.Route.StepText(step) or ""
end

-- Lay a generated part over a flat colour, on `parent` at `layer`. The
-- texture fills `parent`, unless `pad` is given (a widget to anchor around
-- with a little padding instead), for a part that sits behind one small
-- widget rather than covering the whole frame. Returns the texture, or nil
-- when the part is unknown or the file will not load, leaving the colour
-- showing.
local function art(parent, name, layer, pad)
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
    if pad then
        t:SetPoint("TOPLEFT", pad, "TOPLEFT", -6, 4)
        t:SetPoint("BOTTOMRIGHT", pad, "BOTTOMRIGHT", 6, -4)
    else
        t:SetAllPoints(parent)
    end
    return t
end

-- Draws whatever is in `state`. Safe to call at any time. `state.banner`,
-- when set, takes the "then ..." line for exactly the tick it was set on
-- (Dash.Tick clears it and redraws before checking the next verdict), so
-- "Recalculating..." is seen without being able to stick around forever.
-- Distance and ETA are cleared here too: whatever they showed belonged to
-- the step or trip this call is replacing, and the very next tick recomputes
-- them fresh.
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
    ui.next:SetText(state.banner or (following and ("then " .. stepText(following)) or ""))
    ui.distance:SetText("")
    ui.eta:SetText("")
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
    -- Escape hides this frame (it is in UISpecialFrames) without calling
    -- Dash.Stop, and there is no other way to reopen it: without this, the
    -- trip would keep ticking, replanning and even finishing behind a
    -- window nobody can see. OnHide is the one place both Escape and the
    -- Stop button end up, so ending the trip here covers both.
    f:SetScript("OnHide", function()
        state.plan, state.index, state.best, state.banner = nil, nil, nil, nil
    end)
    f:Hide()

    -- A child frame draws entirely above every draw layer of its parent, and
    -- within one frame the region created later wins a layer tie — draw
    -- layers alone cannot stack four frames' worth of parts correctly, so
    -- every level below is set explicitly instead of left to either rule by
    -- accident. Bottom to top: f's own flat colours, screen (its flat
    -- colour, screenArt, compass, arrow), bezel (bodyArt, whose transparent
    -- hole lets the screen show through), content (the plate and every
    -- FontString, so the body art can never cover the directions).
    local base = f:GetFrameLevel()

    -- The square the round art lives in. Everything round anchors to this
    -- and never to `f`, whose height carries the text band as well.
    local device = CreateFrame("Frame", nil, f)
    device:SetSize(DEVICE, DEVICE)
    device:SetPoint("TOP", 0, -PAD)
    device:SetFrameLevel(base + 1)

    local screen = W.Panel(device, "screen", "steel", 2)
    screen:SetSize(SCREEN, SCREEN)
    screen:SetPoint("CENTER")
    screen:SetFrameLevel(base + 1)

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
    else
        -- The generated file is unknown or would not load: put the flat
        -- placeholder back. Without this, a failed SetTexture above leaves
        -- the texture object holding the path that just failed, and the
        -- arrow -- the one part with no colour behind it -- draws nothing.
        arrow:SetTexture("Interface\\Buttons\\WHITE8X8")
    end

    -- The bezel carries only the body art, above the screen so its
    -- transparent hole lets the screen (and the arrow on it) show through.
    local bezel = CreateFrame("Frame", nil, f)
    bezel:SetAllPoints(device)
    bezel:SetFrameLevel(base + 2)
    local bodyArt = art(bezel, "dash-body", "OVERLAY")

    -- The content frame carries the plate and every line of text, above the
    -- bezel so the body art can never cover them.
    local content = CreateFrame("Frame", nil, f)
    content:SetAllPoints(f)
    content:SetFrameLevel(base + 3)

    local distance = W.Text(content, "green", "GameFontNormalLarge", "CENTER")
    distance:SetPoint("TOPLEFT", device, "BOTTOMLEFT", 0, -2)
    distance:SetPoint("TOPRIGHT", device, "BOTTOMRIGHT", 0, -2)

    local eta = W.Text(content, "dim", "GameFontNormalSmall", "CENTER")
    eta:SetPoint("TOPLEFT", distance, "BOTTOMLEFT", 0, -2)
    eta:SetPoint("TOPRIGHT", distance, "BOTTOMRIGHT", 0, -2)

    -- The step is the one line worth reading, and stop names are long
    -- ("Walk to Undercity Zeppelin Tower" truncated in game at 200 wide), so
    -- this line wraps instead of truncating. An explicit height keeps the
    -- rest of the band still whether it takes one line or two.
    local step = W.Text(content, "green", "GameFontNormalSmall", "CENTER")
    step:SetWordWrap(true)
    step:SetHeight(28)
    step:SetPoint("TOPLEFT", eta, "BOTTOMLEFT", 2, -6)
    step:SetPoint("TOPRIGHT", eta, "BOTTOMRIGHT", -2, -6)

    local following = W.Text(content, "dim", "GameFontHighlightSmall", "CENTER")
    following:SetPoint("TOPLEFT", step, "BOTTOMLEFT", 0, -1)
    following:SetPoint("TOPRIGHT", step, "BOTTOMRIGHT", 0, -1)

    -- The ETA plate sits behind the time-left line: a BACKGROUND texture
    -- directly on `content`, anchored around `eta` instead of filling the
    -- frame, drawing under the FontStrings above at OVERLAY on that same
    -- frame — no draw-layer override needed on `eta` for that to hold.
    local plateArt = art(content, "dash-eta-plate", "BACKGROUND", eta)

    -- Stop is its own frame; with no explicit level it would default to one
    -- above `f`, level with `screen` and so under the bezel and content that
    -- now cover the whole device, so it is pinned above all of them.
    local stop = W.Button(f, "Stop", 48, 20, function() Dash.Stop() end)
    stop:SetPoint("BOTTOM", 0, PAD)
    stop:SetFrameLevel(base + 4)

    ui = { frame = f, device = device, screen = screen, screenArt = screenArt,
           compass = compass, arrow = arrow,
           bezel = bezel, content = content, bodyArt = bodyArt, plateArt = plateArt,
           distance = distance, eta = eta, step = step, next = following, stop = stop }
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

-- Hide is the one action that ends a trip: the OnHide script above clears
-- state, so Stop and Escape (which only hides the frame, via UISpecialFrames)
-- both end up ending the trip the same way.
function Dash.Stop()
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
        -- Through Trip.CompassAngle, the same ROTATION_SIGN the arrow uses:
        -- flipping that constant (the checklist's in-game remedy for an
        -- arrow that turns the wrong way) must turn the compass with it,
        -- not leave it hard-coded to one direction.
        ui.compass:SetRotation(ns.Trip.CompassAngle(ns.API.PlayerFacing()))
    end
end

local function finish()
    ui.step:SetText("Arrived.")
    ui.next:SetText("")
    ui.distance:SetText("")
    ui.eta:SetText("")
    ui.arrow:Hide()
    state.plan, state.index, state.best, state.banner = nil, nil, nil, nil
end

-- One look at where the player is against the step they are on. `event` is
-- "tick", "zone" or "landed" and is handed straight to Trip.Check.
function Dash.Tick(event)
    if not ui or not state.plan then
        return
    end
    if state.banner then
        -- The banner (e.g. "Recalculating...") has had its one tick on
        -- screen; clear it and redraw the ordinary text before deciding
        -- what this tick does, so it cannot stick around past the change
        -- it announced.
        state.banner = nil
        Dash.Refresh()
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
            state.banner = "Recalculating..."
            Dash.Refresh()
            ns.Core.PinStep(replanned.result.steps[1])   -- the pin follows the replanned route too
        elseif replanned.result then
            -- The replan found nothing left to do: the player was already at
            -- the destination. That is arrival, not a plan to sit on quietly;
            -- finish() is the same path an advance past the last step takes,
            -- so the text never goes stale on an old, now-pointless step.
            finish()
        else
            -- No route at all: straying again next tick would call
            -- PlanRoute again, and again every 0.5s for as long as the
            -- player stands somewhere unroutable. Treat the current spot as
            -- the new baseline, the same way a successful recalculation
            -- resets `best`, so another full STRAY_YARDS of wandering is
            -- needed before this is retried.
            state.best = ns.Trip.DistanceTo(pos, step)
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

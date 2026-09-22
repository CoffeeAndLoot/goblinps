local _, ns = ...

-- The dash unit: a small draggable device showing the step you are on, an
-- arrow that turns to point at it, how far is left and how long. The art of
-- the second design is laid over a flat-colour fallback, and a texture that
-- does not load must leave this readable.
local Dash = {}
ns.Dash = Dash

local W = ns.Widgets

-- The device's rectangle on screen, and the ONE layout number not read from
-- the geometry. 288x360 is exactly 4:5, the art's 1024:1280, so the device
-- cannot draw stretched; everything inside is placed as a fraction of it,
-- from the geometry the art tool generates. The size was chosen so the
-- artist's smallest opening still clears the client's 10 px fonts (a step
-- line comes out at 21.19 px, the ETA plate at 19.12). It has not yet been
-- looked at in game: if a line is cramped or swims, this is the number to
-- change, and nothing else moves with it.
Dash.SIZE = { 288, 360 }
local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"

local ui              -- built on first Start
local state = {}      -- plan, index, best (closest yet to the current target)

local function stepText(step)
    return step and ns.Route.StepText(step) or ""
end

-- Lay a generated part over a flat colour, on `parent` at `layer`, filling
-- `parent`. Returns the texture, or nil when the part is unknown or the file
-- will not load, leaving the colour showing.
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

-- Draws whatever is in `state`. Safe to call at any time. `state.banner`,
-- when set, takes the first step line for exactly the tick it was set on
-- (Dash.Tick clears it and redraws before checking the next verdict), so
-- "Recalculating..." is seen without being able to stick around forever; the
-- other two step lines are blanked with it so the panel reads as one message
-- rather than a message with stale directions under it.
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
    if state.banner then
        ui.steps[1]:SetText(state.banner)
        ui.steps[2]:SetText("")
        ui.steps[3]:SetText("")
    else
        for i = 1, 3 do
            ui.steps[i]:SetText(stepText(steps[state.index + i - 1]))
        end
    end
    -- The glass names the CURRENT STEP's target, never the trip's final
    -- destination: the arrow only ever points at the current step, and
    -- putting the journey's end on the same glass would invite reading the
    -- arrow as pointing there.
    ui.destination:SetText(step.to and ns.Search.Label(step.to.name) or "")
    ui.distance:SetText("")
    ui.eta:SetText("")
end

-- The placement file stands on its own: the parts table says which textures
-- shipped, which is a different question and not a precondition. Gating one
-- on the other would drop the whole layout to its fallback while a perfectly
-- good geometry sat there unread.
local function geometry()
    return ns.Data.ArtGeometry
end

local function build()
    -- Bare on purpose. A texture created on this frame could only be taken
    -- off screen by hiding the frame, which is the one thing that must never
    -- happen mid-trip -- so it would be a rectangle behind a device whose art
    -- is nearly 40% transparent, showing as brass down both edges. Every
    -- layer, including the no-art fallback, goes on a child frame that CAN
    -- be hidden.
    local f = CreateFrame("Frame", nil, UIParent)
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

    local base = f:GetFrameLevel()
    local g = geometry()

    -- One rectangle for the five layers that were drawn to stack.
    local artLayer = CreateFrame("Frame", nil, f)
    artLayer:SetAllPoints(f)
    artLayer:SetFrameLevel(base + 1)

    -- The flat colour is the fallback for art that will not load. It is a
    -- rectangle, so it goes the moment the glass arrives, or it boxes in a
    -- round device.
    local flat = W.Panel(f, "body", "brass", 3)
    flat:SetAllPoints(f)
    flat:SetFrameLevel(base)
    local glass = art(artLayer, "dash2-glass", "BACKGROUND")
    if glass then
        flat:Hide()
    end

    -- The compass and the arrow turn, so each is a square texture centred on
    -- the dial. SetRotation turns a texture about its own middle, and Task 1
    -- cropped the compass so that its middle IS the dial.
    -- The `or` half of this is only reached when the generated geometry is
    -- absent: a rough guess at the dial's centre, not a coordinate from the
    -- art.
    local dial = g and { x = g.glass.cx, y = g.glass.cy } or { x = 0.5, y = 0.4 }
    local function centreOnDial(region, share)
        local side = f:GetWidth() * share
        region:SetSize(side, side)
        region:ClearAllPoints()
        -- `f`, not `artLayer`: artLayer is sized by SetAllPoints and so has no
        -- resolved size during build(). See Widgets.PlaceLine's note.
        region:SetPoint("CENTER", f, "TOPLEFT",
                        dial.x * f:GetWidth(), -dial.y * f:GetHeight())
    end

    local compass = artLayer:CreateTexture(nil, "BORDER")
    local compassPart = ns.Data.Art and ns.Data.Art["dash2-compass"]
    if compassPart and compass:SetTexture(MEDIA .. compassPart.file) then
        compass:SetTexCoord(compassPart.l, compassPart.r, compassPart.t, compassPart.b)
    else
        compass:Hide()
    end
    -- 0.55 is only reached when the generated geometry is absent: a rough
    -- guess at the compass's share of the device, not a measured fraction.
    centreOnDial(compass, g and g.compassCrop.share or 0.55)

    local arrow = artLayer:CreateTexture(nil, "ARTWORK")
    local arrowPart = ns.Data.Art and ns.Data.Art["arrow"]
    if arrowPart and arrow:SetTexture(MEDIA .. arrowPart.file) then
        arrow:SetTexCoord(arrowPart.l, arrowPart.r, arrowPart.t, arrowPart.b)
    else
        arrow:SetTexture("Interface\\Buttons\\WHITE8X8")
        arrow:SetVertexColor(unpack(W.COLOR.green))
    end
    -- 0.45 is only reached when the generated geometry is absent: a rough
    -- guess at the arrow's share of the device, not a measured fraction.
    centreOnDial(arrow, g and g.arrow.share or 0.45)

    -- images/parts/dash2-notes.md states the order: glass, compass, arrow,
    -- steps insert, ETA insert, then housing. The five draw layers above and
    -- below are that order, and the housing is a frame above this one. The
    -- two inserts overlap nothing today, so nothing moves on screen -- but a
    -- redraw that widened either one would have put it under the glass.
    local stepsScreen = art(artLayer, "dash2-steps-screen", "OVERLAY")
    local etaScreen = art(artLayer, "dash2-eta-screen", "OVERLAY")

    -- The chassis, over the art, with its holes letting the art show through.
    local housingFrame = CreateFrame("Frame", nil, f)
    housingFrame:SetAllPoints(f)
    housingFrame:SetFrameLevel(base + 2)
    local housing = art(housingFrame, "dash2-housing", "ARTWORK")

    local content = CreateFrame("Frame", nil, f)
    content:SetAllPoints(f)
    content:SetFrameLevel(base + 3)

    -- On the glass: what the arrow points at, and how far.
    local destination = W.Text(content, "green", "GameFontNormalSmall", "CENTER")
    local distance = W.Text(content, "green", "GameFontNormalLarge", "CENTER")
    if g then
        W.PlaceLine(destination, f, g.destination)
        W.PlaceLine(distance, f, g.distance)
    else
        -- Only reached when the generated geometry is absent: a plain
        -- vertical stack down the middle of the frame, not a placed layout.
        -- Every line still gets two horizontal anchors, so a missing
        -- geometry file leaves a legible device instead of an invisible one.
        destination:SetPoint("TOPLEFT", content, "TOPLEFT")
        destination:SetPoint("TOPRIGHT", content, "TOPRIGHT")
        distance:SetPoint("TOPLEFT", destination, "BOTTOMLEFT")
        distance:SetPoint("TOPRIGHT", destination, "BOTTOMRIGHT")
    end

    -- In the lit panel: the step you are on, then the next two. The panel is
    -- one box in the art, so the three lines share it, each a third tall.
    local steps = {}
    for i = 1, 3 do
        steps[i] = W.Text(content, i == 1 and "green" or "dim", "GameFontNormalSmall", "LEFT")
    end
    if g then
        local box, third = g.stepsText, (g.stepsText.bottom - g.stepsText.top) / 3
        for i = 1, 3 do
            W.PlaceLine(steps[i], f, {
                left = box.left, right = box.right,
                top = box.top + third * (i - 1), bottom = box.top + third * i,
            })
        end
    else
        -- Only reached when the generated geometry is absent: continues the
        -- same vertical stack, one line per step.
        steps[1]:SetPoint("TOPLEFT", distance, "BOTTOMLEFT")
        steps[1]:SetPoint("TOPRIGHT", distance, "BOTTOMRIGHT")
        for i = 2, 3 do
            steps[i]:SetPoint("TOPLEFT", steps[i - 1], "BOTTOMLEFT")
            steps[i]:SetPoint("TOPRIGHT", steps[i - 1], "BOTTOMRIGHT")
        end
    end

    -- On its own plate: the time left.
    local eta = W.Text(content, "green", "GameFontNormalSmall", "CENTER")
    if g then
        W.PlaceLine(eta, f, g.etaText)
    else
        -- Only reached when the generated geometry is absent: the last line
        -- of the same vertical stack.
        eta:SetPoint("TOPLEFT", steps[3], "BOTTOMLEFT")
        eta:SetPoint("TOPRIGHT", steps[3], "BOTTOMRIGHT")
    end

    -- How wide each line's opening is, for the marquee. Worked out from the
    -- geometry and `f`, which was given an explicit size -- never read off a
    -- FontString, which only inherits its width from two anchors and answers
    -- 0 during build(). With no geometry the fallback stack spans the frame,
    -- so the frame's own width is the opening.
    local frameWidth = f:GetWidth()
    local function slot(rect)
        return rect and (rect.right - rect.left) * frameWidth or frameWidth
    end
    local stepSlot = slot(g and g.stepsText)
    local lines = {
        { fs = destination, slot = slot(g and g.destination) },
        { fs = distance, slot = slot(g and g.distance) },
        { fs = steps[1], slot = stepSlot },
        { fs = steps[2], slot = stepSlot },
        { fs = steps[3], slot = stepSlot },
        { fs = eta, slot = slot(g and g.etaText) },
    }

    -- A real button in the housing's socket, with the three caps the artist
    -- drew. It is the one way a trip ends now that Escape does not touch the
    -- dash. With no explicit level it would default to one above `f`, level
    -- with `artLayer` and so under the housing and content that now cover
    -- the whole device, so it is pinned above all of them.
    local stop = CreateFrame("Button", nil, f)
    stop:SetFrameLevel(base + 4)
    if g then
        local side = f:GetWidth() * g.stop.r * 2
        stop:SetSize(side, side)
        stop:SetPoint("CENTER", f, "TOPLEFT", g.stop.cx * f:GetWidth(), -g.stop.cy * f:GetHeight())
    else
        -- Only reached when the generated geometry is absent: a small
        -- placeholder square in a corner, not a position from the art.
        stop:SetSize(20, 20)
        stop:SetPoint("TOPRIGHT", -8, -8)
    end
    stop:RegisterForClicks("LeftButtonUp")
    stop:SetScript("OnClick", function() Dash.Stop() end)

    -- Every cap is a shipped part on a padded canvas, so every cap needs
    -- part.l/r/t/b to crop the padding away -- the hover one no less than the
    -- other two. It is right today only because dash2-stop-hover happens to
    -- land on a canvas its art fills exactly, which is an accident of its
    -- size, not a property of the pipeline.
    local function cap(name, layer)
        local part = ns.Data.Art and ns.Data.Art[name]
        if not part then
            return nil
        end
        local t = stop:CreateTexture(nil, layer)
        if not t:SetTexture(MEDIA .. part.file) then
            return nil
        end
        t:SetTexCoord(part.l, part.r, part.t, part.b)
        t:SetAllPoints(stop)
        return t
    end

    local stopNormal = cap("dash2-stop", "ARTWORK")
    local stopPressed = cap("dash2-stop-pressed", "ARTWORK")
    if stopPressed then
        stopPressed:Hide()
        stop:SetScript("OnMouseDown", function()
            stopPressed:Show()
            if stopNormal then stopNormal:Hide() end
        end)
        stop:SetScript("OnMouseUp", function()
            stopPressed:Hide()
            if stopNormal then stopNormal:Show() end
        end)
    end
    local stopHover = cap("dash2-stop-hover", "HIGHLIGHT")
    if stopHover then
        stop:SetHighlightTexture(stopHover, "ADD")
    end
    if not stopNormal then
        -- No art: a flat coloured square still presses and still stops.
        W.Fill(stop, "ARTWORK", "hazard")
    end

    ui = { frame = f, artLayer = artLayer, flat = flat, glass = glass,
           compass = compass, arrow = arrow, stepsScreen = stepsScreen,
           etaScreen = etaScreen, housingFrame = housingFrame, housing = housing,
           content = content, destination = destination, distance = distance,
           steps = steps, eta = eta, lines = lines, stop = stop, stopNormal = stopNormal,
           stopPressed = stopPressed, stopHover = stopHover }
    local since = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        Dash.Steer(elapsed)
        Dash.Scroll(elapsed)
        since = since + elapsed
        if since >= Dash.TICK then
            since = 0
            Dash.Tick("tick")
        end
    end)
    ns.API.OnTripEvent(function(kind) Dash.Tick(kind) end)
end

local function ensureBuilt()
    if ui then
        return
    end
    build()
    local p = ns.Core.Position("dash")
    ui.frame:ClearAllPoints()
    if p then
        ui.frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    else
        ui.frame:SetPoint("CENTER", UIParent, "CENTER", -260, 0)
    end
end

-- Begin a trip. A plan with no steps is not a trip, and opens nothing.
function Dash.Start(plan)
    ensureBuilt()
    local steps = plan and plan.result and plan.result.steps or {}
    if #steps == 0 then
        return
    end
    -- `banner` resets with the rest: a second Start before the next tick
    -- would otherwise open the new trip under the old one's "Recalculating...",
    -- with all three step lines blanked behind it. A resume in progress is
    -- replaced too: a new route takes over from wherever it was waiting.
    state.plan, state.index, state.best, state.banner, state.resume = plan, 1, nil, nil, nil
    state.arrowAngle, state.compassAngle = nil, nil
    Dash.Refresh()
    ui.frame:Show()
end

-- Stop is the one action that ends a trip. Nothing else does -- not Escape,
-- not hiding the interface, not arriving, not a reload -- so it is also the
-- one place the saved trip and our map pin are cleared.
function Dash.Stop()
    state.plan, state.index, state.best, state.banner, state.resume = nil, nil, nil, nil, nil
    state.arrowAngle, state.compassAngle = nil, nil
    ns.Core.ClearTrip()
    ns.Core.ClearPin()
    if ui then
        ui.frame:Hide()
    end
end

-- Carry on with a trip saved before a reload or a logout. Every route starts
-- where you stand, so resuming is planning again -- as soon as the client can
-- say where that is.
function Dash.Resume(place)
    ensureBuilt()
    state.plan, state.index, state.best, state.banner = nil, nil, nil, nil
    state.arrowAngle, state.compassAngle = nil, nil
    state.resume = place
    ui.steps[1]:SetText("Resuming your trip to " .. ns.Search.ShortName(place.name) .. "...")
    ui.steps[2]:SetText("")
    ui.steps[3]:SetText("")
    ui.destination:SetText("")
    ui.distance:SetText("")
    ui.eta:SetText("")
    ui.arrow:Hide()
    ui.frame:Show()
end

-- Where the running trip, or the one resuming, is headed.
function Dash.Destination()
    return state.plan and state.plan.to or state.resume
end

Dash.TICK = 0.5        -- seconds between checks; every frame is jitter, not accuracy

local function yards(d)
    return ("%d yd"):format(math.floor(d + 0.5))
end

-- Point the arrow at the current step, or hide it. The client can decline to
-- say which way the player faces, and an arrow pointing the wrong way is worse
-- than no arrow at all.
--
-- This only decides show/hide and, on the moment the arrow comes into view,
-- snaps the shown angle straight to its target so it never swings in from a
-- stale one. While it is already showing, this touches neither angle at
-- all -- Dash.Steer, running every frame, is what turns it -- so a step
-- advance glides to the new target instead of jumping to it.
local function aimArrow(pos, step)
    local wasShown = ui.arrow:IsShown()
    local angle = ns.Trip.ArrowAngle(ns.Trip.Bearing(pos, step.to), ns.API.PlayerFacing())
    if not angle then
        ui.arrow:Hide()
        state.arrowAngle, state.compassAngle = nil, nil
        return
    end
    if not wasShown or state.arrowAngle == nil then
        state.arrowAngle = angle
        -- Through Trip.CompassAngle, the same ROTATION_SIGN the arrow uses:
        -- flipping that constant (the checklist's in-game remedy for an
        -- arrow that turns the wrong way) must turn the compass with it,
        -- not leave it hard-coded to one direction.
        state.compassAngle = ns.Trip.CompassAngle(ns.API.PlayerFacing())
        ui.arrow:SetRotation(state.arrowAngle)
        ui.compass:SetRotation(state.compassAngle)
    end
    ui.arrow:Show()
end

-- Called every frame, ahead of the 0.5s tick check, so the arrow and compass
-- glide instead of jumping twice a second. Guarded to run only while there
-- is something to steer: Tick still owns showing, hiding and (on the tick
-- the arrow comes into view) snapping it, and clears state.arrowAngle /
-- state.compassAngle wherever the arrow goes away.
function Dash.Steer(elapsed)
    if not ui or not ui.frame:IsShown() then
        return
    end
    if state.resume or not state.plan then
        return
    end
    local steps = state.plan.result and state.plan.result.steps or {}
    local step = steps[state.index]
    if not step or not ui.arrow:IsShown() then
        return
    end
    local pos = ns.Core.Here()
    local facing = ns.API.PlayerFacing()
    local arrowTarget = ns.Trip.ArrowAngle(ns.Trip.Bearing(pos, step.to), facing)
    if not arrowTarget then
        -- Leave the arrow at its last angle; the next tick hides it.
        return
    end
    local compassTarget = ns.Trip.CompassAngle(facing)
    state.arrowAngle = ns.Trip.Ease(state.arrowAngle, arrowTarget, elapsed)
    state.compassAngle = ns.Trip.Ease(state.compassAngle, compassTarget, elapsed)
    ui.arrow:SetRotation(state.arrowAngle)
    ui.compass:SetRotation(state.compassAngle)
end

-- Called every frame. Each line keeps a marquee (Marquee.lua). A line whose
-- text has been set to anything other than what the marquee last drew -- a
-- step advance, a new trip, a banner -- starts again from its beginning, its
-- fit judged afresh: the text's own width against the line's opening, which
-- build() worked out from the geometry. A line that fits never moves, so the
-- distance and ETA, re-set every tick, hold still.
function Dash.Scroll(elapsed)
    if not ui or not ui.frame:IsShown() then
        return
    end
    for _, line in ipairs(ui.lines) do
        local shown = line.fs:GetText() or ""
        if not line.marquee or shown ~= line.drawn then
            line.marquee = ns.Marquee.New(shown, line.fs:GetUnboundedStringWidth() <= line.slot)
        end
        local text = ns.Marquee.Advance(line.marquee, elapsed)
        if text ~= shown then
            line.fs:SetText(text)
        end
        line.drawn = text
    end
end

local function finish()
    ui.steps[1]:SetText("Arrived.")
    ui.steps[2]:SetText("")
    ui.steps[3]:SetText("")
    ui.destination:SetText("")
    ui.distance:SetText("")
    ui.eta:SetText("")
    ui.arrow:Hide()
    -- There is nowhere left to point. The trip is not over -- only Stop ends
    -- it -- but a pin on the spot you are standing on says nothing.
    ns.Core.ClearPin()
    state.plan, state.index, state.best, state.banner = nil, nil, nil, nil
    state.arrowAngle, state.compassAngle = nil, nil
end

-- One try at resuming. No position yet (still loading, or in an instance):
-- keep waiting. A position but no route: say so and stop trying, but keep the
-- saved trip -- only Stop ends a trip.
local function tryResume()
    if not ns.Core.Here() then
        ui.distance:SetText("Waiting...")
        return
    end
    local place = state.resume
    state.resume = nil
    local plan = ns.Core.PlanRoute(place)
    local steps = plan.result and plan.result.steps
    if not steps then
        ui.steps[1]:SetText(plan.notes[#plan.notes] or ("No route found to " .. place.name .. "."))
        ui.distance:SetText("") -- clear whatever the waiting state left showing
        return
    end
    if #steps == 0 then
        finish()
        return
    end
    state.plan, state.index, state.best, state.banner = plan, 1, nil, nil
    Dash.Refresh()
    ns.Core.PinStep(steps[1])
end

-- One look at where the player is against the step they are on. `event` is
-- "tick", "zone" or "landed" and is handed straight to Trip.Check.
function Dash.Tick(event)
    -- A dash hidden by itself (only something other than Stop can do that
    -- now) holds still. Hiding the whole interface (Alt+Z) does not: this
    -- guard checks only the dash's own shown flag, and API.OnTripEvent still
    -- calls Tick on zone changes and landings underneath it, so the trip
    -- keeps up with you while the UI is out of sight.
    if not ui or not ui.frame:IsShown() then
        return
    end
    if state.resume then
        tryResume()
        return
    end
    if not state.plan then
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
        state.arrowAngle, state.compassAngle = nil, nil
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
        state.arrowAngle, state.compassAngle = nil, nil
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

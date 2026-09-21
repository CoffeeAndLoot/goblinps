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

-- The chat escape for a palette entry: |cffRRGGBB, so chat text and the
-- window's own colours never drift apart.
function Widgets.ChatColor(name)
    local c = Widgets.COLOR[name] or Widgets.COLOR.dim
    return ("|cff%02x%02x%02x"):format(
        math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

function Widgets.Text(parent, color, fontObject, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
    fs:SetTextColor(rgb(color or "green"))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- ---- placement from a geometry table ----
--
-- Every one of these takes `device`: the frame with the explicit SetSize, and
-- it must be. A frame sized only by SetAllPoints has NO resolved size until
-- the client's layout pass runs, so GetWidth on one during build() answers 0.
-- Every fraction would then be multiplied by nothing and the region would
-- anchor twice to the same point. Seen in the client 2026-09-20: the dash's
-- compass and arrow sat off the device and all six lines of text were
-- invisible, while 257 tests passed. Measure and anchor the frame that was
-- given a size, never one that inherits it.
--
-- `rect` is { left, top, right, bottom } in 0..1 with the origin at the top
-- left, which is how both geometry files state every box.

function Widgets.PlaceRect(region, device, rect)
    local w, h = device:GetWidth(), device:GetHeight()
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", device, "TOPLEFT", rect.left * w, -rect.top * h)
    region:SetPoint("BOTTOMRIGHT", device, "TOPLEFT", rect.right * w, -rect.bottom * h)
end

-- A *_line rect in the artist's files is a few pixels tall: a line for text to
-- sit ON, not a box to fit text INTO -- the areas are named for what they are
-- and are sized like areas. Anchoring corner to corner crushes the text into a
-- box it cannot fit, so hang the FontString on the rect's vertical centre and
-- let its font decide the height. Two horizontal anchors still, so the
-- bounding rule holds and the line truncates rather than escaping.
function Widgets.PlaceLine(fs, device, rect)
    local w, h = device:GetWidth(), device:GetHeight()
    local y = -(rect.top + rect.bottom) / 2 * h
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", device, "TOPLEFT", rect.left * w, y)
    fs:SetPoint("RIGHT", device, "TOPLEFT", rect.right * w, y)
end

-- `circ` is { cx, cy, r }. The radius is a fraction of the device's WIDTH on
-- both layouts: a radius measured against two different axes stops being a
-- circle, which is the rule that saved the dash's compass.
function Widgets.PlaceCircle(region, device, circ)
    local w, h = device:GetWidth(), device:GetHeight()
    local side = circ.r * 2 * w
    region:SetSize(side, side)
    region:ClearAllPoints()
    region:SetPoint("CENTER", device, "TOPLEFT", circ.cx * w, -circ.cy * h)
end

-- Draw one part as three textures so its decorative ends keep their shape at
-- any width: a left cap and a right cap at their natural size, and a middle
-- stretched between them. One button part draws at 65 pixels for "Here" and
-- 135 for "GO"; stretching the whole texture squashes the caps at one width
-- and stretches them at the other.
--
-- `capFraction` is how much of the part's width each cap takes, and
-- `capAspect` is that cap region's width over its height in the source art.
-- Both are read off the artwork, because the geometry file describes where
-- controls go and not how they are built. They are the only two hand-typed art
-- numbers in this plan; a squashed end cap is visible in one look, and the
-- checklist asks for that look.
--
-- Returns { left, middle, right, capFraction, name }, or nil when the part is
-- missing or will not load -- and every caller uses that, because a missing
-- texture must leave a working control. The table is also recorded as
-- `parent.slice`, so a later caller that only has the frame (SetButtonEnabled,
-- swapping in "button-disabled") can find and repoint the same three pieces
-- without the builder having kept the return value around.
function Widgets.Stretch3(parent, name, capFraction, capAspect)
    local part = ns.Data.Art and ns.Data.Art[name]
    if not part then
        return nil
    end
    local path = "Interface\\AddOns\\GoblinPS\\Media\\" .. part.file
    local span = part.r - part.l
    local cap = span * capFraction

    local function piece(l, r)
        local t = parent:CreateTexture(nil, "ARTWORK")
        if not t:SetTexture(path) then
            -- Only some pieces failing is possible in principle (they share
            -- one path today, but a future part could give caps and middle
            -- different files), and an unhidden, unanchored leftover region
            -- is exactly the kind of thing "a missing texture must leave a
            -- working control" is supposed to rule out.
            t:Hide()
            return nil
        end
        t:SetTexCoord(l, r, part.t, part.b)
        return t
    end

    local left, middle, right = piece(part.l, part.l + cap),
                                piece(part.l + cap, part.r - cap),
                                piece(part.r - cap, part.r)
    if not (left and middle and right) then
        return nil
    end
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    local slice = { left = left, middle = middle, right = right,
                    capFraction = capFraction, capAspect = capAspect, name = name }
    parent.slice = slice
    -- Legal to measure here and nowhere else: every caller builds its control
    -- with an explicit SetSize (W.Button, W.EditBox) and three-slices it
    -- before the layout has re-anchored anything, so this height is real.
    Widgets.Restretch3(parent, parent:GetHeight())
    return slice
end

-- Re-size a three-slice's end caps for a control that is now `height` tall:
-- the cap keeps the shape it was drawn at, so its drawn width is its own
-- aspect times that height, and it never squashes.
--
-- The height is an ARGUMENT, and it has to be. Stretch3 can only measure what
-- the control was built at; ApplyLayout then re-anchors every control corner
-- to corner from the geometry, and from that moment the control only INHERITS
-- its size -- which is the one thing this file's placement rule (see the note
-- above PlaceRect) says never to measure. GetHeight on such a frame answers
-- the stale explicit size until the client's layout pass, and 0 where there
-- never was one, so a Restretch3 that measured the frame would be wired in
-- correctly and change no number at all. Measured before this was fixed: GO's
-- cap drew 24 px in both layouts, where the wide geometry implies 32.50 and
-- the tall 33.75. So the caller works the height out the same way PlaceRect
-- works its offsets out: from the control's own rect and the frame that really
-- was given a size.
--
-- Answers false rather than erroring for a control carrying no slice (its
-- part was missing, and a missing texture must leave a working control), so
-- the caller can call it unconditionally.
function Widgets.Restretch3(frame, height)
    local slice = frame and frame.slice
    if not (slice and slice.capAspect) then
        return false
    end
    local width = height * slice.capAspect
    slice.left:SetWidth(width)
    slice.right:SetWidth(width)
    return true
end

-- Repoints an already-built three-slice's pieces at `part`, recomputing the
-- same capFraction crop against part's own l/r/t/b. Used to swap "button" for
-- "button-disabled" without rebuilding the pieces. Leaves the pieces exactly
-- as they were -- still showing whatever they showed before this call -- when
-- `part` is nil or its texture will not load, because a missing disabled
-- state must never lose the button.
local function reslice(slice, part)
    if not part then
        return false
    end
    local path = "Interface\\AddOns\\GoblinPS\\Media\\" .. part.file
    -- SetTexture takes hold of the region even when it reports failure (a
    -- missing file draws blank, it does not keep the old picture), so a
    -- half-failed swap has to be put back by hand rather than left alone.
    -- All three calls are made unconditionally, not `and`-chained: today the
    -- three pieces always share one path and so always succeed or fail
    -- together, but the moment caps and middle come from different files, an
    -- `and` chain would short-circuit after the first failure and never even
    -- attempt the rest.
    local prevLeft, prevMiddle, prevRight = slice.left:GetTexture(), slice.middle:GetTexture(), slice.right:GetTexture()
    local okLeft = slice.left:SetTexture(path)
    local okMiddle = slice.middle:SetTexture(path)
    local okRight = slice.right:SetTexture(path)
    if not (okLeft and okMiddle and okRight) then
        slice.left:SetTexture(prevLeft)
        slice.middle:SetTexture(prevMiddle)
        slice.right:SetTexture(prevRight)
        return false
    end
    local span = part.r - part.l
    local cap = span * slice.capFraction
    slice.left:SetTexCoord(part.l, part.l + cap, part.t, part.b)
    slice.middle:SetTexCoord(part.l + cap, part.r - cap, part.t, part.b)
    slice.right:SetTexCoord(part.r - cap, part.r, part.t, part.b)
    return true
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
-- `button.face` is the fallback: tinted here so it still shows the state
-- when no art loaded at all. When a three-slice sits over it (Stretch3
-- records `button.slice`), that art is opaque and would otherwise hide the
-- tint, so this also repoints the slice at the shipped "<name>-disabled"
-- part -- or leaves it showing whatever it already did if that part is
-- missing or will not load.
-- A button's label takes the colour of what it sits on: steel on the flat
-- brass face, green on the dark glass of the shipped button art, dim whenever
-- the button is disabled. Seen in the client 2026-09-21: Tall, Here and GO
-- kept the steel meant for the brass face, dark text on dark glass, and could
-- not be read.
local function paintLabel(button, enabled)
    if button.label then
        button.label:SetTextColor(rgb(not enabled and "dim" or (button.slice and "green" or "steel")))
    end
end

function Widgets.SetButtonEnabled(button, enabled)
    button:SetEnabled(enabled)
    paintLabel(button, enabled)
    local r, g, b = rgb(enabled and "brass" or "dim")
    button.face:SetColorTexture(r, g, b, 1)
    local slice = button.slice
    if slice then
        local partName = enabled and slice.name or (slice.name .. "-disabled")
        reslice(slice, ns.Data.Art and ns.Data.Art[partName])
    end
end

-- Swap a three-sliced button's art to "<name>-<suffix>", or back to the plain
-- part when `suffix` is nil. A disabled button answers neither: it is already
-- showing "<name>-disabled" and must keep showing it. reslice leaves the art
-- exactly as it was when the state's part is missing or will not load, so a
-- part that never shipped costs the button nothing.
local function buttonState(button, suffix)
    local slice = button.slice
    if slice and button:IsEnabled() then
        reslice(slice, ns.Data.Art and ns.Data.Art[suffix and (slice.name .. "-" .. suffix) or slice.name])
    end
end

-- Hover and pressed art for a three-sliced button. OnMouseUp goes back to
-- hover, not to the plain part: the cursor is still on the button.
function Widgets.WireButtonArt(button)
    paintLabel(button, button:IsEnabled())
    button:SetScript("OnEnter", function(self) buttonState(self, "hover") end)
    button:SetScript("OnLeave", function(self) buttonState(self, nil) end)
    button:SetScript("OnMouseDown", function(self) buttonState(self, "pressed") end)
    button:SetScript("OnMouseUp", function(self) buttonState(self, "hover") end)
end

function Widgets.EditBox(parent, width, height, placeholder)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width, height)
    e:SetAutoFocus(false)
    e:EnableMouse(true)
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
    return e
end

-- Show the grey hint only while the box is empty.
function Widgets.UpdatePlaceholder(editBox)
    editBox.placeholder:SetShown(editBox:GetText() == "")
end

-- One tooltip for a thing on screen, from plain { text, amber } lines. The
-- first line is the tooltip's title and keeps the client's own colour; every
-- line after is dim, or amber for a warning. Blizzard's shared GameTooltip,
-- not a template: SetOwner, AddLine and Show are on build 1.60.1.69913 and
-- Blizzard's own UI calls them throughout. The minimap button keeps its own.
function Widgets.ShowTooltip(owner, lines)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    for i, line in ipairs(lines) do
        if i == 1 then
            GameTooltip:AddLine(line.text)
        else
            GameTooltip:AddLine(line.text, rgb(line.amber and "amber" or "dim"))
        end
    end
    GameTooltip:Show()
end

return Widgets

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

return Widgets

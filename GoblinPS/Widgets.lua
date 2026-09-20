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

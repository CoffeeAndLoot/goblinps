local _, ns = ...

-- A draggable button on the minimap's ring; click opens the planner. Hand
-- rolled like HealMe's (no LibDBIcon). The angle and the hidden flag live in
-- the account-wide preferences. Right-click opens a small copy box with the
-- player's position, for correcting Data/Crossings.lua and Data/Links.lua.
local MinimapButton = {}
ns.MinimapButton = MinimapButton

local W = ns.Widgets

local ICON = "Interface\\AddOns\\GoblinPS\\Media\\icon"
local WHERE_WIDTH = 420
local WHERE_PAD = 10
local WHERE_BUTTON = 20

local button
local whereBox

-- From the minimap's real size: a fixed radius of 80 is right only for the
-- default 140px minimap and lands inside a resized one.
local function ringRadius()
    local width = Minimap:GetWidth()
    if not width or width <= 0 then
        width = 140
    end
    return (width / 2) + 10
end

local function place()
    if not button then
        return
    end
    local angle = math.rad(ns.Core.MinimapPrefs().angle)
    local radius = ringRadius()
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function angleFromCursor()
    local mx, my = Minimap:GetCenter()
    if not mx then
        return nil
    end
    local scale = Minimap:GetEffectiveScale()
    local px, py = GetCursorPosition()
    return math.deg(math.atan2(py / scale - my, px / scale - mx))
end

local function whileDragging()
    local angle = angleFromCursor()
    if angle then
        ns.Core.MinimapPrefs().angle = angle
        place()
    end
end

local function showTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("GoblinPS")
    GameTooltip:AddLine("Click to open the planner.", 1, 1, 1)
    GameTooltip:AddLine("Drag to move this button.", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Right-click to copy where you are.", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("May explode.", 0.88, 0.44, 0.11)
    GameTooltip:Show()
end

-- Built on first use: a plain frame holding the copyable line, a hint and a
-- Close button. Typing must not change the line (restored in OnTextChanged,
-- as Settings.lua's feedback box does); OnEditFocusGained highlights all of
-- it, and ShowWhere calls SetFocus so Ctrl+C works without a click first.
local function buildWhereBox()
    local f = W.Panel(UIParent, "body", "brass", 3)
    f:SetSize(WHERE_WIDTH, 86)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true) -- a click on the box must not fall through to whatever is under it
    f:Hide()

    local hint = W.Text(f, "dim")
    hint:SetText("Ctrl+C to copy, Esc to close")
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", WHERE_PAD, -WHERE_PAD)
    hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", -WHERE_PAD, -WHERE_PAD)

    local edit = W.EditBox(f, WHERE_WIDTH - WHERE_PAD * 2, WHERE_BUTTON + 2, "")
    edit:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -6)
    edit:SetPoint("TOPRIGHT", hint, "BOTTOMRIGHT", 0, -6)
    edit:SetMaxLetters(255)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(whereBox.line)
            self:HighlightText()
        end
    end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    -- Escape closes the box outright here, not just the edit focus: the box
    -- has one job and holding the escape key's usual "leave the field" step
    -- without closing anything would be a second keypress the brief does not
    -- ask for.
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        MinimapButton.HideWhere()
    end)

    local close = W.Button(f, "Close", 70, WHERE_BUTTON, function() MinimapButton.HideWhere() end)
    close:SetPoint("BOTTOM", f, "BOTTOM", 0, WHERE_PAD)

    whereBox = { frame = f, edit = edit, close = close, line = "" }
    ns.Core.CloseOnEscape(f, "GoblinPSWhereBox")
end

-- Shows the copy box with the player's current position, already selected
-- and focused so Ctrl+C works at once. Also said in chat, since that costs
-- nothing and the line is useful there too.
function MinimapButton.ShowWhere()
    if not whereBox then
        buildWhereBox()
    end
    whereBox.line = ns.Core.WhereLine()
    whereBox.edit:SetText(whereBox.line)
    if button then
        whereBox.frame:ClearAllPoints()
        whereBox.frame:SetPoint("TOP", button, "BOTTOM", 0, -6)
    end
    whereBox.frame:Show()
    whereBox.edit:SetFocus()
    ns.Core.Say(whereBox.line)
end

function MinimapButton.HideWhere()
    if whereBox then
        whereBox.edit:ClearFocus()
        whereBox.frame:Hide()
    end
end

function MinimapButton.ToggleWhere()
    if whereBox and whereBox.frame:IsShown() then
        MinimapButton.HideWhere()
    else
        MinimapButton.ShowWhere()
    end
end

-- For the desktop smoke test only.
function MinimapButton.Debug()
    return whereBox
end

local function build()
    local b = CreateFrame("Button", "GoblinPSMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton") -- right-click must not start a drag

    -- The art is its own brass ring with its own round alpha, so it fills the
    -- button and there is no Blizzard tracking border over it: that would be a
    -- ring inside a ring, and it would shrink the icon to 20 px of the 31.
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(b)
    icon:SetTexture(ICON)

    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    b:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            MinimapButton.ToggleWhere()
        else
            ns.Planner.Toggle()
        end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", whileDragging)
        GameTooltip:Hide()
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", showTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Call once at PLAYER_LOGIN, when the minimap and saved variables exist.
function MinimapButton.Initialize()
    if button or not Minimap then
        return
    end
    button = build()
    place()
    button:SetShown(not ns.Core.MinimapPrefs().hide)

    -- The minimap can be resized in Edit Mode or by a UI scale change.
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:SetScript("OnEvent", place)
end

function MinimapButton.SetHidden(hidden)
    ns.Core.MinimapPrefs().hide = hidden and true or false
    if button then
        button:SetShown(not hidden)
    end
end

return MinimapButton

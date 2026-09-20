local _, ns = ...

-- A draggable button on the minimap's ring; click opens the planner. Hand
-- rolled like HealMe's (no LibDBIcon). The angle and the hidden flag live in
-- the account-wide preferences.
local MinimapButton = {}
ns.MinimapButton = MinimapButton

local ICON = "Interface\\AddOns\\GoblinPS\\Media\\icon"

local button

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
    GameTooltip:AddLine("May explode.", 0.88, 0.44, 0.11)
    GameTooltip:Show()
end

local function build()
    local b = CreateFrame("Button", "GoblinPSMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp")
    b:RegisterForDrag("LeftButton")

    -- The art is its own brass ring with its own round alpha, so it fills the
    -- button and there is no Blizzard tracking border over it: that would be a
    -- ring inside a ring, and it would shrink the icon to 20 px of the 31.
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(b)
    icon:SetTexture(ICON)

    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    b:SetScript("OnClick", function() ns.Planner.Toggle() end)
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

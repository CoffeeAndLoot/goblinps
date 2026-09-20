-- A tiny stand-in for the WoW frame API, enough to build the GoblinPS windows
-- on the desktop and poke at them. It proves OUR code paths run (no nil
-- calls, no bad field names, the right text lands in the right widget). It
-- proves nothing about how Blizzard's real frames behave: that is what
-- docs/manual-test-checklist.md is for.
local Fake = {}

-- Paths for which SetTexture below reports failure, the way a texture the
-- client cannot find would. Tests add and remove entries; empty by default.
Fake.missingTextures = {}

-- Real widget methods our code calls beyond the ones modelled as full
-- methods below, each checked against the client source. Anything else is a
-- misspelt or invented call, and the fake raises instead of quietly doing
-- nothing, so a bad widget call fails on the desktop instead of only in game.
local ALLOWED_NOOP = {
    SetColorTexture = true, SetAlpha = true,
    SetJustifyH = true, SetFontObject = true,
    SetTextInsets = true, SetMaxLetters = true, SetAutoFocus = true, EnableMouse = true,
    SetMovable = true, SetClampedToScreen = true, RegisterForDrag = true, RegisterForClicks = true,
    StartMoving = true, StopMovingOrSizing = true, SetFrameStrata = true,
    SetHighlightTexture = true, RegisterEvent = true, SetOwner = true, AddLine = true,
}

local Region = {}
Region.__index = function(_, key)
    local method = Region[key]
    if method then
        return method
    end
    if ALLOWED_NOOP[key] then
        return function() end
    end
    -- Blizzard's own widget methods are always PascalCase (SetPoint,
    -- GetText, ...); anything shaped like one that we have not modelled or
    -- allow-listed is a misspelt or invented call, so raise. A lowercase key
    -- is the addon's own instance data (row.item, results.owner, ...), not
    -- yet set on this object: real frames answer that with plain nil too.
    if key:match("^%u") then
        error("fake_frames: unknown widget method '" .. key .. "'", 2)
    end
    return nil
end

local function new(kind, parent)
    return setmetatable({ kind = kind, parent = parent, shown = true, text = "", scripts = {}, points = {},
                          width = 0, height = 0 }, Region)
end

function Region:CreateTexture() return new("Texture", self) end
function Region:CreateFontString() return new("FontString", self) end
function Region:SetText(text) self.text = text or "" end
function Region:GetText() return self.text end
function Region:SetTextColor(r, g, b) self.color = { r, g, b } end
function Region:Show() self.shown = true end
function Region:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Region:SetShown(shown) self.shown = shown and true or false end
function Region:IsShown() return self.shown end
-- The real client answers from the cursor; tests set frame.mouseOver by hand.
function Region:IsMouseOver() return self.mouseOver == true end
function Region:SetScript(name, fn) self.scripts[name] = fn end
function Region:GetScript(name) return self.scripts[name] end
function Region:SetSize(w, h) self.width, self.height = w, h end
function Region:SetWidth(w) self.width = w end
function Region:SetHeight(h) self.height = h end
-- Recorded, not swallowed: a region told to fill another takes that one's
-- size in the real client, and code that lines two frames up by calling this
-- can only be checked if the fake carries the size across.
function Region:SetAllPoints(target)
    self.fills = target
    if target then
        self.width, self.height = target:GetWidth(), target:GetHeight()
    end
end

function Region:GetWidth() return self.width or (self.fills and self.fills:GetWidth()) end
function Region:GetHeight() return self.height or (self.fills and self.fills:GetHeight()) end
function Region:ClearAllPoints()
    self.points = {}
    self.lastPoint = nil
end

-- Normalises every SetPoint overload down to the five values the real
-- GetPoint returns (point, relativeTo, relativePoint, x, y), so a
-- save/restore round trip can be asserted the way the client really answers.
function Region:SetPoint(...)
    local n = select("#", ...)
    local point, relativeTo, relativePoint, x, y
    if n <= 1 then
        point = ...
        x, y = 0, 0
    elseif n == 2 then
        point, relativeTo = ...
        x, y = 0, 0
    elseif n == 3 then
        point, x, y = ...
    elseif n == 4 then
        point, relativeTo, x, y = ...
    else
        point, relativeTo, relativePoint, x, y = ...
    end
    local p = { point, relativeTo, relativePoint or point, x, y }
    self.points[#self.points + 1] = p
    self.lastPoint = p
end

-- Always the last point set, matching how the addon only ever keeps one
-- anchor (ClearAllPoints then a single SetPoint).
function Region:GetPoint()
    local p = self.lastPoint or { "CENTER", nil, "CENTER", 0, 0 }
    return p[1], p[2], p[3], p[4], p[5]
end

-- Recorded, not swallowed: whether a line wraps or truncates is a decision
-- this project requires every FontString to make, so a test has to see it.
function Region:SetWordWrap(wrap) self.wordWrap = wrap and true or false end

function Region:SetEnabled(enabled) self.enabled = enabled end

function Region:SetFrameLevel(level) self.frameLevel = level end
-- A frame with no explicit level sits one above its parent, the same
-- default the real client uses, so a test can compare levels meaningfully
-- even when a frame never calls SetFrameLevel itself.
function Region:GetFrameLevel()
    if self.frameLevel then
        return self.frameLevel
    end
    return self.parent and (self.parent:GetFrameLevel() + 1) or 0
end

-- The real SetTexture returns a documented success bool.
function Region:SetTexture(path)
    self.texture = path
    return path ~= nil and not Fake.missingTextures[path]
end
function Region:GetTexture() return self.texture end
function Region:SetTexCoord(l, r, t, b) self.texCoord = { l, r, t, b } end
function Region:SetRotation(radians) self.rotation = radians end
function Region:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
function Region:SetDrawLayer(layer) self.drawLayer = layer end
function Region:GetCenter() return 100, 100 end
function Region:GetEffectiveScale() return 1 end
function Region:ClearFocus()
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end

-- Test helpers: act like the player.
function Fake.Type(editBox, text)
    editBox:SetText(text)
    editBox.scripts.OnTextChanged(editBox, true)
end
function Fake.Click(button)
    button.scripts.OnClick(button, "LeftButton")
end
function Fake.MouseDown(frame)
    frame.scripts.OnMouseDown(frame, "LeftButton")
end

-- Installs the globals the UI files use. Returns a table of what was printed.
function Fake.Install()
    local printed = {}
    _G.CreateFrame = function(kind, name, parent)
        local f = new(kind, parent)
        if name then _G[name] = f end
        return f
    end
    _G.UIParent = new("Frame")
    _G.Minimap = new("Frame")
    _G.Minimap.width = 140
    _G.GameTooltip = new("GameTooltip")
    _G.UISpecialFrames = {}
    _G.GetCursorPosition = function() return 150, 100 end
    _G.SlashCmdList = {}
    _G.print = function(text) printed[#printed + 1] = text end
    Fake.missingTextures = {}
    return printed
end

return Fake

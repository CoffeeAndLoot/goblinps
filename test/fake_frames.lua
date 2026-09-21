-- A tiny stand-in for the WoW frame API, enough to build the GoblinPS windows
-- on the desktop and poke at them. It proves OUR code paths run (no nil
-- calls, no bad field names, the right text lands in the right widget). It
-- proves nothing about how Blizzard's real frames behave: that is what
-- docs/manual-test-checklist.md is for.
local Fake = {}

-- Paths for which SetTexture below reports failure, the way a texture the
-- client cannot find would. Tests add and remove entries; empty by default.
Fake.missingTextures = {}
-- The client's layout pass. Until this runs, a frame sized only by
-- SetAllPoints has no size to report -- which is when build() reads them.
-- Tests that want resolved sizes call Fake.Layout() first, and by having to
-- call it they say out loud that they are past build time.
Fake.laidOut = false
function Fake.Layout() Fake.laidOut = true end

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
    SetHorizTile = true, SetVertTile = true,
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
    -- No width or height on purpose: nil means "never given one", which is
    -- what lets GetWidth tell an explicit size from a size that only a layout
    -- pass could supply. A default of 0 is truthy in Lua and collapsed that
    -- distinction, which is how a device with no resolved sizes passed 257
    -- tests and drew wrong in the client.
    return setmetatable({ kind = kind, parent = parent, shown = true, text = "", scripts = {}, points = {},
                          regions = {} }, Region)
end

-- Recorded, not swallowed, on two counts. `regions` is every texture and
-- font string created ON this frame, which is the only way a test can ask
-- whether a frame carries art of its own -- a frame's own textures cannot be
-- hidden without hiding the frame, so "does this frame own regions" is a real
-- question about the layout. The draw layer is kept because stacking order
-- between textures on one frame is decided by it and nothing else.
local function region(kind, parent, layer)
    local r = new(kind, parent)
    r.drawLayer = layer
    parent.regions[#parent.regions + 1] = r
    return r
end

function Region:CreateTexture(_, layer) return region("Texture", self, layer) end
function Region:CreateFontString(_, layer) return region("FontString", self, layer) end
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
--
-- But it does NOT carry it across yet. In the client a frame sized only by
-- SetAllPoints has no resolved size until the layout pass runs, so GetWidth
-- on one during build() answers 0 -- and an earlier version of this fake
-- copied the size in immediately, which made every test agree with code that
-- was broken on screen. The dash unit's compass, arrow and all six lines of
-- text were misplaced or invisible in the client on 2026-09-20 while 257
-- tests passed. So: record the target, resolve the size only when
-- Fake.Layout() has run, and answer 0 before that, exactly as the client
-- does.
function Region:SetAllPoints(target)
    self.fills = target
end

function Region:GetWidth()
    if self.width then return self.width end
    if Fake.laidOut and self.fills then return self.fills:GetWidth() end
    return 0                            -- what the client answers, unresolved
end
function Region:GetHeight()
    if self.height then return self.height end
    if Fake.laidOut and self.fills then return self.fills:GetHeight() end
    return 0                            -- what the client answers, unresolved
end
function Region:ClearAllPoints()
    self.points = {}
    self.lastPoint = nil
end

-- Normalises every SetPoint overload down to the five values the real
-- GetPoint returns (point, relativeTo, relativePoint, x, y), so a
-- save/restore round trip can be asserted the way the client really answers.
--
-- Three arguments is the one ambiguous count: the client takes BOTH
-- (point, x, y) and (point, relativeTo, relativePoint), and it tells them
-- apart by type, so this does too. Reading every three-argument call as the
-- first form silently dropped the frame out of the second and left the
-- anchor string sitting in y -- which a test counting anchors could not see.
-- Four arguments has only one form, (point, relativeTo, x, y): there is no
-- overload whose second argument is a number at that count.
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
        if type((select(2, ...))) == "number" then
            point, x, y = ...
        else
            point, relativeTo, relativePoint = ...
            x, y = 0, 0
        end
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
    Fake.laidOut = false             -- a fresh client has not laid anything out
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

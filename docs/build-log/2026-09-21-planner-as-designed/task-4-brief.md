### Task 4: draw the route strip, with a tooltip on every stop

**Files:**
- Modify: `GoblinPS/Widgets.lua` (add `Widgets.ShowTooltip`)
- Modify: `GoblinPS/Planner.lua` (the strip)
- Modify: `test/fake_frames.lua` (tooltip lines, texture wrap modes)
- Modify: `test/test_ui.lua` (a new "the route strip" block)

**Interfaces:**
- Consumes: `ns.Strip.Layout` (Task 1), the wide geometry `stripTrack`,
  `screen` and `ns.Data.ArtGeometry.planner.strip` =
  `{ nodeDiameter = 0.06, lineThickness = 0.02, labelGap = 0.012 }` (Task 2),
  and the Task 3 planner.
- Produces: `W.ShowTooltip(owner, lines)` where `lines` is Strip's tooltip
  shape; `ui.strip` (a Frame on the screen) with `ui.strip.badges[i]`
  (Buttons, each with `.art`, `.flat`, `.label`, `.stop`) and
  `ui.strip.legs[i]` (`{ line = Texture, dot = Texture }`).

Numbers this task uses, all from the geometry at 650x416: the track runs
from x = 0.14375 x 650 = 93.4 px to 0.85 x 650 = 552.5 px (459.1 px), at
y = (0.46875 + 0.625) / 2 x 416 = 227.5 px. The visible ring is
0.06 x 650 = 39 px; the badge sprite is 1.5 times that, 58.5 px. The line box
is 0.02 x 650 = 13 px tall, glow included. The label gap is 0.012 x 650 = 7.8 px.
The shipped line parts are 128x16, so one tile is 13 x 8 = 104 px long.

Rulings this task carries (record them in the ledger):

- **The dot is drawn one line-box square (13 px).** The geometry gives the
  dot no size of its own; Codex's preview drew it at 20/32 of the line's
  box. Sizing it from `lineThickness` keeps it off hand-typed numbers.
- **A badge whose art will not load wears `node-ring`; if that fails too, a
  flat brass square the size of the ring.** The spec says "a flat circle",
  but a colour texture cannot be round without a mask, and no stock circular
  texture is verified on this build. The strip still reads either way.
- **The warning line's priority**: the first amber stop's detail, then a
  note about the route, then the flight path worth discovering.
- **Names are bounded symmetrically** around their badge: half the space
  between stops, and never past the screen's edge, so the end names stay on
  the glass (about 65 px wide at the two ends; the screen reserves 32.5 px
  beyond each end badge).

- [ ] **Step 1: Teach the fake frames the two things this needs**

In `test/fake_frames.lua`:

1. Remove `SetOwner = true, AddLine = true,` from `ALLOWED_NOOP`.
2. Replace `function Region:SetTexture(path)` with:

```lua
-- The real SetTexture returns a documented success bool. The two wrap modes
-- are recorded: a line that TILES along its leg needs "REPEAT", and a test
-- must be able to tell a tiled texture from a stretched one.
function Region:SetTexture(path, wrapH, wrapV)
    self.texture = path
    self.wrapH, self.wrapV = wrapH, wrapV
    return path ~= nil and not Fake.missingTextures[path]
end
```

3. In `Fake.Install`, replace `_G.GameTooltip = new("GameTooltip")` with:

```lua
    -- The one tooltip the client shares. SetOwner starts a fresh tooltip, as
    -- the real one does, and each line is kept with its colour so a test can
    -- read what the player would.
    local tip = new("GameTooltip")
    tip.lines = {}
    function tip.SetOwner(self, owner, anchor)
        self.owner, self.anchor, self.lines = owner, anchor, {}
    end
    function tip.AddLine(self, text, r, g, b)
        self.lines[#self.lines + 1] = { text = text, color = r and { r, g, b } or nil }
    end
    _G.GameTooltip = tip
```

Run the Lua suite: still green (the minimap button's tooltip now exercises
the modelled methods).

- [ ] **Step 2: Write the failing tests**

In `test/test_ui.lua`, add this block directly after the end of
`h.describe("the planner window", ...)`:

```lua
    h.describe("the route strip", function()
        local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"
        local amber, dim = ns.Widgets.COLOR.amber, ns.Widgets.COLOR.dim
        local function art(name) return MEDIA .. ns.Data.Art[name].file end
        local function pickTo(text)
            local ui = Planner.Debug()
            Fake.Type(ui.toBox, text)
            Fake.Click(ui.results.rows[1])
            return ui
        end
        local function track()
            local ui = Planner.Debug()
            local g, s = ns.Data.ArtGeometry.planner.wide, ns.Data.ArtGeometry.planner.strip
            local w, fh = ui.frame:GetWidth(), ui.frame:GetHeight()
            return { left = g.stripTrack.left * w, right = g.stripTrack.right * w,
                     cy = (g.stripTrack.top + g.stripTrack.bottom) / 2 * fh,
                     ring = s.nodeDiameter * w, thick = s.lineThickness * w }
        end
        local function near(a, b) return math.abs(a - b) < 0.01 end

        h.it("draws one badge per stop, wearing how you get there", function()
            if not Planner.Debug().frame:IsShown() then
                SlashCmdList.GOBLINPS("")
            end
            local ui = pickTo("delt")
            h.truthy(ui.strip:IsShown())
            local want = { "icon-horde", "icon-ride", "icon-flight", "icon-ride", "icon-zeppelin",
                           "node-destination" }
            for i, name in ipairs(want) do
                local b = ui.strip.badges[i]
                h.truthy(b and b:IsShown(), "badge " .. i)
                h.eq(b.art:GetTexture(), art(name), "badge " .. i)
            end
        end)

        h.it("puts each badge where the layout says, in real pixels", function()
            local ui, t = Planner.Debug(), track()
            for i = 1, 6 do
                local b = ui.strip.badges[i]
                local p = b.points[1]
                h.eq(p[1], "CENTER")
                h.truthy(p[2] == ui.frame, "measured from the window, which has a real size")
                h.truthy(near(p[4], t.left + (i - 1) / 5 * (t.right - t.left)), "badge " .. i .. " x")
                h.truthy(near(p[5], -t.cy), "badge " .. i .. " y")
                h.truthy(near(b:GetWidth(), t.ring * 1.5), "the sprite is 1.5 times the visible ring")
                h.eq(b:GetWidth(), b:GetHeight())
            end
        end)

        h.it("joins the stops with a solid first leg and dashed after, tiled not stretched", function()
            local ui, t = Planner.Debug(), track()
            local length = (t.right - t.left) / 5
            for i = 1, 5 do
                local line = ui.strip.legs[i].line
                h.eq(line:GetTexture(), art(i == 1 and "line-solid" or "line-dashed"), "leg " .. i)
                h.eq(line.wrapH, "REPEAT", "a dash keeps its length on any leg")
                local part = ns.Data.Art["line-dashed"]
                h.truthy(near(line.texCoord[2], length / (t.thick * part.cw / part.ch)),
                         "one tile per line-box times the part's own aspect")
                h.truthy(near(line:GetWidth(), length))
                h.truthy(near(line:GetHeight(), t.thick))
                h.truthy(near(line.points[1][4], t.left + (i - 1) * length), "starts at its badge's centre")
                local dot = ui.strip.legs[i].dot
                h.eq(dot:GetTexture(), art("line-dot"))
                h.truthy(near(dot.points[1][4], t.left + (i - 0.5) * length), "the dot sits mid-leg")
            end
        end)

        h.it("draws the line under the badges and the strip above the screen's fills", function()
            local ui = Planner.Debug()
            h.truthy(ui.strip.legs[1].line.parent == ui.strip, "the line is the strip's own texture")
            h.truthy(ui.strip.badges[1].parent == ui.strip, "each badge is a child frame over it")
            h.truthy(ui.strip.badges[1]:GetFrameLevel() > ui.strip:GetFrameLevel())
            h.truthy(ui.strip.parent == ui.screen, "and the strip is a child of the opaque screen")
            h.truthy(ui.strip:GetFrameLevel() > ui.screen:GetFrameLevel())
        end)

        h.it("names the stops while there is room, each name bounded", function()
            local ui = Planner.Debug()
            h.eq(ui.strip.badges[1].label:GetText(), "You are here")
            h.eq(ui.strip.badges[2].label:GetText(), "Alpha")
            for i = 1, 6 do
                local label = ui.strip.badges[i].label
                h.truthy(label:IsShown(), "91.8 px between stops is more than two 39 px rings")
                h.eq(#label.points, 2, "two horizontal anchors, so it truncates")
                h.eq(label.wordWrap, false)
            end
        end)

        h.it("drops every name into the tooltips when the stops crowd", function()
            local ui, state = Planner.Debug()
            local saved = state.plan
            local steps = {}
            for i = 1, 8 do
                steps[i] = { kind = "ride", to = { name = "Stop " .. i }, seconds = 60, copper = 0 }
            end
            state.plan = { to = { name = "Stop 8" }, notes = {}, level = 60,
                           result = { steps = steps, seconds = 480, copper = 0 } }
            Planner.Refresh()
            for i = 1, 9 do
                h.truthy(ui.strip.badges[i]:IsShown(), "every stop still shows")
                h.falsy(ui.strip.badges[i].label:IsShown(), "57 px between stops: names go")
            end
            state.plan = saved
            Planner.Refresh()
            h.falsy(ui.strip.badges[7]:IsShown(), "a shorter route hides the spare badges")
            h.falsy(ui.strip.badges[7].label:IsShown())
            h.falsy(ui.strip.legs[6].line:IsShown(), "and the spare legs")
            h.falsy(ui.strip.legs[6].dot:IsShown())
        end)

        h.it("shows a stop's lines on hover and puts them away on leave", function()
            local ui = Planner.Debug()
            local b = ui.strip.badges[3]
            b.scripts.OnEnter(b)
            h.truthy(GameTooltip.owner == b)
            h.truthy(GameTooltip:IsShown())
            h.eq(GameTooltip.lines[1].text, "Fly to Bravo")
            h.eq(GameTooltip.lines[2].text, "~4 min")
            b.scripts.OnLeave(b)
            h.falsy(GameTooltip:IsShown())
        end)

        h.it("turns a hazard's detail amber and names it on the warning line", function()
            local ui = pickTo("hotel")
            local b = ui.strip.badges[2]
            b.scripts.OnEnter(b)
            h.eq(GameTooltip.lines[1].text, "Ride to the North Gate")
            h.eq(GameTooltip.lines[3].text, "into Northland · trolls on the bridge")
            h.eq(GameTooltip.lines[3].color[1], amber[1])
            h.eq(GameTooltip.lines[3].color[2], amber[2])
            h.eq(GameTooltip.lines[3].color[3], amber[3])
            local last = ui.strip.badges[3]
            last.scripts.OnEnter(last)
            h.eq(GameTooltip.lines[3].text, "in Northland · level 30-40")
            h.eq(GameTooltip.lines[3].color[1], dim[1], "level 60 in a 30-40 zone is no warning")
            GameTooltip:Hide()
            h.eq(ui.hint:GetText(), "the North Gate: into Northland · trolls on the bridge")
        end)

        h.it("wears the boot and says Walk for a low-level character", function()
            level = 1
            local ui = pickTo("hotel")
            local b = ui.strip.badges[2]
            h.eq(b.art:GetTexture(), art("icon-walk"))
            b.scripts.OnEnter(b)
            h.eq(GameTooltip.lines[1].text, "Walk to the North Gate")
            GameTooltip:Hide()
            level = 60
        end)

        h.it("says so on the tooltip when the crossings table has a hole", function()
            local ui = pickTo("lostland")
            local b = ui.strip.badges[2]
            b.scripts.OnEnter(b)
            h.eq(GameTooltip.lines[1].text, "Ride toward Lostland (no mapped path)")
            h.eq(#GameTooltip.lines, 2, "a straight line has no zone detail")
            GameTooltip:Hide()
        end)

        h.it("keeps a readable strip when a badge's art will not load", function()
            local ui = pickTo("delt")
            Fake.missingTextures[art("icon-flight")] = true
            Planner.Refresh()
            h.eq(ui.strip.badges[3].art:GetTexture(), art("node-ring"), "the plain ring stands in")
            Fake.missingTextures[art("node-ring")] = true
            Planner.Refresh()
            h.falsy(ui.strip.badges[3].art:IsShown())
            h.truthy(ui.strip.badges[3].flat:IsShown(), "and failing that, a flat marker")
            Fake.missingTextures[art("icon-flight")] = nil
            Fake.missingTextures[art("node-ring")] = nil
            Planner.Refresh()
            h.truthy(ui.strip.badges[3].art:IsShown())
            h.falsy(ui.strip.badges[3].flat:IsShown())
        end)

        h.it("draws no strip without a route", function()
            local ui = pickTo("westland")
            h.falsy(ui.strip:IsShown(), "you're already there: words, not a strip")
            h.truthy(ui.notes:IsShown())
            pickTo("delt")
            h.truthy(ui.strip:IsShown())
        end)

        h.it("W.ShowTooltip colours every line after the first, amber for a warning", function()
            local owner = CreateFrame("Button", nil, UIParent)
            W.ShowTooltip(owner, { { text = "Ride to X" }, { text = "~2 min" },
                                   { text = "careful", amber = true } })
            h.eq(GameTooltip.anchor, "ANCHOR_TOP")
            h.eq(GameTooltip.lines[1].color, nil, "the first line keeps the tooltip's own title colour")
            h.eq(GameTooltip.lines[2].color[1], dim[1])
            h.eq(GameTooltip.lines[3].color[1], amber[1])
            GameTooltip:Hide()
        end)
    end)
```

Run the Lua suite. Expected: the new block fails (`ui.strip` is nil,
`W.ShowTooltip` is nil).

- [ ] **Step 3: Add `W.ShowTooltip` to `GoblinPS/Widgets.lua`**

Directly before `return Widgets`:

```lua
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
```

- [ ] **Step 4: Draw the strip in `GoblinPS/Planner.lua`**

Add after `local MEDIA = ...` and `geo()`:

```lua
-- The badge art is a 128 px ring on a 192 px canvas, and the geometry's
-- nodeDiameter is the RING, so the whole sprite is 1.5 times it. Size from
-- the ring alone and every stop draws a third too small.
local SPRITE = 1.5

-- The strip's measurements in real pixels, all read off the window: it is
-- the frame given an explicit SetSize, so measuring it is legal.
local function stripMetrics(g)
    local s = ns.Data.ArtGeometry.planner.strip
    local w, h = ui.frame:GetWidth(), ui.frame:GetHeight()
    return { left = g.stripTrack.left * w, right = g.stripTrack.right * w,
             cy = (g.stripTrack.top + g.stripTrack.bottom) / 2 * h,
             ring = s.nodeDiameter * w, thick = s.lineThickness * w, gap = s.labelGap * w,
             screenLeft = g.screen.left * w, screenRight = g.screen.right * w }
end

-- Badges and legs are pooled: made the first time a route needs that many,
-- reused after, hidden when a shorter route needs fewer.
local function badge(i)
    local b = ui.strip.badges[i]
    if b then
        return b
    end
    b = CreateFrame("Button", nil, ui.strip)
    b.flat = b:CreateTexture(nil, "BACKGROUND")
    b.flat:SetPoint("CENTER")
    local c = W.COLOR.brass
    b.flat:SetColorTexture(c[1], c[2], c[3], 1)
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetAllPoints(b)
    b.label = W.Text(ui.strip, "green", nil, "CENTER")
    b:SetScript("OnEnter", function(self) W.ShowTooltip(self, self.stop.tooltip) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.strip.badges[i] = b
    return b
end

local function leg(i)
    local l = ui.strip.legs[i]
    if not l then
        -- On the strip itself, so the badges -- child frames -- cover their ends.
        l = { line = ui.strip:CreateTexture(nil, "BORDER"), dot = ui.strip:CreateTexture(nil, "ARTWORK") }
        ui.strip.legs[i] = l
    end
    return l
end

-- A badge wears its part; failing that the plain ring; failing that a flat
-- marker the size of the ring. The strip must read with no art at all.
local function wear(b, name)
    for _, try in ipairs({ name, "node-ring" }) do
        local part = ns.Data.Art and ns.Data.Art[try]
        if part and b.art:SetTexture(MEDIA .. part.file) then
            b.art:SetTexCoord(part.l, part.r, part.t, part.b)
            b.art:Show()
            b.flat:Hide()
            return
        end
    end
    b.art:Hide()
    b.flat:Show()
end

-- A line part TILES along its leg at its own aspect, so a dash keeps its
-- length on a short leg and a long one alike; only the last tile is cut.
-- One tile is the line box's height times the part's width over its height.
-- That needs the part shipped unpadded -- its crop the whole texture -- as
-- planner-panel is, since tiling a padded part repeats the padding. Padded
-- or missing, the leg falls back to a flat green stroke a quarter of the
-- box: the glow box itself, filled solid, would read as a bar.
local function drawLine(t, name, length, thick)
    local part = ns.Data.Art and ns.Data.Art[name]
    local whole = part and part.l == 0 and part.r == 1 and part.t == 0 and part.b == 1
    if whole and t:SetTexture(MEDIA .. part.file, "REPEAT", "CLAMP") then
        t:SetTexCoord(0, length / (thick * part.cw / part.ch), 0, 1)
        t:SetHeight(thick)
    else
        local c = W.COLOR.green
        t:SetColorTexture(c[1], c[2], c[3], 1)
        t:SetHeight(thick / 4)
    end
end

local function drawStrip(layout, m)
    local span = m.right - m.left
    local function at(x) return m.left + x * span end
    local sprite = m.ring * SPRITE
    for i, stop in ipairs(layout.stops) do
        local b, x = badge(i), at(stop.x)
        b.stop = stop
        b:SetSize(sprite, sprite)
        b:ClearAllPoints()
        b:SetPoint("CENTER", ui.frame, "TOPLEFT", x, -m.cy)
        b.flat:SetSize(m.ring, m.ring)
        wear(b, stop.badge)
        b:Show()
        -- Half the space to the next stop either side, never off the glass.
        local half = math.min(layout.spacing / 2, x - m.screenLeft, m.screenRight - x)
        local top = -(m.cy + m.ring / 2 + m.gap)
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", x - half, top)
        b.label:SetPoint("TOPRIGHT", ui.frame, "TOPLEFT", x + half, top)
        b.label:SetText(stop.label)
        b.label:SetShown(layout.labels)
    end
    for i = #layout.stops + 1, #ui.strip.badges do
        ui.strip.badges[i]:Hide()
        ui.strip.badges[i].label:Hide()
    end
    for i, lg in ipairs(layout.legs) do
        local l = leg(i)
        local x1, x2 = at(layout.stops[lg.from].x), at(layout.stops[lg.to].x)
        l.line:ClearAllPoints()
        l.line:SetPoint("LEFT", ui.frame, "TOPLEFT", x1, -m.cy)
        l.line:SetWidth(x2 - x1)
        drawLine(l.line, lg.style == "solid" and "line-solid" or "line-dashed", x2 - x1, m.thick)
        l.line:Show()
        local dot = ns.Data.Art and ns.Data.Art["line-dot"]
        l.dot:ClearAllPoints()
        l.dot:SetPoint("CENTER", ui.frame, "TOPLEFT", at(lg.mid), -m.cy)
        l.dot:SetSize(m.thick, m.thick)
        if dot and l.dot:SetTexture(MEDIA .. dot.file) then
            l.dot:SetTexCoord(dot.l, dot.r, dot.t, dot.b)
            l.dot:Show()
        else
            l.dot:Hide()   -- decoration: the strip reads without it
        end
    end
    for i = #layout.legs + 1, #ui.strip.legs do
        ui.strip.legs[i].line:Hide()
        ui.strip.legs[i].dot:Hide()
    end
end
```

In `Planner.Refresh`, after `local routed = #steps > 0`, add:

```lua
    local g = geo()
    local layout
    if routed and g then
        local m = stripMetrics(g)
        layout = ns.Strip.Layout(ns.Data, steps, { faction = ns.Core.Faction(), level = plan.level,
                                                   trackWidth = m.right - m.left, badgeWidth = m.ring })
        drawStrip(layout, m)
    end
    ui.strip:SetShown(layout ~= nil)
```

and change the hint block so the warning comes first:

```lua
        -- One amber line under the strip. What the player must know first
        -- wins: a stop in a dangerous place, then a note about the route
        -- itself, then a flight path worth discovering.
        if layout and layout.warning then
            hint = layout.warning
        elseif notes ~= "" then
            hint = notes
        elseif plan.hint then
            hint = ns.Route.HintText(plan.hint)
        end
```

In `build()`, directly after the `backdrop` block, add:

```lua
    -- The route strip, a child of the screen so it draws over the screen's
    -- opaque fills and its scenery -- the invisible-backdrop fault was exactly
    -- a picture under an opaque panel. Its badges and legs are placed against
    -- the window, which has a real size, by drawStrip.
    local strip = CreateFrame("Frame", nil, screen)
    strip:SetAllPoints(screen)
    strip.badges, strip.legs = {}, {}
    strip:Hide()
```

and add `strip = strip` to the `ui` table.

- [ ] **Step 5: Run every gate**

Lua suite green (report the count; the new block adds 13). Python suite and
`check_art.py` green. luacheck and the language server from PowerShell at
zero warnings.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Planner.lua GoblinPS/Widgets.lua test/fake_frames.lua test/test_ui.lua
git commit -m "Planner: draw the route strip, a tooltip on every stop" -m "Each stop wears how you get there, joined by the glowing line: solid for the leg about to start, dashed after, tiled so a dash keeps its length, a dot mid-leg. Names give way to tooltips when crowded, the first amber detail becomes the warning under the strip, and a badge whose art fails still reads." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---


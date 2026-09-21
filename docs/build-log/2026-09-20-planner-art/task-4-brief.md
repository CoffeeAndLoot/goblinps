### Task 4: The planner frame and its chrome, from geometry

**Files:**
- Modify: `GoblinPS/Planner.lua`
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `ns.Data.ArtGeometry.planner` (Task 2), `W.PlaceRect`,
  `W.PlaceLine`, `W.PlaceCircle` (Task 3), `ns.Data.Art[...]` (Task 1).
- Produces, for Task 5: `ui.artLayer`, `ui.frameArt`, `ui.flat`, `ui.content`,
  and a file-local `geo()` returning the active layout's geometry table.

**The frame's own panel is the same bug the dash had.** `Planner.lua:217` is
`W.Panel(UIParent, "body", "brass", 3)`. `Widgets.Panel` lays two opaque
textures directly on that frame and returns only the frame, so nothing can ever
hide them. The planner frame art has transparent margins exactly as the dash
housing does. Fix it the same way the dash was fixed: build the frame bare and
give the no-art fallback its own hideable frame.

**Frame levels, set explicitly.** A child frame draws above every draw layer of
its parent, and within one frame and layer the later-created region wins:

| Level | Frame | Holds |
|---|---|---|
| base | `f` | nothing; it is bare |
| base | `flat` | the flat-colour fallback panel |
| base + 1 | `artLayer` | the frame art, plates, panel backing |
| base + 2 | `content` | every widget and FontString |
| base + 3 | `results` | the search overlay, which covers content |

- [ ] **Step 1: Write the failing test**

Add to the planner block in `test/test_ui.lua`:

```lua
        h.it("keeps the window at the art's exact aspect ratio", function()
            -- 1600x1024 is 25:16 and 1024x1600 is 16:25. The old 660x400 and
            -- 390x600 were 1.65 and 0.65, so the wide frame would have drawn
            -- about 6% too wide -- the fault that made the dash's first design
            -- render as an oval, which took a client run to see.
            local g = ns.Data.ArtGeometry.planner
            for _, mode in ipairs({ "wide", "tall" }) do
                local size = ns.Planner.SIZE[mode]
                local canvas = g[mode].canvas
                h.truthy(math.abs(size[1] / size[2] - canvas.w / canvas.h) < 0.001,
                         mode .. " must keep the art's aspect ratio")
            end
        end)

        h.it("carries no art of its own on the window frame", function()
            -- Widgets.Panel lays two opaque textures on the frame it makes and
            -- returns only the frame, so nothing can hide them. The planner
            -- art has transparent margins; an unhideable rectangle behind it
            -- boxes in a window that is not a rectangle. Fixed once on the
            -- dash already.
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.eq(#ui.frame.regions, 0,
                 "the window frame must own no regions; the fallback is its own frame")
            h.truthy(ui.flat, "and the fallback frame exists")
        end)

        h.it("hides the flat fallback once the frame art loads", function()
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.truthy(ui.frameArt, "the frame art loaded in the test fixture")
            h.falsy(ui.flat:IsShown(), "so the coloured rectangle goes")
        end)

        h.it("stacks the art under the content", function()
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.truthy(ui.content:GetFrameLevel() > ui.artLayer:GetFrameLevel(),
                     "nothing the player reads is ever behind the chassis")
            h.truthy(ui.results:GetFrameLevel() > ui.content:GetFrameLevel(),
                     "the search overlay covers what it drops over")
        end)

        h.it("places the chrome from the geometry, in real pixels", function()
            -- Pin the position, not just the size: a test that checks how big
            -- a thing is cannot tell you it is in the wrong place.
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout("wide")
            local ui = ns.Planner.Debug()
            local g = ns.Data.ArtGeometry.planner.wide
            local w = ui.frame:GetWidth()
            for _, name in ipairs({ "close", "gear" }) do
                local button, circ = ui[name], g[name .. "Button"]
                h.truthy(button, name .. " is missing")
                h.truthy(math.abs(button:GetWidth() - circ.r * 2 * w) < 1,
                         name .. " is sized from geometry." .. name .. "Button.r")
                h.truthy(math.abs(button.points[1][4] - circ.cx * w) < 1,
                         name .. " sits at geometry." .. name .. "Button.cx, got "
                         .. tostring(button.points[1][4]))
            end
            h.truthy(math.abs(ui.titlePlate.points[1][4] - g.titlePlate.left * w) < 1,
                     "the title plate starts where the geometry says")
        end)
```

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: FAIL on the aspect-ratio test (660/400 is 1.65,
not 1.5625), and FAIL on `carries no art of its own` with `expected "0", actual
"2"` — the two textures `Widgets.Panel` lays on the frame.

- [ ] **Step 3: Rebuild the frame and the chrome**

In `GoblinPS/Planner.lua`, replace the size constant:

```lua
-- The window's rectangle on screen. The art is 1600x1024 and 1024x1600, so
-- these keep those shapes exactly; everything inside is placed as a fraction
-- of them, from the geometry the art tool generates. Nothing here is a
-- measured guess.
Planner.SIZE = { wide = { 650, 416 }, tall = { 384, 600 } }
```

Add a file-local accessor beside the other locals:

```lua
local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"

-- The active layout's geometry, or nil when the generated table is absent.
-- Gated on the geometry alone: whether the parts shipped is a different
-- question, and answering it here would drop the whole layout to its fallback
-- while a perfectly good geometry sat there unread.
local function geo(mode)
    local g = ns.Data.ArtGeometry and ns.Data.ArtGeometry.planner
    return g and g[mode or ns.Core.Layout()]
end

-- Lay a shipped part over `parent`, cropping the power-of-two padding away.
-- Returns nil when the part is missing or the texture will not load, and every
-- caller uses that: a missing texture must leave a working window.
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
```

In `build()`, replace the opening `local f = W.Panel(UIParent, "body", "brass", 3)`
with a bare frame and a hideable fallback, and add the three stacked frames:

```lua
    -- Bare on purpose. A texture created on this frame could only be taken off
    -- screen by hiding the frame, and the window art has transparent margins,
    -- so an unhideable rectangle behind it boxes in a window that is not a
    -- rectangle. The dash unit shipped that fault once already.
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(Planner.SIZE.wide[1], Planner.SIZE.wide[2])
```

Everything else in that opening block — strata, movable, mouse, clamped, drag
scripts, `OnMouseDown`, `Hide` — stays exactly as it is.

Then, after `f:Hide()`:

```lua
    local base = f:GetFrameLevel()

    -- The flat colour is the fallback for art that will not load. It is its
    -- own frame so it can be hidden as a unit the moment the real frame art
    -- arrives.
    local flat = W.Panel(f, "body", "brass", 3)
    flat:SetAllPoints(f)
    flat:SetFrameLevel(base)

    local artLayer = CreateFrame("Frame", nil, f)
    artLayer:SetAllPoints(f)
    artLayer:SetFrameLevel(base + 1)

    local content = CreateFrame("Frame", nil, f)
    content:SetAllPoints(f)
    content:SetFrameLevel(base + 2)

    -- The window's own chassis. ApplyLayout swaps the texture between the two
    -- frames, so create it empty here and let ApplyLayout fill it.
    local frameArt = artLayer:CreateTexture(nil, "BACKGROUND")
    frameArt:SetAllPoints(artLayer)

    -- The plates carry art but are NOT SetAllPoints to their parent: each sits
    -- in its own rect, which ApplyLayout places. That is the one difference
    -- from `art()` above, and it is why they cannot use it.
    local function plate(name)
        local part = ns.Data.Art and ns.Data.Art[name]
        if not part then
            return nil
        end
        local t = artLayer:CreateTexture(nil, "ARTWORK")
        if not t:SetTexture(MEDIA .. part.file) then
            t:Hide()
            return nil
        end
        t:SetTexCoord(part.l, part.r, part.t, part.b)
        return t
    end
    local titlePlate = plate("title-plate")
    local taglinePlate = plate("tagline-plate")
```

Delete the orange `stripe` texture entirely: it was a flat-colour flourish for
a window with no art, and it draws across the top of the brass.

The title and tagline FontStrings stay, but move to `content` and lose their
hand-typed anchors — `ApplyLayout` will place them. Change their parent from
`f` to `content` and delete their `SetPoint` calls.

Replace the close and layout buttons, and add the gear:

```lua
    local close = CreateFrame("Button", nil, content)
    close:RegisterForClicks("LeftButtonUp")
    close:SetScript("OnClick", function()
        dismiss()
        f:Hide()
    end)
    local closeArt = art(close, "close", "ARTWORK")
    if not closeArt then
        W.Fill(close, "ARTWORK", "hazard")
    end
    local hover = ns.Data.Art and ns.Data.Art["close-hover"]
    if hover then
        close:SetHighlightTexture(MEDIA .. hover.file, "ADD")
    end

    -- The art has a socket beside the To box and the geometry places it, but
    -- no such control exists today: the results list only appears while you
    -- type. An empty socket reads as a fault, and a way to browse every
    -- destination without knowing its name is worth having, so the button
    -- opens the same list with an empty query.
    local dropdown = CreateFrame("Button", nil, content)
    dropdown:RegisterForClicks("LeftButtonUp")
    dropdown:SetScript("OnClick", function()
        if ui.results:IsShown() and ui.results.owner == ui.toBox then
            hideResults()
        else
            showResults(ui.toBox)
        end
    end)
    local dropdownArt = art(dropdown, "dropdown-button", "ARTWORK")
    if not dropdownArt then
        W.Fill(dropdown, "ARTWORK", "steel")
    end

    -- The gear opens settings, which is a later plan. It is drawn and placed
    -- now because the art has a socket for it and an empty socket reads as a
    -- fault; it says so when clicked rather than doing nothing.
    local gear = CreateFrame("Button", nil, content)
    gear:RegisterForClicks("LeftButtonUp")
    gear:SetScript("OnClick", function()
        ns.Core.Say("Settings are not built yet.")
    end)
    local gearArt = art(gear, "gear", "ARTWORK")
    if not gearArt then
        W.Fill(gear, "ARTWORK", "steel")
    end
    local gearHover = ns.Data.Art and ns.Data.Art["gear-hover"]
    if gearHover then
        gear:SetHighlightTexture(MEDIA .. gearHover.file, "ADD")
    end
```

Keep `layoutButton` as a `W.Button` — it carries a runtime "Wide"/"Tall" label
and the existing widget already draws one. Delete its `SetPoint`.

**There is no tools button.** `close.png` is the crossed-wrench X, and the
geometry's `tools_button` was an alias that Task 2 dropped before it reached
the addon. Do not create a second control.

Extend the `ui` table with the new names: `artLayer`, `content`, `flat`,
`frameArt`, `titlePlate`, `taglinePlate`, `close`, `gear`, `dropdown`,
`title` and `tagline`. The last two already exist as locals in `build()` but
have never been on the `ui` table, and `ApplyLayout` now places them.

`showResults` and `hideResults` are declared above `build()` already, so the
dropdown's handler can call them. `candidatesFor` returns every candidate when
the box is empty, which is what makes an empty query list everything.

- [ ] **Step 4: Place the chrome in `ApplyLayout`**

`ApplyLayout` is the only function that differs between the two shapes, and it
is now the only place any coordinate appears. Replace its body:

```lua
function Planner.ApplyLayout(mode)
    if not ui then
        return
    end
    mode = (mode == "tall") and "tall" or "wide"
    local size = Planner.SIZE[mode]
    local f = ui.frame
    -- The explicit size first, before anything reads it: every helper below
    -- measures this frame, and a frame with no size measures 0.
    f:SetSize(size[1], size[2])

    local part = ns.Data.Art and ns.Data.Art["planner-frame-" .. mode]
    if part and ui.frameArt:SetTexture(MEDIA .. part.file) then
        ui.frameArt:SetTexCoord(part.l, part.r, part.t, part.b)
        ui.frameArt:Show()
        ui.flat:Hide()
    else
        ui.frameArt:Hide()
        ui.flat:Show()
    end

    local g = geo(mode)
    if g then
        W.PlaceRect(ui.titlePlate, f, g.titlePlate)
        W.PlaceRect(ui.taglinePlate, f, g.taglinePlate)
        W.PlaceLine(ui.title, f, g.titlePlate)
        W.PlaceLine(ui.tagline, f, g.taglinePlate)
        W.PlaceCircle(ui.close, f, g.closeButton)
        W.PlaceCircle(ui.gear, f, g.gearButton)
        W.PlaceCircle(ui.dropdown, f, g.dropdownButton)
        W.PlaceRect(ui.layoutButton, f, g.layoutButton)
    end

    ui.layoutButton.label:SetText(mode == "tall" and "Wide" or "Tall")
end
```

`plate()` returns nil when a part is missing, so guard the two plate
placements with `if ui.titlePlate then` and `if ui.taglinePlate then`. The two
FontStrings always exist and are always placed.

Task 5 adds its placements **inside this same `if g then` block**, not in a
second one: one block, one condition, one place to look.

- [ ] **Step 5: Run the tests to verify they pass**

Run the Lua suite. Expected: green. The planner's existing tests must still
pass; if one of them reads a widget that moved, the read may change and the
assertion may not.

- [ ] **Step 6: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 7: Commit**

```bash
git add GoblinPS/Planner.lua test/test_ui.lua
git commit -m "The planner frame wears its art, placed from the geometry" -m "The window is bare, its fallback is a frame that can be hidden, and its size matches the art's aspect ratio exactly -- three faults the dash unit found in the client, fixed here before this one has been seen at all." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---


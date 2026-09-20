### Task 2: The device, rebuilt from the geometry

**Files:**
- Modify: `GoblinPS/Dash.lua`
- Modify: `GoblinPS/GoblinPS.toc` (version `2026.09.20.3`)
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `ns.Data.Art["dash2-*"]` and `ns.Data.ArtGeometry` from Task 1.
- Produces, for Task 3: a `ui` table whose art and frames are in place, with `ui.artLayer`, `ui.glass`, `ui.compass`, `ui.arrow`, `ui.stepsScreen`, `ui.etaScreen`, `ui.housingFrame`, `ui.housing` and `ui.content`; and a file-local `place(region, parent, rect)` that Task 3 calls directly. `place` is **not** put on the `ui` table: both tasks edit the same file, so the local is already in scope, and an export nothing reads is dead weight.

This task replaces the device's **appearance** only. Do not touch `Dash.Tick`, `Dash.Refresh`, `Dash.Start`, `Dash.Stop` or anything in `Trip.lua`. The old widgets keep their names so the trip loop still writes to them; Task 3 moves the text.

**The shape of it.** The device is one rectangle, 1024 by 1280 in the art, drawn at `Dash.SIZE`. Five layers fill that rectangle corner to corner, in this order, bottom to top: glass, compass, arrow, steps screen, ETA screen, then the housing over all of them. The compass and the arrow are the exceptions: both are square textures centred on the dial, because both rotate.

**Frame levels, set explicitly.** Plan 4 lost an afternoon to this: a child frame draws above every draw layer of its parent, and within one frame and layer the later-created region wins. So:

| Level | Frame | Holds |
|---|---|---|
| base | `f` | the flat-colour fallback |
| base + 1 | `artLayer` | glass, compass, arrow, both screens |
| base + 2 | `housing` | the chassis, over the art, with its holes |
| base + 3 | `content` | every FontString (Task 3) |
| base + 4 | `stop` | the button (Task 3) |

- [ ] **Step 1: Write the failing tests**

Add to `test/test_ui.lua`, in the dash block:

```lua
        h.it("lays the five shared layers on one rectangle", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            -- They were drawn corner to corner on one canvas: any that is
            -- sized differently is drawn somewhere the artist did not mean.
            for _, name in ipairs({ "glass", "stepsScreen", "etaScreen", "housing" }) do
                h.truthy(ui[name], name .. " is missing")
                h.eq(ui[name]:GetWidth(), ui.artLayer:GetWidth(), name .. " must fill the device")
                h.eq(ui[name]:GetHeight(), ui.artLayer:GetHeight(), name .. " must fill the device")
            end
        end)

        h.it("makes the compass and the arrow square, because both turn", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            for _, name in ipairs({ "compass", "arrow" }) do
                h.eq(ui[name]:GetWidth(), ui[name]:GetHeight(),
                     name .. " rotates about its own middle, so it must be square")
            end
        end)

        h.it("takes every position from the generated geometry, not from constants", function()
            local g = ns.Data.ArtGeometry
            h.truthy(g, "Task 1 must have written ns.Data.ArtGeometry")
            Dash.Start(plan)
            local ui = Dash.Debug()
            -- The compass is sized as a share of the device, so a change in
            -- the art reaches the layout by regenerating Art.lua.
            local expect = ui.artLayer:GetWidth() * g.compassCrop.share
            h.truthy(math.abs(ui.compass:GetWidth() - expect) < 1,
                     "the compass is sized from geometry.compassCrop.share")
        end)

        h.it("stacks the housing above the art and the text above the housing", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            h.truthy(ui.housingFrame:GetFrameLevel() > ui.artLayer:GetFrameLevel(),
                     "the housing covers the art")
            h.truthy(ui.content:GetFrameLevel() > ui.housingFrame:GetFrameLevel(),
                     "nothing the player reads is ever behind the chassis")
        end)
```

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: FAIL, `ui.artLayer` is nil.

- [ ] **Step 3: Rebuild the layout**

In `GoblinPS/Dash.lua`, replace the geometry constants:

```lua
-- The device's rectangle on screen. The art is 1024x1280, so this keeps that
-- shape; everything inside is placed as a fraction of it, from the geometry
-- the art tool generates. Nothing here is a measured guess.
Dash.SIZE = { 230, 288 }
local PAD = 8
local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"
```

Add two helpers above `build()`:

```lua
local function geometry()
    return ns.Data.Art and ns.Data.ArtGeometry
end

-- Put a region where the geometry says, as a fraction of `parent`. `rect` is
-- { left, top, right, bottom } in 0..1 with the origin at the top left, which
-- is how the artist's file states every box.
local function place(region, parent, rect)
    local w, h = parent:GetWidth(), parent:GetHeight()
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", rect.left * w, -rect.top * h)
    region:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", rect.right * w, -rect.bottom * h)
end
```

Then in `build()`, after the drag wiring and `f:Hide()`, replace everything from
the old `device` frame down to the old `bodyArt` with:

```lua
    local base = f:GetFrameLevel()
    local g = geometry()

    -- One rectangle for the five layers that were drawn to stack.
    local artLayer = CreateFrame("Frame", nil, f)
    artLayer:SetAllPoints(f)
    artLayer:SetFrameLevel(base + 1)

    -- The flat colour is the fallback for art that will not load. It is a
    -- rectangle, so it goes the moment the glass arrives, or it boxes in a
    -- round device.
    local flat = W.Fill(artLayer, "BACKGROUND", "screen")
    local glass = art(artLayer, "dash2-glass", "BORDER")
    if glass then
        flat:Hide()
    end

    -- The compass and the arrow turn, so each is a square texture centred on
    -- the dial. SetRotation turns a texture about its own middle, and Task 1
    -- cropped the compass so that its middle IS the dial.
    local dial = g and { x = g.glass.cx, y = g.glass.cy } or { x = 0.5, y = 0.4 }
    local function centreOnDial(region, share)
        local side = f:GetWidth() * share
        region:SetSize(side, side)
        region:ClearAllPoints()
        region:SetPoint("CENTER", artLayer, "TOPLEFT",
                        dial.x * artLayer:GetWidth(), -dial.y * artLayer:GetHeight())
    end

    local compass = artLayer:CreateTexture(nil, "ARTWORK")
    local compassPart = ns.Data.Art and ns.Data.Art["dash2-compass"]
    if compassPart and compass:SetTexture(MEDIA .. compassPart.file) then
        compass:SetTexCoord(compassPart.l, compassPart.r, compassPart.t, compassPart.b)
    else
        compass:Hide()
    end
    centreOnDial(compass, g and g.compassCrop.share or 0.55)

    local arrow = artLayer:CreateTexture(nil, "OVERLAY")
    local arrowPart = ns.Data.Art and ns.Data.Art["arrow"]
    if arrowPart and arrow:SetTexture(MEDIA .. arrowPart.file) then
        arrow:SetTexCoord(arrowPart.l, arrowPart.r, arrowPart.t, arrowPart.b)
    else
        arrow:SetTexture("Interface\\Buttons\\WHITE8X8")
        arrow:SetVertexColor(unpack(W.COLOR.green))
    end
    centreOnDial(arrow, g and g.arrow.share or 0.45)

    local stepsScreen = art(artLayer, "dash2-steps-screen", "BACKGROUND")
    local etaScreen = art(artLayer, "dash2-eta-screen", "BACKGROUND")

    -- The chassis, over the art, with its holes letting the art show through.
    local housingFrame = CreateFrame("Frame", nil, f)
    housingFrame:SetAllPoints(f)
    housingFrame:SetFrameLevel(base + 2)
    local housing = art(housingFrame, "dash2-housing", "ARTWORK")

    local content = CreateFrame("Frame", nil, f)
    content:SetAllPoints(f)
    content:SetFrameLevel(base + 3)
```

Keep the existing FontStrings for now, parented to `content`, so the trip loop
still has somewhere to write; Task 3 moves them onto the glass and into the
panel. Extend the `ui` table with the new names:

```lua
    ui = { frame = f, artLayer = artLayer, flat = flat, glass = glass,
           compass = compass, arrow = arrow, stepsScreen = stepsScreen,
           etaScreen = etaScreen, housingFrame = housingFrame, housing = housing,
           content = content,
           distance = distance, eta = eta, step = step, next = following, stop = stop }
```

Set `## Version: 2026.09.20.3` in the TOC.

- [ ] **Step 4: Run the tests to verify they pass**

Run the Lua suite. Expected: green.

- [ ] **Step 5: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 6: Commit**

```bash
git add GoblinPS/Dash.lua GoblinPS/GoblinPS.toc test/test_ui.lua
git commit -m "Dash unit: rebuild the layout from the generated geometry" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---


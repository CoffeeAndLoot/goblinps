### Task 5: Inputs, screen, side panel and footer

**Files:**
- Modify: `GoblinPS/Planner.lua`
- Modify: `GoblinPS/Widgets.lua`
- Modify: `GoblinPS/GoblinPS.toc` (version `2026.09.21`)
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: everything Tasks 1 to 4 produced.
- Produces: nothing later in this plan depends on it.

**Three-slice stretching, and why it is needed.** One `button` part draws at 65
pixels wide for "Here" and 135 for GO, and one `input-box` draws at 187 and
245. Stretching the whole texture squashes the decorative end caps at one width
and stretches them at another. Codex said so plainly: "Input/button art needs
fixed end caps." So: draw three textures from one part — a left cap at its
natural width, a right cap at its natural width, and a middle stretched between
them.

**The backdrop is an insert, not a layer.** This is the opposite of the rule
the dash taught. `screen-backdrop` is 1600x640 scenery that must cover the
`screen` rectangle without distorting: scale to cover, centre-crop the
overflow, clip to the rectangle. All three happen in one `SetTexCoord`, with no
clipping frame and no new API — but the crop must compose with the padding crop
the part already carries, or it crops the wrong thing.

- [ ] **Step 1: Write the failing test**

Add to the planner block in `test/test_ui.lua`:

```lua
        h.it("covers the screen with the backdrop without distorting it", function()
            -- screen-backdrop is 2.5:1 scenery and the screen opening is not.
            -- Stretching it to fit would squash the mountains; the answer is
            -- to crop the overflow, centred, inside the part's own texture
            -- coordinates.
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout("wide")
            local ui = ns.Planner.Debug()
            h.truthy(ui.backdrop, "the backdrop texture exists")
            local l, r, t, b = unpack(ui.backdrop.texCoord)
            local part = ns.Data.Art["screen-backdrop"]
            h.truthy(l >= part.l - 0.0001 and r <= part.r + 0.0001,
                     "the cover-crop stays inside the part's own padding crop")
            h.truthy(math.abs((l - part.l) - (part.r - r)) < 0.0001,
                     "the crop is centred: equal slivers off each side")
            h.truthy(r - l < part.r - part.l,
                     "2.5:1 scenery in a wider-than-tall-but-not-2.5 opening loses width")
        end)

        h.it("gives a stretched control fixed end caps", function()
            -- One button part draws at 65 px for Here and 135 for GO. A single
            -- stretched texture squashes the caps at one width and stretches
            -- them at the other.
            local f = CreateFrame("Frame", nil, UIParent)
            f:SetSize(200, 40)
            -- button.png is 768x192, so a quarter of its width is a 192x192
            -- cap: aspect 1.
            local slice = W.Stretch3(f, "button", 0.25, 1.0)
            h.truthy(slice, "three-slice returns its pieces")
            h.eq(slice.left:GetWidth(), slice.right:GetWidth(),
                 "both caps draw at the same natural width")
            h.truthy(slice.middle.points and #slice.middle.points >= 2,
                     "the middle is anchored between the caps, so it takes the slack")
        end)

        h.it("places every input, panel and footer line from the geometry", function()
            ns.Planner.Toggle()
            for _, mode in ipairs({ "wide", "tall" }) do
                ns.Planner.ApplyLayout(mode)
                local ui = ns.Planner.Debug()
                local g = ns.Data.ArtGeometry.planner[mode]
                local w = ui.frame:GetWidth()
                local checks = {
                    { ui.fromBox, g.fromBox, "fromBox" },
                    { ui.toBox, g.toBox, "toBox" },
                    { ui.here, g.hereButton, "hereButton" },
                    { ui.screen, g.screen, "screen" },
                    { ui.side, g.sidePanel, "sidePanel" },
                    { ui.go, g.goButton, "goButton" },
                }
                for _, check in ipairs(checks) do
                    local region, rect, name = check[1], check[2], check[3]
                    h.truthy(region, mode .. ": " .. name .. " is missing")
                    h.truthy(math.abs(region.points[1][4] - rect.left * w) < 1,
                             mode .. ": " .. name .. " starts at its rect's left, got "
                             .. tostring(region.points[1][4]))
                end
                -- The two footer lines are lines, so they carry two horizontal
                -- anchors on one y, not four corners.
                for _, fs in ipairs({ ui.total, ui.hint }) do
                    h.eq(#fs.points, 2)
                    h.eq(fs.points[1][5], fs.points[2][5], "both ends sit on one line")
                end
            end
        end)

        h.it("keeps working when not one texture loads", function()
            -- Art is laid over colours. A beta patch that renames a file must
            -- leave a window the player can still route with.
            local restore = ns.Data.Art
            ns.Data.Art = nil
            local ok = pcall(function()
                ns.Planner.Toggle()
                ns.Planner.ApplyLayout("wide")
            end)
            ns.Data.Art = restore
            h.truthy(ok, "building with no art at all must not error")
            local ui = ns.Planner.Debug()
            h.truthy(ui.flat:IsShown(), "and the flat fallback comes back")
        end)
```

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: FAIL, `ui.backdrop` is nil and
`W.Stretch3` is nil.

- [ ] **Step 3: Write the three-slice stretcher**

In `GoblinPS/Widgets.lua`, after the placement helpers:

```lua
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
-- Returns { left, middle, right }, or nil when the part is missing or will not
-- load -- and every caller uses that, because a missing texture must leave a
-- working control.
function Widgets.Stretch3(parent, name, capFraction, capAspect)
    local part = ns.Data.Art and ns.Data.Art[name]
    if not part then
        return nil
    end
    local path = "Interface\\AddOns\\GoblinPS\\Media\\" .. part.file
    local span = part.r - part.l
    local cap = span * capFraction
    -- The cap keeps the shape it was drawn at: its drawn width is its own
    -- aspect times the control's height, so it never squashes.
    local width = parent:GetHeight() * capAspect

    local function piece(l, r)
        local t = parent:CreateTexture(nil, "ARTWORK")
        if not t:SetTexture(path) then
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
    left:SetWidth(width)
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(width)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    return { left = left, middle = middle, right = right }
end
```

- [ ] **Step 4: Write the backdrop's cover-crop**

In `GoblinPS/Planner.lua`, above `ApplyLayout`:

```lua
-- Cover `rect` (in device fractions) with a part whose own aspect differs,
-- losing the overflow evenly off both sides rather than distorting the art.
-- The crop composes with the part's padding crop: the part's artwork lives in
-- l..r of its texture, so the cover-crop takes a centred sub-range of THAT,
-- never of 0..1. Getting this backwards crops the padding instead of the art.
--
-- screen-backdrop is decorative scenery, not a map. Losing its sides is
-- intended.
local function coverCrop(texture, part, partW, partH, boxW, boxH)
    local span = part.r - part.l
    local tall = part.b - part.t
    local partAspect = (partW * span) / (partH * tall)
    local boxAspect = boxW / boxH
    if partAspect > boxAspect then
        -- The art is wider than the opening: keep a centred slice of width.
        local keep = span * (boxAspect / partAspect)
        local trim = (span - keep) / 2
        texture:SetTexCoord(part.l + trim, part.r - trim, part.t, part.b)
    else
        local keep = tall * (partAspect / boxAspect)
        local trim = (tall - keep) / 2
        texture:SetTexCoord(part.l, part.r, part.t + trim, part.b - trim)
    end
end
```

`partW` and `partH` are the part's **source** pixel dimensions, 1600 and 640
for `screen-backdrop`. Put them in the call rather than in the helper: the
helper knows nothing about which part it is given.

- [ ] **Step 5: Place the rest of the window**

In `build()`, give the screen a backdrop texture and the side panel a backing,
both on `artLayer` so they sit under the content:

```lua
    local backdrop = artLayer:CreateTexture(nil, "BORDER")
    local backdropPart = ns.Data.Art and ns.Data.Art["screen-backdrop"]
    if not (backdropPart and backdrop:SetTexture(MEDIA .. backdropPart.file)) then
        backdrop:Hide()
        backdrop = nil
    end

    -- The interior backing, genuinely tiled. That works only because this part
    -- ships unpadded: a 512x512 source at 256x256 is already a power of two,
    -- so its crop is the whole texture. Tiling a PADDED part would repeat the
    -- transparent padding along with the picture, which is why every other
    -- part in this window is stretched instead. check_art.py flags this one as
    -- tiling, meaning its four edges were drawn to meet.
    --
    -- SetHorizTile and SetVertTile are both present on build 1.60.1.69913
    -- (SimpleTextureBaseAPIDocumentation.lua) and Blizzard's own UI calls them.
    local panelArt = artLayer:CreateTexture(nil, "BACKGROUND")
    local panelPart = ns.Data.Art and ns.Data.Art["planner-panel"]
    local whole = panelPart and panelPart.l == 0 and panelPart.r == 1
                  and panelPart.t == 0 and panelPart.b == 1
    if whole and panelArt:SetTexture(MEDIA .. panelPart.file, "REPEAT", "REPEAT") then
        panelArt:SetHorizTile(true)
        panelArt:SetVertTile(true)
    elseif panelPart and panelArt:SetTexture(MEDIA .. panelPart.file) then
        -- Padded after all: stretch rather than repeat the padding.
        panelArt:SetTexCoord(panelPart.l, panelPart.r, panelPart.t, panelPart.b)
    else
        panelArt:Hide()
    end
```

Change `screen`, `side` and `results` from `W.Panel(f, ...)` to
`W.Panel(content, ...)` so they sit above the art, and reparent the two edit
boxes, `here`, `go`, `hint`, `total` and every step row from `f`/`side` to
their existing parents but with `content` as the root. Delete every `SetPoint`
call on `fromBox`, `toBox`, `here`, `go`, `hint` and `total` — `ApplyLayout`
places them now. The step rows inside `side` keep their existing relative
anchors: they are laid out within the side panel, which the geometry places as
a unit.

Give the two edit boxes and the three buttons their three-slice art:

```lua
    -- input-box.png is 1024x128, so 0.18 of its width is a 184x128 cap.
    local CAP, CAP_ASPECT = 0.18, 184 / 128
    local fromSlice = W.Stretch3(fromBox, "input-box", CAP, CAP_ASPECT)
    local toSlice = W.Stretch3(toBox, "input-box", CAP, CAP_ASPECT)
```

Add to the `ui` table: `backdrop`, `panelArt`, `fromSlice`, `toSlice`.

Then extend `ApplyLayout`, after the chrome block from Task 4:

```lua
Add these **into the `if g then` block Task 4 opened**. Do not start a second
one, and do not re-place the chrome Task 4 already placed:

```lua
        W.PlaceRect(ui.fromBox, f, g.fromBox)
        W.PlaceRect(ui.toBox, f, g.toBox)
        W.PlaceRect(ui.here, f, g.hereButton)
        W.PlaceRect(ui.results, f, g.resultsList)
        W.PlaceRect(ui.screen, f, g.screen)
        W.PlaceRect(ui.side, f, g.sidePanel)
        W.PlaceRect(ui.go, f, g.goButton)
        W.PlaceLine(ui.total, f, g.totalLine)
        W.PlaceLine(ui.hint, f, g.hintLine)
        if ui.panelArt then
            W.PlaceRect(ui.panelArt, f, g.screen)
        end
        if ui.backdrop then
            W.PlaceRect(ui.backdrop, f, g.screen)
            local part = ns.Data.Art["screen-backdrop"]
            coverCrop(ui.backdrop, part, 1600, 640,
                      (g.screen.right - g.screen.left) * f:GetWidth(),
                      (g.screen.bottom - g.screen.top) * f:GetHeight())
        end
```

Delete `SCREEN_SHARE`, `PAD`, `HEADER`, `INPUTS`, `FOOTER` and any other layout
constant no longer read. `ROW` and `STEP_ROW` stay: they lay out rows *inside*
the side panel and results list, which is relative positioning the geometry
does not describe. Run luacheck to find any that became unused.

Set `## Version: 2026.09.21` in `GoblinPS/GoblinPS.toc`.

- [ ] **Step 6: Stop `showResults` re-anchoring the list**

`showResults` currently ends by anchoring `ui.results` under whichever box has
focus and sizing it to that box's width:

```lua
    ui.results:ClearAllPoints()
    ui.results:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
    ui.results:SetSize(box:GetWidth(), math.min(#items, Planner.MAX_RESULTS) * ROW + 4)
```

That fights `ApplyLayout`, which now places the list from `g.resultsList`, and
it contradicts what the art was drawn for: Codex specified one shared list that
"spans the search area rather than being restricted to the focused field".
Delete those three lines. `showResults` keeps filling the rows, setting
`ui.results.owner` and calling `Show`; where the list sits is `ApplyLayout`'s
business alone.

The list's height is now fixed by the geometry rather than by how many results
there are, so hide the unused rows — `row:SetShown(item ~= nil)` already does
exactly that, which is why nothing else needs to change.

Add the test:

```lua
        h.it("drops the results list over the search area, not under one box", function()
            -- One shared list, spanning the search area: it serves whichever
            -- box has focus and the art has one opening for it.
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout("wide")
            local ui = ns.Planner.Debug()
            local g = ns.Data.ArtGeometry.planner.wide
            local w = ui.frame:GetWidth()
            ui.toBox:SetText("Orgrimmar")
            ui.toBox:GetScript("OnTextChanged")(ui.toBox, true)
            h.truthy(ui.results:IsShown(), "typing opens the list")
            h.eq(ui.results.points[1][2], ui.frame,
                 "anchored to the window, not to the box that has focus")
            h.truthy(math.abs(ui.results.points[1][4] - g.resultsList.left * w) < 1,
                     "and it sits where the geometry says")
        end)

        h.it("opens the whole list from the dropdown button", function()
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.truthy(ui.dropdown, "the socket beside To has a control in it")
            Fake.Click(ui.dropdown)
            h.truthy(ui.results:IsShown(), "browsing needs no typing")
            Fake.Click(ui.dropdown)
            h.falsy(ui.results:IsShown(), "and clicking again puts it away")
        end)
```

- [ ] **Step 7: Run the tests to verify they pass**

Run the Lua suite. Expected: green. Every existing planner test must still
pass.

- [ ] **Step 8: Prove the fallback is real**

In a scratch copy outside the repo, delete `GoblinPS/Data/Art.lua` entirely and
run the Lua suite.

Expected: green. Not "green except the art tests" — the whole suite. A window
that cannot be built without its art is a window a renamed texture breaks.
Delete the scratch copy afterwards.

- [ ] **Step 9: Lint**

Run luacheck and the language server. Expected: zero warnings, and no
`unused variable` left behind by the deleted constants.

- [ ] **Step 10: Commit**

```bash
git add GoblinPS/Planner.lua GoblinPS/Widgets.lua GoblinPS/GoblinPS.toc test/test_ui.lua
git commit -m "The planner's inputs, screen, panel and footer, from the geometry" -m "Three-slice stretching keeps the end caps on controls drawn at two widths, and the screen backdrop covers its opening by cropping rather than distorting -- an insert, not a stacked layer, which is the opposite of what the dash taught." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Documents

**Files:**
- Modify: `docs/superpowers/specs/2026-09-19-goblinps-design.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: The spec**

In the status header, record that plan 6 is the planner's art and plan 7 is the
route strip, and that the strip was separated because it draws inside a screen
rectangle this plan places and that art has never been in the client.

In decision 5, record that `images/parts/planner-geometry.json` is the
placement authority for the window, that `tools/check_art.py` verifies it
against the frame pixels, and that `tools/make_art.py` copies it into
`GoblinPS/Data/Art.lua` so no coordinate is hand-typed in `Planner.lua`.

Record the ruling on `tools_button`: it is an alias of `close_button` that the
generator drops, so the addon cannot draw a second control on top of Close.

- [ ] **Step 2: The checklist**

Add a `## Planner window art (plan 6)` section to
`docs/manual-test-checklist.md`:

```
- [ ] /gps opens a window wearing brass, not flat colour, in both shapes
- [ ] The window is the art's shape, not stretched: the round lamps in the
      corners are round. If they are ovals, Planner.SIZE and the art's canvas
      have drifted apart
- [ ] No coloured rectangle shows at the window's edges or corners
- [ ] Title and tagline sit on their plates; neither draws on the brass
- [ ] Close shuts the window; the gear says settings are not built yet
- [ ] The title bar has exactly TWO buttons, a gear and a close -- if a
      third sits exactly on top of close, the tools_button alias got through
- [ ] The dropdown beside To opens the whole destination list without typing
- [ ] The Wide/Tall button switches shape and both shapes are laid out
- [ ] From, To and Here sit in their openings, and the end caps on the boxes
      and buttons are not squashed or stretched
- [ ] Typing in either box drops the results list over the screen, and it
      covers what it drops over rather than hiding behind it
- [ ] The screen's scenery fills its opening without looking stretched;
      losing the sides is intended
- [ ] The step list, total and amber hint sit in their openings, and a long
      warning never covers GO
- [ ] At UI scale 0.64 and 1.0 the window is legible and nothing overlaps
- [ ] /gps selftest names the sixteen new textures; if one FAILS the window
      must still be usable on its flat colours
```

- [ ] **Step 3: CLAUDE.md**

Update the status line: plan 6 built, plan 7 the route strip next. Note in the
layout map that `GoblinPS/Data/Art.lua` now carries the planner's geometry as
well as the dash's, that no coordinate is hand-typed in `Planner.lua`, and that
`GoblinPS/Widgets.lua` owns the three shared placement helpers.

Add to "Rules that are easy to break":

```
- **An art part that stacks shares its canvas; an art part that is an insert
  does not.** The dash's five layers are one rectangle corner to corner. The
  planner's `screen-backdrop` is the opposite: 2.5:1 scenery scaled to cover
  its opening and centre-cropped, with the crop composed into the part's own
  padding coordinates. Reading one rule as the other either distorts the art
  or crops the padding instead of the picture.
```

- [ ] **Step 4: Commit**

```bash
git add docs/ CLAUDE.md
git commit -m "Docs: the planner's art, and why the strip is its own plan" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Notes for the reviewer

- **No coordinate may be hand-typed in `Planner.lua`.** Every position comes
  from `ns.Data.ArtGeometry.planner`. A literal offset or size in the layout is
  a finding even if it happens to look right, because the next art delivery
  will move it and nothing will notice. `Planner.SIZE` is the one permitted
  exception and is checked against the art's aspect ratio by a test.
- **Check what each helper measures.** `W.PlaceRect`, `W.PlaceLine` and
  `W.PlaceCircle` must all measure the frame with the explicit `SetSize`. A
  call that passes `content` or `artLayer` as the device reproduces the fault
  that reached the client on 2026-09-20, and it will pass any test that only
  counts anchors.
- **Positions, not just sizes.** Plan 5 shipped a device whose every texture
  was the right size and in the wrong place, past a green suite. Every
  placement test in this plan asserts a coordinate.
- **The backdrop's crop is the subtle part.** It composes with the part's
  padding crop. A version that calls `SetTexCoord` with a sub-range of 0..1
  instead of a sub-range of `l..r` will crop the transparent padding and show a
  sliver of scenery. Check the arithmetic against a part whose `l` is not 0 —
  `screen-backdrop` pads from 512x205 to 512x256, so its `b` is about 0.80.
- **There is no tools button.** If one appears, Task 2's drop list failed.
- **The fallback is not decoration.** With `Data/Art.lua` deleted the window
  must still open, lay out both shapes and route. Step 7 of Task 5 tests
  exactly that; check it was actually run.
- The fake's accepted-and-ignored list has hidden five methods so far, and its
  `SetAllPoints` hid a sixth fault by being too helpful. If a test cannot see
  something, look there before concluding it cannot be tested. It does not
  record the font object at all.

### Task 3: Three shared placement helpers, and Dash moved onto them

**Files:**
- Modify: `GoblinPS/Widgets.lua`
- Modify: `GoblinPS/Dash.lua`
- Test: `test/test_ui.lua`

**Interfaces:**
- Produces, for Tasks 4 and 5:

```lua
W.PlaceRect(region, device, rect)   -- corner to corner; rect is {left, top, right, bottom}
W.PlaceLine(fs, device, rect)       -- LEFT/RIGHT on the rect's vertical centre
W.PlaceCircle(region, device, circ) -- square, side = 2 * r * device width, CENTER on (cx, cy)
```

`device` is always the frame with an explicit `SetSize`. `rect` fractions have
their origin at the top left, which is how both geometry files state every box.

**Why this task exists.** `Dash.lua` has a private `placeLine` carrying a
comment earned in the client on 2026-09-20. `Planner.lua` needs the same
function plus two siblings. Two copies means the next person fixes one of them.
`Widgets.lua` is the shared palette and is where this belongs.

**Why it is safe.** `placeLine` is seven lines and the dash has a test that
fails when it is wrong — verified today by reverting the fix and watching two
placement tests fail. Those 258 tests are the net for this migration.

- [ ] **Step 1: Write the failing test**

Add a new block to `test/test_ui.lua`, beside the existing widget tests:

```lua
    h.describe("the shared placement helpers", function()
        local function device(w, h2)
            local f = CreateFrame("Frame", nil, UIParent)
            f:SetSize(w, h2)
            return f
        end

        h.it("places a rectangle corner to corner from the device's top left", function()
            local f = device(200, 100)
            local t = f:CreateTexture(nil, "ARTWORK")
            W.PlaceRect(t, f, { left = 0.1, top = 0.2, right = 0.6, bottom = 0.7 })
            h.eq(#t.points, 2, "two corners fully place a region")
            h.eq(t.points[1][1], "TOPLEFT")
            h.eq(t.points[1][3], "TOPLEFT", "offsets are from the device's corner")
            h.truthy(math.abs(t.points[1][4] - 20) < 0.01, "left 0.1 of 200")
            h.truthy(math.abs(t.points[1][5] + 20) < 0.01, "top 0.2 of 100, downward")
            h.eq(t.points[2][1], "BOTTOMRIGHT")
            h.truthy(math.abs(t.points[2][4] - 120) < 0.01, "right 0.6 of 200")
            h.truthy(math.abs(t.points[2][5] + 70) < 0.01, "bottom 0.7 of 100")
        end)

        h.it("hangs a line on its rect's centre, letting the font set the height", function()
            -- The artist's *_line rects are a few pixels tall: slots to sit on,
            -- not boxes to fit in. Anchoring one corner to corner crushes the
            -- text into a box it cannot fit.
            local f = device(200, 100)
            local fs = W.Text(f, "green")
            W.PlaceLine(fs, f, { left = 0.1, top = 0.4, right = 0.9, bottom = 0.44 })
            h.eq(#fs.points, 2, "two horizontal anchors, so it still truncates")
            h.eq(fs.points[1][1], "LEFT")
            h.eq(fs.points[2][1], "RIGHT")
            h.truthy(math.abs(fs.points[1][5] + 42) < 0.01, "centre of 0.40..0.44 of 100")
            h.eq(fs.points[1][5], fs.points[2][5], "both ends sit on one line")
        end)

        h.it("makes a circle square and sizes it from the device's width", function()
            -- A radius measured against two different axes stops being a
            -- circle. Width, always, on both layouts.
            local f = device(200, 100)
            local t = f:CreateTexture(nil, "ARTWORK")
            W.PlaceCircle(t, f, { cx = 0.5, cy = 0.25, r = 0.1 })
            h.eq(t:GetWidth(), t:GetHeight(), "a circle is drawn on a square")
            h.truthy(math.abs(t:GetWidth() - 40) < 0.01, "2 * 0.1 * 200")
            h.eq(t.points[1][1], "CENTER")
            h.truthy(math.abs(t.points[1][4] - 100) < 0.01)
            h.truthy(math.abs(t.points[1][5] + 25) < 0.01)
        end)

        h.it("never reads a size from a frame that only inherits one", function()
            -- The fault that reached the client on 2026-09-20. A frame sized
            -- by SetAllPoints has no resolved size until the layout pass, so
            -- every fraction would be multiplied by nothing.
            local f = device(200, 100)
            local child = CreateFrame("Frame", nil, f)
            child:SetAllPoints(f)
            local fs = W.Text(child, "green")
            W.PlaceLine(fs, f, { left = 0.1, top = 0.4, right = 0.9, bottom = 0.44 })
            h.truthy(fs.points[1][4] > 0, "measured the device, not the child")
        end)
    end)
```

- [ ] **Step 2: Run to verify it fails**

Run the Lua suite. Expected: FAIL, `attempt to call field 'PlaceRect' (a nil value)`.

- [ ] **Step 3: Write the helpers**

In `GoblinPS/Widgets.lua`, after `Widgets.Text`:

```lua
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the Lua suite. Expected: green, 262 passed.

- [ ] **Step 5: Move `Dash.lua` onto the shared helper**

Delete the private `placeLine` from `GoblinPS/Dash.lua` — the whole function
and its comment block, since the comment now lives on `W.PlaceLine`. Replace
its four call sites with `W.PlaceLine(...)`, keeping `f` as the device argument
exactly as it is today:

```lua
        W.PlaceLine(destination, f, g.destination)
        W.PlaceLine(distance, f, g.distance)
```

and in the steps loop:

```lua
            W.PlaceLine(steps[i], f, {
```

and:

```lua
        W.PlaceLine(eta, f, g.etaText)
```

Leave `centreOnDial` alone. It predates this and does one extra thing
(`SetTexCoord` on a rotating texture); folding it into `W.PlaceCircle` is a
change worth making only when a second caller wants it.

- [ ] **Step 6: Run the tests, and prove the migration kept its teeth**

Run the Lua suite. Expected: green, 262 passed — every dash test still passing,
unchanged.

Then prove the net still catches the original fault. In a scratch copy outside
the repo, change the four `W.PlaceLine(x, f, ...)` calls back to passing
`content` (the `SetAllPoints` frame) and run the suite:

Expected: FAIL on the two dash placement tests, `sits all three step lines on
the centre of their third of the art's steps box` and `sits the destination,
distance and ETA on their own centre lines too`. If they pass, the migration
lost the protection and the helper is wrong. Delete the scratch copy afterwards.

- [ ] **Step 7: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 8: Commit**

```bash
git add GoblinPS/Widgets.lua GoblinPS/Dash.lua test/test_ui.lua
git commit -m "Three shared placement helpers, and the dash moved onto them" -m "PlaceRect, PlaceLine and PlaceCircle live in the widget palette so the planner and the dash cannot drift. The comment about never measuring a SetAllPoints frame moves with them, since that is the fault it exists to prevent." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---


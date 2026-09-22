### Task 2: the dash's long lines scroll

**Files:**
- Modify: `GoblinPS/Dash.lua` (build(): the slot widths and `ui.lines`; the
  `OnUpdate`; a new `Dash.Scroll`)
- Modify: `test/fake_frames.lua` (`Fake.CHAR_WIDTH`, `GetUnboundedStringWidth`)
- Modify: `test/test_ui.lua` (load `Marquee`; a new "the dash's scrolling
  text" block; one fake-frames test)

**Interfaces:**
- Consumes: `ns.Marquee.New`, `ns.Marquee.Advance`, `Marquee.HOLD`,
  `Marquee.STEP`, `Marquee.GAP` (Task 1); the dash geometry keys
  `destination`, `distance`, `stepsText`, `etaText` (each
  `{ left, top, right, bottom }` in 0..1 of the dash).
- Produces: `ui.lines`, six `{ fs = FontString, slot = px, marquee = state|nil,
  drawn = string|nil }` in the order destination, distance, steps[1],
  steps[2], steps[3], eta; `Dash.Scroll(elapsed)`; the fake's
  `Fake.CHAR_WIDTH` (= 5) and `FontString:GetUnboundedStringWidth()`, which
  Task 5 also relies on.

Numbers at the dash's 288 px width: the step lines' slot is
(0.731445 - 0.279297) x 288 = 130.2 px, the glass destination's
(0.65625 - 0.351562) x 288 = 87.75 px. At 5 px a character,
"Ride to the North Gate" (22) is 110 px and fits; "Ride to Far Distant
Southern Crossing" (37) is 185 px and does not.

- [ ] **Step 1: Teach the fake to measure text**

In `test/fake_frames.lua`, directly after `Fake.laidOut = false` and
`function Fake.Layout() ... end`, add:

```lua
-- Every character of every font is this many pixels wide. A stand-in, not
-- the client's fonts: chosen so the dash fixture's ordinary lines fit their
-- openings and a long one does not. Tests may change it and put it back.
Fake.CHAR_WIDTH = 5
```

and after `function Region:GetText() return self.text end`, add:

```lua
-- Modelled, not swallowed: whether a line fits its opening, and how wide the
-- drop-down must be, are both decided from this number. It measures the text
-- the FontString holds, as the real one does, not the width it was given.
function Region:GetUnboundedStringWidth() return #(self.text or "") * Fake.CHAR_WIDTH end
```

- [ ] **Step 2: Write the failing tests**

In `test/test_ui.lua`, add `"Marquee"` to the load list directly after
`"Trip"` (line 71).

In the `h.describe("the fake frames model what the dash needs", ...)` block,
add after "a texture records its coordinates, tint and layer":

```lua
        h.it("a FontString measures the text it holds, not the width it was given", function()
            local f = CreateFrame("Frame")
            local fs = f:CreateFontString(nil, "OVERLAY")
            fs:SetWidth(1)
            fs:SetText("Abcd")
            h.eq(fs:GetUnboundedStringWidth(), 4 * Fake.CHAR_WIDTH)
        end)
```

Inside the dash `do ... end` block, directly after the end of
`h.describe("the dash unit's words and stop button", ...)` (before the `end`
that closes the `do`), add:

```lua
        h.describe("the dash's scrolling text", function()
            local Marquee = ns.Marquee
            local LONG = "Far Distant Southern Crossing"
            local function rideTo(name, seconds)
                return { kind = "ride", seconds = seconds, to = { name = name, c = 1, x = 0, y = 0, map = 1 } }
            end
            local longPlan = {
                level = 60,
                to = ns.Search.Exact(ns.Data, "Westland", "H"),
                result = { seconds = 400, steps = {
                    rideTo(LONG, 200), rideTo("Delta", 100), rideTo("Another Far Distant Crossing", 100),
                } },
            }
            local full = "Ride to " .. LONG

            h.it("works out each line's opening from the geometry and the frame's own size", function()
                Dash.Start(longPlan)
                local ui = Dash.Debug()
                local g, w = ns.Data.ArtGeometry, ui.frame:GetWidth()
                h.eq(w, Dash.SIZE[1], "measured on the frame given an explicit size")
                local rects = { g.destination, g.distance, g.stepsText, g.stepsText, g.stepsText, g.etaText }
                local lines = { ui.destination, ui.distance, ui.steps[1], ui.steps[2], ui.steps[3], ui.eta }
                h.eq(#ui.lines, 6)
                for i, line in ipairs(ui.lines) do
                    h.truthy(line.fs == lines[i], "line " .. i .. " is the right FontString")
                    h.truthy(math.abs(line.slot - (rects[i].right - rects[i].left) * w) < 1e-9,
                             "line " .. i .. " slot is its rect's width times the dash's")
                end
            end)

            h.it("scrolls a line too long for its opening, and holds a short one still", function()
                Dash.Start(longPlan)
                local ui = Dash.Debug()
                Dash.Scroll(0)
                h.eq(ui.steps[1]:GetText(), full, "it starts at its start")
                Dash.Scroll(Marquee.HOLD - 0.1)
                h.eq(ui.steps[1]:GetText(), full, "and holds there")
                Dash.Scroll(0.11)
                h.eq(ui.steps[1]:GetText(), full:sub(2) .. Marquee.GAP .. full, "then drops its first character")
                Dash.Scroll(Marquee.STEP)
                h.eq(ui.steps[1]:GetText(), full:sub(3) .. Marquee.GAP .. full)
                h.eq(ui.steps[2]:GetText(), "Ride to Delta", "a line that fits never moves")
                h.eq(ui.destination:GetText(), LONG:sub(3) .. Marquee.GAP .. LONG, "the glass scrolls too")
            end)

            h.it("judges fit by the opening, never by the FontString's own width", function()
                Dash.Start(longPlan)
                local ui = Dash.Debug()
                -- Widths that would flip both answers if the code read them:
                -- the long line "wide enough", the short one "too narrow".
                ui.steps[1].width, ui.steps[2].width = 10000, 1
                Dash.Scroll(Marquee.HOLD + 0.01)
                ui.steps[1].width, ui.steps[2].width = nil, nil
                h.eq(ui.steps[1]:GetText(), full:sub(2) .. Marquee.GAP .. full)
                h.eq(ui.steps[2]:GetText(), "Ride to Delta")
            end)

            h.it("restarts a line from its start when its text changes", function()
                Dash.Start(longPlan)
                local ui, state = Dash.Debug()
                Dash.Scroll(Marquee.HOLD + 3 * Marquee.STEP)
                h.truthy(ui.steps[1]:GetText() ~= full, "well into the first name")
                state.index = 3
                Dash.Refresh()
                Dash.Scroll(Marquee.STEP)
                h.eq(ui.steps[1]:GetText(), "Ride to Another Far Distant Crossing",
                     "a new step starts at its beginning and holds, never mid-name")
                state.index = 1
                Dash.Refresh()
            end)

            h.it("rides the dash's own OnUpdate, with no timer of its own", function()
                Dash.Start(longPlan)
                local ui = Dash.Debug()
                standAt(5000, 5000) -- far from every target: the tick in the same frame moves nothing on
                ui.frame.scripts.OnUpdate(ui.frame, 0)
                ui.frame.scripts.OnUpdate(ui.frame, Marquee.HOLD + 0.01)
                h.eq(ui.steps[1]:GetText(), full:sub(2) .. Marquee.GAP .. full, "the frame's OnUpdate drove it")
                h.eq(ui.steps[2]:GetText(), "Ride to Delta")
                Dash.Stop()
            end)
        end)
```

- [ ] **Step 3: Run the Lua gate to see them fail**

Expected: the fake-frames test passes; the five scrolling tests fail
(`ui.lines` is nil, `Dash.Scroll` is nil).

- [ ] **Step 4: Wire the marquee into `GoblinPS/Dash.lua`**

In `build()`, directly after the ETA block (the `if g then W.PlaceLine(eta,
f, g.etaText) else ... end`), add:

```lua
    -- How wide each line's opening is, for the marquee. Worked out from the
    -- geometry and `f`, which was given an explicit size -- never read off a
    -- FontString, which only inherits its width from two anchors and answers
    -- 0 during build(). With no geometry the fallback stack spans the frame,
    -- so the frame's own width is the opening.
    local frameWidth = f:GetWidth()
    local function slot(rect)
        return rect and (rect.right - rect.left) * frameWidth or frameWidth
    end
    local stepSlot = slot(g and g.stepsText)
    local lines = {
        { fs = destination, slot = slot(g and g.destination) },
        { fs = distance, slot = slot(g and g.distance) },
        { fs = steps[1], slot = stepSlot },
        { fs = steps[2], slot = stepSlot },
        { fs = steps[3], slot = stepSlot },
        { fs = eta, slot = slot(g and g.etaText) },
    }
```

Add `lines = lines` to the `ui = { ... }` table (after `steps = steps, eta = eta,`).

Change the `OnUpdate` so the marquee rides it, between the steering and the tick:

```lua
    f:SetScript("OnUpdate", function(_, elapsed)
        Dash.Steer(elapsed)
        Dash.Scroll(elapsed)
        since = since + elapsed
        if since >= Dash.TICK then
            since = 0
            Dash.Tick("tick")
        end
    end)
```

Directly after `function Dash.Steer(elapsed) ... end`, add:

```lua
-- Called every frame. Each line keeps a marquee (Marquee.lua). A line whose
-- text has been set to anything other than what the marquee last drew -- a
-- step advance, a new trip, a banner -- starts again from its beginning, its
-- fit judged afresh: the text's own width against the line's opening, which
-- build() worked out from the geometry. A line that fits never moves, so the
-- distance and ETA, re-set every tick, hold still.
function Dash.Scroll(elapsed)
    if not ui or not ui.frame:IsShown() then
        return
    end
    for _, line in ipairs(ui.lines) do
        local shown = line.fs:GetText() or ""
        if not line.marquee or shown ~= line.drawn then
            line.marquee = ns.Marquee.New(shown, line.fs:GetUnboundedStringWidth() <= line.slot)
        end
        local text = ns.Marquee.Advance(line.marquee, elapsed)
        if text ~= shown then
            line.fs:SetText(text)
        end
        line.drawn = text
    end
end
```

- [ ] **Step 5: Run every gate**

Lua: expected `364 passed, 0 failed` (358 + 6). Python and art green.
luacheck and the language server from PowerShell: zero warnings.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Dash.lua test/fake_frames.lua test/test_ui.lua
git commit -m "Dash: a line too long for its opening scrolls" -m "The destination, distance, three step lines and ETA each run a marquee on the dash's existing OnUpdate. Fit is the text's own width against the opening worked out from the geometry and the dash's explicit size, never the FontString's; a new text starts at its beginning." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---


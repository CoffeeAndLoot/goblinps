### Task 3: The words, and a stop button that presses

**Files:**
- Modify: `GoblinPS/Dash.lua`
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `ui.place`, `ui.content`, `ui.artLayer` and `ns.Data.ArtGeometry` from Task 2.
- Produces: the device as designed. Nothing later in this plan depends on it.

**What the device says, and where.** The art puts four pieces of text in four boxes, and the geometry names all four:

| Box | What goes in it |
|---|---|
| `destination` | the name of the step you are walking to, on the glass |
| `distance` | how far that is, in yards, under the name |
| `stepsText` | three lines: the step you are on, then the next two |
| `etaText` | the time left for the whole journey |

**A decision this plan makes, and the reason.** The name on the glass is the **current step's target**, not the final destination. The arrow points at the current step; the distance counts down to the current step. Putting a third thing on the same glass — a destination the arrow is not pointing at — invites the player to read the arrow as pointing there. Arrow, name and number describe one thing. The step lines underneath carry the journey.

**The stop button.** Three states are shipped: `dash2-stop`, `dash2-stop-hover`, `dash2-stop-pressed`. The housing has a transparent socket for it, and the geometry gives its centre and radius. It replaces the old text button.

- [ ] **Step 1: Write the failing tests**

```lua
        h.it("puts the current step's name and distance on the glass", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            standAt(700, 0)
            Dash.Tick("tick")
            h.eq(ui.destination:GetText(), "the North Gate",
                 "the glass names what the arrow points at, not the journey's end")
            h.eq(ui.distance:GetText(), "700 yd")
        end)

        h.it("shows the step you are on and the next two", function()
            Dash.Start(plan)
            local ui, state = Dash.Debug()
            h.eq(ui.steps[1]:GetText(), "Ride to the North Gate")
            h.eq(ui.steps[2]:GetText(), "Zeppelin to East Dock")
            h.eq(ui.steps[3]:GetText(), "Ride to Delta")
            state.index = 3
            Dash.Refresh()
            h.eq(ui.steps[1]:GetText(), "Ride to Delta")
            h.eq(ui.steps[2]:GetText(), "", "nothing follows the last step")
            h.eq(ui.steps[3]:GetText(), "")
        end)

        h.it("bounds every line it draws", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            local lines = { ui.destination, ui.distance, ui.eta, ui.steps[1], ui.steps[2], ui.steps[3] }
            for i, fs in ipairs(lines) do
                h.truthy(fs.points and #fs.points >= 2,
                         "line " .. i .. " needs two horizontal anchors or it draws past the frame")
            end
        end)

        h.it("gives the stop button its three states and puts it in the socket", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            local g = ns.Data.ArtGeometry
            h.eq(ui.stop:GetWidth(), ui.stop:GetHeight(), "the button is round art on a square")
            local expect = ui.frame:GetWidth() * g.stop.r * 2
            h.truthy(math.abs(ui.stop:GetWidth() - expect) < 2, "sized from geometry.stop.r")
            h.truthy(ui.stopNormal, "the unpressed cap")
            h.truthy(ui.stopPressed, "the pushed cap")
        end)

        h.it("still ends the trip when the button is clicked", function()
            Dash.Start(plan)
            local ui, state = Dash.Debug()
            h.truthy(state.plan)
            Fake.Click(ui.stop)
            h.falsy(ui.frame:IsShown())
            h.falsy(state.plan, "clicking Stop ends the trip, as Escape does")
        end)

        h.it("keeps a usable button when its art will not load", function()
            Fake.missingTextures[MEDIA_STOP] = true
            Dash.Stop()
            local FreshDash = assert(loadfile("GoblinPS/Dash.lua"))("GoblinPS", ns)
            FreshDash.Start(plan)
            h.truthy(FreshDash.Debug().stop, "a missing texture must not lose the button")
            Fake.missingTextures[MEDIA_STOP] = nil
        end)
```

Define `MEDIA_STOP` near the top of the dash block as
`"Interface\\AddOns\\GoblinPS\\Media\\dash2-stop"`, and reuse whatever helper
the existing "keeps a working device when a texture will not load" test uses to
load a second copy of the module. If that helper is inline, lift it to a local
so both tests share it rather than copying it.

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: FAIL, `ui.destination` and `ui.steps` are nil.

- [ ] **Step 3: Write the text and the button**

Replace the old FontStrings in `build()` with these, all on `content`, all
positioned by `place`:

```lua
    local g = geometry()

    -- On the glass: what the arrow points at, and how far.
    local destination = W.Text(content, "green", "GameFontNormalSmall", "CENTER")
    local distance = W.Text(content, "green", "GameFontNormalLarge", "CENTER")
    if g then
        place(destination, content, g.destination)
        place(distance, content, g.distance)
    end

    -- In the lit panel: the step you are on, then the next two. The panel is
    -- one box in the art, so the three lines share it, each a third tall.
    local steps = {}
    for i = 1, 3 do
        steps[i] = W.Text(content, i == 1 and "green" or "dim", "GameFontNormalSmall", "LEFT")
    end
    if g then
        local box, third = g.stepsText, (g.stepsText.bottom - g.stepsText.top) / 3
        for i = 1, 3 do
            place(steps[i], content, {
                left = box.left, right = box.right,
                top = box.top + third * (i - 1), bottom = box.top + third * i,
            })
        end
    end

    -- On its own plate: the time left.
    local eta = W.Text(content, "green", "GameFontNormalSmall", "CENTER")
    if g then
        place(eta, content, g.etaText)
    end
```

The stop button, replacing the old text button:

```lua
    -- A real button in the housing's socket, with the three caps the artist
    -- drew. It ends the trip exactly as Escape does.
    local stop = CreateFrame("Button", nil, f)
    stop:SetFrameLevel(base + 4)
    if g then
        local side = f:GetWidth() * g.stop.r * 2
        stop:SetSize(side, side)
        stop:SetPoint("CENTER", f, "TOPLEFT", g.stop.cx * f:GetWidth(), -g.stop.cy * f:GetHeight())
    else
        stop:SetSize(20, 20)
        stop:SetPoint("TOPRIGHT", -PAD, -PAD)
    end
    stop:RegisterForClicks("LeftButtonUp")
    stop:SetScript("OnClick", function() Dash.Stop() end)

    local function cap(name, setter)
        local part = ns.Data.Art and ns.Data.Art[name]
        if not part then
            return nil
        end
        local t = stop:CreateTexture(nil, "ARTWORK")
        if not t:SetTexture(MEDIA .. part.file) then
            return nil
        end
        t:SetTexCoord(part.l, part.r, part.t, part.b)
        t:SetAllPoints(stop)
        if setter then
            setter(t)
        end
        return t
    end

    local stopNormal = cap("dash2-stop")
    local stopPressed = cap("dash2-stop-pressed")
    if stopPressed then
        stopPressed:Hide()
        stop:SetScript("OnMouseDown", function()
            stopPressed:Show()
            if stopNormal then stopNormal:Hide() end
        end)
        stop:SetScript("OnMouseUp", function()
            stopPressed:Hide()
            if stopNormal then stopNormal:Show() end
        end)
    end
    local hover = ns.Data.Art and ns.Data.Art["dash2-stop-hover"]
    if hover then
        stop:SetHighlightTexture(MEDIA .. hover.file, "ADD")
    end
    if not stopNormal then
        -- No art: a flat coloured square still presses and still stops.
        W.Fill(stop, "ARTWORK", "hazard")
    end
```

Then update `Dash.Refresh` to fill the three lines and the glass. It currently
writes `ui.step` and `ui.next`; replace that with:

```lua
    for i = 1, 3 do
        ui.steps[i]:SetText(stepText(steps[state.index + i - 1]))
    end
    ui.destination:SetText(step.to and ns.Search.ShortName(step.to.name) or "")
```

**The banner needs somewhere to go, and this is the subtle part.** Plan 4's fix
wave made "Recalculating..." survive by holding it in `state.banner`, which
`Dash.Refresh` reads *instead of* the normal text for `ui.next`, and which the
top of `Dash.Tick` clears on the following tick. `ui.next` no longer exists, so
the banner must move without losing that behaviour. Put it on the first step
line, and blank the other two, so the panel reads as one message rather than a
message with stale directions under it:

```lua
    if state.banner then
        ui.steps[1]:SetText(state.banner)
        ui.steps[2]:SetText("")
        ui.steps[3]:SetText("")
    else
        for i = 1, 3 do
            ui.steps[i]:SetText(stepText(steps[state.index + i - 1]))
        end
    end
```

Leave the clearing in `Dash.Tick` exactly as it is: it already blanks
`state.banner` and calls `Refresh()` before evaluating the next verdict, which
is what stops the message sticking. Change only the widget, never the timing.

Elsewhere in `Dash.Tick`, wherever it writes "Arrived." to `ui.step`, write to
`ui.steps[1]` and blank `ui.steps[2]` and `ui.steps[3]`.

Add all the new names to the `ui` table: `destination`, `steps`, `eta`, `stop`,
`stopNormal`, `stopPressed`.

- [ ] **Step 4: Re-point the plan 4 tests that read the old widgets**

`ui.step` and `ui.next` are gone, so the tests that read them must read
`ui.steps[1]` and `ui.steps[2]` instead. **Change the read, never the
assertion** — these are plan 4's contract for the trip loop and they still
hold. In `test/test_ui.lua` they are at roughly lines 528, 529, 535, 536, 633,
652, 755, 828, 832 and 895.

Two need more than a rename:

- The wrap test at 583-585 asserted `ui.step.wordWrap` was true because the old
  single line had to wrap to fit a long stop name. The panel now gives three
  short lines inside a box the artist sized, so wrapping is wrong there: each
  line truncates. Replace that test with one asserting all three lines
  truncate and sit inside `geometry.stepsText`.
- The fallback test at 882 loads a second copy of the module
  (`local FreshDash = assert(loadfile("GoblinPS/Dash.lua"))("GoblinPS", ns)`)
  because `build()` runs once per instance. Reuse that exact idiom for the new
  stop-button fallback test rather than inventing another; if you use it twice,
  lift it to a local helper.

- [ ] **Step 5: Run the tests to verify they pass**

Run the Lua suite. Expected: green.

- [ ] **Step 6: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 7: Commit**

```bash
git add GoblinPS/Dash.lua test/test_ui.lua
git commit -m "Dash unit: the words on the glass, three steps, and a button that presses" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---


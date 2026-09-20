### Task 4: The device, on flat colours

**Files:**
- Create: `GoblinPS/Dash.lua`
- Modify: `GoblinPS/GoblinPS.toc`
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `ns.Widgets` (`Panel`, `Text`, `Button`, `Fill`, `COLOR`), `ns.Core.Position` and `ns.Core.SavePosition`.
- Produces, for task 5: `Dash.Start(plan)`, `Dash.Stop()`, `Dash.Debug()` returning `ui, state`, and `Dash.SIZE = { 200, 250 }`.

This task draws the device and nothing else: no trip, no ticking, no events. It must look right and survive dragging before it is given a job.

The layout, top to bottom, inside a 200 by 250 frame:

- a round screen area, 180 square, `screen` coloured, at the top;
- the arrow, 90 square, centred on that screen, drawn from `Interface\Buttons\WHITE8X8` tinted green until task 6 gives it real art;
- the distance, large, centred under the screen;
- the ETA plate: one line, centred;
- the current step, two lines' worth of width, wrapping off;
- the next step, dimmer;
- a small "Stop" button at the bottom right.

- [ ] **Step 1: Write the failing test**

Add to `test/test_ui.lua`, beside its other describe blocks:

```lua
-- Smoke test of the dash unit against test/fake_frames.lua. It catches our own
-- mistakes: nil calls, text in the wrong widget, a FontString with one anchor.
-- Real frame behaviour is checked in game from docs/manual-test-checklist.md.
return function(h, loaded)
    local ns = loaded.ns
    local Dash = ns.Dash

    local plan = {
        level = 60,
        result = {
            seconds = 600,
            steps = {
                { kind = "ride", seconds = 200, to = { name = "the North Gate", c = 1, x = 0, y = 0 } },
                { kind = "zeppelin", seconds = 240, to = { name = "East Dock", c = 1, x = 0, y = 0 } },
                { kind = "ride", seconds = 160, to = { name = "Delta", c = 1, x = 0, y = 0 } },
            },
        },
    }

    h.describe("the dash unit", function()
        h.it("opens on Start and shows the first step and the one after", function()
            Dash.Start(plan)
            local ui, state = Dash.Debug()
            h.truthy(ui.frame:IsShown())
            h.eq(state.index, 1)
            h.eq(ui.step:GetText(), "Ride to the North Gate")
            h.eq(ui.next:GetText(), "then Zeppelin to East Dock")
        end)
        h.it("says nothing follows the last step", function()
            local ui, state = Dash.Debug()
            state.index = 3
            Dash.Refresh()
            h.eq(ui.step:GetText(), "Ride to Delta")
            h.eq(ui.next:GetText(), "")
            state.index = 1
            Dash.Refresh()
        end)
        h.it("every line of text is bounded", function()
            local ui = Dash.Debug()
            for _, name in ipairs({ "step", "next", "distance", "eta" }) do
                local fs = ui[name]
                h.truthy(fs.points and #fs.points >= 2,
                         name .. " needs two horizontal anchors or it will draw past the frame")
            end
        end)
        h.it("dragging saves the position", function()
            local ui = Dash.Debug()
            ui.frame:SetPoint("TOP", UIParent, "BOTTOM", 7, -11)
            ui.frame.scripts.OnDragStart(ui.frame)
            ui.frame.scripts.OnDragStop(ui.frame)
            local p = GoblinPSDB.positions.dash
            h.eq(p.point, "TOP")
            h.eq(p.relativePoint, "BOTTOM")
            h.eq(p.x, 7)
            h.eq(p.y, -11)
        end)
        h.it("Stop closes it", function()
            local ui = Dash.Debug()
            Dash.Stop()
            h.falsy(ui.frame:IsShown())
        end)
        h.it("Start with no steps does not open", function()
            Dash.Start({ result = { steps = {} } })
            h.falsy(Dash.Debug().frame:IsShown())
        end)
    end)
end
```

- [ ] **Step 2: Run to verify it fails**

Add `"Dash"` to the module list inside `test/test_ui.lua` (the `for _, file in ipairs({...})` line), after `"Planner"` and before `"MinimapButton"`. Run the Lua suite. Expected: FAIL, `ns.Dash` is nil.

- [ ] **Step 3: Write the device**

Create `GoblinPS/Dash.lua`. It owns one frame and never builds a second set of widgets:

```lua
local _, ns = ...

-- The dash unit: a small draggable device showing the step you are on, an
-- arrow that turns to point at it, how far is left and how long. Built on flat
-- colours; task 6 lays the art over them, and a texture that does not load
-- must leave this readable.
local Dash = {}
ns.Dash = Dash

local W = ns.Widgets

Dash.SIZE = { 200, 250 }
local PAD, SCREEN = 10, 180

local ui              -- built on first Start
local state = {}      -- plan, index, best (closest yet to the current target)

local function stepText(step)
    return step and ns.Route.StepText(step) or ""
end

-- Draws whatever is in `state`. Safe to call at any time.
function Dash.Refresh()
    if not ui or not state.plan then
        return
    end
    local steps = state.plan.result and state.plan.result.steps or {}
    local step = steps[state.index]
    if not step then
        return
    end
    ui.step:SetText(stepText(step))
    local following = steps[state.index + 1]
    ui.next:SetText(following and ("then " .. stepText(following)) or "")
end

local function build()
    local f = W.Panel(UIParent, "body", "brass", 3)
    f:SetSize(Dash.SIZE[1], Dash.SIZE[2])
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        ns.Core.SavePosition("dash", point, relativePoint, x, y)
    end)
    f:Hide()

    local screen = W.Panel(f, "screen", "steel", 2)
    screen:SetSize(SCREEN, SCREEN)
    screen:SetPoint("TOP", 0, -PAD)

    local arrow = screen:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(90, 90)
    arrow:SetPoint("CENTER")
    arrow:SetTexture("Interface\\Buttons\\WHITE8X8")
    arrow:SetVertexColor(unpack(W.COLOR.green))

    local distance = W.Text(f, "green", "GameFontNormalLarge", "CENTER")
    distance:SetPoint("TOPLEFT", screen, "BOTTOMLEFT", 0, -4)
    distance:SetPoint("TOPRIGHT", screen, "BOTTOMRIGHT", 0, -4)

    local eta = W.Text(f, "dim", "GameFontNormalSmall", "CENTER")
    eta:SetPoint("TOPLEFT", distance, "BOTTOMLEFT", 0, -2)
    eta:SetPoint("TOPRIGHT", distance, "BOTTOMRIGHT", 0, -2)

    local step = W.Text(f, "green", "GameFontNormalSmall", "CENTER")
    step:SetPoint("TOPLEFT", eta, "BOTTOMLEFT", 0, -6)
    step:SetPoint("TOPRIGHT", eta, "BOTTOMRIGHT", 0, -6)

    local following = W.Text(f, "dim", "GameFontHighlightSmall", "CENTER")
    following:SetPoint("TOPLEFT", step, "BOTTOMLEFT", 0, -2)
    following:SetPoint("TOPRIGHT", step, "BOTTOMRIGHT", 0, -2)

    local stop = W.Button(f, "Stop", 48, 20, function() Dash.Stop() end)
    stop:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    ui = { frame = f, screen = screen, arrow = arrow, distance = distance,
           eta = eta, step = step, next = following, stop = stop }
    ns.Core.CloseOnEscape(f, "GoblinPSDash")
end

-- Begin a trip. A plan with no steps is not a trip, and opens nothing.
function Dash.Start(plan)
    if not ui then
        build()
        local p = ns.Core.Position("dash")
        ui.frame:ClearAllPoints()
        if p then
            ui.frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
        else
            ui.frame:SetPoint("CENTER", UIParent, "CENTER", -260, 0)
        end
    end
    local steps = plan and plan.result and plan.result.steps or {}
    if #steps == 0 then
        return
    end
    state.plan, state.index, state.best = plan, 1, nil
    Dash.Refresh()
    ui.frame:Show()
end

function Dash.Stop()
    state.plan, state.index, state.best = nil, nil, nil
    if ui then
        ui.frame:Hide()
    end
end

-- For the desktop smoke test only.
function Dash.Debug()
    return ui, state
end

return Dash
```

Add to `GoblinPS/GoblinPS.toc`, after `Planner.lua` and before `MinimapButton.lua`:

```
Dash.lua
```

and `Data\Art.lua` after `Data\Zones.lua`. Set `## Version: 2026.09.20.2`.

- [ ] **Step 4: Run the tests to verify they pass**

Run the Lua suite. Expected: green.

- [ ] **Step 5: Lint**

Run luacheck and the language server. Expected: zero warnings. Add `GoblinPSDash` to both config files.

- [ ] **Step 6: Commit**

```bash
git add GoblinPS/Dash.lua GoblinPS/GoblinPS.toc test/test_ui.lua .luacheckrc .luarc.json
git commit -m "Dash unit: the device on flat colours" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---


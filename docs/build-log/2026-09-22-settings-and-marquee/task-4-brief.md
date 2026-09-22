### Task 4: the settings panel

**Files:**
- Create: `GoblinPS/Settings.lua`
- Modify: `GoblinPS/GoblinPS.toc` (add `Settings.lua` after `Planner.lua`)
- Modify: `GoblinPS/API.lua` (`addonName`, `API.AddOnVersion`, one `SelfCheck` row)
- Modify: `GoblinPS/Planner.lua` (the gear, `OnHide`, `Planner.OpenSettings`)
- Modify: `GoblinPS/Core.lua` (`/gps settings`, `/gps hearth` refreshes the panel, help)
- Modify: `test/fake_frames.lua` (`HighlightText`)
- Modify: `test/test_ui.lua` (load `Settings`; fake `AddOnVersion`; a new block)
- Modify: `.luacheckrc`, `.luarc.json`

**Interfaces:**
- Consumes: Task 3's `Prefs.HEARTH_MINUTES`, `Prefs.ARRIVE`, `Prefs.Step`,
  `Core.Arrive`, `Core.SetArrive`, `Core.ResetSettings`; existing
  `Core.HearthSaving()` (seconds), `Core.SetHearthSaving(seconds)`,
  `Core.CloseOnEscape(frame, globalName)`, `Planner.Replan()`,
  `W.Panel`, `W.Text`, `W.Button`, `W.EditBox`, `W.SetButtonEnabled`,
  `W.UpdatePlaceholder`.
- Produces: `ns.Settings` with `Settings.FEEDBACK_URL` (nil), `Settings.SIZE =
  { 320, 368 }`, `Settings.Open(anchor)`, `Settings.Close()`,
  `Settings.Toggle(anchor)`, `Settings.Refresh()`, `Settings.Debug()` -> `ui`
  with fields `frame, title, rows, reset, honest, version, tagline, feedback,
  url, close, cursor`; each `rows[i]` is `{ spec, frame, label, value, minus,
  plus, note }` and `spec` is `{ label, range, get, set, show, note }`.
  `API.AddOnVersion()` -> string or nil. `Planner.OpenSettings()`. The
  global `GoblinPSSettings`.

The panel's stack, top to bottom, at `PAD` = 12: the title (26), five rows
(24 each) with the transport row's note (28) under it, Reset (28), the honest
line (28), a gap (8), the version (18), the tagline (16), the feedback line
(16) and the copy box (22). That ends 322 px down; Close sits 12 px off the
bottom at 20 px tall, so 368 leaves 14 px clear.

- [ ] **Step 1: Teach the fake to select an edit box's text**

In `test/fake_frames.lua`, after `function Region:ClearFocus() ... end`, add:

```lua
-- Modelled, not swallowed: the feedback box selects its whole address when
-- it takes focus, so the player can copy it, and a test must see that it did.
function Region:HighlightText(start, stop) self.highlighted = { start or 0, stop or -1 } end
```

- [ ] **Step 2: Write the failing tests**

In `test/test_ui.lua`:

1. Add `AddOnVersion = function() return "2099.01.01" end,` to the `ns.API`
   table, directly after `SelfCheck = ...`.
2. Add `"Settings"` to the load list directly after `"Planner"`.
3. Directly before the final `print = realPrint`, add:

```lua
    h.describe("the settings panel", function()
        local Settings = ns.Settings
        local function openPlanner()
            if not Planner.Debug().frame:IsShown() then
                Planner.Toggle()
            end
            return Planner.Debug()
        end
        -- What the client does on Escape: hide every shown frame UISpecialFrames names.
        local function pressEscape()
            for _, name in ipairs(UISpecialFrames) do
                local frame = _G[name]
                if frame and frame:IsShown() then
                    frame:Hide()
                end
            end
        end

        h.it("opens from the gear, centred over the planner and one strata above it", function()
            local pui = openPlanner()
            Fake.Click(pui.gear)
            local ui = Settings.Debug()
            h.truthy(ui.frame:IsShown())
            h.eq(#ui.frame.points, 1)
            local p = ui.frame.points[1]
            h.eq(p[1], "CENTER")
            h.truthy(p[2] == pui.frame, "centred on the planner, not the screen")
            h.eq(p[3], "CENTER")
            h.eq(p[4], 0)
            h.eq(p[5], 0)
            h.eq(pui.frame:GetFrameStrata(), "HIGH")
            h.eq(ui.frame:GetFrameStrata(), "DIALOG")
            h.eq(ui.frame:GetWidth(), Settings.SIZE[1])
            h.eq(ui.frame:GetHeight(), Settings.SIZE[2])
            Fake.Click(pui.gear)
            h.falsy(ui.frame:IsShown(), "the gear puts it away again")
        end)

        h.it("opens from /gps settings, bringing the planner up under it", function()
            local pui = Planner.Debug()
            if pui.frame:IsShown() then
                Planner.Toggle()
            end
            SlashCmdList.GOBLINPS("settings")
            h.truthy(pui.frame:IsShown(), "the panel sits over the planner, so the planner opens first")
            h.truthy(Settings.Debug().frame:IsShown())
            h.truthy(Settings.Debug().frame.points[1][2] == pui.frame)
        end)

        h.it("closes on Close, on Escape, and with the planner", function()
            local ui = Settings.Debug()
            Fake.Click(ui.close)
            h.falsy(ui.frame:IsShown(), "Close")
            SlashCmdList.GOBLINPS("settings")
            local listed = false
            for _, name in ipairs(UISpecialFrames) do
                listed = listed or name == "GoblinPSSettings"
            end
            h.truthy(listed, "Escape closes a frame only through UISpecialFrames")
            h.truthy(GoblinPSSettings == ui.frame)
            GoblinPSSettings:Hide()
            h.falsy(ui.frame:IsShown(), "Escape's entry for the panel")
            h.truthy(Planner.Debug().frame:IsShown(), "is the panel's alone")
            SlashCmdList.GOBLINPS("settings")
            pressEscape()
            h.falsy(ui.frame:IsShown(), "Escape")
            SlashCmdList.GOBLINPS("settings")
            Planner.Toggle()
            h.falsy(Planner.Debug().frame:IsShown())
            h.falsy(ui.frame:IsShown(), "closing the planner closes it too")
        end)

        h.it("stacks its rows down the panel, every line bounded, nothing under Close", function()
            SlashCmdList.GOBLINPS("settings")
            local ui = Settings.Debug()
            local labels = { "Hearthstone must save", "Ground arrival", "Flight arrival",
                             "Boat, zeppelin, tram arrival", "Hearthstone arrival" }
            h.eq(#ui.rows, #labels)
            local lastY = 0
            for i, row in ipairs(ui.rows) do
                h.eq(row.label:GetText(), labels[i])
                local p1, p2 = row.frame.points[1], row.frame.points[2]
                h.truthy(p1[2] == ui.frame and p2[2] == ui.frame, "row " .. i .. " hangs from the panel")
                h.eq(p1[1], "TOPLEFT")
                h.eq(p2[1], "TOPRIGHT")
                h.eq(p1[5], p2[5], "row " .. i .. " is level")
                h.truthy(p1[5] < lastY, "row " .. i .. " sits below the one before")
                lastY = p1[5]
                h.eq(row.plus.points[1][1], "RIGHT")
                h.truthy(row.plus.points[1][2] == row.frame, "+ at the row's right end")
                h.truthy(row.value.points[1][2] == row.plus, "the value just left of +")
                h.truthy(row.minus.points[1][2] == row.value, "and - just left of the value")
                h.truthy(row.label.points[2][2] == row.minus, "the label stops short of -")
            end
            local texts = { ui.title, ui.honest, ui.version, ui.tagline, ui.feedback, ui.rows[4].note }
            for _, row in ipairs(ui.rows) do
                texts[#texts + 1] = row.label
                texts[#texts + 1] = row.value
            end
            for i, fs in ipairs(texts) do
                h.truthy(#fs.points >= 2 or fs.width, "text " .. i .. " has two anchors or a width")
            end
            local close = ui.close.points[1]
            h.eq(close[1], "BOTTOM")
            h.truthy(close[2] == ui.frame)
            h.truthy(-ui.cursor + close[5] + ui.close:GetHeight() <= Settings.SIZE[2],
                     "the last line ends above Close")
        end)

        h.it("moves every number by its step and clamps it at both ends", function()
            local ui = Settings.Debug()
            for _, row in ipairs(ui.rows) do
                local range, name = row.spec.range, row.spec.label
                local start = row.spec.get()
                Fake.Click(row.plus)
                h.eq(row.spec.get(), start + range.step, name .. ": + adds one step")
                Fake.Click(row.minus)
                h.eq(row.spec.get(), start, name .. ": - takes it back")
                for _ = 1, (range.max - range.min) / range.step + 2 do
                    Fake.Click(row.minus)
                end
                h.eq(row.spec.get(), range.min, name .. ": clamped at the bottom")
                h.falsy(row.minus:IsEnabled(), name .. ": - greys out at the bottom")
                for _ = 1, (range.max - range.min) / range.step + 2 do
                    Fake.Click(row.plus)
                end
                h.eq(row.spec.get(), range.max, name .. ": clamped at the top")
                h.falsy(row.plus:IsEnabled(), name .. ": + greys out at the top")
                h.truthy(row.minus:IsEnabled())
                h.eq(row.value:GetText(), row.spec.show(range.max))
            end
            h.eq(GoblinPSDB.hearthSaving, 30 * 60, "the hearth row stores seconds")
            h.eq(GoblinPSDB.arrive.transport, 1000)
        end)

        h.it("Reset to defaults puts all five back", function()
            local ui = Settings.Debug()
            Fake.Click(ui.reset)
            h.eq(GoblinPSDB.hearthSaving, ns.Prefs.HEARTH_SAVING_DEFAULT)
            for key, range in pairs(ns.Prefs.ARRIVE) do
                h.eq(GoblinPSDB.arrive[key], range.default, key)
            end
            local want = { "5 min", "40 yd", "150 yd", "800 yd", "300 yd" }
            for i, row in ipairs(ui.rows) do
                h.eq(row.value:GetText(), want[i], "row " .. i .. " shows its default")
            end
        end)

        h.it("shares the hearthstone value with /gps hearth, both ways", function()
            local ui = Settings.Debug()
            local hearth = ui.rows[1]
            SlashCmdList.GOBLINPS("hearth 12")
            h.eq(hearth.value:GetText(), "12 min", "the open panel follows the chat command")
            Fake.Click(hearth.plus)
            h.eq(GoblinPSDB.hearthSaving, 13 * 60)
            local from = #printed
            SlashCmdList.GOBLINPS("hearth")
            h.truthy(table.concat(printed, " ", from + 1, #printed):find("~13 min", 1, true),
                     "and the chat command reads what the panel set")
            SlashCmdList.GOBLINPS("hearth 0")
            h.eq(hearth.value:GetText(), "any", "0 means whenever it is faster")
            Fake.Click(ui.reset)
        end)

        h.it("an arrival change reaches Trip.Check: 30 yards out advances at 40, not at 20", function()
            local ui = Settings.Debug()
            local ground = ui.rows[2]
            Fake.Click(ground.minus)
            Fake.Click(ground.minus)
            h.eq(ground.value:GetText(), "20 yd")
            local function rideTo(name)
                return { kind = "ride", seconds = 200, to = { name = name, c = 1, x = 0, y = 0, map = 1 } }
            end
            ns.Dash.Start({ level = 60, to = ns.Search.Exact(ns.Data, "Westland", "H"),
                            result = { seconds = 400, steps = { rideTo("Alpha"), rideTo("Delta") } } })
            local _, dash = ns.Dash.Debug()
            where.map, where.mx, where.my = 1, 1, (10000 - 30) / 10000 -- world 30, 0: 30 yards out
            ns.Dash.Tick("tick")
            h.eq(dash.index, 1, "not there yet at 20 yards")
            Fake.Click(ground.plus)
            Fake.Click(ground.plus)
            ns.Dash.Tick("tick")
            h.eq(dash.index, 2, "there at 40")
            ns.Dash.Stop()
        end)

        h.it("names the version the client reads from the TOC, through API", function()
            local ui = Settings.Debug()
            h.eq(ui.version:GetText(), "GoblinPS 2099.01.01")
            h.eq(ui.tagline:GetText(), "Accuracy not guaranteed. No refunds.")
            local saved = ns.API.AddOnVersion
            ns.API.AddOnVersion = function() return nil end
            Settings.Refresh()
            h.eq(ui.version:GetText(), "GoblinPS (version unknown)", "an API that does not answer says so")
            ns.API.AddOnVersion = saved
            Settings.Refresh()
        end)

        h.it("says feedback is coming soon, and offers a copyable address once there is one", function()
            local ui = Settings.Debug()
            h.eq(Settings.FEEDBACK_URL, nil, "no page exists yet, so none is printed")
            h.eq(ui.feedback:GetText(), "Feedback: a GitHub page is coming soon.")
            h.falsy(ui.url:IsShown())
            Settings.FEEDBACK_URL = "https://example.invalid/feedback"
            Settings.Refresh()
            h.truthy(ui.url:IsShown())
            h.eq(ui.url:GetText(), Settings.FEEDBACK_URL)
            h.falsy(ui.feedback:GetText():find("coming soon", 1, true))
            ui.url.scripts.OnEditFocusGained(ui.url)
            h.truthy(ui.url.highlighted, "focus selects the whole address, ready to copy")
            Fake.Type(ui.url, "typed over")
            h.eq(ui.url:GetText(), Settings.FEEDBACK_URL, "the address cannot be typed over")
            Settings.FEEDBACK_URL = nil
            Settings.Refresh()
            h.falsy(ui.url:IsShown())
            h.eq(ui.feedback:GetText(), "Feedback: a GitHub page is coming soon.")
        end)

        h.it("says plainly that settings last one session on this build", function()
            local ui = Settings.Debug()
            h.eq(ui.honest:GetText(),
                 "On this beta build, settings last until you reload: the client does not load saved data yet.")
            h.eq(ui.honest.wordWrap, true, "a sentence that long wraps inside the panel")
            h.truthy(ui.rows[4].note:GetText():find("100 yd", 1, true), "the transport floor gives its reason")
            h.eq(ui.rows[2].note, nil, "only the transport row carries a note")
            Settings.Close()
        end)
    end)
```

In `.luacheckrc`, add `"GoblinPSSettings"` to `globals` after
`"GoblinPSPlanner"`, and `"C_AddOns"` to `read_globals` after
`"UiMapPoint"`. In `.luarc.json`, add `"GoblinPSSettings"` after
`"GoblinPSPlanner"` and `"C_AddOns"` after `"UiMapPoint"` in
`diagnostics.globals`.

- [ ] **Step 3: Run the Lua gate to see them fail**

Expected: the run stops with an error naming `GoblinPS/Settings.lua`:
`test/test_ui.lua` loads it with `assert(loadfile(...))` and the file does
not exist yet. That is the expected red (plan 8's Task 1 met the same with
`Strip.lua`).

- [ ] **Step 4: `API.AddOnVersion` in `GoblinPS/API.lua`**

Change the first line to `local addonName, ns = ...`. After `API.Level`, add:

```lua
-- The version in GoblinPS.toc, as the client read it: "2026.09.22.1". Nil
-- when the client cannot say. C_AddOns.GetAddOnMetadata is present on build
-- 1.60.1.69913 (AddOnsDocumentation.lua; Blizzard_AddOnList calls it), which
-- on this build is not the same as answering -- the About box says
-- "(version unknown)" rather than guess.
function API.AddOnVersion()
    if not (C_AddOns and C_AddOns.GetAddOnMetadata) then
        return nil
    end
    local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
    return type(version) == "string" and version ~= "" and version or nil
end
```

In `API.SelfCheck`'s `checks`, after the `UnitOnTaxi` row, add
`{ "C_AddOns.GetAddOnMetadata", C_AddOns and C_AddOns.GetAddOnMetadata },`.

- [ ] **Step 5: Write `GoblinPS/Settings.lua`**

```lua
local _, ns = ...

-- The settings panel behind the planner's gear: how much the hearthstone must
-- save, how close counts as arriving, Reset, and an About box. A plain panel
-- in the gadget palette with no art of its own yet (docs/later.md). Every
-- control is a W.Button, never a Blizzard template, so there are no sliders:
-- each number has a - and a +, and Prefs.Step clamps it to its range.
--
-- Its own window, centred over the planner one strata above it, closed by
-- Close, by Escape (UISpecialFrames) and with the planner. It has no art and
-- no geometry, so its spacing numbers live here, named once below.
local Settings = {}
ns.Settings = Settings

local W = ns.Widgets

-- Where to send feedback. Nil until the page exists: the owner said it does
-- not yet and did not want it made, so no address is printed -- not even the
-- repository's. Set it and the About box shows it in a box to copy from,
-- because text in the game cannot be clicked open.
Settings.FEEDBACK_URL = nil

Settings.SIZE = { 320, 368 }
local PAD = 12      -- the panel's margin on every side
local TITLE = 26    -- the heading's line
local ROW = 24      -- one number row
local NOTE = 28     -- a dim note of up to two lines
local LINE = 16     -- one line of small text
local BUTTON = 20   -- the - and + buttons are square; Close and Reset are this tall
local VALUE = 64    -- the value between - and +
local GAP = 6       -- between a row's label and its - button

local ui

local function minutes(seconds)
    return math.floor(seconds / 60 + 0.5)
end

-- The five numbers, top to bottom. Each reads and writes through Core in the
-- unit it shows. ns.Core is looked up when a row is used: Core loads last.
local ROWS = {
    { label = "Hearthstone must save", range = ns.Prefs.HEARTH_MINUTES,
      get = function() return minutes(ns.Core.HearthSaving()) end,
      set = function(v)
          ns.Core.SetHearthSaving(v * 60)
          ns.Planner.Replan()
      end,
      show = function(v) return v == 0 and "any" or (v .. " min") end },
}
local function arrival(key, label, hint)
    ROWS[#ROWS + 1] = { label = label, range = ns.Prefs.ARRIVE[key], note = hint,
                        get = function() return ns.Core.Arrive(key) end,
                        set = function(v) ns.Core.SetArrive(key, v) end,
                        show = function(v) return v .. " yd" end }
end
arrival("ride", "Ground arrival")
arrival("fly", "Flight arrival")
arrival("transport", "Boat, zeppelin, tram arrival",
        "No tighter than 100 yd: some dock positions are still estimates, and a trip could never arrive.")
arrival("hearth", "Hearthstone arrival")

-- Paint every value, grey out a button at its end, and fill the About box.
-- Safe to call at any time; /gps hearth calls it so an open panel keeps up.
function Settings.Refresh()
    if not ui then
        return
    end
    for _, row in ipairs(ui.rows) do
        local v = row.spec.get()
        row.value:SetText(row.spec.show(v))
        W.SetButtonEnabled(row.minus, v > row.spec.range.min)
        W.SetButtonEnabled(row.plus, v < row.spec.range.max)
    end
    ui.version:SetText("GoblinPS " .. (ns.API.AddOnVersion() or "(version unknown)"))
    local url = Settings.FEEDBACK_URL
    if url then
        ui.feedback:SetText("Feedback: select the address below and copy it.")
        ui.url:SetText(url)
        ui.url:Show()
    else
        ui.feedback:SetText("Feedback: a GitHub page is coming soon.")
        ui.url:SetText("")
        ui.url:Hide()
    end
    W.UpdatePlaceholder(ui.url)
end

local function nudge(row, direction)
    row.spec.set(ns.Prefs.Step(row.spec.get(), row.spec.range, direction))
    Settings.Refresh()
end

-- A dim sentence that may take two lines, bounded on both sides.
local function note(parent, color, text)
    local fs = W.Text(parent, color)
    fs:SetWordWrap(true)
    fs:SetHeight(NOTE)
    fs:SetText(text)
    return fs
end

local function build()
    local f = W.Panel(UIParent, "body", "brass", 3)
    f:SetSize(Settings.SIZE[1], Settings.SIZE[2])
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)   -- a click on the panel must not fall through to the planner
    f:Hide()

    -- A top-to-bottom stack: each region hangs full width at the cursor, with
    -- two horizontal anchors, and the cursor moves down past it.
    local y = -PAD
    local function stack(region, height)
        region:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
        region:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y)
        y = y - height
    end

    local title = W.Text(f, "amber", "GameFontNormalLarge", "CENTER")
    title:SetText("Settings")
    stack(title, TITLE)

    local rows = {}
    for i, spec in ipairs(ROWS) do
        local entry = { spec = spec }
        local row = CreateFrame("Frame", nil, f)
        row:SetHeight(ROW)
        stack(row, ROW)
        -- Right to left: +, the value, -, then the label takes what is left.
        local plus = W.Button(row, "+", BUTTON, BUTTON, function() nudge(entry, 1) end)
        plus:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        local value = W.Text(row, "green", nil, "CENTER")
        value:SetWidth(VALUE)
        value:SetPoint("RIGHT", plus, "LEFT", 0, 0)
        local minus = W.Button(row, "-", BUTTON, BUTTON, function() nudge(entry, -1) end)
        minus:SetPoint("RIGHT", value, "LEFT", 0, 0)
        local label = W.Text(row, "green")
        label:SetPoint("LEFT", row, "LEFT", 0, 0)
        label:SetPoint("RIGHT", minus, "LEFT", -GAP, 0)
        label:SetText(spec.label)
        entry.frame, entry.label, entry.value, entry.minus, entry.plus = row, label, value, minus, plus
        if spec.note then
            entry.note = note(f, "dim", spec.note)
            stack(entry.note, NOTE)
        end
        rows[i] = entry
    end

    local reset = W.Button(f, "Reset to defaults", 130, BUTTON, function()
        ns.Core.ResetSettings()
        ns.Planner.Replan()
        Settings.Refresh()
    end)
    reset:SetPoint("TOP", f, "TOP", 0, y - 4)
    y = y - (BUTTON + 8)

    -- CLAUDE.md: say plainly what does not work. Comes out when a build loads
    -- saved data again.
    local honest = note(f, "amber",
        "On this beta build, settings last until you reload: the client does not load saved data yet.")
    stack(honest, NOTE)
    y = y - 8

    local version = W.Text(f, "amber", "GameFontNormal")
    stack(version, LINE + 2)
    local tagline = W.Text(f, "dim")
    tagline:SetText("Accuracy not guaranteed. No refunds.")
    stack(tagline, LINE)
    local feedback = W.Text(f, "dim")
    stack(feedback, LINE)

    -- The address, when there is one, in a box the player can select and copy
    -- from: the usual addon pattern, since game text cannot be clicked open.
    -- Typing cannot change it; focus selects all of it.
    local url = W.EditBox(f, 200, BUTTON + 2, "")
    url:SetMaxLetters(255)
    stack(url, BUTTON + 2)
    url:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    url:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(Settings.FEEDBACK_URL or "")
            self:HighlightText()
        end
    end)
    url:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    url:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local close = W.Button(f, "Close", 80, BUTTON, function() Settings.Close() end)
    close:SetPoint("BOTTOM", f, "BOTTOM", 0, PAD)

    ui = { frame = f, title = title, rows = rows, reset = reset, honest = honest, version = version,
           tagline = tagline, feedback = feedback, url = url, close = close, cursor = y }
    ns.Core.CloseOnEscape(f, "GoblinPSSettings")
end

-- Show the panel centred over `anchor` (the planner's window).
function Settings.Open(anchor)
    if not ui then
        build()
    end
    ui.frame:ClearAllPoints()
    ui.frame:SetPoint("CENTER", anchor or UIParent, "CENTER", 0, 0)
    Settings.Refresh()
    ui.frame:Show()
end

function Settings.Close()
    if ui then
        ui.frame:Hide()
    end
end

function Settings.Toggle(anchor)
    if ui and ui.frame:IsShown() then
        Settings.Close()
    else
        Settings.Open(anchor)
    end
end

-- For the desktop smoke test only.
function Settings.Debug()
    return ui
end

return Settings
```

In `GoblinPS/GoblinPS.toc`, add `Settings.lua` on its own line directly after
`Planner.lua`.

- [ ] **Step 6: `GoblinPS/Planner.lua`**

Replace the gear's comment and `OnClick`:

```lua
    -- The gear opens the settings panel over this window, and closes it again.
    local gear = CreateFrame("Button", nil, content)
    gear:RegisterForClicks("LeftButtonUp")
    gear:SetScript("OnClick", function()
        dismiss()
        ns.Settings.Toggle(f)
    end)
```

Replace `f:SetScript("OnHide", hideResults)` with:

```lua
    -- The settings panel sits over this window, so it goes when this does.
    f:SetScript("OnHide", function()
        hideResults()
        ns.Settings.Close()
    end)
```

After `function Planner.Replan() ... end`, add:

```lua
-- /gps settings: the panel sits over the planner, so open the planner first.
function Planner.OpenSettings()
    if not (ui and ui.frame:IsShown()) then
        Planner.Toggle()
    end
    ns.Settings.Open(ui.frame)
end
```

- [ ] **Step 7: `GoblinPS/Core.lua`**

In `slash`, add a branch before `elseif command == "minimap" then`:

```lua
    elseif command == "settings" then
        ns.Planner.OpenSettings()
```

In the `hearth` branch, change the closing `ns.Planner.Replan()` to:

```lua
            ns.Planner.Replan()
            ns.Settings.Refresh()   -- an open panel shows the new value
```

In the help list, after the `/gps hearth <min>` line, add
`say("/gps settings     open the settings panel")`.

- [ ] **Step 8: Run every gate**

Lua: expected `384 passed, 0 failed` (373 + 11). Python and art green.
luacheck and the language server from PowerShell: zero warnings. Grep:
`grep -n "not built yet" GoblinPS` must print nothing.

- [ ] **Step 9: Commit**

```
git add GoblinPS/Settings.lua GoblinPS/GoblinPS.toc GoblinPS/API.lua GoblinPS/Planner.lua GoblinPS/Core.lua test/fake_frames.lua test/test_ui.lua .luacheckrc .luarc.json
git commit -m "Settings panel behind the gear" -m "A plain panel over the planner, one strata up: the hearthstone's saving and four arrival radii, each with - and + clamped to its range, Reset, one honest line that settings last a session on this build, and About with the TOC version read through API.AddOnVersion. Feedback reads coming soon; a copyable box waits behind Settings.FEEDBACK_URL. Opens from the gear and /gps settings; Close, Escape and the planner close it." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---


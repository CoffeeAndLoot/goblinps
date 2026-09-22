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

-- The stack, top to bottom: PAD 12 + title 26 + six rows 6 x 24 + the
-- transport note 28 + Reset 28 + the amber note 28 + 8 + version 18 +
-- tagline 16 + feedback 16 + the address 22 = 346, then Close's own 20 and
-- PAD 12 at the bottom: 378, and 14 spare so nothing touches Close.
Settings.SIZE = { 320, 392 }
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

local SCROLL_NAMES = { off = "Off", slow = "Slow", normal = "Normal", fast = "Fast" }

-- The six rows, top to bottom. Each reads and writes through Core in the
-- unit it shows. ns.Core is looked up when a row is used: Core loads last.
local ROWS = {
    { label = "Hearthstone must save", range = ns.Prefs.HEARTH_MINUTES,
      get = function() return minutes(ns.Core.HearthSaving()) end,
      set = function(v)
          ns.Core.SetHearthSaving(v * 60)
          ns.Planner.Replan()
      end,
      show = function(v) return v == 0 and "any" or (v .. " min") end },
    -- The scrolling text is a list, not a number: the row steps through its
    -- positions in Prefs.SCROLL and shows each by name. A saved value that
    -- is not in the list reads as the default, so Refresh always has a number.
    { label = "Scrolling text", range = { min = 1, max = #ns.Prefs.SCROLL, step = 1 },
      get = function()
          return ns.Prefs.ScrollIndex(ns.Core.Scroll()) or ns.Prefs.ScrollIndex(ns.Prefs.SCROLL_DEFAULT)
      end,
      set = function(i) ns.Core.SetScroll(ns.Prefs.SCROLL[i]) end,
      show = function(i) return SCROLL_NAMES[ns.Prefs.SCROLL[i]] end },
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
    -- The panel and the planner's results list are both DIALOG strata, so
    -- only their frame level settles who draws on top. Left at its default,
    -- this frame sits at the planner's own level -- the same tie the list's
    -- children broke by going to level + 3 -- so the list could be reopened
    -- over an open panel and cover it, taking its clicks (client report
    -- 2026-09-22). +10 clears that and everything else on the planner.
    ui.frame:SetFrameLevel((anchor and anchor:GetFrameLevel() or 0) + 10)
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

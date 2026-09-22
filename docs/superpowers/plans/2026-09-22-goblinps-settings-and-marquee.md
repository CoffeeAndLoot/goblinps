# Settings, Scrolling Dash Text, a Narrower Drop-down (plan 9) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the planner's gear a working settings panel (the hearthstone's
saving, four arrival radii, Reset, About), make the dash's too-long lines
scroll like an old car radio, and draw the results drop-down only a little
wider than its longest name.

**Architecture:** A new pure `Marquee.lua` turns text plus elapsed time into
the text to show; `Dash.lua` runs it on its existing `OnUpdate`, judging fit
from the geometry and the dash frame's explicit size. `Prefs.lua` gains the
arrival radii with their ranges and validation; `Trip.Check` reads
`state.arrive` and falls back to `Trip.ARRIVE`. A new `Settings.lua` draws a
plain panel in the gadget palette. `Planner.lua` measures every label the
search can offer with the rows' real font and narrows the list to fit.

**Tech Stack:** Lua 5.1 against the WoW Forever client API (build
1.60.1.69913, interface 16001), no libraries; desktop tests through lupa.

**Spec:** `docs/superpowers/specs/2026-09-21-goblinps-settings-and-marquee-design.md`
(binding). It amends `docs/superpowers/specs/2026-09-19-goblinps-design.md`
and `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`.

## Global Constraints

- Plain Lua 5.1, **no libraries**, **no Blizzard frame templates**, no secure code.
- `API.lua` is the only file that calls Blizzard game APIs. UI files may use
  UI globals the siblings already use (`CreateFrame`, `UIParent`, `GameTooltip`,
  `UISpecialFrames`).
- **Never read a size from a frame that only inherits one.** Measure the frame
  given an explicit `SetSize` (the dash's `ui.frame`, the planner's `ui.frame`),
  never a FontString or a frame placed by `SetAllPoints` or two anchors. Slot
  widths are geometry fractions times that frame's width.
- **A test that checks how big a thing is cannot tell you it is in the wrong
  place.** Pin positions, not only sizes.
- Every FontString gets two horizontal anchors (or a width) and decides wrap
  or truncate.
- A missing texture must leave a working window.
- No coordinate is hand-typed in `Planner.lua` or `Dash.lua`: every position
  comes from `ns.Data.ArtGeometry`. `Settings.lua` has no art and no geometry
  (spec ruling 3), so its plain top-to-bottom stack keeps its own spacing
  constants, named at the top of the file.
- Route text stays plain and glanceable.
- Lint and the language server at **zero warnings**; do not silence a warning,
  fix the code. No new `---@diagnostic disable`, `luacheck:` exemption or
  `max_line_length = false`. A new WoW global goes in **both** `.luacheckrc`
  and `.luarc.json`.
- Never guess an event, API or method name: check it in
  `D:\wow-api\1.60.1.69913` (the `forever` branch; its `version.txt` reads
  `1.60.1.69913`). Verified for this plan:
  - `FontString:GetUnboundedStringWidth()` -> `width`
    (`SimpleFontStringAPIDocumentation.lua`; Blizzard's own
    `ChatConfigFrame.lua` and `UserScaledElementTemplates.lua` call it).
  - `EditBox:HighlightText(start = 0, stop = -1)`, `EditBox:SetMaxLetters`,
    `EditBox:SetText` (`SimpleEditBoxAPIDocumentation.lua`).
  - `C_AddOns.GetAddOnMetadata(name, variable)` -> `value`
    (`AddOnsDocumentation.lua`, namespace `C_AddOns`; `Blizzard_AddOnList/AddonList.lua`
    calls it).
  - Present is not the same as answering on this build (CLAUDE.md). Both
    `GetUnboundedStringWidth` and `GetAddOnMetadata` are **unverified in
    game**; the code falls back safely when either answers nothing (a 0 width
    leaves a line still and the list at its geometry width; a nil version
    reads "(version unknown)"), and the checklist asks for the look.
- Any widget method the fake frames do not model is added to
  `test/fake_frames.lua` in the task that first calls it: modelled when it
  has an effect a test must see, `ALLOWED_NOOP` only when it has none.
- Commit after each task. **Never stage `AGENTS.md`** (it belongs to Codex).
  Never push. Do not switch branches: the work is on `settings-and-marquee`.
- Gates, all green before a task is done (run from `D:\goblinps`):
  - Lua: `python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"`
  - Python: `python -m unittest discover -s test/tools`
  - Art: `python tools/check_art.py`
  - luacheck and lua-language-server **from PowerShell**, as in `CLAUDE.md`
    ("Commands"). Through Git Bash the language server mis-scopes itself and
    reports bogus warnings.
- Known state at the start (checked 2026-09-21 on this branch at `c5b422c`):
  Lua **351 passed, 0 failed**; Python 55 tests OK; `check_art.py`
  `47 pass, 0 with problems`. This plan touches no Python or art, so those
  two must simply stay green.

## Dependency on plan 8

The project rule is to write each plan after the one before it has been used
in game. Plan 8 was seen in the client on 2026-09-21 (the window, the strip,
the tooltips, a whole Crossroads to Silverpine trip). Plan 9 touches plan 8 at
three seams: the gear (it opens settings instead of saying "not built yet"),
the planner's `OnHide` (it now also closes settings), and the results list's
width. Everything else in `Planner.lua` stays as it is.

## Rulings this plan makes (the spec left these open)

Record each in the ledger for the owner.

1. **`/gps settings` opens the planner first when it is closed**, then the
   panel over it. The spec centres the panel over the planner and closes it
   with the planner, so a panel with no planner under it would contradict both.
2. **The gear toggles the panel**: a second click puts it away.
3. **The hearthstone row's 0 to 30 minutes bounds the panel's buttons only.**
   `/gps hearth` still takes any number of minutes, as it does today. A value
   above 30 set that way shows as it is, `+` greys out, and `-` brings it to 30.
   0 shows as "any" (spec: 0 means "whenever it is faster").
4. **`-` is the ASCII hyphen**, not the en dash the spec typeset: every font
   on the client has it.
5. **A button greys out at its end of the range** (`W.SetButtonEnabled`), so
   the clamp is visible, not only enforced.
6. **The arrival defaults are read from `Trip.ARRIVE`**, not typed twice:
   `Prefs.ARRIVE.transport.default` is `Trip.ARRIVE.zeppelin`.
7. **The marquee restarts whenever a line's text is set to anything other than
   what the marquee itself last drew.** That is how "restarts on new text" is
   told apart from its own scrolling without touching every `SetText` in
   `Dash.lua`. A consequence: the distance and ETA are set every tick, so one
   too long for its plate would restart every half second and hold at its
   start. Both are a few characters ("700 yd", "~12 min") and fit today.
8. **The marquee never starts a line on half a character**: it steps over
   UTF-8 continuation bytes.
9. **The drop-down is measured over what the search can offer this character**
   (every zone and every flight stop legal for its faction), using a new public
   `Search.Candidates`, the same list `Search.Find` ranks. The padding is the
   rows' own insets (2 px row edge plus 6 px label edge, each side), now named
   constants. A measurement of 0 leaves the list at its geometry width.
10. **The fake measures text at `Fake.CHAR_WIDTH` = 5 px a character, for every
    font.** It is a stand-in chosen so today's dash fixture lines fit their
    slots ("Ride to the North Gate" is 110 px in a 130.2 px slot); it says
    nothing about the real font, which is what the checklist is for.

## File map

- Create `GoblinPS/Marquee.lua`: pure character-window marquee.
- Create `test/test_marquee.lua`: its tests.
- Create `GoblinPS/Settings.lua`: the settings panel.
- Modify `GoblinPS/GoblinPS.toc`: load `Marquee.lua` and `Settings.lua`; version.
- Modify `test/run.lua`: load `Marquee`, run `test_marquee.lua`.
- Modify `GoblinPS/Dash.lua`: slot widths, `Dash.Scroll`, the radii into `Trip.Check`.
- Modify `GoblinPS/Trip.lua`: `Trip.Check` reads `state.arrive`.
- Modify `GoblinPS/Prefs.lua`: `HEARTH_MINUTES`, `ARRIVE`, `Step`, `Reset`,
  `ArriveRadii`, `db.arrive` validation.
- Modify `GoblinPS/Core.lua`: arrival accessors, `ResetSettings`,
  `/gps settings`, `/gps hearth` refreshes the panel.
- Modify `GoblinPS/API.lua`: `API.AddOnVersion()`, one `SelfCheck` row.
- Modify `GoblinPS/Planner.lua`: the gear, `OnHide`, `Planner.OpenSettings`,
  the measured drop-down.
- Modify `GoblinPS/Search.lua`: `Search.Candidates` made public.
- Modify `test/fake_frames.lua`: `GetUnboundedStringWidth`, `HighlightText`.
- Modify `test/test_ui.lua`, `test/test_prefs.lua`, `test/test_trip.lua`,
  `test/test_search.lua`.
- Modify `.luacheckrc`, `.luarc.json`: `C_AddOns`, `GoblinPSSettings`.
- Docs: `docs/manual-test-checklist.md`, `docs/later.md`, `CLAUDE.md`, the spec's status.

Untouched: routing, `Strip.lua`, art, geometry, tools.

---

### Task 1: `Marquee.lua`, the character window

**Files:**
- Create: `GoblinPS/Marquee.lua`
- Create: `test/test_marquee.lua`
- Modify: `GoblinPS/GoblinPS.toc` (add `Marquee.lua` after `Trip.lua`)
- Modify: `test/run.lua` (module list and suite list)

**Interfaces:**
- Consumes: nothing.
- Produces: `ns.Marquee` with `Marquee.HOLD = 1.5`, `Marquee.STEP = 0.2`,
  `Marquee.GAP = "   "` (three spaces), `Marquee.New(text, fits)` -> a state
  table `{ text, fits, offset, clock }`, and `Marquee.Advance(m, dt)` -> the
  string to show. Task 2 calls both.

- [ ] **Step 1: Write the failing tests**

Create `test/test_marquee.lua`:

```lua
return function(h, loaded)
    local Marquee = loaded.ns.Marquee
    local HOLD, STEP, GAP = Marquee.HOLD, Marquee.STEP, Marquee.GAP

    h.describe("Marquee", function()
        h.it("holds a line that does not fit at its start for HOLD seconds", function()
            h.eq(GAP, "   ", "the wrap gap is three spaces")
            local m = Marquee.New("Ride to Far Crossing", false)
            h.eq(Marquee.Advance(m, 0), "Ride to Far Crossing")
            h.eq(Marquee.Advance(m, HOLD - 0.01), "Ride to Far Crossing", "still holding")
        end)

        h.it("then drops one character every STEP", function()
            local m = Marquee.New("Abcdef", false)
            h.eq(Marquee.Advance(m, HOLD + 0.01), "bcdef" .. GAP .. "Abcdef")
            h.eq(Marquee.Advance(m, STEP), "cdef" .. GAP .. "Abcdef")
            h.eq(Marquee.Advance(m, STEP / 2), "cdef" .. GAP .. "Abcdef", "half a step moves nothing")
            h.eq(Marquee.Advance(m, STEP / 2), "def" .. GAP .. "Abcdef")
        end)

        h.it("wraps round through the gap to the start, and holds again", function()
            local m = Marquee.New("Abc", false)
            h.eq(Marquee.Advance(m, HOLD + 0.01), "bc" .. GAP .. "Abc")
            h.eq(Marquee.Advance(m, STEP), "c" .. GAP .. "Abc")
            h.eq(Marquee.Advance(m, STEP), GAP .. "Abc", "the gap comes round")
            h.eq(Marquee.Advance(m, STEP), GAP:sub(2) .. "Abc")
            h.eq(Marquee.Advance(m, STEP), GAP:sub(3) .. "Abc")
            h.eq(Marquee.Advance(m, STEP), "Abc", "back at the start")
            h.eq(Marquee.Advance(m, HOLD - 0.05), "Abc", "and holding there again")
            h.eq(Marquee.Advance(m, 0.1), "bc" .. GAP .. "Abc")
        end)

        h.it("never moves text that fits", function()
            local m = Marquee.New("Delta", true)
            h.eq(Marquee.Advance(m, 0), "Delta")
            h.eq(Marquee.Advance(m, 60), "Delta")
        end)

        h.it("never moves an empty line", function()
            local m = Marquee.New("", false)
            h.eq(Marquee.Advance(m, 60), "")
            h.eq(Marquee.Advance(Marquee.New(nil, false), 60), "", "no text reads as empty")
        end)

        h.it("starts every new line fresh, at its start", function()
            local m = Marquee.New("Uvwxyz", false)
            h.eq(m.offset, 1)
            h.eq(m.clock, 0)
            h.eq(Marquee.Advance(m, STEP), "Uvwxyz", "a new line holds before it moves")
        end)

        h.it("never starts a line on half a character", function()
            -- "été": the first step would land on the second byte of the é.
            local ete = "\195\169t\195\169"
            local m = Marquee.New(ete, false)
            h.eq(Marquee.Advance(m, HOLD + 0.01), "t\195\169" .. GAP .. ete)
        end)
    end)
end
```

- [ ] **Step 2: Load it in the runner**

In `test/run.lua`, add `{ "Marquee", "GoblinPS/Marquee.lua" },` to `modules`
directly after the `Trip` row, and `"test/test_marquee.lua",` to `suites`
directly after `"test/test_strip.lua",`.

- [ ] **Step 3: Run the Lua gate to see them fail**

Expected: the runner skips the missing `Marquee.lua` (it checks `io.open`), so
every test in `test_marquee.lua` fails on `Marquee` being nil: 351 passed,
7 failed.

- [ ] **Step 4: Write `GoblinPS/Marquee.lua`**

```lua
local _, ns = ...

-- Scrolling text for the dash, the way the LED radios in old cars did it: a
-- character window. A line too long for its opening holds still at its start
-- for HOLD seconds, then drops its first character every STEP seconds, runs
-- round through a GAP and back to its start, and holds again. The
-- FontString's own truncation cuts the right edge, so this needs no clipping,
-- no new frames and no new API. A line that fits never moves.
--
-- Pure: state in, text out, no frames. The dash decides whether a line fits
-- (from its geometry, never from the FontString) and calls Advance every
-- frame from the OnUpdate it already runs.
local Marquee = {}
ns.Marquee = Marquee

Marquee.HOLD = 1.5   -- seconds the start is shown before it moves, and again after each lap
Marquee.STEP = 0.2   -- seconds per character
Marquee.GAP = "   "  -- between the end of the text and its start coming round again

-- A fresh marquee for `text`, at its start. `fits` is the caller's verdict.
function Marquee.New(text, fits)
    return { text = text or "", fits = fits and true or false, offset = 1, clock = 0 }
end

-- A byte in the middle of a UTF-8 character: showing from one would draw
-- half a letter.
local function continues(byte)
    return byte ~= nil and byte >= 128 and byte < 192
end

-- Moves the window on by `dt` seconds and answers the text to show.
function Marquee.Advance(m, dt)
    if m.fits or m.text == "" then
        return m.text
    end
    local tape = m.text .. Marquee.GAP
    m.clock = m.clock + (dt or 0)
    while true do
        local wait = m.offset == 1 and Marquee.HOLD or Marquee.STEP
        if m.clock < wait then
            break
        end
        m.clock = m.clock - wait
        m.offset = m.offset + 1
        while continues(tape:byte(m.offset)) do
            m.offset = m.offset + 1
        end
        if m.offset > #tape then
            m.offset = 1
        end
    end
    if m.offset == 1 then
        return m.text
    end
    -- The start follows the gap in, so the lap reads as one continuous tape.
    return tape:sub(m.offset) .. m.text
end

return Marquee
```

In `GoblinPS/GoblinPS.toc`, add `Marquee.lua` on its own line directly after
`Trip.lua`.

- [ ] **Step 5: Run every gate**

Lua: expected `358 passed, 0 failed` (351 + 7). Python and art unchanged and
green. luacheck and the language server from PowerShell: zero warnings.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Marquee.lua GoblinPS/GoblinPS.toc test/test_marquee.lua test/run.lua
git commit -m "Marquee.lua: scrolling text as a character window" -m "Holds a line that does not fit at its start, drops one character a step, wraps round through a three-space gap and holds again, never on half a UTF-8 character. A line that fits never moves. Pure, so the dash only feeds it time." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

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

### Task 3: the arrival radii, from the save to `Trip.Check`

**Files:**
- Modify: `GoblinPS/Prefs.lua` (header comment, constants, `Prefs.Init`, three new functions)
- Modify: `GoblinPS/Trip.lua:12-26` (`Trip.Check`)
- Modify: `GoblinPS/Core.lua:51-52` (four accessors)
- Modify: `GoblinPS/Dash.lua` (`Dash.Tick` hands the radii to `Trip.Check`)
- Modify: `test/test_prefs.lua`, `test/test_trip.lua`, `test/test_ui.lua`

**Interfaces:**
- Consumes: `ns.Trip.ARRIVE` (= `{ ride = 40, fly = 150, zeppelin = 800,
  boat = 800, tram = 800, hearth = 300 }`), loaded before `Prefs.lua` in the
  TOC and in both test loaders.
- Produces, for Task 4:
  - `Prefs.HEARTH_MINUTES = { min = 0, max = 30, step = 1 }`
  - `Prefs.ARRIVE[key] = { default, min, max, step, kinds }` for
    `key` in `ride`, `fly`, `transport`, `hearth`
  - `Prefs.Step(value, range, direction)` -> number, `direction` is 1 or -1
  - `Prefs.Reset(db)`, `Prefs.ArriveRadii(db)` -> `{ [tripKind] = yards }`
  - `db.arrive = { ride, fly, transport, hearth }` (yards), always valid after `Prefs.Init`
  - `Core.Arrive(key)` -> yards, `Core.SetArrive(key, yards)`,
    `Core.ArriveRadii()` -> `{ [tripKind] = yards }`, `Core.ResetSettings()`
  - `Trip.Check(step, state)` reads `state.arrive[step.kind]` when given.

- [ ] **Step 1: Write the failing tests**

In `test/test_trip.lua`, inside `h.describe("Trip.Check", ...)`, after
"advances a boat that docked":

```lua
        h.it("judges arrival by the radius it is handed", function()
            local ride = { kind = "ride", to = target }
            local pos = at(1000, 8970) -- 30 yards out
            h.eq(Trip.Check(ride, { pos = pos, event = "tick", arrive = { ride = 20 } }), "stay")
            h.eq(Trip.Check(ride, { pos = pos, event = "tick", arrive = { ride = 40 } }), "advance")
        end)
        h.it("falls back to Trip.ARRIVE for a kind it is not handed", function()
            local boat = { kind = "boat", to = target }
            local pos = at(1500, 9000) -- 500 yards out
            h.eq(Trip.Check(boat, { pos = pos, event = "zone", arrive = { ride = 20 } }), "advance",
                 "800 yards by default")
            h.eq(Trip.Check(boat, { pos = pos, event = "zone", arrive = { boat = 300 } }), "stay")
        end)
```

In `test/test_prefs.lua`, directly before the final `end`:

```lua
    h.describe("the arrival radii", function()
        local ARRIVE = loaded.ns.Trip.ARRIVE
        h.it("default to Trip's own radii", function()
            local db = Prefs.Init(nil)
            h.eq(db.arrive.ride, ARRIVE.ride)
            h.eq(db.arrive.fly, ARRIVE.fly)
            h.eq(db.arrive.transport, ARRIVE.zeppelin)
            h.eq(db.arrive.hearth, ARRIVE.hearth)
            for key, range in pairs(Prefs.ARRIVE) do
                for _, kind in ipairs(range.kinds) do
                    h.eq(range.default, ARRIVE[kind], key .. " covers " .. kind .. " at Trip's radius")
                end
            end
        end)
        h.it("keep an in-range value the player chose", function()
            local db = Prefs.Init({ arrive = { ride = 20, transport = 100 } })
            h.eq(db.arrive.ride, 20)
            h.eq(db.arrive.transport, 100, "the floor itself is allowed")
            h.eq(db.arrive.fly, 150, "a missing one is filled in")
        end)
        h.it("repair hostile and out-of-range values", function()
            local db = Prefs.Init({ arrive = { ride = "near", fly = 5, transport = 5000, hearth = 0 / 0 } })
            h.eq(db.arrive.ride, 40, "not a number")
            h.eq(db.arrive.fly, 150, "under the floor")
            h.eq(db.arrive.transport, 800, "over the ceiling")
            h.eq(db.arrive.hearth, 300, "NaN")
            h.eq(Prefs.Init({ arrive = "junk" }).arrive.ride, 40, "a hostile table is replaced")
        end)
        h.it("fan the one transport value out to zeppelin, boat and tram", function()
            local db = Prefs.Init({ arrive = { transport = 300 } })
            local radii = Prefs.ArriveRadii(db)
            h.eq(radii.zeppelin, 300)
            h.eq(radii.boat, 300)
            h.eq(radii.tram, 300)
            h.eq(radii.ride, 40)
            h.eq(radii.fly, 150)
            h.eq(radii.hearth, 300)
        end)
        h.it("Reset puts the hearthstone and every radius back", function()
            local db = Prefs.Init({ hearthSaving = 0,
                                    arrive = { ride = 20, fly = 50, transport = 100, hearth = 1000 } })
            Prefs.Reset(db)
            h.eq(db.hearthSaving, Prefs.HEARTH_SAVING_DEFAULT)
            for key, range in pairs(Prefs.ARRIVE) do
                h.eq(db.arrive[key], range.default, key)
            end
        end)
    end)

    h.describe("Prefs.Step", function()
        h.it("moves by the range's step and clamps at both ends", function()
            local ride = Prefs.ARRIVE.ride
            h.eq(Prefs.Step(40, ride, 1), 50)
            h.eq(Prefs.Step(40, ride, -1), 30)
            h.eq(Prefs.Step(200, ride, 1), 200, "the ceiling")
            h.eq(Prefs.Step(10, ride, -1), 10, "the floor")
            h.eq(Prefs.Step(45, Prefs.HEARTH_MINUTES, -1), 30, "a value /gps hearth set above the range comes in")
            h.eq(Prefs.Step(nil, ride, -1), 10, "a value it cannot read starts from the floor")
        end)
    end)
```

In `test/test_ui.lua`, inside `h.describe("the dash unit drives the trip", ...)`,
after "advances when you reach the step's target":

```lua
            h.it("judges arrival by the player's own radius", function()
                ns.Core.SetArrive("ride", 20)
                Dash.Start(plan)
                local _, state = Dash.Debug()
                standAt(30, 0)
                Dash.Tick("tick")
                h.eq(state.index, 1, "30 yards out is not there at 20")
                ns.Core.SetArrive("ride", 40)
                Dash.Tick("tick")
                h.eq(state.index, 2, "and is at 40")
                ns.Core.ResetSettings()
                h.eq(ns.Core.Arrive("ride"), 40)
            end)
```

- [ ] **Step 2: Run the Lua gate to see them fail**

Expected: the Trip test "judges arrival by the radius it is handed" fails
(the default 40 advances at 30 yards); the Prefs tests fail on
`db.arrive` / `Prefs.ARRIVE` being nil; the UI test fails on
`ns.Core.SetArrive` being nil. "falls back to Trip.ARRIVE" passes already.

- [ ] **Step 3: `GoblinPS/Trip.lua`**

Replace the state comment and the arrival line of `Trip.Check`:

```lua
-- state: pos = { c, x, y } or nil (instances); onTaxi = bool; event =
-- "tick" | "landed" | "zone"; best = closest the player has been to the
-- step's target so far, tracked by the caller; arrive = { [kind] = yards },
-- the player's own radii (Prefs.ArriveRadii), or nil for Trip.ARRIVE's.
-- Returns "advance", "recalculate", "stay" or "pause".
function Trip.Check(step, state)
    if not state.pos then
        return "pause"
    end
    if state.onTaxi then
        return "stay"
    end
    local d = ns.Geo.Distance(state.pos, step.to)
    local radius = state.arrive and state.arrive[step.kind] or Trip.ARRIVE[step.kind]
    if d <= radius then
        return "advance"
    end
```

(the rest of the function is unchanged). Change the comment above
`Trip.ARRIVE` to: `-- Yards from a step's target that count as "arrived", unless the player
-- chose their own (Prefs.ARRIVE takes its defaults from here).`

- [ ] **Step 4: `GoblinPS/Prefs.lua`**

In the header comment, after the `trips` paragraph, add:

```lua
-- `arrive`: the player's arrival radii in yards, { ride, fly, transport,
-- hearth }, set from the settings panel and repaired here.
```

After `Prefs.HEARTH_SAVING_DEFAULT = 300   -- five minutes`, add:

```lua
-- The settings panel's hearthstone row, in whole minutes. `/gps hearth` takes
-- any number of minutes; only the panel's buttons keep to this range.
Prefs.HEARTH_MINUTES = { min = 0, max = 30, step = 1 }

-- How close counts as arriving, per setting, in yards. The defaults are
-- Trip.ARRIVE's own, so the rule and the panel cannot disagree; `kinds` is
-- the Trip step kinds each setting covers. One value serves boat, zeppelin
-- and tram: all three arrive when you step off at a dock. Its floor is 100
-- yards because several dock coordinates are still estimates, and a radius
-- tighter than the error in the data would never let a trip advance. The
-- 800-yard default stays until a dock is measured in game.
local ARRIVE = ns.Trip.ARRIVE
Prefs.ARRIVE = {
    ride      = { default = ARRIVE.ride, min = 10, max = 200, step = 10, kinds = { "ride" } },
    fly       = { default = ARRIVE.fly, min = 50, max = 500, step = 25, kinds = { "fly" } },
    transport = { default = ARRIVE.zeppelin, min = 100, max = 1000, step = 50,
                  kinds = { "zeppelin", "boat", "tram" } },
    hearth    = { default = ARRIVE.hearth, min = 100, max = 1000, step = 50, kinds = { "hearth" } },
}
```

In `Prefs.Init`, directly before `return db`:

```lua
    -- Arrival radii. A hostile, missing or out-of-range value (NaN included:
    -- it is the one number unequal to itself) falls back to its default. The
    -- panel can only set values inside the range, so one outside it was
    -- never the player's choice.
    db.arrive = type(db.arrive) == "table" and db.arrive or {}
    for key, range in pairs(Prefs.ARRIVE) do
        local v = db.arrive[key]
        if type(v) ~= "number" or v ~= v or v < range.min or v > range.max then
            db.arrive[key] = range.default
        end
    end
```

After `Prefs.Init`, add:

```lua
-- One press of a settings button: `value` moved one step up (direction 1) or
-- down (-1), clamped into the range. A value it cannot read starts from the
-- floor.
function Prefs.Step(value, range, direction)
    local v = (type(value) == "number" and value or range.min) + direction * range.step
    return math.max(range.min, math.min(range.max, v))
end

-- Reset to defaults: the hearthstone's saving and every arrival radius.
function Prefs.Reset(db)
    db.hearthSaving = Prefs.HEARTH_SAVING_DEFAULT
    db.arrive = {}
    for key, range in pairs(Prefs.ARRIVE) do
        db.arrive[key] = range.default
    end
end

-- The radii by Trip step kind, for Trip.Check: each setting fanned out to
-- the kinds it covers.
function Prefs.ArriveRadii(db)
    local out = {}
    for key, range in pairs(Prefs.ARRIVE) do
        for _, kind in ipairs(range.kinds) do
            out[kind] = db.arrive[key]
        end
    end
    return out
end
```

- [ ] **Step 5: `GoblinPS/Core.lua`**

After `function Core.SetHearthSaving(seconds) prefs().hearthSaving = seconds end`, add:

```lua
function Core.Arrive(key) return prefs().arrive[key] end
function Core.SetArrive(key, yards) prefs().arrive[key] = yards end
-- The player's radii by Trip step kind; the dash hands this to Trip.Check.
function Core.ArriveRadii() return Prefs.ArriveRadii(prefs()) end
function Core.ResetSettings() Prefs.Reset(prefs()) end
```

- [ ] **Step 6: `GoblinPS/Dash.lua`**

In `Dash.Tick`, the `Trip.Check` call becomes:

```lua
    local verdict = ns.Trip.Check(step, {
        pos = pos, onTaxi = ns.API.OnTaxi(), event = event, best = state.best,
        arrive = ns.Core.ArriveRadii(),
    })
```

- [ ] **Step 7: Run every gate**

Lua: expected `373 passed, 0 failed` (364 + 2 Trip + 6 Prefs + 1 UI). Python
and art green. luacheck and the language server from PowerShell: zero warnings.

- [ ] **Step 8: Commit**

```
git add GoblinPS/Prefs.lua GoblinPS/Trip.lua GoblinPS/Core.lua GoblinPS/Dash.lua test/test_prefs.lua test/test_trip.lua test/test_ui.lua
git commit -m "Arrival radii: saved, repaired, and read by Trip.Check" -m "GoblinPSDB.arrive holds ride, fly, transport and hearth radii with ranges and Trip.ARRIVE's defaults; Prefs.Init repairs hostile values, Prefs.Step clamps a button press, and the dash hands Trip.Check the player's radii with transport fanned out to zeppelin, boat and tram. Trip stays pure and falls back to its own." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

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

### Task 5: a drop-down only a little wider than its longest name

**Files:**
- Modify: `GoblinPS/Search.lua` (`Search.Candidates` made public)
- Modify: `GoblinPS/Planner.lua` (row inset constants, `rowLabel`, the
  measurement in build(), the width in `ApplyLayout`)
- Modify: `test/test_search.lua`, `test/test_ui.lua`

**Interfaces:**
- Consumes: the fake's `GetUnboundedStringWidth` and `Fake.CHAR_WIDTH` (Task 2);
  the geometry's `resultsList = { left = 0.20625, top = 0.371094,
  right = 0.88125, bottom = 0.634766 }`.
- Produces: `Search.Candidates(data, faction)` -> list of
  `{ kind = "zone"|"stop", name, ... }`; `ui.results.labelWidth` (px, or nil).

Numbers: the list's geometry width is (0.88125 - 0.20625) x 650 = 438.75 px.
The widest label the fake world offers the Horde is "Charlie  (flight stop)"
(22 characters, 110 px), so the list becomes 110 + 16 = 126 px.

- [ ] **Step 1: Write the failing tests**

In `test/test_search.lua`, after the `Search.Label` block:

```lua
    h.describe("Search.Candidates", function()
        h.it("offers every zone and every stop the faction may use", function()
            local zones, stops, names = 0, 0, {}
            for _, item in ipairs(Search.Candidates(world, "H")) do
                if item.kind == "zone" then
                    zones = zones + 1
                else
                    stops = stops + 1
                end
                names[item.name] = true
            end
            h.eq(zones, 5)
            h.eq(stops, 7)
            h.falsy(names.Echo, "an Alliance stop is not offered to the Horde")
            h.truthy(names.Charlie, "a neutral one is")
        end)
    end)
```

In `test/test_ui.lua`, at the end of `h.describe("the planner window", ...)`
(after "shows the idle status lines before a destination is picked"):

```lua
        -- The rows sit 2 px inside the list and each label 6 px inside its
        -- row, on both sides: 16 px of insets, mirrored from Planner.lua's
        -- ROW_EDGE and LABEL_EDGE.
        local INSETS = 16
        local function labelOf(item)
            return item.name .. (item.kind == "zone" and "" or "  (flight stop)")
        end

        h.it("draws the drop-down only a little wider than its longest name", function()
            local ui = Planner.Debug()
            Planner.ApplyLayout()
            local g, w, fh = ns.Data.ArtGeometry.planner.wide, ui.frame:GetWidth(), ui.frame:GetHeight()
            local widest = 0
            for _, item in ipairs(ns.Search.Candidates(ns.Data, "H")) do
                widest = math.max(widest, #labelOf(item) * Fake.CHAR_WIDTH)
            end
            h.eq(widest, 110, "Charlie  (flight stop) is the widest name the fake world offers")
            local tl, br = ui.results.points[1], ui.results.points[2]
            h.truthy(math.abs(tl[4] - g.resultsList.left * w) < 1e-9, "its left edge stays the geometry's")
            h.truthy(math.abs(tl[5] + g.resultsList.top * fh) < 1e-9, "and its top")
            h.truthy(math.abs(br[5] + g.resultsList.bottom * fh) < 1e-9, "and its bottom")
            local width = br[4] - tl[4]
            h.truthy(math.abs(width - (widest + INSETS)) < 1e-9, "the widest name plus the rows' insets")
            h.truthy(width < (g.resultsList.right - g.resultsList.left) * w, "narrower than the geometry")
            for _, item in ipairs(ns.Search.Candidates(ns.Data, "H")) do
                h.truthy(#labelOf(item) * Fake.CHAR_WIDTH <= width - INSETS, labelOf(item) .. " still fits its row")
            end
        end)

        h.it("never draws the drop-down wider than the geometry, however long the names", function()
            local savedPlanner, savedWidth = ns.Planner, Fake.CHAR_WIDTH
            Fake.CHAR_WIDTH = 100
            local ok, err = pcall(function()
                local FreshPlanner = assert(loadfile("GoblinPS/Planner.lua"))("GoblinPS", ns)
                ns.Planner = savedPlanner
                FreshPlanner.Toggle()
                local ui = FreshPlanner.Debug()
                local g, w = ns.Data.ArtGeometry.planner.wide, ui.frame:GetWidth()
                local width = ui.results.points[2][4] - ui.results.points[1][4]
                h.truthy(math.abs(width - (g.resultsList.right - g.resultsList.left) * w) < 1e-9,
                         "capped at the geometry's width")
                FreshPlanner.Toggle()
            end)
            ns.Planner, Fake.CHAR_WIDTH = savedPlanner, savedWidth
            -- The fresh window took the global Escape name; give it back.
            GoblinPSPlanner = Planner.Debug().frame
            h.truthy(ok, err)
        end)
```

- [ ] **Step 2: Run the Lua gate to see them fail**

Expected: `Search.Candidates` is nil (the search test and both planner tests
fail; the second fails on the first `ipairs` of a nil, the first on its own).

- [ ] **Step 3: `GoblinPS/Search.lua`**

Replace `local function candidates(data, faction)` with
`function Search.Candidates(data, faction)`, change its comment to
`-- Every destination the search can offer: every zone, and every flight stop
-- this faction may use (nil means any), zones first on a name tie so
-- "Orgrimmar" means the city. The planner measures its drop-down over this.`,
and change the two calls `candidates(data, faction)` (in `Search.Find` and
`Search.Exact`) to `Search.Candidates(data, faction)`.

- [ ] **Step 4: `GoblinPS/Planner.lua`**

Replace

```lua
local ROW = 18
-- The 2px inset the rows anchor with, top and bottom of the list's box.
local ROW_INSET = 4
```

with

```lua
local ROW = 18
-- The rows sit ROW_EDGE px inside the list's box on every side, and each
-- row's label LABEL_EDGE px inside its row. ROW_INSET is the top and bottom
-- edges together, which the rows that fit are counted against.
local ROW_EDGE, LABEL_EDGE = 2, 6
local ROW_INSET = 2 * ROW_EDGE
```

Directly before `local function showResults()`, add:

```lua
-- What a result row says. The drop-down's width is measured over this too.
local function rowLabel(item)
    return item.name .. (item.kind == "zone" and "" or "  (flight stop)")
end
```

and in `showResults` change
`row.label:SetText(item.name .. (item.kind == "zone" and "" or "  (flight stop)"))`
to `row.label:SetText(rowLabel(item))`.

In `build()`, the row loop's anchors use the constants:

```lua
        row:SetPoint("TOPLEFT", ROW_EDGE, -(ROW_EDGE + (i - 1) * ROW))
        row:SetPoint("TOPRIGHT", -ROW_EDGE, -(ROW_EDGE + (i - 1) * ROW))
```

```lua
        row.label:SetPoint("LEFT", LABEL_EDGE, 0)
        row.label:SetPoint("RIGHT", -LABEL_EDGE, 0)
```

and directly after the loop (before `ui = { ... }`), add:

```lua
    -- The widest label the search can ever offer, measured once in the rows'
    -- own font, so ApplyLayout can draw the list only a little wider than
    -- that. The first row's label is the ruler; it is blank again before
    -- anything shows it. GetUnboundedStringWidth is the text's own width, not
    -- the row's -- the row only inherits a size, which is never to be read.
    -- A width of 0 (a font that would not answer) leaves labelWidth nil and
    -- the list at the geometry's full width.
    local ruler = results.rows[1].label
    local widest = 0
    for _, item in ipairs(ns.Search.Candidates(ns.Data, ns.Core.Faction())) do
        ruler:SetText(rowLabel(item))
        widest = math.max(widest, ruler:GetUnboundedStringWidth())
    end
    ruler:SetText("")
    results.labelWidth = widest > 0 and widest or nil
```

In `ApplyLayout`, replace `W.PlaceRect(ui.results, f, g.resultsList)` with:

```lua
    -- Only a little wider than the longest name: the width measured at build
    -- plus the rows' insets, never past the geometry. Left, top and bottom
    -- are the geometry's. The widest name is data and the font sets its
    -- width, so no coordinate is typed here.
    local list = g.resultsList
    local hug = ((ui.results.labelWidth or math.huge) + 2 * (ROW_EDGE + LABEL_EDGE)) / f:GetWidth()
    W.PlaceRect(ui.results, f, { left = list.left, top = list.top, bottom = list.bottom,
                                 right = math.min(list.right, list.left + hug) })
```

- [ ] **Step 5: Run every gate**

Lua: expected `387 passed, 0 failed` (384 + 1 + 2). Python and art green.
luacheck and the language server from PowerShell: zero warnings.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Search.lua GoblinPS/Planner.lua test/test_search.lua test/test_ui.lua
git commit -m "Planner: the drop-down hugs its longest name" -m "Every label the search can offer is measured once in the rows' own font; the list is that plus the rows' insets, capped at the geometry, its left edge, top and bottom unchanged. Search.Candidates is the one list both the search and the measurement read." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: the checklist, the notes, and the version

**Files:**
- Modify: `docs/manual-test-checklist.md`, `docs/later.md`, `CLAUDE.md`,
  `docs/superpowers/specs/2026-09-21-goblinps-settings-and-marquee-design.md`,
  `GoblinPS/GoblinPS.toc` (version)

**Interfaces:** none (documentation only).

- [ ] **Step 1: The checklist**

In `docs/manual-test-checklist.md`, add this section directly after the
plan 8 section ("The planner as designed (plan 8)") and before
"## Flight paths survive a reload":

```markdown
## Settings, scrolling dash text, a narrower drop-down (plan 9)

**Needs a full game restart, not `/reload`:** the TOC gained `Marquee.lua` and
`Settings.lua`, and the client reads the file list only at startup. Built
2026-09-22; not yet run in the client.

- [ ] The gear opens the settings panel over the planner; the gear again,
      Close, and Escape each close it; closing the planner closes it too
- [ ] `/gps settings` with the planner closed opens the planner and the panel over it
- [ ] Every row's - and + change its value by one step; each stops at its end
      and that button greys out there
- [ ] The hearthstone row and `/gps hearth` agree: change one, the other shows it
- [ ] Reset to defaults puts back 5 min, 40, 150, 800 and 300 yd
- [ ] The panel looks decent without art -- or ask Codex for some (`docs/later.md`)
- [ ] Every label and value reads in full; the transport note and the amber
      line about saved data wrap inside the panel, not past it
- [ ] About shows "GoblinPS 2026.09.22.1". If it says "(version unknown)",
      `C_AddOns.GetAddOnMetadata` is one more API present on this build that
      does not answer: note it in CLAUDE.md's list
- [ ] The feedback line reads "Feedback: a GitHub page is coming soon." and
      no address is shown
- [ ] Lower "Boat, zeppelin, tram arrival" (say to 300 yd) and take a
      zeppelin: the dash advances only once you are that close to the far
      dock. Note how far from the dock's coordinates you really step off --
      that is the measurement the 800-yard default waits for
- [ ] A long step line on the dash (a long crossing name) holds about 1.5 s,
      then creeps left a character at a time, wraps round through a gap, and
      holds again; a short one holds still. If nothing ever scrolls,
      `GetUnboundedStringWidth` answers 0 on this build: say so
- [ ] On a step advance the new line starts at its beginning, never mid-name
- [ ] The glass's destination scrolls the same way when it is too long
- [ ] Type in the planner's box: the drop-down is only a little wider than the
      longest name, its left edge where it was, and no name in it is cut off.
      If it is still full width, the font measured 0 (see the line above)
```

- [ ] **Step 2: `docs/later.md`**

Delete the whole "**Scrolling text on the dash unit**" entry (it is built).
Add, as the first entry (newest at the top):

```markdown
- **Dress the settings panel with art.** Plan 9, 2026-09-22, built the panel
  plain: the gadget palette's body and brass, flat `-` / `+` buttons, no new
  parts, because the art is Codex's and nothing was asked of Codex. A dressed
  panel wants a frame, plate and button art like the planner's, and a
  geometry file for it, so its layout numbers come out of `Settings.lua` the
  way the planner's came out of `Planner.lua`.
```

- [ ] **Step 3: `CLAUDE.md`**

- Status: `**Status: plans 1 to 8 are built.**` becomes
  `**Status: plans 1 to 9 are built.**`. After the sentence ending
  "The rest of its checklist section is still to walk." add:
  "Plan 9, built 2026-09-22, put a settings panel behind the gear (the
  hearthstone's saving, four arrival radii, Reset, About), made the dash's
  too-long lines scroll like an old car radio (the pure `Marquee.lua`), and
  drew the drop-down only a little wider than its longest name. **Plan 9 has
  not been run in the client.**"
- The sentence "amended for plans 7 and 8 by
  `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`."
  becomes "amended for plans 7 and 8 by
  `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`
  and for plan 9 by
  `docs/superpowers/specs/2026-09-21-goblinps-settings-and-marquee-design.md`."
- Layout block: after the `Strip.lua` line add
  `GoblinPS/Marquee.lua          # pure: the dash's scrolling text, a character window`;
  change the `Known.lua, Prefs.lua` comment to
  `# pure: learned flight paths; account preferences, arrival radii and their ranges`;
  after the two `Planner.lua` lines add
  `GoblinPS/Settings.lua         # the settings panel behind the gear; plain, no art yet, so its spacing is its own`.

- [ ] **Step 4: The spec's status**

In `docs/superpowers/specs/2026-09-21-goblinps-settings-and-marquee-design.md`,
add a line directly under the `Status:` paragraph:
"Built 2026-09-22 by `docs/superpowers/plans/2026-09-22-goblinps-settings-and-marquee.md`
-- not yet run in the client."

- [ ] **Step 5: Version**

`GoblinPS/GoblinPS.toc`: `## Version: 2026.09.21.6` becomes
`## Version: 2026.09.22.1` (if another commit has already used that number,
take the next free one for the day, and change the checklist's About line to
match).

- [ ] **Step 6: Run every gate, then commit**

All five gates green; Lua still `387 passed, 0 failed`.

```
git add docs/manual-test-checklist.md docs/later.md CLAUDE.md docs/superpowers/specs/2026-09-21-goblinps-settings-and-marquee-design.md GoblinPS/GoblinPS.toc
git commit -m "Docs: plan 9 built, and what to walk in game" -m "The checklist gains the settings, scrolling text and drop-down section, with the full restart the new files need; later.md trades the built scrolling entry for dressing the settings panel; CLAUDE.md names Marquee.lua and Settings.lua and says plan 9 has not been run in the client. Version 2026.09.22.1." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

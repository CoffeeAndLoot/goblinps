### Task 4: the list scrolls on the wheel, with a footer

**Files:**
- Modify: `GoblinPS/Search.lua` (`Search.Find`: every match when no limit)
- Modify: `GoblinPS/Planner.lua` (`FOOTER`, `candidates`, `drawResults`,
  `scrollResults`, `showResults`, Enter, `fit` in `ApplyLayout`, the wheel and
  footer in `build()`)
- Modify: `test/fake_frames.lua` (`EnableMouseWheel`, `Fake.Wheel`)
- Modify: `test/test_search.lua`, `test/test_ui.lua`

**Interfaces:**
- Consumes: Task 3's `Search.Candidates`; the geometry's `resultsList = {
  left = 0.20625, top = 0.371094, right = 0.88125, bottom = 0.634766 }`
  (109.69 px tall at the planner's 416).
- Produces: `Search.Find(data, text, faction, limit)` returns every match when
  `limit` is nil. On the planner: `ui.results.items` (the full list),
  `ui.results.offset` (0-based index of the top row shown),
  `ui.results.footer` (FontString, 14 px, two bottom anchors),
  `ui.results.fit` (5 at 416 px); the list's `OnMouseWheel(self, delta)`
  script. The fake's `Region:EnableMouseWheel(enable)` sets `mouseWheel`, and
  `Fake.Wheel(frame, delta)` raises unless it is set. Task 5 builds on all of
  these and on `showResults`/`drawResults`.

Numbers: the list is (0.634766 - 0.371094) x 416 = 109.69 px. Rows start
2 px down and are 18 px each; five end at 92 px. The footer's slot is 14 px on
the bottom edge's 2 px inset, so its top is at 109.69 - 2 - 14 = 93.69 px, and
(109.69 - 4 - 14) / 18 = 5.09 still floors to 5 rows. In the fake world
"westland" matches six places (Alpha, Bravo, Charlie, Echo, Juliet, Quiet
Hollow), one more than fits, and "a" matches ten for the Horde.

- [ ] **Step 1: Teach the fake the wheel**

In `test/fake_frames.lua`, directly before the comment
`-- Modelled, not swallowed: the feedback box selects its whole address when`,
add:

```lua
-- Modelled, not swallowed: the client delivers the mouse wheel only to a
-- frame that enabled it, so Fake.Wheel refuses a frame that did not, and a
-- list that forgot the call fails on the desktop instead of lying still in
-- game. Verified present on SimpleScriptRegionAPIDocumentation.lua.
function Region:EnableMouseWheel(enable) self.mouseWheel = enable and true or false end

```

and directly after `function Fake.MouseDown(frame) ... end`, add:

```lua
-- One notch of the wheel over `frame`: 1 up, -1 down, as the client passes it.
function Fake.Wheel(frame, delta)
    assert(frame.mouseWheel, "the client sends no wheel to a frame that did not EnableMouseWheel")
    frame.scripts.OnMouseWheel(frame, delta)
end
```

- [ ] **Step 2: Write the failing tests**

In `test/test_search.lua`, inside `h.describe("Search.Find", ...)`, directly
after "respects the limit", add:

```lua
        h.it("returns every match when no limit is given", function()
            local all = Search.Find(world, "a", "H")
            h.eq(#all, 10, "more than the eight it used to stop at")
            h.eq(#all, #Search.Find(world, "a", "H", 100))
        end)
```

In `test/test_ui.lua`, in "keeps every result row inside the list's box":

1. Replace

```lua
            -- ROW mirrors Planner.lua's private row-height constant (18px);
            -- it has no other home to be read from.
```

with

```lua
            -- ROW mirrors Planner.lua's private row-height constant (18px);
            -- it has no other home to be read from. The footer's slot is
            -- read off the footer, which is given an explicit height.
```

2. Replace

```lua
            -- Real numbers at 416px: (109.69 - 4) / 18 floors to 5.
            h.eq(ui.results.fit, 5, "5 rows fit the 416px-tall window's list")
```

with

```lua
            local footerTop = listHeight - 2 - ui.results.footer:GetHeight()
            -- Real numbers at 416px: (109.69 - 4 - 14) / 18 floors to 5.
            h.eq(ui.results.fit, 5, "5 rows fit the 416px-tall window's list, the footer's slot kept free")
```

3. Replace

```lua
                    h.truthy(bottom <= listHeight,
                              "row " .. i .. " bottom edge must stay inside the list's own height")
```

with

```lua
                    h.truthy(bottom <= footerTop,
                              "row " .. i .. " bottom edge must stay above the footer's slot")
```

Then, directly before `h.describe("the route strip", function()`, add:

```lua
    h.describe("the results list scrolls, and browses zones", function()
        local function open()
            if not Planner.Debug().frame:IsShown() then
                Planner.Toggle()
            end
            return Planner.Debug()
        end
        local function labels(ui)
            local out = {}
            for _, row in ipairs(ui.results.rows) do
                if row:IsShown() then
                    out[#out + 1] = row.label:GetText()
                end
            end
            return table.concat(out, " | ")
        end
        local WESTLAND = { "Alpha · Westland", "Bravo · Westland", "Charlie · Westland",
                           "Echo · Westland (Alliance)", "Juliet · Westland", "Quiet Hollow · Westland" }

        h.it("keeps the footer in its own slot at the bottom of the list, bounded", function()
            local ui = open()
            local footer = ui.results.footer
            h.eq(footer:GetHeight(), 14)
            h.eq(#footer.points, 2, "two horizontal anchors, so it truncates")
            h.eq(footer.points[1][1], "BOTTOMLEFT")
            h.eq(footer.points[1][4], 8, "the label's own inset: row edge 2 plus label edge 6")
            h.eq(footer.points[1][5], 2, "on the list's bottom edge, inside its inset")
            h.eq(footer.points[2][1], "BOTTOMRIGHT")
            h.eq(footer.points[2][4], -8)
            h.eq(footer.points[2][5], 2)
            h.eq(footer.wordWrap, false, "one line")
            h.truthy(footer.points[1][2] == nil and footer.parent == ui.results, "it lives on the list")
        end)

        h.it("shows only what fits, and says where the window is when there is more", function()
            local ui = open()
            Fake.Type(ui.toBox, "westland")
            h.eq(labels(ui), table.concat(WESTLAND, " | ", 1, 5))
            h.truthy(ui.results.footer:IsShown())
            h.eq(ui.results.footer:GetText(), "1-5 of 6")
        end)

        h.it("scrolls one row a notch on the wheel, and clamps at both ends", function()
            local ui = open()
            h.truthy(ui.results.mouseWheel, "the list asked the client for the wheel")
            Fake.Wheel(ui.results, -1)
            h.eq(labels(ui), table.concat(WESTLAND, " | ", 2, 6), "one notch down, one row on")
            h.eq(ui.results.footer:GetText(), "2-6 of 6")
            Fake.Wheel(ui.results, -1)
            h.eq(ui.results.footer:GetText(), "2-6 of 6", "clamped at the bottom")
            h.eq(ui.results.rows[5].label:GetText(), WESTLAND[6])
            Fake.Wheel(ui.results, 1)
            Fake.Wheel(ui.results, 1)
            h.eq(ui.results.footer:GetText(), "1-5 of 6", "clamped at the top")
            h.eq(ui.results.rows[1].label:GetText(), WESTLAND[1])
        end)

        h.it("hides the footer when everything fits", function()
            local ui = open()
            Fake.Type(ui.toBox, "delt")
            h.eq(labels(ui), "Delta · Eastland")
            h.falsy(ui.results.footer:IsShown())
        end)

        h.it("starts again at the top whenever you type", function()
            local ui = open()
            Fake.Type(ui.toBox, "westland")
            Fake.Wheel(ui.results, -1)
            h.eq(ui.results.rows[1].label:GetText(), WESTLAND[2])
            Fake.Type(ui.toBox, "westlan")
            h.eq(ui.results.rows[1].label:GetText(), WESTLAND[1])
            h.eq(ui.results.footer:GetText(), "1-5 of 6")
        end)

        h.it("Enter picks the top row on screen, wherever the wheel left it", function()
            local ui, state = open()
            Fake.Type(ui.toBox, "westland")
            Fake.Wheel(ui.results, -1)
            ui.toBox.scripts.OnEnterPressed(ui.toBox)
            h.eq(state.to.nodeID, 2, "Bravo, the top row shown, not Alpha above it")
            -- put the destination back for the tests that follow
            Fake.Type(ui.toBox, "delt")
            Fake.Click(ui.results.rows[1])
            h.eq(state.to.nodeID, 4)
        end)
    end)

```

- [ ] **Step 3: Run the Lua gate to see them fail**

Expected: `455 passed, 8 failed`: "returns every match when no limit is
given" (8, not 10), "keeps every result row inside the list's box" (no
footer to read), and the six new planner tests (no footer, no wheel).

- [ ] **Step 4: `GoblinPS/Search.lua`, every match**

In `Search.Find`, change the comment's last line
`-- it; alphabetical inside each group.` to
`-- it; alphabetical inside each group. Every match, unless a limit is given.`
and the loop head `for i = 1, math.min(limit or 8, #ranked) do` to
`for i = 1, math.min(limit or #ranked, #ranked) do`.

- [ ] **Step 5: `GoblinPS/Planner.lua`**

After `local ROW_INSET = 2 * ROW_EDGE`, add:

```lua
-- The footer's own slot at the bottom of the list, "6-10 of 23": one line of
-- the rows' small font (GameFontHighlightSmall, 10 px on this build's
-- Fonts.xml) with room for its descenders. The rows that fit are counted
-- with this slot kept free, so the footer never sits on a row.
local FOOTER = 14
```

Replace `candidates` and its comment:

```lua
-- Matches for the text; with an empty box, the recent destinations. Asks for
-- only as many as the list's own box can show (ui.results.fit), not the
-- pool size, so Enter still picks the first of what is actually on screen.
local function candidates()
    local text = ui.toBox:GetText()
    local fit = ui.results.fit or Planner.MAX_RESULTS
    if text ~= "" then
        return ns.Search.Find(ns.Data, text, ns.Core.Faction(), fit)
    end
```

with

```lua
-- Every match for the text, however many: the list shows `fit` of them at a
-- time and the wheel moves over the rest. With an empty box, the recent
-- destinations.
local function candidates()
    local text = ui.toBox:GetText()
    if text ~= "" then
        return ns.Search.Find(ns.Data, text, ns.Core.Faction())
    end
```

(the recents loop and `return out` below it are unchanged).

Directly before `local function showResults()`, add:

```lua
-- Paint the `fit` rows from the list's window onto its items, and the footer
-- when there is more than fits. The window is results.offset, 0 at the top.
local function drawResults()
    local r = ui.results
    local fit = r.fit or Planner.MAX_RESULTS
    local shown = 0
    for i = 1, Planner.MAX_RESULTS do
        local row, item = r.rows[i], (i <= fit) and r.items[r.offset + i] or nil
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            row.label:SetText(rowLabel(item))
            shown = shown + 1
        end
    end
    local more = #r.items > fit
    r.footer:SetText(more and ((r.offset + 1) .. "-" .. (r.offset + shown) .. " of " .. #r.items) or "")
    r.footer:SetShown(more)
end

-- One notch of the wheel moves the window one row, clamped at both ends.
-- delta is the client's: 1 for a notch up, -1 for a notch down.
local function scrollResults(delta)
    local r = ui.results
    local last = math.max(0, #r.items - (r.fit or Planner.MAX_RESULTS))
    r.offset = math.max(0, math.min(last, r.offset - delta))
    drawResults()
end

```

In `showResults`, replace everything after the settings-panel guard (from
`local items = candidates()` to the function's end):

```lua
    local items = candidates()
    if #items == 0 then
        hideResults()
        return
    end
    local fit = ui.results.fit or Planner.MAX_RESULTS
    for i = 1, Planner.MAX_RESULTS do
        local row, item = ui.results.rows[i], (i <= fit) and items[i] or nil
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            row.label:SetText(rowLabel(item))
        end
    end
    ui.results:Show()
end
```

with

```lua
    -- A fresh list always starts at its top: typing resets the window.
    ui.results.items, ui.results.offset = candidates(), 0
    if #ui.results.items == 0 then
        hideResults()
        return
    end
    drawResults()
    ui.results:Show()
end
```

In `wireBox`, the `OnEnterPressed` script's first line
`local first = candidates()[1]` becomes:

```lua
        -- The top row on screen, wherever the wheel has moved the list to.
        local r = ui.results
        local first = r:IsShown() and r.items[r.offset + 1] or candidates()[1]
```

In `ApplyLayout`, replace

```lua
    ui.results.fit = math.max(1, math.min(Planner.MAX_RESULTS, math.floor(
        ((g.resultsList.bottom - g.resultsList.top) * f:GetHeight() - ROW_INSET) / ROW)))
```

with

```lua
    -- The footer's slot is kept free: 109.7 px of list at 416 px tall, less
    -- the insets and the footer, still holds 5 rows.
    ui.results.fit = math.max(1, math.min(Planner.MAX_RESULTS, math.floor(
        ((g.resultsList.bottom - g.resultsList.top) * f:GetHeight() - ROW_INSET - FOOTER) / ROW)))
```

In `build()`, directly after
`results.fit = Planner.MAX_RESULTS -- ApplyLayout narrows this once geometry is known`,
add:

```lua
    results.items, results.offset = {}, 0
    -- The wheel scrolls the list. EnableMouseWheel is present on build
    -- 1.60.1.69913 (SimpleScriptRegionAPIDocumentation.lua) and Blizzard's
    -- own UI sets OnMouseWheel scripts with SetScript; without the enable the
    -- client never delivers the wheel to this frame.
    results:EnableMouseWheel(true)
    results:SetScript("OnMouseWheel", function(_, delta) scrollResults(delta) end)
    -- "6-10 of 23", in its own slot under the rows: bounded by two anchors,
    -- one line, truncated. Hidden when everything fits.
    results.footer = W.Text(results, "dim", nil, "RIGHT")
    results.footer:SetHeight(FOOTER)
    results.footer:SetPoint("BOTTOMLEFT", ROW_EDGE + LABEL_EDGE, ROW_EDGE)
    results.footer:SetPoint("BOTTOMRIGHT", -(ROW_EDGE + LABEL_EDGE), ROW_EDGE)
    results.footer:Hide()
```

(`W.Text` already calls `SetWordWrap(false)`.)

- [ ] **Step 6: Run every gate**

Lua: `463 passed, 0 failed` (456 + 7). Python `Ran 70 tests`, `OK`. Art
green. luacheck and the language server from PowerShell: zero warnings.

- [ ] **Step 7: Commit**

```
git add GoblinPS/Search.lua GoblinPS/Planner.lua test/fake_frames.lua test/test_search.lua test/test_ui.lua
git commit -m "Planner: the results list scrolls on the wheel, with a footer" -m "The search returns every match and the list keeps them all, drawing its five rows from a window one wheel notch moves, clamped at both ends. A footer in its own 14 px slot under the rows reads 1-5 of 6 when there is more than fits, and hides otherwise. Typing starts the window again at the top; Enter picks the top row on screen. The fake models EnableMouseWheel and refuses a wheel a frame did not ask for." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---


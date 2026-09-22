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


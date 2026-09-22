### Task 5: the zone browser

**Files:**
- Modify: `GoblinPS/Search.lua` (`Search.Zones`)
- Modify: `GoblinPS/Planner.lua` (`candidates`, `rowLabel`, `browse`, `pick`
  moved, the measured width)
- Modify: `test/test_search.lua`, `test/test_ui.lua`

**Interfaces:**
- Consumes: Task 3's `Search.Candidates`; Task 4's `showResults`,
  `ui.results.items`, `ui.results.offset`, `ui.results.footer`, `Fake.Wheel`,
  and the `open`, `labels`, `WESTLAND` helpers in Task 4's test block;
  `EditBox:SetFocus()` (the fake fires `OnEditFocusGained` and sets `focused`).
- Produces: `Search.Zones(data, faction)` -> list sorted by name of
  `{ kind = "browse", name = <zone name>, map = <UiMap>, count = <places> }`.
  With the box empty, `ui.results.items` is the resolved recents followed by
  `Search.Zones`. A `"browse"` row's label is `"<zone> (<count>)"`.

In the fake world the Horde is offered, per zone: Eastland 1 (Delta), Isle 2
(Foxtrot, Golf), Lostland 1 (its own "(zone)" row), Northland 2 (Hotel,
Gatehouse), Westland 6.

- [ ] **Step 1: Write the failing tests**

In `test/test_search.lua`, inside `h.describe("two stops of one name", ...)`
after "pins the tie", add:

```lua
        h.it("is counted once in the zone browser", function()
            for _, zone in ipairs(Search.Zones(withTwins(), "H")) do
                if zone.name == "Westland" then
                    h.eq(zone.count, 7, "six places and one Kilo, not two")
                end
            end
        end)
```

and directly after the `end)` that closes that describe (before
`h.describe("Search.Candidates", ...)`), add:

```lua
    h.describe("Search.Zones", function()
        h.it("lists every zone A to Z with how many places it holds", function()
            local out = {}
            for i, zone in ipairs(Search.Zones(world, "H")) do
                h.eq(zone.kind, "browse", zone.name .. " is a way in, not a destination")
                out[i] = zone.name .. " " .. zone.count
            end
            h.eq(table.concat(out, ", "), "Eastland 1, Isle 2, Lostland 1, Northland 2, Westland 6",
                 "Lostland holds only its own (zone) row")
        end)
    end)

```

In `test/test_ui.lua`, at the end of
`h.describe("the results list scrolls, and browses zones", ...)` (after
"Enter picks the top row on screen, wherever the wheel left it"), add:

```lua

        h.it("with the box empty, lists the recent destinations, then every zone with its count", function()
            local ui = open()
            local saved = GoblinPSDB.recents
            GoblinPSDB.recents = { "Delta", "Juliet" }
            Fake.Type(ui.toBox, "")
            h.eq(labels(ui), "Delta · Eastland | Juliet · Westland | Eastland (1) | Isle (2) | Lostland (1)")
            h.eq(ui.results.footer:GetText(), "1-5 of 7")
            Fake.Wheel(ui.results, -1)
            Fake.Wheel(ui.results, -1)
            h.eq(ui.results.rows[4].label:GetText(), "Northland (2)")
            h.eq(ui.results.rows[5].label:GetText(), "Westland (6)")
            GoblinPSDB.recents = saved
            ui.toBox:SetText("Delta")
            ui.toBox:ClearFocus()
        end)

        h.it("the dropdown opens the same browser", function()
            local ui = open()
            ui.toBox:SetText("")
            Fake.MouseDown(GoblinPSPlanner) -- the list starts put away
            Fake.Click(ui.dropdown)
            h.truthy(ui.results:IsShown())
            local items = ui.results.items
            h.eq(items[1].name, GoblinPSDB.recents[1], "the newest recent first")
            h.truthy(items[1].kind ~= "browse", "a recent is a place")
            h.eq(items[#items].kind, "browse")
            h.eq(items[#items].name, "Westland", "and the last zone, A to Z, at the end")
            ui.toBox:SetText("Delta")
            ui.toBox:ClearFocus()
        end)

        h.it("a zone row fills the box and lists that zone's places, and is never routed to", function()
            local ui, state = open()
            local saved, to, plan = GoblinPSDB.recents, state.to, state.plan
            GoblinPSDB.recents = {} -- the five zones fill the list exactly
            ui.toBox:SetText("")
            ui.toBox.scripts.OnEditFocusGained(ui.toBox)
            h.eq(ui.results.rows[5].label:GetText(), "Westland (6)")
            Fake.Click(ui.results.rows[5])
            h.eq(ui.toBox:GetText(), "Westland", "exactly as typing it would")
            h.truthy(ui.toBox.focused, "the box keeps the search going")
            h.truthy(ui.results:IsShown())
            h.eq(labels(ui), table.concat(WESTLAND, " | ", 1, 5), "the zone's places")
            h.truthy(state.to == to and state.plan == plan, "nothing was planned")
            h.eq(#GoblinPSDB.recents, 0, "and nothing remembered")
            GoblinPSDB.recents = saved
            ui.toBox:SetText("Delta")
            ui.toBox:ClearFocus()
        end)

        h.it("Enter on a zone row at the top browses too, and never routes", function()
            local ui, state = open()
            local saved, to = GoblinPSDB.recents, state.to
            GoblinPSDB.recents = {}
            Fake.Type(ui.toBox, "")
            h.eq(ui.results.rows[1].label:GetText(), "Eastland (1)")
            ui.toBox.scripts.OnEnterPressed(ui.toBox)
            h.eq(ui.toBox:GetText(), "Eastland")
            h.eq(labels(ui), "Delta · Eastland")
            h.truthy(state.to == to, "nothing was planned")
            GoblinPSDB.recents = saved
            ui.toBox:SetText("Delta")
            ui.toBox:ClearFocus()
        end)
```

- [ ] **Step 2: Run the Lua gate to see them fail**

Expected: `463 passed, 6 failed`: the two Search tests (`Search.Zones` is
nil) and the four planner tests (an empty box lists the recents only).

- [ ] **Step 3: `GoblinPS/Search.lua`, `Search.Zones`**

Directly before the comment `-- Which of two same-named places comes first`,
add:

```lua
-- The zone browser: every zone that holds something to pick, A to Z, each
-- with how many it holds (a zone that holds no place holds its own "(zone)"
-- row, so it counts one). A row here is a way in, never a destination: its
-- kind is "browse", and picking one searches for the zone's name, which
-- lists the zone's places (Find's zone rank).
function Search.Zones(data, faction)
    local count = {}
    for _, item in ipairs(Search.Candidates(data, faction)) do
        count[item.map] = (count[item.map] or 0) + 1
    end
    local out = {}
    for map, n in pairs(count) do
        local p = data.Places[map]
        if p then
            out[#out + 1] = { kind = "browse", name = p.name, map = map, count = n }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

```

- [ ] **Step 4: `GoblinPS/Planner.lua`**

In `candidates`, change the comment's last line `-- destinations.` to
`-- destinations, then the zone browser's rows.`, and directly before its
final `return out` add:

```lua
    for _, zone in ipairs(ns.Search.Zones(ns.Data, ns.Core.Faction())) do
        out[#out + 1] = zone
    end
```

In `rowLabel`'s comment, replace

```lua
-- place. The drop-down's width is measured over this too.
local function rowLabel(item)
```

with

```lua
-- place, "Ashenvale (6)" for the zone browser's way into a zone. The
-- drop-down's width is measured over this too.
local function rowLabel(item)
    if item.kind == "browse" then
        return item.name .. " (" .. item.count .. ")"
    end
```

**Move `pick`.** Delete the whole `local function pick(item) ... end` from
its place after `dismiss` (it must now call `browse`, which is defined below
`showResults`; a Lua local is only visible after its definition). Then,
directly after `showResults`'s closing `end` (before `local function
wireBox(box)`), add:

```lua

-- A zone browser row is a way in, never a destination: it puts the zone's
-- name in the box, exactly as typing it would, and the list shows the
-- zone's places. Nothing is planned and nothing is remembered.
local function browse(item)
    ui.toBox:SetText(item.name)
    W.UpdatePlaceholder(ui.toBox)
    ui.toBox:SetFocus()
    showResults()
end

local function pick(item)
    if item.kind == "browse" then
        browse(item)
        return
    end
    hideResults()
    state.to = item
    ns.Core.Remember(item.name)
    ui.toBox:SetText(item.name)
    ui.toBox:ClearFocus()
    W.UpdatePlaceholder(ui.toBox)
    replan()
end
```

(`SetFocus` fires `OnEditFocusGained`, which lists too; the explicit
`showResults()` covers Enter, where the box already has focus and the client
fires nothing.)

In `build()`, the drop-down measurement also measures the browser's rows.
Replace

```lua
    for _, item in ipairs(ns.Search.Candidates(ns.Data, ns.Core.Faction())) do
        ruler:SetText(rowLabel(item))
        widest = math.max(widest, ruler:GetUnboundedStringWidth())
    end
```

with

```lua
    for _, list in ipairs({ ns.Search.Candidates(ns.Data, ns.Core.Faction()),
                            ns.Search.Zones(ns.Data, ns.Core.Faction()) }) do
        for _, item in ipairs(list) do
            ruler:SetText(rowLabel(item))
            widest = math.max(widest, ruler:GetUnboundedStringWidth())
        end
    end
```

(The widest label in the fake world is still "Echo · Westland (Alliance)",
135 px, so "draws the drop-down only a little wider than its longest name"
is unchanged.)

- [ ] **Step 5: Run every gate**

Lua: `469 passed, 0 failed` (463 + 6). Python `Ran 70 tests`, `OK`. Art
green. luacheck and the language server from PowerShell: zero warnings.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Search.lua GoblinPS/Planner.lua test/test_search.lua test/test_ui.lua
git commit -m "Planner: the empty box browses recents, then every zone" -m "With the box empty, the drop-down and the focused box list the recent destinations, then every zone A to Z with how many places it holds (Search.Zones). A zone row is a way in, never a destination: clicking it, or Enter with it on top, puts the zone's name in the box and lists its places; nothing is planned or remembered. The browser's labels are measured for the drop-down's width too." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---


### Task 3: one search box, wide only, no step list

The window moves to the new geometry and loses everything the mockup does
not have. The route strip itself is Task 4; between the two commits a route
shows as its total, warning line and Start Route only. The "ground steps in
the window" row tests are deleted here and come back as tooltip tests in
Task 4.

**Files:**
- Regenerate: `GoblinPS/Data/Art.lua`, `GoblinPS/Media/*.tga`
- Delete: `GoblinPS/Media/planner-frame-tall.tga`
- Rewrite: `GoblinPS/Planner.lua`
- Modify: `GoblinPS/Prefs.lua:28-35, 54-57`, `GoblinPS/Core.lua:47-48, 204`
- Modify: `test/test_ui.lua` (the "the planner window" and "ground steps in
  the window" blocks), `test/test_prefs.lua`

**Interfaces:**
- Consumes: the wide geometry keys from Task 2.
- Produces, for Task 4: `Planner.SIZE = { 650, 416 }`,
  `Planner.ApplyLayout()` (no argument), and `ui` fields `frame, artLayer,
  content, flat, frameArt, titlePlate, taglinePlate, title, tagline, close,
  gear, dropdown, backdrop, panelArt, toBox, toSlice, screen, total, hint,
  notes, known, go, results`. `local function geo()` answers the wide table.
  Gone: `fromBox`, `here`, `layoutButton`, `side`, `rows`, `Planner.MAX_ROWS`,
  `Core.Layout`, `Core.ToggleLayout`, `Prefs.ToggleLayout`, `db.layout`.

- [ ] **Step 1: Regenerate the art**

```
python tools/make_art.py
git rm GoblinPS/Media/planner-frame-tall.tga
```

Expected: 43 textures written (29 today, less the tall frame, plus fifteen), `Data/Art.lua` with fifteen new rows and
`ns.Data.ArtGeometry.planner` holding `wide` and `strip` only. Run the Lua
suite: it now fails in the planner tests (the old keys are gone). That is the
red this task turns green.

- [ ] **Step 2: Drop the layout preference**

`GoblinPS/Prefs.lua`: delete the `LAYOUTS` line and `Prefs.ToggleLayout`. In
`Prefs.Init`, replace the three-line `if not LAYOUTS[db.layout] ...` block
with:

```lua
    -- The wide/tall switch is gone (plan 8). A save from before it still
    -- carries the choice; drop it rather than keep a key nothing reads.
    db.layout = nil
```

`GoblinPS/Core.lua`: delete `function Core.Layout()` and
`function Core.ToggleLayout()`. In `Core.Go`, change
`"Use your hearthstone, then press GO again."` to
`"Use your hearthstone, then press Start Route again."`.

`test/test_prefs.lua`: in "fills an empty table with the defaults" change
`h.eq(db.layout, "wide")` to `h.eq(db.layout, nil, "there is no layout choice any more")`.
Replace "keeps what the player already chose" and "repairs a layout it does
not know" with:

```lua
        h.it("keeps what the player already chose", function()
            local db = Prefs.Init({ minimap = { angle = 10 } })
            h.eq(db.minimap.angle, 10)
            h.eq(db.minimap.hide, false)
        end)
        h.it("drops a layout choice saved before the switch was removed", function()
            h.eq(Prefs.Init({ layout = "tall" }).layout, nil)
        end)
```

Delete the whole `h.describe("Prefs.ToggleLayout", ...)` block.

- [ ] **Step 3: Rewrite `GoblinPS/Planner.lua`**

Replace the file with the following. Everything not shown as changed is
carried over from today's file word for word, comments included: `art()`,
`coverCrop()` and its comment, `ON_THE_CHASSIS`, `boundingBox()` (its comment
loses the words "in this layout's"), the frame, flat, artLayer, content,
frameArt, plates, panelArt, title/tagline, close, dropdown, gear, backdrop and
results blocks in `build()`.

```lua
local _, ns = ...

-- The planner: one search box, the green screen with the route strip in it,
-- the total and the warning under the strip, and Start Route. The route
-- always starts where you stand. One wide shape; every position comes from
-- the geometry the art tool generates.
local Planner = {}
ns.Planner = Planner

local W = ns.Widgets

-- The window's rectangle on screen. The frame art is 1600x1024, so this keeps
-- its 25:16 exactly; everything inside is placed as a fraction of it, from
-- the geometry the art tool generates. Nothing here is a measured guess.
Planner.SIZE = { 650, 416 }
Planner.MAX_RESULTS = 8
local ROW = 18

local ui          -- built on first open
local state = {}  -- to = place, plan = Core.PlanRoute's answer

local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"

-- The layout's geometry, or nil when the generated table is absent. Gated on
-- the geometry alone: whether the parts shipped is a different question.
local function geo()
    local g = ns.Data.ArtGeometry and ns.Data.ArtGeometry.planner
    return g and g.wide
end

-- [art() unchanged]

-- Paint whatever state.plan holds. With a route, the idle status lines give
-- way to it; without one, they say why there is none.
function Planner.Refresh()
    if not ui then
        return
    end
    local plan = state.plan
    local steps = plan and plan.result and plan.result.steps or {}
    local routed = #steps > 0
    local notes = plan and table.concat(plan.notes, "  ") or ""
    local total, hint = "", ""
    if routed then
        total = ns.Route.FormatTime(plan.result.seconds) .. " · " .. ns.Route.FormatMoney(plan.result.copper)
        -- One amber line under the strip. What the player must know first
        -- wins: a note about the route itself, then a flight path worth
        -- discovering. (Task 4 puts the level warning ahead of both.)
        if notes ~= "" then
            hint = notes
        elseif plan.hint then
            hint = ns.Route.HintText(plan.hint)
        end
    end
    ui.total:SetText(total)
    ui.hint:SetText(hint)
    ui.notes:SetText(notes)
    ui.notes:SetShown(not routed)
    ui.known:SetShown(not routed)
    W.SetButtonEnabled(ui.go, routed)

    local known = ns.Core.KnownCount()
    ui.known:SetText(known == 0 and "No flight paths yet: open a flight map."
        or ("Flight paths known: " .. known))
end

local function replan()
    state.plan = state.to and ns.Core.PlanRoute(state.to) or nil
    Planner.Refresh()
end

-- ---- the results list under the search box ----

local function hideResults()
    ui.results:Hide()
end

-- Puts the results list away and drops focus from the box: used wherever
-- clicking something other than a result row should end the search.
local function dismiss()
    ui.toBox:ClearFocus()
    hideResults()
end

local function pick(item)
    hideResults()
    state.to = item
    ns.Core.Remember(item.name)
    ui.toBox:SetText(item.name)
    ui.toBox:ClearFocus()
    W.UpdatePlaceholder(ui.toBox)
    replan()
end

-- Matches for the text; with an empty box, the recent destinations.
local function candidates()
    local text = ui.toBox:GetText()
    if text ~= "" then
        return ns.Search.Find(ns.Data, text, ns.Core.Faction(), Planner.MAX_RESULTS)
    end
    local out = {}
    for _, name in ipairs(ns.Core.Recents()) do
        out[#out + 1] = ns.Search.Exact(ns.Data, name, ns.Core.Faction())
    end
    return out
end

local function showResults()
    local items = candidates()
    if #items == 0 then
        hideResults()
        return
    end
    for i = 1, Planner.MAX_RESULTS do
        local row, item = ui.results.rows[i], items[i]
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            row.label:SetText(item.name .. (item.kind == "zone" and "" or "  (flight stop)"))
        end
    end
    ui.results:Show()
end

local function wireBox(box)
    box:SetScript("OnTextChanged", function(self, userInput)
        W.UpdatePlaceholder(self)
        if userInput then
            showResults()
        end
    end)
    box:SetScript("OnEditFocusGained", showResults)
    box:SetScript("OnEditFocusLost", function()
        -- The client drops edit focus on mouse-down, before a click on a row
        -- completes. With the cursor on the list, leave it for that click.
        if not ui.results:IsMouseOver() then
            hideResults()
        end
    end)
    box:SetScript("OnEnterPressed", function(self)
        local first = candidates()[1]
        if first then
            pick(first)
        else
            self:ClearFocus()
        end
    end)
    box:SetScript("OnEscapePressed", function(self)
        hideResults()
        self:ClearFocus()
    end)
end

-- [coverCrop(), ON_THE_CHASSIS and boundingBox() unchanged]

-- ---- placement ----

function Planner.ApplyLayout()
    if not ui then
        return
    end
    local f = ui.frame
    -- The explicit size first, before anything reads it: every helper below
    -- measures this frame, and a frame with no size measures 0.
    f:SetSize(Planner.SIZE[1], Planner.SIZE[2])

    local part = ns.Data.Art and ns.Data.Art["planner-frame-wide"]
    if part and ui.frameArt:SetTexture(MEDIA .. part.file) then
        ui.frameArt:SetTexCoord(part.l, part.r, part.t, part.b)
        ui.frameArt:Show()
        ui.flat:Hide()
    else
        ui.frameArt:Hide()
        ui.flat:Show()
    end

    local g = geo()
    if not g then
        return
    end
    if ui.titlePlate then
        W.PlaceRect(ui.titlePlate, f, g.titlePlate)
    end
    if ui.taglinePlate then
        W.PlaceRect(ui.taglinePlate, f, g.taglinePlate)
    end
    W.PlaceLine(ui.title, f, g.titlePlate)
    W.PlaceLine(ui.tagline, f, g.taglinePlate)
    W.PlaceCircle(ui.close, f, g.closeButton)
    W.PlaceCircle(ui.gear, f, g.gearButton)
    W.PlaceCircle(ui.dropdown, f, g.dropdownButton)
    W.PlaceRect(ui.toBox, f, g.toBox)
    W.PlaceRect(ui.results, f, g.resultsList)
    W.PlaceRect(ui.screen, f, g.screen)
    W.PlaceRect(ui.go, f, g.goButton)
    W.PlaceLine(ui.total, f, g.totalLine)
    W.PlaceLine(ui.hint, f, g.hintLine)
    W.PlaceLine(ui.notes, f, g.notesLine)
    W.PlaceLine(ui.known, f, g.knownLine)
    if ui.panelArt then
        -- The frame's opening, measured from its own alpha by make_art.py.
        -- Seen in the client 2026-09-21: sized to the controls instead,
        -- the backing stopped short of the brass and the world showed
        -- through on the left, the right and the bottom.
        W.PlaceRect(ui.panelArt, f, g.interior or boundingBox(g))
    end
    -- Both three-sliced controls have just been re-anchored corner to corner,
    -- so their end caps were measured against the height they had before.
    -- The new height CANNOT be read off the control: it only inherits its
    -- size now. Work it out from the same two things PlaceRect used -- the
    -- control's own rect and this frame, given an explicit size above.
    for _, pair in ipairs({ { ui.go, g.goButton }, { ui.toBox, g.toBox } }) do
        W.Restretch3(pair[1], (pair[2].bottom - pair[2].top) * f:GetHeight())
    end
    if ui.backdrop then
        -- Placed by its parent, not by the geometry, but the crop still
        -- needs the screen opening's pixel size.
        local backdropPart = ns.Data.Art and ns.Data.Art["screen-backdrop"]
        if backdropPart then
            coverCrop(ui.backdrop, backdropPart,
                      (g.screen.right - g.screen.left) * f:GetWidth(),
                      (g.screen.bottom - g.screen.top) * f:GetHeight())
        end
    end
end
```

`build()` changes, against today's file:

- `f:SetSize(Planner.SIZE.wide[1], Planner.SIZE.wide[2])` becomes
  `f:SetSize(Planner.SIZE[1], Planner.SIZE[2])`.
- The frameArt comment: "ApplyLayout swaps the texture between the two
  frames, so create it empty here" becomes "ApplyLayout gives it the frame
  art, so create it empty here".
- The close button's `OnClick` stays `dismiss(); f:Hide()`.
- The dropdown's `OnClick` becomes:

```lua
    dropdown:SetScript("OnClick", function()
        if ui.results:IsShown() then
            hideResults()
        else
            showResults()
        end
    end)
```

- The three-slice comment above `BUTTON_CAP` becomes: "Start Route draws the
  "button" part at a width the geometry, not this code, decides. A single
  stretched texture would squash its end caps, so it gets three-slice art on
  top of its flat fallback."
- Delete `layoutButton`, `fromBox`, `here`, `fromSlice`, the `device`
  watermark (the mockup has none, and the strip now sits where it drew), the
  `side` panel and its `rows`.
- The search box: `local toBox = W.EditBox(content, 170, 20, "To: city, zone or flight stop")`
  and `local toSlice = W.Stretch3(toBox, "input-box", CAP, CAP_ASPECT)`,
  keeping the `CAP` comment.
- The status and footer lines all live on the screen, above its scenery: a
  FontString on `content` would draw under the screen, which is its child.
  Replace the `notes`, `known`, `device`, `side`, `rows`, `hint`, `go` and
  `total` blocks with:

```lua
    -- Four lines, all on the screen so they draw over its scenery (a string on
    -- `content` would sit under the screen, which is content's child). notes
    -- and known are the idle status lines and give way to the route; total
    -- and hint sit under the strip and stay.
    local notes = W.Text(screen, "dim")
    local known = W.Text(screen, "green")
    local total = W.Text(screen, "green", "GameFontNormal", "CENTER")
    local hint = W.Text(screen, "amber", nil, "CENTER")

    local go = W.Button(content, "Start Route", 120, 24, function()
        dismiss()
        replan()
        ns.Core.Go(state.plan)
        -- The Garmin model: plan the route, then drive. /gps reopens the
        -- planner without ending the trip.
        local plan = state.plan
        if ui.frame:IsShown() and plan and plan.result and #plan.result.steps > 0 then
            ui.frame:Hide()
        end
    end)
    W.Stretch3(go, "button", BUTTON_CAP, BUTTON_CAP_ASPECT)
    W.WireButtonArt(go)
```

- Result rows: `row:SetScript("OnClick", function(self) pick(self.item) end)`.
- The `ui` table:

```lua
    ui = { frame = f, artLayer = artLayer, content = content, flat = flat, frameArt = frameArt,
           titlePlate = titlePlate, taglinePlate = taglinePlate, title = title, tagline = tagline,
           close = close, gear = gear, dropdown = dropdown, backdrop = backdrop, panelArt = panelArt,
           toBox = toBox, toSlice = toSlice, screen = screen, total = total, hint = hint,
           notes = notes, known = known, go = go, results = results }
    wireBox(toBox)
```

- `Planner.Toggle`: `Planner.ApplyLayout(ns.Core.Layout())` becomes
  `Planner.ApplyLayout()`. The plan 7 seeding from `ns.Dash.Destination()`
  stays exactly as it is.

- [ ] **Step 4: Update the planner tests in `test/test_ui.lua`**

Inside `h.describe("the planner window", ...)`, test by test:

- "opens from the slash command with both layouts' widgets built once":
  rename "opens from the slash command"; `Planner.SIZE.wide[1]` becomes
  `Planner.SIZE[1]`.
- "offers matches as you type and plans when you pick one": replace the six
  `ui.rows` lines and the total line with:

```lua
            local steps = state.plan.result.steps
            h.eq(#steps, 5)
            h.eq(ns.Route.StepText(steps[1]), "Ride to Alpha")
            h.eq(ns.Route.StepText(steps[2]), "Fly to Bravo")
            h.eq(ns.Route.StepText(steps[4]), "Zeppelin to East Dock")
            h.eq(ns.Route.StepText(steps[5]), "Ride to Delta")
            h.eq(ui.total:GetText(), "~10 min · 1s")
```

- Delete: "clicking Here dismisses the open results list", "plans from
  another place", "switches layout with one set of widgets and saves the
  choice", "Here plans from where you stand again", "shows an overflow row
  for a route longer than MAX_ROWS, with the last step always visible".
- "GO drops a pin on the first step": rename "Start Route drops a pin on the
  first step"; the expected chat line becomes `"Pin set: Ride to Alpha"`
  (with "plans from another place" gone, the route starts beside Alpha).
- "shows the plan's notes on the screen when the route has steps" becomes:

```lua
        h.it("puts the plan's notes on the warning line when the route has steps", function()
            local ui = Planner.Debug()
            local originalHearthBindName = ns.API.HearthBindName
            ns.API.HearthBindName = function() return "Nowhere Inn Bind" end
            Planner.Replan()
            h.truthy(ui.hint:GetText():find("Hearth: unknown inn", 1, true))
            h.falsy(ui.notes:IsShown(), "the idle status lines give way to the route")
            h.falsy(ui.known:IsShown())
            ns.API.HearthBindName = originalHearthBindName
            Planner.Replan()
            h.falsy(ui.hint:GetText():find("Hearth", 1, true))
        end)
```

- "explains itself when it cannot tell where you are": both
  `Fake.Click(ui.here)` become `Planner.Replan()`; delete the `ui.rows` line;
  add `h.truthy(ui.notes:IsShown(), "a status line says why there is no route")`
  after the notes assertion.
- "GO re-plans from where you are now instead of using a stale plan": rename
  "Start Route re-plans ..."; its first line becomes
  `local ui, state = Planner.Debug()` followed by
  `h.eq(ns.Route.StepText(state.plan.result.steps[1]), "Ride to Alpha")`;
  replace `h.eq(ui.rows[1].left:GetText(), "1. Ride to West Dock")` with
  `h.eq(ns.Route.StepText(state.plan.result.steps[1]), "Ride to West Dock")`.
- "shows the zero-step case when you are already at the destination": delete
  the `ui.rows` line; add `h.truthy(ui.notes:IsShown())`.
- "keeps the window at the art's exact aspect ratio": one layout:

```lua
            local canvas = ns.Data.ArtGeometry.planner.wide.canvas
            h.truthy(math.abs(Planner.SIZE[1] / Planner.SIZE[2] - canvas.w / canvas.h) < 0.001,
                     "the window must keep the art's aspect ratio")
```

  and its comment keeps only the wide half ("1600x1024 is 25:16 ...").
- Every `ns.Planner.ApplyLayout("wide")` becomes `ns.Planner.ApplyLayout()`.
- Every `for _, mode in ipairs({ "wide", "tall" }) do ... end` loop is
  unrolled to its wide body: `mode` becomes the literal `"wide"` in messages,
  `ns.Data.ArtGeometry.planner[mode]` becomes `.planner.wide`, and the
  trailing `ns.Planner.ApplyLayout("wide")` restore lines go.
- "tiles the panel backing behind every opening, not just the screen" and
  "keeps the tiled backing off the chassis's own ornament": the rect lists
  `{ g.screen, g.sidePanel }` become `{ g.screen, g.toBox, g.goButton }`.
- "labels a button on its shipped art in green, and dims it when disabled":
  delete the `layoutButton` and `here` assertions and the words "Tall, Here
  and" from its comment.
- "sizes every three-sliced control's caps from its own rect, in both
  layouts": rename "... from its own rect"; checks become
  `{ { ui.go, g.goButton, "go" }, { ui.toBox, g.toBox, "toBox" } }`.
- "places every input, panel and footer line from the geometry": checks
  become `{ ui.toBox, g.toBox, "toBox" }, { ui.screen, g.screen, "screen" },
  { ui.go, g.goButton, "goButton" }`, and the line loop covers
  `{ ui.total, ui.hint, ui.notes, ui.known }`.
- "drops the results list over the search area, not under one box": rename
  "drops the results list over the screen"; its closing
  `Fake.Click(ui.here)` becomes `Fake.MouseDown(GoblinPSPlanner)`.

Add, at the end of the block:

```lua
        h.it("is the mockup: no From, no Here, no layout switch, no step list", function()
            local ui = Planner.Debug()
            h.eq(ui.fromBox, nil)
            h.eq(ui.here, nil)
            h.eq(ui.layoutButton, nil)
            h.eq(ui.side, nil)
            h.eq(ui.rows, nil)
            h.eq(Planner.MAX_ROWS, nil)
            h.eq(ns.Core.Layout, nil)
            h.eq(ns.Data.ArtGeometry.planner.tall, nil, "the tall geometry no longer ships")
            h.eq(ns.Data.Art["planner-frame-tall"], nil, "nor the tall frame")
            h.eq(ui.go.label:GetText(), "Start Route")
        end)

        h.it("shows the idle status lines before a destination is picked", function()
            -- Start Route, a few tests up, left a trip running, and a fresh
            -- window seeds its box from a running trip (plan 7). Hide the trip
            -- from it rather than end it: later tests expect it.
            local savedPlanner, savedDestination = ns.Planner, ns.Dash.Destination
            ns.Dash.Destination = function() return nil end
            local FreshPlanner = assert(loadfile("GoblinPS/Planner.lua"))("GoblinPS", ns)
            ns.Planner = savedPlanner
            FreshPlanner.Toggle()
            ns.Dash.Destination = savedDestination
            local ui, state = FreshPlanner.Debug()
            h.eq(state.to, nil, "a fresh window with no trip to show has no destination")
            h.truthy(ui.notes:IsShown())
            h.truthy(ui.known:IsShown())
            h.eq(ui.known:GetText(), "Flight paths known: 3")
            h.eq(ui.total:GetText(), "")
            h.falsy(ui.go.enabled)
            FreshPlanner.Toggle()
        end)
```

In `h.describe("ground steps in the window", ...)`: delete the four row tests
("shows each ground step's zone and levels on a second line", "turns the
detail amber for a hazard and leaves it dim otherwise", "says Walk and warns
about the zone for a low-level character", "labels a straight line when the
crossings table has a hole") and the `pickTo`, `amber` and `dim` locals.
Rename the block "ground steps in chat"; it keeps "prints the detail under
each step in chat too". Task 4 brings the four back as strip tests.

- [ ] **Step 5: Run every gate**

Lua suite green (the count drops: expected about 323 - 14 + 3 = 312; report
the real number). Python suite green, `check_art.py` clean, luacheck and the
language server at zero from PowerShell. Grep for leftovers:
`grep -rn "fromBox\|layoutButton\|ToggleLayout\|Core.Layout\|MAX_ROWS\|sidePanel\|SIZE.wide\|SIZE.tall" GoblinPS test`
must print nothing.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Planner.lua GoblinPS/Prefs.lua GoblinPS/Core.lua GoblinPS/Data/Art.lua GoblinPS/Media test/test_ui.lua test/test_prefs.lua
git commit -m "Planner: one search box, wide only, no step list" -m "The window moves to Codex's mockup geometry: From, Here, the Wide/Tall switch and its saved choice, the side panel and its step rows are gone, the idle status lines give way to a route, and GO is Start Route. The route strip that replaces the step list is the next commit." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---


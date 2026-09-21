# The Planner as Designed (plan 8) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the planner window to the Codex mockup: one search box, a
screen holding the route strip (one badge per stop, joined by a glowing line,
with each stop's detail in a tooltip), the total and warning under it, and a
Start Route button. Wide only; no From, no Here, no step list.

**Architecture:** A new pure module, `Strip.lua`, turns a planned route into
layout data (which badge each stop wears, where it sits, its tooltip lines,
solid or dashed legs). `Planner.lua` draws that data and decides nothing. The
art tool ships the fifteen strip parts, stops shipping anything tall, and
emits wide geometry only; `check_art.py` classifies the new wide keys.

**Tech Stack:** Lua 5.1 against the WoW Forever client API (build
1.60.1.69913, interface 16001), no libraries; desktop tests through lupa;
Python 3 + Pillow for the art tool.

**Spec:** `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`
(the "Plan 8" section). The design it amends is
`docs/superpowers/specs/2026-09-19-goblinps-design.md`.

## Global Constraints

- Plain Lua 5.1, **no libraries**, **no Blizzard frame templates**, no secure code.
- `API.lua` is the only file that calls Blizzard game APIs. UI files may use
  UI globals the siblings already use (`CreateFrame`, `UIParent`, `GameTooltip`).
- **Never read a size from a frame that only inherits one.** Measure the frame
  given an explicit `SetSize` (the planner's `ui.frame`), never a frame placed
  by `SetAllPoints` or by two anchors.
- **A test that checks how big a thing is cannot tell you it is in the wrong
  place.** Pin positions, not only sizes.
- Every FontString gets two horizontal anchors (or a width) and decides wrap
  or truncate.
- A missing texture must leave a working window: every art call falls back.
- No coordinate is hand-typed in `Planner.lua`: every position comes from
  `ns.Data.ArtGeometry.planner`.
- Route text stays plain and glanceable; no jokes in directions or tooltips'
  step lines.
- Lint and the language server at **zero warnings**; do not silence a warning,
  fix the code. No new `---@diagnostic disable`, `luacheck:` exemption or
  `max_line_length = false`.
- Never guess an event, API or texture-call name: check it in
  `D:\wow-api\1.60.1.69913` (the `forever` branch). Verified for this plan:
  `Texture:SetTexture(asset, wrapModeHorizontal, wrapModeVertical, filterMode)`
  with `"REPEAT"` / `"CLAMP"` (`SimpleTextureBaseAPIDocumentation.lua`), and
  `GameTooltip:SetOwner(self, "ANCHOR_TOP")`, `:AddLine(text, r, g, b)`,
  `:Show()`, `:Hide()` (used throughout Blizzard's own UI on this branch).
- Commit after each task. **Never stage `AGENTS.md`** (it belongs to Codex).
  Never push.
- Gates, all green before a task is done:
  - Lua: `python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"`
  - Python: `python -m unittest discover -s test/tools`
  - Art: `python tools/check_art.py`
  - luacheck and lua-language-server **from PowerShell**, as in `CLAUDE.md`
    ("Commands"). Through Git Bash the language server mis-scopes itself and
    reports bogus warnings.
- Known state at the start: the Python suite has 8 failures and
  `check_art.py` reports 6 geometry problems, **by design**, because Codex's
  new wide geometry is already in `images/parts/planner-geometry.json` and the
  tooling still expects the old keys. Task 2 makes both green. The Lua suite
  (310) is green and must stay green after every task.

## Dependency on plan 7

The project rule is to write each plan after the one before it has been used
in game. Plan 7 was partly exercised on 2026-09-21: Escape leaves the dash
alone, as designed. Its resume-after-reload items are blocked by the client
(this build loads no addon's SavedVariables), not by GoblinPS. Plan 8 touches
plan 7 only at one seam: `Planner.Toggle` seeds the search box from
`ns.Dash.Destination()`. Keep that exactly as it is.

## File map

- Create `GoblinPS/Strip.lua`: pure layout of the route strip.
- Create `test/test_strip.lua`: its tests.
- Modify `GoblinPS/GoblinPS.toc`, `test/run.lua`: load `Strip.lua`.
- Modify `tools/make_art.py`, `tools/check_art.py`,
  `test/tools/test_make_art.py`, `test/tools/test_check_art.py`: strip parts,
  wide only.
- Regenerate `GoblinPS/Data/Art.lua` and `GoblinPS/Media/*.tga`; delete
  `GoblinPS/Media/planner-frame-tall.tga`.
- Rewrite `GoblinPS/Planner.lua`: one box, wide only, the strip.
- Modify `GoblinPS/Prefs.lua`, `GoblinPS/Core.lua`: no layout preference.
- Modify `GoblinPS/Widgets.lua`: `W.ShowTooltip`.
- Modify `test/fake_frames.lua`: record tooltip lines and texture wrap modes.
- Modify `test/test_ui.lua`, `test/test_prefs.lua`.
- Docs: `CLAUDE.md`, `docs/manual-test-checklist.md`, the spec's status.

Untouched: `images/parts/planner-frame-tall.png`, the `tall` section of
`images/parts/planner-geometry.json`, `Dash.lua`, routing.

---

### Task 1: `Strip.lua`, the route strip as data

**Files:**
- Create: `GoblinPS/Strip.lua`
- Create: `test/test_strip.lua`
- Modify: `GoblinPS/GoblinPS.toc` (add `Strip.lua` after `Route.lua`)
- Modify: `test/run.lua` (module list and suite list)
- Modify: `test/test_ui.lua:71-72` (load `Strip` after `Route`)

**Interfaces:**
- Consumes: `ns.Route.StepText(step)`, `ns.Route.FormatTime(seconds)`,
  `ns.Route.StepDetail(data, step, level)` -> `text, warn`,
  `ns.Search.ShortName(name)`. A step is
  `{ kind = "ride"|"fly"|"zeppelin"|"boat"|"tram"|"hearth", to = place,
  seconds = n, copper = n, walk = bool?, zone = map?, rough = bool? }`.
- Produces: `ns.Strip.LABEL_ROOM` (= 2) and
  `ns.Strip.Layout(data, steps, opts)`, where
  `opts = { faction = "H"|"A"|other|nil, level = number|nil, trackWidth = px, badgeWidth = px }`,
  returning:

  ```lua
  {
    stops   = { { x = 0..1, badge = "<part name>", label = "...",
                  tooltip = { { text = "...", amber = bool? }, ... } }, ... },
    legs    = { { from = i, to = i + 1, style = "solid"|"dashed", mid = 0..1 }, ... },
    labels  = bool,        -- show names under the badges
    spacing = px|nil,      -- trackWidth / (#stops - 1); nil with no stops
    warning = "..."|nil,   -- "<stop name>: <detail>" for the first amber detail
  }
  ```

  `spacing` and `warning` go beyond the spec's sketch: the planner needs the
  first to bound each name, and the spec's "the warning under the strip names
  it" needs the second. Both are pure, so they belong here.

- [ ] **Step 1: Write the failing tests**

Create `test/test_strip.lua`:

```lua
return function(h, loaded)
    local ns = loaded.ns
    local Strip = ns.Strip
    local data = dofile("test/fake_world.lua")()

    local function step(kind, name, extra)
        local s = { kind = kind, to = { name = name }, seconds = 240, copper = 0 }
        for k, v in pairs(extra or {}) do
            s[k] = v
        end
        return s
    end
    local OPTS = { faction = "H", level = 60, trackWidth = 400, badgeWidth = 40 }

    h.describe("Strip.Layout", function()
        h.it("draws nothing for a route with no steps", function()
            local layout = Strip.Layout(data, {}, OPTS)
            h.eq(#layout.stops, 0)
            h.eq(#layout.legs, 0)
            h.eq(layout.labels, false)
            h.eq(layout.spacing, nil)
        end)

        h.it("puts a one-step route's two stops at the two ends", function()
            local layout = Strip.Layout(data, { step("ride", "Alpha, Westland") }, OPTS)
            h.eq(#layout.stops, 2)
            h.eq(layout.stops[1].x, 0)
            h.eq(layout.stops[2].x, 1)
            h.eq(layout.stops[2].badge, "node-destination", "the last stop is the signpost")
            h.eq(#layout.legs, 1)
        end)

        h.it("spaces every stop evenly, however many there are", function()
            local steps = {}
            for i = 1, 4 do
                steps[i] = step("ride", "Stop " .. i)
            end
            local layout = Strip.Layout(data, steps, OPTS)
            h.eq(#layout.stops, 5, "one more stop than there are steps")
            for i = 1, 5 do
                h.truthy(math.abs(layout.stops[i].x - (i - 1) / 4) < 1e-9, "stop " .. i)
            end
            h.truthy(math.abs(layout.spacing - 100) < 1e-9, "400 px over four gaps")
        end)

        h.it("starts at the faction's crest", function()
            local steps = { step("ride", "Alpha") }
            for faction, badge in pairs({ H = "icon-horde", A = "icon-alliance", N = "icon-neutral" }) do
                local opts = { faction = faction, level = 60, trackWidth = 400, badgeWidth = 40 }
                h.eq(Strip.Layout(data, steps, opts).stops[1].badge, badge, faction)
            end
            local opts = { level = 60, trackWidth = 400, badgeWidth = 40 }
            h.eq(Strip.Layout(data, steps, opts).stops[1].badge, "icon-neutral", "no faction")
        end)

        h.it("shows at each stop how you got there", function()
            local steps = {
                step("ride", "A"), step("ride", "B", { walk = true }), step("fly", "C"),
                step("zeppelin", "D"), step("boat", "E"), step("tram", "F"),
                step("hearth", "G"), step("portal", "H"), step("fly", "End"),
            }
            local want = { "icon-ride", "icon-walk", "icon-flight", "icon-zeppelin", "icon-boat",
                           "icon-tram", "icon-hearth", "node-ring", "node-destination" }
            local layout = Strip.Layout(data, steps, OPTS)
            for i, badge in ipairs(want) do
                h.eq(layout.stops[i + 1].badge, badge, "stop " .. (i + 1))
            end
        end)

        h.it("names the start You are here and every other stop by its short name", function()
            local layout = Strip.Layout(data, { step("fly", "Crossroads, The Barrens") }, OPTS)
            h.eq(layout.stops[1].label, "You are here")
            h.eq(layout.stops[2].label, "Crossroads")
        end)

        h.it("keeps the names while two badge widths fit between stops, and drops them below", function()
            local opts = { faction = "H", level = 60, trackWidth = 100, badgeWidth = 50 }
            h.eq(Strip.Layout(data, { step("ride", "A") }, opts).labels, true, "100 px is exactly two badges")
            h.eq(Strip.Layout(data, { step("ride", "A"), step("ride", "B") }, opts).labels, false,
                 "50 px is one badge: too crowded to read")
        end)

        h.it("draws the leg you are about to start solid and every one after dashed", function()
            local layout = Strip.Layout(data, { step("ride", "A"), step("fly", "B"), step("ride", "C") }, OPTS)
            h.eq(layout.legs[1].style, "solid")
            h.eq(layout.legs[2].style, "dashed")
            h.eq(layout.legs[3].style, "dashed")
            for i, leg in ipairs(layout.legs) do
                h.eq(leg.from, i)
                h.eq(leg.to, i + 1)
                h.truthy(math.abs(leg.mid - (i - 0.5) / 3) < 1e-9, "leg " .. i .. " midpoint")
            end
        end)

        h.it("tells the start's tooltip where you are", function()
            local layout = Strip.Layout(data, { step("ride", "A") }, OPTS)
            h.eq(#layout.stops[1].tooltip, 1)
            h.eq(layout.stops[1].tooltip[1].text, "You are here")
        end)

        h.it("gives each stop the step, its time and its detail", function()
            local layout = Strip.Layout(data, { step("zeppelin", "East Dock") }, OPTS)
            local tip = layout.stops[2].tooltip
            h.eq(tip[1].text, "Zeppelin to East Dock")
            h.eq(tip[2].text, "~4 min")
            h.eq(tip[3].text, "includes the average wait")
            h.eq(tip[3].amber, false)
        end)

        h.it("leaves out a detail line the step does not have", function()
            local layout = Strip.Layout(data, { step("fly", "Bravo, Westland") }, OPTS)
            h.eq(#layout.stops[2].tooltip, 2)
        end)

        h.it("turns a hazard's detail amber and names it as the warning", function()
            local gate = step("ride", "the North Gate", { zone = 1 })
            gate.to.zones = { 1, 4 }
            gate.to.warn = "trolls on the bridge"
            local layout = Strip.Layout(data, { gate, step("ride", "Hotel, Northland", { zone = 4 }) }, OPTS)
            local detail = layout.stops[2].tooltip[3]
            h.eq(detail.text, "into Northland · trolls on the bridge")
            h.eq(detail.amber, true)
            h.eq(layout.warning, "the North Gate: into Northland · trolls on the bridge")
        end)

        h.it("has no warning when nothing is amber", function()
            local layout = Strip.Layout(data, { step("ride", "Hotel, Northland", { zone = 4 }) }, OPTS)
            h.eq(layout.warning, nil)
        end)
    end)
end
```

- [ ] **Step 2: Load it in the runner**

In `test/run.lua`, add `{ "Strip",   "GoblinPS/Strip.lua" },` to `modules`
directly after the `Route` row, and `"test/test_strip.lua",` to `suites`
directly after `"test/test_route.lua",`. In `test/test_ui.lua` lines 71-72,
add `"Strip"` to the load list directly after `"Route"`.

- [ ] **Step 3: Run the Lua suite to verify the new tests fail**

Run the Lua gate. Expected: the runner skips a missing `Strip.lua` (it checks
`io.open`), so `test_strip.lua` errors on `Strip` being nil, and the UI suite
fails loading `GoblinPS/Strip.lua`. Both are the expected red.

- [ ] **Step 4: Write `GoblinPS/Strip.lua`**

```lua
local _, ns = ...

-- The route strip as data: one stop per place the route passes through, the
-- badge each one wears, where it sits along the track, what its tooltip says,
-- and how the legs between them are drawn. Pure: no frames and no Blizzard
-- globals. Planner.lua draws what this returns and decides nothing.
local Strip = {}
ns.Strip = Strip

-- Names show under the badges while the space between two badge centres is
-- at least this many badge widths. Closer than that, every name is dropped
-- and lives only in the tooltips.
Strip.LABEL_ROOM = 2

local CREST = { H = "icon-horde", A = "icon-alliance" }
local BADGE = { fly = "icon-flight", zeppelin = "icon-zeppelin", boat = "icon-boat",
                tram = "icon-tram", hearth = "icon-hearth" }

-- How you got to a stop. Walk or ride is the same test Route.StepText uses,
-- so the badge and the words can never disagree. A kind this file does not
-- know wears the plain ring rather than raising.
local function badgeFor(step)
    if step.kind == "ride" then
        return step.walk and "icon-walk" or "icon-ride"
    end
    return BADGE[step.kind] or "node-ring"
end

local function tooltipFor(data, step, level)
    local lines = { { text = ns.Route.StepText(step) }, { text = ns.Route.FormatTime(step.seconds) } }
    local detail, warn = ns.Route.StepDetail(data, step, level)
    if detail ~= "" then
        lines[3] = { text = detail, amber = warn and true or false }
    end
    return lines
end

function Strip.Layout(data, steps, opts)
    local layout = { stops = {}, legs = {}, labels = false }
    if #steps == 0 then
        return layout
    end
    local gaps = #steps
    layout.spacing = opts.trackWidth / gaps
    layout.labels = layout.spacing >= Strip.LABEL_ROOM * opts.badgeWidth
    layout.stops[1] = { x = 0, badge = CREST[opts.faction] or "icon-neutral", label = "You are here",
                        tooltip = { { text = "You are here" } } }
    for i, step in ipairs(steps) do
        local name = ns.Search.ShortName(step.to.name)
        local tooltip = tooltipFor(data, step, opts.level)
        layout.stops[i + 1] = { x = i / gaps, badge = i == gaps and "node-destination" or badgeFor(step),
                                label = name, tooltip = tooltip }
        layout.legs[i] = { from = i, to = i + 1, style = i == 1 and "solid" or "dashed",
                           mid = (i - 0.5) / gaps }
        if not layout.warning and tooltip[3] and tooltip[3].amber then
            layout.warning = name .. ": " .. tooltip[3].text
        end
    end
    return layout
end

return Strip
```

Add `Strip.lua` to `GoblinPS/GoblinPS.toc` on its own line directly after
`Route.lua`.

- [ ] **Step 5: Run every gate**

Lua suite: expected green, 310 + 13 = 323 passed. luacheck and the language
server from PowerShell: zero warnings.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Strip.lua GoblinPS/GoblinPS.toc test/test_strip.lua test/run.lua test/test_ui.lua
git commit -m "Strip.lua: the route strip as data" -m "One stop per place the route passes through: the faction crest at the start, how you got there at each stop after, the signpost at the end; evenly spaced, names dropped when crowded, the first leg solid and the rest dashed, and each stop's tooltip lines. Pure, so the planner only draws it." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: the art tool ships the strip and stops shipping tall

Python only. **Do not run `tools/make_art.py` in this task**: regenerating
`Data/Art.lua` from the new geometry removes keys today's `Planner.lua`
reads (`fromBox`, `sidePanel` ...) and would break the Lua suite. Task 3
regenerates and switches the planner over in one commit.

**Files:**
- Modify: `tools/make_art.py`
- Modify: `tools/check_art.py:261-337`
- Modify: `test/tools/test_make_art.py`
- Modify: `test/tools/test_check_art.py`

**Interfaces:**
- Produces: `make_art.PARTS` holds the fifteen strip parts and no
  `planner-frame-tall`; `make_art.planner_geometry_lua()` returns
  `{ "wide": {...}, "strip": {...} }`, no `"tall"`. The wide keys, camel-cased:
  `canvas, titlePlate, taglinePlate, closeButton, gearButton, toBox,
  dropdownButton, resultsList, screen, stripTrack, totalLine, hintLine,
  notesLine, knownLine, goButton, interior`. Task 3 and Task 4 read these.

- [ ] **Step 1: Write the failing Python tests**

In `test/tools/test_make_art.py`:

1. In `TestShipsThePlannerParts.test_ships_the_planner_parts_at_their_source_aspect`,
   remove `"planner-frame-tall"` from `wanted`.
2. Replace `test_does_not_ship_the_strip_parts_yet` with these three tests
   (same class):

```python
    STRIP = ("node-ring", "node-destination", "line-solid", "line-dashed", "line-dot",
             "icon-flight", "icon-boat", "icon-zeppelin", "icon-tram", "icon-hearth",
             "icon-walk", "icon-ride", "icon-horde", "icon-alliance", "icon-neutral")

    def test_ships_the_fifteen_strip_parts_at_their_source_aspect(self):
        from PIL import Image
        import tools.make_art as make_art
        by_name = {p.name: p for p in make_art.PARTS}
        self.assertEqual(set(self.STRIP) - set(by_name), set(), "these strip parts are not shipped")
        for name in self.STRIP:
            part = by_name[name]
            with Image.open(make_art.SOURCE / (name + ".png")) as im:
                sw, sh = im.size
            self.assertLess(abs(sw / sh - part.width / part.height) / (sw / sh), 0.005, name)

    def test_ships_the_strip_parts_unpadded(self):
        """The lines tile along a leg; a padded part would repeat its padding."""
        import tools.make_art as make_art
        by_name = {p.name: p for p in make_art.PARTS}
        for name in self.STRIP:
            part = by_name[name]
            self.assertEqual(make_art.next_power_of_two(part.width), part.width, name)
            self.assertEqual(make_art.next_power_of_two(part.height), part.height, name)

    def test_does_not_ship_what_nothing_draws(self):
        import tools.make_art as make_art
        names = {p.name for p in make_art.PARTS}
        for name in ("node-current", "icon-gate", "icon-warning", "planner-frame-tall"):
            self.assertNotIn(name, names)
```

3. In `TestPlannerGeometry`:
   - `test_planner_geometry_reaches_the_addon_whole` becomes wide only:

```python
    def test_planner_geometry_reaches_the_addon_whole(self):
        """Wide only, and every number still normalised."""
        import tools.make_art as make_art
        g = make_art.planner_geometry_lua()
        self.assertEqual(set(g), {"wide", "strip"}, "tall is no longer read by the addon")
        self.assertEqual(g["wide"]["canvas"], {"w": 1600, "h": 1024})
        for key, box in g["wide"].items():
            if key == "canvas":
                continue
            for edge, value in box.items():
                self.assertGreaterEqual(value, 0.0, "wide.{0}.{1}".format(key, edge))
                self.assertLessEqual(value, 1.0, "wide.{0}.{1}".format(key, edge))

    def test_planner_geometry_has_exactly_the_mockups_keys(self):
        import tools.make_art as make_art
        g = make_art.planner_geometry_lua()
        self.assertEqual(set(g["wide"]), {
            "canvas", "titlePlate", "taglinePlate", "closeButton", "gearButton", "toBox",
            "dropdownButton", "resultsList", "screen", "stripTrack", "totalLine", "hintLine",
            "notesLine", "knownLine", "goButton", "interior"})
```

   - In `test_planner_geometry_names_are_camel_case`, replace
     `self.assertIn("fromBox", g["wide"])` with
     `self.assertIn("stripTrack", g["wide"])`.
4. In `TestFrameInterior`, every `for mode in ("wide", "tall"):` loop becomes
   wide only (drop the loop, set `mode = "wide"`), and the key tuple in
   `test_every_layout_has_an_interior_that_holds_its_panels` becomes
   `("screen", "toBox", "goButton", "stripTrack", "totalLine", "hintLine")`.
   Rename that test `test_the_interior_holds_every_panel`.

In `test/tools/test_check_art.py`:

1. `test_a_listed_key_that_vanished_fails`: `del g["wide"]["screen"]` and
   assert `"wide.screen"` is in the problem.
2. `test_a_renamed_key_fails_twice_over`: rename `hint_line` to `hint_slot`:
   `g["wide"]["hint_slot"] = g["wide"].pop("hint_line")`, and assert both
   `"wide.hint_slot"` and `"wide.hint_line"` appear.
3. Replace class `TestBrassKeys` with:

```python
class TestBrassKeys(unittest.TestCase):
    def test_only_the_two_plates_sit_on_brass(self):
        # Every other rectangle must clear the frame's opening. The gear,
        # Close and the dropdown are circles and are not classified at all.
        self.assertEqual(check_art.PLANNER_BRASS_KEYS, {"title_plate", "tagline_plate"})

    def test_the_tall_record_is_not_checked(self):
        # Kept on disk verbatim, read by nothing: checking it would pin a
        # layout the addon no longer has.
        self.assertEqual(set(check_art.PLANNER_FRAMES), {"wide"})
```

- [ ] **Step 2: Run the Python suite to see them fail**

`python -m unittest discover -s test/tools`. Expected: failures naming the
strip parts, the tall key and the brass list.

- [ ] **Step 3: Change `tools/make_art.py`**

Replace the comment line `# The strip's nodes, lines and icons are plan 7 and are not shipped yet.`
with nothing, remove `Part("planner-frame-tall", 384, 600),` from the planner
list, and append after that list:

```python
# The route strip. Badges are 192 px sources (a 128 px visible ring) and draw
# at about 58 px, the full sprite being 1.5 times the geometry's ring. The
# lines are 512x64 sources, 8:1, and draw 13 px tall at 650 px wide; they
# TILE along each leg, so they ship unpadded -- a padded part would repeat its
# padding. Every one of these is a power of two already, so none is padded.
# node-current, icon-gate and icon-warning stay unshipped: nothing draws them.
PARTS += [Part(name, 64, 64) for name in (
    "node-ring", "node-destination",
    "icon-flight", "icon-boat", "icon-zeppelin", "icon-tram", "icon-hearth", "icon-walk", "icon-ride",
    "icon-horde", "icon-alliance", "icon-neutral",
)]
PARTS += [
    Part("line-solid", 128, 16),
    Part("line-dashed", 128, 16),
    Part("line-dot", 16, 16),
]
```

In `planner_geometry_lua`, read wide only. Replace the loop and its body with:

```python
    g = planner_geometry()
    source = g["wide"]
    # canvas is source pixels, the one exception to the 0..1 rule.
    box = {"canvas": {"w": source["canvas"][0], "h": source["canvas"][1]}}
    for key, rect in source.items():
        if key == "canvas" or key in PLANNER_DROP:
            continue
        box[_camel(key)] = dict(rect)
    # Measured from the frame art, not read from the geometry file.
    box["interior"] = frame_interior("wide", source["screen"])
    out = {"wide": box}
```

and update the docstring's first line to "The planner's placement numbers, as
plain fractions, for its one wide layout." Add one line to the docstring:
"The file's `tall` section is kept on disk as a record and read by nothing."
Keep the `strip` block as it is. `PLANNER_DROP` stays: it is harmless for the
wide keys and still documents `tools_button`.

- [ ] **Step 4: Change `tools/check_art.py`**

Replace lines 261-289 (the two allow-lists, their comments and
`PLANNER_FRAMES`) with:

```python
# Every rectangular key in the wide layout of planner-geometry.json is in
# exactly one of the two sets below, and a key in neither is a failure. It
# used to be a silence: a key in no list got neither a pass nor a complaint.
# CLAUDE.md has the rule this broke -- never let silence read as "nothing
# disagrees".
#
# INTERIOR: content drawn straight onto the frame with nothing of its own
# behind it. These must land on the frame's real cut-out or the text prints
# on brass. Codex measured every one at 0% opaque frame pixels (2026-09-21).
PLANNER_INTERIOR_KEYS = {"screen", "results_list", "strip_track", "total_line", "hint_line",
                         "notes_line", "known_line", "to_box", "go_button"}

# BRASS: keys that sit on the frame's brass BY DESIGN, because each carries its
# own opaque sprite -- a name plate riveted to the crest or the rail.
PLANNER_BRASS_KEYS = {"title_plate", "tagline_plate"}

# Wide only. The tall section stays in the file as a record, read by nothing,
# so it is not checked: that would pin a layout the addon no longer has.
PLANNER_FRAMES = {"wide": "planner-frame-wide.png"}
```

Rewrite `planner_keys_classified` for the one layout:

```python
def planner_keys_classified(g):
    """Both directions of the allow-list, against the wide geometry as loaded.

    A rectangular key in neither set is unclassified, and an addition must
    not slip in silently. A key either set names that is not in the geometry
    is a rename or a deletion, and that must not slip out silently either.
    """
    problems = []
    keys = g.get("wide", {})
    rects = {key for key, value in keys.items() if isinstance(value, dict) and "left" in value}
    for key in sorted(rects - PLANNER_INTERIOR_KEYS - PLANNER_BRASS_KEYS):
        problems.append("wide.{0} is in neither PLANNER_INTERIOR_KEYS nor "
                        "PLANNER_BRASS_KEYS: say which it is".format(key))
    for key in sorted((PLANNER_INTERIOR_KEYS | PLANNER_BRASS_KEYS) - set(keys)):
        problems.append("wide.{0} is named by the allow-lists but is not in the "
                        "geometry: renamed or dropped".format(key))
    return problems
```

In `planner_geometry_holds`, change the skip test from
`if key not in PLANNER_INTERIOR_KEYS or key in PLANNER_BRASS_KEYS[layout]:`
to `if key not in PLANNER_INTERIOR_KEYS:`. Leave the `SPEC` table alone: it
checks the source PNGs, and the tall source art stays on disk.

- [ ] **Step 5: Run the Python suite and the art check**

`python -m unittest discover -s test/tools`: expected green, 0 failures.
`python tools/check_art.py`: expected `0 with problems`. The Lua suite is
untouched and must still read 323 passed.

- [ ] **Step 6: Commit**

```
git add tools/make_art.py tools/check_art.py test/tools/test_make_art.py test/tools/test_check_art.py
git commit -m "Art tool: ship the route strip, stop shipping tall" -m "Fifteen strip parts ship unpadded so the lines can tile; planner-frame-tall and the tall geometry no longer reach the addon, and check_art classifies the mockup's wide keys. The tall source art and its record stay on disk. Art.lua is regenerated with the planner in the next commit, since today's window still reads the old keys." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

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

### Task 4: draw the route strip, with a tooltip on every stop

**Files:**
- Modify: `GoblinPS/Widgets.lua` (add `Widgets.ShowTooltip`)
- Modify: `GoblinPS/Planner.lua` (the strip)
- Modify: `test/fake_frames.lua` (tooltip lines, texture wrap modes)
- Modify: `test/test_ui.lua` (a new "the route strip" block)

**Interfaces:**
- Consumes: `ns.Strip.Layout` (Task 1), the wide geometry `stripTrack`,
  `screen` and `ns.Data.ArtGeometry.planner.strip` =
  `{ nodeDiameter = 0.06, lineThickness = 0.02, labelGap = 0.012 }` (Task 2),
  and the Task 3 planner.
- Produces: `W.ShowTooltip(owner, lines)` where `lines` is Strip's tooltip
  shape; `ui.strip` (a Frame on the screen) with `ui.strip.badges[i]`
  (Buttons, each with `.art`, `.flat`, `.label`, `.stop`) and
  `ui.strip.legs[i]` (`{ line = Texture, dot = Texture }`).

Numbers this task uses, all from the geometry at 650x416: the track runs
from x = 0.14375 x 650 = 93.4 px to 0.85 x 650 = 552.5 px (459.1 px), at
y = (0.46875 + 0.625) / 2 x 416 = 227.5 px. The visible ring is
0.06 x 650 = 39 px; the badge sprite is 1.5 times that, 58.5 px. The line box
is 0.02 x 650 = 13 px tall, glow included. The label gap is 0.012 x 650 = 7.8 px.
The shipped line parts are 128x16, so one tile is 13 x 8 = 104 px long.

Rulings this task carries (record them in the ledger):

- **The dot is drawn one line-box square (13 px).** The geometry gives the
  dot no size of its own; Codex's preview drew it at 20/32 of the line's
  box. Sizing it from `lineThickness` keeps it off hand-typed numbers.
- **A badge whose art will not load wears `node-ring`; if that fails too, a
  flat brass square the size of the ring.** The spec says "a flat circle",
  but a colour texture cannot be round without a mask, and no stock circular
  texture is verified on this build. The strip still reads either way.
- **The warning line's priority**: the first amber stop's detail, then a
  note about the route, then the flight path worth discovering.
- **Names are bounded symmetrically** around their badge: half the space
  between stops, and never past the screen's edge, so the end names stay on
  the glass (about 65 px wide at the two ends; the screen reserves 32.5 px
  beyond each end badge).

- [ ] **Step 1: Teach the fake frames the two things this needs**

In `test/fake_frames.lua`:

1. Remove `SetOwner = true, AddLine = true,` from `ALLOWED_NOOP`.
2. Replace `function Region:SetTexture(path)` with:

```lua
-- The real SetTexture returns a documented success bool. The two wrap modes
-- are recorded: a line that TILES along its leg needs "REPEAT", and a test
-- must be able to tell a tiled texture from a stretched one.
function Region:SetTexture(path, wrapH, wrapV)
    self.texture = path
    self.wrapH, self.wrapV = wrapH, wrapV
    return path ~= nil and not Fake.missingTextures[path]
end
```

3. In `Fake.Install`, replace `_G.GameTooltip = new("GameTooltip")` with:

```lua
    -- The one tooltip the client shares. SetOwner starts a fresh tooltip, as
    -- the real one does, and each line is kept with its colour so a test can
    -- read what the player would.
    local tip = new("GameTooltip")
    tip.lines = {}
    function tip.SetOwner(self, owner, anchor)
        self.owner, self.anchor, self.lines = owner, anchor, {}
    end
    function tip.AddLine(self, text, r, g, b)
        self.lines[#self.lines + 1] = { text = text, color = r and { r, g, b } or nil }
    end
    _G.GameTooltip = tip
```

Run the Lua suite: still green (the minimap button's tooltip now exercises
the modelled methods).

- [ ] **Step 2: Write the failing tests**

In `test/test_ui.lua`, add this block directly after the end of
`h.describe("the planner window", ...)`:

```lua
    h.describe("the route strip", function()
        local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"
        local amber, dim = ns.Widgets.COLOR.amber, ns.Widgets.COLOR.dim
        local function art(name) return MEDIA .. ns.Data.Art[name].file end
        local function pickTo(text)
            local ui = Planner.Debug()
            Fake.Type(ui.toBox, text)
            Fake.Click(ui.results.rows[1])
            return ui
        end
        local function track()
            local ui = Planner.Debug()
            local g, s = ns.Data.ArtGeometry.planner.wide, ns.Data.ArtGeometry.planner.strip
            local w, fh = ui.frame:GetWidth(), ui.frame:GetHeight()
            return { left = g.stripTrack.left * w, right = g.stripTrack.right * w,
                     cy = (g.stripTrack.top + g.stripTrack.bottom) / 2 * fh,
                     ring = s.nodeDiameter * w, thick = s.lineThickness * w }
        end
        local function near(a, b) return math.abs(a - b) < 0.01 end

        h.it("draws one badge per stop, wearing how you get there", function()
            if not Planner.Debug().frame:IsShown() then
                SlashCmdList.GOBLINPS("")
            end
            local ui = pickTo("delt")
            h.truthy(ui.strip:IsShown())
            local want = { "icon-horde", "icon-ride", "icon-flight", "icon-ride", "icon-zeppelin",
                           "node-destination" }
            for i, name in ipairs(want) do
                local b = ui.strip.badges[i]
                h.truthy(b and b:IsShown(), "badge " .. i)
                h.eq(b.art:GetTexture(), art(name), "badge " .. i)
            end
        end)

        h.it("puts each badge where the layout says, in real pixels", function()
            local ui, t = Planner.Debug(), track()
            for i = 1, 6 do
                local b = ui.strip.badges[i]
                local p = b.points[1]
                h.eq(p[1], "CENTER")
                h.truthy(p[2] == ui.frame, "measured from the window, which has a real size")
                h.truthy(near(p[4], t.left + (i - 1) / 5 * (t.right - t.left)), "badge " .. i .. " x")
                h.truthy(near(p[5], -t.cy), "badge " .. i .. " y")
                h.truthy(near(b:GetWidth(), t.ring * 1.5), "the sprite is 1.5 times the visible ring")
                h.eq(b:GetWidth(), b:GetHeight())
            end
        end)

        h.it("joins the stops with a solid first leg and dashed after, tiled not stretched", function()
            local ui, t = Planner.Debug(), track()
            local length = (t.right - t.left) / 5
            for i = 1, 5 do
                local line = ui.strip.legs[i].line
                h.eq(line:GetTexture(), art(i == 1 and "line-solid" or "line-dashed"), "leg " .. i)
                h.eq(line.wrapH, "REPEAT", "a dash keeps its length on any leg")
                local part = ns.Data.Art["line-dashed"]
                h.truthy(near(line.texCoord[2], length / (t.thick * part.cw / part.ch)),
                         "one tile per line-box times the part's own aspect")
                h.truthy(near(line:GetWidth(), length))
                h.truthy(near(line:GetHeight(), t.thick))
                h.truthy(near(line.points[1][4], t.left + (i - 1) * length), "starts at its badge's centre")
                local dot = ui.strip.legs[i].dot
                h.eq(dot:GetTexture(), art("line-dot"))
                h.truthy(near(dot.points[1][4], t.left + (i - 0.5) * length), "the dot sits mid-leg")
            end
        end)

        h.it("draws the line under the badges and the strip above the screen's fills", function()
            local ui = Planner.Debug()
            h.truthy(ui.strip.legs[1].line.parent == ui.strip, "the line is the strip's own texture")
            h.truthy(ui.strip.badges[1].parent == ui.strip, "each badge is a child frame over it")
            h.truthy(ui.strip.badges[1]:GetFrameLevel() > ui.strip:GetFrameLevel())
            h.truthy(ui.strip.parent == ui.screen, "and the strip is a child of the opaque screen")
            h.truthy(ui.strip:GetFrameLevel() > ui.screen:GetFrameLevel())
        end)

        h.it("names the stops while there is room, each name bounded", function()
            local ui = Planner.Debug()
            h.eq(ui.strip.badges[1].label:GetText(), "You are here")
            h.eq(ui.strip.badges[2].label:GetText(), "Alpha")
            for i = 1, 6 do
                local label = ui.strip.badges[i].label
                h.truthy(label:IsShown(), "91.8 px between stops is more than two 39 px rings")
                h.eq(#label.points, 2, "two horizontal anchors, so it truncates")
                h.eq(label.wordWrap, false)
            end
        end)

        h.it("drops every name into the tooltips when the stops crowd", function()
            local ui, state = Planner.Debug()
            local saved = state.plan
            local steps = {}
            for i = 1, 8 do
                steps[i] = { kind = "ride", to = { name = "Stop " .. i }, seconds = 60, copper = 0 }
            end
            state.plan = { to = { name = "Stop 8" }, notes = {}, level = 60,
                           result = { steps = steps, seconds = 480, copper = 0 } }
            Planner.Refresh()
            for i = 1, 9 do
                h.truthy(ui.strip.badges[i]:IsShown(), "every stop still shows")
                h.falsy(ui.strip.badges[i].label:IsShown(), "57 px between stops: names go")
            end
            state.plan = saved
            Planner.Refresh()
            h.falsy(ui.strip.badges[7]:IsShown(), "a shorter route hides the spare badges")
            h.falsy(ui.strip.badges[7].label:IsShown())
            h.falsy(ui.strip.legs[6].line:IsShown(), "and the spare legs")
            h.falsy(ui.strip.legs[6].dot:IsShown())
        end)

        h.it("shows a stop's lines on hover and puts them away on leave", function()
            local ui = Planner.Debug()
            local b = ui.strip.badges[3]
            b.scripts.OnEnter(b)
            h.truthy(GameTooltip.owner == b)
            h.truthy(GameTooltip:IsShown())
            h.eq(GameTooltip.lines[1].text, "Fly to Bravo")
            h.eq(GameTooltip.lines[2].text, "~4 min")
            b.scripts.OnLeave(b)
            h.falsy(GameTooltip:IsShown())
        end)

        h.it("turns a hazard's detail amber and names it on the warning line", function()
            local ui = pickTo("hotel")
            local b = ui.strip.badges[2]
            b.scripts.OnEnter(b)
            h.eq(GameTooltip.lines[1].text, "Ride to the North Gate")
            h.eq(GameTooltip.lines[3].text, "into Northland · trolls on the bridge")
            h.eq(GameTooltip.lines[3].color[1], amber[1])
            h.eq(GameTooltip.lines[3].color[2], amber[2])
            h.eq(GameTooltip.lines[3].color[3], amber[3])
            local last = ui.strip.badges[3]
            last.scripts.OnEnter(last)
            h.eq(GameTooltip.lines[3].text, "in Northland · level 30-40")
            h.eq(GameTooltip.lines[3].color[1], dim[1], "level 60 in a 30-40 zone is no warning")
            GameTooltip:Hide()
            h.eq(ui.hint:GetText(), "the North Gate: into Northland · trolls on the bridge")
        end)

        h.it("wears the boot and says Walk for a low-level character", function()
            level = 1
            local ui = pickTo("hotel")
            local b = ui.strip.badges[2]
            h.eq(b.art:GetTexture(), art("icon-walk"))
            b.scripts.OnEnter(b)
            h.eq(GameTooltip.lines[1].text, "Walk to the North Gate")
            GameTooltip:Hide()
            level = 60
        end)

        h.it("says so on the tooltip when the crossings table has a hole", function()
            local ui = pickTo("lostland")
            local b = ui.strip.badges[2]
            b.scripts.OnEnter(b)
            h.eq(GameTooltip.lines[1].text, "Ride toward Lostland (no mapped path)")
            h.eq(#GameTooltip.lines, 2, "a straight line has no zone detail")
            GameTooltip:Hide()
        end)

        h.it("keeps a readable strip when a badge's art will not load", function()
            local ui = pickTo("delt")
            Fake.missingTextures[art("icon-flight")] = true
            Planner.Refresh()
            h.eq(ui.strip.badges[3].art:GetTexture(), art("node-ring"), "the plain ring stands in")
            Fake.missingTextures[art("node-ring")] = true
            Planner.Refresh()
            h.falsy(ui.strip.badges[3].art:IsShown())
            h.truthy(ui.strip.badges[3].flat:IsShown(), "and failing that, a flat marker")
            Fake.missingTextures[art("icon-flight")] = nil
            Fake.missingTextures[art("node-ring")] = nil
            Planner.Refresh()
            h.truthy(ui.strip.badges[3].art:IsShown())
            h.falsy(ui.strip.badges[3].flat:IsShown())
        end)

        h.it("draws no strip without a route", function()
            local ui = pickTo("westland")
            h.falsy(ui.strip:IsShown(), "you're already there: words, not a strip")
            h.truthy(ui.notes:IsShown())
            pickTo("delt")
            h.truthy(ui.strip:IsShown())
        end)

        h.it("W.ShowTooltip colours every line after the first, amber for a warning", function()
            local owner = CreateFrame("Button", nil, UIParent)
            W.ShowTooltip(owner, { { text = "Ride to X" }, { text = "~2 min" },
                                   { text = "careful", amber = true } })
            h.eq(GameTooltip.anchor, "ANCHOR_TOP")
            h.eq(GameTooltip.lines[1].color, nil, "the first line keeps the tooltip's own title colour")
            h.eq(GameTooltip.lines[2].color[1], dim[1])
            h.eq(GameTooltip.lines[3].color[1], amber[1])
            GameTooltip:Hide()
        end)
    end)
```

Run the Lua suite. Expected: the new block fails (`ui.strip` is nil,
`W.ShowTooltip` is nil).

- [ ] **Step 3: Add `W.ShowTooltip` to `GoblinPS/Widgets.lua`**

Directly before `return Widgets`:

```lua
-- One tooltip for a thing on screen, from plain { text, amber } lines. The
-- first line is the tooltip's title and keeps the client's own colour; every
-- line after is dim, or amber for a warning. Blizzard's shared GameTooltip,
-- not a template: SetOwner, AddLine and Show are on build 1.60.1.69913 and
-- Blizzard's own UI calls them throughout. The minimap button keeps its own.
function Widgets.ShowTooltip(owner, lines)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    for i, line in ipairs(lines) do
        if i == 1 then
            GameTooltip:AddLine(line.text)
        else
            GameTooltip:AddLine(line.text, rgb(line.amber and "amber" or "dim"))
        end
    end
    GameTooltip:Show()
end
```

- [ ] **Step 4: Draw the strip in `GoblinPS/Planner.lua`**

Add after `local MEDIA = ...` and `geo()`:

```lua
-- The badge art is a 128 px ring on a 192 px canvas, and the geometry's
-- nodeDiameter is the RING, so the whole sprite is 1.5 times it. Size from
-- the ring alone and every stop draws a third too small.
local SPRITE = 1.5

-- The strip's measurements in real pixels, all read off the window: it is
-- the frame given an explicit SetSize, so measuring it is legal.
local function stripMetrics(g)
    local s = ns.Data.ArtGeometry.planner.strip
    local w, h = ui.frame:GetWidth(), ui.frame:GetHeight()
    return { left = g.stripTrack.left * w, right = g.stripTrack.right * w,
             cy = (g.stripTrack.top + g.stripTrack.bottom) / 2 * h,
             ring = s.nodeDiameter * w, thick = s.lineThickness * w, gap = s.labelGap * w,
             screenLeft = g.screen.left * w, screenRight = g.screen.right * w }
end

-- Badges and legs are pooled: made the first time a route needs that many,
-- reused after, hidden when a shorter route needs fewer.
local function badge(i)
    local b = ui.strip.badges[i]
    if b then
        return b
    end
    b = CreateFrame("Button", nil, ui.strip)
    b.flat = b:CreateTexture(nil, "BACKGROUND")
    b.flat:SetPoint("CENTER")
    local c = W.COLOR.brass
    b.flat:SetColorTexture(c[1], c[2], c[3], 1)
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetAllPoints(b)
    b.label = W.Text(ui.strip, "green", nil, "CENTER")
    b:SetScript("OnEnter", function(self) W.ShowTooltip(self, self.stop.tooltip) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.strip.badges[i] = b
    return b
end

local function leg(i)
    local l = ui.strip.legs[i]
    if not l then
        -- On the strip itself, so the badges -- child frames -- cover their ends.
        l = { line = ui.strip:CreateTexture(nil, "BORDER"), dot = ui.strip:CreateTexture(nil, "ARTWORK") }
        ui.strip.legs[i] = l
    end
    return l
end

-- A badge wears its part; failing that the plain ring; failing that a flat
-- marker the size of the ring. The strip must read with no art at all.
local function wear(b, name)
    for _, try in ipairs({ name, "node-ring" }) do
        local part = ns.Data.Art and ns.Data.Art[try]
        if part and b.art:SetTexture(MEDIA .. part.file) then
            b.art:SetTexCoord(part.l, part.r, part.t, part.b)
            b.art:Show()
            b.flat:Hide()
            return
        end
    end
    b.art:Hide()
    b.flat:Show()
end

-- A line part TILES along its leg at its own aspect, so a dash keeps its
-- length on a short leg and a long one alike; only the last tile is cut.
-- One tile is the line box's height times the part's width over its height.
-- That needs the part shipped unpadded -- its crop the whole texture -- as
-- planner-panel is, since tiling a padded part repeats the padding. Padded
-- or missing, the leg falls back to a flat green stroke a quarter of the
-- box: the glow box itself, filled solid, would read as a bar.
local function drawLine(t, name, length, thick)
    local part = ns.Data.Art and ns.Data.Art[name]
    local whole = part and part.l == 0 and part.r == 1 and part.t == 0 and part.b == 1
    if whole and t:SetTexture(MEDIA .. part.file, "REPEAT", "CLAMP") then
        t:SetTexCoord(0, length / (thick * part.cw / part.ch), 0, 1)
        t:SetHeight(thick)
    else
        local c = W.COLOR.green
        t:SetColorTexture(c[1], c[2], c[3], 1)
        t:SetHeight(thick / 4)
    end
end

local function drawStrip(layout, m)
    local span = m.right - m.left
    local function at(x) return m.left + x * span end
    local sprite = m.ring * SPRITE
    for i, stop in ipairs(layout.stops) do
        local b, x = badge(i), at(stop.x)
        b.stop = stop
        b:SetSize(sprite, sprite)
        b:ClearAllPoints()
        b:SetPoint("CENTER", ui.frame, "TOPLEFT", x, -m.cy)
        b.flat:SetSize(m.ring, m.ring)
        wear(b, stop.badge)
        b:Show()
        -- Half the space to the next stop either side, never off the glass.
        local half = math.min(layout.spacing / 2, x - m.screenLeft, m.screenRight - x)
        local top = -(m.cy + m.ring / 2 + m.gap)
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", x - half, top)
        b.label:SetPoint("TOPRIGHT", ui.frame, "TOPLEFT", x + half, top)
        b.label:SetText(stop.label)
        b.label:SetShown(layout.labels)
    end
    for i = #layout.stops + 1, #ui.strip.badges do
        ui.strip.badges[i]:Hide()
        ui.strip.badges[i].label:Hide()
    end
    for i, lg in ipairs(layout.legs) do
        local l = leg(i)
        local x1, x2 = at(layout.stops[lg.from].x), at(layout.stops[lg.to].x)
        l.line:ClearAllPoints()
        l.line:SetPoint("LEFT", ui.frame, "TOPLEFT", x1, -m.cy)
        l.line:SetWidth(x2 - x1)
        drawLine(l.line, lg.style == "solid" and "line-solid" or "line-dashed", x2 - x1, m.thick)
        l.line:Show()
        local dot = ns.Data.Art and ns.Data.Art["line-dot"]
        l.dot:ClearAllPoints()
        l.dot:SetPoint("CENTER", ui.frame, "TOPLEFT", at(lg.mid), -m.cy)
        l.dot:SetSize(m.thick, m.thick)
        if dot and l.dot:SetTexture(MEDIA .. dot.file) then
            l.dot:SetTexCoord(dot.l, dot.r, dot.t, dot.b)
            l.dot:Show()
        else
            l.dot:Hide()   -- decoration: the strip reads without it
        end
    end
    for i = #layout.legs + 1, #ui.strip.legs do
        ui.strip.legs[i].line:Hide()
        ui.strip.legs[i].dot:Hide()
    end
end
```

In `Planner.Refresh`, after `local routed = #steps > 0`, add:

```lua
    local g = geo()
    local layout
    if routed and g then
        local m = stripMetrics(g)
        layout = ns.Strip.Layout(ns.Data, steps, { faction = ns.Core.Faction(), level = plan.level,
                                                   trackWidth = m.right - m.left, badgeWidth = m.ring })
        drawStrip(layout, m)
    end
    ui.strip:SetShown(layout ~= nil)
```

and change the hint block so the warning comes first:

```lua
        -- One amber line under the strip. What the player must know first
        -- wins: a stop in a dangerous place, then a note about the route
        -- itself, then a flight path worth discovering.
        if layout and layout.warning then
            hint = layout.warning
        elseif notes ~= "" then
            hint = notes
        elseif plan.hint then
            hint = ns.Route.HintText(plan.hint)
        end
```

In `build()`, directly after the `backdrop` block, add:

```lua
    -- The route strip, a child of the screen so it draws over the screen's
    -- opaque fills and its scenery -- the invisible-backdrop fault was exactly
    -- a picture under an opaque panel. Its badges and legs are placed against
    -- the window, which has a real size, by drawStrip.
    local strip = CreateFrame("Frame", nil, screen)
    strip:SetAllPoints(screen)
    strip.badges, strip.legs = {}, {}
    strip:Hide()
```

and add `strip = strip` to the `ui` table.

- [ ] **Step 5: Run every gate**

Lua suite green (report the count; the new block adds 13). Python suite and
`check_art.py` green. luacheck and the language server from PowerShell at
zero warnings.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Planner.lua GoblinPS/Widgets.lua test/fake_frames.lua test/test_ui.lua
git commit -m "Planner: draw the route strip, a tooltip on every stop" -m "Each stop wears how you get there, joined by the glowing line: solid for the leg about to start, dashed after, tiled so a dash keeps its length, a dot mid-leg. Names give way to tooltips when crowded, the first amber detail becomes the warning under the strip, and a badge whose art fails still reads." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: look at it, and say what was built

**Files:**
- Modify: `CLAUDE.md`, `docs/manual-test-checklist.md`,
  `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`,
  `GoblinPS/GoblinPS.toc` (version)

- [ ] **Step 1: Composite the strip from the shipped art, and look at it**

This is the spec's "a composite of the strip from the real art at its
geometry, looked at". It is a verification, not a deliverable: write the
script in the session's scratchpad, not the repo. With Pillow, at 650x416:
paste `GoblinPS/Media/planner-frame-wide.tga` (cropped by its `Art.lua`
coordinates) full size; then, for a six-stop route (crest, ride, flight,
ride, zeppelin, signpost) and for an eleven-stop route, paste each badge TGA
scaled to 58.5 px centred at the positions Task 4's test computes, each leg's
`line-solid`/`line-dashed` TILED at 104x13 px from centre to centre, and
`line-dot` at 13 px mid-leg. Save both PNGs to the scratchpad and **look at
them** with the Read tool. Check: badges sit on the line's centre, the first
leg solid and the rest dashed, no dash bunched at a seam, the end badges clear
the brass, eleven stops fit without overlapping. Anything wrong is a Task 4
fix, found before the user's game time is spent on it. Record what you saw in
the ledger.

- [ ] **Step 2: The checklist**

In `docs/manual-test-checklist.md`, add a section after "A trip survives
everything except Stop (plan 7)":

```markdown
## The planner as designed (plan 8)

Needs a full game restart, not `/reload`: the TOC gained `Strip.lua`.

- [ ] `/gps` opens one wide window: one search box, the screen, Start Route.
      No From, no Here, no Wide/Tall button, no step list
- [ ] With nothing picked, the screen shows the two status lines and no strip
- [ ] Brill to Orgrimmar reads crest, boot or horseshoe, zeppelin, signpost;
      the first leg solid, the rest dashed, a glowing dot mid-leg; the badges
      sit on the line, not above or below it
- [ ] Hover each badge: the step, its time, and its detail line where it has
      one; a zeppelin says it includes the wait
- [ ] A long route (try a far city on the other continent) shows every stop;
      when they crowd, the names go and the tooltips still say everything
- [ ] A leg into a zone above your level: its tooltip detail is amber and the
      amber line under the strip names that stop; the line itself is not
      coloured and no badge changes (the skull is day 2)
- [ ] The total under the strip reads like "~15 min · free"
- [ ] Type in the box: the results list drops over the screen and the amber
      line stays visible under it
- [ ] Start Route closes the planner and opens the dash; `/gps` mid-trip
      shows the trip's destination in the box
- [ ] `/gps selftest` lists the fifteen strip textures, all `ok`
- [ ] Nothing reads past the brass or overlaps: names under the end badges
      stay on the glass
```

In the plan 2 "Planner window" section, and any line that names the tall
layout, From, Here or the step list, add one line under the section heading:
`Superseded by plan 8: the window has one box, one layout and no step list.`
Do not delete the history.

- [ ] **Step 3: `CLAUDE.md` and the spec**

- Status paragraph: "plans 1 to 7 are built" becomes "plans 1 to 8 are
  built"; replace the sentence beginning "Next: plan 8, the planner rebuilt
  to the mockup" through "is unaffected." with: "Plan 8, built 2026-09-21,
  rebuilt the planner to the mockup: one search box, the route strip drawn by
  the pure `Strip.lua`, a tooltip on every stop, wide only. **Plan 8 has not
  been run in the client.**"
- Layout block: add `GoblinPS/Strip.lua           # pure: the route strip as data -- badges, spacing, tooltips, solid/dashed legs`
  after the `Route.lua` line, and change the `Planner.lua` comment to
  `# the window; draws Strip.lua's layout and decides nothing; no coordinate
  is hand-typed here -- every position comes from ns.Data.ArtGeometry.planner.wide`.
- The spec's plan 8 heading gets a line under it: "Built 2026-09-21 -- not yet
  run in the client."

- [ ] **Step 4: Version**

`GoblinPS/GoblinPS.toc`: `## Version: 2026.09.21.5` becomes
`## Version: 2026.09.21.6` (or the next free number for the day).

- [ ] **Step 5: Run every gate, then commit**

All five gates green.

```
git add CLAUDE.md docs/manual-test-checklist.md docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md GoblinPS/GoblinPS.toc
git commit -m "Docs: plan 8 built, and what to walk in game" -m "The checklist gains the planner-as-designed section and marks the old two-box window superseded; CLAUDE.md names Strip.lua and says plan 8 has not been run in the client." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

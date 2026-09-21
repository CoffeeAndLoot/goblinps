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


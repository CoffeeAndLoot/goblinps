### Task 3: `Data/Stopovers.lua`, loaded and checked

**Files:**
- Create: `GoblinPS/Data/Stopovers.lua`
- Modify: `GoblinPS/GoblinPS.toc` (one line after `Data\Crossings.lua`)
- Modify: `test/run.lua` (module list)
- Test: `test/test_data.lua` (a new block before `h.describe("a real route", ...)`)

**Interfaces:**
- Consumes: `ns.Data.Places`.
- Produces: `ns.Data.Stopovers = { { name, map, mx, my, unverified? }, ... }`
  (empty), loaded in the client (TOC) and in `test/run.lua`'s shared `ns`.
  Nothing reads it until Task 4.

- [ ] **Step 1: Write the failing tests**

Insert into `test/test_data.lua` directly before

```lua
    h.describe("a real route", function()
```

this block:

```lua
    h.describe("the stopovers", function()
        -- The check returns what is wrong with the table, so it can be shown
        -- failing on planted rows: a check that cannot fail proves nothing,
        -- and Data/Stopovers.lua starts empty.
        local function badStopovers(stopovers)
            local bad = {}
            for i, s in ipairs(stopovers) do
                local onMap = data.Places[s.map] and s.mx and s.my and s.mx >= 0 and s.mx <= 1
                    and s.my >= 0 and s.my <= 1
                if not onMap or type(s.name) ~= "string" or s.name == "" or s.name:find(",", 1, true) then
                    bad[#bad + 1] = i .. " " .. tostring(s.name)
                end
            end
            return table.concat(bad, ", ")
        end

        h.it("puts every stopover on its own zone's map, under a name with no comma", function()
            h.truthy(data.Stopovers, "Data/Stopovers.lua is not loaded")
            h.eq(badStopovers(data.Stopovers), "")
        end)
        h.it("catches a stopover off its zone's map, on no zone, or with a comma in its name", function()
            h.eq(badStopovers({
                { name = "the road south of Silverwind Refuge", map = 1440, mx = 0.52, my = 0.70 },
                { name = "past the edge", map = 1440, mx = 1.2, my = 0.5 },
                { name = "on no map", map = 99999, mx = 0.5, my = 0.5 },
                { name = "a road, Ashenvale", map = 1440, mx = 0.5, my = 0.5 },
            }), "2 past the edge, 3 on no map, 4 a road, Ashenvale")
        end)
    end)
```

- [ ] **Step 2: Run the Lua gate to see them fail**

Expected: `478 passed, 1 failed`: "puts every stopover on its own zone's
map, under a name with no comma" (`Data/Stopovers.lua is not loaded, got
"nil"`). The planted-row check already passes: it proves the check can fail
before there is a row to check.

- [ ] **Step 3: Create `GoblinPS/Data/Stopovers.lua`**

```lua
-- HAND-WRITTEN. Named points inside one zone that a ride may pass through.
-- Inside a zone a ride leg is a straight line, and the router knows nothing
-- of roads, so a line between two points can run straight through an enemy
-- town (Graph.Hostile). A stopover gives it a way round: Graph.Build
-- joins it to every other point in its zone, like a tunnel's mouth, and the
-- router bends through it when that is quicker than the penalty.
--
--   { name = "...", map = <UiMap>, mx = 0.501, my = 0.662, unverified = true }
--     name   what the step says, "Ride to <name>": describe the way, and
--            include "the" ("the road south of Silverwind Refuge"). No comma:
--            everything after one is cut from the step.
--     map    the zone's UiMap ID (Data/Places.lua; /gps where prints it)
--     mx, my map coords (0..1). Stand on the spot and type /gps where: it
--            prints "Ashenvale (1440) 50.1, 66.2"; divide each by 100.
--     unverified = true   optional: placed from the map, not walked. The
--            step's detail line then says "stopover not confirmed".
--
-- test/test_data.lua checks every row sits on its zone's map.
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Stopovers = {
}
```

- [ ] **Step 4: Load it**

In `GoblinPS/GoblinPS.toc`, insert directly after the line `Data\Crossings.lua`
the line

```text
Data\Stopovers.lua
```

In `test/run.lua`, insert directly after

```lua
    { "Crossings", "GoblinPS/Data/Crossings.lua" },
```

the row

```lua
    { "Stopovers", "GoblinPS/Data/Stopovers.lua" },
```

- [ ] **Step 5: Run every gate**

Lua `479 passed, 0 failed`. Python `Ran 74 tests`, `OK`. Art green.
luacheck and the language server: zero warnings (luacheck now checks 45
files).

- [ ] **Step 6: Commit**

```
git add GoblinPS/Data/Stopovers.lua GoblinPS/GoblinPS.toc test/run.lua test/test_data.lua
git commit -m "Data/Stopovers.lua, hand-written and empty" -m "Named points a ride may bend through round an enemy town. It starts empty, with a header saying how to measure one with /gps where; the TOC and the test runner load it, and a data test checks every row sits on its zone's map under a name with no comma, shown failing on planted rows." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---


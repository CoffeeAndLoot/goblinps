### Task 2: The inn list

`GetBindLocation()` returns the inn's area name. Most match a flight stop or zone once a leading "The" is ignored (done already). Two kinds do not: inns beside a flight stop with a different name, and towns with an inn but no flight master (Brill, Razor Hill, Goldshire ...).

**Files:**
- Create: `GoblinPS/Data/Inns.lua`
- Modify: `GoblinPS/Search.lua`, `test/fake_world.lua`, `test/test_search.lua`, `test/test_data.lua`, `test/run.lua`, `GoblinPS/GoblinPS.toc`

**Interfaces:**
- Consumes: `Search.Exact(data, name, faction)`, `ns.Geo.ToWorld`.
- Produces: `ns.Data.Inns[bindName] = { stop = "<short flight stop name>" }` or `{ map, mx, my }`. `Search.Exact` returns the flight stop for the first kind, and for the second a place `{ kind = "inn", name, c, x, y, map, mx, my }`. `data.Inns` may be nil.

- [ ] **Step 1: Add inns to the fake world.** In `test/fake_world.lua`, insert immediately before the line `        Links = {`:

```lua
        Inns = {
            ["Delta Harbour Inn"] = { stop = "Delta" },                 -- an inn beside a flight stop
            ["Quiet Hollow"] = { map = 1, mx = 0.25, my = 0.5 },        -- a town with no flight master
            ["Nowhere Inn"] = { map = 99, mx = 0.5, my = 0.5 },         -- a map we do not have
        },
```

- [ ] **Step 2: Add the failing tests.** In `test/test_search.lua`, insert immediately before the line `        h.it("returns nil for an inn it does not know", function()`:

```lua
        h.it("follows an inn that stands beside a flight stop", function()
            h.eq(Search.Exact(world, "Delta Harbour Inn", "H").nodeID, 4)
        end)
        h.it("places an inn in a town with no flight master", function()
            local inn = Search.Exact(world, "quiet hollow", "H")
            h.eq(inn.kind, "inn")
            h.eq(inn.name, "Quiet Hollow")
            h.eq(inn.c, 1)
            h.eq(inn.x, 5000)
            h.eq(inn.y, 7500)
        end)
        h.it("returns nil for an inn on a map we do not have", function()
            h.eq(Search.Exact(world, "Nowhere Inn", "H"), nil)
        end)
```

In `test/test_data.lua`, insert immediately before the line `    h.describe("a real route", function()`:

```lua
    h.describe("the inn list", function()
        h.it("resolves every row for the faction that can use it", function()
            for bind in pairs(data.Inns) do
                local found = ns.Search.Exact(data, bind, "H") or ns.Search.Exact(data, bind, "A")
                h.truthy(found, bind .. " does not resolve")
            end
        end)
        h.it("only lists names Search cannot already find", function()
            local without = {}
            for k, v in pairs(data) do
                without[k] = v
            end
            without.Inns = nil
            for bind in pairs(data.Inns) do
                h.falsy(ns.Search.Exact(without, bind, nil), bind .. " already resolves; drop the row")
            end
        end)
        h.it("finds the binds met in game", function()
            h.eq(ns.Search.Exact(data, "The Crossroads", "H").nodeID, 25)
            h.eq(ns.Search.Exact(data, "Brill", "H").kind, "inn")
        end)
    end)

```

In `test/run.lua`, add the module line `    { "Inns",    "GoblinPS/Data/Inns.lua" },` directly after the `Links` line.

- [ ] **Step 3: Run the Lua tests.** Expected: failures in the two new Search tests that expect a match, and in all three inn-list data tests (`data.Inns` is nil).

- [ ] **Step 4: Change `Search.Exact` in `GoblinPS/Search.lua`.** Replace

```lua
    local best
    for _, item in ipairs(candidates(data, faction)) do
```

with

```lua
    local best
    for bind, inn in pairs(data.Inns or {}) do
        if plain(bind) == needle then
            if inn.stop then
                return Search.Exact(data, inn.stop, faction)
            end
            local c, x, y = ns.Geo.ToWorld(data.Places, inn.map, inn.mx, inn.my)
            if c then
                return { kind = "inn", name = bind, c = c, x = x, y = y, map = inn.map, mx = inn.mx, my = inn.my }
            end
        end
    end
    for _, item in ipairs(candidates(data, faction)) do
```

- [ ] **Step 5: Write `GoblinPS/Data/Inns.lua`**

```lua
-- HAND-WRITTEN. Hearthstone bind names that Search cannot find by itself.
-- GetBindLocation() returns the inn's area name. Most match a flight stop or
-- a zone once a leading "The" is ignored ("The Crossroads" -> Crossroads).
-- These do not:
--   stop = "<short flight stop name>"  the inn stands beside that flight stop
--   map, mx, my                        a town with an inn and no flight master;
--                                      map coords (0..1), APPROXIMATE until
--                                      checked from docs/manual-test-checklist.md
-- Add a row whenever the addon prints "Hearth: unknown inn (...)".
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Inns = {
    ["Grom'gol Base Camp"]     = { stop = "Grom'gol" },
    ["Theramore Isle"]         = { stop = "Theramore" },
    ["Feathermoon Stronghold"] = { stop = "Feathermoon" },

    ["Razor Hill"]        = { map = 1411, mx = 0.515, my = 0.416 }, -- Durotar
    ["Bloodhoof Village"] = { map = 1412, mx = 0.466, my = 0.611 }, -- Mulgore
    ["Brill"]             = { map = 1420, mx = 0.617, my = 0.520 }, -- Tirisfal Glades
    ["Goldshire"]         = { map = 1429, mx = 0.438, my = 0.658 }, -- Elwynn Forest
    ["Kharanos"]          = { map = 1426, mx = 0.474, my = 0.525 }, -- Dun Morogh
    ["Dolanaar"]          = { map = 1438, mx = 0.556, my = 0.598 }, -- Teldrassil
}
```

- [ ] **Step 6: Load it in the addon.** In `GoblinPS/GoblinPS.toc` add the line `Data\Inns.lua` directly after `Data\Links.lua`.

- [ ] **Step 7: Run the Lua tests.** Expected: `79 passed, 0 failed`. Run luacheck: `0 warnings / 0 errors`.

- [ ] **Step 8: Commit**

```
git add GoblinPS/Data/Inns.lua GoblinPS/Search.lua GoblinPS/GoblinPS.toc test/fake_world.lua test/test_search.lua test/test_data.lua test/run.lua
git commit -m "Add the inn list for hearthstone binds" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---


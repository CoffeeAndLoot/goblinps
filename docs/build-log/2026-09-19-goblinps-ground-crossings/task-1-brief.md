### Task 1: `Travel`

**Files:**
- Create: `GoblinPS/Travel.lua`, `test/test_travel.lua`
- Replace: `test/run.lua`

**Interfaces:**
- Produces: `ns.Travel.For(level) -> { speed, walk }` (nil level means on foot); `ns.Travel.Dangerous(range, level) -> bool`; settings `Travel.WALK_YARDS_PER_SECOND`, `Travel.MOUNTS` (list of `{ level, yardsPerSecond }`, lowest first), `Travel.WARN_LEVELS_ABOVE`.

- [ ] **Step 1: Replace `test/run.lua`** (it lists every module and suite of this plan and skips files that do not exist yet)

```lua
-- Run from the repository root through lupa (see CLAUDE.md).
local harness = dofile("test/harness.lua")

-- Same (addonName, ns) the client passes, loaded in TOC order into one ns.
-- API.lua and Core.lua touch Blizzard globals, so they are not loaded here.
local modules = {
    { "Geo",     "GoblinPS/Geo.lua" },
    { "Places",  "GoblinPS/Data/Places.lua" },
    { "Nodes",   "GoblinPS/Data/Nodes.lua" },
    { "Flights", "GoblinPS/Data/Flights.lua" },
    { "Links",   "GoblinPS/Data/Links.lua" },
    { "Inns",    "GoblinPS/Data/Inns.lua" },
    { "Crossings", "GoblinPS/Data/Crossings.lua" },
    { "Zones",   "GoblinPS/Data/Zones.lua" },
    { "Travel",  "GoblinPS/Travel.lua" },
    { "Search",  "GoblinPS/Search.lua" },
    { "Graph",   "GoblinPS/Graph.lua" },
    { "Route",   "GoblinPS/Route.lua" },
    { "Trip",    "GoblinPS/Trip.lua" },
    { "Known",   "GoblinPS/Known.lua" },
    { "Prefs",   "GoblinPS/Prefs.lua" },
}

local ns = {}
local loaded = { ns = ns }
for i = 1, #modules do
    local name, path = modules[i][1], modules[i][2]
    local f = io.open(path, "r")
    if f then
        f:close()
        loaded[name] = assert(loadfile(path))("GoblinPS", ns)
    end
end

local suites = {
    "test/test_geo.lua",
    "test/test_search.lua",
    "test/test_graph.lua",
    "test/test_route.lua",
    "test/test_trip.lua",
    "test/test_known.lua",
    "test/test_prefs.lua",
    "test/test_travel.lua",
    "test/test_crossings.lua",
    "test/test_ui.lua",
    "test/test_data.lua",
}

for i = 1, #suites do
    local f = io.open(suites[i], "r")
    if f then
        f:close()
        dofile(suites[i])(harness, loaded)
    end
end

os.exit(harness.run())
```

- [ ] **Step 2: Write the failing test `test/test_travel.lua`**

```lua
return function(h, loaded)
    local Travel = loaded.ns.Travel

    h.describe("Travel.For", function()
        h.it("walks below the first mount level", function()
            local t = Travel.For(1)
            h.eq(t.speed, Travel.WALK_YARDS_PER_SECOND)
            h.eq(t.walk, true)
        end)
        h.it("rides the first mount from its level", function()
            local first = Travel.MOUNTS[1]
            h.eq(Travel.For(first.level - 1).walk, true)
            h.eq(Travel.For(first.level).walk, false)
            h.eq(Travel.For(first.level).speed, first.yardsPerSecond)
        end)
        h.it("rides the fastest mount the level allows", function()
            local last = Travel.MOUNTS[#Travel.MOUNTS]
            h.eq(Travel.For(last.level).speed, last.yardsPerSecond)
            h.eq(Travel.For(last.level + 10).speed, last.yardsPerSecond)
        end)
        h.it("treats an unknown level as on foot", function()
            h.eq(Travel.For(nil).walk, true)
        end)
        h.it("follows the settings, so the definitive numbers are a two-line change", function()
            local saved = Travel.MOUNTS
            Travel.MOUNTS = { { level = 20, yardsPerSecond = 9 } }
            h.eq(Travel.For(20).speed, 9)
            h.eq(Travel.For(19).walk, true)
            Travel.MOUNTS = saved
        end)
    end)

    h.describe("Travel.Dangerous", function()
        h.it("warns when the zone starts well above the character", function()
            h.eq(Travel.Dangerous({ 48, 55 }, 1), true)
            h.eq(Travel.Dangerous({ 10, 25 }, 1), true)
        end)
        h.it("does not warn inside the margin", function()
            h.eq(Travel.Dangerous({ 10, 25 }, 10 - Travel.WARN_LEVELS_ABOVE), false)
            h.eq(Travel.Dangerous({ 1, 10 }, 1), false)
            h.eq(Travel.Dangerous({ 48, 55 }, 60), false)
        end)
        h.it("never warns without a range or a level", function()
            h.eq(Travel.Dangerous(nil, 5), false)
            h.eq(Travel.Dangerous({ 48, 55 }, nil), false)
        end)
    end)
end
```

- [ ] **Step 3: Run the Lua tests.** Expected: the eight new tests fail (`Travel` is nil); the other 122 pass.

- [ ] **Step 4: Write `GoblinPS/Travel.lua`**

```lua
local _, ns = ...

-- Pure: how fast this character covers ground, and the settings behind it.
-- THE NUMBERS ARE NOT CONFIRMED for WoW Forever: the mount levels come from
-- press coverage. They live here, in one place, so the definitive answer is a
-- two-line change. Level stands in for "has a mount" on purpose: the riding
-- skill and mount list APIs are unverified on this client.
local Travel = {}
ns.Travel = Travel

Travel.WALK_YARDS_PER_SECOND = 7
Travel.MOUNTS = {               -- lowest level first
    { level = 40, yardsPerSecond = 11.2 }, -- a 60% mount
    { level = 60, yardsPerSecond = 14 },   -- a 100% mount
}
Travel.WARN_LEVELS_ABOVE = 5    -- a zone that starts this far above you gets an amber warning

-- level nil (unknown) is treated as on foot: the safe, slower guess.
-- Returns { speed = yards per second, walk = true when on foot }.
function Travel.For(level)
    local speed, walk = Travel.WALK_YARDS_PER_SECOND, true
    for _, mount in ipairs(Travel.MOUNTS) do
        if level and level >= mount.level then
            speed, walk = mount.yardsPerSecond, false
        end
    end
    return { speed = speed, walk = walk }
end

-- Is a zone with this { low, high } range dangerous for this level?
function Travel.Dangerous(range, level)
    if not range or not level then
        return false
    end
    return range[1] > level + Travel.WARN_LEVELS_ABOVE
end

return Travel
```

- [ ] **Step 5: Run the Lua tests.** Expected: `130 passed, 0 failed`. luacheck: `0 warnings / 0 errors`.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Travel.lua test/test_travel.lua test/run.lua
git commit -m "Add travel settings: walk or ride by level" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---


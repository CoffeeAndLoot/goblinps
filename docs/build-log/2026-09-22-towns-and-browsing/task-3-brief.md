### Task 3: Search offers towns, and never one place twice

**Files:**
- Modify: `GoblinPS/Search.lua` (header comment, `fromTown`, `plain` moved up,
  `Search.Candidates`, `before`)
- Modify: `GoblinPS/Data/Inns.lua` (header comment only)
- Modify: `test/test_search.lua` (two new blocks)
- Modify: `test/test_data.lua` (the inn guard, the fallback list, one test in
  "the towns table", a "no place offered twice" block)
- Modify: `test/test_crossings.lua` ("leaves a city by its gate")

**Interfaces:**
- Consumes: `ns.Data.Towns` (Task 2) or none (`data.Towns` may be nil: the fake
  world has none).
- Produces: `Search.Candidates(data, faction)` rows gain kind `"town"` rows
  from `data.Towns` with `townID = <poi id>` and `enemy = "A"|"H"|nil` from
  the inferred faction; enemy stops that share a short name with a usable stop
  are gone; a generated town whose plain name is an `Inns` key is gone.
  `before` orders same-named towns by `townID`. Tasks 4 and 5 rely on
  `Search.Candidates` and on the item fields `kind, name, zone, map, enemy,
  townID, nodeID`.

- [ ] **Step 1: Write the failing tests**

In `test/test_search.lua`, directly after the `end)` that closes
`h.describe("Search.Find", ...)` and before `h.describe("Search.Candidates", ...)`,
add:

```lua
    h.describe("generated towns", function()
        -- The fake world with a towns table shaped as tools/build_graph.py
        -- emits Data/Towns.lua. Map coords and world coords are one point.
        local function withTowns()
            local w = dofile("test/fake_world.lua")()
            w.Towns = {
                [101] = { name = "Mike", map = 1, mx = 0.3, my = 0.3, c = 1, x = 7000, y = 7000 },
                [102] = { name = "November", map = 4, mx = 0.6, my = 0.6, c = 1, x = 4000, y = 4000, f = "A" },
                -- The game's own label for the hand-written inn town, 100 yards off it.
                [103] = { name = "Quiet Hollow", map = 1, mx = 0.26, my = 0.5, c = 1, x = 5000, y = 7400 },
                -- In Lostland, which held nothing until now.
                [104] = { name = "Oscar", map = 5, mx = 0.5, my = 0.5, c = 1, x = 5000, y = 5000, f = "H" },
            }
            return w
        end

        h.it("offers a town as a place of kind town, in its zone", function()
            local mike = Search.Find(withTowns(), "mike", "H")[1]
            h.eq(mike.kind, "town")
            h.eq(mike.townID, 101)
            h.eq(mike.name, "Mike")
            h.eq(mike.zone, "Westland")
            h.eq(mike.enemy, nil, "a town with no inferred faction is nobody's enemy")
            h.eq(mike.map, 1)
            h.eq(mike.x, 7000)
            h.eq(mike.y, 7000)
        end)
        h.it("marks a town with the other faction's inferred faction", function()
            local w = withTowns()
            h.eq(Search.Find(w, "november", "H")[1].enemy, "A")
            h.eq(Search.Find(w, "november", "A")[1].enemy, nil, "an Alliance town is no enemy to the Alliance")
            h.eq(Search.Find(w, "oscar", "A")[1].enemy, "H")
        end)
        h.it("lets the hand-written inn town win over the game's town of its name", function()
            local found = Search.Find(withTowns(), "quiet", "H")
            h.eq(#found, 1, "one Quiet Hollow, not two")
            h.eq(found[1].townID, nil, "the inn row's")
            h.eq(found[1].y, 7500, "at the inn row's own position")
        end)
        h.it("takes a zone off the list once a town stands in it", function()
            local w = withTowns()
            local count = { stop = 0, town = 0, zone = 0 }
            for _, item in ipairs(Search.Candidates(w, "H")) do
                count[item.kind] = count[item.kind] + 1
            end
            h.eq(count.stop, 8)
            h.eq(count.town, 6, "three inn towns and Mike, November and Oscar")
            h.eq(count.zone, 0, "Oscar stands in Lostland")
            h.eq(Search.Exact(w, "Lostland", "H"), nil)
            h.eq(Search.Exact(w, "Oscar", "H").map, 5)
        end)
    end)

    h.describe("two stops of one name", function()
        -- Booty Bay, Gadgetzan and Everlook each have one stop per faction, a
        -- few yards apart. Kilo is that town. The enemy's stop is on the LOWER
        -- ID, so a tie broken by ID alone would pick the one you cannot use.
        local function withTwins()
            local w = dofile("test/fake_world.lua")()
            w.Nodes[11] = { name = "Kilo, Westland", f = "A", c = 1, x = 3000, y = 3000, map = 1, mx = 0.7, my = 0.7 }
            w.Nodes[12] = { name = "Kilo, Westland", f = "H", c = 1, x = 3010, y = 3010,
                            map = 1, mx = 0.699, my = 0.699 }
            return w
        end

        h.it("offers only the stop this faction may use", function()
            local w = withTwins()
            local horde = Search.Find(w, "kilo", "H")
            h.eq(#horde, 1, "the Alliance's Kilo is not offered to the Horde")
            h.eq(horde[1].nodeID, 12)
            h.eq(horde[1].enemy, nil)
            local alliance = Search.Find(w, "kilo", "A")
            h.eq(#alliance, 1)
            h.eq(alliance[1].nodeID, 11)
        end)
        h.it("still offers an enemy stop that has no twin of your own", function()
            local echo = Search.Find(withTwins(), "echo", "H")
            h.eq(#echo, 1)
            h.eq(echo[1].enemy, "A")
        end)
        h.it("pins the tie: the stop you may use wins, though the enemy's ID is lower", function()
            local w = withTwins()
            h.eq(Search.Exact(w, "Kilo", "H").nodeID, 12)
            h.eq(Search.Exact(w, "Kilo", "A").nodeID, 11)
            local any = Search.Find(w, "kilo")
            h.eq(#any, 2, "with no faction, neither is an enemy, so both are offered")
            h.eq(any[1].nodeID, 11, "and the lower ID comes first")
            h.eq(Search.Exact(w, "Kilo").nodeID, 11)
        end)
    end)

```

In `test/test_data.lua`:

1. In "only lists names Search cannot already find", replace

```lua
        h.it("only lists names Search cannot already find", function()
            local without = {}
            for k, v in pairs(data) do
                without[k] = v
            end
            without.Inns = nil
```

with

```lua
        h.it("only lists names Search cannot already find", function()
            -- Without the generated towns too: a row that names one of them
            -- still earns its place, because hand-written data wins -- it
            -- says what the name is ("Theramore Isle" is the Theramore stop,
            -- "Kharanos" the inn town) and keeps the town from being offered
            -- a second time.
            local without = {}
            for k, v in pairs(data) do
                without[k] = v
            end
            without.Inns, without.Towns = nil, nil
```

2. Change the fallback-zone expectation
`h.eq(table.concat(zones, ", "), "Alterac Mountains, Darnassus, Deadwind Pass, Shen'dralas")`
to `h.eq(table.concat(zones, ", "), "Alterac Mountains, Shen'dralas")`.

3. At the end of `h.describe("the towns table", ...)` (Task 2's block, after
"never repeats a flight stop in the stop's own zone"), add:

```lua
        h.it("makes Darnassus, Kharanos and Sentinel Hill places, not zones", function()
            for _, name in ipairs({ "Darnassus", "Kharanos", "Sentinel Hill" }) do
                for _, faction in ipairs({ "A", "H" }) do
                    local place = ns.Search.Exact(data, name, faction)
                    h.truthy(place, name .. " cannot be found by the " .. faction)
                    h.truthy(place.kind ~= "zone", name .. " is still only a zone")
                end
            end
            h.eq(ns.Search.Exact(data, "Darnassus", "H").enemy, "A", "a capital takes its own flight stop's faction")
            h.eq(ns.Search.Exact(data, "Sentinel Hill", "H").nodeID, 4, "the stop, not a town beside it")
        end)
```

4. Directly before `h.describe("a real route", function()`, add:

```lua
    h.describe("no place offered twice", function()
        -- Stronger than "no two of one name within 300 yards": two rows with
        -- one name and one zone would read the same at any distance. The two
        -- ends of a tunnel share a name 217 yards apart (Timbermaw Hold) but
        -- not a zone, and are two places.
        h.it("never offers two rows that read the same", function()
            for _, faction in ipairs({ "A", "H" }) do
                local seen, rows = {}, 0
                for _, item in ipairs(ns.Search.Candidates(data, faction)) do
                    local label = item.name .. " @ " .. tostring(item.zone)
                    h.falsy(seen[label], faction .. ": " .. label .. " is offered twice")
                    seen[label] = true
                    rows = rows + 1
                end
                h.truthy(rows > 200, "a check that saw no rows proves nothing")
            end
        end)
        h.it("hides the other faction's stop where one of your own has its name", function()
            for _, name in ipairs({ "Booty Bay", "Gadgetzan", "Everlook" }) do
                local found = ns.Search.Find(data, name, "H")
                h.eq(found[1].name, name)
                h.eq(found[1].enemy, nil, name .. ": the Horde's own stop")
                h.truthy(not found[2] or found[2].name ~= name, name .. " is offered twice to the Horde")
            end
        end)
    end)

```

In `test/test_crossings.lua`, in "leaves a city by its gate", replace

```lua
            local r = ns.Route.Plan(data, { faction = "A", known = {}, from = place("Stormwind City", "A"),
                                            to = place("Westfall", "A") })
```

with

```lua
            -- Sentinel Hill by name: "Westfall" alone now finds Moonbrook first, a
            -- town off the road, and this test is about the gate, not the town.
            local r = ns.Route.Plan(data, { faction = "A", known = {}, from = place("Stormwind City", "A"),
                                            to = place("Sentinel Hill", "A") })
```

- [ ] **Step 2: Run the Lua gate to see them fail**

Expected: `448 passed, 8 failed`. Failing: "offers a town as a place of kind
town, in its zone", "marks a town with the other faction's inferred
faction", "takes a zone off the list once a town stands in it", "offers only
the stop this faction may use", "offers a zone only where it holds no stop and
no inn town, and these are all of them" (still four zones), "makes
Darnassus, Kharanos and Sentinel Hill places, not zones" (Darnassus is a
zone), "never offers two rows that read the same" and "hides the other
faction's stop where one of your own has its name" (Booty Bay twice).
Passing already, and pinned from here on: "lets the hand-written inn town
win" (towns are not read yet), "still offers an enemy stop that has no twin"
and "pins the tie" (`before` already puts a usable stop first). The changed
inn guard and the crossings test pass both ways.

- [ ] **Step 3: `GoblinPS/Search.lua`**

Replace the header comment

```lua
-- Pure lookup of destinations by name: flight stops, inn towns, and a zone
-- only when it holds neither.
```

with

```lua
-- Pure lookup of destinations by name: flight stops, towns (the game's own
-- AreaPOI table, Data/Towns.lua), hand-written inn towns, and a zone only
-- when it holds none of these.
```

Directly after `fromInn`'s closing `end`, add:

```lua
-- A generated town. Its faction is inferred (tools/build_graph.py) and often
-- absent; a town with none is nobody's enemy.
local function fromTown(data, id, t, faction)
    return { kind = "town", townID = id, name = t.name, zone = zoneOf(data, t.map),
             enemy = t.f and not legal(t, faction) and t.f or nil,
             c = t.c, x = t.x, y = t.y, map = t.map, mx = t.mx, my = t.my }
end

-- The game says "The Crossroads" where the flight stop is "Crossroads".
local function plain(name)
    return ((name or ""):lower():gsub("^the%s+", ""))
end
```

and **delete** the same `plain` function (with its comment) from its old place
directly above the `Search.Exact` comment, so it is defined once, above its
first use.

Replace the whole of `Search.Candidates` and the comment above it with:

```lua
-- Every destination the search can offer: every flight stop, the other
-- faction's marked enemy (faction nil means none is), every town and every
-- inn town. A zone is offered only when it holds none of these, so that no
-- zone is out of reach; one that holds a place is only a search word,
-- because a zone destination routes to its border. The planner measures its
-- drop-down over this.
--
-- Two rows are never one place. An enemy stop that shares its name with a
-- stop this faction may use (Booty Bay, Gadgetzan, Everlook) is left out:
-- the usable one is the same town. A generated town whose name is a
-- hand-written inn row's is left out too: the hand-written row says what
-- that name is, whether a stop ("Theramore Isle") or an inn town
-- ("Kharanos"). The generator has already dropped every town that shares a
-- name and a zone with a flight stop.
function Search.Candidates(data, faction)
    local list, held, usable, written = {}, {}, {}, {}
    for _, n in pairs(data.Nodes) do
        if legal(n, faction) then
            usable[Search.ShortName(n.name)] = true
        end
    end
    for id, n in pairs(data.Nodes) do
        if legal(n, faction) or not usable[Search.ShortName(n.name)] then
            list[#list + 1] = fromNode(data, id, n, faction)
        end
    end
    for bind, inn in pairs(data.Inns or {}) do
        written[plain(bind)] = true
        list[#list + 1] = fromInn(data, bind, inn)
    end
    for id, t in pairs(data.Towns or {}) do
        if not written[plain(t.name)] then
            list[#list + 1] = fromTown(data, id, t, faction)
        end
    end
    for _, item in ipairs(list) do
        held[item.map] = true
    end
    for map, p in pairs(data.Places) do
        if not held[map] then
            list[#list + 1] = fromZone(data, map, p)
        end
    end
    return list
end
```

Replace `before` and its comment with:

```lua
-- Which of two same-named places comes first: a place this faction may use,
-- then a stop, then a town, then a zone; among stops the lowest nodeID, among
-- towns the lowest townID (the two ends of a tunnel share a name).
local ORDER = { stop = 1, town = 2, zone = 3 }
local function before(a, b)
    local aEnemy, bEnemy = a.enemy ~= nil, b.enemy ~= nil
    if aEnemy ~= bEnemy then return bEnemy end
    if a.kind ~= b.kind then return ORDER[a.kind] < ORDER[b.kind] end
    return (a.nodeID or a.townID or 0) < (b.nodeID or b.townID or 0)
end
```

- [ ] **Step 4: `GoblinPS/Data/Inns.lua`, the header comment**

Replace

```lua
--                                      A town is also a destination the planner
--                                      offers, as "<name> · <zone>".
```

with

```lua
--                                      A town is also a destination the planner
--                                      offers, as "<name> · <zone>". It wins
--                                      over the game's own town of its name
--                                      (Data/Towns.lua), which is not offered.
```

and after the line `-- Add a row whenever the addon prints "Hearth: unknown inn (...)".`
add:

```lua
-- Every row here wins by name over a generated town: "Theramore Isle" is the
-- Theramore stop, and the game's own Theramore Isle label is not offered too.
```

(No row changes. Their positions stay the inn's own: the hearthstone lands
there, and each is within 84 yards of its town's label.)

- [ ] **Step 5: Run every gate**

Lua: `456 passed, 0 failed` (446 + 7 in `test_search.lua` + 3 in
`test_data.lua`). Python `Ran 70 tests`, `OK`. Art green. luacheck and the
language server from PowerShell: zero warnings.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Search.lua GoblinPS/Data/Inns.lua test/test_search.lua test/test_data.lua test/test_crossings.lua
git commit -m "Search: towns are places, and no place is offered twice" -m "Candidates offers every generated town beside the stops and the inn rows, marked with its inferred faction when that is the other side's. An enemy stop whose name a usable stop shares is not offered, a generated town whose name is a hand-written inn row's gives way to that row, and same-named towns order by ID. Darnassus is a place now; only Alterac Mountains and Shen'dralas are still offered as zones." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---


### Task 1: A zone destination is reached anywhere inside the zone

Seen in game: bound at the Crossroads inn, `/gps to barrens` printed "Hearthstone to Crossroads" then a pointless "Ride to The Barrens", because a zone destination aimed at the zone's centre.

**Files:**
- Modify: `GoblinPS/Graph.lua`, `test/test_route.lua`

**Interfaces:**
- Consumes: `opts.to.kind` and `opts.to.map` (places from `Search.Find` carry `kind = "zone"` and the zone's `map`); every stop carries `map`.
- Produces: no new names. When `opts.to.kind == "zone"`, a ride from a place whose `map` equals `opts.to.map` to `DEST` costs 0 seconds; `Route` already drops rides under 5 seconds. A route with zero steps means "already there" (`Core` prints that).

- [ ] **Step 1: Add the failing tests.** In `test/test_route.lua`, insert this block immediately before the line `    h.describe("Route.Hint", function()`:

```lua
    h.describe("a zone destination", function()
        local westland = loaded.ns.Search.Find(world, "westland", "H", 1)[1]
        h.it("is reached at the first stop inside the zone", function()
            local r = Route.Plan(world, { faction = "H", known = { [4] = true }, from = nearDelta, to = westland })
            h.eq(kinds(r), "ride,zeppelin")
            h.eq(r.steps[2].to.key, "west_dock")
        end)
        h.it("has no steps when you already stand in it", function()
            local inWestland = { name = "You", c = 1, x = 1000, y = 1100, map = 1, mx = 0.89, my = 0.9 }
            local r = Route.Plan(world, { faction = "H", known = {}, from = inWestland, to = westland })
            h.eq(#r.steps, 0)
        end)
        h.it("still rides to an exact stop in that zone", function()
            local charlie = loaded.ns.Search.Find(world, "charlie", "H", 1)[1]
            local inWestland = { name = "You", c = 1, x = 1000, y = 1100, map = 1, mx = 0.89, my = 0.9 }
            local r = Route.Plan(world, { faction = "H", known = {}, from = inWestland, to = charlie })
            h.eq(kinds(r), "ride")
        end)
    end)

```

- [ ] **Step 2: Run the Lua tests.** Expected: `71 passed, 2 failed`; the first two new tests fail (`ride,zeppelin,ride` and `1` step).

- [ ] **Step 3: Change `GoblinPS/Graph.lua`.** Three edits inside `Graph.Build`.

Replace

```lua
    stops.START = stopFrom("START", opts.from)
    stops.DEST = stopFrom("DEST", opts.to)
```

with

```lua
    stops.START = stopFrom("START", opts.from)
    stops.DEST = stopFrom("DEST", opts.to)

    -- A zone destination means "anywhere in the zone": a place already on the
    -- zone's map has arrived, so its ride to DEST costs nothing (and Route
    -- drops a ride that short). A stop or an exact spot is ridden to as usual.
    local zoneMap = opts.to.kind == "zone" and opts.to.map or nil
    local function toDest(place)
        if zoneMap and place.map == zoneMap then
            return 0
        end
        return Graph.RideSeconds(place, stops.DEST)
    end
```

Replace `addEdge(edges, origin.key, "DEST", "ride", Graph.RideSeconds(origin, stops.DEST))` with `addEdge(edges, origin.key, "DEST", "ride", toDest(origin))`.

Replace `addEdge(edges, key, "DEST", "ride", Graph.RideSeconds(stops[key], stops.DEST))` with `addEdge(edges, key, "DEST", "ride", toDest(stops[key]))`.

- [ ] **Step 4: Run the Lua tests.** Expected: `73 passed, 0 failed`. Run luacheck: `0 warnings / 0 errors`.

- [ ] **Step 5: Commit**

```
git add GoblinPS/Graph.lua test/test_route.lua
git commit -m "Reach a zone destination at any stop inside the zone" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---


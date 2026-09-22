### Task 2: `Geo.SegmentDistance`

**Files:**
- Modify: `GoblinPS/Geo.lua` (after `Geo.Distance`, line 24)
- Test: `test/test_geo.lua` (a new block before `h.describe("Geo.Nearest", ...)`)

**Interfaces:**
- Consumes: world positions `{ c, x, y }`, as `Geo.Distance` takes them.
- Produces: `Geo.SegmentDistance(a, b, p) -> number`: yards from `p` to the
  segment `a`-`b`, `math.huge` unless all three are given and on one
  continent. Task 4's `dangerOn` calls it.

- [ ] **Step 1: Write the failing tests**

Insert into `test/test_geo.lua` directly before

```lua
    h.describe("Geo.Nearest", function()
```

this block:

```lua
    h.describe("Geo.SegmentDistance", function()
        -- A leg 100 yards long along x, on continent 1.
        local a, b = { c = 1, x = 0, y = 0 }, { c = 1, x = 100, y = 0 }
        local function near(got, want) return math.abs(got - want) < 0.001 end

        h.it("is zero at either end", function()
            h.eq(Geo.SegmentDistance(a, b, { c = 1, x = 0, y = 0 }), 0)
            h.eq(Geo.SegmentDistance(a, b, { c = 1, x = 100, y = 0 }), 0)
        end)
        h.it("measures square to the leg in the middle", function()
            h.truthy(near(Geo.SegmentDistance(a, b, { c = 1, x = 50, y = 30 }), 30))
            h.truthy(near(Geo.SegmentDistance(a, b, { c = 1, x = 25, y = -40 }), 40), "either side")
        end)
        h.it("measures to the nearer end past either end, not to the line beyond it", function()
            h.truthy(near(Geo.SegmentDistance(a, b, { c = 1, x = -30, y = 40 }), 50), "before a")
            h.truthy(near(Geo.SegmentDistance(a, b, { c = 1, x = 130, y = 40 }), 50), "past b")
        end)
        h.it("treats a leg of no length as a point", function()
            h.truthy(near(Geo.SegmentDistance(a, a, { c = 1, x = 3, y = 4 }), 5))
        end)
        h.it("is infinite off the leg's continent or with a position missing", function()
            h.eq(Geo.SegmentDistance(a, b, { c = 0, x = 50, y = 0 }), math.huge)
            h.eq(Geo.SegmentDistance(a, { c = 0, x = 100, y = 0 }, { c = 1, x = 50, y = 0 }), math.huge)
            h.eq(Geo.SegmentDistance(a, b, nil), math.huge)
        end)
    end)
```

- [ ] **Step 2: Run the Lua gate to see them fail**

Expected: `472 passed, 5 failed`, all five in `Geo.SegmentDistance`, each
`attempt to call field 'SegmentDistance' (a nil value)`.

- [ ] **Step 3: Write `Geo.SegmentDistance`**

Insert into `GoblinPS/Geo.lua` directly after

```lua
    return math.sqrt(dx * dx + dy * dy)
end
```

(the end of `Geo.Distance`) a blank line and:

```lua
-- Yards from world position p to the straight segment a-b; math.huge unless
-- all three are on one continent. A ride leg is a straight line, so this is
-- how close one passes to a place.
function Geo.SegmentDistance(a, b, p)
    if not a or not b or not p or a.c ~= b.c or a.c ~= p.c then
        return math.huge
    end
    local dx, dy = b.x - a.x, b.y - a.y
    local t, length2 = 0, dx * dx + dy * dy
    if length2 > 0 then
        t = math.max(0, math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length2))
    end
    local ex, ey = a.x + t * dx - p.x, a.y + t * dy - p.y
    return math.sqrt(ex * ex + ey * ey)
end
```

- [ ] **Step 4: Run every gate**

Lua `477 passed, 0 failed`. Python `Ran 74 tests`, `OK`. Art green.
luacheck and the language server: zero warnings.

- [ ] **Step 5: Commit**

```
git add GoblinPS/Geo.lua test/test_geo.lua
git commit -m "Geo.SegmentDistance: how close a straight leg passes a point" -m "Yards from a point to a segment, measured to the nearer end past either end and to a point for a leg of no length; infinite off the leg's continent or with a position missing. The router's ride legs are straight lines, so this is how the graph will tell which ones pass an enemy town." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---


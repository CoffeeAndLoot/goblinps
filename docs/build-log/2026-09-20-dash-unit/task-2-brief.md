### Task 2: Bearing, distance and time left

**Files:**
- Modify: `GoblinPS/Trip.lua`
- Test: `test/test_trip.lua`

**Interfaces:**
- Consumes: `ns.Geo.Distance(a, b)`; world positions shaped `{ c, x, y }`.
- Produces, all pure:
  - `Trip.Bearing(from, to)` returns radians, or nil when either is missing, they are on different continents, or they are the same point.
  - `Trip.ArrowAngle(bearing, facing)` returns radians to pass to `texture:SetRotation`, or nil when either input is nil.
  - `Trip.DistanceTo(pos, step)` returns yards, or nil.
  - `Trip.Remaining(result, index, pos, speed)` returns seconds left for the whole journey, or nil.

The coordinate facts this rests on, so nobody has to rediscover them:

- `Geo.ToWorld` gives `wx = x1 - my * (x1 - x0)` and `wy = y1 - mx * (y1 - y0)`. So **world x increases north and world y increases west**, which is Blizzard's own world convention.
- `GetPlayerFacing()` returns radians with **0 = north, increasing counter-clockwise**, the same frame.
- Therefore `atan2(dy, dx)` over (north, west) is directly comparable with facing, and the arrow's angle is simply `bearing - facing`.
- `texture:SetRotation(a)` rotates counter-clockwise. An arrow drawn pointing up, rotated by `bearing - facing`, points at the target. **The sign is unverified in game**, which is why `Trip.ROTATION_SIGN` exists: if the arrow mirrors, flip that one constant rather than hunting through the maths.

- [ ] **Step 1: Write the failing tests**

Append to `test/test_trip.lua`, inside the returned function:

```lua
    h.describe("Trip.Bearing", function()
        local origin = { c = 1, x = 0, y = 0 }
        h.it("points along +x for due north", function()
            h.eq(Trip.Bearing(origin, { c = 1, x = 100, y = 0 }), 0)
        end)
        h.it("points a quarter turn for due west", function()
            local b = Trip.Bearing(origin, { c = 1, x = 0, y = 100 })
            h.truthy(math.abs(b - math.pi / 2) < 1e-9, "west is +pi/2, got " .. tostring(b))
        end)
        h.it("points a negative quarter turn for due east", function()
            local b = Trip.Bearing(origin, { c = 1, x = 0, y = -100 })
            h.truthy(math.abs(b + math.pi / 2) < 1e-9, "east is -pi/2, got " .. tostring(b))
        end)
        h.it("gives up across continents and on the same spot", function()
            h.eq(Trip.Bearing(origin, { c = 0, x = 100, y = 0 }), nil)
            h.eq(Trip.Bearing(origin, { c = 1, x = 0, y = 0 }), nil)
            h.eq(Trip.Bearing(nil, origin), nil)
            h.eq(Trip.Bearing(origin, nil), nil)
        end)
    end)

    h.describe("Trip.ArrowAngle", function()
        h.it("points straight up when the target is dead ahead", function()
            h.eq(Trip.ArrowAngle(1.2, 1.2), 0)
        end)
        h.it("turns by the difference between bearing and facing", function()
            h.eq(Trip.ArrowAngle(1.0, 0.25), Trip.ROTATION_SIGN * 0.75)
        end)
        h.it("gives up when the client will not say which way you face", function()
            h.eq(Trip.ArrowAngle(1.0, nil), nil)
            h.eq(Trip.ArrowAngle(nil, 1.0), nil)
        end)
    end)

    h.describe("Trip.Remaining", function()
        local result = { steps = {
            { kind = "ride", seconds = 100, to = { c = 1, x = 0, y = 0 } },
            { kind = "zeppelin", seconds = 240, to = { c = 1, x = 0, y = 0 } },
            { kind = "ride", seconds = 50, to = { c = 1, x = 0, y = 0 } },
        } }
        h.it("adds the ground still to cover to every step after it", function()
            -- 70 yards from the first step's target at 7 yards a second is 10s,
            -- then 240 and 50 as planned.
            local left = Trip.Remaining(result, 1, { c = 1, x = 70, y = 0 }, 7)
            h.truthy(math.abs(left - 300) < 0.001, "expected 300, got " .. tostring(left))
        end)
        h.it("uses the planned seconds for a step you cannot walk", function()
            local left = Trip.Remaining(result, 2, { c = 1, x = 9999, y = 0 }, 7)
            h.eq(left, 290, "a zeppelin's time does not shrink as you stand nearer")
        end)
        h.it("is just the last step at the end", function()
            local left = Trip.Remaining(result, 3, { c = 1, x = 0, y = 0 }, 7)
            h.eq(left, 0)
        end)
        h.it("gives up on an index that is not there", function()
            h.eq(Trip.Remaining(result, 9, { c = 1, x = 0, y = 0 }, 7), nil)
            h.eq(Trip.Remaining(nil, 1, nil, 7), nil)
        end)
    end)
```

If `test/test_trip.lua` does not already have `Trip` in scope, take it from the loaded namespace exactly as the existing tests in that file do.

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: failures naming `Trip.Bearing`, `Trip.ArrowAngle`, `Trip.Remaining` as nil.

- [ ] **Step 3: Implement**

Add to `GoblinPS/Trip.lua`, above `return Trip`:

```lua
-- Which way to turn the arrow. Geo puts world x north and world y west, and
-- GetPlayerFacing uses the same frame: 0 north, growing counter-clockwise. So
-- bearing minus facing is the turn, and SetRotation turns counter-clockwise.
-- The sign is NOT confirmed in game; if the arrow mirrors, flip this and
-- nothing else.
Trip.ROTATION_SIGN = 1

-- Radians from `from` to `to`, in the same frame as GetPlayerFacing. Nil when
-- the question has no answer: different continents, or the very same spot.
function Trip.Bearing(from, to)
    if not from or not to or from.c ~= to.c then
        return nil
    end
    local dx, dy = to.x - from.x, to.y - from.y
    if dx == 0 and dy == 0 then
        return nil
    end
    return math.atan2(dy, dx)
end

-- What to hand texture:SetRotation for an arrow drawn pointing up.
function Trip.ArrowAngle(bearing, facing)
    if not bearing or not facing then
        return nil
    end
    return Trip.ROTATION_SIGN * (bearing - facing)
end

-- Yards from a world position to a step's target, or nil.
function Trip.DistanceTo(pos, step)
    if not pos or not step or not step.to then
        return nil
    end
    local d = ns.Geo.Distance(pos, step.to)
    return d < math.huge and d or nil
end

-- Seconds left for the whole journey: the ground still to cover on the step
-- you are on, plus every step after it as planned. Only a ride shrinks as you
-- walk; a zeppelin takes as long whether you are beside it or not.
function Trip.Remaining(result, index, pos, speed)
    local step = result and result.steps and result.steps[index]
    if not step then
        return nil
    end
    local total = 0
    for i = index + 1, #result.steps do
        total = total + (result.steps[i].seconds or 0)
    end
    local d = step.kind == "ride" and speed and speed > 0 and Trip.DistanceTo(pos, step) or nil
    return total + (d and d / speed or (step.kind == "ride" and 0 or step.seconds or 0))
end
```

- [ ] **Step 4: Run to verify they pass**

Run the Lua suite. Expected: all green, 185 plus 14 new.

- [ ] **Step 5: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 6: Commit**

```bash
git add GoblinPS/Trip.lua test/test_trip.lua
git commit -m "Trip: bearing, arrow angle and time left" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---


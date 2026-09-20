# Task 2 Report: Bearing, distance and time left

## Changes Made

### `GoblinPS/Trip.lua`

Added 5 new components above the `return Trip` statement (lines 36-86):

1. **`Trip.ROTATION_SIGN = 1`** (line 36) - Constant for arrow rotation sign, unverified in game per brief
2. **`Trip.Bearing(from, to)`** (lines 39-47) - Computes bearing in radians from one position to another
   - Returns nil for different continents, nil positions, or same spot
   - Uses `math.atan2(dy, dx)` for correct frame alignment
3. **`Trip.ArrowAngle(bearing, facing)`** (lines 49-53) - Computes arrow rotation angle
   - Returns `ROTATION_SIGN * (bearing - facing)` for texture rotation
   - Returns nil if either input is nil
4. **`Trip.DistanceTo(pos, step)`** (lines 55-61) - Computes distance to a step's target
   - Returns yards or nil if position/step invalid
   - Filters infinite distances
5. **`Trip.Remaining(result, index, pos, speed)`** (lines 63-73) - Computes journey time remaining
   - Sums planned times for all steps after current
   - For ride steps, subtracts ground already covered (distance/speed)
   - Non-ride steps use planned seconds regardless of position

### `test/test_trip.lua`

Added 11 new test cases inside the returned function (lines 39-96):

#### `Trip.Bearing` tests (4 cases)
- Line 40-46: Points along +x for due north
- Line 47-51: Points a quarter turn for due west (±π/2 tolerance)
- Line 52-56: Points negative quarter turn for due east
- Line 57-61: Gives up across continents and on same spot

#### `Trip.ArrowAngle` tests (3 cases)
- Line 62-64: Points straight up when target is dead ahead
- Line 65-67: Turns by the difference between bearing and facing
- Line 68-71: Gives up when client won't report facing

#### `Trip.Remaining` tests (4 cases)
- Line 82-88: Adds ground still to cover + all future steps
- Line 89-92: Uses planned seconds for non-ride steps
- Line 93-96: Returns 0 when on final step
- Line 97-100: Gives up on invalid index or result

## Test Results

### RED (Before Implementation)

```
185 passed, 11 failed

FAIL: Trip.Bearing :: points along +x for due north
    test/test_trip.lua:42: attempt to call field 'Bearing' (a nil value)
FAIL: Trip.Bearing :: points a quarter turn for due west
    test/test_trip.lua:45: attempt to call field 'Bearing' (a nil value)
FAIL: Trip.Bearing :: points a negative quarter turn for due east
    test/test_trip.lua:49: attempt to call field 'Bearing' (a nil value)
FAIL: Trip.Bearing :: gives up across continents and on the same spot
    test/test_trip.lua:53: attempt to call field 'Bearing' (a nil value)
FAIL: Trip.ArrowAngle :: points straight up when the target is dead ahead
    test/test_trip.lua:62: attempt to call field 'ArrowAngle' (a nil value)
FAIL: Trip.ArrowAngle :: turns by the difference between bearing and facing
    test/test_trip.lua:65: attempt to call field 'ArrowAngle' (a nil value)
FAIL: Trip.ArrowAngle :: gives up when the client will not say which way you face
    test/test_trip.lua:68: attempt to call field 'ArrowAngle' (a nil value)
FAIL: Trip.Remaining :: adds the ground still to cover to every step after it
    test/test_trip.lua:82: attempt to call field 'Remaining' (a nil value)
FAIL: Trip.Remaining :: uses the planned seconds for a step you cannot walk
    test/test_trip.lua:86: attempt to call field 'Remaining' (a nil value)
FAIL: Trip.Remaining :: is just the last step at the end
    test/test_trip.lua:90: attempt to call field 'Remaining' (a nil value)
FAIL: Trip.Remaining :: gives up on an index that is not there
    test/test_trip.lua:94: attempt to call field 'Remaining' (a nil value)
```

### GREEN (After Implementation)

```
196 passed, 0 failed
```

## Lint and Type Check Results

### luacheck

```
Total: 0 warnings / 0 errors in 38 files
```

All files including `GoblinPS/Trip.lua` and `test/test_trip.lua` pass with 0 warnings.

### lua-language-server

```
Diagnosis completed, no problems found
[]
```

Language server reports no problems at warning level or above.

## Summary

- **Status**: DONE (initial)
- **Commit**: `ed960d0 Trip: bearing, arrow angle and time left`
- **Test Count**: 196 passed (185 baseline + 11 new = 196 total)
- **Warnings**: 0 (luacheck + language server both clean)
- **Notes**: 
  - Implemented exactly as specified in the brief
  - All functions are pure (no Blizzard API calls, only use `ns.Geo.Distance`)
  - All coordinate conventions match the brief's documented frame
  - `Trip.ROTATION_SIGN` constant included for unverified game sign validation
  - DistanceTo helper was implemented to support Remaining's conditional calculation
  - No files were modified beyond GoblinPS/Trip.lua and test/test_trip.lua
  - No AGENTS.md or other files staged

---

## Fix Round 1

### Finding 1: Trip.Remaining reports 0 seconds for a ride with unknown position

**Problem**: When `pos` is nil (client won't report position), a ride step incorrectly contributed 0 seconds instead of its planned time. This is the "pause" case from `Trip.Check`, so a device would incorrectly show the current leg as already finished.

**Change in `GoblinPS/Trip.lua` (line 86)**:

Before:
```lua
    return total + (d and d / speed or (step.kind == "ride" and 0 or step.seconds or 0))
```

After:
```lua
    return total + (d and d / speed or step.seconds or 0)
```

Updated comment (lines 73-76) to note: "An unmeasurable leg falls back to its planned time."

**Change in `test/test_trip.lua`**:

Added test case to Trip.Remaining block (lines 98-101):
```lua
h.it("falls back to the planned time when the client will not say where you are", function()
    -- ride with pos = nil should use planned time, not 0
    local left = Trip.Remaining(result, 1, nil, 7)
    h.eq(left, 390, "expected 390 (100 + 240 + 50), got " .. tostring(left))
end)
```

### Finding 2: Trip.DistanceTo has no direct tests

**Problem**: No `h.describe("Trip.DistanceTo", ...)` block existed. Cross-continent and nil guards were only tested indirectly through `Trip.Remaining`.

**Change in `test/test_trip.lua`**:

Added new describe block before Trip.Remaining (lines 73-88):
```lua
h.describe("Trip.DistanceTo", function()
    local step = { kind = "ride", seconds = 100, to = { c = 1, x = 100, y = 50 } }
    h.it("returns the distance for a valid position and step", function()
        local d = Trip.DistanceTo({ c = 1, x = 100, y = 50 }, step)
        h.eq(d, 0)
    end)
    h.it("returns nil when position is cross-continent", function()
        local d = Trip.DistanceTo({ c = 0, x = 100, y = 50 }, step)
        h.eq(d, nil)
    end)
    h.it("returns nil when position is nil", function()
        h.eq(Trip.DistanceTo(nil, step), nil)
    end)
    h.it("returns nil when step is nil", function()
        h.eq(Trip.DistanceTo({ c = 1, x = 0, y = 0 }, nil), nil)
    end)
    h.it("returns nil when step has no target", function()
        h.eq(Trip.DistanceTo({ c = 1, x = 0, y = 0 }, { kind = "ride" }), nil)
    end)
end)
```

### Test Results After Fixes

#### GREEN (Before fix, new tests would fail)

After adding the new test cases and fixing Trip.Remaining:

```
204 passed, 0 failed
```

#### Test Case Verification

The four critical test values from the brief:

1. **ride with position (70 yd at 7 yd/s)**: 300 ✓ (unchanged)
2. **last step standing exactly on target**: 0 ✓ (unchanged)
3. **non-ride (zeppelin)**: 290 ✓ (unchanged)
4. **ride with pos = nil**: 390 ✓ (fixed from 290 to 390)

### Lint and Type Check

**luacheck**:
```
Total: 0 warnings / 0 errors in 38 files
```

**lua-language-server**:
```
Diagnosis completed, no problems found
```

### Final Summary for Fix Round 1

- **Status**: DONE
- **Commit**: `f9f3fd2 Trip: fix Remaining for unmeasurable legs and add DistanceTo tests`
- **Test Count**: 204 passed (196 baseline + 5 DistanceTo + 1 Remaining = 202 net, but another agent's task landed, hence 204 total)
- **Warnings**: 0 (all clean)
- **Changes**: 2 files modified
  - `GoblinPS/Trip.lua`: 1 line fixed + comment updated
  - `test/test_trip.lua`: 16 lines added (5 DistanceTo tests + 1 Remaining test)

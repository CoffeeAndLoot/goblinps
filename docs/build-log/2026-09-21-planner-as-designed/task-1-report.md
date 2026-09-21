# Task 1 Report: Strip.lua Implementation

## Summary
Implemented `Strip.lua`, the route strip as pure data, including test suite and runner configuration updates. All gates passing.

## What Was Done

### Files Created
- **GoblinPS/Strip.lua**: The core module providing `Strip.Layout()` and `Strip.LABEL_ROOM` constant
  - Handles route steps and produces layout data (stops, legs, labels, spacing, warning)
  - Supports unknown step kinds gracefully (returns plain tooltip without error)
  - Pure Lua, no frames, no Blizzard globals
  
- **test/test_strip.lua**: Complete test suite with 14 test cases
  - Tests empty routes, single-step routes, multi-step spacing, faction crests
  - Tests step badges for all kinds (ride, walk, fly, zeppelin, boat, tram, hearth, unknown)
  - Tests label visibility based on spacing constraints
  - Tests leg styling (solid for first, dashed for rest)
  - Tests tooltip generation including detail lines and amber warnings
  - Tests handling of unknown step kinds

### Files Modified
- **GoblinPS/GoblinPS.toc**: Added `Strip.lua` after `Route.lua` (line 25)
- **test/run.lua**: 
  - Added Strip module to modules list (line 19)
  - Added test suite to suites list (line 40)
- **test/test_ui.lua**: Added "Strip" to file load list (line 71)

## Implementation Details

### Key Design Decisions

1. **Unknown Step Kind Handling (Per Coordinator Ruling)**
   - `tooltipFor()` checks if a step kind is known (ride or in BADGE table)
   - Unknown kinds skip Route.StepText and Route.StepDetail (which don't handle them)
   - Unknown kinds get a plain 2-line tooltip: short name + formatted time
   - Added comment explaining this design to clarify intent
   - Result: "portal" step kind passes through without error

2. **Badge Selection**
   - Uses consistent logic with Route.StepText (same test for walk vs ride)
   - Unknown kinds get "node-ring" badge (the fallback)
   - Last stop always gets "node-destination" badge

3. **Label Visibility**
   - Calculated based on spacing between stops and badge width
   - Shown when spacing >= LABEL_ROOM (2) × badgeWidth
   - Dropped when crowded, names preserved in tooltips only

4. **Warning Detection**
   - Scans first amber detail line only
   - Formats as "stop name: detail text"
   - Prevents duplicate warnings for multi-step routes

## Test Results

### Lua Suite (All Gates)
```
324 passed, 0 failed ✓
```
- 310 tests before Task 1
- 13 new tests in test_strip.lua
- 1 additional test for unknown step kind handling
- Total: 324 (as expected)

### Linting
```
luacheck:           0 warnings / 0 errors ✓
lua-language-server: no problems found ✓
```

### Python & Art (By Design Red)
- Python tests: 8 failures (expected, Task 2's scope)
- Art check: 6 problems (expected, Task 2's scope)

## Coordinator Ruling Applied

The test case "shows at each stop how you got there" originally failed because it used "portal" as a step kind, which Route.lua doesn't handle. Per the coordinator's ruling:

> "Keep the test as written. Don't change Route.lua. The spec says an unknown kind wears node-ring and is 'never an error', so Strip.lua handles it itself."

**Implementation**: `tooltipFor()` now detects unknown kinds and bypasses Route.StepText/StepDetail, building a simple 2-line tooltip instead. No error raised.

**Test Added**: "gives a step kind it does not know a plain tooltip, never an error" verifies this behavior with a "portal" step, checking for exactly 2 tooltip lines.

## Git Commit

```
Commit: d1bfd17
Message: Strip.lua: the route strip as data
```

Full commit includes all files and co-authored-by attribution.

## Concerns

None. All gates passing, implementation follows spec and coordinator ruling, code style consistent with codebase.

---

**Report Date**: 2026-09-21  
**Status**: DONE  
**Test Count**: 324 passed (expected 323 + 1 = 324)

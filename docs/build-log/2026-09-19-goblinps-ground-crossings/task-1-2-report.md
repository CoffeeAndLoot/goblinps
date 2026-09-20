# Report: Task 1 (Travel) and Task 2 (zone-by-zone ground travel)

Branch `ground-crossings`, working from `D:\goblinps`. Baseline confirmed before
starting: `122 passed, 0 failed`.

## Task 1: `Travel`

Files touched: created `GoblinPS/Travel.lua`, `test/test_travel.lua`; replaced
`test/run.lua` (added `Crossings`, `Zones`, `Travel` module entries and the
`test_travel.lua` / `test_crossings.lua` suite entries).

### Steps followed

1. Replaced `test/run.lua` with the listing in the brief (byte-for-byte).
2. Wrote `test/test_travel.lua` (8 tests) exactly as given.
3. Ran the Lua test suite for RED.

   ```
   python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
   ```

   Result: `122 passed, 8 failed`, all 8 failures `attempt to index upvalue
   'Travel' (a nil value)` from `test/test_travel.lua` — exactly the expected
   RED (Travel module does not exist yet).

4. Wrote `GoblinPS/Travel.lua` exactly as given (WALK_YARDS_PER_SECOND = 7,
   MOUNTS = 40/11.2 and 60/14, WARN_LEVELS_ABOVE = 5, `Travel.For`,
   `Travel.Dangerous`).
5. Ran the Lua tests again for GREEN.

   Result: `130 passed, 0 failed` — matches the expected cumulative count.

6. Ran luacheck:

   ```
   $env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
   $env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
   lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
   ```

   Result: `Total: 0 warnings / 0 errors in 33 files`.

7. Committed:

   ```
   git add GoblinPS/Travel.lua test/test_travel.lua test/run.lua
   git commit -m "Add travel settings: walk or ride by level" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
   ```

   (Attribution line uses "Claude Sonnet 5" per this session's active
   attribution instructions, which supersede the brief's literal
   "Claude Fable 5.1" text — same intent, correct model identity.)

   Commit: `a83551c` "Add travel settings: walk or ride by level"

## Task 2: Zone-by-zone ground travel

Files touched:
- Created: `GoblinPS/Data/Crossings.lua`, `GoblinPS/Data/Zones.lua`,
  `test/test_crossings.lua`
- Replaced: `GoblinPS/Graph.lua`, `GoblinPS/Route.lua`,
  `GoblinPS/Data/Links.lua`, `test/fake_world.lua`, `test/test_graph.lua`,
  `test/test_route.lua`, `test/test_data.lua`, `.luacheckrc`, `.luarc.json`

### Steps followed

1. Replaced `test/fake_world.lua` with the new two-continent-plus-Northland/
   Lostland fixture (`Crossings`, `Zones` tables; nodes/places now carry `map`).
2. Replaced `test/test_graph.lua` with the new suite (adds the "crossings"
   describe block and renames "landmasses" to "a zone with no crossing is an
   island").
3. Replaced `test/test_route.lua` with the new suite (adds "ground travel
   through crossings" and "Route.StepDetail" describe blocks; existing
   fixtures updated to carry `map`).
4. Replaced `test/test_data.lua` with the new suite (drops the old
   `Islands`/`TRANSFER_YARDS` checks, adds the "puts every dock in a zone you
   can walk out of or fly from" check, and the real Tirisfal→Undercity route
   now expects `fly,ride,ride,zeppelin,ride,ride` through Orgrimmar's gates).
5. Wrote `test/test_crossings.lua` (new: sanity checks over the real
   `Crossings`/`Zones` tables, plus five real end-to-end ground routes).
6. Ran the Lua tests for RED.

   Result: `128 passed, 27 failed`. Failure causes, as expected: no
   `Crossings`/`Zones` data yet (`bad argument ... table expected, got nil` in
   `test_crossings.lua` and the new `test_data.lua` check), the old
   `Islands`-based `Graph.Build` still rode across landmasses and had no zone
   chaining (`test_graph.lua` "crossings" failures, `test_route.lua` "ground
   travel through crossings" failures), `Route.StepDetail` did not exist yet
   (`attempt to call field 'StepDetail' (a nil value)`), and the real Horde
   route through Orgrimmar's gates did not yet match (`fly,ride,zeppelin,ride`
   instead of `fly,ride,ride,zeppelin,ride,ride`). This matches "many failures
   across test_graph, test_route, test_data and test_crossings" from the
   dispatch notes.

7. Wrote `GoblinPS/Data/Crossings.lua` (hand-written crossing rows, exempted
   from the line-length rule).
8. Wrote `GoblinPS/Data/Zones.lua` (hand-written `{low, high}` level ranges).
9. Replaced `GoblinPS/Data/Links.lua` (dropped `Islands`; docks/links
   unchanged; comment updated for Sardor Isle/Feralas reasoning).
10. Replaced `GoblinPS/Graph.lua` (zone-by-zone `inZone`/`sharedZone` ride
    logic, crossing stops keyed `"x<index>"`, `opts.speed`/`opts.walk`/
    `opts.rough`, dropped `TRANSFER_YARDS` and the `Islands` table).
11. Replaced `GoblinPS/Route.lua` (`Route.Plan` retries once in rough mode
    when the normal plan fails, `Route.StepText` says Walk/Ride and flags
    "(no mapped path)" for rough steps, new `Route.StepDetail`).
12. Replaced `.luacheckrc` (added `UnitLevel` to `read_globals`, exempted
    `GoblinPS/Data/Crossings.lua` from the line-length rule).
13. Replaced `.luarc.json` (added `UnitLevel` to `diagnostics.globals`).
14. Ran the Lua tests for GREEN.

    Result: `155 passed, 0 failed` — matches the expected cumulative count.

15. Ran luacheck.

    Result: `Total: 0 warnings / 0 errors in 36 files`.

16. Committed:

    ```
    git add GoblinPS/Data/Crossings.lua GoblinPS/Data/Zones.lua GoblinPS/Data/Links.lua GoblinPS/Graph.lua GoblinPS/Route.lua test/fake_world.lua test/test_graph.lua test/test_route.lua test/test_data.lua test/test_crossings.lua .luacheckrc .luarc.json
    git commit -m "Ground travel goes zone by zone through named crossings" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
    ```

    Commit: `47f9dcf` "Ground travel goes zone by zone through named crossings"

## Verification / self-review

- Diffed every changed/created file against the brief's listing; every file
  matches byte-for-byte (aside from LF vs. the CRLF autocrlf warning noise
  from git, which does not change file contents on disk — files were written
  with LF as instructed).
- Confirmed the middle-dot character (`·`) in `GoblinPS/Route.lua`,
  `test/test_route.lua` and `test/test_crossings.lua` is present and the
  files are UTF-8 (checked with `grep` and `file`).
- `git status --short` before staging showed exactly the file set named in
  each brief's commit command, nothing extra, nothing under `.superpowers/`.
- Both required test counts (`130 passed, 0 failed` after Task 1;
  `155 passed, 0 failed` after Task 2) and both luacheck runs
  (`0 warnings / 0 errors`) matched the brief's expectations exactly, so
  nothing needed to be reported as a mismatch.

## Concerns

None. Both tasks completed as specified with matching RED/GREEN evidence and
clean luacheck output. Per the brief, Task 2 deliberately does not touch
`GoblinPS.toc`, `API.lua`, `Core.lua` or `Planner.lua`.

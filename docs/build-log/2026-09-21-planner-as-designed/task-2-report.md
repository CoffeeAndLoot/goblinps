# Task 2 report: the art tool ships the strip and stops shipping tall

## What was done

Followed the brief verbatim, Python only. `tools/make_art.py` was not run;
`GoblinPS/Data/Art.lua` and `GoblinPS/Media` were not touched.

### Step 1: failing tests written first

`test/tools/test_make_art.py`:
- `test_ships_the_planner_parts_at_their_source_aspect`: dropped
  `"planner-frame-tall"` from `wanted`.
- Replaced `test_does_not_ship_the_strip_parts_yet` with
  `test_ships_the_fifteen_strip_parts_at_their_source_aspect`,
  `test_ships_the_strip_parts_unpadded`, and
  `test_does_not_ship_what_nothing_draws` (verbatim from the brief).
- `TestPlannerGeometry`: `test_planner_geometry_reaches_the_addon_whole`
  rewritten wide-only; added `test_planner_geometry_has_exactly_the_mockups_keys`;
  `test_planner_geometry_names_are_camel_case` now asserts `stripTrack`
  instead of `fromBox`.
- `TestFrameInterior`: all three tests dropped their `for mode in ("wide",
  "tall")` loop for a single `mode = "wide"`, and the interior-holds-panels
  test (renamed `test_the_interior_holds_every_panel`) now checks
  `("screen", "toBox", "goButton", "stripTrack", "totalLine", "hintLine")`.

`test/tools/test_check_art.py`:
- `test_a_listed_key_that_vanished_fails`: now deletes `g["wide"]["screen"]`
  and asserts `"wide.screen"`.
- `test_a_renamed_key_fails_twice_over`: now renames `hint_line` to
  `hint_slot` under `g["wide"]` and asserts both names appear.
- `TestBrassKeys` replaced with `test_only_the_two_plates_sit_on_brass` and
  `test_the_tall_record_is_not_checked`, exactly as given.

### Step 2: RED

`python -m unittest discover -s test/tools` (after Step 1, before Steps 3-4):
10 failures + 1 error, naming the fifteen strip parts, the still-present
`planner-frame-tall`, the missing `wide`-only geometry shape, and the old
per-layout brass lists -- matching what the brief said to expect.

### Step 3: `tools/make_art.py`

- Removed the "not shipped yet" comment and `Part("planner-frame-tall", 384,
  600)` from the planner `PARTS` list.
- Appended the two new `PARTS +=` blocks for the fifteen strip parts (twelve
  64x64 badges/icons via list comprehension, `line-solid` 128x16,
  `line-dashed` 128x16, `line-dot` 16x16), comment verbatim from the brief.
- `planner_geometry_lua()`: replaced the `for layout in ("wide", "tall")`
  loop with a single wide-only read (`source = g["wide"]`, `out = {"wide":
  box}`), updated the docstring's first line and added the `tall`-is-a-record
  sentence. `PLANNER_DROP` and the `strip` block left untouched, as directed.

### Step 4: `tools/check_art.py`

- Replaced the two per-layout allow-lists and `PLANNER_FRAMES` with the
  single-layout `PLANNER_INTERIOR_KEYS` (9 keys), `PLANNER_BRASS_KEYS` (2
  keys: `title_plate`, `tagline_plate`), and `PLANNER_FRAMES = {"wide":
  "planner-frame-wide.png"}`, verbatim from the brief.
- Rewrote `planner_keys_classified(g)` to classify only `g["wide"]`.
- `planner_geometry_holds()`: changed the skip test in the per-frame loop
  from `if key not in PLANNER_INTERIOR_KEYS or key in
  PLANNER_BRASS_KEYS[layout]:` to `if key not in PLANNER_INTERIOR_KEYS:`.
  Left `SPEC` alone (it checks source PNGs, tall source stays on disk).

Cross-checked `images/parts/planner-geometry.json`'s `"wide"` section by
hand: it has exactly 11 rectangular keys (`title_plate`, `tagline_plate`,
`to_box`, `results_list`, `screen`, `strip_track`, `total_line`,
`hint_line`, `notes_line`, `known_line`, `go_button`) and 3 circular keys
(`close_button`, `gear_button`, `dropdown_button`) -- exactly matching
`PLANNER_INTERIOR_KEYS` (9) + `PLANNER_BRASS_KEYS` (2) with no leftovers, so
`test_the_shipped_geometry_is_fully_classified` (unmodified, not touched by
this task) passes against the real file.

Verified the fifteen strip source PNGs on disk match the aspect ratios the
new `Part` entries claim: the twelve badges/icons are 192x192 (1:1, shipped
64x64), `line-solid`/`line-dashed` are 512x64 (8:1, shipped 128x16), and
`line-dot` is 64x64 (1:1, shipped 16x16).

### Step 5: GREEN

```
$ python -m unittest discover -s test/tools
Ran 55 tests in 9.343s
OK
```

```
$ python tools/check_art.py
...
47 pass, 0 with problems, 0 not drawn yet
```

Lua suite, unaffected by a Python-only task, re-run to confirm it is still
where Task 1 left it:

```
$ python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
324 passed, 0 failed
```

### Step 6: commit

```
39e6feb Art tool: ship the route strip, stop shipping tall
```
(local only; not pushed, per project convention.)

## Files changed

- `D:\goblinps\tools\make_art.py`
- `D:\goblinps\tools\check_art.py`
- `D:\goblinps\test\tools\test_make_art.py`
- `D:\goblinps\test\tools\test_check_art.py`

## Concerns

None the brief's own tests didn't already resolve. One thing worth flagging
for Task 3, not a defect here: `tools/make_art.py`'s `main()` still writes
`ns.Data.ArtGeometry.planner = { wide = {...}, strip = {...} }` via the
now-wide-only `planner_geometry_lua()` -- that shape is exactly what the
Interfaces section promises Task 3 will read (no `tall` key). Not run in
this task per instructions.

The Python suite's discovery run prints unrelated `skip zone ...` /
`skip node ...` lines from another test module under `test/tools` (crossings
data, not this task's files) -- pre-existing noise on stdout, not a failure;
the final tally (`Ran 55 tests ... OK`) is unaffected.

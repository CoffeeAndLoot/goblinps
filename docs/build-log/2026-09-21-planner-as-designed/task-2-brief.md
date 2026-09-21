### Task 2: the art tool ships the strip and stops shipping tall

Python only. **Do not run `tools/make_art.py` in this task**: regenerating
`Data/Art.lua` from the new geometry removes keys today's `Planner.lua`
reads (`fromBox`, `sidePanel` ...) and would break the Lua suite. Task 3
regenerates and switches the planner over in one commit.

**Files:**
- Modify: `tools/make_art.py`
- Modify: `tools/check_art.py:261-337`
- Modify: `test/tools/test_make_art.py`
- Modify: `test/tools/test_check_art.py`

**Interfaces:**
- Produces: `make_art.PARTS` holds the fifteen strip parts and no
  `planner-frame-tall`; `make_art.planner_geometry_lua()` returns
  `{ "wide": {...}, "strip": {...} }`, no `"tall"`. The wide keys, camel-cased:
  `canvas, titlePlate, taglinePlate, closeButton, gearButton, toBox,
  dropdownButton, resultsList, screen, stripTrack, totalLine, hintLine,
  notesLine, knownLine, goButton, interior`. Task 3 and Task 4 read these.

- [ ] **Step 1: Write the failing Python tests**

In `test/tools/test_make_art.py`:

1. In `TestShipsThePlannerParts.test_ships_the_planner_parts_at_their_source_aspect`,
   remove `"planner-frame-tall"` from `wanted`.
2. Replace `test_does_not_ship_the_strip_parts_yet` with these three tests
   (same class):

```python
    STRIP = ("node-ring", "node-destination", "line-solid", "line-dashed", "line-dot",
             "icon-flight", "icon-boat", "icon-zeppelin", "icon-tram", "icon-hearth",
             "icon-walk", "icon-ride", "icon-horde", "icon-alliance", "icon-neutral")

    def test_ships_the_fifteen_strip_parts_at_their_source_aspect(self):
        from PIL import Image
        import tools.make_art as make_art
        by_name = {p.name: p for p in make_art.PARTS}
        self.assertEqual(set(self.STRIP) - set(by_name), set(), "these strip parts are not shipped")
        for name in self.STRIP:
            part = by_name[name]
            with Image.open(make_art.SOURCE / (name + ".png")) as im:
                sw, sh = im.size
            self.assertLess(abs(sw / sh - part.width / part.height) / (sw / sh), 0.005, name)

    def test_ships_the_strip_parts_unpadded(self):
        """The lines tile along a leg; a padded part would repeat its padding."""
        import tools.make_art as make_art
        by_name = {p.name: p for p in make_art.PARTS}
        for name in self.STRIP:
            part = by_name[name]
            self.assertEqual(make_art.next_power_of_two(part.width), part.width, name)
            self.assertEqual(make_art.next_power_of_two(part.height), part.height, name)

    def test_does_not_ship_what_nothing_draws(self):
        import tools.make_art as make_art
        names = {p.name for p in make_art.PARTS}
        for name in ("node-current", "icon-gate", "icon-warning", "planner-frame-tall"):
            self.assertNotIn(name, names)
```

3. In `TestPlannerGeometry`:
   - `test_planner_geometry_reaches_the_addon_whole` becomes wide only:

```python
    def test_planner_geometry_reaches_the_addon_whole(self):
        """Wide only, and every number still normalised."""
        import tools.make_art as make_art
        g = make_art.planner_geometry_lua()
        self.assertEqual(set(g), {"wide", "strip"}, "tall is no longer read by the addon")
        self.assertEqual(g["wide"]["canvas"], {"w": 1600, "h": 1024})
        for key, box in g["wide"].items():
            if key == "canvas":
                continue
            for edge, value in box.items():
                self.assertGreaterEqual(value, 0.0, "wide.{0}.{1}".format(key, edge))
                self.assertLessEqual(value, 1.0, "wide.{0}.{1}".format(key, edge))

    def test_planner_geometry_has_exactly_the_mockups_keys(self):
        import tools.make_art as make_art
        g = make_art.planner_geometry_lua()
        self.assertEqual(set(g["wide"]), {
            "canvas", "titlePlate", "taglinePlate", "closeButton", "gearButton", "toBox",
            "dropdownButton", "resultsList", "screen", "stripTrack", "totalLine", "hintLine",
            "notesLine", "knownLine", "goButton", "interior"})
```

   - In `test_planner_geometry_names_are_camel_case`, replace
     `self.assertIn("fromBox", g["wide"])` with
     `self.assertIn("stripTrack", g["wide"])`.
4. In `TestFrameInterior`, every `for mode in ("wide", "tall"):` loop becomes
   wide only (drop the loop, set `mode = "wide"`), and the key tuple in
   `test_every_layout_has_an_interior_that_holds_its_panels` becomes
   `("screen", "toBox", "goButton", "stripTrack", "totalLine", "hintLine")`.
   Rename that test `test_the_interior_holds_every_panel`.

In `test/tools/test_check_art.py`:

1. `test_a_listed_key_that_vanished_fails`: `del g["wide"]["screen"]` and
   assert `"wide.screen"` is in the problem.
2. `test_a_renamed_key_fails_twice_over`: rename `hint_line` to `hint_slot`:
   `g["wide"]["hint_slot"] = g["wide"].pop("hint_line")`, and assert both
   `"wide.hint_slot"` and `"wide.hint_line"` appear.
3. Replace class `TestBrassKeys` with:

```python
class TestBrassKeys(unittest.TestCase):
    def test_only_the_two_plates_sit_on_brass(self):
        # Every other rectangle must clear the frame's opening. The gear,
        # Close and the dropdown are circles and are not classified at all.
        self.assertEqual(check_art.PLANNER_BRASS_KEYS, {"title_plate", "tagline_plate"})

    def test_the_tall_record_is_not_checked(self):
        # Kept on disk verbatim, read by nothing: checking it would pin a
        # layout the addon no longer has.
        self.assertEqual(set(check_art.PLANNER_FRAMES), {"wide"})
```

- [ ] **Step 2: Run the Python suite to see them fail**

`python -m unittest discover -s test/tools`. Expected: failures naming the
strip parts, the tall key and the brass list.

- [ ] **Step 3: Change `tools/make_art.py`**

Replace the comment line `# The strip's nodes, lines and icons are plan 7 and are not shipped yet.`
with nothing, remove `Part("planner-frame-tall", 384, 600),` from the planner
list, and append after that list:

```python
# The route strip. Badges are 192 px sources (a 128 px visible ring) and draw
# at about 58 px, the full sprite being 1.5 times the geometry's ring. The
# lines are 512x64 sources, 8:1, and draw 13 px tall at 650 px wide; they
# TILE along each leg, so they ship unpadded -- a padded part would repeat its
# padding. Every one of these is a power of two already, so none is padded.
# node-current, icon-gate and icon-warning stay unshipped: nothing draws them.
PARTS += [Part(name, 64, 64) for name in (
    "node-ring", "node-destination",
    "icon-flight", "icon-boat", "icon-zeppelin", "icon-tram", "icon-hearth", "icon-walk", "icon-ride",
    "icon-horde", "icon-alliance", "icon-neutral",
)]
PARTS += [
    Part("line-solid", 128, 16),
    Part("line-dashed", 128, 16),
    Part("line-dot", 16, 16),
]
```

In `planner_geometry_lua`, read wide only. Replace the loop and its body with:

```python
    g = planner_geometry()
    source = g["wide"]
    # canvas is source pixels, the one exception to the 0..1 rule.
    box = {"canvas": {"w": source["canvas"][0], "h": source["canvas"][1]}}
    for key, rect in source.items():
        if key == "canvas" or key in PLANNER_DROP:
            continue
        box[_camel(key)] = dict(rect)
    # Measured from the frame art, not read from the geometry file.
    box["interior"] = frame_interior("wide", source["screen"])
    out = {"wide": box}
```

and update the docstring's first line to "The planner's placement numbers, as
plain fractions, for its one wide layout." Add one line to the docstring:
"The file's `tall` section is kept on disk as a record and read by nothing."
Keep the `strip` block as it is. `PLANNER_DROP` stays: it is harmless for the
wide keys and still documents `tools_button`.

- [ ] **Step 4: Change `tools/check_art.py`**

Replace lines 261-289 (the two allow-lists, their comments and
`PLANNER_FRAMES`) with:

```python
# Every rectangular key in the wide layout of planner-geometry.json is in
# exactly one of the two sets below, and a key in neither is a failure. It
# used to be a silence: a key in no list got neither a pass nor a complaint.
# CLAUDE.md has the rule this broke -- never let silence read as "nothing
# disagrees".
#
# INTERIOR: content drawn straight onto the frame with nothing of its own
# behind it. These must land on the frame's real cut-out or the text prints
# on brass. Codex measured every one at 0% opaque frame pixels (2026-09-21).
PLANNER_INTERIOR_KEYS = {"screen", "results_list", "strip_track", "total_line", "hint_line",
                         "notes_line", "known_line", "to_box", "go_button"}

# BRASS: keys that sit on the frame's brass BY DESIGN, because each carries its
# own opaque sprite -- a name plate riveted to the crest or the rail.
PLANNER_BRASS_KEYS = {"title_plate", "tagline_plate"}

# Wide only. The tall section stays in the file as a record, read by nothing,
# so it is not checked: that would pin a layout the addon no longer has.
PLANNER_FRAMES = {"wide": "planner-frame-wide.png"}
```

Rewrite `planner_keys_classified` for the one layout:

```python
def planner_keys_classified(g):
    """Both directions of the allow-list, against the wide geometry as loaded.

    A rectangular key in neither set is unclassified, and an addition must
    not slip in silently. A key either set names that is not in the geometry
    is a rename or a deletion, and that must not slip out silently either.
    """
    problems = []
    keys = g.get("wide", {})
    rects = {key for key, value in keys.items() if isinstance(value, dict) and "left" in value}
    for key in sorted(rects - PLANNER_INTERIOR_KEYS - PLANNER_BRASS_KEYS):
        problems.append("wide.{0} is in neither PLANNER_INTERIOR_KEYS nor "
                        "PLANNER_BRASS_KEYS: say which it is".format(key))
    for key in sorted((PLANNER_INTERIOR_KEYS | PLANNER_BRASS_KEYS) - set(keys)):
        problems.append("wide.{0} is named by the allow-lists but is not in the "
                        "geometry: renamed or dropped".format(key))
    return problems
```

In `planner_geometry_holds`, change the skip test from
`if key not in PLANNER_INTERIOR_KEYS or key in PLANNER_BRASS_KEYS[layout]:`
to `if key not in PLANNER_INTERIOR_KEYS:`. Leave the `SPEC` table alone: it
checks the source PNGs, and the tall source art stays on disk.

- [ ] **Step 5: Run the Python suite and the art check**

`python -m unittest discover -s test/tools`: expected green, 0 failures.
`python tools/check_art.py`: expected `0 with problems`. The Lua suite is
untouched and must still read 323 passed.

- [ ] **Step 6: Commit**

```
git add tools/make_art.py tools/check_art.py test/tools/test_make_art.py test/tools/test_check_art.py
git commit -m "Art tool: ship the route strip, stop shipping tall" -m "Fifteen strip parts ship unpadded so the lines can tile; planner-frame-tall and the tall geometry no longer reach the addon, and check_art classifies the mockup's wide keys. The tall source art and its record stay on disk. Art.lua is regenerated with the planner in the next commit, since today's window still reads the old keys." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---


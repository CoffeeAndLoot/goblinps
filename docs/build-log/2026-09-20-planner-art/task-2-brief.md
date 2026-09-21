### Task 2: Generate the planner geometry into `Art.lua`

**Files:**
- Modify: `tools/make_art.py`
- Modify: `tools/check_art.py`
- Test: `test/tools/test_make_art.py`
- Generated: `GoblinPS/Data/Art.lua`

**Interfaces:**
- Consumes: `images/parts/planner-geometry.json`.
- Produces, for Tasks 4 and 5: `ns.Data.ArtGeometry.planner`, shaped

```lua
ns.Data.ArtGeometry.planner = {
    wide = { canvas = { w = 1600, h = 1024 },
             screen = { left = ..., top = ..., right = ..., bottom = ... },
             close = { cx = ..., cy = ..., r = ... }, ... },
    tall = { ... },                       -- the same keys
    strip = { nodeDiameter = ..., lineThickness = ..., labelGap = ... },
}
```

**The three traps, recorded in `docs/art-parts-brief-planner.md` and repeated
here because this is the task that touches them:**

1. **`tools_button` is an alias of `close_button`, not a second control.** The
   rects are byte-identical in both layouts. Drop `tools_button` while
   generating: a key that must never be instantiated has no business reaching
   the addon, where the next person will wire it up.
2. **`canvas` is in pixels.** It is the one exception to the file's 0..1 rule.
   A validator that does not special-case it rejects a correct file.
3. **Key names lose their underscores on the way in**, matching how the dash's
   geometry became `stepsText` and `etaText`: `from_box` becomes `fromBox`,
   `close_button` becomes `close`, `total_line` becomes `total`. Do the
   conversion in one place in the generator, not by hand.

- [ ] **Step 1: Write the failing test**

Add to `test/tools/test_make_art.py`:

```python
    def test_planner_geometry_reaches_the_addon_whole(self):
        """Both layouts, the same keys, and every number still normalised."""
        import tools.make_art as make_art
        g = make_art.planner_geometry_lua()
        self.assertIn("wide", g)
        self.assertIn("tall", g)
        self.assertEqual(set(g["wide"]) - {"canvas"}, set(g["tall"]) - {"canvas"})
        self.assertEqual(g["wide"]["canvas"], {"w": 1600, "h": 1024})
        self.assertEqual(g["tall"]["canvas"], {"w": 1024, "h": 1600})
        for layout in ("wide", "tall"):
            for key, box in g[layout].items():
                if key == "canvas":
                    continue
                for edge, value in box.items():
                    self.assertGreaterEqual(value, 0.0, "{0}.{1}.{2}".format(layout, key, edge))
                    self.assertLessEqual(value, 1.0, "{0}.{1}.{2}".format(layout, key, edge))

    def test_planner_geometry_drops_the_tools_alias(self):
        """tools_button is close_button under another name.

        Codex shipped it for schema compatibility and said plainly: never draw
        it twice. A key that must not be instantiated has no business reaching
        the addon, where somebody will wire it to a second button sitting
        exactly on top of Close.
        """
        import tools.make_art as make_art
        g = make_art.planner_geometry_lua()
        self.assertNotIn("toolsButton", g["wide"])
        self.assertIn("closeButton", g["wide"])

    def test_planner_geometry_names_are_camel_case(self):
        import tools.make_art as make_art
        g = make_art.planner_geometry_lua()
        for key in g["wide"]:
            self.assertNotIn("_", key, "{0} still carries the file's underscores".format(key))
        self.assertIn("fromBox", g["wide"])
        self.assertIn("strip", g)
        self.assertIn("nodeDiameter", g["strip"])
```

- [ ] **Step 2: Run to verify it fails**

```bash
python -m unittest discover -s test/tools
```

Expected: FAIL, `module 'tools.make_art' has no attribute 'planner_geometry_lua'`.

- [ ] **Step 3: Write the generator function**

In `tools/make_art.py`, beside the existing `GEOMETRY` constant add:

```python
PLANNER_GEOMETRY = SOURCE / "planner-geometry.json"
```

and beside `geometry_lua()` add:

```python
def planner_geometry():
    with open(PLANNER_GEOMETRY, encoding="utf-8") as handle:
        return json.load(handle)


# Keys the addon should never see. tools_button is a byte-identical alias of
# close_button, shipped for schema compatibility with an explicit instruction
# not to draw it twice; letting it through would invite a second button sitting
# exactly on top of Close.
PLANNER_DROP = {"tools_button"}


def _camel(name):
    """from_box -> fromBox, close_button -> closeButton, total_line -> totalLine.

    Nothing is stripped. An earlier draft dropped the trailing _button and
    _line as noise, which turned close_button into close and layout_button into
    layout -- and "layout" beside a variable already called `mode` reads as the
    wrong thing entirely. Converting and nothing else means a key in the
    artist's file and a key in the addon differ by exactly one rule.
    """
    head, _, tail = name.partition("_")
    while tail:
        head = head + tail[:1].upper() + tail[1:].partition("_")[0]
        tail = tail.partition("_")[2]
    return head


def planner_geometry_lua():
    """The planner's placement numbers, as plain fractions.

    Everything Planner.lua positions comes from here. The addon never
    hand-types a coordinate, so a change in the art reaches the layout by
    regenerating this file rather than by editing Lua.
    """
    g = planner_geometry()
    out = {}
    for layout in ("wide", "tall"):
        source = g[layout]
        # canvas is source pixels, the one exception to the 0..1 rule.
        box = {"canvas": {"w": source["canvas"][0], "h": source["canvas"][1]}}
        for key, rect in source.items():
            if key == "canvas" or key in PLANNER_DROP:
                continue
            box[_camel(key)] = dict(rect)
        out[layout] = box
    strip = g["strip"]
    out["strip"] = {
        "nodeDiameter": strip["node_diameter"],
        "lineThickness": strip["line_thickness"],
        "labelGap": strip["label_gap"],
    }
    return out
```

Add `import json` at the top of the file if it is not already there.

Then find where the generator writes `ns.Data.ArtGeometry` and give it the
planner table as a sibling key. The dash's geometry currently becomes the whole
of `ns.Data.ArtGeometry`; it must not change shape, because `Dash.lua` reads
`ns.Data.ArtGeometry.glass` and friends directly. So write:

```lua
ns.Data.ArtGeometry = { ...the dash keys, unchanged..., planner = { ... } }
```

The existing dash keys stay exactly where they are. Only a new `planner` key
appears. Verify that by running the Lua suite in Step 4 — a change to the dash's
geometry shape breaks its 258 tests immediately.

- [ ] **Step 4: Regenerate and run everything**

```bash
python tools/make_art.py
```

```bash
python -m unittest discover -s test/tools
```

```bash
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```

Expected: Python tests pass; Lua stays at 258 passed, 0 failed. If any dash
test fails, the dash's geometry moved — put it back.

- [ ] **Step 5: Have `check_art.py` verify the planner geometry against pixels**

`check_art.py` already has `geometry_holds()`, which checks the dash geometry
against the actual art. Add the planner's equivalent: for each layout, open the
matching frame PNG and assert every rectangular box lands entirely on
**transparent** pixels — inside the frame's interior opening, never on the
brass. A box on the brass means text drawn on metal.

```python
def planner_geometry_holds():
    """Every content box must sit inside the frame's interior opening.

    Codex's own build script checks this and passes; checking it here too
    means a later hand-edit of the geometry cannot slip past us.
    """
    import json
    with open(PARTS / "planner-geometry.json", encoding="utf-8") as handle:
        g = json.load(handle)
    problems = []
    frames = {"wide": "planner-frame-wide.png", "tall": "planner-frame-tall.png"}
    for layout, filename in frames.items():
        im = Image.open(PARTS / filename).convert("RGBA")
        width, height = im.size
        alpha = im.split()[3]
        for key, rect in g[layout].items():
            if key == "canvas" or "left" not in rect:
                continue
            box = (int(rect["left"] * width), int(rect["top"] * height),
                   int(rect["right"] * width), int(rect["bottom"] * height))
            pixels = list(alpha.crop(box).getdata())
            opaque = sum(1 for value in pixels if value > 200)
            if opaque:
                problems.append("{0}.{1}: {2} opaque frame pixels under it".format(
                    layout, key, opaque))
    return problems
```

Call it from `main()` alongside the dash's check and fold its problems into the
existing counters.

- [ ] **Step 6: Run the art check**

```bash
python tools/check_art.py
```

Expected: `47 pass, 0 with problems, 0 not drawn yet`. This has been verified by
hand already: every content box in both layouts sits at 0% opaque frame pixels.
If the new check reports a problem, the check is wrong, not the geometry —
find the bug before changing any number.

- [ ] **Step 7: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 8: Commit**

```bash
git add tools/make_art.py tools/check_art.py test/tools/test_make_art.py GoblinPS/Data/Art.lua
git commit -m "Generate the planner geometry into Art.lua" -m "Both layouts reach the addon as ns.Data.ArtGeometry.planner, with the tools_button alias dropped on the way in so nobody can wire a second button on top of Close." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---


# Planner Window Art Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The planner window wears the art Codex drew for it, with every
position read from a generated geometry file rather than hand-typed.

**Architecture:** Sixteen PNGs become shipped TGAs through the existing
`tools/make_art.py`; `images/parts/planner-geometry.json` becomes
`ns.Data.ArtGeometry.planner` in the same generated `Data/Art.lua` the dash
already reads; `Planner.lua` stops positioning widgets with arithmetic
constants and reads every box, centre and radius from that table. Three
placement helpers move out of `Dash.lua` into `Widgets.lua` so both windows
share one implementation of the rules that were learned the hard way.

**Tech Stack:** Plain Lua 5.1 against the Blizzard API on WoW Forever beta
build 1.60.1.69913 (interface `16001`), no libraries, no Blizzard frame
templates. Python 3 with Pillow for the art pipeline. Tests run on the desktop
through `lupa` and `unittest`.

**Spec:** `docs/superpowers/specs/2026-09-19-goblinps-design.md`

**Art brief and its answers:** `docs/art-parts-brief-planner.md` and
`images/parts/QUESTIONS.md`. Read both. The geometry file is
`images/parts/planner-geometry.json`, and `images/parts/build_planner_geometry.py`
regenerates it.

## Why the route strip is not in this plan

The strip is plan 7. It draws inside the `screen` rectangle this plan places,
using node, line and icon parts this plan does not ship. `CLAUDE.md` says each
plan is written after the one before it has been used in game, and this art has
never been on screen. Laying the strip against coordinates nobody has looked at
is exactly the mistake that cost plan 4 two client runs and plan 5 one.

When this plan is done the screen shows what it shows today — the notes line,
the known-flight-paths line and the faint "GoblinPS" watermark — inside its
proper opening, on its proper backdrop.

## Global Constraints

- **No libraries.** No Ace3, no vendored libs. Plain Lua 5.1.
- **No Blizzard frame templates.** Plain frames and colour textures only.
- **No secure code.** No casting, no combat lockdown, no protected frames.
- **`API.lua` is the only file that calls Blizzard game APIs** or registers
  game-data events. `Planner.lua` may touch `CreateFrame`, `UIParent` and
  `UISpecialFrames` only.
- **Never read a size from a frame that only inherits one.** A frame sized by
  `SetAllPoints` has no resolved size until the client's layout pass, so
  `GetWidth()` on one during `build()` answers **0**. Measure the frame that
  was given an explicit `SetSize`. This reached the client on 2026-09-20 after
  257 tests passed.
- **A test that checks how big a thing is cannot tell you it is in the wrong
  place.** Pin both.
- **Every FontString gets two horizontal anchors** (or a width) and a decided
  wrap-or-truncate.
- **A missing texture must leave a working window.** Every `SetTexture` return
  value is used; art is laid over colours that still work without it.
- **No coordinate may be hand-typed in `Planner.lua`.** Every position comes
  from `ns.Data.ArtGeometry.planner`. A literal offset or size in the layout is
  a defect even if it looks right.
- **Generated files are never hand-edited.** `GoblinPS/Data/Art.lua` and
  `GoblinPS/Media/*.tga` come from `tools/make_art.py`.
- **Zero luacheck warnings, zero language-server warnings, no lint
  suppression.**
- **Route text stays plain.** Jokes live in the frame, the tagline and the
  tooltips, never in the directions.
- **Calendar versions in the TOC only.** This plan ships `2026.09.21`.

## Gates — every task runs all of these before committing

```bash
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```

```bash
python -m unittest discover -s test/tools
```

```bash
python tools/check_art.py
```

luacheck, from PowerShell:

```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
$env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
```

Language server: `lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=<file.json>`

**Baseline to match or beat: 258 Lua tests, 37 Python tests, `check_art`
47 pass / 0 problems / 0 not drawn, luacheck 0 warnings in 38 files, language
server clean.**

## File structure

| File | Responsibility | Task |
|---|---|---|
| `tools/make_art.py` | Ships the sixteen planner PNGs as TGAs; copies the planner geometry into `Data/Art.lua` | 1, 2 |
| `tools/check_art.py` | Knows the new parts; checks the planner geometry against the frame pixels | 1, 2 |
| `GoblinPS/Data/Art.lua` | GENERATED. Gains sixteen part entries and `ns.Data.ArtGeometry.planner` | 1, 2 |
| `GoblinPS/Media/*.tga` | GENERATED. Sixteen new textures | 1 |
| `GoblinPS/Widgets.lua` | Gains the three shared placement helpers and the three-slice stretcher | 3, 5 |
| `GoblinPS/Dash.lua` | Its private `placeLine` migrates to the shared helper | 3 |
| `GoblinPS/Planner.lua` | Wears the art; every position from geometry | 4, 5 |
| `GoblinPS/GoblinPS.toc` | Version | 5 |
| `test/tools/test_make_art.py` | Generator tests | 1, 2 |
| `test/test_ui.lua` | Planner and widget tests | 3, 4, 5 |
| `docs/` + `CLAUDE.md` | Spec, checklist, status | 6 |

---

### Task 1: Ship the sixteen planner parts

**Files:**
- Modify: `tools/make_art.py`
- Modify: `tools/check_art.py`
- Test: `test/tools/test_make_art.py`
- Generated: `GoblinPS/Data/Art.lua`, `GoblinPS/Media/*.tga`

**Interfaces:**
- Consumes: the PNGs already in `images/parts/`.
- Produces, for Tasks 4 and 5: `ns.Data.Art["planner-frame-wide"]` and fifteen
  siblings, each `{ file = <name>, l, r, t, b }` — the same shape the dash
  parts already have, where `l, r, t, b` crop the power-of-two padding away.

**Which sixteen, and why not thirty-four.** The strip's parts (`node-current`,
`node-destination`, `node-ring`, `line-solid`, `line-dashed`, `line-dot` and
the twelve `icon-*`) belong to plan 7 and are not shipped here. Shipping a
texture nothing draws is weight in the addon for no picture on screen.

**The sizes, and the reasoning.** `make_art.py` scales each source PNG to the
size it actually draws at, then pads up to a power-of-two canvas. A `Part`'s
width and height must keep the source's aspect ratio or the art distorts. The
window draws at `650x416` and `384x600` (Task 4 sets that), so:

| Part | Source | Draws at about | `Part(...)` | Padded canvas |
|---|---|---|---|---|
| `planner-frame-wide` | 1600x1024 | 650x416 | 650, 416 | 1024x512 |
| `planner-frame-tall` | 1024x1600 | 384x600 | 384, 600 | 512x1024 |
| `planner-panel` | 512x512 | interior backing | 256, 256 | 256x256 |
| `screen-backdrop` | 1600x640 | 762x352 | 512, 205 | 512x256 |
| `title-plate` | 1024x256 | 260x65 | 256, 64 | 256x64 |
| `tagline-plate` | 512x128 | 130x32 | 128, 32 | 128x32 |
| `input-box` | 1024x128 | 187 to 245 wide | 256, 32 | 256x32 |
| `dropdown-button` | 128x128 | 31 | 32, 32 | 32x32 |
| `button` | 768x192 | 65 to 135 wide | 128, 32 | 128x32 |
| `button-hover` | 768x192 | as `button` | 128, 32 | 128x32 |
| `button-pressed` | 768x192 | as `button` | 128, 32 | 128x32 |
| `button-disabled` | 768x192 | as `button` | 128, 32 | 128x32 |
| `close` | 192x192 | 31 | 32, 32 | 32x32 |
| `close-hover` | 192x192 | 31 | 32, 32 | 32x32 |
| `gear` | 192x192 | 31 | 32, 32 | 32x32 |
| `gear-hover` | 192x192 | 31 | 32, 32 | 32x32 |

Two of those are deliberate judgements, not arithmetic:

- **The two frames are shipped at full drawn size** and pad to 1024x512 and
  512x1024, about 2 MB each. `GoblinPS/Media` grows from 3.5 MB to roughly
  8 MB. This is the main window and brass detail shows when it is soft; the
  weight is worth it. If the reviewer disagrees, the cheaper option is
  `Part(500, 320)` and `Part(320, 500)`, which pad to 512x512 and cost 1 MB
  each at the price of a 1.3x upscale.
- **`screen-backdrop` is shipped small on purpose.** It is out-of-focus
  scenery behind text, drawn at 762 wide from a 512-wide texture. Softness
  there is invisible and 2 MB of sharp wallpaper is not worth carrying.

Note `screen-backdrop` at `Part(512, 205)`: 1600/640 is 2.5, and 512/205 is
2.4976, the closest integer height that keeps the aspect within a quarter of a
percent. Do not round it to 256, which would stretch the scenery.

- [ ] **Step 1: Write the failing test**

Add to `test/tools/test_make_art.py`:

```python
    def test_ships_the_planner_parts_at_their_source_aspect(self):
        """A Part whose aspect differs from its PNG's distorts the art.

        The frames are the whole window; a frame stretched by a few percent
        is the fault that made the dash's first design render as an oval,
        and it took a client run to see it.
        """
        from PIL import Image
        import tools.make_art as make_art
        wanted = {
            "planner-frame-wide", "planner-frame-tall", "planner-panel",
            "screen-backdrop", "title-plate", "tagline-plate", "input-box",
            "dropdown-button", "button", "button-hover", "button-pressed",
            "button-disabled", "close", "close-hover", "gear", "gear-hover",
        }
        by_name = {p.name: p for p in make_art.PARTS}
        missing = wanted - set(by_name)
        self.assertEqual(missing, set(), "these planner parts are not shipped")
        for name in sorted(wanted):
            part = by_name[name]
            with Image.open(make_art.SOURCE / (name + ".png")) as im:
                sw, sh = im.size
            source = sw / sh
            shipped = part.width / part.height
            self.assertLess(
                abs(source - shipped) / source, 0.005,
                "{0}: source aspect {1:.4f} but shipped {2:.4f}".format(
                    name, source, shipped))

    def test_does_not_ship_the_strip_parts_yet(self):
        """They belong to plan 7. A texture nothing draws is dead weight."""
        import tools.make_art as make_art
        names = {p.name for p in make_art.PARTS}
        for name in ("node-current", "line-solid", "icon-walk"):
            self.assertNotIn(name, names)
```

- [ ] **Step 2: Run to verify it fails**

```bash
python -m unittest discover -s test/tools
```

Expected: FAIL on `test_ships_the_planner_parts_at_their_source_aspect` with
"these planner parts are not shipped" naming all sixteen.

- [ ] **Step 3: Add the parts**

In `tools/make_art.py`, after the `PARTS +=` block for the dash's second
design, add:

```python
# The planner window. The two frames are the whole window and ship at full
# drawn size because brass detail shows when it is soft; screen-backdrop is
# out-of-focus scenery behind text and ships small on purpose. Every width and
# height here keeps its source PNG's aspect ratio: a frame stretched by a few
# percent is what made the dash's first design render as an oval.
# The strip's nodes, lines and icons are plan 7 and are not shipped yet.
PARTS += [
    Part("planner-frame-wide", 650, 416),
    Part("planner-frame-tall", 384, 600),
    Part("planner-panel", 256, 256),
    Part("screen-backdrop", 512, 205),   # 1600/640 is 2.5; 512/205 is 2.4976
    Part("title-plate", 256, 64),
    Part("tagline-plate", 128, 32),
    Part("input-box", 256, 32),
    Part("dropdown-button", 32, 32),
    Part("button", 128, 32),
    Part("button-hover", 128, 32),
    Part("button-pressed", 128, 32),
    Part("button-disabled", 128, 32),
    Part("close", 32, 32),
    Part("close-hover", 32, 32),
    Part("gear", 32, 32),
    Part("gear-hover", 32, 32),
]
```

- [ ] **Step 4: Run the generator and the tests**

```bash
python tools/make_art.py
```

```bash
python -m unittest discover -s test/tools
```

Expected: the generator prints a part count of 29 and a larger total size; the
Python tests pass. Then confirm the sixteen TGAs exist and `Art.lua` grew:

```bash
git status --porcelain GoblinPS/Media GoblinPS/Data/Art.lua
```

Expected: sixteen new `??` lines under `Media/` and one `M` on `Art.lua`.

- [ ] **Step 5: Confirm `check_art.py` needs no change**

`tools/check_art.py` already carries all 47 parts in its `SPEC` table,
including every planner part, with flags describing each — note
`planner-panel.png` is flagged as tiling and `screen-backdrop.png` as solid.
It checks the delivered PNGs, which arrived long before this plan; what ships
as a TGA is a separate question it does not ask. **Make no edit here.**

Run it and confirm nothing moved:

```bash
python tools/check_art.py
```

Expected: `47 pass, 0 with problems, 0 not drawn yet` — unchanged, because all
47 PNGs were already being checked. If the count moves, something was renamed;
stop and find out what.

- [ ] **Step 6: Lint**

Run luacheck and the language server. Expected: zero warnings. (`Art.lua` is
generated Lua and is linted like any other file.)

- [ ] **Step 7: Commit**

```bash
git add tools/make_art.py tools/check_art.py test/tools/test_make_art.py GoblinPS/Data/Art.lua GoblinPS/Media
git commit -m "Ship the sixteen planner parts" -m "Every Part keeps its source PNG's aspect ratio, checked by a test: a frame stretched by a few percent is what made the dash's first design render as an oval. The strip's parts stay unshipped until plan 7 draws them." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

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

### Task 3: Three shared placement helpers, and Dash moved onto them

**Files:**
- Modify: `GoblinPS/Widgets.lua`
- Modify: `GoblinPS/Dash.lua`
- Test: `test/test_ui.lua`

**Interfaces:**
- Produces, for Tasks 4 and 5:

```lua
W.PlaceRect(region, device, rect)   -- corner to corner; rect is {left, top, right, bottom}
W.PlaceLine(fs, device, rect)       -- LEFT/RIGHT on the rect's vertical centre
W.PlaceCircle(region, device, circ) -- square, side = 2 * r * device width, CENTER on (cx, cy)
```

`device` is always the frame with an explicit `SetSize`. `rect` fractions have
their origin at the top left, which is how both geometry files state every box.

**Why this task exists.** `Dash.lua` has a private `placeLine` carrying a
comment earned in the client on 2026-09-20. `Planner.lua` needs the same
function plus two siblings. Two copies means the next person fixes one of them.
`Widgets.lua` is the shared palette and is where this belongs.

**Why it is safe.** `placeLine` is seven lines and the dash has a test that
fails when it is wrong — verified today by reverting the fix and watching two
placement tests fail. Those 258 tests are the net for this migration.

- [ ] **Step 1: Write the failing test**

Add a new block to `test/test_ui.lua`, beside the existing widget tests:

```lua
    h.describe("the shared placement helpers", function()
        local function device(w, h2)
            local f = CreateFrame("Frame", nil, UIParent)
            f:SetSize(w, h2)
            return f
        end

        h.it("places a rectangle corner to corner from the device's top left", function()
            local f = device(200, 100)
            local t = f:CreateTexture(nil, "ARTWORK")
            W.PlaceRect(t, f, { left = 0.1, top = 0.2, right = 0.6, bottom = 0.7 })
            h.eq(#t.points, 2, "two corners fully place a region")
            h.eq(t.points[1][1], "TOPLEFT")
            h.eq(t.points[1][3], "TOPLEFT", "offsets are from the device's corner")
            h.truthy(math.abs(t.points[1][4] - 20) < 0.01, "left 0.1 of 200")
            h.truthy(math.abs(t.points[1][5] + 20) < 0.01, "top 0.2 of 100, downward")
            h.eq(t.points[2][1], "BOTTOMRIGHT")
            h.truthy(math.abs(t.points[2][4] - 120) < 0.01, "right 0.6 of 200")
            h.truthy(math.abs(t.points[2][5] + 70) < 0.01, "bottom 0.7 of 100")
        end)

        h.it("hangs a line on its rect's centre, letting the font set the height", function()
            -- The artist's *_line rects are a few pixels tall: slots to sit on,
            -- not boxes to fit in. Anchoring one corner to corner crushes the
            -- text into a box it cannot fit.
            local f = device(200, 100)
            local fs = W.Text(f, "green")
            W.PlaceLine(fs, f, { left = 0.1, top = 0.4, right = 0.9, bottom = 0.44 })
            h.eq(#fs.points, 2, "two horizontal anchors, so it still truncates")
            h.eq(fs.points[1][1], "LEFT")
            h.eq(fs.points[2][1], "RIGHT")
            h.truthy(math.abs(fs.points[1][5] + 42) < 0.01, "centre of 0.40..0.44 of 100")
            h.eq(fs.points[1][5], fs.points[2][5], "both ends sit on one line")
        end)

        h.it("makes a circle square and sizes it from the device's width", function()
            -- A radius measured against two different axes stops being a
            -- circle. Width, always, on both layouts.
            local f = device(200, 100)
            local t = f:CreateTexture(nil, "ARTWORK")
            W.PlaceCircle(t, f, { cx = 0.5, cy = 0.25, r = 0.1 })
            h.eq(t:GetWidth(), t:GetHeight(), "a circle is drawn on a square")
            h.truthy(math.abs(t:GetWidth() - 40) < 0.01, "2 * 0.1 * 200")
            h.eq(t.points[1][1], "CENTER")
            h.truthy(math.abs(t.points[1][4] - 100) < 0.01)
            h.truthy(math.abs(t.points[1][5] + 25) < 0.01)
        end)

        h.it("never reads a size from a frame that only inherits one", function()
            -- The fault that reached the client on 2026-09-20. A frame sized
            -- by SetAllPoints has no resolved size until the layout pass, so
            -- every fraction would be multiplied by nothing.
            local f = device(200, 100)
            local child = CreateFrame("Frame", nil, f)
            child:SetAllPoints(f)
            local fs = W.Text(child, "green")
            W.PlaceLine(fs, f, { left = 0.1, top = 0.4, right = 0.9, bottom = 0.44 })
            h.truthy(fs.points[1][4] > 0, "measured the device, not the child")
        end)
    end)
```

- [ ] **Step 2: Run to verify it fails**

Run the Lua suite. Expected: FAIL, `attempt to call field 'PlaceRect' (a nil value)`.

- [ ] **Step 3: Write the helpers**

In `GoblinPS/Widgets.lua`, after `Widgets.Text`:

```lua
-- ---- placement from a geometry table ----
--
-- Every one of these takes `device`: the frame with the explicit SetSize, and
-- it must be. A frame sized only by SetAllPoints has NO resolved size until
-- the client's layout pass runs, so GetWidth on one during build() answers 0.
-- Every fraction would then be multiplied by nothing and the region would
-- anchor twice to the same point. Seen in the client 2026-09-20: the dash's
-- compass and arrow sat off the device and all six lines of text were
-- invisible, while 257 tests passed. Measure and anchor the frame that was
-- given a size, never one that inherits it.
--
-- `rect` is { left, top, right, bottom } in 0..1 with the origin at the top
-- left, which is how both geometry files state every box.

function Widgets.PlaceRect(region, device, rect)
    local w, h = device:GetWidth(), device:GetHeight()
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", device, "TOPLEFT", rect.left * w, -rect.top * h)
    region:SetPoint("BOTTOMRIGHT", device, "TOPLEFT", rect.right * w, -rect.bottom * h)
end

-- A *_line rect in the artist's files is a few pixels tall: a line for text to
-- sit ON, not a box to fit text INTO -- the areas are named for what they are
-- and are sized like areas. Anchoring corner to corner crushes the text into a
-- box it cannot fit, so hang the FontString on the rect's vertical centre and
-- let its font decide the height. Two horizontal anchors still, so the
-- bounding rule holds and the line truncates rather than escaping.
function Widgets.PlaceLine(fs, device, rect)
    local w, h = device:GetWidth(), device:GetHeight()
    local y = -(rect.top + rect.bottom) / 2 * h
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", device, "TOPLEFT", rect.left * w, y)
    fs:SetPoint("RIGHT", device, "TOPLEFT", rect.right * w, y)
end

-- `circ` is { cx, cy, r }. The radius is a fraction of the device's WIDTH on
-- both layouts: a radius measured against two different axes stops being a
-- circle, which is the rule that saved the dash's compass.
function Widgets.PlaceCircle(region, device, circ)
    local w, h = device:GetWidth(), device:GetHeight()
    local side = circ.r * 2 * w
    region:SetSize(side, side)
    region:ClearAllPoints()
    region:SetPoint("CENTER", device, "TOPLEFT", circ.cx * w, -circ.cy * h)
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the Lua suite. Expected: green, 262 passed.

- [ ] **Step 5: Move `Dash.lua` onto the shared helper**

Delete the private `placeLine` from `GoblinPS/Dash.lua` — the whole function
and its comment block, since the comment now lives on `W.PlaceLine`. Replace
its four call sites with `W.PlaceLine(...)`, keeping `f` as the device argument
exactly as it is today:

```lua
        W.PlaceLine(destination, f, g.destination)
        W.PlaceLine(distance, f, g.distance)
```

and in the steps loop:

```lua
            W.PlaceLine(steps[i], f, {
```

and:

```lua
        W.PlaceLine(eta, f, g.etaText)
```

Leave `centreOnDial` alone. It predates this and does one extra thing
(`SetTexCoord` on a rotating texture); folding it into `W.PlaceCircle` is a
change worth making only when a second caller wants it.

- [ ] **Step 6: Run the tests, and prove the migration kept its teeth**

Run the Lua suite. Expected: green, 262 passed — every dash test still passing,
unchanged.

Then prove the net still catches the original fault. In a scratch copy outside
the repo, change the four `W.PlaceLine(x, f, ...)` calls back to passing
`content` (the `SetAllPoints` frame) and run the suite:

Expected: FAIL on the two dash placement tests, `sits all three step lines on
the centre of their third of the art's steps box` and `sits the destination,
distance and ETA on their own centre lines too`. If they pass, the migration
lost the protection and the helper is wrong. Delete the scratch copy afterwards.

- [ ] **Step 7: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 8: Commit**

```bash
git add GoblinPS/Widgets.lua GoblinPS/Dash.lua test/test_ui.lua
git commit -m "Three shared placement helpers, and the dash moved onto them" -m "PlaceRect, PlaceLine and PlaceCircle live in the widget palette so the planner and the dash cannot drift. The comment about never measuring a SetAllPoints frame moves with them, since that is the fault it exists to prevent." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: The planner frame and its chrome, from geometry

**Files:**
- Modify: `GoblinPS/Planner.lua`
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `ns.Data.ArtGeometry.planner` (Task 2), `W.PlaceRect`,
  `W.PlaceLine`, `W.PlaceCircle` (Task 3), `ns.Data.Art[...]` (Task 1).
- Produces, for Task 5: `ui.artLayer`, `ui.frameArt`, `ui.flat`, `ui.content`,
  and a file-local `geo()` returning the active layout's geometry table.

**The frame's own panel is the same bug the dash had.** `Planner.lua:217` is
`W.Panel(UIParent, "body", "brass", 3)`. `Widgets.Panel` lays two opaque
textures directly on that frame and returns only the frame, so nothing can ever
hide them. The planner frame art has transparent margins exactly as the dash
housing does. Fix it the same way the dash was fixed: build the frame bare and
give the no-art fallback its own hideable frame.

**Frame levels, set explicitly.** A child frame draws above every draw layer of
its parent, and within one frame and layer the later-created region wins:

| Level | Frame | Holds |
|---|---|---|
| base | `f` | nothing; it is bare |
| base | `flat` | the flat-colour fallback panel |
| base + 1 | `artLayer` | the frame art, plates, panel backing |
| base + 2 | `content` | every widget and FontString |
| base + 3 | `results` | the search overlay, which covers content |

- [ ] **Step 1: Write the failing test**

Add to the planner block in `test/test_ui.lua`:

```lua
        h.it("keeps the window at the art's exact aspect ratio", function()
            -- 1600x1024 is 25:16 and 1024x1600 is 16:25. The old 660x400 and
            -- 390x600 were 1.65 and 0.65, so the wide frame would have drawn
            -- about 6% too wide -- the fault that made the dash's first design
            -- render as an oval, which took a client run to see.
            local g = ns.Data.ArtGeometry.planner
            for _, mode in ipairs({ "wide", "tall" }) do
                local size = ns.Planner.SIZE[mode]
                local canvas = g[mode].canvas
                h.truthy(math.abs(size[1] / size[2] - canvas.w / canvas.h) < 0.001,
                         mode .. " must keep the art's aspect ratio")
            end
        end)

        h.it("carries no art of its own on the window frame", function()
            -- Widgets.Panel lays two opaque textures on the frame it makes and
            -- returns only the frame, so nothing can hide them. The planner
            -- art has transparent margins; an unhideable rectangle behind it
            -- boxes in a window that is not a rectangle. Fixed once on the
            -- dash already.
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.eq(#ui.frame.regions, 0,
                 "the window frame must own no regions; the fallback is its own frame")
            h.truthy(ui.flat, "and the fallback frame exists")
        end)

        h.it("hides the flat fallback once the frame art loads", function()
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.truthy(ui.frameArt, "the frame art loaded in the test fixture")
            h.falsy(ui.flat:IsShown(), "so the coloured rectangle goes")
        end)

        h.it("stacks the art under the content", function()
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.truthy(ui.content:GetFrameLevel() > ui.artLayer:GetFrameLevel(),
                     "nothing the player reads is ever behind the chassis")
            h.truthy(ui.results:GetFrameLevel() > ui.content:GetFrameLevel(),
                     "the search overlay covers what it drops over")
        end)

        h.it("places the chrome from the geometry, in real pixels", function()
            -- Pin the position, not just the size: a test that checks how big
            -- a thing is cannot tell you it is in the wrong place.
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout("wide")
            local ui = ns.Planner.Debug()
            local g = ns.Data.ArtGeometry.planner.wide
            local w = ui.frame:GetWidth()
            for _, name in ipairs({ "close", "gear" }) do
                local button, circ = ui[name], g[name .. "Button"]
                h.truthy(button, name .. " is missing")
                h.truthy(math.abs(button:GetWidth() - circ.r * 2 * w) < 1,
                         name .. " is sized from geometry." .. name .. "Button.r")
                h.truthy(math.abs(button.points[1][4] - circ.cx * w) < 1,
                         name .. " sits at geometry." .. name .. "Button.cx, got "
                         .. tostring(button.points[1][4]))
            end
            h.truthy(math.abs(ui.titlePlate.points[1][4] - g.titlePlate.left * w) < 1,
                     "the title plate starts where the geometry says")
        end)
```

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: FAIL on the aspect-ratio test (660/400 is 1.65,
not 1.5625), and FAIL on `carries no art of its own` with `expected "0", actual
"2"` — the two textures `Widgets.Panel` lays on the frame.

- [ ] **Step 3: Rebuild the frame and the chrome**

In `GoblinPS/Planner.lua`, replace the size constant:

```lua
-- The window's rectangle on screen. The art is 1600x1024 and 1024x1600, so
-- these keep those shapes exactly; everything inside is placed as a fraction
-- of them, from the geometry the art tool generates. Nothing here is a
-- measured guess.
Planner.SIZE = { wide = { 650, 416 }, tall = { 384, 600 } }
```

Add a file-local accessor beside the other locals:

```lua
local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"

-- The active layout's geometry, or nil when the generated table is absent.
-- Gated on the geometry alone: whether the parts shipped is a different
-- question, and answering it here would drop the whole layout to its fallback
-- while a perfectly good geometry sat there unread.
local function geo(mode)
    local g = ns.Data.ArtGeometry and ns.Data.ArtGeometry.planner
    return g and g[mode or ns.Core.Layout()]
end

-- Lay a shipped part over `parent`, cropping the power-of-two padding away.
-- Returns nil when the part is missing or the texture will not load, and every
-- caller uses that: a missing texture must leave a working window.
local function art(parent, name, layer)
    local part = ns.Data.Art and ns.Data.Art[name]
    if not part then
        return nil
    end
    local t = parent:CreateTexture(nil, layer)
    if not t:SetTexture(MEDIA .. part.file) then
        t:Hide()
        return nil
    end
    t:SetTexCoord(part.l, part.r, part.t, part.b)
    t:SetAllPoints(parent)
    return t
end
```

In `build()`, replace the opening `local f = W.Panel(UIParent, "body", "brass", 3)`
with a bare frame and a hideable fallback, and add the three stacked frames:

```lua
    -- Bare on purpose. A texture created on this frame could only be taken off
    -- screen by hiding the frame, and the window art has transparent margins,
    -- so an unhideable rectangle behind it boxes in a window that is not a
    -- rectangle. The dash unit shipped that fault once already.
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(Planner.SIZE.wide[1], Planner.SIZE.wide[2])
```

Everything else in that opening block — strata, movable, mouse, clamped, drag
scripts, `OnMouseDown`, `Hide` — stays exactly as it is.

Then, after `f:Hide()`:

```lua
    local base = f:GetFrameLevel()

    -- The flat colour is the fallback for art that will not load. It is its
    -- own frame so it can be hidden as a unit the moment the real frame art
    -- arrives.
    local flat = W.Panel(f, "body", "brass", 3)
    flat:SetAllPoints(f)
    flat:SetFrameLevel(base)

    local artLayer = CreateFrame("Frame", nil, f)
    artLayer:SetAllPoints(f)
    artLayer:SetFrameLevel(base + 1)

    local content = CreateFrame("Frame", nil, f)
    content:SetAllPoints(f)
    content:SetFrameLevel(base + 2)

    -- The window's own chassis. ApplyLayout swaps the texture between the two
    -- frames, so create it empty here and let ApplyLayout fill it.
    local frameArt = artLayer:CreateTexture(nil, "BACKGROUND")
    frameArt:SetAllPoints(artLayer)

    -- The plates carry art but are NOT SetAllPoints to their parent: each sits
    -- in its own rect, which ApplyLayout places. That is the one difference
    -- from `art()` above, and it is why they cannot use it.
    local function plate(name)
        local part = ns.Data.Art and ns.Data.Art[name]
        if not part then
            return nil
        end
        local t = artLayer:CreateTexture(nil, "ARTWORK")
        if not t:SetTexture(MEDIA .. part.file) then
            t:Hide()
            return nil
        end
        t:SetTexCoord(part.l, part.r, part.t, part.b)
        return t
    end
    local titlePlate = plate("title-plate")
    local taglinePlate = plate("tagline-plate")
```

Delete the orange `stripe` texture entirely: it was a flat-colour flourish for
a window with no art, and it draws across the top of the brass.

The title and tagline FontStrings stay, but move to `content` and lose their
hand-typed anchors — `ApplyLayout` will place them. Change their parent from
`f` to `content` and delete their `SetPoint` calls.

Replace the close and layout buttons, and add the gear:

```lua
    local close = CreateFrame("Button", nil, content)
    close:RegisterForClicks("LeftButtonUp")
    close:SetScript("OnClick", function()
        dismiss()
        f:Hide()
    end)
    local closeArt = art(close, "close", "ARTWORK")
    if not closeArt then
        W.Fill(close, "ARTWORK", "hazard")
    end
    local hover = ns.Data.Art and ns.Data.Art["close-hover"]
    if hover then
        close:SetHighlightTexture(MEDIA .. hover.file, "ADD")
    end

    -- The art has a socket beside the To box and the geometry places it, but
    -- no such control exists today: the results list only appears while you
    -- type. An empty socket reads as a fault, and a way to browse every
    -- destination without knowing its name is worth having, so the button
    -- opens the same list with an empty query.
    local dropdown = CreateFrame("Button", nil, content)
    dropdown:RegisterForClicks("LeftButtonUp")
    dropdown:SetScript("OnClick", function()
        if ui.results:IsShown() and ui.results.owner == ui.toBox then
            hideResults()
        else
            showResults(ui.toBox)
        end
    end)
    local dropdownArt = art(dropdown, "dropdown-button", "ARTWORK")
    if not dropdownArt then
        W.Fill(dropdown, "ARTWORK", "steel")
    end

    -- The gear opens settings, which is a later plan. It is drawn and placed
    -- now because the art has a socket for it and an empty socket reads as a
    -- fault; it says so when clicked rather than doing nothing.
    local gear = CreateFrame("Button", nil, content)
    gear:RegisterForClicks("LeftButtonUp")
    gear:SetScript("OnClick", function()
        ns.Core.Say("Settings are not built yet.")
    end)
    local gearArt = art(gear, "gear", "ARTWORK")
    if not gearArt then
        W.Fill(gear, "ARTWORK", "steel")
    end
    local gearHover = ns.Data.Art and ns.Data.Art["gear-hover"]
    if gearHover then
        gear:SetHighlightTexture(MEDIA .. gearHover.file, "ADD")
    end
```

Keep `layoutButton` as a `W.Button` — it carries a runtime "Wide"/"Tall" label
and the existing widget already draws one. Delete its `SetPoint`.

**There is no tools button.** `close.png` is the crossed-wrench X, and the
geometry's `tools_button` was an alias that Task 2 dropped before it reached
the addon. Do not create a second control.

Extend the `ui` table with the new names: `artLayer`, `content`, `flat`,
`frameArt`, `titlePlate`, `taglinePlate`, `close`, `gear`, `dropdown`,
`title` and `tagline`. The last two already exist as locals in `build()` but
have never been on the `ui` table, and `ApplyLayout` now places them.

`showResults` and `hideResults` are declared above `build()` already, so the
dropdown's handler can call them. `candidatesFor` returns every candidate when
the box is empty, which is what makes an empty query list everything.

- [ ] **Step 4: Place the chrome in `ApplyLayout`**

`ApplyLayout` is the only function that differs between the two shapes, and it
is now the only place any coordinate appears. Replace its body:

```lua
function Planner.ApplyLayout(mode)
    if not ui then
        return
    end
    mode = (mode == "tall") and "tall" or "wide"
    local size = Planner.SIZE[mode]
    local f = ui.frame
    -- The explicit size first, before anything reads it: every helper below
    -- measures this frame, and a frame with no size measures 0.
    f:SetSize(size[1], size[2])

    local part = ns.Data.Art and ns.Data.Art["planner-frame-" .. mode]
    if part and ui.frameArt:SetTexture(MEDIA .. part.file) then
        ui.frameArt:SetTexCoord(part.l, part.r, part.t, part.b)
        ui.frameArt:Show()
        ui.flat:Hide()
    else
        ui.frameArt:Hide()
        ui.flat:Show()
    end

    local g = geo(mode)
    if g then
        W.PlaceRect(ui.titlePlate, f, g.titlePlate)
        W.PlaceRect(ui.taglinePlate, f, g.taglinePlate)
        W.PlaceLine(ui.title, f, g.titlePlate)
        W.PlaceLine(ui.tagline, f, g.taglinePlate)
        W.PlaceCircle(ui.close, f, g.closeButton)
        W.PlaceCircle(ui.gear, f, g.gearButton)
        W.PlaceCircle(ui.dropdown, f, g.dropdownButton)
        W.PlaceRect(ui.layoutButton, f, g.layoutButton)
    end

    ui.layoutButton.label:SetText(mode == "tall" and "Wide" or "Tall")
end
```

`plate()` returns nil when a part is missing, so guard the two plate
placements with `if ui.titlePlate then` and `if ui.taglinePlate then`. The two
FontStrings always exist and are always placed.

Task 5 adds its placements **inside this same `if g then` block**, not in a
second one: one block, one condition, one place to look.

- [ ] **Step 5: Run the tests to verify they pass**

Run the Lua suite. Expected: green. The planner's existing tests must still
pass; if one of them reads a widget that moved, the read may change and the
assertion may not.

- [ ] **Step 6: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 7: Commit**

```bash
git add GoblinPS/Planner.lua test/test_ui.lua
git commit -m "The planner frame wears its art, placed from the geometry" -m "The window is bare, its fallback is a frame that can be hidden, and its size matches the art's aspect ratio exactly -- three faults the dash unit found in the client, fixed here before this one has been seen at all." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Inputs, screen, side panel and footer

**Files:**
- Modify: `GoblinPS/Planner.lua`
- Modify: `GoblinPS/Widgets.lua`
- Modify: `GoblinPS/GoblinPS.toc` (version `2026.09.21`)
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: everything Tasks 1 to 4 produced.
- Produces: nothing later in this plan depends on it.

**Three-slice stretching, and why it is needed.** One `button` part draws at 65
pixels wide for "Here" and 135 for GO, and one `input-box` draws at 187 and
245. Stretching the whole texture squashes the decorative end caps at one width
and stretches them at another. Codex said so plainly: "Input/button art needs
fixed end caps." So: draw three textures from one part — a left cap at its
natural width, a right cap at its natural width, and a middle stretched between
them.

**The backdrop is an insert, not a layer.** This is the opposite of the rule
the dash taught. `screen-backdrop` is 1600x640 scenery that must cover the
`screen` rectangle without distorting: scale to cover, centre-crop the
overflow, clip to the rectangle. All three happen in one `SetTexCoord`, with no
clipping frame and no new API — but the crop must compose with the padding crop
the part already carries, or it crops the wrong thing.

- [ ] **Step 1: Write the failing test**

Add to the planner block in `test/test_ui.lua`:

```lua
        h.it("covers the screen with the backdrop without distorting it", function()
            -- screen-backdrop is 2.5:1 scenery and the screen opening is not.
            -- Stretching it to fit would squash the mountains; the answer is
            -- to crop the overflow, centred, inside the part's own texture
            -- coordinates.
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout("wide")
            local ui = ns.Planner.Debug()
            h.truthy(ui.backdrop, "the backdrop texture exists")
            local l, r, t, b = unpack(ui.backdrop.texCoord)
            local part = ns.Data.Art["screen-backdrop"]
            h.truthy(l >= part.l - 0.0001 and r <= part.r + 0.0001,
                     "the cover-crop stays inside the part's own padding crop")
            h.truthy(math.abs((l - part.l) - (part.r - r)) < 0.0001,
                     "the crop is centred: equal slivers off each side")
            h.truthy(r - l < part.r - part.l,
                     "2.5:1 scenery in a wider-than-tall-but-not-2.5 opening loses width")
        end)

        h.it("gives a stretched control fixed end caps", function()
            -- One button part draws at 65 px for Here and 135 for GO. A single
            -- stretched texture squashes the caps at one width and stretches
            -- them at the other.
            local f = CreateFrame("Frame", nil, UIParent)
            f:SetSize(200, 40)
            -- button.png is 768x192, so a quarter of its width is a 192x192
            -- cap: aspect 1.
            local slice = W.Stretch3(f, "button", 0.25, 1.0)
            h.truthy(slice, "three-slice returns its pieces")
            h.eq(slice.left:GetWidth(), slice.right:GetWidth(),
                 "both caps draw at the same natural width")
            h.truthy(slice.middle.points and #slice.middle.points >= 2,
                     "the middle is anchored between the caps, so it takes the slack")
        end)

        h.it("places every input, panel and footer line from the geometry", function()
            ns.Planner.Toggle()
            for _, mode in ipairs({ "wide", "tall" }) do
                ns.Planner.ApplyLayout(mode)
                local ui = ns.Planner.Debug()
                local g = ns.Data.ArtGeometry.planner[mode]
                local w = ui.frame:GetWidth()
                local checks = {
                    { ui.fromBox, g.fromBox, "fromBox" },
                    { ui.toBox, g.toBox, "toBox" },
                    { ui.here, g.hereButton, "hereButton" },
                    { ui.screen, g.screen, "screen" },
                    { ui.side, g.sidePanel, "sidePanel" },
                    { ui.go, g.goButton, "goButton" },
                }
                for _, check in ipairs(checks) do
                    local region, rect, name = check[1], check[2], check[3]
                    h.truthy(region, mode .. ": " .. name .. " is missing")
                    h.truthy(math.abs(region.points[1][4] - rect.left * w) < 1,
                             mode .. ": " .. name .. " starts at its rect's left, got "
                             .. tostring(region.points[1][4]))
                end
                -- The two footer lines are lines, so they carry two horizontal
                -- anchors on one y, not four corners.
                for _, fs in ipairs({ ui.total, ui.hint }) do
                    h.eq(#fs.points, 2)
                    h.eq(fs.points[1][5], fs.points[2][5], "both ends sit on one line")
                end
            end
        end)

        h.it("keeps working when not one texture loads", function()
            -- Art is laid over colours. A beta patch that renames a file must
            -- leave a window the player can still route with.
            local restore = ns.Data.Art
            ns.Data.Art = nil
            local ok = pcall(function()
                ns.Planner.Toggle()
                ns.Planner.ApplyLayout("wide")
            end)
            ns.Data.Art = restore
            h.truthy(ok, "building with no art at all must not error")
            local ui = ns.Planner.Debug()
            h.truthy(ui.flat:IsShown(), "and the flat fallback comes back")
        end)
```

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: FAIL, `ui.backdrop` is nil and
`W.Stretch3` is nil.

- [ ] **Step 3: Write the three-slice stretcher**

In `GoblinPS/Widgets.lua`, after the placement helpers:

```lua
-- Draw one part as three textures so its decorative ends keep their shape at
-- any width: a left cap and a right cap at their natural size, and a middle
-- stretched between them. One button part draws at 65 pixels for "Here" and
-- 135 for "GO"; stretching the whole texture squashes the caps at one width
-- and stretches them at the other.
--
-- `capFraction` is how much of the part's width each cap takes, and
-- `capAspect` is that cap region's width over its height in the source art.
-- Both are read off the artwork, because the geometry file describes where
-- controls go and not how they are built. They are the only two hand-typed art
-- numbers in this plan; a squashed end cap is visible in one look, and the
-- checklist asks for that look.
--
-- Returns { left, middle, right }, or nil when the part is missing or will not
-- load -- and every caller uses that, because a missing texture must leave a
-- working control.
function Widgets.Stretch3(parent, name, capFraction, capAspect)
    local part = ns.Data.Art and ns.Data.Art[name]
    if not part then
        return nil
    end
    local path = "Interface\\AddOns\\GoblinPS\\Media\\" .. part.file
    local span = part.r - part.l
    local cap = span * capFraction
    -- The cap keeps the shape it was drawn at: its drawn width is its own
    -- aspect times the control's height, so it never squashes.
    local width = parent:GetHeight() * capAspect

    local function piece(l, r)
        local t = parent:CreateTexture(nil, "ARTWORK")
        if not t:SetTexture(path) then
            return nil
        end
        t:SetTexCoord(l, r, part.t, part.b)
        return t
    end

    local left, middle, right = piece(part.l, part.l + cap),
                                piece(part.l + cap, part.r - cap),
                                piece(part.r - cap, part.r)
    if not (left and middle and right) then
        return nil
    end
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    left:SetWidth(width)
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(width)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    return { left = left, middle = middle, right = right }
end
```

- [ ] **Step 4: Write the backdrop's cover-crop**

In `GoblinPS/Planner.lua`, above `ApplyLayout`:

```lua
-- Cover `rect` (in device fractions) with a part whose own aspect differs,
-- losing the overflow evenly off both sides rather than distorting the art.
-- The crop composes with the part's padding crop: the part's artwork lives in
-- l..r of its texture, so the cover-crop takes a centred sub-range of THAT,
-- never of 0..1. Getting this backwards crops the padding instead of the art.
--
-- screen-backdrop is decorative scenery, not a map. Losing its sides is
-- intended.
local function coverCrop(texture, part, partW, partH, boxW, boxH)
    local span = part.r - part.l
    local tall = part.b - part.t
    local partAspect = (partW * span) / (partH * tall)
    local boxAspect = boxW / boxH
    if partAspect > boxAspect then
        -- The art is wider than the opening: keep a centred slice of width.
        local keep = span * (boxAspect / partAspect)
        local trim = (span - keep) / 2
        texture:SetTexCoord(part.l + trim, part.r - trim, part.t, part.b)
    else
        local keep = tall * (partAspect / boxAspect)
        local trim = (tall - keep) / 2
        texture:SetTexCoord(part.l, part.r, part.t + trim, part.b - trim)
    end
end
```

`partW` and `partH` are the part's **source** pixel dimensions, 1600 and 640
for `screen-backdrop`. Put them in the call rather than in the helper: the
helper knows nothing about which part it is given.

- [ ] **Step 5: Place the rest of the window**

In `build()`, give the screen a backdrop texture and the side panel a backing,
both on `artLayer` so they sit under the content:

```lua
    local backdrop = artLayer:CreateTexture(nil, "BORDER")
    local backdropPart = ns.Data.Art and ns.Data.Art["screen-backdrop"]
    if not (backdropPart and backdrop:SetTexture(MEDIA .. backdropPart.file)) then
        backdrop:Hide()
        backdrop = nil
    end

    -- The interior backing, genuinely tiled. That works only because this part
    -- ships unpadded: a 512x512 source at 256x256 is already a power of two,
    -- so its crop is the whole texture. Tiling a PADDED part would repeat the
    -- transparent padding along with the picture, which is why every other
    -- part in this window is stretched instead. check_art.py flags this one as
    -- tiling, meaning its four edges were drawn to meet.
    --
    -- SetHorizTile and SetVertTile are both present on build 1.60.1.69913
    -- (SimpleTextureBaseAPIDocumentation.lua) and Blizzard's own UI calls them.
    local panelArt = artLayer:CreateTexture(nil, "BACKGROUND")
    local panelPart = ns.Data.Art and ns.Data.Art["planner-panel"]
    local whole = panelPart and panelPart.l == 0 and panelPart.r == 1
                  and panelPart.t == 0 and panelPart.b == 1
    if whole and panelArt:SetTexture(MEDIA .. panelPart.file, "REPEAT", "REPEAT") then
        panelArt:SetHorizTile(true)
        panelArt:SetVertTile(true)
    elseif panelPart and panelArt:SetTexture(MEDIA .. panelPart.file) then
        -- Padded after all: stretch rather than repeat the padding.
        panelArt:SetTexCoord(panelPart.l, panelPart.r, panelPart.t, panelPart.b)
    else
        panelArt:Hide()
    end
```

Change `screen`, `side` and `results` from `W.Panel(f, ...)` to
`W.Panel(content, ...)` so they sit above the art, and reparent the two edit
boxes, `here`, `go`, `hint`, `total` and every step row from `f`/`side` to
their existing parents but with `content` as the root. Delete every `SetPoint`
call on `fromBox`, `toBox`, `here`, `go`, `hint` and `total` — `ApplyLayout`
places them now. The step rows inside `side` keep their existing relative
anchors: they are laid out within the side panel, which the geometry places as
a unit.

Give the two edit boxes and the three buttons their three-slice art:

```lua
    -- input-box.png is 1024x128, so 0.18 of its width is a 184x128 cap.
    local CAP, CAP_ASPECT = 0.18, 184 / 128
    local fromSlice = W.Stretch3(fromBox, "input-box", CAP, CAP_ASPECT)
    local toSlice = W.Stretch3(toBox, "input-box", CAP, CAP_ASPECT)
```

Add to the `ui` table: `backdrop`, `panelArt`, `fromSlice`, `toSlice`.

Then extend `ApplyLayout`, after the chrome block from Task 4:

```lua
Add these **into the `if g then` block Task 4 opened**. Do not start a second
one, and do not re-place the chrome Task 4 already placed:

```lua
        W.PlaceRect(ui.fromBox, f, g.fromBox)
        W.PlaceRect(ui.toBox, f, g.toBox)
        W.PlaceRect(ui.here, f, g.hereButton)
        W.PlaceRect(ui.results, f, g.resultsList)
        W.PlaceRect(ui.screen, f, g.screen)
        W.PlaceRect(ui.side, f, g.sidePanel)
        W.PlaceRect(ui.go, f, g.goButton)
        W.PlaceLine(ui.total, f, g.totalLine)
        W.PlaceLine(ui.hint, f, g.hintLine)
        if ui.panelArt then
            W.PlaceRect(ui.panelArt, f, g.screen)
        end
        if ui.backdrop then
            W.PlaceRect(ui.backdrop, f, g.screen)
            local part = ns.Data.Art["screen-backdrop"]
            coverCrop(ui.backdrop, part, 1600, 640,
                      (g.screen.right - g.screen.left) * f:GetWidth(),
                      (g.screen.bottom - g.screen.top) * f:GetHeight())
        end
```

Delete `SCREEN_SHARE`, `PAD`, `HEADER`, `INPUTS`, `FOOTER` and any other layout
constant no longer read. `ROW` and `STEP_ROW` stay: they lay out rows *inside*
the side panel and results list, which is relative positioning the geometry
does not describe. Run luacheck to find any that became unused.

Set `## Version: 2026.09.21` in `GoblinPS/GoblinPS.toc`.

- [ ] **Step 6: Stop `showResults` re-anchoring the list**

`showResults` currently ends by anchoring `ui.results` under whichever box has
focus and sizing it to that box's width:

```lua
    ui.results:ClearAllPoints()
    ui.results:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
    ui.results:SetSize(box:GetWidth(), math.min(#items, Planner.MAX_RESULTS) * ROW + 4)
```

That fights `ApplyLayout`, which now places the list from `g.resultsList`, and
it contradicts what the art was drawn for: Codex specified one shared list that
"spans the search area rather than being restricted to the focused field".
Delete those three lines. `showResults` keeps filling the rows, setting
`ui.results.owner` and calling `Show`; where the list sits is `ApplyLayout`'s
business alone.

The list's height is now fixed by the geometry rather than by how many results
there are, so hide the unused rows — `row:SetShown(item ~= nil)` already does
exactly that, which is why nothing else needs to change.

Add the test:

```lua
        h.it("drops the results list over the search area, not under one box", function()
            -- One shared list, spanning the search area: it serves whichever
            -- box has focus and the art has one opening for it.
            ns.Planner.Toggle()
            ns.Planner.ApplyLayout("wide")
            local ui = ns.Planner.Debug()
            local g = ns.Data.ArtGeometry.planner.wide
            local w = ui.frame:GetWidth()
            ui.toBox:SetText("Orgrimmar")
            ui.toBox:GetScript("OnTextChanged")(ui.toBox, true)
            h.truthy(ui.results:IsShown(), "typing opens the list")
            h.eq(ui.results.points[1][2], ui.frame,
                 "anchored to the window, not to the box that has focus")
            h.truthy(math.abs(ui.results.points[1][4] - g.resultsList.left * w) < 1,
                     "and it sits where the geometry says")
        end)

        h.it("opens the whole list from the dropdown button", function()
            ns.Planner.Toggle()
            local ui = ns.Planner.Debug()
            h.truthy(ui.dropdown, "the socket beside To has a control in it")
            Fake.Click(ui.dropdown)
            h.truthy(ui.results:IsShown(), "browsing needs no typing")
            Fake.Click(ui.dropdown)
            h.falsy(ui.results:IsShown(), "and clicking again puts it away")
        end)
```

- [ ] **Step 7: Run the tests to verify they pass**

Run the Lua suite. Expected: green. Every existing planner test must still
pass.

- [ ] **Step 8: Prove the fallback is real**

In a scratch copy outside the repo, delete `GoblinPS/Data/Art.lua` entirely and
run the Lua suite.

Expected: green. Not "green except the art tests" — the whole suite. A window
that cannot be built without its art is a window a renamed texture breaks.
Delete the scratch copy afterwards.

- [ ] **Step 9: Lint**

Run luacheck and the language server. Expected: zero warnings, and no
`unused variable` left behind by the deleted constants.

- [ ] **Step 10: Commit**

```bash
git add GoblinPS/Planner.lua GoblinPS/Widgets.lua GoblinPS/GoblinPS.toc test/test_ui.lua
git commit -m "The planner's inputs, screen, panel and footer, from the geometry" -m "Three-slice stretching keeps the end caps on controls drawn at two widths, and the screen backdrop covers its opening by cropping rather than distorting -- an insert, not a stacked layer, which is the opposite of what the dash taught." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Documents

**Files:**
- Modify: `docs/superpowers/specs/2026-09-19-goblinps-design.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: The spec**

In the status header, record that plan 6 is the planner's art and plan 7 is the
route strip, and that the strip was separated because it draws inside a screen
rectangle this plan places and that art has never been in the client.

In decision 5, record that `images/parts/planner-geometry.json` is the
placement authority for the window, that `tools/check_art.py` verifies it
against the frame pixels, and that `tools/make_art.py` copies it into
`GoblinPS/Data/Art.lua` so no coordinate is hand-typed in `Planner.lua`.

Record the ruling on `tools_button`: it is an alias of `close_button` that the
generator drops, so the addon cannot draw a second control on top of Close.

- [ ] **Step 2: The checklist**

Add a `## Planner window art (plan 6)` section to
`docs/manual-test-checklist.md`:

```
- [ ] /gps opens a window wearing brass, not flat colour, in both shapes
- [ ] The window is the art's shape, not stretched: the round lamps in the
      corners are round. If they are ovals, Planner.SIZE and the art's canvas
      have drifted apart
- [ ] No coloured rectangle shows at the window's edges or corners
- [ ] Title and tagline sit on their plates; neither draws on the brass
- [ ] Close shuts the window; the gear says settings are not built yet
- [ ] The title bar has exactly TWO buttons, a gear and a close -- if a
      third sits exactly on top of close, the tools_button alias got through
- [ ] The dropdown beside To opens the whole destination list without typing
- [ ] The Wide/Tall button switches shape and both shapes are laid out
- [ ] From, To and Here sit in their openings, and the end caps on the boxes
      and buttons are not squashed or stretched
- [ ] Typing in either box drops the results list over the screen, and it
      covers what it drops over rather than hiding behind it
- [ ] The screen's scenery fills its opening without looking stretched;
      losing the sides is intended
- [ ] The step list, total and amber hint sit in their openings, and a long
      warning never covers GO
- [ ] At UI scale 0.64 and 1.0 the window is legible and nothing overlaps
- [ ] /gps selftest names the sixteen new textures; if one FAILS the window
      must still be usable on its flat colours
```

- [ ] **Step 3: CLAUDE.md**

Update the status line: plan 6 built, plan 7 the route strip next. Note in the
layout map that `GoblinPS/Data/Art.lua` now carries the planner's geometry as
well as the dash's, that no coordinate is hand-typed in `Planner.lua`, and that
`GoblinPS/Widgets.lua` owns the three shared placement helpers.

Add to "Rules that are easy to break":

```
- **An art part that stacks shares its canvas; an art part that is an insert
  does not.** The dash's five layers are one rectangle corner to corner. The
  planner's `screen-backdrop` is the opposite: 2.5:1 scenery scaled to cover
  its opening and centre-cropped, with the crop composed into the part's own
  padding coordinates. Reading one rule as the other either distorts the art
  or crops the padding instead of the picture.
```

- [ ] **Step 4: Commit**

```bash
git add docs/ CLAUDE.md
git commit -m "Docs: the planner's art, and why the strip is its own plan" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Notes for the reviewer

- **No coordinate may be hand-typed in `Planner.lua`.** Every position comes
  from `ns.Data.ArtGeometry.planner`. A literal offset or size in the layout is
  a finding even if it happens to look right, because the next art delivery
  will move it and nothing will notice. `Planner.SIZE` is the one permitted
  exception and is checked against the art's aspect ratio by a test.
- **Check what each helper measures.** `W.PlaceRect`, `W.PlaceLine` and
  `W.PlaceCircle` must all measure the frame with the explicit `SetSize`. A
  call that passes `content` or `artLayer` as the device reproduces the fault
  that reached the client on 2026-09-20, and it will pass any test that only
  counts anchors.
- **Positions, not just sizes.** Plan 5 shipped a device whose every texture
  was the right size and in the wrong place, past a green suite. Every
  placement test in this plan asserts a coordinate.
- **The backdrop's crop is the subtle part.** It composes with the part's
  padding crop. A version that calls `SetTexCoord` with a sub-range of 0..1
  instead of a sub-range of `l..r` will crop the transparent padding and show a
  sliver of scenery. Check the arithmetic against a part whose `l` is not 0 —
  `screen-backdrop` pads from 512x205 to 512x256, so its `b` is about 0.80.
- **There is no tools button.** If one appears, Task 2's drop list failed.
- **The fallback is not decoration.** With `Data/Art.lua` deleted the window
  must still open, lay out both shapes and route. Step 7 of Task 5 tests
  exactly that; check it was actually run.
- The fake's accepted-and-ignored list has hidden five methods so far, and its
  `SetAllPoints` hid a sixth fault by being too helpful. If a test cannot see
  something, look there before concluding it cannot be tested. It does not
  record the font object at all.

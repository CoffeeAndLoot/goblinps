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


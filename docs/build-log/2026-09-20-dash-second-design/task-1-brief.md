### Task 1: Ship the new parts, and re-centre the compass

**Files:**
- Modify: `tools/make_art.py`
- Regenerate: `GoblinPS/Data/Art.lua`, `GoblinPS/Media/dash2-*.tga`
- Test: `test/tools/test_make_art.py`

**Interfaces:**
- Consumes: the eight PNGs and `images/parts/dash2-geometry.json`, all committed and passing `python tools/check_art.py`.
- Produces, for Tasks 2 and 3:
  - `GoblinPS/Media/dash2-<name>.tga` for all eight parts.
  - `ns.Data.Art["dash2-<name>"] = { file, l, r, t, b }`, as today.
  - `ns.Data.Art.geometry`, a Lua copy of the artist's placement numbers, shaped exactly as given in Step 3. Every position in `Dash.lua` comes from this and nothing is hand-typed.

Read `images/parts/dash2-notes.md` first. The facts that bind this task:

- The five layers `dash2-housing`, `dash2-glass`, `dash2-compass`, `dash2-steps-screen`, `dash2-eta-screen` share one 1024x1280 canvas and one origin. **Scale them together, by the same factor, to the same shipped rectangle.** They are stacked corner to corner and never centred or scaled independently.
- The three button states share a 256 square and keep it.
- `arrow.png` is already shipped and working. Its SHA-256 is recorded in the geometry file. **Do not rebuild or alter it.**

**The compass needs different treatment from the other four.**

The dial's centre is at (516, 469) on a 1024x1280 canvas whose own centre is (512, 640). `texture:SetRotation` turns a texture about its own middle. So a compass shipped on the shared canvas would turn about a point 171 px below the dial and orbit instead of spin.

Fix it in the tool, not in the addon: crop a square out of `dash2-compass.png` centred on the dial, so the shipped texture's own middle **is** the dial. The crop must be large enough to hold the ring at any rotation — the ring's radius is 262 px, so a half-width of at least 262. Use 280 for margin, giving a 560 square, which fits inside the canvas on both axes (x 236 to 796, y 189 to 749).

Record the crop's size as a fraction of canvas width in the geometry, so `Dash.lua` knows how big to draw it relative to the device.

**Shipped sizes.**

| Part | Source | Shipped | Why |
|---|---|---|---|
| the five shared layers | 1024x1280 | 256x320 | The device draws about 230 px wide; 256 keeps it sharp. |
| `dash2-compass` | cropped 560 square | 256x256 | Its own square, centred on the dial so it can rotate. |
| the three button states | 256x256 | 64x64 | The button draws about 24 px across. |

256x320 pads to 256x512, and 64 and 256 are already powers of two.

- [ ] **Step 1: Write the failing tests**

Add to `test/tools/test_make_art.py`:

```python
class TestDashTwo(unittest.TestCase):
    def test_every_new_part_is_planned(self):
        names = {p.name for p in make_art.PARTS}
        for part in ("dash2-housing", "dash2-glass", "dash2-compass",
                     "dash2-steps-screen", "dash2-eta-screen",
                     "dash2-stop", "dash2-stop-hover", "dash2-stop-pressed"):
            self.assertIn(part, names)

    def test_the_shared_layers_go_to_one_rectangle(self):
        shared = [p for p in make_art.PARTS
                  if p.name in ("dash2-housing", "dash2-glass",
                                "dash2-steps-screen", "dash2-eta-screen")]
        self.assertEqual(len(shared), 4)
        self.assertEqual(len({(p.width, p.height) for p in shared}), 1,
                         "layers stacked corner to corner must ship at one size")

    def test_the_compass_is_not_one_of_them(self):
        # It is cropped and re-centred on the dial so it can be rotated, so it
        # must NOT share the rectangle the others are scaled into.
        compass = next(p for p in make_art.PARTS if p.name == "dash2-compass")
        shared = next(p for p in make_art.PARTS if p.name == "dash2-glass")
        self.assertNotEqual((compass.width, compass.height),
                            (shared.width, shared.height))
        self.assertEqual(compass.width, compass.height, "it must be square to rotate")

    def test_the_button_states_share_one_size(self):
        states = [p for p in make_art.PARTS if p.name.startswith("dash2-stop")]
        self.assertEqual(len(states), 3)
        self.assertEqual(len({(p.width, p.height) for p in states}), 1)


class TestCompassCrop(unittest.TestCase):
    def test_the_crop_is_centred_on_the_dial(self):
        box = make_art.compass_crop_box()
        cx = (box[0] + box[2]) / 2
        cy = (box[1] + box[3]) / 2
        g = make_art.geometry()
        self.assertAlmostEqual(cx, g["glass"]["cx"] * g["canvas"][0], delta=1)
        self.assertAlmostEqual(cy, g["glass"]["cy"] * g["canvas"][1], delta=1)

    def test_the_crop_is_square_and_holds_the_ring_at_any_angle(self):
        box = make_art.compass_crop_box()
        w, h = box[2] - box[0], box[3] - box[1]
        self.assertEqual(w, h)
        g = make_art.geometry()
        ring = g["compass_ring"]["r"] * g["canvas"][0]
        self.assertGreaterEqual(w / 2, ring, "half the crop must clear the ring's radius")

    def test_the_crop_stays_inside_the_canvas(self):
        box = make_art.compass_crop_box()
        w, h = make_art.geometry()["canvas"]
        self.assertGreaterEqual(box[0], 0)
        self.assertGreaterEqual(box[1], 0)
        self.assertLessEqual(box[2], w)
        self.assertLessEqual(box[3], h)


class TestGeometryExport(unittest.TestCase):
    def test_the_lua_table_carries_what_the_addon_needs(self):
        lua = make_art.geometry_lua()
        for key in ("canvas", "glass", "compassRing", "compassCrop",
                    "stepsText", "etaText", "destination", "distance", "stop"):
            self.assertIn(key, lua, f"{key} is missing; Dash.lua would have to guess it")

    def test_it_reports_the_crop_as_a_fraction_of_the_device(self):
        lua = make_art.geometry_lua()
        share = lua["compassCrop"]["share"]
        self.assertGreater(share, 0.0)
        self.assertLess(share, 1.0)
```

- [ ] **Step 2: Run to verify they fail**

Run: `python -m unittest discover -s test/tools`
Expected: FAIL with `AttributeError` for `compass_crop_box`, `geometry` and `geometry_lua`.

- [ ] **Step 3: Extend the tool**

In `tools/make_art.py`, add beside the existing constants:

```python
GEOMETRY = SOURCE / "dash2-geometry.json"

# Half the compass crop, in source pixels. The ring's radius is 262, so this
# clears it with margin and still fits inside the 1024x1280 canvas.
COMPASS_HALF = 280
```

Extend `PARTS` with the eight new entries — the four stacked layers at one
rectangle, the compass at its own square, the buttons at theirs:

```python
PARTS += [
    Part("dash2-housing", 256, 320),
    Part("dash2-glass", 256, 320),
    Part("dash2-steps-screen", 256, 320),
    Part("dash2-eta-screen", 256, 320),
    Part("dash2-compass", 256, 256),      # cropped square, see compass_crop_box
    Part("dash2-stop", 64, 64),
    Part("dash2-stop-hover", 64, 64),
    Part("dash2-stop-pressed", 64, 64),
]
```

Add the geometry helpers:

```python
def geometry():
    """The artist's placement file, which tools/check_art.py checks against the pixels."""
    import json
    return json.loads(GEOMETRY.read_text(encoding="utf-8"))


def compass_crop_box():
    """The square to cut out of the compass so it can be rotated.

    texture:SetRotation turns a texture about its own middle, and the dial is
    not at the middle of the shared canvas, so a compass shipped whole would
    orbit rather than spin. Cutting a square centred on the dial makes the
    shipped texture's own middle the dial.
    """
    g = geometry()
    w, h = g["canvas"]
    cx, cy = g["glass"]["cx"] * w, g["glass"]["cy"] * h
    left, top = round(cx - COMPASS_HALF), round(cy - COMPASS_HALF)
    right, bottom = round(cx + COMPASS_HALF), round(cy + COMPASS_HALF)
    if left < 0 or top < 0 or right > w or bottom > h:
        raise ValueError(f"the compass crop {left, top, right, bottom} leaves the canvas")
    return (left, top, right, bottom)
```

Give `build_one` a special case, keeping everything else as it is:

```python
def build_one(part):
    src = SOURCE / "{0}.png".format(part.name)
    if not src.is_file():
        raise FileNotFoundError("{0} is missing; the art has not been delivered".format(src))
    art = Image.open(src).convert("RGBA")
    if part.name == "dash2-compass":
        art = art.crop(compass_crop_box())
    art = art.resize((part.width, part.height), Image.LANCZOS)
    cw, ch = next_power_of_two(part.width), next_power_of_two(part.height)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.paste(art, (0, 0))
    MEDIA.mkdir(parents=True, exist_ok=True)
    canvas.save(MEDIA / "{0}.tga".format(part.name))
    return tex_coords(part.width, part.height, cw, ch), (cw, ch)
```

Add the geometry export:

```python
def geometry_lua():
    """The placement numbers the addon needs, as plain fractions.

    Everything Dash.lua positions comes from here. The addon never hand-types
    a coordinate, so a change in the art reaches the layout by regenerating
    this file rather than by editing Lua.
    """
    g = geometry()
    w, h = g["canvas"]
    box = compass_crop_box()

    def rect(r):
        return {"left": r["left"], "top": r["top"], "right": r["right"], "bottom": r["bottom"]}

    return {
        "canvas": {"w": w, "h": h},
        "glass": {"cx": g["glass"]["cx"], "cy": g["glass"]["cy"], "r": g["glass"]["r"]},
        "compassRing": {"r": g["compass_ring"]["r"]},
        # How wide the cropped compass is against the whole device, so the
        # addon can size it without knowing anything about the crop.
        "compassCrop": {"share": (box[2] - box[0]) / w},
        "arrow": {"share": g["_assembly"]["arrow"]["display_size_pixels"][0] / w},
        "stepsText": rect(g["_assembly"]["steps_text_safe_box"]),
        "etaText": rect(g["_assembly"]["eta_text_safe_box"]),
        "destination": rect(g["destination_line"]),
        "distance": rect(g["distance_line"]),
        "stop": {"cx": g["stop_button"]["cx"], "cy": g["stop_button"]["cy"],
                 "r": g["stop_button"]["r"]},
    }
```

And write it into the generated Lua. After the existing rows are built, append a
`geometry` entry. Keep the formatting plain and deterministic — the file is
compared byte for byte by the reviewer:

```python
def lua_value(v, indent):
    pad = " " * indent
    if isinstance(v, dict):
        inner = ",\n".join('{0}["{1}"] = {2}'.format(pad + "    ", k, lua_value(x, indent + 4))
                           for k, x in sorted(v.items()))
        return "{\n" + inner + "\n" + pad + "}"
    if isinstance(v, float):
        return "{0:.6g}".format(v)
    return str(v)
```

Then in `main()`, after the parts loop, add the geometry table to the text it
writes, as `ns.Data.Art.geometry = <table>`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest discover -s test/tools`
Expected: PASS, the existing tests plus the new ones.

- [ ] **Step 5: Build, and check the compass really is centred**

Run: `python tools/make_art.py`
Then confirm the shipped compass has its ring centred on its own middle, which
is the whole point of the crop. Put this in your session scratchpad, not the repo:

```python
from PIL import Image
import numpy as np
a = np.asarray(Image.open("GoblinPS/Media/dash2-compass.tga").convert("RGBA").getchannel("A"))
ys, xs = np.nonzero(a > 32)
w, h = a.shape[1], a.shape[0]
print("bbox centre", (xs.min()+xs.max())/2, (ys.min()+ys.max())/2, "canvas centre", (w-1)/2, (h-1)/2)
```

Both centres must agree within a pixel or two. Report the numbers.

- [ ] **Step 6: Confirm nothing else regressed**

Run `python tools/check_art.py` — expected `47 pass, 0 with problems`.
Run the Lua suite — expected 239 passed, since no Lua changed.

- [ ] **Step 7: Commit**

```bash
git add tools/make_art.py test/tools/test_make_art.py GoblinPS/Data/Art.lua GoblinPS/Media
git commit -m "Ship the second dash set, with the compass re-centred on the dial" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---


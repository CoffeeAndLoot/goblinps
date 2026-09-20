### Task 1: The shipped-texture tool

**Files:**
- Create: `tools/make_art.py`
- Create: `GoblinPS/Data/Art.lua` (written by running the tool, never by hand)
- Test: `test/tools/test_make_art.py`

**Interfaces:**
- Consumes: the 39 PNGs in `images/parts/`, which `python tools/check_art.py` already passes.
- Produces: `GoblinPS/Media/<name>.tga` for the five dash parts, and
  `ns.Data.Art[name] = { file = "<name>", l = <number>, r = <number>, t = <number>, b = <number> }`
  in `GoblinPS/Data/Art.lua`. Task 6 reads that table. `file` is the base name only; the caller builds the full path.

Read `images/parts/CLAUDE-HANDOFF.md` before starting. The facts that bind this task:

- The TGAs in `images/parts/` are **not** what ships. They are authoring resolution, about 49 MiB, and gitignored. Do not copy them into `GoblinPS/Media/`.
- The authoring `texture-manifest.json` is **not** the shipped manifest. Its coordinates belong to authoring canvases. Recompute them.
- The dash stack is screen, compass, arrow, body. The three 1024 px layers share centre (512,512) and **must stay aligned after downscaling**, which holds only if all three go to the same shipped canvas.
- `arrow.png` is 512 square with generous glow padding; the visible arrow is about 245 px of that. Do not confuse visible width with canvas width when choosing a size.

Shipped sizes. Only the five dash parts are built here; plan 5 extends the same tool to the other 34.

| Part | Source | Shipped | Why |
|---|---|---|---|
| `dash-body` | 1024 | 256 | The device draws about 200 px wide. |
| `dash-screen` | 1024 | 256 | Same canvas as the body, so it stays concentric. |
| `dash-compass` | 1024 | 256 | Same canvas; it rotates about the centre. |
| `arrow` | 512 | 128 | Drawn about 90 px inside the screen. |
| `dash-eta-plate` | 512x128 | 128x32 | A small plate under the device. |

All five shipped sizes are already powers of two, so padding is a no-op for them today. The padding code still has to be correct, because plan 5's parts (192, 768x192, 1600x640) are not.

- [ ] **Step 1: Write the failing test**

Create `test/tools/test_make_art.py`:

```python
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import make_art


class TestPowerOfTwo(unittest.TestCase):
    def test_leaves_a_power_of_two_alone(self):
        self.assertEqual(make_art.next_power_of_two(256), 256)
        self.assertEqual(make_art.next_power_of_two(1), 1)

    def test_rounds_up(self):
        self.assertEqual(make_art.next_power_of_two(192), 256)
        self.assertEqual(make_art.next_power_of_two(768), 1024)
        self.assertEqual(make_art.next_power_of_two(1600), 2048)

    def test_rejects_nonsense(self):
        for bad in (0, -8):
            with self.assertRaises(ValueError):
                make_art.next_power_of_two(bad)


class TestTexCoords(unittest.TestCase):
    def test_art_filling_its_canvas_uses_the_whole_texture(self):
        self.assertEqual(make_art.tex_coords(256, 256, 256, 256), (0.0, 1.0, 0.0, 1.0))

    def test_padding_shrinks_the_coordinates(self):
        self.assertEqual(make_art.tex_coords(192, 192, 256, 256), (0.0, 0.75, 0.0, 0.75))

    def test_the_two_axes_are_independent(self):
        left, right, top, bottom = make_art.tex_coords(1600, 640, 2048, 1024)
        self.assertEqual((left, right), (0.0, 0.78125))
        self.assertEqual((top, bottom), (0.0, 0.625))


class TestPlan(unittest.TestCase):
    def test_every_dash_part_is_planned(self):
        self.assertEqual({p.name for p in make_art.PARTS},
                         {"dash-body", "dash-screen", "dash-compass",
                          "arrow", "dash-eta-plate"})

    def test_the_stacked_layers_share_one_canvas(self):
        stacked = [p for p in make_art.PARTS
                   if p.name in ("dash-body", "dash-screen", "dash-compass")]
        self.assertEqual(len({(p.width, p.height) for p in stacked}), 1,
                         "the dash layers must stay aligned after scaling")

    def test_every_planned_part_has_a_source_png(self):
        for part in make_art.PARTS:
            self.assertTrue((make_art.SOURCE / f"{part.name}.png").is_file(), part.name)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `python -m unittest discover -s test/tools`
Expected: FAIL with `ModuleNotFoundError: No module named 'make_art'`.

- [ ] **Step 3: Write the tool**

Create `tools/make_art.py`:

```python
#!/usr/bin/env python3
"""Build GoblinPS/Media/*.tga and GoblinPS/Data/Art.lua from images/parts/*.png.

The PNGs are the source of truth and are authoring resolution: a route icon is
256 square and draws at about 24 pixels. Shipping them whole would make the
addon tens of megabytes of pixels nobody sees, so each part is scaled to the
size it actually draws at, then padded up to a power-of-two canvas, the
conservative choice for texture compatibility on this client.

Padding means the art no longer fills its texture, so each part carries the
coordinates that crop the padding away. Those live in the generated
GoblinPS/Data/Art.lua and are read by the UI; nothing hand-types them.

Run from anywhere: python tools/make_art.py
"""

from dataclasses import dataclass
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "images" / "parts"
MEDIA = ROOT / "GoblinPS" / "Media"
TABLE = ROOT / "GoblinPS" / "Data" / "Art.lua"


@dataclass(frozen=True)
class Part:
    name: str
    width: int
    height: int


# The size each part is drawn at in the UI. The three 1024 px dash layers share
# one shipped canvas so that stacking them still lines up: their artwork is
# concentric on (512,512) and stays concentric only under one common scale.
# See images/parts/CLAUDE-HANDOFF.md.
PARTS = [
    Part("dash-body", 256, 256),
    Part("dash-screen", 256, 256),
    Part("dash-compass", 256, 256),
    Part("arrow", 128, 128),
    Part("dash-eta-plate", 128, 32),
]


def next_power_of_two(n):
    """The smallest power of two that is at least n."""
    if n < 1:
        raise ValueError("size must be positive, got {0}".format(n))
    p = 1
    while p < n:
        p *= 2
    return p


def tex_coords(art_w, art_h, canvas_w, canvas_h):
    """left, right, top, bottom for art sitting at the top-left of its canvas."""
    return (0.0, art_w / canvas_w, 0.0, art_h / canvas_h)


def build_one(part):
    src = SOURCE / "{0}.png".format(part.name)
    if not src.is_file():
        raise FileNotFoundError("{0} is missing; the art has not been delivered".format(src))
    art = Image.open(src).convert("RGBA").resize((part.width, part.height), Image.LANCZOS)
    cw, ch = next_power_of_two(part.width), next_power_of_two(part.height)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.paste(art, (0, 0))            # top-left, as the authoring export does
    MEDIA.mkdir(parents=True, exist_ok=True)
    canvas.save(MEDIA / "{0}.tga".format(part.name))
    return tex_coords(part.width, part.height, cw, ch), (cw, ch)


HEADER = """-- Generated by tools/make_art.py. Do not edit.
-- Each part was scaled to the size it draws at, then padded up to a
-- power-of-two canvas. l, r, t, b crop that padding away: pass them straight
-- to texture:SetTexCoord(l, r, t, b).
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Art = {
"""


def main():
    rows, total = [], 0
    for part in PARTS:
        (left, right, top, bottom), (cw, ch) = build_one(part)
        size = (MEDIA / "{0}.tga".format(part.name)).stat().st_size
        total += size
        rows.append(
            '    ["{0}"] = {{ file = "{0}", l = {1:g}, r = {2:g}, t = {3:g}, b = {4:g} }},'
            "  -- {5}x{6} art on {7}x{8}".format(
                part.name, left, right, top, bottom,
                part.width, part.height, cw, ch))
        print("{0}: {1}x{2} on {3}x{4}, {5:.0f} KB".format(
            part.name, part.width, part.height, cw, ch, size / 1024))
    TABLE.write_text(HEADER + "\n".join(rows) + "\n}\n", encoding="utf-8")
    print("wrote {0}".format(TABLE))
    print("{0} textures, {1:.2f} MB total".format(len(PARTS), total / 1024 / 1024))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest discover -s test/tools`
Expected: PASS. 18 existing plus 9 new.

- [ ] **Step 5: Generate the textures and the table**

Run: `python tools/make_art.py`
Expected: five lines naming each part, `wrote ...Art.lua`, and a total well under 1 MB. Open `GoblinPS/Data/Art.lua`: five rows, every one `l = 0, r = 1, t = 0, b = 1`, because all five shipped sizes are already powers of two so nothing is cropped yet.

- [ ] **Step 6: Commit**

```bash
git add tools/make_art.py test/tools/test_make_art.py GoblinPS/Data/Art.lua GoblinPS/Media
git commit -m "Build shipped-size dash textures from the PNG sources" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---


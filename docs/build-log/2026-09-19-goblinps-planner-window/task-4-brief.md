### Task 4: The icon

**Files:**
- Create: `tools/make_icon.py`, `GoblinPS/Media/icon.tga` (generated, committed)

**Interfaces:**
- Produces: the texture path `Interface\AddOns\GoblinPS\Media\icon` (256x256 RGBA TGA, round alpha mask) used by the TOC, the minimap button and the self-test. If `images/icon-source.png` exists it is used; otherwise a placeholder is drawn. Art can arrive later without touching code.

- [ ] **Step 1: Write `tools/make_icon.py`**

```python
#!/usr/bin/env python3
"""Build GoblinPS/Media/icon.tga (256x256 RGBA, round).

If images/icon-source.png exists (square art, any size: from an artist or an
image generator) it is used. Otherwise a placeholder is drawn: a brass dial
with a green screen and an amber route, so the addon always has an icon.
Run from anywhere: python tools/make_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "images" / "icon-source.png"
DEST = ROOT / "GoblinPS" / "Media" / "icon.tga"
SIZE = 256

BRASS, STEEL, SCREEN, GREEN, AMBER = (184, 134, 59), (29, 26, 20), (8, 30, 16), (112, 224, 138), (240, 182, 74)


def placeholder() -> Image.Image:
    big = SIZE * 4  # draw large, shrink for smooth edges
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, big - 1, big - 1), fill=BRASS)
    d.ellipse((big * 0.04, big * 0.04, big * 0.96, big * 0.96), outline=STEEL, width=big // 40)
    d.ellipse((big * 0.14, big * 0.14, big * 0.86, big * 0.86), fill=SCREEN, outline=STEEL, width=big // 50)
    route = [(0.30, 0.68), (0.44, 0.52), (0.58, 0.58), (0.70, 0.34)]
    d.line([(x * big, y * big) for x, y in route], fill=AMBER, width=big // 22, joint="curve")
    for x, y in route[:-1]:
        r = big * 0.035
        d.ellipse((x * big - r, y * big - r, x * big + r, y * big + r), fill=GREEN)
    x, y = route[-1]
    r = big * 0.06
    d.ellipse((x * big - r, y * big - r, x * big + r, y * big + r), fill=AMBER, outline=STEEL, width=big // 80)
    return im.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> int:
    if SOURCE.is_file():
        im = Image.open(SOURCE).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)
        print("using", SOURCE)
    else:
        im = placeholder()
        print("no", SOURCE, "- drawing the placeholder")
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse((2, 2, SIZE - 3, SIZE - 3), fill=255)
    im.putalpha(mask)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    im.save(DEST)
    print("wrote", DEST)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 2: Run it.** `python tools/make_icon.py`. Expected: `no ...icon-source.png - drawing the placeholder` then `wrote ...GoblinPS\Media\icon.tga`.

- [ ] **Step 3: Check the file.** `python -c "from PIL import Image; im=Image.open('GoblinPS/Media/icon.tga'); print(im.size, im.mode)"` prints `(256, 256) RGBA`.

- [ ] **Step 4: Commit**

```
git add tools/make_icon.py GoblinPS/Media/icon.tga
git commit -m "Add the icon tool and a placeholder icon" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---


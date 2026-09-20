#!/usr/bin/env python3
"""Build GoblinPS/Media/icon.tga (256x256 RGBA, round).

If images/goblinps-icon.png exists (art of any size, from an artist or an image
generator) it is used: the opaque part is cropped out, centred in a square and
scaled down, and its own alpha is kept, so round art with lugs or bolts poking
past the circle survives intact. Otherwise a placeholder is drawn and masked
to a circle, so the addon always has an icon.
Run from anywhere: python tools/make_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "images" / "goblinps-icon.png"
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


def from_source() -> Image.Image:
    """Crop the art to what is actually drawn, centre it in a square, scale it."""
    im = Image.open(SOURCE).convert("RGBA")
    # Ignore all-but-invisible pixels: a faint smear along one edge is enough to
    # throw the crop off centre, and it contributes nothing once scaled down.
    solid = im.getchannel("A").point(lambda v: 255 if v > 8 else 0)
    box = solid.getbbox()  # None only if the whole image is transparent
    if box:
        im = im.crop(box)
    side = max(im.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    return square.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> int:
    if SOURCE.is_file():
        im = from_source()
        print("using", SOURCE)
    else:
        im = placeholder()
        mask = Image.new("L", (SIZE, SIZE), 0)
        ImageDraw.Draw(mask).ellipse((2, 2, SIZE - 3, SIZE - 3), fill=255)
        im.putalpha(mask)
        print("no", SOURCE, "- drawing the placeholder")
    DEST.parent.mkdir(parents=True, exist_ok=True)
    im.save(DEST)
    print("wrote", DEST)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

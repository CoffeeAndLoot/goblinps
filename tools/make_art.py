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
GEOMETRY = SOURCE / "dash2-geometry.json"

# Half the compass crop, in source pixels. The ring's radius is 262, so this
# clears it with margin and still fits inside the 1024x1280 canvas.
COMPASS_HALF = 280


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

# Dash unit, second design. The four stacked layers ship at one rectangle so
# they stay aligned after scaling; the compass is cropped to its own square,
# centred on the dial, so it can be rotated about its own middle; the three
# button states share their own square. See images/parts/dash2-notes.md.
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
    canvas.paste(art, (0, 0))            # top-left, as the authoring export does
    MEDIA.mkdir(parents=True, exist_ok=True)
    canvas.save(MEDIA / "{0}.tga".format(part.name))
    return tex_coords(part.width, part.height, cw, ch), (cw, ch)


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


def lua_value(v, indent):
    pad = " " * indent
    if isinstance(v, dict):
        inner = ",\n".join('{0}["{1}"] = {2}'.format(pad + "    ", k, lua_value(x, indent + 4))
                           for k, x in sorted(v.items()))
        return "{\n" + inner + "\n" + pad + "}"
    if isinstance(v, float):
        return "{0:.6g}".format(v)
    return str(v)


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
    text = HEADER + "\n".join(rows) + "\n}\n"
    text += "\nns.Data.ArtGeometry = {0}\n".format(lua_value(geometry_lua(), 0))
    TABLE.write_text(text, encoding="utf-8")
    print("wrote {0}".format(TABLE))
    print("{0} textures, {1:.2f} MB total".format(len(PARTS), total / 1024 / 1024))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

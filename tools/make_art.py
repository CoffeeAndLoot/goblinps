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

import json
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "images" / "parts"
MEDIA = ROOT / "GoblinPS" / "Media"
TABLE = ROOT / "GoblinPS" / "Data" / "Art.lua"
GEOMETRY = SOURCE / "dash2-geometry.json"
PLANNER_GEOMETRY = SOURCE / "planner-geometry.json"

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


# How the frame's opening is measured. These are tolerances of the measurement,
# not coordinates: a pixel counts as brass at alpha 16 and as solid brass above
# 200; hairline seams are sealed by growing the brass SEAL pixels before the
# fill; and each side of the opening is pushed outward, at most REACH pixels,
# until the BAND pixels beyond it are SOLID percent solid brass.
FRAME_BRASS, FRAME_SOLID = 16, 200
SEAL, BAND, SOLID, REACH = 2, 3, 0.99, 60


def frame_interior(layout, screen):
    """The frame's clear opening, as fractions of its canvas.

    The tiled panel backing draws UNDER the frame and must reach the brass on
    every side. Seen in the client 2026-09-21: sized to the union of the
    controls, which sits inset from the opening, it let the world show through
    on the left, the right and the bottom. The opening is a property of the
    frame art, like a part's canvas size, so it is measured from the frame's
    own alpha rather than typed or borrowed from a preview script: a flood fill
    from the middle of the screen, over pixels that are not brass, with
    hairline seams sealed first so the fill cannot leak into the exterior.

    The brass has a soft anti-aliased inner edge, so the filled box stops a
    few pixels short of solid metal and the world would bleed through that
    edge. Each side is pushed outward until what lies beyond it is solid brass;
    the frame is drawn on top, so the overshoot is hidden.
    """
    frame = Image.open(SOURCE / ("planner-frame-%s.png" % layout)).convert("RGBA")
    alpha = frame.getchannel("A")
    width, height = frame.size
    mask = alpha.point(lambda v: 255 if v >= FRAME_BRASS else 0)
    mask = mask.filter(ImageFilter.MaxFilter(2 * SEAL + 1))
    seed = (int((screen["left"] + screen["right"]) / 2 * width),
            int((screen["top"] + screen["bottom"]) / 2 * height))
    if mask.getpixel(seed) != 0:
        raise SystemExit("planner-frame-%s: the middle of the screen is brass, not opening" % layout)
    ImageDraw.floodfill(mask, seed, 128)
    left, top, right, bottom = mask.point(lambda v: 255 if v == 128 else 0).getbbox()
    if left <= SEAL or top <= SEAL or right >= width - SEAL or bottom >= height - SEAL:
        raise SystemExit("planner-frame-%s: the opening's fill leaked through a seam to the "
                         "canvas edge; raise SEAL" % layout)

    def solid(box):
        pixels = list(alpha.crop(box).getdata())
        return sum(1 for value in pixels if value > FRAME_SOLID) / len(pixels)

    def beyond(side, n):
        return {"left": (left - n - BAND, top, left - n, bottom),
                "right": (right + n, top, right + n + BAND, bottom),
                "top": (left, top - n - BAND, right, top - n),
                "bottom": (left, bottom + n, right, bottom + n + BAND)}[side]

    tuck = {}
    for side in ("left", "top", "right", "bottom"):
        for n in range(REACH + 1):
            if solid(beyond(side, n)) >= SOLID:
                tuck[side] = n
                break
        else:
            raise SystemExit("planner-frame-%s: no solid brass within %d px beyond the "
                             "opening's %s edge" % (layout, REACH, side))
    return {
        "left": round((left - tuck["left"]) / width, 6),
        "top": round((top - tuck["top"]) / height, 6),
        "right": round((right + tuck["right"]) / width, 6),
        "bottom": round((bottom + tuck["bottom"]) / height, 6),
    }


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
        # Measured from the frame art, not read from the geometry file.
        box["interior"] = frame_interior(layout, source["screen"])
        out[layout] = box
    strip = g["strip"]
    out["strip"] = {
        "nodeDiameter": strip["node_diameter"],
        "lineThickness": strip["line_thickness"],
        "labelGap": strip["label_gap"],
    }
    return out


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
-- to texture:SetTexCoord(l, r, t, b). cw, ch are that padded canvas's own
-- pixel size (what the file on disk actually is), not the pre-scale source
-- art -- a cover-crop needs the shipped aspect ratio, and l/r/t/b are
-- fractions OF cw/ch, not of the master PNG.
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
            '    ["{0}"] = {{ file = "{0}", l = {1:g}, r = {2:g}, t = {3:g}, b = {4:g}, '
            "cw = {5}, ch = {6} }},"
            "  -- {7}x{8} art on {9}x{10}".format(
                part.name, left, right, top, bottom, cw, ch,
                part.width, part.height, cw, ch))
        print("{0}: {1}x{2} on {3}x{4}, {5:.0f} KB".format(
            part.name, part.width, part.height, cw, ch, size / 1024))
    text = HEADER + "\n".join(rows) + "\n}\n"
    art_geometry = geometry_lua()
    art_geometry["planner"] = planner_geometry_lua()
    text += "\nns.Data.ArtGeometry = {0}\n".format(lua_value(art_geometry, 0))
    TABLE.write_text(text, encoding="utf-8")
    print("wrote {0}".format(TABLE))
    print("{0} textures, {1:.2f} MB total".format(len(PARTS), total / 1024 / 1024))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Check the art parts in images/parts/ against docs/art-parts-brief.md.

An image generator gets canvas sizes, transparency and centring wrong in ways
that are invisible on a contact sheet and obvious in game, so every delivered
part is measured instead of eyeballed. Parts that have not been drawn yet are
reported as pending, not as failures.

Run from anywhere: python tools/check_art.py
Exit code 0 when every delivered part passes.
"""

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PARTS = ROOT / "images" / "parts"

# name: (width, height, flags). Flags, any combination:
#   hole    an enclosed transparent area in the middle (the art frames a gap)
#   spins   the addon rotates it, so it must be centred, left-right symmetric
#           and small enough to turn inside its canvas without clipping
#   turns   the addon rotates it, so it must be centred and fit when turned,
#           but it is not expected to be symmetric
#   tilesx  it repeats left to right, so its two side edges must meet cleanly
#   tiles   it repeats both ways, so all four edges must meet cleanly
#   solid   it fills its canvas on purpose, so opaque corners are right
SPEC = {
    # Dash unit
    "dash-body.png": (1024, 1024, {"hole"}),
    "dash-screen.png": (1024, 1024, set()),
    "dash-compass.png": (1024, 1024, {"turns"}),
    "dash-eta-plate.png": (512, 128, set()),
    "arrow.png": (512, 512, {"spins"}),
    # Planner window
    "planner-frame-wide.png": (1600, 1024, {"hole"}),
    "planner-frame-tall.png": (1024, 1600, {"hole"}),
    "planner-panel.png": (512, 512, {"tiles"}),
    "title-plate.png": (1024, 256, set()),
    "tagline-plate.png": (512, 128, set()),
    "input-box.png": (1024, 128, set()),
    "dropdown-button.png": (128, 128, set()),
    "button.png": (768, 192, set()),
    "button-hover.png": (768, 192, set()),
    "button-pressed.png": (768, 192, set()),
    "button-disabled.png": (768, 192, set()),
    "gear.png": (192, 192, set()),
    "gear-hover.png": (192, 192, set()),
    "close.png": (192, 192, set()),
    "close-hover.png": (192, 192, set()),
    "screen-backdrop.png": (1600, 640, {"solid"}),
    # Route strip
    "node-ring.png": (192, 192, set()),
    "node-current.png": (192, 192, set()),
    "node-destination.png": (192, 192, set()),
    "icon-horde.png": (192, 192, set()),
    "icon-alliance.png": (192, 192, set()),
    "icon-neutral.png": (192, 192, set()),
    "icon-flight.png": (192, 192, set()),
    "icon-boat.png": (192, 192, set()),
    "icon-zeppelin.png": (192, 192, set()),
    "icon-tram.png": (192, 192, set()),
    "icon-hearth.png": (192, 192, set()),
    "icon-gate.png": (192, 192, set()),
    "icon-walk.png": (192, 192, set()),
    "icon-ride.png": (192, 192, set()),
    "icon-warning.png": (192, 192, set()),
    "line-solid.png": (512, 64, {"tilesx"}),
    "line-dashed.png": (512, 64, {"tilesx"}),
    "line-dot.png": (64, 64, set()),
    # Dash unit, second design. The five layers share one canvas and one
    # origin: they are stacked corner to corner, never scaled or centred
    # independently, so "is it centred" is the wrong question for them and
    # `geometry` is checked instead. Their corners are transparent because
    # the device does not fill the canvas.
    "dash2-housing.png": (1024, 1280, {"hole"}),
    "dash2-glass.png": (1024, 1280, set()),
    "dash2-compass.png": (1024, 1280, set()),
    "dash2-steps-screen.png": (1024, 1280, set()),
    "dash2-eta-screen.png": (1024, 1280, set()),
    "dash2-stop.png": (256, 256, set()),
    "dash2-stop-hover.png": (256, 256, set()),
    "dash2-stop-pressed.png": (256, 256, set()),
}

GEOMETRY = PARTS / "dash2-geometry.json"

SOLID = 128  # alpha at or above this counts as part of the drawn shape


def enclosed_gap(alpha):
    """The transparent pixels the art surrounds, ignoring the space around it."""
    h, w = alpha.shape
    clear = alpha < 32
    outside = np.zeros_like(clear)
    queue = deque()
    for y, x in [(y, x) for y in (0, h - 1) for x in range(w)] + \
                [(y, x) for x in (0, w - 1) for y in range(h)]:
        if clear[y, x] and not outside[y, x]:
            outside[y, x] = True
            queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and clear[ny, nx] and not outside[ny, nx]:
                outside[ny, nx] = True
                queue.append((ny, nx))
    return clear & ~outside


def seam(rgba, axis):
    """How badly two opposite edges meet, against the normal step inside the art.

    Tiling art wraps, so the join must be no worse than any join within it. A
    seam is usually a jump in colour, not in alpha, so all four channels count;
    colour is scaled by alpha first, because a fully transparent pixel's colour
    is arbitrary and would raise false alarms. axis=1 is left against right.
    """
    a = rgba[:, :, 3:4].astype(np.float32) / 255.0
    art = np.concatenate([rgba[:, :, :3].astype(np.float32) * a, rgba[:, :, 3:4]], axis=2)
    if axis == 1:
        first, last, strip = art[:, 0], art[:, -1], art[:, :8]
    else:
        first, last, strip = art[0, :], art[-1, :], art[:8, :]
    step = float(np.abs(np.diff(strip, axis=axis)).mean())
    join = float(np.abs(first - last).mean())
    return join / max(step, 0.5)


def check(name, want_w, want_h, flags):
    path = PARTS / name
    if not path.is_file():
        return None, []

    problems = []
    im = Image.open(path)
    if im.mode != "RGBA":
        problems.append(f"mode is {im.mode}, not RGBA: it has no alpha channel")
    im = im.convert("RGBA")
    w, h = im.size
    if (w, h) != (want_w, want_h):
        problems.append(f"canvas is {w}x{h}, the brief says {want_w}x{want_h}")

    a = np.asarray(im.getchannel("A"), dtype=np.int16)
    corners = [a[0, 0], a[0, -1], a[-1, 0], a[-1, -1]]
    if max(corners) > 0 and not flags & {"tiles", "tilesx", "solid"}:
        problems.append(f"corners are not transparent (alpha {max(corners)}): "
                        "the old background was keyed out, not removed")
    if "solid" in flags and min(corners) < 255:
        problems.append(f"corners are not opaque (alpha {min(corners)}): "
                        "this part fills its canvas, so it must not fade at the edge")

    if "hole" in flags:
        gap = enclosed_gap(a)
        if not gap.any():
            problems.append("no enclosed transparent area: the middle must be a real hole")
        elif not gap[h // 2, w // 2]:
            problems.append("the hole does not cover the centre of the canvas")

    if flags & {"spins", "turns"}:
        ys, xs = np.nonzero(a >= SOLID)
        if len(xs) == 0:
            problems.append("nothing solid enough to rotate")
        else:
            cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
            off = max(abs(cx - (w - 1) / 2), abs(cy - (h - 1) / 2))
            if off > 2:
                problems.append(f"drawn {off:.1f} px off centre: it would wobble as it turns")
            ya, xa = np.nonzero(a > 0)
            reach = float(np.hypot(xa - (w - 1) / 2, ya - (h - 1) / 2).max())
            if reach > min(w, h) / 2:
                problems.append(f"reaches {reach:.0f} px from the centre but the canvas "
                                f"allows {min(w, h) / 2:.0f}: turning it would clip the corners off")
        if "spins" in flags:
            lop = np.abs(a - a[:, ::-1])
            share = float((lop > 16).mean())
            if share > 0.02:
                problems.append(f"{100 * share:.1f}% of it is not left-right symmetric: "
                                "it would lean when it points")

    if flags & {"tiles", "tilesx"}:
        rgba = np.asarray(im)
        side = seam(rgba, axis=1)
        if side > 3:
            problems.append(f"the left and right edges do not meet ({side:.1f}x a normal step): "
                            "a seam will show where it repeats")
        if "tiles" in flags:
            updown = seam(rgba, axis=0)
            if updown > 3:
                problems.append(f"the top and bottom edges do not meet ({updown:.1f}x a normal step): "
                                "a seam will show where it repeats")

    return f"{w}x{h}", problems


def geometry_holds():
    """Is dash2-geometry.json telling the truth about the pixels?

    It is the placement authority for the whole device, so a number that
    drifts from the art puts the compass, the text boxes and the button in
    the wrong places at once, with nothing to catch it.
    """
    import json

    if not GEOMETRY.is_file():
        return ["dash2-geometry.json is missing: nothing states where anything goes"]

    g = json.loads(GEOMETRY.read_text(encoding="utf-8"))
    w, h = g["canvas"]
    problems = []

    def alpha_of(name):
        im = Image.open(PARTS / name).convert("RGBA")
        if im.size != (w, h):
            problems.append(f"{name} is {im.size[0]}x{im.size[1]}, but the geometry says {w}x{h}")
            return None
        return np.asarray(im.getchannel("A"), dtype=np.int16)

    # The glass and the compass must share a centre, and it is NOT the canvas
    # centre: the device's dial sits high. SetRotation turns a texture about
    # its own middle, so a compass shipped on this canvas would swing about a
    # point far below the dial. The tool that builds the shipped textures has
    # to re-centre it on this point.
    cx, cy = g["glass"]["cx"] * w, g["glass"]["cy"] * h
    for name, key in (("dash2-glass.png", "glass"), ("dash2-compass.png", "compass_ring")):
        a = alpha_of(name)
        if a is None:
            continue
        ys, xs = np.nonzero(a > 32)
        mx, my = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
        if abs(mx - cx) > 3 or abs(my - cy) > 3:
            problems.append(f"{name} is drawn around ({mx:.0f}, {my:.0f}) but the geometry "
                            f"puts {key} at ({cx:.0f}, {cy:.0f})")
        r = g[key]["r"] * w
        drawn = (xs.max() - xs.min()) / 2
        if abs(drawn - r) > 6:
            problems.append(f"{name} has radius {drawn:.0f} px, the geometry claims {r:.0f}")
        # Turning about the dial's centre must not push art off the canvas.
        if cx - r < 0 or cx + r > w or cy - r < 0 or cy + r > h:
            problems.append(f"{name} would clip the canvas when turned about the dial")

    # Every opening the geometry names must really be a hole in the housing.
    a = alpha_of("dash2-housing.png")
    if a is not None:
        spots = {"glass": (cx, cy),
                 "stop_button": (g["stop_button"]["cx"] * w, g["stop_button"]["cy"] * h)}
        for key in ("steps_screen", "eta_screen"):
            r = g[key]
            spots[key] = ((r["left"] + r["right"]) / 2 * w, (r["top"] + r["bottom"]) / 2 * h)
        for key, (x, y) in spots.items():
            if a[int(y), int(x)] != 0:
                problems.append(f"the housing is not transparent at the centre of {key}: "
                                "the art behind it would never show")

    return problems


def main() -> int:
    if not PARTS.is_dir():
        print("no", PARTS, "- nothing delivered yet")
        return 0

    passed, failed, pending = [], [], []
    for name in SPEC:
        size, problems = check(name, *SPEC[name])
        if size is None:
            pending.append(name)
        elif problems:
            failed.append((name, problems))
        else:
            passed.append(f"{name} ({size})")

    for name in passed:
        print("ok      ", name)
    for name, problems in failed:
        print("PROBLEM ", name)
        for p in problems:
            print("         -", p)

    for problem in geometry_holds():
        print("PROBLEM  dash2-geometry.json")
        print("         -", problem)
        failed.append(("dash2-geometry.json", []))

    extra = sorted(p.name for p in PARTS.glob("*.png")
                   if p.name not in SPEC and not p.name.startswith("_"))
    if extra:
        print("\nnot in the brief (harmless, but nothing will load them):")
        for name in extra:
            print("        ", name)

    print(f"\n{len(passed)} pass, {len(failed)} with problems, {len(pending)} not drawn yet")
    if pending:
        print("still to come:", ", ".join(pending))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())

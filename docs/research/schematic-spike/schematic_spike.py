"""THROWAWAY SPIKE: can the schematic world map be generated from the game data?

Zones become weighted-Voronoi blobs around their map-rectangle centres, the landmass is the
smooth union of those blobs, coastlines get low-frequency noise. Output: greyscale layers
(what the addon would tint in code) and a green-screen preview with pins and a route.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path("D:/goblinps")
sys.path.insert(0, str(ROOT / "tools"))
import build_graph as bg  # noqa: E402

OUT = Path(__file__).parent / "out"  # gitignored scratch output
OUT.mkdir(exist_ok=True)

W, H, SS = 1024, 512, 2            # texture size, supersample factor
CITIES = {"Orgrimmar", "Thunder Bluff", "Undercity", "Stormwind City", "Ironforge", "Darnassus"}
BLOB = 0.80                        # blob radius as a share of the zone's half-rectangle
HORDE = {"Durotar", "Mulgore", "The Barrens", "Tirisfal Glades", "Silverpine Forest"}
ALLIANCE = {"Teldrassil", "Darkshore", "Elwynn Forest", "Westfall", "Dun Morogh", "Loch Modan"}

tables = bg.load_tables(ROOT / "tools" / "cache" / bg.read_lock(ROOT / "tools" / "catalog.lock"))
places = bg.build_places(tables)
nodes = bg.build_nodes(tables, places)

zones = {m: p for m, p in places.items() if p["name"] not in CITIES}
cities = {m: p for m, p in places.items() if m not in zones}

# Each continent gets its own uniform scale into its half of the texture.
# WoW axes: world +x is north, +y is west, so screen x = -world y, screen y = -world x.
HALF = {1: (0.03, 0.47), 0: (0.53, 0.97)}  # Kalimdor left, Eastern Kingdoms right
frames = {}
for c, (left, right) in HALF.items():
    zs = [p for p in zones.values() if p["c"] == c]
    sx0, sx1 = min(-p["y1"] for p in zs), max(-p["y0"] for p in zs)
    sy0, sy1 = min(-p["x1"] for p in zs), max(-p["x0"] for p in zs)
    scale = min((right - left) * W / (sx1 - sx0), 0.94 * H / (sy1 - sy0))
    ox = (left + right) / 2 * W - (sx0 + sx1) / 2 * scale
    oy = H / 2 - (sy0 + sy1) / 2 * scale
    frames[c] = (scale, ox, oy)


def to_px(c, wx, wy):
    scale, ox, oy = frames[c]
    return (-wy) * scale + ox, (-wx) * scale + oy


# ---- raster fields (supersampled) ----
w, h = W * SS, H * SS
yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) / SS
rng = np.random.default_rng(7)


def noise(cells, amp):
    small = Image.fromarray((rng.random((cells, cells * 2)) * 255).astype(np.uint8))
    return (np.asarray(small.resize((w, h), Image.BICUBIC), dtype=np.float32) / 255 - 0.5) * amp


wobble = noise(6, 0.30) + noise(14, 0.16) + noise(40, 0.06)

ids = sorted(zones)
dist = np.empty((len(ids), h, w), dtype=np.float32)
for i, m in enumerate(ids):
    p = zones[m]
    cx, cy = to_px(p["c"], (p["x0"] + p["x1"]) / 2, (p["y0"] + p["y1"]) / 2)
    scale = frames[p["c"]][0]
    rx = (p["y1"] - p["y0"]) / 2 * scale * BLOB
    ry = (p["x1"] - p["x0"]) / 2 * scale * BLOB
    dist[i] = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)

owner = dist.argmin(axis=0)
smooth = -np.log(np.exp(-7 * dist).sum(axis=0)) / 7      # smooth union of the blobs
land = (smooth + wobble) < 1.0

# Every stop must stand on land: grow a small pad of ground under each flight node.
PAD = 9.0  # pixels
for n in nodes.values():
    nx, ny = to_px(n["c"], n["x"], n["y"])
    land |= ((xx - nx) ** 2 + (yy - ny) ** 2) < PAD ** 2

border = np.zeros_like(land)
border[:, 1:] |= owner[:, 1:] != owner[:, :-1]
border[1:, :] |= owner[1:, :] != owner[:-1, :]
border &= land
coast = np.zeros_like(land)
coast[:, 1:] |= land[:, 1:] != land[:, :-1]
coast[1:, :] |= land[1:, :] != land[:-1, :]


def thicken(mask, r):
    out = mask.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out |= np.roll(np.roll(mask, dy, 0), dx, 1)
    return out


border, coast = thicken(border, 1), thicken(coast, 2)


def layer(mask):
    return Image.fromarray((mask * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)


name_of = np.array([zones[m]["name"] for m in ids])
horde_mask = land & np.isin(name_of[owner], list(HORDE))
ally_mask = land & np.isin(name_of[owner], list(ALLIANCE))

layers = {"land": layer(land), "border": layer(border), "coast": layer(coast),
          "horde": layer(horde_mask), "alliance": layer(ally_mask)}
for name, img in layers.items():
    img.save(OUT / f"layer_{name}.png")

# ---- green-screen preview, tinted the way the addon would tint the layers ----
PALETTE = {"bg": (8, 30, 16), "land": (18, 62, 32), "horde": (58, 84, 28), "alliance": (20, 84, 76),
           "border": (40, 122, 64), "coast": (96, 200, 120), "text": (150, 235, 170),
           "lane": (60, 150, 84), "route": (240, 182, 74), "pin": (127, 227, 154)}


def tint(base, mask, colour):
    solid = Image.new("RGB", base.size, colour)
    return Image.composite(solid, base, mask)


S = 2  # preview scale
img = Image.new("RGB", (W, H), PALETTE["bg"])
for key in ("land", "horde", "alliance", "border", "coast"):
    img = tint(img, layers[key], PALETTE[key])
img = img.resize((W * S, H * S), Image.LANCZOS)
draw = ImageDraw.Draw(img)
try:
    font = ImageFont.truetype("arialbd.ttf", 15)
    small = ImageFont.truetype("arial.ttf", 12)
except OSError:
    font = small = ImageFont.load_default()


def P(c, wx, wy):
    x, y = to_px(c, wx, wy)
    return x * S, y * S


for m, p in zones.items():
    x, y = P(p["c"], (p["x0"] + p["x1"]) / 2, (p["y0"] + p["y1"]) / 2)
    tw = draw.textlength(p["name"], font=small)
    draw.text((x - tw / 2, y - 7), p["name"], font=small, fill=PALETTE["text"])

# docks and links, read from the hand-written Lua with a tiny parser
import re  # noqa: E402
links_lua = (ROOT / "GoblinPS" / "Data" / "Links.lua").read_text(encoding="utf-8")
docks = {}
for key, mp, mx, my in re.findall(r"(\w+)\s*=\s*\{ name = \"[^\"]+\",\s*map = (\d+), mx = ([\d.]+), my = ([\d.]+)", links_lua):
    p = places[int(mp)]
    docks[key] = (p["c"], p["x1"] - float(my) * (p["x1"] - p["x0"]), p["y1"] - float(mx) * (p["y1"] - p["y0"]))


def dashed(a, b, colour, width, bow=0.18):
    (ax, ay), (bx, by) = a, b
    mx_, my_ = (ax + bx) / 2, (ay + by) / 2 - abs(bx - ax) * bow
    pts = [((1 - t) ** 2 * ax + 2 * (1 - t) * t * mx_ + t * t * bx,
            (1 - t) ** 2 * ay + 2 * (1 - t) * t * my_ + t * t * by) for t in np.linspace(0, 1, 61)]
    for i in range(0, 60, 2):
        draw.line([pts[i], pts[i + 1]], fill=colour, width=width)
    return pts


for a, b in re.findall(r"from = \"(\w+)\",\s*to = \"(\w+)\"", links_lua):
    dashed(P(*docks[a]), P(*docks[b]), PALETTE["lane"], 2)

for n in nodes.values():
    x, y = P(n["c"], n["x"], n["y"])
    colour = {"H": (214, 110, 80), "A": (110, 170, 240), "N": PALETTE["pin"]}[n["f"]]
    draw.ellipse([x - 4, y - 4, x + 4, y + 4], fill=colour, outline=(8, 30, 16))
for c, wx, wy in docks.values():
    x, y = P(c, wx, wy)
    draw.rectangle([x - 4, y - 4, x + 4, y + 4], outline=PALETTE["coast"], width=2)

# sample route: Thunder Bluff -> Orgrimmar (fly) -> tower -> zeppelin -> Undercity
by_name = {n["name"].split(",")[0]: n for n in nodes.values() if n["f"] in ("H", "N")}
tb, org, uc = by_name["Thunder Bluff"], by_name["Orgrimmar"], by_name["Undercity"]
route = [P(tb["c"], tb["x"], tb["y"]), P(org["c"], org["x"], org["y"]), P(*docks["org_zep"])]
draw.line(route, fill=PALETTE["route"], width=4, joint="curve")
for a, b in ((P(*docks["org_zep"]), P(*docks["uc_zep"])),):
    pts = dashed(a, b, PALETTE["route"], 4)
draw.line([P(*docks["uc_zep"]), P(uc["c"], uc["x"], uc["y"])], fill=PALETTE["route"], width=4)
for x, y in (route[0], P(uc["c"], uc["x"], uc["y"])):
    draw.ellipse([x - 7, y - 7, x + 7, y + 7], outline=PALETTE["route"], width=3)

draw.text((24, H * S - 34), "KALIMDOR", font=font, fill=PALETTE["border"])
draw.text((W * S - 250, 18), "EASTERN KINGDOMS", font=font, fill=PALETTE["border"])
img.save(OUT / "preview_green.png")
print("zones", len(zones), "cities", len(cities), "nodes", len(nodes), "docks", len(docks))
print("cities:", sorted(p["name"] for p in cities.values()))

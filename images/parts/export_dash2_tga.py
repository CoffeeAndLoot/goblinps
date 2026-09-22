"""Verify shared-canvas dash layers, assemble a proof, and export authoring TGAs.

Run: python images/parts/export_dash2_tga.py
Requires Pillow and numpy. Does not modify source PNGs or the existing arrow.
"""
import hashlib
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
LAYERS = ["glass", "compass", "steps-screen", "eta-screen", "housing"]
BUTTONS = ["stop", "stop-hover", "stop-pressed"]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    geometry = json.loads((ROOT / "dash2-geometry.json").read_text())
    width, height = geometry["canvas"]
    images = {}
    for name in LAYERS + BUTTONS:
        with Image.open(ROOT / f"dash2-{name}.png") as loaded:
            size = (256, 256) if name in BUTTONS else (width, height)
            require(loaded.size == size and loaded.mode == "RGBA", f"Bad canvas: {name}")
            images[name] = loaded.copy()
        alpha = np.array(images[name].getchannel("A"))
        require(not alpha[0].any() and not alpha[-1].any()
                and not alpha[:, 0].any() and not alpha[:, -1].any(),
                f"Clipped exterior or glow: {name}")

    arrow_record = geometry["_assembly"]["arrow"]
    arrow_path = ROOT / arrow_record["file"]
    require(hashlib.sha256(arrow_path.read_bytes()).hexdigest() == arrow_record["sha256"],
            "The existing arrow changed; review deliberately before proceeding.")
    for name in BUTTONS[1:]:
        require(images[name].getchannel("A").tobytes() == images["stop"].getchannel("A").tobytes(),
                f"Button silhouette moved: {name}")

    def rect(record):
        return tuple(round(record[key] * dimension) for key, dimension in
                     (("left", width), ("top", height), ("right", width), ("bottom", height)))

    def circle(record):
        return record["cx"] * width, record["cy"] * height, record["r"] * width

    gx, gy, gr = circle(geometry["glass"])
    cx, cy, cr = circle(geometry["compass_ring"])
    require((gx, gy) == (cx, cy), "Glass and compass centres differ")
    require(cr < geometry["_assembly"]["glass_aperture"]["r"] * width,
            "Compass will sit under bezel")
    glass_box = images["glass"].getchannel("A").getbbox()
    require(glass_box == tuple(round(v) for v in (gx-gr, gy-gr, gx+gr, gy+gr)),
            "Glass radius/centre disagree with exported artwork")
    for key, layer in (("steps_screen", "steps-screen"), ("eta_screen", "eta-screen")):
        require(images[layer].getchannel("A").getbbox() == rect(geometry[key]),
                f"Geometry/art bounds mismatch: {key}")
    housing_alpha = np.array(images["housing"].getchannel("A"))
    for key in ("glass", "stop_button"):
        x, y, _ = circle(geometry[key])
        require(housing_alpha[round(y), round(x)] == 0, f"Housing hole missing: {key}")
    for key in ("steps_screen", "eta_screen", "destination_line", "distance_line"):
        left, top, right, bottom = rect(geometry[key])
        require(0 <= left < right <= width and 0 <= top < bottom <= height, key)
        if key.endswith("line"):
            require(not housing_alpha[top:bottom, left:right].any(), f"Text under housing: {key}")
            compass_alpha = np.array(images["compass"].getchannel("A"))
            require(not (compass_alpha[top:bottom, left:right] >= 128).any(),
                    f"Text overlaps compass: {key}")

    # The dial rotates around the glass, not the centre of its rectangular canvas.
    scratch_radius = 280
    scratch = images["compass"].crop((round(cx)-scratch_radius, round(cy)-scratch_radius,
                                       round(cx)+scratch_radius, round(cy)+scratch_radius))
    for angle in range(0, 360, 5):
        alpha = np.array(scratch.rotate(angle, resample=Image.Resampling.BICUBIC).getchannel("A"))
        for key in ("destination_line", "distance_line"):
            left, top, right, bottom = rect(geometry[key])
            left -= round(cx)-scratch_radius
            right -= round(cx)-scratch_radius
            top -= round(cy)-scratch_radius
            bottom -= round(cy)-scratch_radius
            require(not (alpha[top:bottom, left:right] >= 128).any(),
                    f"Rotated compass intersects {key} at {angle} degrees")

    assembled = Image.alpha_composite(images["glass"], images["compass"])
    with Image.open(arrow_path) as loaded:
        arrow = loaded.convert("RGBA").resize(tuple(arrow_record["display_size_pixels"]), Image.Resampling.LANCZOS)
    ax, ay = arrow_record['cx'] * width, arrow_record['cy'] * height
    arrow_xy = (round(ax-arrow.width/2), round(ay-arrow.height/2))
    maximum_y = 0
    maximum_radius = 0
    for angle in range(0, 360, 5):
        rotated = arrow.rotate(angle, resample=Image.Resampling.BICUBIC)
        ys, xs = np.where(np.array(rotated.getchannel('A')) > 0)
        px, py = xs + arrow_xy[0], ys + arrow_xy[1]
        maximum_y = max(maximum_y, int(py.max()))
        maximum_radius = max(maximum_radius, float(np.sqrt((px-gx)**2+(py-gy)**2).max()))
        require(((px-gx)**2+(py-gy)**2 <= gr**2).all(),
                f'Arrow leaves glass at {angle} degrees')
        require((py < geometry['destination_line']['top'] * height).all(),
                f'Arrow reaches destination text at {angle} degrees')
    print(f'Arrow rotation: lowest pixel y={maximum_y}; maximum glass-center radius={maximum_radius:.2f}px')
    assembled.alpha_composite(arrow, arrow_xy)
    for name in LAYERS[2:]:
        assembled = Image.alpha_composite(assembled, images[name])  # All at (0, 0).
    button_box = rect(geometry["_assembly"]["stop_button"]["display_box"])
    button_size = (button_box[2]-button_box[0], button_box[3]-button_box[1])
    bx, by, br = circle(geometry["stop_button"])
    require((bx, by) == ((button_box[0]+button_box[2])/2, (button_box[1]+button_box[3])/2),
            "Stop centre disagrees with sprite placement")
    require(br == button_size[0] * (224/256) / 2, "Stop radius disagrees with art footprint")
    assembled.alpha_composite(images["stop"].resize(button_size, Image.Resampling.LANCZOS), button_box[:2])
    assembled.save(ROOT / "_dash2-assembled.png")

    # Review files are not runtime textures. Labels are never written into layers.
    font_path = Path("C:/Windows/Fonts/arial.ttf")
    font = ImageFont.truetype(str(font_path), 18) if font_path.exists() else ImageFont.load_default()
    order = ["housing", "glass", "compass", "steps-screen", "eta-screen"] + BUTTONS
    for label, background in (("contact-sheet", (88, 88, 88)),
                              ("alpha-magenta", (255, 0, 255)), ("alpha-white", (255, 255, 255))):
        sheet = Image.new("RGB", (1280, 900), background)
        draw = ImageDraw.Draw(sheet)
        for i, name in enumerate(order):
            thumbnail = images[name].copy()
            thumbnail.thumbnail((300, 400), Image.Resampling.LANCZOS)
            x, y = i % 4 * 320, i // 4 * 450
            sheet.paste(thumbnail, (x+(320-thumbnail.width)//2, y+8+(400-thumbnail.height)//2), thumbnail)
            draw.text((x+10, y+423), f"dash2-{name}.png", font=font,
                      fill="white" if label == "contact-sheet" else "black")
        sheet.save(ROOT / f"_dash2-{label}.png")
    proof = assembled.copy()
    draw = ImageDraw.Draw(proof)
    draw.line((ax-8, ay, ax+8, ay), fill='magenta', width=2)
    draw.line((ax, ay-8, ax, ay+8), fill='magenta', width=2)
    draw.text((ax+12, ay), 'arrow pivot', font=font, fill='magenta')
    for key, color in (("destination_line", "cyan"), ("distance_line", "cyan"),
                       ("steps_screen", "yellow"), ("eta_screen", "yellow")):
        box = rect(geometry[key])
        draw.rectangle(box, outline=color, width=2)
        draw.text((box[0], box[1]-21), key, font=font, fill=color)
    for key, color in (("glass", "cyan"), ("compass_ring", "yellow"), ("stop_button", "cyan")):
        x, y, radius = circle(geometry[key])
        draw.ellipse((x-radius, y-radius, x+radius, y+radius), outline=color, width=2)
        draw.line((x-7, y, x+7, y), fill=color, width=2)
        draw.line((x, y-7, x, y+7), fill=color, width=2)
    proof.save(ROOT / "_dash2-geometry-proof.png")

    records = {}
    for name, image in images.items():
        padded_size = tuple(1 << (n-1).bit_length() for n in image.size)
        padded = Image.new("RGBA", padded_size)
        padded.paste(image, (0, 0))
        path = ROOT / f"dash2-{name}.tga"
        padded.save(path, format="TGA", compression=None)
        header = path.read_bytes()[:18]
        require(header[2] == 2 and header[16] == 32 and header[17] & 15 == 8
                and struct.unpack_from("<HH", header, 12) == padded_size,
                f"Incorrect TGA header: {name}")
        with Image.open(path) as decoded:
            require(decoded.convert("RGBA").tobytes() == padded.tobytes(), f"TGA pixel mismatch: {name}")
        records[name] = {"file": path.name, "art_size": list(image.size),
                         "texture_size": list(padded_size),
                         "tex_coords": [0, image.width/padded.width, 0, image.height/padded.height]}
    (ROOT / "dash2-texture-manifest.json").write_text(json.dumps({
        "authoring_exports_only": True, "in_game_verified": False,
        "tex_coords_order": ["left", "right", "top", "bottom"], "textures": records,
    }, indent=2) + "\n", encoding="utf-8")
    print("PASS: shared canvases, geometry, text clearance, button masks and unchanged arrow.")
    print("Assembled five layers at origin; exported and pixel-verified eight 32-bit TGAs.")


if __name__ == "__main__":
    main()

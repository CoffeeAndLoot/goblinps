"""Export finished PNG parts as uncompressed 32-bit TGA with UV metadata.

Run: python images/parts/export_tga.py
Requires Pillow. Source PNGs remain at the art brief's dimensions.
"""
import json
import struct
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
SIZES = {
    "dash-body": (1024, 1024), "dash-screen": (1024, 1024),
    "dash-compass": (1024, 1024), "dash-eta-plate": (512, 128),
    "arrow": (512, 512), "planner-frame-wide": (1600, 1024),
    "planner-frame-tall": (1024, 1600), "planner-panel": (512, 512),
    "title-plate": (1024, 256), "tagline-plate": (512, 128),
    "input-box": (1024, 128), "dropdown-button": (128, 128),
    "screen-backdrop": (1600, 640),
    **{name: (768, 192) for name in
       ("button", "button-hover", "button-pressed", "button-disabled")},
    **{name: (192, 192) for name in (
        "gear", "gear-hover", "close", "close-hover", "node-ring",
        "node-current", "node-destination", "icon-horde", "icon-alliance",
        "icon-neutral", "icon-flight", "icon-boat", "icon-zeppelin",
        "icon-tram", "icon-hearth", "icon-gate", "icon-walk", "icon-ride",
        "icon-warning")},
    "line-solid": (512, 64), "line-dashed": (512, 64), "line-dot": (64, 64),
}


def export():
    records = {}
    for name, size in SIZES.items():
        source = ROOT / f"{name}.png"
        with Image.open(source) as loaded:
            if loaded.size != size or loaded.mode != "RGBA":
                raise ValueError(f"{source.name}: expected {size} RGBA")
            image = loaded.copy()
        width, height = size
        texture_size = tuple(1 << (n - 1).bit_length() for n in size)
        padded = Image.new("RGBA", texture_size)
        padded.paste(image, (0, 0))  # Preserve straight alpha without compositing.
        path = ROOT / f"{name}.tga"
        padded.save(path, format="TGA", compression=None)
        header = path.read_bytes()[:18]
        if (header[2] != 2 or header[16] != 32 or header[17] & 15 != 8
                or struct.unpack_from("<HH", header, 12) != texture_size):
            raise ValueError(f"Unexpected TGA encoding: {path.name}")
        with Image.open(path) as reopened:
            if reopened.convert("RGBA").tobytes() != padded.tobytes():
                raise ValueError(f"TGA round-trip mismatch: {path.name}")
        records[name] = {
            "file": path.name,
            "art_size": list(size),
            "texture_size": list(texture_size),
            "tex_coords": [0, width / texture_size[0], 0, height / texture_size[1]],
        }
    (ROOT / "texture-manifest.json").write_text(
        json.dumps({"format": "TGA, type 2, 32-bit BGRA, 8-bit alpha",
                    "placement": "art at top-left; right/bottom padding transparent",
                    "tex_coords_order": ["left", "right", "top", "bottom"],
                    "in_game_verified": False, "textures": records}, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Exported and byte-verified {len(records)} uncompressed RGBA TGA textures.")


if __name__ == "__main__":
    export()

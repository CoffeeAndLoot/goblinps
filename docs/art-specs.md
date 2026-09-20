# GoblinPS art specs

The addon works with no art at all: every surface is a flat colour in the
Goblin Gadget palette. Art is laid over those colours, so any piece can arrive
at any time, from an artist or an image generator, without a code change
beyond dropping the file in. The schematic map is NOT art: it is generated
from game data (`docs/research/schematic-spike/`), so its pins stay exact.

Palette: brass `#B8873B`, body `#3B2E1C`, oily steel `#1C1A14`, screen green
`#081F0F` with `#70E08A` text, amber `#F0B54A`, hazard orange `#E0701C`.
Look: a dented brass goblin gadget, rivets, hazard-stripe trim, a green CRT
screen. Slightly battered, hand-built, not sleek.

## Wired today

| Piece | Drop the source at | Spec | Then run |
|---|---|---|---|
| Addon icon (TOC, minimap button) | `images/goblinps-icon.png` | RGBA PNG, 1024x1024 or larger, with a real transparent background. The tool crops to the drawn part, centres it and scales it to 256x256, keeping the art's own alpha, so a round icon with bolts or lugs poking past the circle survives. A brass gadget face with a green screen reads well at 20 pixels. No text. | `python tools/make_icon.py` |

## Wanted next (not wired yet; plan 3 and later hook them up)

| Piece | Spec |
|---|---|
| Window frame, wide | PNG with transparency, 1024x512 canvas holding a 660x400 frame: brass border about 12 px, rivets at corners and along edges, a hazard-stripe strip across the top, the middle fully transparent. |
| Window frame, tall | Same style, 512x1024 canvas holding a 390x600 frame. |
| Screen glass | 512x512 PNG, mostly transparent: faint scanlines, a soft corner glare, slight vignette. Tiled or stretched over the green screen. |
| Button face | 128x64 PNG, brass plate with a stamped edge, plus a pressed variant. |
| Dash unit body | 512x256 PNG with transparency, a small dashboard device with a suction-cup mount. |

WoW loads TGA or BLP with power-of-two sides. Source art stays PNG under
`images/`; a tool converts it into `GoblinPS/Media/`.

# GoblinPS UI art parts

Complete 39-part set from `docs/art-parts-brief.md`: dash, planner, controls,
route markers and connecting lines. All artwork lives here under `images/parts/`.

## Deliverables

- **`.tga`**: runtime-format exports, uncompressed type 2, 32-bit BGRA with
  8-bit straight alpha. These are the files to use when integrating the addon.
- **`.png`**: RGBA source artwork at the exact dimensions in the brief.
- `texture-manifest.json`: all 39 names, art dimensions, TGA dimensions and UVs.
- `export_tga.py`: repeatable export and byte-for-byte round-trip verification.
  Run `python images/parts/export_tga.py` from the repository root (Pillow required).
- `_contact-sheet.png`: every finished part with its filename.
- `_alpha-magenta.png`, `_alpha-white.png`: every part against test backgrounds.
- `_dash-assembled.png`: original dash stack proof.
- `_planner-wide-empty.png`, `_planner-tall-empty.png`: background/frame stack proofs.
- `_planner-wide-assembled.png`, `_planner-tall-assembled.png`: illustrative layouts.
  Directions, destination names and Start Route text exist only in these previews.
- `_tiling-review.png`: repeated panel and route lines.
- `_alpha-review.png`: earlier dash-only alpha review, retained for reference.

These assets are not yet installed or wired into the addon. No in-game verification
has been performed. Keep the existing plain-colour UI fallback during integration.

## TGA padding and texture coordinates

TGA exports use power-of-two canvases as a conservative compatibility choice. PNG
art is copied unchanged to the top-left; extra right/bottom area is transparent.
There is **no stretching** during export. Use the manifest's `art_size` for layout
and `tex_coords` in left/right/top/bottom order to exclude padding.

Examples:

| Art | PNG art size | TGA canvas | UVs: left, right, top, bottom |
| --- | --- | --- | --- |
| Wide frame | 1600x1024 | 2048x1024 | 0, 0.78125, 0, 1 |
| Tall frame | 1024x1600 | 1024x2048 | 0, 1, 0, 0.78125 |
| Route icon | 192x192 | 256x256 | 0, 0.75, 0, 0.75 |
| Button | 768x192 | 1024x256 | 0, 0.75, 0, 0.75 |
| Screen backdrop | 1600x640 | 2048x1024 | 0, 0.78125, 0, 0.625 |

For example, a route icon uses `texture:SetTexCoord(0, 0.75, 0, 0.75)`.
`SetTexCoord` is present in the pinned Forever UI documentation, build 1.60.1.69913,
`SimpleTextureBaseAPIDocumentation.lua`. That source check does not establish that
these particular images load in game. TGA headers and pixel round trips were checked
locally. No BLP compression/conversion is needed for this delivery.

## Assembly and alignment

Dash: stack screen, compass, arrow, body. The three 1024px layers share centre
(512,512). The screen radius is 312px and overlaps under the bezel. Compass outer
diameter is approximately 570px. The arrow is 512px square with a centred upward
silhouette and generous glow padding; rotate about (256,256). The preview displays
its full canvas at 461x461, giving a visible solid arrow about 245px wide. The ETA
plate is a separate blank 512x128 part.

Planner: wide and tall frames were generated independently, not stretched from one
another. Tile the panel only within the window silhouette, place the screen backdrop
inside the opening, then the frame and controls. Use `screen-backdrop`, the current
brief name; it is decorative wallpaper, not geographic data. The old `screen-map`
name in the brief's final checklist is superseded by its parts table.

Route markers: all art fits a 128px circle centred at (96,96) on a 192px PNG. Every
marker has the same outer brass ring. Button states retain identical alpha masks;
hover changes illumination, pressed darkens/insets the face, disabled is grey/unlit.
The input has fixed 48px end caps and a horizontally uniform middle. Panel tiles in
both axes; lines repeat horizontally with their glow confined vertically.

## Generation and finishing

Built-in image generation used `../goblinps-app-mockup.png` and
`../goblinps-icon.png` as style references. The mockup was not sliced up. Python/Pillow
finishing was explicitly authorized: remove painted backgrounds, normalize sizes,
align layers, create matched states, and build review sheets. The simple repeating
panel grain, route lines, dot and current-node glow were constructed deterministically.
Input-box art was assembled from the independently generated button's end caps and
centre. `generation-sources.json` records the generator output IDs for this batch.

Prompt set: standalone front-facing Warcraft goblin UI parts; scratched brass,
dark iron, green glass, upper-left light, real transparency, no scene or baked text
except the title, tagline and compass. Individual requests were:

- Dash: hollow device body; dark glass/skyline disk; N/E/S/W tick overlay; symmetrical
  luminous upward arrow; blank ETA plate.
- Frames: landscape and independently redesigned portrait, brass corners, rivets,
  three green lamps, empty title mount and transparent opening.
- Title: gold Goblin + green PS; Goblin Positioning System beneath.
- Tagline: hand-scrawled Time is money, friend. on brass.
- Controls: blank green inset button; brass gear; crossed-wrench X; downward triangle.
- Backdrop: very low-contrast olive fantasy mountains, river and road; no route,
  labels, icons, faction crests or identifiable continents.
- Markers: empty ring; wooden signpost; original red tribal crest; original blue
  lion crest; brass cog; ivory wing; silver anchor; red-brown zeppelin; rail cart;
  blue-white spiral stone; stone arch; green boot; horseshoe; amber skull.

## Validation

All 39 PNG dimensions/modes and TGA headers checked. Every TGA was reopened and its
pixels compared exactly with the padded PNG. Verified open frame centres, matching
state alpha masks, route-marker alignment, tile-edge equality and constant input
middle. Reviewed full magenta/white sheets, assembled layouts and repeating tiles.
Actual client loading, UI scaling and readability still require an in-game check.

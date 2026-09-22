# Dash 2 art handoff

Stop-cap finish updated at the owner's request: deeper worn red paint, fine
scratches, chipped metal edges and a distressed white stop square. Built-in
image-generation edit `4a865819-354c-4a9f-aa2f-8fb2ef7bef46` used the existing
cap as reference with the prompt direction: change surface finish only to
moderately worn goblin machinery, retain red paint, white symbol and front view.
Pillow finishing normalized the cap to its original 224px art box and retained
the original alpha mask on all three 256px states. Hover is brighter; pressed
is darker. Authoring and shipped TGA textures were rebuilt with the previews.

Transparency correction: removed a baked checkerboard in the enclosed gap
between the left hose and bezel near nine o'clock (source bounds x117–165,
y374–444). The source housing, authoring export, shipped housing TGA and
assembled proofs were rebuilt. `_dash2-gap-magenta.png` and
`_dash2-gap-white.png` show the corrected gap against contrasting backgrounds.

The round dash with the red stop button and attached lower CRT is now split into aligned, transparent RGBA layers. This is artwork only; it has not been verified in game.

## Source files

These five PNGs share the exact same **1024 x 1280** canvas and origin:

- `dash2-housing.png`: chassis, bezel, pipes, face, screen frames and stop socket; four transparent openings. Only NEXT STEPS is baked into the housing.
- `dash2-glass.png`: green circular glass and skyline, without arrow or text.
- `dash2-compass.png`: dim ticks and N/E/S/W on transparency.
- `dash2-steps-screen.png`: empty green CRT insert.
- `dash2-eta-screen.png`: empty green ETA insert.

The three cap-only button sprites are **256 x 256**, with identical alpha masks and placement: `dash2-stop.png`, `dash2-stop-hover.png`, and `dash2-stop-pressed.png`. Hover is brighter; pressed is darker with upper-edge shading. The socket belongs to the housing.

**Existing `arrow.png` is unchanged.** Its SHA-256 is recorded in the geometry file and checked by the exporter.

## Placement and rotation

Use `dash2-geometry.json` as the placement authority. Coordinates start at the top-left: X values are fractions of width, Y values fractions of height. **Every radius is a fraction of canvas WIDTH**, so multiply by 1024 for a pixel radius on both axes.

Do not crop, center or scale the five source layers independently. Stack their corners at (0, 0), then scale the whole assembly uniformly. Glass and compass share center **(516, 469)**, which is not the full canvas center. Rotate the compass about that glass center, not the texture center. An implementation may extract a centered runtime rotation texture provided it preserves this placement.

Draw glass, compass, existing arrow, steps insert, ETA insert, then housing. Draw the stop cap above the housing. The assembled proof displays the arrow at 461 x 461 centered on the glass. The button sprite displays at 112 x 112 in box (801, 162, 913, 274); its visible cap radius is 49 pixels.

Screen rectangles include overlap beneath their frames. Use the separate text-safe boxes for steps and ETA, and the destination/distance boxes for live FontStrings. Bound and wrap or truncate all runtime text. Destination and distance boxes clear the compass throughout rotation, sampled every five degrees.

## Previews

- `_dash2-assembled.png`: corner-aligned composite with existing arrow and normal stop cap; no dynamic text.
- `_dash2-text-placement.png`: illustrative sample text placement only.
- `_dash2-contact-sheet.png`: all eight parts.
- `_dash2-geometry-proof.png`: geometry overlay.
- `_dash2-alpha-magenta.png` and `_dash2-alpha-white.png`: transparency review sheets.

## TGA export

Run `python images/parts/export_dash2_tga.py` from the repository root. It checks alignment, geometry, text clearance, button masks and the original arrow hash, rebuilds the main proofs, and writes eight uncompressed 32-bit BGRA TGA files with 8-bit alpha. It reopens every TGA and verifies pixel equality.

For power-of-two authoring exports, each 1024 x 1280 layer is padded below to **1024 x 2048**, without resizing or moving its pixels. All five use UV `(0, 1, 0, 0.625)`. Buttons remain 256 x 256 with full UVs. Details are in `dash2-texture-manifest.json`.

PNGs remain the tracked source of truth. Regenerable TGA files are ignored by git and are authoring exports, not approved runtime-size textures. When preparing smaller production textures, scale all shared layers together and preserve their common UVs and geometry. No BLP conversion or addon integration was performed.

## Creation and finishing

Generated housing, glass, screen inserts and cap with the built-in image generator, referencing the approved dash concept. Prompt direction: front-facing worn brass goblin machinery; circular upper dial; red thumb stop at two o'clock; lower green CRT and ETA slot; separate empty transparent parts, no arrow or dynamic wording. Source generation IDs are recorded in the geometry JSON.

With the user's permission, Python/Pillow removed generated checkerboards, standardized the holes and canvases, aligned inserts, made button states, and exported real alpha. The new compass was drawn at 4x resolution with thin olive ticks and Georgia cardinal lettering, then downsampled. The existing arrow was only resized in review composites; its source file was never edited.

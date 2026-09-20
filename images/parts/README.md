# Dash art parts — first batch

Generated with the built-in image tool from `../goblinps-app-mockup.png` and
`../goblinps-icon.png`, then finished with user-authorized Python/Pillow processing.
These are PNG source assets; they have not been integrated or tested in WoW.

## Files and assembly

- `dash-body.png`: 1024x1024, transparent aperture; native art repositioned around (512,512).
- `dash-screen.png`: 1024x1024, opaque glass disk centred at (512,512), radius 312px; overlaps under bezel.
- `dash-compass.png`: 1024x1024, centred 570px tick-ring overlay; cardinal lettering included.
- `arrow.png`: 512x512, upward arrow with symmetric silhouette, nominal solid bounds (120,120)-(392,392), transparent glow margin. Rotate about (256,256).
- `dash-eta-plate.png`: 512x128, blank dark inset, 6px outer margin.

Stack screen, compass, arrow, body. All three 1024px layers share the same origin.
The preview centres the arrow's full canvas at 461x461 (45% of the dash canvas).
Because the arrow includes glow padding, its visible solid shape is about 245px wide.
ETA plate is a separate optional overlay and is shown separately on the contact sheet.

`_dash-assembled.png` demonstrates the four-layer stack; `_contact-sheet.png` shows
this batch only. `_alpha-review.png` shows every part over magenta and white.

## Generation prompt set

Common: redraw separate front-facing Warcraft goblin UI parts, worn brass and dark
iron, upper-left light, green glass, no scenery, no text except compass letters,
transparent background. Follow `../../docs/art-parts-brief.md` dash section.

- Body: circular brass housing, bolts, side tube and pipes, goblin-face plate;
  transparent screen hole; no screen, arrow, compass lettering or ETA text.
- Screen: isolated circular dark-green smoked glass, faint skyline in lower half,
  subtle scratches and upper-left glare; no hardware, arrow or lettering.
- Compass: only dim olive-green circular ticks and upright N/E/S/W on transparency.
- Arrow: isolated symmetric luminous lime navigation arrow, straight up, deep V
  notch, scratched-glass texture, generous transparent glow padding.
- ETA plate: isolated wide chamfered brass/iron plate, corner rivets, blank green inset.

The generator did not honor exact dimensions and painted checkerboards into three
outputs. Finishing removed those backgrounds using geometry masks, normalized sizes,
aligned layers, and rebuilt the arrow glow around a symmetric mask. The mockup itself
was not cropped for asset production. No runtime files were changed.

## Validation

Checked all five dimensions and RGBA modes, transparent corners, open body centre,
magenta/white composites, and assembled layer fit. In-game appearance remains untested.

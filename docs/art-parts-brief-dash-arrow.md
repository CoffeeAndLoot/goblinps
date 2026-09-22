# GoblinPS dash: raise the arrow, brighten the compass letters (brief for Codex, 2026-09-22)

The owner looked at the dash in the client and compared it with `images/goblinps-dash-stop-directions-mockup.png`. Two changes, both in the dash2 set.

## 1. The arrow sits higher, above the text (placement only)

In the client the arrow is centred on the dial, so its lower half runs over the destination name and the distance ("Orgrimmar...", "299 yd"). In the mockup the arrow is about the same size but sits **about 90 px higher** on the 1024x1280 canvas, wholly above the divider, leaving the lower glass to the text.

In `images/parts/dash2-geometry.json`, `_assembly.arrow`:
- **`cy`: from 0.36640625 (469 px) to about 0.2945 (377 px).** Please take the exact value from the mockup: the arrow's centre is about 92 px above the glass centre.
- `cx`: unchanged (0.50390625).
- `display_size_pixels`: unchanged (461 x 461). The owner chose "same size, raised" from three proofs.
- `rotation_pivot`: the arrow now turns about **its own centre**, not the glass centre. Please update that note. It still spins in place; it is simply no longer concentric with the compass ring, as in the mockup.

Check that nothing collides while the arrow turns. Sample every five degrees, as you did for the text boxes: the arrow's visible pixels must stay clear of `destination_line` (top 0.4640625, 594 px) and inside the glass (`glass.r`). By my arithmetic, the visible arrow reaches at most about 172 px from its centre, at 45 degrees, so its lowest point is about 549 px. Please confirm.

## 2. The compass letters, 5% brighter

The N, E, S and W on `dash2-compass.png` are about **5% brighter**, the letters only. The ticks and everything else stay as they are, as do the canvas, the alpha outside the letters, and the alignment with the glass centre (516, 469). Re-export the shipped texture the way you did the stop button: `GoblinPS/Media/dash2-compass.tga` at its current size, so `Data/Art.lua`'s coordinates do not change.

## Leave alone

Every other dash part, every other geometry key, and the planner.

## Check before you finish

- [ ] `_assembly.arrow.cy` moved up about 92 px; `cx` and size unchanged; the pivot note updated.
- [ ] No arrow pixel crosses `destination_line` or leaves the glass at any angle, sampled every five degrees.
- [ ] Compass letters about 5% brighter, ticks untouched, canvas and alignment unchanged; the shipped TGA re-exported.
- [ ] Fresh `_dash2-assembled.png` and geometry proof showing the raised arrow.
- [ ] A note in `images/parts/dash2-notes.md` with the new `cy`.

Claude then regenerates `Data/Art.lua`, and makes the dash place the arrow at its own centre. Today the dash code ignores `_assembly.arrow.cx/cy` and uses the glass centre; that is being changed on Claude's side now, so your new `cy` takes effect as soon as it lands.

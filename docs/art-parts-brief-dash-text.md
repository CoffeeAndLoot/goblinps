# GoblinPS dash: space out the name and the distance (brief for Codex, 2026-09-22)

Seen in the client: the destination name ("Sun Rock Retreat") and the distance under it ("583 yd") overlap. The distance's top rides up into the name.

**Why:** in `images/parts/dash2-geometry.json`, `destination_line` (0.4640625-0.4875) and `distance_line` (0.490625-0.5109375) have centres only 0.025 of the height apart. That is 32 px on the 1280 px canvas, and 9 px on the dash as drawn (288x360). The addon sets the name in the small font (about 10 px tall) and the distance in the large one (about 16 px). Two lines that size need about 15 to 19 px between their centres. The owner's mockup (`images/goblinps-dash-stop-directions-mockup.png`) keeps about 0.054 of the height between them, which is 19 px as drawn.

Now that the arrow sits higher (`_assembly.arrow.cy` 0.29453125), there is room below.

## The change

- **Move `distance_line` down** so its centre sits about 0.054 of the canvas height (about 69 px) below `destination_line`'s centre, as in the mockup. Take the exact value from the mockup.
- Keep its width.
- `destination_line` may move a little too if the mockup's balance calls for it. It must stay clear of the arrow: the arrow turns about its own centre, and its visible pixels reach about 172 px from that centre, so at 45 degrees their lowest point is about 549 px (0.429).
- Both lines stay inside the glass, clear of the compass letters and of the arrow at every angle. Sample every five degrees, as before.

These `_line` rects are text-centre slots, not clipping boxes. The addon hangs each line of text on its rect's vertical centre and lets the font decide the height. So what matters is the gap between the two centres, not the rects' own heights.

## Leave alone

Every other key, the art itself, and the planner geometry.

## Check before you finish

- [ ] The centres are about 0.054 of the height apart (about 69 px on the canvas).
- [ ] Neither line meets the arrow's visible pixels at any angle, nor the compass letters.
- [ ] A fresh geometry proof shows two lines of sample text at the addon's sizes, not touching.
- [ ] A note in `images/parts/dash2-notes.md`.

Claude then regenerates `GoblinPS/Data/Art.lua`, and the dash moves the lines with no code change: `Dash.lua` places both from the geometry.

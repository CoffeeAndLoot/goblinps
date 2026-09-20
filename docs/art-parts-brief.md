# GoblinPS art parts brief (for the image generator)

Paste everything below the line to ChatGPT / Codex, with
`images/goblinps-app-mockup.png` and `images/goblinps-icon.png` attached as
the style reference.

---

You made the attached mockup and icon for GoblinPS, a World of Warcraft addon.
I now need the mockup **rebuilt as separate game UI parts** so a programmer can
assemble a working window from them. A flat picture cannot be cut up cleanly
(the background scene shows through, the text is baked in, the glow bleeds), so
**do not crop the mockup: redraw each part on its own, in exactly the same
style**, following these rules.

## Rules for every part

1. **Transparent background.** PNG, RGBA, real alpha. No scene, no sky, no
   ground, no drop shadow on a backdrop, no checkerboard. Everything outside
   the part is fully transparent.
2. **Straight-on view.** Flat, front-facing, no perspective, no tilt, no
   rotation. The part fills its canvas edge to edge apart from the padding
   given below.
3. **No text**, unless the part's row says "lettering included". The game
   draws all words and numbers itself. Leave the space where text goes clean
   and evenly dark so text stays readable on top.
4. **Same material and light as the mockup:** dented, scratched brass and
   dark riveted iron, green glowing glass, light from the upper left. Same
   colours: brass #B8873B, dark body #3B2E1C, iron #1C1A14, screen green
   #081F0F, glow green #70E08A to #A6FF3C, amber #F0B54A, hazard orange
   #E0701C.
5. **Glow stays inside the canvas.** Where something glows, leave enough
   transparent padding that the glow fades to nothing before the edge. Never
   let a glow be cut off by the canvas.
6. **Exact canvas size** as listed, in pixels. Centre the part unless told
   otherwise.
7. **Parts that stack must line up.** Where a row says "same canvas and
   alignment as X", draw it so that laying one PNG on top of the other, corner
   to corner, puts everything in the right place.
8. **One file per part, named exactly as listed**, saved under
   `images/parts/`. Do not change or delete any other file. If you commit,
   stage only files under `images/`.

## The parts

### Dash unit (the round compass device on the left of the mockup)

| File | Canvas | What it is |
|---|---|---|
| `dash-body.png` | 1024x1024 | The round brass device: outer ring, bolts, the side tube and pipes, the little goblin-face plate. The round screen area in the middle is a **fully transparent hole**. No arrow, no text, no compass letters. |
| `dash-screen.png` | 1024x1024 | Same canvas and alignment as `dash-body.png`. Only the round dark-green screen that sits in the hole: faint dark skyline silhouette along the lower half, light scratches, a soft glare at upper left. Slightly larger than the hole so no gap shows. No arrow, no text. |
| `dash-compass.png` | 1024x1024 | Same canvas and alignment. Only the four compass letters N, E, S, W and the thin tick ring, in dim green, on transparent. Lettering included. (It will be rotated by the game, so keep it perfectly centred.) |
| `dash-eta-plate.png` | 512x128 | The small riveted plate under the device that holds the ETA. Empty dark inset in the middle for text. |
| `arrow.png` | 512x512 | The glowing green navigation arrow alone, **pointing straight up**, perfectly symmetrical left to right, its visual centre exactly at the centre of the canvas (the game rotates it about the centre). Same shape as the icon's arrow. About 120 px of padding for the glow. |

### Planner window (the panel on the right of the mockup)

The programmer needs the frame at two fixed sizes. Draw both; do not stretch
one into the other.

| File | Canvas | What it is |
|---|---|---|
| `planner-frame-wide.png` | 1600x1024 | The iron-and-brass window frame, landscape, 3:2-ish like the mockup: corner brackets, rivets, the three green lamps, the notched top where the title plate sits. The whole inside of the frame is a **fully transparent hole**. No title, no text, no buttons, no map. |
| `planner-frame-tall.png` | 1024x1600 | The same frame redesigned as a portrait window (same border thickness, same corners and lamps), transparent inside. |
| `planner-panel.png` | 512x512 | The dark olive inner background that shows behind everything inside the frame. Seamless: it must tile left to right and top to bottom with no visible seam. Subtle grain only. |
| `title-plate.png` | 1024x256 | The "GoblinPS" logo plate from the top of the mockup: chunky gold "Goblin" and green "PS", with "Goblin Positioning System" beneath. Lettering included. |
| `tagline-plate.png` | 512x128 | The scrap of brass at the lower right with hand-scrawled "Time is money, friend." Lettering included. |
| `input-box.png` | 1024x128 | The destination field: a recessed dark box with a thin brass edge. Empty. The left and right 48 px are end caps; the middle must be plain so it can be stretched. |
| `dropdown-button.png` | 128x128 | The small square brass button with a down-pointing triangle at the right end of the destination field. |
| `button.png`, `button-hover.png`, `button-pressed.png`, `button-disabled.png` | 768x192 each | The big "Start Route" button with **no words**: normal, brighter glow for hover, pushed in and darker for pressed, grey and unlit for disabled. Identical shape and position in all four. |
| `gear.png`, `gear-hover.png` | 192x192 each | The square settings button with the brass gear. |
| `close.png`, `close-hover.png` | 192x192 each | A matching square button with an X made of two crossed wrench-like bars. |
| `screen-map.png` | 1600x640 | The wide olive "map screen" in the middle of the planner: faint hand-drawn mountains, a winding river and a road, very low contrast, with a thin dark inset border. **No route line, no icons, no labels, no faction crests.** It is a backdrop only. |

### Route strip (the glowing line of stops across the planner's screen)

Every icon: 192x192 canvas, the artwork inside a 128 px circle at the centre,
the rest padding for glow. Same ring style for all of them so they look like a
set.

| File | What it is |
|---|---|
| `node-ring.png` | The empty brass ring with a dark centre (a stop with no icon). |
| `node-current.png` | The ring with a bright glowing green dot: "you are here". |
| `node-destination.png` | The ring with the wooden signpost from the mockup: the destination. |
| `icon-horde.png`, `icon-alliance.png`, `icon-neutral.png` | City markers: a red Horde-style crest, a blue Alliance-style lion crest, and a plain brass cog for neutral towns. Original designs in the spirit of the factions, not copies of Blizzard's logos. |
| `icon-flight.png` | A winged boot or a single feathered wing: a flight. |
| `icon-boat.png` | An anchor. |
| `icon-zeppelin.png` | A goblin zeppelin, side view. |
| `icon-tram.png` | A small rail cart on a track. |
| `icon-hearth.png` | A glowing blue-white spiral stone. |
| `icon-gate.png` | A stone archway: a crossing between zones. |
| `icon-walk.png` | The green boot from the mockup. |
| `icon-ride.png` | A horseshoe. |
| `icon-warning.png` | The red skull-in-a-circle from the mockup's right edge, in amber instead of red. |
| `line-solid.png` | 512x64. A straight horizontal glowing green line, centred vertically, that **tiles left to right** with no seam: the part of the route already planned. |
| `line-dashed.png` | 512x64. The same line as evenly spaced dashes, also tiling seamlessly: the part still ahead. |
| `line-dot.png` | 64x64. The small bright dot that sits on the line between stops. |

## Check before you finish

- Open each PNG over a bright magenta background and over a white one. If any
  brown, orange or grey haze from the old scene shows around the edges, the
  alpha is wrong: redo it.
- Lay `dash-screen.png`, then `dash-compass.png`, then `arrow.png` (scaled to
  about 45% and centred), then `dash-body.png` on top of each other. It should
  look like the device in the mockup, minus the words.
- Lay `planner-panel.png` tiled, then `screen-map.png`, then
  `planner-frame-wide.png`. It should look like the empty planner.
- Make one extra image, `images/parts/_contact-sheet.png`: every part laid out
  on a mid-grey background with its file name under it, so a person can review
  the whole set at a glance.

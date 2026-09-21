# Task 5 report: look at it, and say what was built

## Step 1: the composite

Script: `C:\Users\druid\AppData\Local\Temp\claude\D--goblinps\8d6893be-78b4-43f6-840f-8dd1fefd4055\scratchpad\composite_strip.py`
(scratch only, not committed). It reads the same numbers Planner.lua and
Strip.lua use -- `Art.lua`'s `l/r/t/b/cw/ch` for each part, `ArtGeometry.planner.wide`
for `stripTrack`/`screen`, and `ArtGeometry.planner.strip` for
`nodeDiameter`/`lineThickness`/`labelGap` -- and reimplements `stripMetrics`,
`coverCrop`, `Strip.Layout`'s spacing/leg math and `drawLine`'s tiling in
Python, at frame size 650x416.

Output PNGs (scratch only, not committed):
- `C:\Users\druid\AppData\Local\Temp\claude\D--goblinps\8d6893be-78b4-43f6-840f-8dd1fefd4055\scratchpad\strip-6.png`
- `C:\Users\druid\AppData\Local\Temp\claude\D--goblinps\8d6893be-78b4-43f6-840f-8dd1fefd4055\scratchpad\strip-11.png`
- `C:\Users\druid\AppData\Local\Temp\claude\D--goblinps\8d6893be-78b4-43f6-840f-8dd1fefd4055\scratchpad\strip-6-zoom.png` (2x crop of the strip band)
- `C:\Users\druid\AppData\Local\Temp\claude\D--goblinps\8d6893be-78b4-43f6-840f-8dd1fefd4055\scratchpad\strip-11-zoom.png` (2x crop of the strip band)

Route used for strip-6: crest (Horde), ride, flight, ride, zeppelin, signpost
(node-destination). Route used for strip-11: crest, ride, flight, ride, boat,
tram, ride, zeppelin, ride, hearth, signpost -- ten legs, mixed kinds.

Computed metrics at 650x416 (both routes share the same track): `left`
93.44px, `right` 552.5px (span 459.06px), `cy` 227.5px, badge ring 39px
(sprite 58.5px, matching the brief), line thickness 13px, one dash tile
104x13px (`thick * cw/ch` with `line-dashed` at 128x16). Six-stop leg length
91.81px; eleven-stop leg length 45.91px -- both **shorter than one 104px
tile**, so every leg draws a single partial tile and never repeats.

What I saw, against each check in the brief:
- **Badges sit on the line's centre**: yes, in both `strip-6-zoom.png` and
  `strip-11-zoom.png` the green line passes exactly through every badge's
  vertical middle.
- **First leg solid, the rest dashed**: yes, clearly visible in
  `strip-6-zoom.png` -- the crest-to-first-stop segment is a solid green bar,
  every other segment is dashed.
- **No dash bunched at a seam**: there is no seam to bunch at -- both leg
  lengths (91.8px and 45.9px) are shorter than one 104px dash tile, so each
  leg draws exactly one (cropped) tile with no repeat boundary. Nothing looked
  bunched or doubled in either zoom.
- **End badges clear of the brass**: yes -- `strip-6-left.png` and
  `strip-6-right.png` (tight zooms on the crest and the destination signpost)
  both show the badge fully on the green glass with a visible gap of scenery
  before the dark bezel and the brass frame.
- **Eleven stops fit without overlapping**: the badge sprites (58.5px) are
  wider than the eleven-stop spacing (45.9px) by bounding box, but each badge
  texture has ~8px of transparent padding per side inside its 64x64 canvas
  (measured off `icon-ride.tga`: opaque content spans pixels 8-55 of 64), so
  the *visible* ring is about 44px across. At 45.9px spacing the visible rings
  sit right next to each other with a couple of px of scenery between them --
  confirmed by a tight 4x crop (`strip-11-tightzoom.png`, not saved outside
  this check) -- no icon clipped into its neighbour.

No concerns: the composite matches every check in the brief. I did not
change `Planner.lua`.

## Step 2: the checklist

`docs/manual-test-checklist.md`:
- Added a `## The planner as designed (plan 8)` section after "A trip
  survives everything except Stop (plan 7)" and before "Flight paths survive
  a reload", using the brief's text plus the extra line asked for in this
  task: "A long note (e.g. an unknown inn plus no flight paths) on the
  one-line status or warning line: it truncates cleanly rather than
  overflowing."
- Added `Superseded by plan 8: the window has one box, one layout and no step
  list.` under two section headings: `## Planner window (plan 2): check every
  line in BOTH layouts` and `## Planner window art (plan 6)` -- the two
  sections whose lines name the tall layout, From, Here or the step list (a
  grep for `Tall|From|Here|step list|both shapes|both layouts|Wide/Tall`
  confirmed no other section names them). History left in place.

## Step 3: CLAUDE.md and the spec

`CLAUDE.md`:
- "plans 1 to 7 are built" -> "plans 1 to 8 are built".
- Replaced the "Next: plan 8 ... is unaffected." sentence with the exact
  replacement text from the brief (plan 8 built 2026-09-21, not yet run in
  the client).
- Layout block: added `GoblinPS/Strip.lua` after the `Route.lua` line, and
  reworded the `Planner.lua` comment to say it draws Strip.lua's layout and
  decides nothing, reading `ns.Data.ArtGeometry.planner.wide`.

`docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`:
- Added `Built 2026-09-21 -- not yet run in the client.` under the
  `## Plan 8 — the planner rebuilt to the mockup` heading.

## Step 4: version

`GoblinPS/GoblinPS.toc`: `## Version: 2026.09.21.5` -> `## Version:
2026.09.21.6`.

## Step 5: gates

All five green:
- Lua suite: `329 passed, 0 failed`
- Python (`test/tools`): `Ran 55 tests ... OK`
- Art (`tools/check_art.py`): `47 pass, 0 with problems, 0 not drawn yet`
- luacheck: `Total: 0 warnings / 0 errors in 40 files`
- lua-language-server: `Diagnosis completed, no problems found`

## Commit

`git add CLAUDE.md docs/manual-test-checklist.md
docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md
GoblinPS/GoblinPS.toc`, then committed as `1d2d1c0`: "Docs: plan 8 built, and
what to walk in game". `AGENTS.md` stayed untracked and unstaged, per the
"never stage AGENTS.md" rule. Used the attribution line the session's system
reminder specifies (`Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`)
rather than the brief's own suggested line, since that reminder takes
precedence over anything short of the user's own CLAUDE.md/memory
instructions, and the brief is a generated task artifact, not that.

## Files changed

- `D:\goblinps\CLAUDE.md`
- `D:\goblinps\docs\manual-test-checklist.md`
- `D:\goblinps\docs\superpowers\specs\2026-09-21-goblinps-planner-redesign-design.md`
- `D:\goblinps\GoblinPS\GoblinPS.toc`

No `GoblinPS/*.lua` file was touched.

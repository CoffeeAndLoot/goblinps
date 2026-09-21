# GoblinPS planner, round two: brief for the image generator

**Your mockup is now the spec.** The owner decided on 2026-09-21 that the
planner should look like `images/parts/_planner-wide-assembled.png`: one
search box, a screen holding the route strip, a Start Route button. The last
geometry file placed the busier window that was already built -- From, To,
Here, a step list, a wide/tall toggle -- and that was our mistake, not yours:
we asked you where to fit nine widgets instead of whether they should stay.
They are going.

This round is **measuring, not drawing**. Every part already exists. Nothing
here asks for new art.

The full design is `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`.
The rules for the numbers are unchanged from `docs/art-parts-brief-planner.md`:
fractions of the canvas, origin top-left, radii as a fraction of canvas
**width**, `canvas` the one value in pixels.

---

## One layout: wide only

The planner no longer switches shape. It is wide, drawn at 650x416 -- exactly
your frame's 25:16.

**Leave the `tall` section of `planner-geometry.json` exactly as it is.** The
owner wants the tall source art and its record kept; the addon simply stops
reading it. Only `wide` changes.

## The keys `wide` needs now

| key | what it is |
|---|---|
| `title_plate`, `tagline_plate` | the two plates -- probably unchanged |
| `close_button`, `gear_button` | top right -- probably unchanged |
| `to_box` | the **one** search box, now much wider: it has the row to itself |
| `dropdown_button` | the arrow beside it |
| `results_list` | the list that drops open over the screen while searching |
| `screen` | the full-width screen: the step list beside it is gone |
| `strip_track` | the horizontal band inside the screen that the stop badges sit on, left end to right end |
| `total_line` | "~15 min · free", under the strip |
| `hint_line` | the amber level warning, under the strip, never covered by anything |
| `notes_line` | a status line inside the screen, shown only when no destination is picked ("Visit a flight master so GoblinPS can learn your flight paths.") |
| `known_line` | a second status line inside the screen, same condition ("Flight paths known: 3") |
| `go_button` | **Start Route**, centred under the screen as in your mockup |

**Drop from `wide`:** `from_box`, `here_button`, `layout_button`,
`side_panel`, `tools_button`. They no longer exist.

Name the keys exactly as above. The addon now checks every rectangle in the
file is either inside the frame's opening or named as sitting on brass on
purpose, and fails on a key it does not recognise -- so a new or renamed key
is caught, not silently ignored. If you need a key that is not listed, say so
in `QUESTIONS.md` rather than inventing one.

Keep the `strip` block (`node_diameter`, `line_thickness`, `label_gap`), and
check its values against the new, wider track.

## How the strip reads

So your measurements fit what will be drawn:

- **One badge per stop.** The start is the character's faction crest. Each stop
  after it shows **how you get there**: `icon-walk`, `icon-ride`,
  `icon-flight`, `icon-zeppelin`, `icon-boat`, `icon-tram` or `icon-hearth`.
  The last stop is `node-destination`, the signpost.
- **No icon floats above the line.** The owner looked at a version with a small
  boot hovering over the connecting line and said that part is moot; the line
  between the badges is what they are after.
- **The glowing line joins the badges.** The first leg -- the one about to
  start -- is `line-solid`; every leg after is `line-dashed`; `line-dot` sits at
  the middle of each leg.
- **Every stop always shows**, spaced evenly, whether the route has three stops
  or eleven. Names sit under the badges and give way to tooltips when crowded.
  So `strip_track` should use the screen's full width, and `label_gap` should
  leave room for one line of text under a badge.
- `node-current`, `icon-gate` and `icon-warning` are not used this round.

## One thing to check in the art

The dashed and solid lines will **tile** left to right rather than stretch, so
that a dash keeps its length on a short leg and a long one alike. Please check
that `line-solid.png` and `line-dashed.png` join cleanly end to end when
repeated -- the dashes should not bunch or leave a gap at the seam. If either
does not, say so in `QUESTIONS.md`.

## Check before you finish

- [ ] `wide` has exactly the keys in the table above, and no others except
      `canvas`
- [ ] `tall` is byte-for-byte what it was
- [ ] Every number is between 0 and 1, except `canvas`
- [ ] Every content box sits in the frame's opening, not on the brass; the
      plates, and anything else placed on the brass deliberately, are named
      as such in `QUESTIONS.md`
- [ ] `strip_track` spans the screen, and `total_line` and `hint_line` sit
      under it where nothing covers them
- [ ] `build_planner_geometry.py` reproduces the file and writes fresh proofs
      of the new layout, one with the results list open
- [ ] The line parts tile cleanly, or you have said they do not

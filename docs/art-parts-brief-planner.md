# GoblinPS planner window: brief for the image generator

The planner is the big window `/gps` opens. It is the one piece of GoblinPS
still wearing flat coloured rectangles while the dash unit wears your art, and
the difference is stark enough that they look like two different addons.

**You have already drawn almost all of this.** `planner-frame-wide.png`,
`planner-frame-tall.png`, the plates, the input box, the buttons, the twelve
icons and the route-strip pieces are all sitting in `images/parts/`. This brief
is not asking you to start over. It asks for **one new file** — a geometry
file — and for answers to a handful of places where the mockup and the working
window disagree.

## Answered, 2026-09-20 — see `images/parts/QUESTIONS.md`

Codex delivered `planner-geometry.json` (both layouts, 17 keys each), a
generator `build_planner_geometry.py` that reproduces it, and six proof
previews. Verified here, not taken on trust: the key sets match, every number
is in 0..1, the canvases match the frames, the generator reproduces the file
with an empty `git diff`, and **every content box sits at 0% opaque frame
pixels** — all of them inside the interior opening, none on the brass.

All four design questions answered, and `_planner-wide-geometry-assembled.png`
shows the nine homeless widgets with homes: the Tall toggle upper left, gear
and close upper right, From / Here / To / dropdown on one row, the strip in the
screen, a numbered scrolling step list beside it with detail lines, the total
and the amber hint in the footer, GO bottom right. He also agreed the window
should be `650x416` and `384x600`.

**Three things that will bite the implementer, recorded here so they do not:**

1. **`tools_button` is an alias of `close_button`, not a second control.** The
   rects are byte-identical in both layouts (checked). There is no wrench
   action — `close.png` *is* the crossed-wrench X. Building a widget per
   geometry key would put two buttons in one socket.
2. **`screen-backdrop` does not stack.** The dash trained us that layers share
   a canvas corner to corner; this one is an independent insert, scaled to
   cover `screen`, centre-cropped and clipped to that rectangle. Losing
   scenery at the sides is intended — it is wallpaper.
3. **`canvas` is in pixels.** It is the one exception to the 0..1 rule, and a
   validator that does not special-case it will reject a correct file.

Still ours: scrolling and selection sync between the strip and the step list,
settings behaviour, live text, texture sizing, and frame-size timing. No
in-game check has been done on any of it.

---

Read `docs/art-parts-brief-dash.md` first if you have not. Everything it says
about shared canvases, materials and light applies here unchanged. This brief
only covers what is different.

---

## The one thing I need most: `images/parts/planner-geometry.json`

The dash unit's second design worked on its first honest client run because of
`dash2-geometry.json`. Not because the art was better — because **not one
coordinate was typed by hand in the addon**. Every box, every centre, every
radius was read from your file, generated into the addon, and checked against
the actual pixels by a tool. When a number was wrong, the tool said so before
the game did.

Without that file, I go back to measuring your alpha channel with a script and
guessing. That is how the first dash design ended up with a compass hidden
behind the brass.

So: the same file, for this window. **Two canvases, because there are two
layouts**, and the boxes are in different places in each.

```json
{
  "_units": {
    "origin": "top-left",
    "x": "fraction of that layout's canvas width",
    "y": "fraction of that layout's canvas height",
    "r": "fraction of that layout's canvas WIDTH, always"
  },
  "wide": {
    "canvas": [1600, 1024],
    "title_plate":     { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
    "tagline_plate":   { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
    "close_button":    { "cx": 0.0, "cy": 0.0, "r": 0.0 },
    "gear_button":     { "cx": 0.0, "cy": 0.0, "r": 0.0 },
    "tools_button":    { "cx": 0.0, "cy": 0.0, "r": 0.0 },
    "from_box":        { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
    "to_box":          { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
    "here_button":     { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
    "dropdown_button": { "cx": 0.0, "cy": 0.0, "r": 0.0 },
    "results_list":    { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
    "screen":          { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
    "strip_track":     { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
    "side_panel":      { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
    "go_button":       { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
    "total_line":      { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
    "hint_line":       { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 }
  },
  "tall": {
    "canvas": [1024, 1600],
    "...": "the same keys, measured on the tall frame"
  },
  "strip": {
    "node_diameter": 0.0,
    "line_thickness": 0.0,
    "label_gap": 0.0
  }
}
```

Rules for the numbers, the same three that made the dash file work:

1. **Fractions, never pixels.** The window is drawn at whatever size the
   player's UI scale gives it; a pixel is meaningless by the time it gets
   there.
2. **Origin top-left**, y increasing downward, for every box in the file.
3. **Radii as a fraction of canvas WIDTH even on the tall layout.** A circle
   measured against two different axes stops being a circle. This is the rule
   that saved the dash's compass.

A `_line` suffix means **a line for text to sit on**, not a box to fit text
into — give it the vertical slot the lettering should centre on and I will
hang the font there at whatever height it needs. A `_box`, `_panel`, `_list`
or `screen` is a real area with room inside it. That distinction is not
cosmetic: I wrote the dash's placement code to treat the two differently, and
the naming is how it knows which is which.

---

## Where the mockup and the working window disagree

This is the part I actually need you to think about, and the reason this is a
conversation rather than a spec.

`_planner-wide-assembled.png` and `_planner-tall-assembled.png` are beautiful
and I want to ship them. But they show a **simpler window than the one that
exists**. The mockup has one search box, a screen, and one Start Route button.
The working planner has all of this:

| What it has | In the mockup? |
|---|---|
| Title and tagline | yes, lettering included |
| **A close button** | **no** — there is nowhere to click to shut the window |
| **A wide/tall layout toggle** | **no** — the player switches shapes with it |
| A destination search box | yes |
| **A second, "from" search box** | **no** — defaults to where you stand, but is settable |
| **A "Here" button** beside it | **no** |
| A dropdown arrow | yes |
| **A results list** that drops open under the search box | **no** — it covers the screen while open |
| The big lit screen | yes |
| The route strip inside it | yes |
| **A side panel listing every step** with times and detail lines | **no** |
| **A hint line** (amber warnings, e.g. a dangerous zone) | **no** |
| **A total line** ("about 12 min") | **no** |
| A GO / Start Route button | yes |

Nine rows with no home in the art. Some of those I can place in the dead space
your frames already have. Others need a decision, and it is a **design**
decision, not a drawing one, so I would rather have your view than guess:

1. **The step list.** The mockup replaces it with the route strip — three
   nodes on a track. That works for a three-stop route. A real route across a
   continent runs eight or ten steps, each with a detail line under it
   ("through the Sepulcher, south gate"). Does the strip scroll? Does the side
   panel come back for long routes? Or does the strip show the next three and
   the rest live in the tooltip?
2. **Close and the layout toggle.** The top-right has a gear and a wrench.
   Should one of those become the close button, and where does the toggle go?
   Or do they belong on the frame's top bar with the green lamps?
3. **The two search boxes.** One box is cleaner. Two is honest, because the
   route genuinely has a start and it is not always where you stand. If you
   would rather keep one, I need somewhere for "from" to appear when the
   player overrides it.
4. **The hint and total lines.** Both are short text and both matter — the
   hint is where the amber "this zone is above your level" warning lands.
   Somewhere near the GO button is natural.

If the answer to any of these is "draw another part", name it and I will
expect it. If it is "move it here", the geometry file is where you say so.

---

## A measurement problem that is mine, not yours

Your frames are `1600x1024` wide and `1024x1600` tall — clean 25:16 and 16:25.
My window is currently `660x400` and `390x600`, which are **1.65 and 0.65**.
Drawn as is, the wide frame would stretch by about 6% horizontally — which is
exactly the fault that made the first dash design render as an oval, and it
took a client run to spot.

I am fixing that on my side by moving the window to `650x416` and `384x600`,
which match your canvases exactly. **You do not need to redraw anything.** I
mention it only so you know the frames will be drawn at their true proportions
and you can trust what you see in the mockup.

---

## The parts, and what may still be missing

Already drawn and fine, as far as I can tell: `planner-frame-wide`,
`planner-frame-tall`, `planner-panel`, `screen-backdrop`, `title-plate`,
`tagline-plate`, `input-box`, `dropdown-button`, `button` with its hover,
pressed and disabled states, `close`, `close-hover`, `gear`, `gear-hover`, the
twelve icons (`icon-walk`, `ride`, `flight`, `boat`, `zeppelin`, `tram`,
`hearth`, `gate`, `warning`, `alliance`, `horde`, `neutral`) and the strip
pieces (`node-current`, `node-destination`, `node-ring`, `line-solid`,
`line-dashed`, `line-dot`).

Two notes on those:

- **`screen-backdrop` is 1600x640** while the frames are 1600x1024. That is
  fine if it is meant to be placed into the screen box rather than stacked
  corner to corner — but say which in the geometry file, because the dash's
  hardest bug was two layers that were meant to stack and were not the same
  size. If it stacks, it needs to be 1600x1024 with the art in the right place
  on it.
- **There is a `gear` but no `tools`/wrench part**, and the mockup clearly
  shows two buttons up there. If the wrench is a separate control, it needs
  its own part and its own hover.

---

## If something here is unclear or wrong

Write `images/parts/QUESTIONS.md` and put it there rather than guessing. A
wrong number in the geometry file is worse than a missing one: a missing box
makes the addon fall back to a flat colour and keep working, while a wrong box
puts text on the brass and nothing notices until someone is standing in the
game looking at it.

That is not hypothetical. Today the dash unit shipped with every coordinate
correct and still drew wrong, because the addon read a frame's size at a moment
the game had not worked it out yet. Two hundred and fifty-seven tests passed
over it. The only thing that caught it was a screenshot.

## Check before you finish

- [ ] `planner-geometry.json` exists, parses as JSON, and has both `wide` and
      `tall` with the same key set
- [ ] Every number is between 0 and 1
- [ ] Every `r` is a fraction of canvas **width**, on both layouts
- [ ] Every box you gave a `_line` name is a slot for text to sit on, and every
      box you gave an area name has room inside it
- [ ] Lay `screen-backdrop` over `planner-frame-wide` the way the geometry says
      and confirm it lands inside the screen opening with nothing clipped
- [ ] The four disagreements above are answered, here or in `QUESTIONS.md`
- [ ] Nothing was redrawn that did not need redrawing

# GoblinPS dash unit, second design: brief for the image generator

Paste everything below the line to ChatGPT / Codex, with the new dash mockup
attached. It supersedes the dash rows in `docs/art-parts-brief.md`; the planner
and route-strip rows there still stand.

This brief is shorter than the first one because the first set has since been
wired into the addon and shipped to the client, and two things went wrong. Both
are now rules.

---

You made the attached dash unit for GoblinPS, a World of Warcraft addon. I need
it **rebuilt as separate layers a programmer can stack**, so the game can draw
the text, turn the arrow and light the button itself.

## The one rule that matters most

**Every part that stacks must be drawn on the same canvas, at the same size,
with the artwork in the same place on it.**

Not "the same proportions". The same canvas. If the housing is 1024x1280, then
the glass is also 1024x1280 with the glass disc sitting exactly where the
housing's round hole is, and the compass is also 1024x1280 with its ring
centred on that same disc. Lay any two of them on top of each other, corner to
corner, and everything must line up with no scaling, no offset and no guessing.

This is not a style preference. The first set was drawn as three separate
concentric images and the programmer had to measure the alpha channel to work
out that the glass was 61% of its canvas, the compass 55% and the body's hole
58%. Drawing them at different sizes in the game made the compass vanish behind
the brass. Shared canvases make that impossible.

## Rules for every part

1. **Transparent background.** PNG, RGBA, real alpha. No checkerboard, no
   scene, no drop shadow on a backdrop.
2. **Same canvas for the stacked parts: 1024 wide by 1280 tall.** The three
   button states are the exception and are described below.
3. **Straight-on view.** Flat, front-facing, no tilt, no perspective.
4. **No text**, except the two parts marked "lettering included". The game
   draws the destination, the distance, the step lines and the ETA. Leave those
   areas clean and evenly dark so text stays readable on top.
5. **Same materials and light as the mockup:** dented scratched brass, dark
   riveted iron, green glowing glass, light from the upper left. Brass #B8873B,
   dark body #3B2E1C, iron #1C1A14, screen green #081F0F, glow green #70E08A to
   #A6FF3C, amber #F0B54A, hazard orange #E0701C, button red #C0392B.
6. **Glow stays inside the canvas**, fading to nothing before the edge.
7. **Exact file names**, saved under `images/parts/`.

## The parts

| File | What it is |
|---|---|
| `dash2-housing.png` | The whole brass and iron chassis as one piece: the round bezel, the side pipes and tubes, the goblin-face plate, the lower panel frame and the ETA plate frame. **Three fully transparent holes**: the round glass area, the "next steps" screen area, and the ETA inset. Also a transparent hole where the red button sits, since that is supplied separately. Lettering included, for the words "NEXT STEPS" stamped on the brass strip only — that label never changes, so bake it in. |
| `dash2-glass.png` | Only the round dark-green glass disc that fills the bezel's hole: faint skyline silhouette, light scratches, a soft glare at upper left. No arrow, no compass letters, no text. Slightly larger than the hole so no gap shows. |
| `dash2-compass.png` | Only the four letters N, E, S, W and the thin tick ring, in dim green, on transparent. Lettering included. **It will be rotated by the game about the centre of the glass disc**, so the ring must be exactly concentric with that disc. |
| `dash2-steps-screen.png` | Only the green lit screen that fills the "next steps" hole: a slight inner glow and a soft glare, no lines of text. |
| `dash2-eta-screen.png` | Only the small green inset that fills the ETA hole. Empty. |
| `dash2-stop.png` | The red emergency button alone, on its own **256x256** canvas, centred, unpressed. No housing, no socket — the socket belongs to the housing. |
| `dash2-stop-hover.png` | The same button, brighter, as if lit. Same canvas, same position. |
| `dash2-stop-pressed.png` | The same button pushed in and darker. Same canvas, same position. |

Keep the existing `arrow.png` exactly as it is. It is already in the game and
working; do not redraw it.

## The file I need most

Write `images/parts/dash2-geometry.json` giving, as **fractions of the canvas**
(0 to 1, with 0,0 at the top left), where each region sits:

```json
{
  "canvas": [1024, 1280],
  "glass":       { "cx": 0.50, "cy": 0.00, "r": 0.00 },
  "compass_ring":{ "cx": 0.50, "cy": 0.00, "r": 0.00 },
  "steps_screen":{ "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
  "eta_screen":  { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
  "stop_button": { "cx": 0.00, "cy": 0.00, "r": 0.00 },
  "destination_line": { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 },
  "distance_line":    { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 }
}
```

Fill in the real numbers. The last two are where the mockup puts "The
Crossroads" and "420 yd" on the glass — the game draws those words, but it
needs to know the box they belong in.

Without this file the programmer has to measure the alpha channel of every
image to rediscover the geometry, which is how the first set went wrong. With
it, the wiring is exact.

## If something here is unclear or wrong

You cannot ask me a question while you work, and I cannot ask you one. So if
anything in this brief is ambiguous, contradicts the mockup, or turns out to be
impossible, **do not guess silently**. Write it down in
`images/parts/QUESTIONS.md` — what you were asked, what was unclear, what you
did instead and why — and carry on with your best judgement. I read that file
before I wire anything up, and I answer in the same file under the question.

Your last handoff note did exactly this in spirit: it told me the generator
would not honour exact canvas sizes, that it had painted checkerboards, and
that the authoring TGAs were not what should ship. All three were things I
would otherwise have discovered the hard way. That is the most useful thing
you can send me, so keep doing it.

## Check before you finish

- Open every part over bright magenta and over white. Any brown or grey haze
  around the edges means the alpha is wrong: redo it.
- Stack `dash2-glass`, then `dash2-compass`, then `arrow` scaled to about 45%
  and centred on the glass, then `dash2-steps-screen`, then `dash2-eta-screen`,
  then `dash2-housing` on top, all corner to corner with no scaling. It must
  reproduce the mockup minus the words the game draws. Save that as
  `images/parts/_dash2-assembled.png`.
- Confirm every number in `dash2-geometry.json` against that stack.

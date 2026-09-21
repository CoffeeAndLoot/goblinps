# Fix wave report — plan 6, the planner window's art

Branch `planner-art`, base `dde84b4`. One wave, everything landed.

**Status: complete. All eight findings fixed, all gates green, three commits,
nothing pushed.**

## Gates

| Gate | Baseline | Now |
|---|---|---|
| `test/run.lua` via lupa | 278 passed, 0 failed | **282 passed, 0 failed** |
| `python -m unittest discover -s test/tools` | 42 | **48** |
| `python tools/check_art.py` | 47 / 0 / 0 | **47 / 0 / 0** |
| `python tools/make_art.py` | regenerates, clean tree | **regenerates, clean tree** |
| luacheck (PowerShell) | 0 warnings, 38 files | **0 warnings / 0 errors in 38 files** |
| lua-language-server `--check` (PowerShell) | clean | **"Diagnosis completed, no problems found", `[]`** |

No lint suppression anywhere. luacheck and the language server were both run
from PowerShell, never Git Bash. The IDE's own diagnostics were not consulted;
the CLI results above are the record.

## The two tests watched failing first

Both were written and run against the unfixed code before a line of the fix
was written. One run, all three new assertions failing for exactly the stated
reasons:

```
278 passed, 3 failed
FAIL: the planner window :: draws the screen's scenery where nothing opaque can cover it
    test/test_ui.lua:436: the scenery belongs to the screen it fills, not to a frame behind it, got "false"
FAIL: the planner window :: re-measures a three-slice's end caps when the control is resized
    test/test_ui.lua:549: attempt to call field 'Restretch3' (a nil value)
FAIL: the planner window :: re-applies a three-sliced control's caps on every layout
    test/test_ui.lua:570: ApplyLayout must re-measure the caps of the control it just resized:
                          cap is 24, control height is 33.75, got "false"
```

The third is the finding's own number back out of the harness: GO's cap drew
24 px where the geometry implies 33.7 — the −29% the brief measured.

Before writing the Critical's test I extended `test/fake_frames.lua` to record
three things it had been swallowing: colour-texture alpha, frame strata and
`IsEnabled`. That is a prerequisite, not the fix — "is this fill opaque" is
the question the Critical turns on, and a test cannot ask something the fake
throws away. All three are verified present on build 1.60.1.69913 in the
`forever` branch source at `D:\wow-api\1.60.1.69913`, as are `OnEnter`,
`OnLeave`, `OnMouseDown` and `OnMouseUp` on a plain Button.

## Finding by finding

### CRITICAL — the scenery was drawn, cropped correctly, and invisible

`GoblinPS/Planner.lua`. `backdrop` is now created on the `screen` frame at
`"ARTWORK"`, after `screen` exists, and `SetAllPoints(screen)` — above the
panel's two opaque `BACKGROUND`/`BORDER` fills and below the `OVERLAY`
FontStrings drawn on it. The `W.PlaceRect(ui.backdrop, f, g.screen)` call is
gone; the `coverCrop` call stays, still computing the screen box's pixel size
from `g.screen` and the frame. The colour fills are untouched and remain the
fallback.

Covered by `test/test_ui.lua` :: *"draws the screen's scenery where nothing
opaque can cover it"* — asserts the mechanism, not the coordinates: the
backdrop's parent is the `screen` frame, its draw layer is `"ARTWORK"`, and no
other region on that frame carries a fully opaque colour texture at an
equal-or-higher layer. The three older backdrop tests (both crop tests and the
missing-texture test) still pass unchanged.

### IMPORTANT 1 — end caps sized once, at build time

`GoblinPS/Widgets.lua`. The slice table now carries `capAspect` alongside
`capFraction`, and a new `Widgets.Restretch3(frame)` re-measures the caps
against the control's current height. `Stretch3` goes through it rather than
keeping a second copy of the maths, so there is one mechanism, extending
`parent.slice` as the brief required. `Planner.ApplyLayout` calls it for
`layoutButton`, `here`, `go`, `fromBox` and `toBox` after placing them, inside
the same `if g then` block. It answers `false` for a control with no slice, so
the call site needs no guard.

Covered by two tests: *"re-measures a three-slice's end caps when the control
is resized"* (the unit, as the brief worded it) and *"re-applies a
three-sliced control's caps on every layout"* (the integration, which is where
the bug actually lived — it proves `ApplyLayout` calls it). The second stands
in for the client's layout pass by setting the height the tall geometry
implies, because the fake resolves no size from two opposing anchors; the test
says so in a comment.

### IMPORTANT 2 — check_art's allow-list was silent on a new key

`tools/check_art.py`. Two lists now, both enforced:

- `PLANNER_INTERIOR_KEYS` gained the four control boxes (`from_box`, `to_box`,
  `here_button`, `go_button`) and `layout_button`. Measured: all of them 0.0%
  opaque in both layouts, except `layout_button`, which is 0.0% in tall only.
- `PLANNER_BRASS_KEYS` is new and **per layout**, exactly as the brief ruled:
  `{title_plate, tagline_plate, layout_button}` in wide,
  `{title_plate, tagline_plate}` in tall. Measured and documented in the
  comment: `title_plate` 100.0% in both, `tagline_plate` 99.2% wide / 95.0%
  tall, `layout_button` 85.4% wide / 0.0% tall.

Because the brass list is per layout, tall's `layout_button` falls to the
interior list and **is** really checked — a strictly stronger arrangement than
exempting the key outright.

A rectangular key in neither list is now a failure, and a key either list
names that the geometry does not carry is also a failure. The classification
is a pure function, `planner_keys_classified(g)`, which
`planner_geometry_holds()` calls first.

Covered by the new `test/tools/test_check_art.py`: the shipped geometry is
fully classified; an unknown rectangular key fails; a vanished listed key
fails; a rename fails on both halves at once; a circle key is not dragged into
it; and the per-layout `layout_button` split is pinned so a later tidy-up
cannot quietly collapse the two lists.

### MINOR 1 — stale plan number

`docs/manual-test-checklist.md:147`: "plan 6 (the route strip)" → "plan 7".
One word. Build-log hits left alone as historical.

### MINOR 2 — two shipped textures nothing drew

Wired, not unshipped. `Widgets.WireButtonArt(button)` sets `OnEnter`/`OnLeave`
(swap to `button-hover` / back to `button`) and `OnMouseDown`/`OnMouseUp`
(`button-pressed` / back to `button-hover`, since the cursor is still on it).
A local `buttonState` helper does the guard: no slice or not enabled, nothing
happens — so a disabled GO answers neither, and `reslice`'s existing behaviour
leaves the current art in place when a state's part is missing or will not
load. Applied to the three three-sliced buttons (`layoutButton`, `here`, `go`)
and not to the edit boxes, which have no such parts.

**Eleven lines of code**, inside the brief's budget of about fifteen. No new
mechanism: it is `reslice`, which `SetButtonEnabled` already used.

Covered by *"lights a three-sliced button on hover and presses it while
held"*, which walks enter → down → up → leave and then re-checks with the
button disabled.

### MINOR 3 — the results overlay's layering test proved the wrong thing

The assertion in *"stacks the art under the content"* now reads
`ui.results:GetFrameStrata() == "DIALOG"`, plus a second assertion that the
frame **level** does not exceed `screen`'s — which documents the tie rather
than hiding it — and a comment saying plainly that the level is not what
carries the overlay.

### MINOR 4 — a client-only question, onto the checklist

Added under the plan 6 art section: a line asking the tester to confirm the
typed text and the grey placeholder are both readable against the `input-box`
art, naming which one washes out and where. A second line was added for the
hover and pressed states this wave wired up, since they are new art that only
the client can judge.

## Judgment calls I made, and why

**Commit grouping: three commits, not four.** The Critical, Important 1,
Minor 2 and Minor 3 all touch the same four files (`Planner.lua`,
`Widgets.lua`, `fake_frames.lua`, `test_ui.lua`). Splitting them further would
need interactive partial staging, which is not available here, so I grouped by
file set rather than shipping a commit whose stated subject does not match its
diff. The commit message names each finding it carries.

1. `f1239de` — Put the screen's scenery where it can be seen, and re-measure
   end caps (Critical, Important 1, Minor 2, Minor 3)
2. `6e161b6` — Make check_art's planner allow-list loud in both directions
   (Important 2)
3. `1eb70bb` — Checklist: the strip is plan 7, and two questions only the
   client answers (Minors 1 and 4)

Every commit staged explicit paths. `AGENTS.md` is still untracked and was
never staged. Nothing pushed.

**How far to take the hover/pressed wiring: all four scripts, buttons only.**
The brief allowed stopping short. Four scripts through the existing `reslice`
came to eleven lines, so there was no reason to ship half of it. I did not
wire the edit boxes — `input-box-hover` and `input-box-pressed` do not exist,
so it would have been four no-op scripts.

**The Important 1 test: two tests, not one.** The brief asked for the unit
test. I added the `ApplyLayout` one as well, because the unit test alone would
have passed against a `Restretch3` that nothing ever called — which is the
same shape of mistake as the finding itself.

## Concerns this wave did not address

1. **The tiled panel backing may be almost entirely hidden, for the same
   reason the backdrop was.** `panelArt` lives on `artLayer` (frame level
   base+1) at the union of every placed rect. Both `screen` and `side` are
   `W.Panel` frames at base+3 with fully opaque colour fills, so the tile can
   only show in the gaps *between* and *around* those two panels, never
   behind either of them. That is the Critical's fault one more time, in a
   milder form: the art is drawn, and most of it cannot be seen. I did not
   touch it — the brief's ruling was specific to the backdrop, and unlike the
   backdrop this one is not simply invisible, so the right fix is a judgment
   call about what the interior is supposed to look like. It is the first
   thing the client run should be asked about: if the interior reads as flat
   dark panels with a band of texture around them, this is why.

2. **`W.Button`'s white HIGHLIGHT wash now stacks on the hover art.** Every
   `W.Button` carries a `HIGHLIGHT` texture at `SetColorTexture(1,1,1,0.18)`,
   which draws above `ARTWORK`. With `button-hover` now swapping in
   underneath, a hovered button gets both cues at once. It is the correct
   fallback when no art loads, so removing it unconditionally would be wrong,
   and it may well look fine. The checklist line I added will catch it if it
   does not.

3. **The fake still resolves no size from two opposing anchors.** This is the
   exact gap that hid Important 1 — the same class as the `SetAllPoints` fault
   that shipped in plan 5. Both of Important 1's tests work around it by
   setting the size the geometry implies and saying so in a comment. Teaching
   `Region:GetHeight()` to resolve a height from a `TOPLEFT`/`BOTTOMRIGHT`
   pair against a sized parent would close it properly and would let the
   `ApplyLayout` test assert the real thing rather than a stand-in. That is a
   change to the harness's core measurement rule, with reach across all 282
   tests, so it does not belong in a fix wave.

4. **Nothing here has run in the client.** Plan 6 has still never been on
   screen. The Critical, Important 1 and Minor 2 all change what is drawn, so
   the checklist's plan 6 section is now the gate that matters, not the suite.

---

# Addendum — re-review residuals

Authorised follow-up pass, scoped to the three items the scoped re-review
raised. Nothing else touched. One commit: `2c05933` — *Hand Restretch3 its
height, and keep the tile off the chassis* (`GoblinPS/Planner.lua`,
`GoblinPS/Widgets.lua`, `test/test_ui.lua`, `docs/manual-test-checklist.md`).
Explicit paths, `AGENTS.md` untouched, not pushed.

## Gates, re-run

| Gate | Before this pass | Now |
|---|---|---|
| `test/run.lua` via lupa | 282 passed, 0 failed | **283 passed, 0 failed** |
| `python -m unittest discover -s test/tools` | 48 | **48** |
| `python tools/check_art.py` | 47 / 0 / 0 | **47 / 0 / 0** |
| `python tools/make_art.py` | regenerates, clean tree | **regenerates, clean tree** |
| luacheck (PowerShell) | 0 / 0 in 38 files | **0 warnings / 0 errors in 38 files** |
| lua-language-server (PowerShell) | clean | **"Diagnosis completed, no problems found", `[]`** |

Test count went 282 → 283: two tests were rewritten rather than added (they
replaced the pair that proved the wrong thing), and one is new.

## Both new tests, failing first

Written and run against the tree as it stood after the first wave, before any
of this pass's production code changed. One run, all three assertions failing
with the reviewer's own numbers:

```
280 passed, 3 failed
FAIL: the planner window :: keeps the tiled backing off the chassis's own ornament
    test/test_ui.lua:549: wide: the tile climbed onto the brass crest, top is 0.0976562, got "false"
FAIL: the planner window :: sizes a three-slice's end caps from the height it is handed, never the frame's
    test/test_ui.lua:595: the left cap takes the height it was handed
    expected: "33.75"
    actual:   "40"
FAIL: the planner window :: sizes every three-sliced control's caps from its own rect, in both layouts
    test/test_ui.lua:627: wide: layoutButton's left cap is 18, the geometry implies 22.343776, got "false"
```

`18` against `22.343776` is the re-review's table coming back out of the
harness unprompted, and `0.0976562` is exactly `titlePlate.top` in wide — the
union had been pulled up onto the crest.

## 1 — Restretch3 measured the one thing the project forbids measuring

The finding is correct and I had it backwards in my own comment. `PlaceRect`
does `ClearAllPoints()` then `TOPLEFT`/`BOTTOMRIGHT`, so from that instant the
control **only inherits** its size; `GetHeight()` answers the stale explicit
size the widget was built with. The helper was wired in correctly at the right
moment and changed no number. My call-site comment said "its height has
changed" about a value that had not — three lines after the rule that says so
is quoted in the same file.

- `Widgets.Restretch3(frame, height)` now takes the height. It still returns
  `false` for a sliceless control, so the call site needs no guard.
- `Stretch3` passes `parent:GetHeight()`, with a comment saying why that one
  site is legal: every caller builds its control with an explicit `SetSize`
  (`W.Button`, `W.EditBox`) and slices it before any layout has run.
- `ApplyLayout` derives the height the same way `PlaceRect` derives its
  offsets — `(rect.bottom - rect.top) * f:GetHeight()`, from the control's own
  rect and the frame that really was given a size at the top of the function.
- The loop iterates explicit `{control, rect}` pairs. That removes the
  `ipairs`-over-controls truncation hazard as a side effect of needing the
  rects anyway, which is the cheapest possible way to be rid of it.

The test now places everything through `ApplyLayout` in **both** layouts and
asserts each cap equals `rect height x capAspect` within 0.01, for all five
controls and both caps — twenty assertions, nothing set by hand. The unit test
was rewritten to pin the contract rather than the plumbing: it hands
`Restretch3` a height that differs from the frame's own and asserts the cap
follows the argument, so a future edit that quietly goes back to measuring the
frame fails immediately rather than in the client.

## 2 — boundingBox put the tile over the chassis

Also correct. `titlePlate` and `taglinePlate` are the only two keys that live
*on* the chassis rather than in its opening, and unioning them stretched a
fully opaque tile — drawn on `artLayer` at `"BACKGROUND"` *after* `frameArt`
on that same frame and layer, so over it — across the inner brass border, both
corner lamps and the bottom rail.

A named, commented `ON_THE_CHASSIS` table excludes exactly those two. I
measured the effect independently against each frame PNG's alpha, same method
as `check_art`:

| layout | with plates | without |
|---|---|---|
| wide | 30.2% | **8.6%** |
| tall | 16.2% | **0.0%** |

Within crop-rounding of the reviewer's 29.7 / 8.4 / 16.0 / 0.0; the comment
says "about 30%" and "about 8.6%" rather than pretending to more precision
than the `int()` crop supports. The wide residue is the crest plate overhanging
the tile's top edge, which is inherent to a bounding box and is why I did not
invent an `interior` rect — that belongs in a geometry delivery, as ruled.

The new test asserts the behaviour, not a mirror of the implementation: the
tile's top stays below the title plate's top, its bottom stays above the
tagline plate's bottom, and it still fully covers `screen` and `sidePanel` in
both layouts — so a later over-shrink is caught as loudly as this over-reach
was not. The stale `boundingBox` comment, which still explained itself in
terms of a backdrop that stopped living on `artLayer` in commit `f1239de`, is
corrected in the same edit.

## 3 — the checklist line

Added under the plan 6 art section, right after the existing end-cap line: the
tester toggles Wide/Tall and looks at the caps **again**, because a cap sized
for one layout and left there only shows on the switch. The line names what a
failure means — the height `ApplyLayout` hands `Restretch3` is wrong for that
layout — so the report comes back actionable.

## Scope

The fake's inability to resolve a size from two opposing anchors was left
alone, as instructed. It is real, it is what hid this, and both of concern 3's
consequences are now visible in one place: the new `ApplyLayout` test can
assert the cap width because the cap is set from the geometry rather than
read back off the frame, so it happens not to need the fake to resolve
anything. That is luck of the fix's shape, not a reason to think the gap
closed. It stays on the list for its own plan.

Concerns 1, 2 and 4 from the first report stand unchanged, except that
concern 1 (the tile hidden behind the opaque `screen` and `side` panels) is
now the *only* remaining question about `panelArt` — its other half, the tile
covering the chassis, was this pass's residual 2 and is fixed. The tile is
still invisible everywhere those two opaque panels sit; only the client can
say whether what is left reads as intended.

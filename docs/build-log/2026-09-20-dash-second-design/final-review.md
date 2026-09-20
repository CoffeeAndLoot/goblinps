# Final whole-branch review — `dash-second-design`

Range reviewed: `9f80ca7..0db3921`, 9 commits. Reviewed against
`docs/superpowers/plans/2026-09-20-goblinps-dash-second-design.md`,
`docs/superpowers/specs/2026-09-19-goblinps-design.md` decisions 3, 5 and 7,
`CLAUDE.md`, `images/parts/dash2-notes.md` and `images/parts/dash2-geometry.json`.

**Verdict: ready with fixes.** 0 Critical, 3 Important, 8 Minor.

The engineering here is good and the hard part — the compass crop — is right
end to end; I measured it rather than trusting the ledger. What this branch
has not done is check that the artist's layout survives the size the device
actually ships at. Two of the three Important findings are that, and one is a
test-harness defect that quietly defeats the regression test added to close
this branch's most serious finding.

I cannot run the WoW client and claim nothing about appearance. Every finding
below is arithmetic, measured pixels, or driven code with its output recorded.

---

## 1. Gates — all green, real output

```
python -c "... test/run.lua ..."        251 passed, 0 failed
python -m unittest discover -s test/tools   Ran 36 tests ... OK
python tools/check_art.py               47 pass, 0 with problems, 0 not drawn yet
python tools/make_art.py                13 textures, 3.13 MB total
git diff (after make_art.py)            empty — the generated file reproduces byte for byte
luacheck GoblinPS test tools            Total: 0 warnings / 0 errors in 39 files
lua-language-server --check             Diagnosis completed, no problems found   (output file: [])
git status --short                      ?? AGENTS.md   (untouched, belongs to another agent)
```

No lint suppression anywhere in the branch. `grep` over `GoblinPS test tools`
for `luacheck:`, `---@diagnostic`, `# noqa`, `# type: ignore`, `pylint:` finds
only a pre-existing `# noqa: E402` in `test/tools/test_build_graph.py`, which
this branch does not touch.

`GoblinPS/Dash.lua` calls no Blizzard game API: the only globals it touches are
`CreateFrame`, `UIParent` and `UISpecialFrames`, the same UI globals
`Planner.lua` uses. No libraries, no frame templates, no secure code.
Generated files were not hand-edited — `make_art.py` reproduces `Art.lua` and
all thirteen TGAs with an empty diff.

---

## 2. What I verified as correct

### The compass crop — correct, end to end

Every link in the chain measured independently:

| Link | Measured | Expected |
|---|---|---|
| Crop box, `tools/make_art.py:89-104` | `(236, 189, 796, 749)` | centred on the dial |
| Crop centre | `(516, 469)` | glass centre `(0.50390625×1024, 0.36640625×1280)` = `(516, 469)` ✓ |
| Crop half-size vs ring radius | 280 vs 262 | 18 px of margin, stays inside the canvas ✓ |
| `compassCrop.share` in `Data/Art.lua:33` | `0.546875` | 560/1024 ✓ |
| **Shipped `GoblinPS/Media/dash2-compass.tga`** | 256×256, alpha bbox `(6,6,250,250)`, centre **(127.5, 127.5)** | canvas centre (127.5, 127.5) — exact ✓ |
| Size `Dash.lua` draws it at (driven live) | **126.88 × 126.88** | 232 × 0.546875 = 126.88 ✓ |
| Source-to-device scale | 232/1024 = 290/1280 = **0.2265625**, identical on both axes | a 560 px source square → 126.88 px ✓ |

So `SetRotation` turns the compass about the dial, and the shipped texture's
own middle *is* the dial. The arrow agrees too: `arrow.share` 0.450195 →
104.45 px drawn, and 461 source px × 0.2265625 = 104.45.

Nothing else depends on the compass being on the shared canvas.
`tools/check_art.py:81,222-240` measures the **source PNG** (still 1024×1280)
against the geometry; `Dash.lua:157-166` bypasses the `art()` helper for the
compass and never calls `SetAllPoints`. The crop exists only inside
`make_art.py`.

### Every drawn position comes from the geometry

Driven live (a scratch script that loads `test/fake_frames.lua` and the modules
the way `test/test_ui.lua` does, then builds the device):

```
frame          232.00 x 290.00  level=1
artLayer       232.00 x 290.00  level=2
housingFrame   232.00 x 290.00  level=3
content        232.00 x 290.00  level=4
stop            22.20 x  22.20  level=5   CENTER->TOPLEFT(194.16,-49.39)
glass/stepsScreen/etaScreen/housing  232.00 x 290.00 each
compass        126.88 x 126.88
arrow          104.45 x 104.45
destination  TOPLEFT->TOPLEFT(81.56,-134.58)  BOTTOMRIGHT->TOPLEFT(152.25,-141.38)
distance     TOPLEFT->TOPLEFT(90.62,-142.28)  BOTTOMRIGHT->TOPLEFT(143.19,-148.17)
steps[1..3]  x 64.80..169.70, y -208.89 / -220.97 / -233.06 / -245.14
eta          TOPLEFT->TOPLEFT(96.06,-259.41)  BOTTOMRIGHT->TOPLEFT(138.88,-269.16)
```

Each value reproduces its geometry entry exactly. The stop button lands at
(194.16, 49.39) — the top-right socket, as the Task 2 reviewer warned it must.
Frame levels stack the way the comments claim: art < housing < content < button.

I hunted for hand-typed coordinates. The only literals left in the layout are
the four geometry-absent fallbacks, each carrying a comment saying so
(`Dash.lua:146-148, 164-166, 176-178, 200-203, 225-226, 240-241, 258-259`), plus
`Dash.SIZE` (see Important 2) and the dead `pad` branch (Minor 2).

### The trip loop really is untouched

`git diff 9f80ca7..0db3921 -- GoblinPS/Trip.lua` is **empty**. `Dash.Tick`,
`Dash.Start`, `Dash.Stop`, `finish()`, `aimArrow()` and `yards()` have no diff
lines. Only `Dash.Refresh` changed, and only in where it writes the banner.

I drove the banner rather than reading it:

```
tick 1                    index=1 banner=nil    steps1="Ride to the North Gate" dist="200 yd" eta="~7 min"
strayed -> recalculate    index=1 banner=Recalculating...  steps = "Recalculating..." / "" / ""
next tick                 index=1 banner=nil    steps = "Ride to West Dock" / "Zeppelin to East Dock" / "Ride to Delta"
```

The precise arrangement holds: held in `state.banner`, read instead of the
normal text in `Dash.Refresh` (`Dash.lua:69-77`), cleared at the top of the next
tick (`Dash.lua:396-403`). Full journey, arrival, pause (no position), taxi
(`stay`) and stop-button click all behave as documented.

### The fallback path is safe when geometry is present, and readable when it is not

Built with `ns.Data.Art` and `ns.Data.ArtGeometry` both nil:

```
frame 232.00 x 290.00 shown=true
flat 232.00 x 290.00 shown=true   glass/stepsScreen/etaScreen/housing nil
compass 127.60 shown=false        arrow 104.40 shown=true (WHITE8X8, green)
stop 20.00 x 20.00  TOPRIGHT(-8,-8)
destination/distance/eta/steps[1..3]  2 anchors each, text present
clicking stop with no art: shown=false   (the trip ends)
```

All six FontStrings get two anchors, the button still works, nothing errors.
The `if g then ... else ... end` branches cannot misbehave with geometry present
— every one is a plain either/or with no shared mutable state, and the live
build above proves the `g` side is what runs.

### Documentation honesty — no third false claim

I re-verified both cited commits against `git log`. `5858643` reads "First
in-game run. The device rendered as an oval and the step name was cut in half by
the Stop button." `2d58322` reads "The compass vanished and a dark square framed
the device." `CLAUDE.md` and the spec now draw the first-design / second-design
distinction correctly and state plainly that plan 5 has **not** run in the
client at all. That is accurate.

---

## Important findings

### I1. The device's own brass rectangle is never hidden, and ~40% of the device is transparent art

`GoblinPS/Dash.lua:102`

```lua
local f = W.Panel(UIParent, "body", "brass", 3)
```

`Widgets.Panel` (`GoblinPS/Widgets.lua:36-44`) creates **two opaque colour
textures**: a `brass` BACKGROUND filling the frame, and a `body` BORDER inset
3 px. They sit at `f`'s own frame level, under `artLayer` (base+1). Nothing
hides them — `W.Panel` does not return them, and no code re-reads them.

Contrast the line directly below, `Dash.lua:134-140`:

```lua
-- The flat colour is the fallback for art that will not load. It is a
-- rectangle, so it goes the moment the glass arrives, or it boxes in a
-- round device.
local flat = W.Fill(artLayer, "BACKGROUND", "screen")
local glass = art(artLayer, "dash2-glass", "BORDER")
if glass then flat:Hide() end
```

The branch identifies the rule and applies it to one rectangle while leaving a
second, larger, equally opaque rectangle behind it.

Measured (Pillow, over the shipped PNGs):

- `dash2-housing.png` alpha is **0 at every corner and every edge midpoint**;
  its alpha bbox is `(88, 9, 926, 1246)`, so it does not reach the canvas edge.
- Compositing **all five** shared layers (glass, compass, steps, eta, housing)
  leaves **39.65 %** of the 1024×1280 canvas at alpha 0, bbox unchanged.
- At the 0.2265625 device scale that is a fully opaque margin of **≈19.9 px on
  the left, ≈22.2 px on the right, ≈2.0 px top, ≈7.7 px bottom** of a 232×290
  device, plus everything transparent inside the bbox.

This is the same class as the in-game fault fixed in `2d58322` ("a dark square
framed the device"), and it is the one defect on this branch that only a
screenshot can confirm. In the first design the `W.Panel` rectangle *was* the
chassis — the round art lived on a 200×200 child frame and the panel carried the
text band beneath it. In the second design the whole device is art, and the
panel is no longer chrome.

Fix: either hide the panel's fills once `housing` loads (same idiom as `flat`),
or build `f` as a bare `CreateFrame` and let `flat` be the only fallback
rectangle. No test covers it because no test inspects `f`'s own textures.

### I2. The artist's text boxes are smaller than the client's fixed fonts at the shipped device size

`Dash.SIZE = { 232, 290 }` (`GoblinPS/Dash.lua:15`) is the **one layout number
not derived from the geometry**. The test at `test/test_ui.lua:562-576` pins its
*ratio* to `ArtGeometry.canvas` exactly, which is good — but nothing checks the
*scale*, and the artist's text-safe boxes were drawn on a 1024×1280 canvas.

Box sizes at 232×290, against the font heights in the `forever` client source
(`Interface/AddOns/Blizzard_Fonts_Shared/Shared/Fonts.xml:39-41` and `:597-599`,
via `FontStyles.xml:56` and `:172`):

| Line | Box (device px) | Font object | Height | Fits? |
|---|---|---|---|---|
| destination | 70.69 × **6.80** | `GameFontNormalSmall` | 10 px | **no** |
| distance | 52.56 × **5.89** | `GameFontNormalLarge` | **16 px** | **no** |
| etaText | 42.82 × **9.74** | `GameFontNormalSmall` | 10 px | **no** (0.26 px short) |
| steps line (each third) | 104.90 × 12.08 | `GameFontNormalSmall` | 10 px | yes |

The distance line is the worst: a 16 px font in a 5.89 px box, 0.9 device px
below the destination line's box. A non-wrapping FontString does not shrink to
its region — it lays out at the font's height and justifies inside, so these
lines cannot stay inside the openings the chassis art cuts for them.
`docs/manual-test-checklist.md:392-393` asks the tester to confirm exactly that
("Every line sits inside its own opening in the chassis"), so the branch has
identified the risk without measuring it.

The width side has a directly relevant in-game precedent. Commit `5858643`
records, from a real run: *"'Walk to Undercity Zeppelin Tower' did not fit at
200 wide"*, and the first design's response was to make that line wrap with an
explicit 28 px height. The second design gives the same class of string
**104.90 px** and `SetWordWrap(false)` — half the width that already failed,
with truncation instead of wrapping. `test/test_ui.lua:604-626` documents the
reversal as intentional ("the panel gives it a short line of its own... so every
line truncates instead"), but a decision that reverses an in-game observation
deserves to be stated as a risk in the checklist, not only in a test comment.

This is not a code defect — it is a sizing decision that was never checked
against the fonts. Worth resolving before the client run, because the remedies
differ (grow `Dash.SIZE`, or drop the fonts to a smaller object, or set explicit
font heights) and each is cheap now and a fix round later.

### I3. `test/fake_frames.lua` mis-parses the three-argument `SetPoint`, defeating the fallback test

`test/fake_frames.lua:98-99`:

```lua
elseif n == 3 then
    point, x, y = ...
```

The real client disambiguates the 3-argument form by type:
`SetPoint(point, x, y)` **and** `SetPoint(point, relativeTo, relativePoint)` are
both valid. The fake assumes the first unconditionally.

This branch is the first code in the repo to use the second form — six times, in
the geometry-absent fallback (`Dash.lua:204-207`, `227-232`, `242-243`). Probed
directly, with `Data.Art` and `ArtGeometry` nil:

```
destination point 1: point=TOPLEFT relativeTo=nil relativePoint=TOPLEFT x=table: 0000...  y=TOPLEFT
distance    point 1: point=TOPLEFT relativeTo=nil relativePoint=TOPLEFT x=table: 0000...  y=BOTTOMLEFT
eta         point 2: point=TOPRIGHT relativeTo=nil relativePoint=TOPRIGHT x=table: 0000... y=BOTTOMRIGHT
```

The frame lands in `x`, the anchor point lands in `y`, and `relativeTo` is lost.
`Region:GetPoint`'s own comment (`:86-88`) claims it normalises "every SetPoint
overload down to the five values the real GetPoint returns" — for this overload
it does not.

The consequence is not a shipping bug: the Lua in `Dash.lua` is correct for the
real client. The consequence is that the regression test added to close this
branch's most serious finding — `test/test_ui.lua:1095-1112`, "keeps the text
legible when the generated geometry is absent" — asserts only
`#fs.points >= 2`, which the fake satisfies from garbage. That test would pass
unchanged if the fallback anchored every line to the wrong frame, or to nothing.
The plan's own Risk 5 names this file and says four methods have already been
found hiding in it (`SetTexCoord`, `SetFrameLevel`, `SetWordWrap`,
`SetAllPoints`). This is the fifth.

Fix: type-switch on the second argument in the `n == 3` branch, then strengthen
the fallback test to assert the relative frames, not just the count.

---

## Minor findings

1. **`state.banner` outlives the trip that set it.** `Dash.Start`
   (`Dash.lua:339`) resets `plan`, `index` and `best`, but not `banner`; only
   `OnHide` and `finish()` clear it. Driven: a stray sets the banner, then a
   second `Dash.Start` before the next tick gives
   `index=1 banner=Recalculating... steps1="Recalculating..." steps2=""` — the new
   trip's first frame shows the old trip's banner with the directions blanked.
   Self-corrects within one tick (≤0.5 s). The leak is pre-existing, but the
   blast radius grew: the old design put the banner in the secondary "then ..."
   line, leaving the current step visible; the new one takes all three lines.
   One word in `Dash.Start` closes it.

2. **`art()`'s `pad` parameter is dead, and holds the branch's only uncommented
   layout literals.** `Dash.lua:31` declares it; all four call sites (`:137`,
   `:180`, `:181`, `:187`) omit it. Its body (`:42-44`) carries `-6, 4, 6, -4`.
   The plan says "a magic number in `Dash.lua` is a defect"; these are
   unreachable, which is why luacheck is silent. It was the first design's ETA
   plate. Delete it.

3. **`geometry()` gates the geometry on the parts table.** `Dash.lua:88`:
   `return ns.Data.Art and ns.Data.ArtGeometry`. Driven with `Data.Art` nil and
   geometry present, the whole layout silently takes the fallback stack while
   the geometry sits there unread. They come from one file today, so this cannot
   bite yet — but it makes `geometry()` answer a question it was not asked.

4. **`if ui.compass then` can never be false** (`Dash.lua:370`). The texture is
   created unconditionally at `:157` and merely `Hide()`n when the part is
   missing. Harmless dead defence.

5. **The steps and ETA inserts draw below the glass, against the artist's stated
   order.** `dash2-notes.md` says "Draw glass, compass, existing arrow, steps
   insert, ETA insert, then housing." `Dash.lua:180-181` puts both inserts at
   `BACKGROUND`, under `glass` (`BORDER`), `compass` (`ARTWORK`) and `arrow`
   (`OVERLAY`). Measured, no pixels are at stake today: sampled alpha overlap is
   **0 px** for glass×steps, glass×eta, compass×steps and compass×eta (glass×
   compass overlaps 3352 sampled px, and that pair *is* in the right order).
   Fragile if a redraw widens either insert.

6. **The stop button's highlight texture gets no `SetTexCoord`.**
   `Dash.lua:296-299` passes the path to `SetHighlightTexture` directly, while
   the normal and pressed caps go through `cap()`, which applies `part.l/r/t/b`.
   Correct today only because `dash2-stop-hover` is 64×64 on a 64×64 canvas
   (`Data/Art.lua:20`, `l=0 r=1 t=0 b=1`). If `make_art.py` ever pads that part,
   two of the three caps crop and one does not.

7. **Stale references left behind.** `Dash.lua:5` still says "task 6 lays the
   art over them" (plan 4's task numbering; introduced in `b7d3fb3`).
   `test/test_ui.lua:996-997` explains the arrow fallback by contrast with
   `dash-body` / `ui.bodyArt`, neither of which exists any more.
   `docs/manual-test-checklist.md:383` still asks the tester to confirm "The five
   dash textures load", which are now the first design's parts that nothing
   draws — kept on disk deliberately (ledger P2), but the checklist does not say
   so, and line 396 already covers the eight that matter.

8. **Two weak assertions around the crop.**
   `test/tools/test_make_art.py:126-130` checks only `0 < share < 1`; nothing
   pins `share == crop width / canvas width`. And no automated test measures the
   shipped `dash2-compass.tga` itself — the crop *arithmetic* is well covered,
   the *artefact* is not. I measured it by hand (bbox centre exactly (127.5,
   127.5)) and it is right, which is why this is Minor rather than Important;
   but the ledger's own convention says manual verification should be pinned.

---

## Triage of the deferred finding

**`docs/manual-test-checklist.md:147` — "it answered the question plan 5 was
waiting on". Fix before merge. One word.**

The line is a dated in-game record (`2026-09-20`) and, read as history, is
accurate about what was observed. But the sentence is a *forward reference by
plan number*, and it is this branch that changed what that number means:
`CLAUDE.md` now ends "Next: plan 6, the route strip", the spec now lists six
plans, and this very file's own heading was changed at line 358 to "Dash unit
(plans 4 and 5)".

Read today, "the question plan 5 was waiting on" points at the dash unit's
second design. The sentence it introduces is about the remaining 34 art parts
shipping as power-of-two TGAs — which is the **route strip's** question, now
plan 6. The paragraph below it already says "a question plan 4 depends on" and
means the dash unit, so the two numbers in one entry now contradict each other.

This is not a historical annotation that merely reads oddly; it is a pointer
that the branch silently repointed, in the document the user reads while
standing in the game. The fix is `plan 5` → `plan 6 (the route strip)`, and the
argument for deferring it — that it sits outside the touched region — is weaker
than the argument for fixing it, since the branch is what broke it and the cost
is one word.

---

## Fitness against `CLAUDE.md`

| Rule | Result |
|---|---|
| No libraries | ✓ |
| No Blizzard frame templates | ✓ — `W.Panel`, `W.Fill`, `W.Text`, bare `CreateFrame` only |
| `API.lua` the only file calling game APIs | ✓ — `Dash.lua` touches `CreateFrame`, `UIParent`, `UISpecialFrames` only |
| No secure code | ✓ |
| Every FontString bounded | ✓ for anchors, both with and without geometry; **see I2** for whether the bounds fit the fonts |
| Wrap-or-truncate decided | ✓ — all six truncate, asserted at `test_ui.lua:608` |
| Zero lint warnings | ✓ luacheck and lua-language-server both clean |
| No lint suppression | ✓ none introduced |
| Generated files never hand-edited | ✓ `make_art.py` reproduces with an empty diff |
| Route text plain, no jokes | ✓ |
| `RegisterEvent` only with known names | ✓ none added |

---

## What convinced me the core is sound

The compass crop is the piece that could have been wrong in a way no desktop
test would catch, and it is right at every link: the crop box's centre equals
the dial, the shipped TGA's alpha bbox centre equals its own canvas centre to
the half-pixel, the share matches the crop, the drawn size matches the share,
and the device's horizontal and vertical scales are bit-identical so a source
square stays a square. The trip loop's diff is genuinely empty, and the banner's
three-part arrangement survived being driven rather than read. The generated
file regenerates byte for byte. The fallback path really does leave a device
with text in it.

The three Important findings are all of one shape: the branch reasoned carefully
about the art and less carefully about the size it ships the art at, and the
test harness cannot see the one path that most needed watching. None is a
rewrite. All three are cheaper to settle now than after a client run.

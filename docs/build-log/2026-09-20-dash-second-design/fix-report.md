# Fix report — plan 5, the dash unit's second design

Branch `dash-second-design`, BASE `0db3921`. Every finding in `fix-brief.md`
landed in this one wave. Nothing is deferred, nothing is pushed.

## Commits

| sha | what |
|---|---|
| `a4e9a5d` | Fake frames: parse three-argument `SetPoint` by type, record regions and layers |
| `c9de780` | Dash unit fix round 2: no art on the device frame, text on the artist's lines |
| `001a7b2` | Docs: the checklist's dash section, and the plan number that moved |

Split three ways so each commit is green on its own. The harness fix went
first and was verified against the unchanged tree (251 passed, the baseline,
so it regresses nothing on its own); the layout fix and the assertions it
unlocks went second; docs last. Every commit staged explicit paths.
`AGENTS.md` was never staged and is still untracked.

## Gates

| gate | baseline | now |
|---|---|---|
| Lua tests | 251 passed, 0 failed | **257 passed, 0 failed** |
| `python -m unittest discover -s test/tools` | 36 | **37**, OK |
| `python tools/check_art.py` | 47 / 0 / 0 | **47 / 0 / 0** |
| `python tools/make_art.py` then `git diff` | clean | **clean** — no churn on `Data/Art.lua` or `Media/*.tga` |
| luacheck | 0 warnings / 38 files | **0 warnings / 0 errors in 38 files** |
| lua-language-server | clean | **"Diagnosis completed, no problems found"** |

The brief's baseline said "39 files" for luacheck; this tree has 38 and had 38
before any change, so the count is unchanged, not reduced. No lint suppression
was added anywhere, and `GoblinPS/Trip.lua` still has an empty diff on this
branch.

## Tests seen failing before the fix

Both required ones were run against the unfixed code and failed for exactly
the reason they claim:

```
FAIL: the dash unit :: gives the device frame no regions of its own, so every rectangle can be hidden
    test/test_ui.lua:612: the device frame must carry no texture of its own; art goes on a child frame
    expected: "0"
    actual:   "2"

FAIL: the dash unit's words and stop button :: keeps the text legible when the generated geometry is absent
    test/test_ui.lua:1141: line 1 anchor 1 must hang from a real frame
    expected: "table"
    actual:   "nil", got "false"
```

The "2" is the two opaque textures `Widgets.Panel` laid on the device frame.
The `nil` is the frame that the fake's three-argument `SetPoint` was dropping
on the floor. A third test — "sits all three step lines on the centre of their
third of the art's steps box" — also failed on the way through, because it
still asserted the corner-to-corner anchoring that Important 2 ruled out; it
was updated to the new ruling rather than the ruling being bent to it.

## Important 1 — the device's own brass rectangle

`GoblinPS/Dash.lua` `build()` now opens with
`local f = CreateFrame("Frame", nil, UIParent)` and lays nothing on it. The
no-art fallback became its own frame: `W.Panel(f, "body", "brass", 3)`,
`SetAllPoints(f)`, `SetFrameLevel(base)` — below `artLayer` at `base + 1`. It
keeps the name `flat` in the `ui` table and keeps the existing comment, which
is now true of the thing it describes. `flat:Hide()` fires in the same place
as before, when the glass texture loads, and hiding a frame takes its textures
with it.

The glass moved from `BORDER` to `BACKGROUND` as part of Minor 5's re-layering;
it is still the bottom of the art stack, now with nothing underneath it on
that frame.

**Covered by** `test/test_ui.lua` "gives the device frame no regions of its own,
so every rectangle can be hidden": `#ui.frame.regions == 0`, and
`#ui.flat.regions > 0` to prove the colour went somewhere hideable rather than
simply disappearing. The fake did not track created regions, so it does now
(`test/fake_frames.lua`) — the fake was extended rather than the assertion
weakened, as the brief required.

## Important 2 — the text boxes versus the client's fonts

**Part A, and the choice the brief left me.** I took the second option:
**one helper, renamed `placeLine`, with the centre-line behaviour, and no
corner-to-corner twin.**

The reason is that there is no non-FontString call site. `place()` was called
exactly six times in `Dash.lua` and all six are lines — the destination, the
distance, the three step lines and the ETA. Everything that genuinely is an
area in this file is a texture, and every one of those fills its own frame
through `SetAllPoints`; none of them goes near the helper. So the type-branching
version would have carried a branch no call site reaches and no test can reach
either (the helper is file-local), which is the same class of dead code as the
`pad` parameter Minor 2 asked me to delete and the unused `place()` helper
commit `13b5b5e` already removed on this branch.

What the brief was guarding against — an area rect silently getting the
centre-line treatment — is instead handled by the name: a call site reading
`placeLine(eta, content, g.etaText)` states what it thinks the rect is, and a
future area cannot be placed through it by accident without the code reading
wrong out loud. The doc comment says so explicitly.

The anchoring is `LEFT` at `(rect.left * w, -(rect.top + rect.bottom) / 2 * h)`
from the parent's `TOPLEFT` and `RIGHT` at the same y, exactly as specified.
Two horizontal anchors, so the bounding rule holds and all six still truncate.

**Part B.** `Dash.SIZE = { 288, 360 }`, TOC bumped to `2026.09.20.4`. I did not
chase the 200 px step-line width; truncation stays the decided behaviour.

**Covered by** two tests: the rewritten "sits all three step lines on the centre
of their third of the art's steps box" (anchor points are `LEFT`/`RIGHT`, x from
`stepsText.left/right`, y on the centre of each third, and both anchors level),
and a new "sits the destination, distance and ETA on their own centre lines too"
doing the same for the other three. The existing aspect-ratio test already
pins `288 * 1280 == 360 * 1024` without naming either number, so it followed the
size change for free.

**The device size is the one number still owed an in-game look.** Nothing in
the repo can tell whether 288x360 reads well on a real screen at a real UI
scale. The checklist line the brief specified was added verbatim under the dash
section to say exactly that.

## Important 3 — the fake mis-parses three-argument `SetPoint`

**Half one.** `test/fake_frames.lua` now disambiguates by type: if the second
argument is a number it is `(point, x, y)`, otherwise
`(point, relativeTo, relativePoint)` with `x, y = 0, 0`. `Dash.lua:152`'s
genuine `(point, x, y)` call and the planner's uses go down the first path
unchanged — the whole suite was green on the fake fix alone before anything
else moved. The `n == 4` branch was checked against the same reasoning and left
as it is: four arguments has exactly one overload, `(point, relativeTo, x, y)`,
and there is no form at that count whose second argument is a number, so there
is nothing to disambiguate. That reasoning is now written into the comment so
the next reader does not have to re-derive it.

**Half two.** The geometry-absent test no longer counts anchors. For each of
the six lines it asserts, per anchor, that the target is a table (a real frame),
that the relative point is a named point, and that anchor 1 is a `LEFT` edge
against a `LEFT` point while anchor 2 is a `RIGHT` edge against a `RIGHT` point.
Seen failing against the unfixed fake, output quoted above.

## Minor findings

| # | what changed | test that covers it |
|---|---|---|
| 1 | `Dash.Start` resets `banner` with `plan`, `index` and `best` | "does not open a new trip under the old one's banner" — sets a banner, Starts again, asserts the banner is gone and the new trip's three lines are drawn |
| 2 | `art()`'s `pad` parameter and its `-6, 4, 6, -4` branch deleted; the body is now a plain `SetAllPoints(parent)` | existing art tests still pin every part's coordinates and size; no literal survives to test |
| 3 | `geometry()` returns `ns.Data.ArtGeometry` alone | "reads the geometry even when no part table shipped with it" — builds with `Data.Art` nil, asserts the stop button and the destination line are still placed from the geometry, not from the 20x20 / unplaced fallback |
| 4 | dead `if ui.compass then` guard in `aimArrow` dropped, comment kept and extended to say why no guard is needed | the existing arrow-aiming trip tests drive that line on every tick |
| 5 | glass `BACKGROUND`, compass `BORDER`, arrow `ARTWORK`, both inserts `OVERLAY` — the order `images/parts/dash2-notes.md` states, with the housing a frame above | "stacks the layers in the order the artist stated" — ranks the five draw layers and walks the artist's order, plus an explicit assertion that the inserts outrank the arrow |
| 6 | the hover cap goes through `cap()`, which applies `part.l/r/t/b`, and is handed to `SetHighlightTexture` as a texture object at draw layer `HIGHLIGHT` | "crops the hover cap exactly as it crops the other two" — path, three tex coords and the draw layer |
| 7 | `Dash.lua:5` no longer says "task 6 lays the art over them"; `test_ui.lua`'s arrow-fallback comment now contrasts with `dash2-housing`/`ui.housing` instead of the non-existent `dash-body`/`ui.bodyArt`; the checklist's "The five dash textures load" line is gone and the line about the eight now says the first design's five parts are kept on disk on purpose and only `arrow` is drawn | n/a — comments and checklist prose |
| 8 | `test_the_it_reports_the_crop_as_a_fraction_of_the_device` now asserts `share == (box[2] - box[0]) / canvas_w` to 12 places instead of `0 < share < 1`; a new `TestShippedCompass` measures the built `GoblinPS/Media/dash2-compass.tga` and asserts its alpha bounding box is centred on its own canvas within half a pixel (it measures exactly 127.5, 127.5 on a 256x256 canvas) | the two Python tests themselves |

On Minor 6 I also dropped `cap()`'s `setter` parameter while I was rewriting
that function: it was never passed by any of the three call sites, so it was
the same dead-parameter defect as Minor 2 sitting in the function Minor 6 asked
me to change. `cap(name, layer)` is what it takes now.

## Deferred finding, triaged

`docs/manual-test-checklist.md` line 147 now reads "the question plan 6 (the
route strip) was waiting on". The dated record around it — what passed, which
textures reported `ok`, the paragraph about plan 4 and the icon TGA — is
untouched; it is accurate history. The only other edit in that entry is
re-wrapping the two lines the substitution made overlong.

## The fake's accepted-and-ignored list — what still worries me

`SetPoint` was the fifth method found hiding in `ALLOWED_NOOP` after
`SetTexCoord`, `SetFrameLevel`, `SetWordWrap` and `SetAllPoints`. Reading the
rest of that list against what this branch's code actually depends on, three
still swallow a distinction we rely on, in rough order of how much they cost:

1. **The font object is not recorded at all**, and it is not even on the list —
   `Widgets.Text` passes it as the third argument of `CreateFontString`, which
   the fake ignores. That is the sharpest gap on this branch, because
   **Important 2 is entirely an argument about font heights against box
   heights**, and nothing in the suite can see which font any of the six lines
   uses. `destination` is `GameFontNormalSmall` and `distance` is
   `GameFontNormalLarge` — a swap would change how the glass reads and no test
   would notice. Cheap to close: record the third argument the same way the
   draw layer is now recorded.
2. **`SetJustifyH`** is a no-op. With the new centre-line anchoring, each line
   is stretched between a `LEFT` and a `RIGHT` anchor, so justification is now
   the only thing deciding where the words sit inside the opening — the ETA and
   the distance are `CENTER`, the step lines are `LEFT`. That distinction went
   from cosmetic to load-bearing in this very change, and it is invisible to
   the suite.
3. **`SetHighlightTexture`** is still a no-op, so Minor 6's test proves the
   hover cap exists and is cropped but *not* that it was handed to the button.
   A refactor that dropped the call would pass. Recording the asset and the
   blend mode would close it.

Two more worth naming but not urgent: `SetFrameStrata` (the dash is `HIGH`, the
planner is not, and nothing pins that) and `RegisterEvent`, where a name the
client does not know is a hard error in game and silence on the desktop — a
pre-existing gap the project already knows about.

## Concerns

- **288x360 has not been looked at in game, and neither has anything else on
  this branch.** Plan 5 has still never run in the client. The size is arithmetic
  from the artist's rects against the client's font heights; it is a reasoned
  number, not a measured one, and the checklist now says which number to change.
- **`SetHighlightTexture` taking a texture object** is verified in the `forever`
  branch source — `Blizzard_GamepadSharedUtility/FrameReformUtility.lua:135-165`
  creates a texture, sets its draw layer to `HIGHLIGHT`, calls `SetAllPoints`
  and passes the object — which is exactly the shape used here. The generated
  API documentation types the argument as `TextureAsset` without spelling out
  the union, so this is verified against real client code rather than against
  the doc table.
- **The working-tree line endings** of the six edited files are now LF where
  git's index expects CRLF on checkout. Git normalised on commit, so the
  committed content and every diff are correct; a future `git checkout` of
  these files will convert them back. Worth a glance if the repo owner sees a
  whitespace surprise.

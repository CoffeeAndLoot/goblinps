# Re-review — fix wave, plan 5 (the dash unit's second design)

Scope: `0db3921..001a7b2` (the fix diff) on branch `dash-second-design`, and
only it. The rest of the branch was reviewed already and is not re-opened here.
No edits were made; the working tree is exactly as the fixer left it
(`AGENTS.md` untracked, nothing else).

First: the recorded diff at
`rereview-0db3921..HEAD.diff` is byte-identical to `git diff -U10 0db3921..HEAD`
in the live repo. What was reviewed is what is committed.

---

## Verdict

**Clean, with one Trivial residual.** All twelve findings are closed by real
changes with tests that can fail. Every gate the fixer claimed is reproduced,
and the two "seen failing before the fix" claims are independently reproduced
(not taken on the report's word). Nothing in the diff introduces a regression,
a hand-typed coordinate, a weakened assertion or a CLAUDE.md violation.

| severity | count |
|---|---|
| Blocking | 0 |
| Important | 0 |
| Minor | 0 |
| Trivial | 1 |

---

## Gates — observed, not quoted

Every command was run against the working tree at `001a7b2`.

| gate | fixer claimed | I observed |
|---|---|---|
| Lua tests (`lupa`) | 257 / 0 | **257 passed, 0 failed** |
| `python -m unittest discover -s test/tools` | 37, OK | **Ran 37 tests … OK** |
| `python tools/check_art.py` | 47 / 0 / 0 | **47 pass, 0 with problems, 0 not drawn yet** |
| `python tools/make_art.py` then `git status` | no churn | **`git diff --stat` empty; only `AGENTS.md` untracked** |
| luacheck | 0 / 0 in 38 files | **Total: 0 warnings / 0 errors in 38 files** |
| lua-language-server `--check` | clean | **"Diagnosis completed, no problems found"** |

**One line:** all six gates green exactly as reported — 257 Lua, 37 Python,
check_art 47/0/0, make_art regenerates with zero churn, luacheck 0/0 in 38,
language server clean.

The brief's baseline said "39 files" for luacheck. The fixer says the tree had
38 before and after. Confirmed: `git ls-tree -r 0db3921` and `… HEAD` both
count 38 `.lua` files under `GoblinPS/` and `test/`. The brief's number was
wrong; nothing was lost.

I also checked the fixer's "each commit is green on its own" claim by
extracting each commit's tree with `git archive` and running the Lua suite in
each:

```
a4e9a5d : 251 passed, 0 failed     (harness fix alone — the stated baseline)
c9de780 : 257 passed, 0 failed
001a7b2 : 257 passed, 0 failed
```

Exactly as reported. All three commits carry
`Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`; `AGENTS.md` was never
staged; `GoblinPS/Trip.lua` has an empty diff on the branch; nothing is pushed
(there is no `origin/dash-second-design`).

### The "fails before the fix" claims, reproduced

I did not take these on trust. Two scratch copies of the tree, outside the
repo:

**Probe A — HEAD's tests and fake, base `Dash.lua`:** `249 passed, 8 failed`.

```
FAIL  gives the device frame no regions of its own …      test_ui.lua:612  expected "0"
FAIL  sits all three step lines on the centre …           test_ui.lua:637  expected "LEFT"
FAIL  sits the destination, distance and ETA …            test_ui.lua:662  expected "LEFT"
FAIL  does not open a new trip under the old one's banner test_ui.lua:710  got "Recalculating..."
FAIL  stacks the layers in the order the artist stated    test_ui.lua:1055
FAIL  reads the geometry even when no part table shipped  test_ui.lua:1084
FAIL  crops the hover cap exactly as it crops the other two test_ui.lua:1191
```

(The eighth, "Start with no steps does not open", is collateral from the banner
test failing before its closing `Dash.Stop()`.)

**Probe B — HEAD's tests and `Dash.lua`, base `fake_frames.lua`:**
`253 passed, 4 failed`, including

```
FAIL  keeps the text legible when the generated geometry is absent
      test_ui.lua:1243: line 1 anchor 1 must hang from a real frame — expected "table"
```

That is Important 3's required demonstration, reproduced word for word. Both
of the brief's mandatory "must have been seen failing" tests genuinely fail
against their unfixed counterpart, and six more besides.

---

## The twelve findings, one at a time

### Important 1 — the device's brass rectangle — **CLOSED**

`Dash.lua:122` is now `local f = CreateFrame("Frame", nil, UIParent)` with
nothing laid on it; the fallback became its own frame at `Dash.lua:156-158`
(`W.Panel(f, "body", "brass", 3)`, `SetAllPoints(f)`, `SetFrameLevel(base)`,
below `artLayer` at `base + 1`), keeps the name `flat` and the original
comment, and `flat:Hide()` still fires when the glass loads.

Test: `test/test_ui.lua:604` "gives the device frame no regions of its own …"
asserts `#ui.frame.regions == 0` and `#ui.flat.regions > 0`. The fake was
extended to record regions rather than the assertion being weakened, as the
brief required — `test/fake_frames.lua:56-64` now pushes every texture and
font string into `parent.regions`. `CreateFrame` still goes through `new()`
and does **not** register as a region, so the count is about textures only,
which is the right question. Verified failing against base `Dash.lua` (expected
"0", the two textures `Widgets.Panel` lays down).

One thing the test does not prove and cannot: that the brass really is gone
from the screen. That is pixels.

### Important 2 — text boxes versus fonts — **CLOSED, with a limit**

Part A: `place()` became `placeLine()` (`Dash.lua:107-113`), anchoring `LEFT`
and `RIGHT` at `-(rect.top + rect.bottom) / 2 * h` from the parent's `TOPLEFT`
— exactly the ruling. Two horizontal anchors kept; all six still truncate.
Part B: `Dash.SIZE = { 288, 360 }`, TOC bumped to `2026.09.20.4`. The
200 px step-line width was correctly not chased.

Tests: the rewritten `test_ui.lua:623` (step lines) and the new
`test_ui.lua:651` (destination, distance, ETA) both assert the anchor *points*
(`LEFT`/`RIGHT`), the x from the rect's edges, the y on the rect's centre, and
that the two anchors are level. The pre-existing aspect-ratio test
(`288 * 1280 == 360 * 1024`) followed the size change without naming either
number. Both new tests verified failing against base `Dash.lua`.

**The limit** — see the adjudication below. These tests pin the *anchor
arithmetic*. Nothing in the suite can see a font, measure a string, or tell
whether text fits its opening. The 21.19 px / 19.12 px arithmetic that
justifies 288×360 is a comment, not a covered claim. The checklist line was
added verbatim and says so.

### Important 3 — the fake mis-parses three-argument `SetPoint` — **CLOSED**

Half one: `fake_frames.lua:110-116` disambiguates on
`type(select(2, ...)) == "number"`. I checked the reasoning against the real
overload set — at three arguments the only two forms are `(point, x, y)` and
`(point, relativeTo, relativePoint)`, and `relativeTo` is a frame or a global
name string in the second, never a number, so the type test is total. The
`n == 4` branch was correctly left alone: `(point, relativeTo, x, y)` is the
only form at that count. That reasoning is now in the comment.

No regression on the `(point, x, y)` form: `Widgets.Panel`'s own
`inner:SetPoint("TOPLEFT", 3, -3)` and `Dash.lua`'s `stop:SetPoint("TOPRIGHT",
-8, -8)` both go down the number path, and probe A's 249 passes (planner
included) confirm it.

Half two: `test_ui.lua:1226-1250` no longer counts anchors. It asserts, per
anchor, that the target is a table, that the relative point is a named point,
and that anchor 1 is a `LEFT` edge against a `LEFT` point and anchor 2 a
`RIGHT` against a `RIGHT`. Verified failing against the base fake.

### Minor 1 — `state.banner` outlives its trip — **CLOSED**
`Dash.lua:369` resets `banner` with `plan`, `index`, `best`. Test
`test_ui.lua:698` sets a banner, refreshes, Starts again, and asserts the
banner is gone and the new trip's lines are drawn. Verified failing on base.

### Minor 2 — `art()`'s dead `pad` parameter — **CLOSED**
Parameter and the `-6, 4, 6, -4` branch deleted; body is a plain
`SetAllPoints(parent)`. No call site passed it and none does now. A deletion
of dead code needs no test; the existing art tests still pin every part.

### Minor 3 — `geometry()` gated on the parts table — **CLOSED**
`Dash.lua:89` returns `ns.Data.ArtGeometry` alone. New test
`test_ui.lua:1058` builds with `Data.Art` nil and asserts the stop button and
the destination line are still placed from the geometry. Verified failing on
base. The new state (parts absent, geometry present) is coherent: `flat`
stays shown, text and button land on the artist's coordinates over a flat
panel.

### Minor 4 — dead `if ui.compass then` — **CLOSED**
Guard dropped, comment kept and extended. `compass` is created unconditionally
at `Dash.lua:179` and only hidden when the part is missing, so it is never
nil; the existing compass-rotation trip tests drive the line on every tick.

### Minor 5 — insert draw order — **CLOSED**
`glass` BACKGROUND, `compass` BORDER, `arrow` ARTWORK, both inserts OVERLAY,
housing on a frame above. New test `test_ui.lua:1035` ranks the layers, walks
the artist's order, and asserts strictly that the inserts outrank the arrow
and the housing frame outranks the art frame. Verified failing on base. The
`>=` chain alone would not catch everything collapsed to one layer, but the
strict `stepsScreen > arrow` assertion does. Within-layer order of the two
inserts (both OVERLAY, decided by creation order) is untested — creation order
happens to match the artist's, and this is below the threshold of a finding.

### Minor 6 — the highlight cap's crop — **CLOSED**
`cap(name, layer)` now serves all three caps; the hover cap is created at
draw layer `HIGHLIGHT` with `part.l/r/t/b` applied and handed to
`SetHighlightTexture(stopHover, "ADD")`. Test `test_ui.lua:1180` pins the path,
three tex coords and the draw layer. Verified failing on base.

I checked the texture-object overload against the `forever` branch at
`D:\wow-api\1.60.1.69913` (`version.txt` = 1.60.1.69913) rather than the doc
table: `Blizzard_SharedXML/Shared/Button/IconButtonTemplate.lua:13` calls
`self:SetHighlightTexture(self.icon, "ADD")` with a texture object and a blend
mode, and `Blizzard_GamepadSharedUtility/FrameReformUtility.lua:155-166`
creates a texture, calls `SetDrawLayer("HIGHLIGHT")`, `SetAllPoints()` and
passes the object. The generated docs type the argument `TextureAsset` without
spelling out the union. The fixer's claim holds, verified in source.

The fixer also dropped `cap()`'s never-passed `setter` parameter. That is in
the spirit of Minor 2 and is fine.

### Minor 7 — three stale references — **CLOSED** (and one new one created;
see the residual)
`Dash.lua:3-6` no longer says "task 6 lays the art over them"; the arrow
fallback comment now contrasts with `dash2-housing`/`ui.housing`; the
checklist's "The five dash textures load" line is gone and the eight-texture
line now explains that the first design's five parts are kept on disk on
purpose and only `arrow` is drawn.

### Minor 8 — two weak assertions round the compass crop — **CLOSED**
`test_the_it_reports_the_crop_as_a_fraction_of_the_device` now asserts
`share == (box[2] - box[0]) / canvas_w` to 12 places, and a new
`TestShippedCompass` measures the built `GoblinPS/Media/dash2-compass.tga`.

I checked both can fail rather than trusting them:

- Mutating `geometry_lua()`'s divisor to `w * 2` in a scratch copy fails the
  test (`0.2734375 != 0.546875`). It is a real detector of magnitude. Two
  honest limits: it re-derives its expectation from the same
  `compass_crop_box()` and `geometry()` the implementation calls, so a wrong
  crop box passes; and because that box is square, swapping width for height
  (`box[3] - box[1]`) also passes. I confirmed the swap mutation goes green.
  The brief asked for exactly this assertion, so this is a note on its reach,
  not a defect.
- `TestShippedCompass` is not vacuous: the shipped TGA is 256×256 with an
  alpha bounding box of x 6–249, y 6–249 and only 2% non-transparent pixels,
  so there is real padding on every side and the centre lands on exactly
  127.5. `assertAlmostEqual(..., delta=0.5)` is inclusive, so a one-sided
  one-pixel crop error (centre 128.0) would slip through; a whole-ring shift
  would not. Fine for its stated purpose.

### Deferred finding — **CLOSED**
`docs/manual-test-checklist.md:147` now reads "the question plan 6 (the route
strip) was waiting on". The dated record around it is untouched; the only
other edit in that entry is re-wrapping.

---

## Did the fix introduce anything new?

**Hand-typed coordinates in `Dash.lua`: none.** Every numeric literal left in
the file is either `Dash.SIZE` (the permitted exception, now documented and
derived from the art's 4:5) or a geometry-absent fallback that predates this
wave and is commented as a guess: `{ x = 0.5, y = 0.4 }`, `0.55`, `0.45`, the
`20, 20` placeholder button and its `-8, -8`. The wave added no new ones and
removed four (`-6, 4, 6, -4`).

**Regressions: none found.** The three-argument `SetPoint` change is the only
one with reach beyond the dash, and the whole planner suite is green through
it (probe A, base Dash, 249 passing).

**New dead code: none.** The wave deleted three dead things (`pad`, `setter`,
the `ui.compass` guard) and added no branch without a caller. `ui.stopHover`
is used by `SetHighlightTexture` and by the test; it is not dead.

**Weakened assertions: none.** The only assertions removed are the four
top/bottom checks in the step-line test, replaced by the centre-line and
levelness checks the ruling demanded. The fixer correctly updated the test to
the ruling rather than bending the ruling to the test.

**CLAUDE.md rules: held.** No Blizzard templates; no secure code; no new
`RegisterEvent`; `Dash.lua` touches only `CreateFrame`/`UIParent`; every
FontString still has two horizontal anchors and `SetWordWrap(false)`; no lint
suppression anywhere in the tree (`grep` for `luacheck:` and `@diagnostic`
returns nothing); generated files regenerate with zero churn; commits are
local and path-staged.

**Stale size references: none.** `232` and `290` survive nowhere in
`GoblinPS/`, `test/` or `docs/` in this sense.

---

## The three things the fixer flagged — adjudicated

### 1. One `placeLine`, not two behaviours — **the fixer is right**

Every call site is genuinely a line, and the brief's premise was factually
wrong about the code it was describing. `git show 0db3921:GoblinPS/Dash.lua`
has exactly four `place(` call lines — `destination`, `distance`, `steps[i]`
in a loop of three, `eta` — six calls, all `FontString`s from `W.Text`. The
brief's "`place()` is also used for regions that genuinely are areas" does not
describe that file: every area in `Dash.lua` is a texture that fills its own
frame through `SetAllPoints`, and none of them goes near the helper. A
type-branching `place()` would have carried a corner-to-corner branch that no
call site and no test could reach, in a file-local function — the same defect
class as the `pad` parameter the same wave was told to delete. The rename
carries the constraint at every call site, which is what the brief actually
wanted. Ruling: accept, and the choice was reported as the brief required.

### 2. The fake does not record the font object — **real, and it limits more
than the report says, though in a different direction**

Confirmed: `Widgets.Text` passes the font object as the **third** argument of
`CreateFontString`, and the fake's `CreateFontString(_, layer)` captures only
the second. `SetFontObject` is separately on `ALLOWED_NOOP`. Both routes to a
font are blind.

How much does it limit what the tests prove? The honest answer is that
recording the font object would buy **less** than the report implies. The fake
has no font metrics at all — no string measurement, no natural height, no
`GetStringWidth` (calling it would raise, being PascalCase and unmodelled).
So even with the font recorded, a test could only assert *which font object
was named*, a change-detector. It still could not answer the question
Important 2 is about: does a 10 px font, centred on a 21.19 px line, sit
inside the artist's opening at 288×360?

So the position is:

- What the tests now prove: the anchor points, targets, x from the rect edges,
  y on the rect's centre, levelness, and that every line truncates. That is
  the whole mechanism of the fix, and it is proved against a fake that no
  longer lies about anchors.
- What no test can prove, now or with the font recorded: fit, legibility, and
  therefore 288×360 itself. That is a pixels-and-client question, and the
  device has never run in the client. The checklist line the brief mandated is
  the right and only instrument for it.

The fixer's suggestion is still worth taking — it is cheap and it closes a
silent-swap hole — but it should not be sold as closing Important 2's
evidence gap, because it does not.

### 3. `SetJustifyH` is a no-op and "just became load-bearing" — **the exposure
is real; the "just became" is not**

The exposure is real. `SetJustifyH` is on `ALLOWED_NOOP`
(`fake_frames.lua:18`), nothing records it, and a refactor that swapped the
ETA from `CENTER` to `LEFT` — or the step lines the other way — would pass the
whole suite. Three of the six lines are `CENTER` and three are `LEFT`, and
with the FontString stretched between two horizontal anchors, justification is
what decides where the words sit in the opening.

But the claim that this "went from cosmetic to load-bearing in this very
change" is wrong, and worth correcting because it misattributes a pre-existing
gap to the fix. The old `place()` anchored `TOPLEFT`/`BOTTOMRIGHT` at the
rect's left and right — the *same* horizontal span. Justification decided
horizontal placement exactly as much before the change as after. What the
centre-line rewrite changed is vertical, and justification has no vertical
component (`SetJustifyV` is not called at all). So: a real, untested
exposure, pre-existing on this branch and before it, neither created nor
worsened by this wave. Not a finding against the fix diff.

The other two the fixer named check out as stated: `SetHighlightTexture` is a
no-op, so Minor 6's test proves the hover cap exists and is cropped but not
that the button received it; and `SetFrameStrata` is a no-op, so the dash's
`HIGH` strata is unpinned. I would add one more to the list, of the same
family: `SetColorTexture` is a no-op, so `#ui.flat.regions > 0` proves the
fallback frame owns textures but not that they carry the brass and body
colours.

---

## Residual finding

### Trivial 1 — a new stale reference, in the wave that fixed three

`test/test_ui.lua:1218` still reads:

```lua
-- Every `if g then place(...) end` block had no `else`: with
```

The helper was renamed to `placeLine` in this same wave (Minor 7's whole point
was stale references, and the rename created a fourth). One word in a comment;
no behaviour. Worth a line on the next pass, not worth a commit of its own.

---

## Things worth the owner's eye, not findings

- **`docs/manual-test-checklist.md` now carries two near-duplicate lines** in
  the dash section: "Every line sits inside its own opening in the chassis; no
  text is cut off and none draws on the brass" and the new "Every line of text
  sits on its opening and is legible …". The brief specified the new one
  verbatim, so this is compliance, not a defect — but that file is read
  standing in the game, and two lines asking nearly the same thing cost the
  tester a moment. Merging them is the owner's call.
- **Line endings.** The report says "the six edited files" are now LF in the
  working tree. Only one is: `test/fake_frames.lua`. The other five are CRLF.
  With `core.autocrlf=true` and no `.gitattributes`, the index and every diff
  are correct either way, and `git status` is clean. No action needed.
- **`cap()` does not hide a texture whose file fails to load**, where `art()`
  does (`t:Hide()`). Pre-existing on both sides of this diff, and harmless for
  a HIGHLIGHT-layer texture, so out of scope — but it is the sort of asymmetry
  that bites later.

---

## The one thing most worth the owner's attention

**288×360 is the whole fix's load-bearing number and no test on this branch
can touch it.** Important 2 was an argument about font heights against box
heights; the fix answered it by taking height out of the anchoring entirely
and growing the device. Both halves are right, and the anchor arithmetic is
now pinned by tests that I watched fail against the old code. But the fake
frame harness has no font metrics of any kind — recording the font object, as
the fixer suggests, would not change that — so whether a 10 px line centred on
a 21.19 px opening actually reads, at UI scale 0.64 and at 1.0, is knowable
only in the client. Plan 5 has still never run there. The checklist line that
names 288×360 as the number to change is the right instrument, and that one
walk is what this branch is waiting on before merge, not more desktop work.

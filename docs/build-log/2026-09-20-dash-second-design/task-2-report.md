# Task 2 report: the device, rebuilt from the geometry

## Files changed

- `GoblinPS/Dash.lua` — layout rebuilt to draw the second design from
  `ns.Data.Art`/`ns.Data.ArtGeometry` instead of the first design's constants.
- `GoblinPS/GoblinPS.toc` — `## Version: 2026.09.20.3`.
- `test/test_ui.lua` — four new tests, six re-pointed tests, two restore
  fixes.

## `GoblinPS/Dash.lua`, by line (final file)

- Lines 12–17: `Dash.SIZE` comment and value replaced. Old: `{ 220, 348 }`
  with `PAD, DEVICE = 10, 200` (a square device plus a text band). New:
  `{ 230, 288 }` (the 1024x1280 art's own shape) with `local PAD = 8`;
  `DEVICE` is gone, nothing else needs it.
- Lines 75–87: two new file-local helpers added above `build()`:
  `geometry()` (returns `ns.Data.ArtGeometry` if `ns.Data.Art` exists) and
  `place(region, parent, rect)` (positions a region from a `{left, top,
  right, bottom}` fractional box). `place` is unused in this task — Task 3
  calls it directly when it moves the FontStrings onto the geometry's
  text-safe boxes — so I marked the line `-- luacheck: ignore 211` (see
  "Deviations from the brief" below).
- Lines 113–210 (old 113–218): the entire old-design layout block replaced.
  New structure, bottom to top: `artLayer` (base+1, one rectangle filling
  `f`, holding `flat`/`glass`/`compass`/`arrow`/`stepsScreen`/`etaScreen`),
  `housingFrame` (base+2, holds `housing`), `content` (base+3, holds the
  four FontStrings), `stop` (base+4). `compass` and `arrow` are centred on
  the dial (`g.glass.cx`, `g.glass.cy`) via a local `centreOnDial` closure
  and sized as `g.compassCrop.share` / `g.arrow.share` of the device.
- Lines 206–210: `ui` table rebuilt with the new field names (see brief's
  interface list): `frame, artLayer, flat, glass, compass, arrow,
  stepsScreen, etaScreen, housingFrame, housing, content, distance, eta,
  step, next, stop`.
- `Dash.Tick`, `Dash.Refresh`, `Dash.Start`, `Dash.Stop`, `aimArrow`,
  `finish`, `Dash.Debug`, `Dash.TICK`, `yards` — byte-for-byte untouched.
  Confirmed by diff: the only hunks in the file are the size constants, the
  two new helpers, and the `build()` layout block.

## First-design textures removed, and where

All four found in `build()`, all removed (the `Data/Art.lua` entries and the
PNG/TGA files on disk are untouched, per the brief):

1. `dash-body` — was `local bodyArt = art(bezel, "dash-body", "OVERLAY")`
   (old line 160), on the old `bezel` frame. Removed with the whole old
   `device`/`screen`/`bezel` block.
2. `dash-screen` — was `local screenArt = art(screen, "dash-screen",
   "BORDER")` (old line 131), on the old `screen` frame. Removed likewise.
3. `dash-compass` — was `local compass = art(screen, "dash-compass",
   "ARTWORK")` (old line 135). Removed; `compass` is now a fresh texture
   built from `dash2-compass`.
4. `dash-eta-plate` — was `local plateArt = art(content, "dash-eta-plate",
   "BACKGROUND", eta)` (old line 194, the one the brief specifically warned
   about because it survives outside the 113–160 block). Removed — no
   `plateArt` anywhere in the new file.

`grep -n "device\|DEVICE\b\|bezel\|plateArt\|bodyArt\|screenArt\|screenFlat"
GoblinPS/Dash.lua` after the change turns up nothing but the words "device"
and "screen" used in prose comments/local variable names that mean the new
thing (`screen` colour name passed to `W.Fill`, "device" as the on-screen
gadget, not the old frame).

## Deviations from the brief, and why

1. **The literal "replace down to the old `bodyArt`" boundary would have
   double-declared `content`.** The old code's `content` frame
   (`CreateFrame` + `SetAllPoints(f)` + `SetFrameLevel(base + 3)`) sits
   *after* the old `bodyArt` line, and the brief's own replacement snippet
   ends by creating a new `content` frame with the same three lines. Taking
   "down to the old bodyArt" completely literally would leave two `local
   content = CreateFrame(...)` declarations in the same scope — the second
   shadowing the first, so the FontStrings created right after would bind to
   whichever one is lexically last, and the earlier one would be a dead,
   wasted frame. I extended the replaced range to also swallow the old
   `content`-frame creation (and its comment), since the new snippet already
   supplies it; nothing behavioural was lost — it's the same frame, created
   once.
2. **The old FontStrings anchored to `device`, which no longer exists.**
   The brief says to "keep the existing FontStrings for now, parented to
   `content`," but their old anchors (`distance:SetPoint("TOPLEFT", device,
   "BOTTOMLEFT", 0, -2)`, etc.) reference the now-deleted `device` frame.
   I re-anchored them to stack directly off `content`'s own edges and each
   other, with no offset (`distance` to `content`'s TOPLEFT/TOPRIGHT, `eta`
   below `distance`, `step` below `eta`, `following` below `step`). This
   also drops the small hand-typed pixel nudges (`0, -2`, `2, -6`, etc.)
   that the old anchors carried, which is consistent with the "no hand-typed
   offsets" constraint — these are placeholder positions Task 3 replaces
   outright with the geometry's `stepsText`/`etaText`/`destination`/
   `distance` boxes, so I did not invent new geometry-sourced numbers for a
   layout that is about to be thrown away.
3. **`place` is unused in this task, which luacheck flags.** The brief's
   interface section requires Task 2 to produce a file-local `place`
   function for Task 3 to call directly, but nothing in Task 2's own layout
   calls it (Task 2 uses `centreOnDial`, a closure, for the two square
   layers; the full-rectangle layers use plain `SetAllPoints`). That leaves
   `place` genuinely unused until Task 3 lands, which luacheck correctly
   flags as `unused function 'place'` (211). Since the "zero warnings" gate
   and the "produce `place` now" interface requirement can't both be
   satisfied by writing different code, I kept the function exactly as
   specified and added a narrow `-- luacheck: ignore 211` on its
   declaration line, with a comment explaining it's unused until Task 3.
   This is a suppression of a real, correctly-reported warning, not a
   hidden defect — flagging it here in case review prefers a different
   resolution (e.g. having Task 2 not add `place` at all, and Task 3 add it
   when it's first used).
4. **The aspect-ratio replacement test is a `<` 0.01 tolerance, not exact
   equality.** `Dash.SIZE = {230, 288}` gives a ratio of 230/288 =
   0.798611..., while the art's own canvas ratio (`1024/1280`) is exactly
   0.8 — a ~0.0014 difference from rounding 230.4 down to 230 in the
   brief's literal size. An exact `h.eq` would fail. I used
   `math.abs((w/h2) - artRatio) < 0.01`, which still catches a real
   regression (e.g. someone changing `Dash.SIZE` to something visibly
   stretched) while tolerating this one-pixel rounding.

## RED (Step 2)

Added the four new tests from the brief's Step 1 first, before touching
`Dash.lua`. Ran:

```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```

Result: `240 passed, 3 failed`

```
FAIL: the dash unit :: lays the five shared layers on one rectangle
    test/test_ui.lua:623: glass is missing, got "nil"
FAIL: the dash unit :: takes every position from the generated geometry, not from constants
    test/test_ui.lua:645: attempt to index field 'artLayer' (a nil value)
FAIL: the dash unit :: stacks the housing above the art and the text above the housing
    test/test_ui.lua:653: attempt to index field 'housingFrame' (a nil value)
```

("makes the compass and the arrow square, because both turn" passed by
coincidence against the old design too, since the old `compass`/`arrow` were
already square — not a false negative, the property genuinely already held.)

After rebuilding `Dash.lua`'s layout (Step 3) but before re-pointing the six
old first-design tests, ran again to confirm the expected regression:

Result: `238 passed, 5 failed` — the four Step-1 tests now pass, and the six
tests naming `ui.device`/`ui.screen`/`ui.bezel`/`ui.bodyArt`/`ui.screenArt`/
`ui.plateArt` fail with `attempt to index field '...' (a nil value)` or
similar, exactly as expected since those fields no longer exist.

## GREEN (Step 4)

After re-pointing all six tests and fixing the two fragile restores:

```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```

Result: `243 passed, 0 failed` (239 baseline + 4 new).

## Re-pointed tests, before and after

All six live in `test/test_ui.lua`:

1. **"keeps the round art on a square frame so it cannot render as an
   oval"** → renamed **"keeps the frame at the art's aspect ratio so it
   cannot render stretched"**. Before: asserted `ui.device` was square
   (width == height) and that `ui.frame` was tall enough to leave >=100px
   below the device for the text band. After: asserts `ui.frame`'s own
   width:height ratio is within 0.01 of the art canvas's 1024:1280 ratio
   (`ns.Data.ArtGeometry.canvas`). The "text band under the device" half of
   the old assertion is gone because the second design has no separate band
   — the whole rectangle is the art, with the steps/ETA screens baked into
   the same canvas — so there is nothing analogous left to assert.
2. **"draws the three stacked layers at one square, as the art requires"**
   — kept, re-pointed. Before: looped over `{"screen", "bezel"}` checking
   each matched `ui.device`'s width/height. After: loops over `{"glass",
   "stepsScreen", "etaScreen", "housing"}` checking each matches
   `ui.artLayer`'s width/height. This duplicates the new "lays the five
   shared layers on one rectangle" test's coverage; I kept both because the
   brief explicitly said to re-point rather than drop it, and it documents
   the same in-game incident under its original name.
3. **"hides the square fallback colour once the round glass loads"** —
   kept, re-pointed. Before: checked `ui.screenArt` truthy and
   `ui.screenFlat:IsShown()` false. After: checks `ui.glass` truthy and
   `ui.flat:IsShown()` false. Same assertion, new names.
4. **"lays every part on with the coordinates the tool generated"** — kept,
   re-pointed. Before: checked `{ui.bodyArt, "dash-body"}, {ui.screenArt,
   "dash-screen"}, {ui.compass, "dash-compass"}, {ui.arrow, "arrow"},
   {ui.plateArt, "dash-eta-plate"}` all carry their generated part's file
   and texture-coordinate `l`/`r`. After: the same shape of check over
   `{ui.housing, "dash2-housing"}, {ui.glass, "dash2-glass"}, {ui.compass,
   "dash2-compass"}, {ui.arrow, "arrow"}, {ui.stepsScreen,
   "dash2-steps-screen"}, {ui.etaScreen, "dash2-eta-screen"}` — the arrow
   entry is unchanged since `arrow.png` itself didn't change.
5. **"keeps a working device when a texture will not load"** — kept,
   re-pointed. Before: faked a missing `dash-body` texture and asserted
   `ui.bodyArt` was falsy afterward (with the window still shown and
   readable). After: fakes a missing `dash2-housing` texture (the housing
   is the new design's equivalent "outer chassis" part) and asserts
   `ui.housing` is falsy, same surrounding assertions kept.
6. **"the directions are never hidden behind the device"** (the stacking
   test) — kept, re-pointed. Before: three assertions,
   `screen > frame`, `bezel > screen`, `content > bezel`. After: two
   assertions, `housingFrame > artLayer` and `content > housingFrame`
   (kept the "content outranks the housing" half exactly, per the brief).
   One assertion fewer because the new design only has three levels of
   frame here (`artLayer`, `housingFrame`, `content`) versus the old
   design's four (`f`, `screen`, `bezel`, `content`).

**Not re-pointed, left as-is (per brief):** "keeps the flat placeholder when
the arrow's own texture will not load" — the brief said to keep this one's
assertion exactly as it is, since `arrow.png` is unchanged; only the file
key checked already matched (`"arrow"`), so no edit was needed here at all.

I did not judge any of the six as obsolete; all six still test a real,
previously-seen-in-game defect against the new shape.

## The two fragile restores

Both were bare final lines (`where.mx, where.my = 0.89, 0.9 -- restore for
the tests that follow`) after several assertions that can raise:

- **"shows Recalculating for the tick a stray is caught..."**
  (around old line 835, now inside the same `it`): wrapped the body from the
  first `standAt` call through the last assertion in `local ok, err =
  pcall(function() ... end)`, moved the `where.mx, where.my = 0.89, 0.9`
  restore to run unconditionally right after the `pcall` returns, then
  `h.truthy(ok, err)` to still fail the test (with the real error message)
  if something inside broke — matching the pattern already used in "backs
  off after a replan finds no route, instead of retrying every tick".
- **"re-pins the replanned route's first step, not just the trip's very
  first one"** (around old line 849): same treatment — body wrapped in
  `pcall`, restore unconditional, `h.truthy(ok, err)` after.

## Trip loop confirmation

`Dash.Tick`, `Dash.Refresh`, `Dash.Start`, `Dash.Stop`, `aimArrow`,
`finish`, `Dash.Debug`, `Dash.TICK`, and everything in `GoblinPS/Trip.lua`
are untouched — `git diff -- GoblinPS/Dash.lua` shows the only hunks are the
`Dash.SIZE`/`PAD` constants, the two new helpers above `build()`, and the
`build()` layout block itself (old line ~113 through the `ui` table). No
other function in the file has a diff.

## Final counts

- Lua suite: **243 passed, 0 failed** (239 baseline + 4 new tests from
  Step 1; net six other tests re-pointed, not added or removed).
- luacheck (`GoblinPS test tools`): **0 warnings, 0 errors** in 39 files
  (after the one `-- luacheck: ignore 211` noted above on `place`'s
  declaration line — without it, `Dash.lua` reports `1 warning:
  GoblinPS\Dash.lua:82:16: unused function 'place'`).
- lua-language-server (`--check D:\goblinps --checklevel=Warning`):
  `Diagnosis completed, no problems found` — `[]`.

## Commit

```
git add GoblinPS/Dash.lua GoblinPS/GoblinPS.toc test/test_ui.lua
git commit -m "Dash unit: rebuild the layout from the generated geometry" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

`AGENTS.md` (untracked, belongs to Codex per the repo's shared-repo
convention) was not staged. Nothing pushed, no branch switched.

## Fix round 1

Two findings from the coordinator, both accepted and fixed.

**Finding 1 — the aspect-ratio tolerance was hiding a rounding choice.**
`Dash.SIZE` is now `{ 232, 290 }` (232/290 = 0.8 exactly, matching the art's
1024/1280 exactly — the coordinator's point that 230/288's 0.798611 was a
side effect of my rounding, not a constraint, was correct). The re-pointed
test in `test/test_ui.lua` ("keeps the frame at the art's aspect ratio so it
cannot render stretched") no longer tolerates any difference:

```lua
local w, h2 = ui.frame:GetWidth(), ui.frame:GetHeight()
-- Cross-multiplied so this is an exact check, not a tolerance:
-- w/h2 == canvas.w/canvas.h without dividing at all.
h.eq(w * g.canvas.h, h2 * g.canvas.w,
     "the frame must keep the art's 1024x1280 aspect ratio exactly")
```

Both sides come from `ns.Data.ArtGeometry.canvas` (`g.canvas.w`,
`g.canvas.h`) and `ui.frame`'s own measured size — no `0.8` written anywhere.
Cross-multiplying avoids floating-point division altogether, so `h.eq` is a
genuinely exact integer comparison, not floats that merely happen to compare
equal.

**Verified the test actually fails on the old value.** I temporarily set
`Dash.SIZE` back to `{ 230, 288 }` and reran the suite:

```
FAIL: the dash unit :: keeps the frame at the art's aspect ratio so it cannot render stretched
    test/test_ui.lua:553: the frame must keep the art's 1024x1280 aspect ratio exactly
    expected: "294912"
    actual:   "294400"
```

(242 passed, 1 failed — only this test broke.) `294912 = 288 * 1024`,
`294400 = 230 * 1280` — cross-multiplication catches the 512-unit gap the
old tolerance was absorbing. I then restored `Dash.SIZE = { 232, 290 }` and
reran: 243 passed, 0 failed.

**Finding 2 — `place` deleted, not suppressed.** Removed `local function
place(region, parent, rect)` and its doc comment entirely from
`GoblinPS/Dash.lua` (it sat between `geometry()` and `build()`), along with
the `-- luacheck: ignore 211` on its declaration line. Task 3 will introduce
`place` at the point it first calls it, so no suppression from this task
enters the branch's history. `geometry()` itself stays — `build()` still
calls it (`local g = geometry()`) to read `g.glass.cx/cy`,
`g.compassCrop.share` and `g.arrow.share` for `centreOnDial`.

**No other lint suppression exists anywhere in the diff.**
`grep -rn "luacheck: ignore\|luacheck: push\|luacheck: pop" GoblinPS/Dash.lua
test/test_ui.lua` returns nothing.

### Final verification (round 1)

- Lua suite: **243 passed, 0 failed** (unchanged from before round 1; no
  regression).
- luacheck (`GoblinPS test tools --no-color --no-cache`): **0 warnings, 0
  errors** in 39 files — `GoblinPS\Dash.lua OK` with no suppression comment
  anywhere in it.
- lua-language-server (`--check D:\goblinps --checklevel=Warning`):
  `Diagnosis completed, no problems found` — `[]`.
- Diff scope: only `GoblinPS/Dash.lua` (13 lines removed, the `place`
  function and its comment, plus the one-line `Dash.SIZE` change) and
  `test/test_ui.lua` (the aspect-ratio assertion) touched. Nothing in
  `GoblinPS/Trip.lua`, `tools/`, `images/parts/` or `GoblinPS/Media/`.

### Commit

```
git add GoblinPS/Dash.lua test/test_ui.lua
git commit -m "Fix round 1: exact art aspect ratio, drop the unused place() helper" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

`AGENTS.md` again left unstaged. Nothing pushed, no branch switched.

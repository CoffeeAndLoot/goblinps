# Task 3 report: the words, and a stop button that presses

## Summary

Implemented as specified in the brief, with three deviations found and fixed
along the way (the removed `place()` helper, the stale "then " prefix in one
pre-existing assertion, and PAD's continued use in the button's fallback
path). Baseline was 243 Lua tests, zero warnings; final is 250 tests, zero
warnings.

## Files changed

- `GoblinPS/Dash.lua`
- `test/test_ui.lua`

## What changed, per file

### `GoblinPS/Dash.lua`

- **Line 16**: removed `local PAD = 8`. Its only use was the old placeholder
  button (`stop:SetPoint("BOTTOM", 0, PAD)`); once the button takes its
  position from geometry, PAD had no remaining caller and would have been a
  dead local flagged by luacheck (unused-variable, 211) had it stayed — and
  no lint suppression is allowed. See "Deviation 1" below for why the
  fallback branch also does not use it.
- **Lines 60-85** (`Dash.Refresh`): now writes `ui.steps[1..3]` instead of
  `ui.step`/`ui.next`. When `state.banner` is set, `steps[1]` takes the
  banner text and `steps[2]`/`steps[3]` are blanked; otherwise all three are
  filled from `stepText(steps[state.index + i - 1])`. Also sets
  `ui.destination` from `step.to` via `ns.Search.ShortName`, per the design
  decision that the glass names the *current step's target*, never the
  trip's final destination.
- **Lines 91-99**: re-added the `place(region, parent, rect)` helper (dropped
  in commit `13b5b5e` as "unused" — Task 2 built the geometry-driven layout
  but nothing called it yet). Task 3 is the first caller, so it is back
  without the `-- luacheck: ignore 211` comment it needed before; it is
  gone from the file's history, not just unused-suppressed.
- **Lines 142-178**: added the three fallback comments requested (dial
  centre `0.5, 0.4`; compass share `0.55`; arrow share `0.45`), each marking
  that the literal is only reached when `ns.Data.ArtGeometry` is absent.
- **Lines 189-286** (`build()`): replaced the four placeholder FontStrings
  and the `W.Button` text button with:
  - `destination` and `distance` on the glass, placed from `g.destination`
    and `g.distance`.
  - `steps[1..3]`, three LEFT-justified lines placed from `g.stepsText`
    split into equal thirds (`box.top + third * (i-1)` to
    `box.top + third * i`).
  - `eta`, placed from `g.etaText`.
  - `stop`, a real `Button` frame sized `f:GetWidth() * g.stop.r * 2` square
    and centred at `g.stop.cx, g.stop.cy` (see "Where the stop button ends
    up" below), carrying the three art caps (`cap()` helper) with hover via
    `SetHighlightTexture`, and a flat "hazard"-coloured square fallback via
    `W.Fill` if the normal cap texture fails to load.
  - `ui` table gained `destination`, `steps` (array), `stop`, `stopNormal`,
    `stopPressed`, and lost `step`/`next`.
- **Lines 356-365** (`finish`): now writes `"Arrived."` to `ui.steps[1]`,
  blanks `ui.steps[2]`/`ui.steps[3]`, and additionally blanks
  `ui.destination` (not explicitly requested by the brief, but consistent —
  the arrow hides on arrival, so there is nothing left for the glass to
  name; this matches the file's existing "leave a working, readable device"
  standard and breaks no test).

No other reads of `ui.step`/`ui.next` remained in `Dash.lua` (`Dash.Tick`
never referenced them directly — only `Dash.Refresh` and `finish` did).

### `test/test_ui.lua`

- **Line 503**: added `local MEDIA_STOP = "Interface\\AddOns\\GoblinPS\\Media\\dash2-stop"` near the top of the dash block, as instructed.
- **Lines 505-511**: lifted the repeated `assert(loadfile("GoblinPS/Dash.lua"))("GoblinPS", ns)` idiom into a local `freshDash()` helper (it had already been copy-pasted twice; Task 3 needed a third copy, which is exactly the "reuse it twice → lift it" trigger the brief names).
- **Two existing "missing texture" tests** (housing, arrow — now around lines 995 and 1010) call `freshDash()` instead of repeating the `loadfile` line.
- **Lines 537-547** ("opens on Start...", "says nothing follows the last step"): re-pointed `ui.step`→`ui.steps[1]`, `ui.next`→`ui.steps[2]`. The old assertion `"then Zeppelin to East Dock"` is now `"Zeppelin to East Dock"` — seeAI **Deviation 2** below; this is a case that needed more than a rename, beyond the two the brief flagged. Also added an explicit `ui.steps[3]` check for completeness (blank when nothing follows).
- **Lines ~592-620** (the wrap test and "every line of text is bounded"): replaced the wrap assertion with a new test, `"truncates all three step lines, each inside its third of the art's steps box"`, that checks `wordWrap == false` for all three and that each line's `place()`-derived anchors land at `box.left/box.right` and the correct third of `g.stepsText` vertically. Updated "every line of text is bounded" to iterate `{ "destination", "distance", "eta" }` plus `ui.steps[1..3]` instead of the old `{ "step", "next", "distance", "eta" }`.
- **Six re-pointed single-line reads**: `ui.step:GetText()` → `ui.steps[1]:GetText()` in "advances when you reach the step's target", "says Arrived and stops at the end", "finishes the trip when a recalculation finds nothing left to plan"; `ui.next:GetText():find("Recalculating"...)` → `ui.steps[1]:GetText():find(...)` (two occurrences) in "shows Recalculating for the tick a stray is caught..."; `ui.step:GetText() ~= ""` → `ui.steps[1]:GetText() ~= ""` in "keeps a working device when a texture will not load". All assertion text and logic left untouched — pure field-name updates, per "change the read, never the assertion."
- **New describe block** `"the dash unit's words and stop button"` (line 1014), added after "the dash art": the six failing tests specified in Step 1 of the brief, verbatim in intent (destination+distance on the glass, three step lines including the index=3 case, bounded lines, stop button geometry/two-state textures, click-stops-trip, and the missing-art fallback using `freshDash()` + `MEDIA_STOP`).
- **New test** `"leaves a malformed Data.Art entry out of the texture list instead of crashing"` (line 1116), inside the existing `"SelfTest.lua without generated art"` describe block. It inserts a `{ l=0, r=1, t=0, b=1 }` entry (no `.file`) into the real `ns.Data.Art`, reloads `SelfTest.lua` against a throwaway namespace sharing that `Data` table (so it doesn't clobber the shared `ns.SelfTest` other tests still read from earlier in the file), asserts the load doesn't error and the malformed entry's path never appears in `TEXTURES`, asserts a real entry (`dash2-housing`) still does, and restores `ns.Data.Art.malformed = nil`. The restore and both assertions run inside a `pcall`, wrapped per item 4 of the brief.

## RED then GREEN

Baseline before any test changes:
```
243 passed, 0 failed
```

RED, after writing all the new/re-pointed tests but before touching
`Dash.lua`:
```
1
237 passed, 13 failed
FAIL: the dash unit :: opens on Start and shows the first step and the one after
    test/test_ui.lua:537: attempt to index field 'steps' (a nil value)
FAIL: the dash unit :: says nothing follows the last step
    test/test_ui.lua:544: attempt to index field 'steps' (a nil value)
FAIL: the dash unit :: truncates all three step lines, each inside its third of the art's steps box
    test/test_ui.lua:602: bad argument #1 to 'ipairs' (table expected, got nil)
FAIL: the dash unit :: every line of text is bounded
    test/test_ui.lua:619: attempt to index local 'fs' (a nil value)
FAIL: the dash unit drives the trip :: advances when you reach the step's target
    test/test_ui.lua:706: attempt to index field 'steps' (a nil value)
FAIL: the dash unit drives the trip :: says Arrived and stops at the end
    test/test_ui.lua:725: attempt to index field 'steps' (a nil value)
FAIL: the dash unit drives the trip :: finishes the trip when a recalculation finds nothing left to plan
    test/test_ui.lua:828: attempt to index field 'steps' (a nil value)
FAIL: the dash unit drives the trip :: shows Recalculating for the tick a stray is caught, and lets it go on the next one
    test/test_ui.lua:913: test/test_ui.lua:905: attempt to index field 'steps' (a nil value), got "false"
FAIL: the dash art :: keeps a working device when a texture will not load
    test/test_ui.lua:979: attempt to index field 'steps' (a nil value)
FAIL: the dash unit's words and stop button :: puts the current step's name and distance on the glass
    test/test_ui.lua:1020: attempt to index field 'destination' (a nil value)
FAIL: the dash unit's words and stop button :: shows the step you are on and the next two
    test/test_ui.lua:1028: attempt to index field 'steps' (a nil value)
FAIL: the dash unit's words and stop button :: bounds every line it draws
    test/test_ui.lua:1043: attempt to index field 'steps' (a nil value)
FAIL: the dash unit's words and stop button :: gives the stop button its three states and puts it in the socket
    test/test_ui.lua:1054: the button is round art on a square
    expected: "20"
    actual:   "48"
```
(The SelfTest guard test was not yet written at this point — it was added
after `Dash.lua` was fixed, along with its own RED/GREEN cycle documented
below.)

GREEN, after implementing `Dash.lua`:
```
0
250 passed, 0 failed
```

SelfTest guard test RED/GREEN (proof the guard matters, done as a scripted
before/after, not left in the tree):
1. Temporarily changed `SelfTest.lua`'s guard from
   `type(part) == "table" and part.file` to `type(part) == "table"`.
2. Ran the suite:
   ```
   1
   249 passed, 1 failed
   FAIL: SelfTest.lua without generated art :: leaves a malformed Data.Art entry out of the texture list instead of crashing
       test/test_ui.lua:1141: GoblinPS/SelfTest.lua:33: attempt to concatenate field 'file' (a nil value), got "false"
   ```
   This is the exact failure mode the guard's own comment describes: a
   malformed entry crashing the whole run via `MEDIA .. ns.Data.Art[name].file`,
   not just failing one assertion.
3. Restored the guard (`git diff GoblinPS/SelfTest.lua` is empty — confirmed
   after restoring) and re-ran: `250 passed, 0 failed`.

## Where the stop button ends up, in pixels, and why

`ns.Data.ArtGeometry.stop = { cx = 0.836914, cy = 0.170313, r = 0.0478516 }`.
`Dash.SIZE = { 232, 290 }`, so `f:GetWidth()` is 232 in the client.

- Diameter: `side = f:GetWidth() * g.stop.r * 2 = 232 * 0.0478516 * 2 ≈ 22.2px`
  square (`stop:SetSize(side, side)`).
- Centre: `stop:SetPoint("CENTER", f, "TOPLEFT", g.stop.cx * f:GetWidth(), -g.stop.cy * f:GetHeight())`
  → `x ≈ 232 * 0.836914 ≈ 194.2px`, `y ≈ -(290 * 0.170313) ≈ -49.4px` from the
  frame's top-left corner. That places the button's centre a little left of
  the top-right corner and about a sixth of the way down — the top-right
  region the artist's notes describe (button sprite box `(801, 162, 913,
  274)` on the 1024x1280 canvas, i.e. `cx ≈ 857/1024 ≈ 0.837`, `cy ≈ 218/1280
  ≈ 0.170`, matching the geometry table almost exactly).
- This replaces the first design's placeholder (`BOTTOM, 0, PAD`, which was
  bottom-centre) entirely for the geometry-present path; `PAD` itself is
  gone from the file (see Deviation 1).

## How the banner survives, and where it now appears

Unchanged timing, per the brief's warning: `Dash.Tick` (line ~373) still
clears `state.banner` and calls `Dash.Refresh()` at the very top, before
evaluating the tick's verdict — so the banner is visible for exactly the
tick it was set on and never persists into the next one. `Dash.Refresh`
(lines 60-85) now writes the banner to `ui.steps[1]` and blanks
`ui.steps[2]`/`ui.steps[3]` instead of writing it to `ui.next`, so
"Recalculating..." reads as a single message across what was the two-line
step/next area, with no stale directions showing underneath it. Verified by
the re-pointed test "shows Recalculating for the tick a stray is caught, and
lets it go on the next one" (now reads `ui.steps[1]`), which passes.

## Tests re-pointed (old field → new field)

| Test | Old read | New read |
|---|---|---|
| "opens on Start and shows the first step and the one after" | `ui.step`, `ui.next` | `ui.steps[1]`, `ui.steps[2]` (text changed, see Deviation 2) |
| "says nothing follows the last step" | `ui.step`, `ui.next` | `ui.steps[1]`, `ui.steps[2]`, `ui.steps[3]` (added) |
| "gives the step line room to wrap..." | `ui.step.wordWrap`, `ui.next.wordWrap` | replaced with a new truncation + box-position test (see below) |
| "every line of text is bounded" | `{ "step", "next", "distance", "eta" }` | `{ "destination", "distance", "eta" }` + `ui.steps[1..3]` |
| "advances when you reach the step's target" | `ui.step` | `ui.steps[1]` |
| "says Arrived and stops at the end" | `ui.step` | `ui.steps[1]` |
| "finishes the trip when a recalculation finds nothing left to plan" | `ui.step` | `ui.steps[1]` |
| "shows Recalculating for the tick a stray is caught..." (x2) | `ui.next` | `ui.steps[1]` |
| "keeps a working device when a texture will not load" | `ui.step` | `ui.steps[1]` |

## The three fallback comments added (item 2)

1. `Dash.lua`, dial centre fallback (`{ x = 0.5, y = 0.4 }`): "The `or` half
   of this is only reached when the generated geometry is absent: a rough
   guess at the dial's centre, not a coordinate from the art."
2. `Dash.lua`, compass share fallback (`0.55`): "0.55 is only reached when
   the generated geometry is absent: a rough guess at the compass's share of
   the device, not a measured fraction."
3. `Dash.lua`, arrow share fallback (`0.45`): "0.45 is only reached when the
   generated geometry is absent: a rough guess at the arrow's share of the
   device, not a measured fraction."

A fourth fallback comment was added for a literal I introduced myself (item
2's "do the same for any fallback literal you add"): the stop button's
geometry-absent branch (`stop:SetSize(20, 20); stop:SetPoint("TOPRIGHT", -8,
-8)`), marked "Only reached when the generated geometry is absent: a small
placeholder square in a corner, not a position from the art."

## The new SelfTest guard test

`test/test_ui.lua`, inside `"SelfTest.lua without generated art"`:
`"leaves a malformed Data.Art entry out of the texture list instead of
crashing"`. It mutates the real `ns.Data.Art` (adding a `.file`-less table
under key `malformed`), loads a private `SelfTest` copy against a namespace
sharing that same `Data` table (so `shippedArt()` sees the real generated
art plus the bad entry), asserts the load succeeds, asserts no path in
`TEXTURES` matches `"malformed"`, asserts `dash2-housing` is still present
(sanity that the guard isn't just skipping everything), and unconditionally
clears `ns.Data.Art.malformed` before re-raising any assertion failure via
`h.truthy(ok, err)`. Proof it catches a regression: see the RED/GREEN
section above — removing the `part.file` half of the guard reproduces the
exact crash the guard's own comment warns about
(`attempt to concatenate field 'file' (a nil value)`).

## Deviations from the brief, and why

**Deviation 1 — PAD.** The brief's own Step 3 code for the geometry-absent
fallback keeps `stop:SetPoint("TOPRIGHT", -PAD, -PAD)`. The task's item 1
explicitly says "PAD is no longer used for the button." Since PAD's only use
anywhere in `Dash.lua` was the button, keeping it in the fallback branch
would (a) contradict that instruction and (b) still leave a barely-used
constant whose sole remaining purpose is a corner case that is never
exercised in game (the generated geometry is always present in the shipped
addon). I removed `local PAD = 8` entirely and replaced the fallback's
offsets with an explicit, commented fallback literal (`-8, -8`), consistent
with item 2's treatment of every other fallback constant in the file.

**Deviation 2 — the "then " prefix.** The brief says for Step 4's
re-pointing: "change the read, never the assertion." But the pre-existing
test "opens on Start and shows the first step and the one after" asserted
`ui.next:GetText() == "then Zeppelin to East Dock"`. The new design's
`Dash.Refresh` writes `ui.steps[2]` as plain `stepText(...)`, with no "then "
prefix — matching the brief's own Step 1 test ("shows the step you are on
and the next two"), which expects `"Zeppelin to East Dock"` with no prefix.
Applying "change the read, never the assertion" literally here would have
produced a test asserting text the new code never writes, which would fail
regardless of field name — this is a case, beyond the two the brief names
(the wrap test and the fallback-helper test), that needed more than a
rename. I dropped the stale "then " to match the new panel's actual output
and the sibling test the brief itself specifies.

**Deviation 3 — the `place()` helper had been deleted, not just left
unused.** The brief's interfaces section says Task 3 "consumes... `ui.place`"
from Task 2, implying a `place` helper already existed. It did, briefly, but
was removed in commit `13b5b5e` ("Fix round 1: exact art aspect ratio, drop
the unused place() helper") because nothing called it yet. I re-added it
verbatim (same signature and body it had before removal), now genuinely used
by six call sites, so no `luacheck: ignore` comment is needed this time.

## Final Lua count and linters

```
0
250 passed, 0 failed
```

luacheck (PowerShell, `GoblinPS test tools --no-color --no-cache`):
```
Total: 0 warnings / 0 errors in 39 files
```

lua-language-server (`--check D:\goblinps --checklevel=Warning`):
```
Diagnosis completed, no problems found
[]
```

## Not done / out of scope

Nothing was left undone from the brief. `GoblinPS/Trip.lua`, `tools/`,
`images/parts/` and `GoblinPS/Media/` were not touched. `AGENTS.md` remains
untracked and was not staged. No commit has been pushed.

## Fix round 1

### Finding 1 — geometry-absent fallback had no anchors at all

**Root cause.** `destination`, `distance`, `steps[1..3]` and `eta` were each
placed only inside `if g then place(...) end`. Unlike the compass, the
arrow, the dial centre and the stop button — every one of which has a
commented `else` — these six had no `else` at all, so with the generated
geometry missing they were created, given text, and never anchored.
`SetText` never checks anchors, so nothing raised; the fake's `points` table
simply stayed empty, and in the real client a region with zero anchors does
not draw. This was a genuine regression: the code these six replaced (the
old `distance`/`eta`/`step`/`following` FontStrings from the first design)
anchored unconditionally, with no dependency on `g` at all.

**Fallback layout chosen.** A single unconditional vertical stack down
`content`, each line's `TOPLEFT`/`TOPRIGHT` anchored to the line above's
`BOTTOMLEFT`/`BOTTOMRIGHT` (the first line to `content` itself), in reading
order: `destination`, `distance`, `steps[1]`, `steps[2]`, `steps[3]`, `eta`.
No attempt at prettiness or centring on any particular part of the frame —
the geometry is always present in the shipped addon (it is generated by
`tools/build_graph.py` before the addon ever loads in game), so this path
only matters for a desktop test or a build gone missing, and the existing
standard for every other fallback in this file is legibility, not polish.
Each `else` is commented as geometry-absent-only, matching the style of the
four fallback comments already in the file (`GoblinPS/Dash.lua`, three
`if g then ... else ... end` blocks, roughly lines 196-243 after this fix).

**Anchor counts, before and after, with the geometry absent** (from the new
test, built via a fresh `Dash.lua` load with `ns.Data.Art` and
`ns.Data.ArtGeometry` both `nil`):

| Region | Points before fix | Points after fix |
|---|---|---|
| `destination` | 0 | 2 |
| `distance` | 0 | 2 |
| `steps[1]` | 0 | 2 |
| `steps[2]` | 0 | 2 |
| `steps[3]` | 0 | 2 |
| `eta` | 0 | 2 |
| `stop` (unchanged, already had a fallback) | 1 (`SetPoint("TOPRIGHT", ...)`) | 1 |

**New test.** `test/test_ui.lua`, in `"the dash unit's words and stop
button"`: `"keeps the text legible when the generated geometry is absent"`.
It saves and nils `ns.Data.Art`/`ns.Data.ArtGeometry` on the real shared
`ns` (so `freshDash()`'s build genuinely takes the `else` branches — Dash
depends on `ns.Widgets`/`ns.Core`/`ns.API`/etc. too heavily to build a fully
isolated namespace the way the SelfTest test does), builds a fresh Dash,
and asserts `#points >= 2` for all six lines, the same check the "bounds
every line it draws" test already uses. The body runs inside `pcall`, and
both the plan-level `Dash.Stop()` cleanup and the `ns.Data.Art`/
`ns.Data.ArtGeometry` restore happen unconditionally, with the result
re-raised via `h.truthy(ok, err)` — per Finding 2's pattern, applied here
too even though it wasn't named for this test specifically.

RED, reproduced by checking out the pre-fix `Dash.lua` (from the commit this
review is on) and running the suite with the new test already in place:
```
1
250 passed, 1 failed
FAIL: the dash unit's words and stop button :: keeps the text legible when the generated geometry is absent
    test/test_ui.lua:1112: test/test_ui.lua:1107: line 1 needs two anchors even with no generated geometry, got "false", got "false"
```
GREEN after restoring the fix:
```
0
251 passed, 0 failed
```

### Finding 2 — unguarded restores in the missing-texture tests

Lifted a small helper, `withMissingTexture(path, fn)` (`test/test_ui.lua`,
defined next to `freshDash()`), that sets `Fake.missingTextures[path] =
true`, runs `fn` inside `pcall`, clears the flag unconditionally, and
re-raises via `h.truthy(ok, err)` — the same shape as the `where`-fixture
restores already used by "backs off after a replan finds no route" and
"shows Recalculating for the tick a stray is caught...". Converted all
three tests that set `Fake.missingTextures` with a bare final-line restore
to use it:

- `"keeps a working device when a texture will not load"` (dash2-housing)
- `"keeps the flat placeholder when the arrow's own texture will not load"` (arrow)
- `"keeps a usable button when its art will not load"` (mine, from this task)

Each test's body (the fresh Dash build and its assertions) now runs inside
the helper's `pcall`; only the `Dash.Stop()` cleanup in the button test
(unrelated to the texture flag, and non-raising) stays outside it. No other
`Fake.missingTextures` mutation with a bare restore remained in
`test/test_ui.lua` outside these three and the unrelated `"fails when a
texture cannot load"` SelfTest test, which the finding did not name and
which this round left untouched (different fixture, different failure
mode — it restores `Fake.missingTextures[badPath]` between two
already-passing `SlashCmdList` calls, not around assertions that can
themselves raise).

### Final state after round 1

```
0
251 passed, 0 failed
```
luacheck: `Total: 0 warnings / 0 errors in 39 files`
lua-language-server: `Diagnosis completed, no problems found`, `[]`

No regression from the 250/0/0 this round started from; net +1 test (the
new geometry-absent-anchors test).

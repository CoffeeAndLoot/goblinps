# Task 3 report: one search box, wide only, no step list

**Status:** DONE_WITH_CONCERNS (all gates green; concerns below are small)
**Commit:** `f6e2cdc` Planner: one search box, wide only, no step list

## What was done

1. **Art regenerated.** `python tools/make_art.py`: "43 textures, 6.27 MB total",
   15 new strip `.tga` files, `Data/Art.lua` now has `ArtGeometry.planner` =
   `{ strip, wide }` only. No existing texture changed bytes. `git rm
   GoblinPS/Media/planner-frame-tall.tga`.
2. **Layout preference dropped.** `Prefs.lua`: `LAYOUTS` and
   `Prefs.ToggleLayout` gone; `Prefs.Init` sets `db.layout = nil` with the
   brief's comment. `Core.lua`: `Core.Layout`/`Core.ToggleLayout` gone; the
   hearth line now says "press Start Route again". `test_prefs.lua` updated as
   specified; `Prefs.ToggleLayout` block deleted.
3. **`Planner.lua` rewritten** to the brief: `Planner.SIZE = { 650, 416 }`,
   `ApplyLayout()` with no argument, `geo()` answers `planner.wide`, one search
   box, no From/Here/layout button/side panel/rows/device watermark/`fromSlice`,
   four status/footer lines on the screen placed from `notesLine`,
   `knownLine`, `totalLine`, `hintLine`, "Start Route" button (120x24) on
   `content`, results rows call `pick(self.item)`, `ui` table exactly as given.
   Unchanged blocks carried over verbatim.
4. **`test_ui.lua` updated** test by test as the brief lists, plus the two new
   tests at the end of the planner block; the ground-steps block renamed
   "ground steps in chat" and cut to the chat test.

## RED / GREEN evidence

Lua suite command (from context.md), after Step 1 only:

```
309 passed, 15 failed
FAIL: the planner window :: opens from the slash command with both layouts' widgets built once
    GoblinPS/Widgets.lua:80: attempt to index local 'rect' (a nil value)
FAIL: the planner window :: keeps the window at the art's exact aspect ratio
... (15 planner tests, all from the missing old geometry keys)
```

After Steps 2-4, first run:

```
314 passed, 2 failed
FAIL: ... covers the screen with the backdrop without distorting it
    2.5:1 scenery in a wider-than-tall-but-not-2.5 opening loses width, got "false"
FAIL: ... crops the backdrop by the shipped canvas's aspect, not the master PNG's
    trimmed span must match the shipped canvas's aspect: got 1, wanted 1.3176...
```

(see Deviation 1), then final:

```
316 passed, 0 failed
python -m unittest discover -s test/tools   -> Ran 55 tests ... OK
python tools/check_art.py                    -> 47 pass, 0 with problems, 0 not drawn yet
luacheck (PowerShell)                        -> Total: 0 warnings / 0 errors in 40 files
lua-language-server (PowerShell)             -> Diagnosis completed, no problems found
```

Count: 324 - 10 removed (5 planner, 4 ground-step row tests, 1 ToggleLayout;
"repairs a layout" was replaced one-for-one) + 2 new = **316**. The brief's
"about 312" over-counted the deletions.

## Files changed

- `D:\goblinps\GoblinPS\Planner.lua` (rewritten)
- `D:\goblinps\GoblinPS\Prefs.lua`, `D:\goblinps\GoblinPS\Core.lua`
- `D:\goblinps\GoblinPS\Data\Art.lua` (regenerated), `D:\goblinps\GoblinPS\Media\*.tga`
  (15 added, `planner-frame-tall.tga` deleted)
- `D:\goblinps\test\test_ui.lua`, `D:\goblinps\test\test_prefs.lua`

## Deviations from the brief

1. **Backdrop crop tests flipped from width to height.** The mockup's screen
   opening is 524x159 px (aspect 3.29), wider than the 2.4976:1 scenery, so
   `coverCrop` (unchanged, and correct) now trims top and bottom and keeps the
   full width. The two tests asserted a width trim, true only of the old
   opening. Kept their intent, changed the axis: "covers the screen..." now
   asserts full width kept, t/b inside the padding crop, centred top/bottom,
   and height lost; "crops the backdrop by the shipped canvas's aspect..."
   asserts the opening is wider than the art and compares `b - t` against
   `tall * (partAspect / boxAspect)`. Its comment's figures updated: the
   master-PNG mistake would now trim about 3% of the art off top and bottom
   instead of about 12% (computed, not guessed).
2. **Leftover grep is not empty, and can't be.** It prints only four lines, all
   in the brief's own mandated test "is the mockup: no From, no Here..."
   (`h.eq(ui.fromBox, nil)`, `ui.layoutButton`, `Planner.MAX_ROWS`,
   `ns.Core.Layout`), which asserts those names are gone. There are no
   leftovers in `GoblinPS/` or elsewhere in `test/`. I didn't obfuscate the
   test to get past the grep.
3. **Two language-server fixes the brief's code needed.**
   - `Planner.Refresh`: `if routed then` became `if plan and routed then`.
     LLS can't narrow `plan` through `routed`, so it reported need-check-nil
     and undefined-field on `plan.result`/`plan.hint`. No change in behaviour
     (`routed` implies `plan`).
   - The new test's stub `ns.Dash.Destination = function() return nil end`
     widened the function's inferred type, so LLS flagged an old line at
     `test_ui.lua` ("resumes this character's saved trip at login"):
     `ns.Dash.Destination() and ns.Dash.Destination().name`. Rewrote it as
     `local trip = ns.Dash.Destination()` / `h.eq(trip and trip.name, "Delta")`
     (one call, narrowed). No diagnostic suppressed.
4. **Small comment wording.** `boundingBox()`'s comment: removing only "in this
   layout's" leaves broken grammar, so it reads "every placed area in the
   geometry" (re-wrapped). The frameArt comment was re-wrapped around the new
   wording. The "place every input..." test's comment now says "status and
   footer lines", since it covers four lines now, not two.

## Concerns

- `coverCrop()`'s comment (kept word for word, as the brief says) still says
  "Losing its sides is intended". In the mockup geometry it loses top and
  bottom. That's worth one word changing in Task 4 or later.
- `test/fake_frames.lua:44` gives `results.owner` as an example of
  instance data. That field no longer exists. It's harmless, but the example
  is out of date.
- Nothing here is verified in game. The layout is correct in source against
  the new geometry, and that's all.

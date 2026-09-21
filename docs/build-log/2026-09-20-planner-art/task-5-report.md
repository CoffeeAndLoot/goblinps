# Task 5 report: Inputs, screen, side panel and footer

## Status: DONE

(Status at first submission was DONE_WITH_CONCERNS; see the "Fix report"
appended at the bottom for the coordinator's rulings and the resulting
changes. Both required fixes are in; concerns 1 and 4 needed no action per
the coordinator.)

## Commit
- `334eeb2` "The planner's inputs, screen, panel and footer, from the geometry"
  (branch `planner-art`, not pushed). Files: `GoblinPS/Planner.lua`,
  `GoblinPS/Widgets.lua`, `GoblinPS/GoblinPS.toc`, `test/test_ui.lua`,
  `test/fake_frames.lua`. `AGENTS.md` was left untouched and unstaged.

## What was built

- `Widgets.Stretch3(parent, name, capFraction, capAspect)` in
  `GoblinPS/Widgets.lua`, exactly as specified: draws a left cap, a
  stretched middle and a right cap from one part, returns `nil` (not a
  half-built table) when the part is missing or a piece's texture fails
  to load.
- `coverCrop(texture, part, partW, partH, boxW, boxH)` in `Planner.lua`,
  above `ApplyLayout`: covers a rect with `screen-backdrop`'s 2.5:1
  scenery, cropping a centred slice out of the part's own `l..r`/`t..b`
  padding-crop rather than out of raw `0..1`.
- `build()` now creates `backdrop` (the scenery insert) and `panelArt`
  (the tiled `planner-panel` backing) on `artLayer`, both falling back to
  `Hide()`/`nil` when their art is absent, per the existing "art over
  colours" convention.
- `screen`, `side` and `results` now parent to `content` instead of `f`;
  `fromBox`, `toBox`, `here` and `layoutButton` now parent to `content`
  too (previously `f`). Every hand-placed `SetPoint` on `fromBox`, `toBox`,
  `here`, `go`, `hint` and `total` was deleted; `ApplyLayout`'s existing
  `if g then ... end` block (Task 4's chrome block) now also places
  `fromBox`, `toBox`, `here`, `results`, `screen`, `side`, `go` (all
  `PlaceRect`), `total`/`hint` (`PlaceLine`), `panelArt` and `backdrop`
  (both at `g.screen`, with `backdrop` additionally cover-cropped). No
  second `if g then` block was opened.
- The two edit boxes get `input-box` three-slice art (`CAP, CAP_ASPECT =
  0.18, 184/128`, verbatim from the brief). The brief's prose also called
  for three-slice art on "the three buttons"; I extended the same
  `Stretch3` call (`0.25, 1.0`, the exact numbers the brief's own widget
  test uses for the `button` part) to `here`, `go` and `layoutButton`, on
  top of their existing flat/colour fallback. **See concern below.**
- `PAD`, `HEADER`, `FOOTER` deleted (no longer read anywhere); `ROW`,
  `STEP_ROW` kept (they still lay out rows inside `side` and `results`,
  which the geometry doesn't describe).
- `showResults` no longer re-anchors/resizes `ui.results` under the
  focused box; it only fills rows, sets `.owner` and calls `Show()`.
  `ApplyLayout` is now the sole owner of where the results list sits.
- `GoblinPS.toc` version bumped to `2026.09.21`.
- Two-additions-beyond-the-brief, both done:
  1. `layoutButton` now built as `W.Button(content, ...)` instead of
     `W.Button(f, ...)` (was sitting at the same frame level as
     `artLayer`).
  2. A new test ("keeps a working window when one named texture will not
     load") fails only `screen-backdrop` via `Fake.missingTextures`,
     confirms the window still builds, `ui.backdrop` is `nil`, and typing
     in `toBox` still opens the results list. The fixture is restored
     immediately after.
- `test/fake_frames.lua`: added `SetHorizTile`/`SetVertTile` to the
  allow-listed no-ops. This file wasn't in the brief's file list, but
  `planner-panel`'s tiling code calls both real methods and the fake's
  strict unknown-method check raised on them (`^%u` names not modelled or
  allow-listed error out) — without this the suite cannot run at all with
  the new code in place.

## Tests added (`test/test_ui.lua`, all inside "the planner window")

All four from Step 1, both from Step 6, plus the per-texture fallback
test from the "two additions" — seven `h.it` blocks total. One deliberate
deviation: the brief's "drops the results list..." test typed
`"Orgrimmar"` into `toBox`, which does not exist in `test/fake_world.lua`'s
fixture (Westland/Eastland/Isle/Northland/Lostland, Alpha..Hotel); as
written it would return zero search results and `hideResults()` would
fire, failing the very assertion that follows. I changed it to
`Fake.Type(ui.toBox, "delt")` (the existing "Delta" fixture, matching
every other search test in this file) — same behaviour under test, a
fixture that actually exists.

The new per-texture-fallback test loads a second `Planner` module via
`loadfile` (mirroring the dash's `freshDash()` pattern), because `build()`
only runs once per module instance. Unlike the dash's tests (which run
last in the file, so nothing downstream reads `ns.Dash` again), this
planner test sits mid-file — later describes (`the minimap button and the
compartment`, `/gps selftest`, `/gps to still prints a route in chat`)
reach the planner through `ns.Planner` directly (`Core.lua`,
`MinimapButton.lua`), and `loadfile("GoblinPS/Planner.lua")(...)`
reassigns `ns.Planner` as a side effect. I save `ns.Planner` before the
load and restore it immediately after, driving the fresh copy only
through its own local variable, so no later test's shared state moves.

I also added one setup line (`Fake.Click(ui.here)`) at the end of the
"drops the results list..." test to leave the results list closed before
the dropdown test runs — without it, the dropdown test's first click
would toggle an already-open list closed instead of open, since the
brief's given tests assume a clean starting state that the preceding test
(also newly added) leaves dirty.

## Gates run

- Lua suite: **274 passed, 0 failed** (baseline 267 + 7 new tests).
- `python -m unittest discover -s test/tools`: **42 passed**, matches
  baseline.
- `python tools/check_art.py`: **47 pass, 0 with problems, 0 not drawn
  yet**, matches baseline.
- luacheck (PowerShell, per instructions): **0 warnings, 38 files**. (Had
  to fix a `part` shadow in `Planner.lua`'s `ApplyLayout` and two unused
  locals `t, b` in the new backdrop test before this was clean.)
- lua-language-server `--check` (PowerShell): **"Diagnosis completed, no
  problems found"**, exit 0.

## Step 8 (prove the fallback outside the repo) — concern, not silently passed

I copied `GoblinPS/`, `test/` and `tools/` to a scratch directory under
the system temp dir (outside `D:\goblinps`), deleted
`GoblinPS/Data/Art.lua` there, and ran the Lua suite.

**Literally as instructed, this does not run at all**:
`test/test_ui.lua` line 18 is `assert(loadfile("GoblinPS/Data/Art.lua"))("GoblinPS", ns)`
— a hard assert, by design (its own comment: "Data/Art.lua is generated,
real game data ... not a fixture to fake"). With the file gone, `loadfile`
returns `nil`, `assert` raises, and the whole suite aborts before a single
test runs.

To get past that and actually exercise the production fallback code, I
made one change **only in the scratch copy** (never touched anything
under `D:\goblinps`): replaced the hard assert with
`local artChunk = loadfile(...); if artChunk then artChunk(...) end` —
which is what a real WoW client does with a `.toc`-listed file that isn't
on disk (skip it, keep loading everything else), rather than what Lua's
`loadfile`/`assert` combination does (hard error).

With that one change, the scratch suite runs: **253 passed, 21 failed**.
Every one of the 21 failures is a **pre-existing test from earlier tasks**
that asserts a real value out of the generated geometry/art tables —
window aspect ratio from `g.canvas`, dash layer positions from
`ns.Data.ArtGeometry`, `ns.Data.Art["dash2-*"]` texture coordinates, and
so on. None of them are about resilience; they're about correctness of
real, shipped numbers, and they have nothing to do with Task 5. Critically,
**none of the tests that exist specifically to prove the missing-art
fallback failed** — "keeps working when not one texture loads", "keeps a
working window when one named texture will not load", and every other
`ns.Data.Art and ...`-guarded path all passed, in the scratch copy, with
the real file physically gone.

So: the production code's fallback guards are proven — a window with no
`Data/Art.lua` at all still builds, lays out and stays usable. What is
**not** true is the brief's literal expectation of "green, the whole
suite" straight off `git rm`'d `Data/Art.lua` with zero other changes —
that would require either accepting the test-bootstrap tolerance change
above, or rewriting dozens of unrelated, already-passing, already-reviewed
tests from earlier plans to skip their real-value assertions when art is
absent. I did neither in the repo; I'm reporting the actual result instead
of asserting a green run that didn't happen. The scratch copy (with my
one-line bootstrap tolerance) was deleted afterward; nothing under
`D:\goblinps` was touched for this step.

## Other concerns for the reviewer

- **`W.Stretch3` wired onto `here`/`go`/`layoutButton`, not just the two
  edit boxes.** The brief's prose says "Give the two edit boxes and the
  three buttons their three-slice art," but the code sample that follows
  only shows the two edit boxes, and the later "Add to the `ui` table"
  line lists only `fromSlice`/`toSlice` — no button slices. I implemented
  the buttons anyway (using `0.25, 1.0`, the exact numbers the brief's own
  `W.Stretch3(f, "button", 0.25, 1.0)` widget test uses), since the design
  rationale at the top of the brief explicitly justifies `Stretch3` by
  citing Here (65px) and GO (135px) on the same `button` part. **Trade-off
  I noticed and did not resolve**: `Widgets.Button` colours `b.face`
  (BORDER layer) for `SetButtonEnabled`'s grey-out, and `Stretch3`'s three
  pieces sit on the ARTWORK layer, above BORDER. Once real `button.png`
  art loads in the client, it will sit opaque over `b.face`, so GO's
  enabled/disabled colour change (used in `Refresh()` when there are no
  route steps) would stop being visible — the button would still refuse
  clicks (`SetEnabled`), just without the visual cue, unless the art fails
  to load. Nothing in the test suite catches this (the fake doesn't model
  opacity/layer compositing), and the manual-test checklist additions in
  Task 6 don't ask anyone to check GO's disabled appearance either. Worth
  a decision: swap in `button-disabled` (already shipped, per
  `ns.Data.Art`) when `SetButtonEnabled(false)` is called, or accept the
  loss of that cue.
- **`panelArt` and `backdrop` are both placed at `g.screen`.** The brief's
  build() comment describes `panelArt` as "the side panel a backing," but
  its own `ApplyLayout` snippet places both at `g.screen`, not
  `g.sidePanel`. I followed the literal code (verbatim, as instructed)
  rather than the prose gloss: `panelArt` sits on `artLayer` at
  `g.screen`, under `backdrop`, on the theory that it's a fallback layer
  for the backdrop's own opening (visible only if `screen-backdrop`
  itself fails to load) rather than a `sidePanel` backing. No test pins
  `panelArt`'s rect either way, so this is worth a second look if "side
  panel a backing" was meant literally.
- The IDE/language-server diagnostics were not consulted for pass/fail
  (per the task instructions); only the CLI `lua-language-server --check`
  run above was used, and it agreed with luacheck (both clean).

## Summary

Lua suite 274/274, `test/tools` 42/42, `check_art.py` 47/0/0, luacheck
0 warnings/38 files, lua-language-server 0 problems. Step 8's fallback is
real and proven for the production code, but not literally "whole-suite
green" without a scratch-only test-bootstrap tolerance, for reasons
explained above — flagging as DONE_WITH_CONCERNS rather than DONE so the
button-layering and `panelArt` placement questions get eyes before this
merges.

---

## Fix report (second pass)

Rulings received: concerns 1 and 4 accepted with no action; concerns 2
and 3 required code. Both are done, in commit `9c39c01` "Fix review
findings: GO's disabled cue and the panel backing's placement" on
`planner-art` (not pushed). Files: `GoblinPS/Planner.lua`,
`GoblinPS/Widgets.lua`, `test/test_ui.lua`. `AGENTS.md` again left
untouched/unstaged.

### Concern 2: GO's disabled cue (fixed)

- `Widgets.Stretch3` now stores `{ left, middle, right, capFraction, name }`
  as `parent.slice` (same table it already returned; every existing call
  site is unaffected whether or not it kept the return value).
- Added a local `reslice(slice, part)` in `Widgets.lua`, used only by
  `SetButtonEnabled`: repoints the three pieces at a different part,
  recomputing the same `capFraction` crop against the new part's own
  `l`/`r`/`t`/`b`. If `part` is `nil` or any of the three `SetTexture`
  calls fails, it restores each piece's previous texture path before
  returning `false` — necessary because the fake (and, per its own
  comment, the real client) blanks a texture region on a failed
  `SetTexture` rather than leaving the old picture in place, so "do
  nothing on failure" required an explicit revert, not just skipping the
  `SetTexCoord` calls.
- `Widgets.SetButtonEnabled` keeps tinting `button.face` exactly as
  before (the fallback when no art loaded), and now also calls
  `reslice(button.slice, ns.Data.Art and ns.Data.Art[enabled and slice.name
  or slice.name .. "-disabled"])` when `button.slice` exists. `go`,
  `here` and `layoutButton` all get this for free — they were already
  calling `W.Stretch3(..., "button", ...)` in `Planner.lua`, so
  `.slice` is populated on all three without touching `Planner.lua` again.
- Two new tests in `test/test_ui.lua`, right after "gives a stretched
  control fixed end caps": one disables then re-enables a sliced button
  and asserts all three pieces' `GetTexture()` paths swap to
  `button-disabled`'s file and back to `button`'s; the other marks
  `button-disabled`'s path missing via `Fake.missingTextures`, disables
  the button, and asserts the pieces still show the enabled texture
  (proving the revert-on-failure path, not just the happy path).

### Concern 3: `panelArt` placement (fixed)

- Added `boundingBox(g)` next to `coverCrop` in `Planner.lua`: unions
  every key in the layout's geometry table that has a `left` field (so
  every rect: `fromBox`, `toBox`, `hereButton`, `goButton`, `totalLine`,
  `hintLine`, `screen`, `sidePanel`, `resultsList`, `stripTrack`,
  `titlePlate`, `taglinePlate`, `layoutButton`), skipping `canvas`
  (pixels, not a fraction) by name and skipping the three circle keys
  (`closeButton`, `gearButton`, `dropdownButton`) implicitly, since they
  have `cx`/`cy`/`r` instead of `left`.
- `ApplyLayout` now calls `W.PlaceRect(ui.panelArt, f, boundingBox(g))`
  instead of `W.PlaceRect(ui.panelArt, f, g.screen)`.
- Replaced the placeholder assumption with a real test: "tiles the panel
  backing behind every opening, not just the screen" reads
  `ui.panelArt.points` back into left/top/right/bottom fractions and
  asserts the covered rect contains both `g.screen` and `g.sidePanel` in
  full (not an exact match to either).

### Gates re-run after the fix (all from a fresh run, all green)

- Lua suite:
  ```
  python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
  ```
  Output: `277 passed, 0 failed` (274 + 3 new tests: the two button-slice
  tests and the panel-backing bounding-box test).
- `test/tools`:
  ```
  python -m unittest discover -s test/tools
  ```
  Output: `Ran 42 tests in 0.215s` / `OK`.
- Art checker:
  ```
  python tools/check_art.py
  ```
  Output: `47 pass, 0 with problems, 0 not drawn yet`.
- luacheck (PowerShell):
  ```powershell
  $env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
  $env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
  lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
  ```
  Output: `Total: 0 warnings / 0 errors in 38 files`.
- lua-language-server (PowerShell):
  ```powershell
  lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=<scratchpad>\lls-check-fix.json
  ```
  Output: `Diagnosis completed, no problems found`, exit `0`.

### Housekeeping note

Confirmed: no `goblinps-fallback-check-*` (or any other) scratch copy
remained in the system temp directory before or after this pass — checked
explicitly this time rather than trusting my own earlier `rm -rf`'s exit
status alone.

---

## Fix report (round 2 — review findings)

Review came back spec-compliant with one Important and three Minors. All
four are fixed, in commit `b3272b1` "Fix review findings round 1:
coverCrop's coordinate domain, and three minors" on `planner-art` (not
pushed, on top of `9c39c01`). Files: `GoblinPS/Data/Art.lua`,
`GoblinPS/Planner.lua`, `GoblinPS/Widgets.lua`, `test/test_ui.lua`,
`tools/make_art.py`. `AGENTS.md` again untouched/unstaged.

### Important: `coverCrop`'s wrong coordinate domain (fixed)

- `tools/make_art.py`: `build_one` already computed `(cw, ch)` — the padded
  canvas's pixel size — for the trailing size comment; that value is now
  also written onto each part's `Art.lua` row as `cw`/`ch`, alongside
  `file`/`l`/`r`/`t`/`b`. Header comment updated to state the domain
  explicitly (`cw`/`ch` are the shipped canvas, not the master PNG).
- `coverCrop(texture, part, boxW, boxH)`: dropped the `partW`/`partH`
  parameters entirely; it now reads `part.cw`/`part.ch` itself, so no
  caller can hand it a wrong-domain size again. If `part.cw` or
  `part.ch` is missing, it returns immediately without touching the
  texture's existing texcoords (a missing field must not break the
  window).
- Call site in `ApplyLayout` updated to the new four-argument signature
  (dropped the hardcoded `1600, 640`).
- **Regenerated `Art.lua`** via `python tools/make_art.py`. Diff is
  exactly the `cw`/`ch` fields plus the header comment on every one of
  the 29 rows — no `l`/`r`/`t`/`b`/`file` value changed, and
  `ArtGeometry` is byte-identical. Confirmed via
  `git status --porcelain -- GoblinPS/Media GoblinPS/Data/Art.lua`
  that **no `.tga` under `GoblinPS/Media` changed** (git shows nothing
  for that path — a binary diff would appear if any of the 29, including
  the 16 planner parts, had). Re-ran `make_art.py` a second time after
  finishing all edits to confirm it's idempotent: identical output,
  nothing new to stage.

### The magnitude test, and proof it fails first

Added "crops the backdrop by the shipped canvas's aspect, not the master
PNG's" right after the existing centredness test. It computes the
expected trimmed span from `part.cw`/`part.ch` and the screen box's own
aspect, then asserts `ui.backdrop.texCoord`'s actual trimmed span matches
to within `0.001`.

To prove it actually catches the bug (not just "a test exists"): I
`git stash push -- GoblinPS/Planner.lua` to put `coverCrop` back to the
pre-fix, committed version (`partW=1600, partH=640` hardcoded, matching
exactly what shipped in `9c39c01`), ran the suite with the new test
already written against the regenerated `Art.lua`, and got:

```
FAIL: the planner window :: crops the backdrop by the shipped canvas's aspect, not the master PNG's
    test/test_ui.lua:466: trimmed span must match the shipped canvas's aspect: got 0.69340354772727, wanted 0.86675443465909, got "false"
```

`0.6934` is exactly the old code's trim (matching the reviewer's stated
"trims 15.33% per side" — `(1 - 0.6934)/2 = 0.1533`); `0.8668` is the
correct one (matching "trims 6.66% per side" —
`(1 - 0.8668)/2 = 0.0666`). Then `git stash pop` to restore the fix, and
re-ran: `278 passed, 0 failed`.

### Three Minors (all fixed)

1. `Widgets.lua`, `Stretch3`'s `piece()`: added `t:Hide()` before
   returning `nil` on a failed `SetTexture`, so a partially-failed
   three-slice never leaves an orphaned, unanchored texture region behind.
2. `Widgets.lua`, `reslice`: the three `SetTexture` calls are no longer
   `and`-chained (`okLeft = ...; okMiddle = ...; okRight = ...` then
   checked together) — unreachable today since all three pieces share one
   file path and so always succeed or fail together, but no longer silently
   skips the remaining pieces the day caps and middle come from different
   files.
3. `test/test_ui.lua`, "swaps a stretched button's art...": the
   re-enabled assertion now checks `slice.middle` and `slice.right` too,
   not just `slice.left`, matching the disabled-state assertion above it.

### Gates re-run after all fixes (all from a fresh run, all green)

- Lua suite:
  ```
  python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
  ```
  Output: `278 passed, 0 failed` (277 + 1 new magnitude test).
- `test/tools`:
  ```
  python -m unittest discover -s test/tools
  ```
  Output: `Ran 42 tests in 0.201s` / `OK`.
- Art checker:
  ```
  python tools/check_art.py
  ```
  Output: `47 pass, 0 with problems, 0 not drawn yet`.
- luacheck (PowerShell):
  ```powershell
  $env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
  $env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
  lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
  ```
  Output: `Total: 0 warnings / 0 errors in 38 files`.
- lua-language-server (PowerShell):
  ```powershell
  lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=<scratchpad>\lls-check-fix2.json
  ```
  Output: `Diagnosis completed, no problems found`, exit `0`.

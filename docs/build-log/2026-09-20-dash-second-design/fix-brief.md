# Fix wave — plan 5, the dash unit's second design

This is the **one and only** fix wave for this branch. Everything below must
land. Read `final-review.md` in this same directory for the full argument
behind each finding; this brief carries the rulings and the exact work.

Branch `dash-second-design`, BASE `0db3921`. Work in `D:\goblinps`.

## Ground rules that bind every change here

- **No coordinate may be hand-typed in `Dash.lua`.** Every position comes from
  `ns.Data.ArtGeometry`. `Dash.SIZE` is the single permitted exception and is
  ruled on below.
- Plain Lua 5.1, no libraries, **no Blizzard frame templates**, no secure code.
- `API.lua` is the only file allowed to call Blizzard game APIs. `Dash.lua` may
  touch `CreateFrame`, `UIParent` and `UISpecialFrames` only.
- Every FontString gets two horizontal anchors (or a width) and a decided
  wrap-or-truncate. All six truncate; keep it that way.
- Generated files are never hand-edited. `GoblinPS/Data/Art.lua` and
  `GoblinPS/Media/*.tga` come from `tools/make_art.py`. If you change the
  generator, re-run it; `git diff` on the generated files must reflect the
  regeneration and nothing else.
- Zero luacheck warnings, zero language-server warnings, **no lint
  suppression** anywhere.
- Do not touch `GoblinPS/Trip.lua`. Its diff on this branch is empty and must
  stay empty.
- Do not change plan-4 trip-loop assertions. If a test must read a different
  widget name, the read may move; the assertion may not.

## Gates — all must be green before you commit anything

```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
python -m unittest discover -s test/tools
python tools/check_art.py
python tools/make_art.py    # then: git diff --stat must show no unexpected churn
```

luacheck (PowerShell):

```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
$env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
```

Language server: `lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=<file.json>` (run against the repo root so `.luarc.json` loads).

Baseline to match or beat: **251 Lua tests, 36 Python tests, check_art 47/0/0,
luacheck 0 warnings in 39 files, language server clean.**

---

## Important 1 — the device's own brass rectangle is never hidden

`Dash.lua:102` builds the device frame with
`W.Panel(UIParent, "body", "brass", 3)`. `Widgets.Panel`
(`GoblinPS/Widgets.lua:36-45`) lays **two opaque textures** directly on that
frame: a `BACKGROUND` border fill and a `BORDER` inner fill, both covering the
full 232×290. `Widgets.Panel` returns only the frame, so neither texture is
reachable and nothing ever hides them.

Six lines below, `flat` — the artLayer fallback — *is* hidden the moment the
glass loads, with the comment *"It is a rectangle, so it goes the moment the
glass arrives, or it boxes in a round device."* The reasoning is right and the
frame's own panel violates it. Compositing all five shipped layers leaves
**39.65%** of the canvas fully transparent (bbox `(88,9)-(926,1246)`): roughly
20 device px of opaque brass down the left edge and 22 down the right. This is
the same class of fault as the in-game one fixed in `2d58322`.

**Ruling.** The device frame carries no art of its own. Build it bare and give
the no-art fallback its own hideable frame:

- `local f = CreateFrame("Frame", nil, UIParent)` — no `W.Panel`, no textures
  on `f`.
- Replace the current `flat = W.Fill(artLayer, "BACKGROUND", "screen")` with a
  fallback **frame**: `W.Panel(f, "body", "brass", 3)`, `SetAllPoints(f)`, at
  frame level `base` (below `artLayer`). Keep the name `flat` in the `ui`
  table so existing tests and the trip loop keep their handle, and keep the
  existing comment — it is now true of the thing it describes.
- Hide that fallback frame exactly where `flat:Hide()` is called today (when
  the glass texture loads). Hiding a frame hides its textures, which is the
  whole point of the change.

**Regression test** (add to the dash block in `test/test_ui.lua`): assert the
device frame itself has **no regions of its own** — no `CreateTexture` was
called on `f` — while the fallback frame exists and is hidden once the glass
loads. The fake tracks created regions per frame; if it does not expose them,
add that to the fake rather than weakening the assertion. The test must fail
against the current code. Verify that it does before you fix it.

---

## Important 2 — the text boxes versus the client's fonts

At `Dash.SIZE = {232, 290}` the artist's rects measure:

| rect | width | height |
|---|---|---|
| `destination_line` | 70.69 | **6.80** (10 px font) |
| `distance_line` | 52.56 | **5.89** (16 px font) |
| `steps_screen` | 118.04 | 51.20 → 17.07 per line |
| `eta_screen` | 56.41 | 15.41 |

**Ruling, part A — `place()` stops constraining height.** Read the artist's own
names: `destination_line` and `distance_line` are 30 and 26 px tall on a
1280-tall canvas. Those are *lines to sit on*, not boxes to fit in — the areas
are the two `_screen` rects, and they are sized like areas. Forcing a
FontString into a 6.8 px rect is our error, not the artist's.

So `place()` must anchor a FontString on the rect's **vertical centre line**,
not corner to corner:

- `LEFT` at `(rect.left * w, -(rect.top + rect.bottom) / 2 * h)` from the
  parent's `TOPLEFT`, and `RIGHT` at `(rect.right * w, <same y>)`.
- Two horizontal anchors, so the bounding rule still holds and truncation
  still works. The font decides the height, centred on the artist's line.

`place()` is also used for regions that genuinely are areas. Do **not** apply
the centre-line treatment to those by accident: give `place()` the corner-to-
corner behaviour for anything that is not a FontString, or add a separate
helper for lines and use the right one at each call site — your choice, but
say which you chose in the report, and make sure every call site gets the
behaviour its rect's name implies. The three step lines are lines; the ETA is
a line; the destination and distance are lines.

**Ruling, part B — the device grows to `{288, 360}`.** 232 was hand-typed and
is the one layout number not derived from the geometry. 288×360 is exactly
4:5, matching the art's 1024:1280, and brings each step line to 21.19 px and
the ETA plate to 19.12 px — comfortable for the client's 10 px fonts. Bump
the TOC version accordingly (`2026.09.20.4`).

Do **not** chase the 200 px step-line width that commit `5858643` recorded as
insufficient in a real client run. Truncation is this design's decided
behaviour, and long stop names get their room in the route strip (plan 6).
Note in the report that the device size is the one number still owed an
in-game look.

**Checklist line to add** under the dash section of
`docs/manual-test-checklist.md`:

```
- [ ] Every line of text sits on its opening and is legible: the destination,
      the yards, the three steps and the ETA. The device is 288x360; if a line
      is cramped or swims in its opening, that number is the one to change
```

---

## Important 3 — the fake mis-parses three-argument `SetPoint`

`test/fake_frames.lua:98-99`:

```lua
    elseif n == 3 then
        point, x, y = ...
```

Real `SetPoint` has two three-argument forms: `(point, x, y)` and
`(point, relativeTo, relativePoint)`. The fake assumes the first. This branch
is the first in the project to use the second — six times, in the
geometry-absent fallback — so the frame lands in `x`, the anchor string lands
in `y`, and `relativeTo` is lost entirely.

The consequence is worse than the parse: `test/test_ui.lua:1095-1112`, the
regression test added to close this branch's most serious finding, asserts only
that each region has **two anchors**. It passes on garbage.

**Fix both halves:**

1. Disambiguate by type in the fake. If the second argument is a number, it is
   `(point, x, y)`; otherwise it is `(point, relativeTo, relativePoint)`.
   Production code uses both forms — `Dash.lua:152` is a genuine
   `(point, x, y)` — so neither may regress. Check the `n == 4` branch against
   the same reasoning while you are there.
2. Strengthen `test/test_ui.lua:1095-1112` so it asserts each anchor's
   **target and relative point**, not just the count. With the geometry absent,
   every text region must be anchored to a real frame at a named point. The
   strengthened test must fail against the unfixed fake. Verify that it does.

This is the **fifth** method found hiding in that fake's accepted-and-ignored
list, after `SetTexCoord`, `SetFrameLevel`, `SetWordWrap` and `SetAllPoints`.
While you are in there, note in your report anything else on that list that
silently swallows a distinction our code depends on.

---

## Minor findings — all eight land in this wave

1. **`state.banner` outlives the trip that set it.** `Dash.Start`
   (`Dash.lua:339`) resets `plan`, `index` and `best` but not `banner`. A
   second `Start` before the next tick shows the old trip's banner with all
   three step lines blanked. Pre-existing, but the blast radius grew: the old
   design put the banner in the secondary line. Add `banner` to that reset.

2. **`art()`'s `pad` parameter is dead and holds the branch's only uncommented
   layout literals.** Declared at `Dash.lua:31`, omitted by all four call sites
   (`:137`, `:180`, `:181`, `:187`); its body (`:42-44`) carries `-6, 4, 6, -4`,
   left over from the first design's ETA plate. Delete the parameter and its
   branch.

3. **`geometry()` gates the geometry on the parts table.** `Dash.lua:88` reads
   `return ns.Data.Art and ns.Data.ArtGeometry`. With `Data.Art` nil and the
   geometry present, the whole layout silently takes the fallback while the
   geometry sits there unread. Return the geometry alone.

4. **`if ui.compass then` can never be false** (`Dash.lua:370`). The texture is
   created unconditionally at `:157` and merely hidden when the part is
   missing. Drop the dead guard.

5. **The two inserts draw below the glass, against the artist's stated order.**
   `images/parts/dash2-notes.md` says "Draw glass, compass, existing arrow,
   steps insert, ETA insert, then housing." `Dash.lua:180-181` puts both
   inserts at `BACKGROUND`, under `glass` (`BORDER`), `compass` (`ARTWORK`)
   and `arrow` (`OVERLAY`). No pixels are at stake today — measured overlap is
   0 px for every pair that would be affected — but it is fragile if a redraw
   widens either insert. Put them in the artist's order.

6. **The stop button's highlight texture gets no `SetTexCoord`.**
   `Dash.lua:296-299` passes the path straight to `SetHighlightTexture` while
   the normal and pressed caps go through `cap()`, which applies
   `part.l/r/t/b`. Correct today only because `dash2-stop-hover` happens to be
   64×64 on a 64×64 canvas. Route the highlight through the same crop.

7. **Three stale references.** `Dash.lua:5` still says "task 6 lays the art
   over them" (plan 4's task numbering). `test/test_ui.lua:996-997` explains
   the arrow fallback by contrast with `dash-body` / `ui.bodyArt`, neither of
   which exists. `docs/manual-test-checklist.md:383` still asks the tester to
   confirm "The five dash textures load" — the first design's parts, which
   nothing draws; they are kept on disk deliberately, but the checklist does
   not say so and line 396 already covers the eight that matter. Fix all three.

8. **Two weak assertions around the compass crop.**
   `test/tools/test_make_art.py:126-130` checks only `0 < share < 1`; nothing
   pins `share == crop width / canvas width`. And **no automated test measures
   the shipped `dash2-compass.tga` itself** — the crop arithmetic is well
   covered, the artefact is not. Pin both: assert the share against the crop
   box, and add a check that the shipped TGA's alpha bounding box is centred on
   its own canvas to within half a pixel (it measures exactly (127.5, 127.5)
   today). `tools/check_art.py` is the natural home for the artefact
   measurement if it fits the existing `geometry_holds()` shape; a Python unit
   test is equally acceptable. This is the project's convention: manual
   verification gets pinned.

---

## Deferred finding, triaged — fix it

`docs/manual-test-checklist.md:147` reads "it answered the question plan 5 was
waiting on". This branch repointed what that number means: `CLAUDE.md` now ends
"Next: plan 6, the route strip", the spec lists six plans, and this file's own
heading at line 358 became "Dash unit (plans 4 and 5)". The sentence the line
introduces is about the remaining 34 art parts shipping as power-of-two TGAs,
which is the **route strip's** question — now plan 6. The paragraph below says
"a question plan 4 depends on" and means the dash, so two numbers in one entry
now contradict each other, in the document the user reads while standing in
the game.

Change `plan 5` to `plan 6 (the route strip)` on that line. Do not rewrite the
dated record around it; it is accurate history.

---

## Commits

Group the work into commits that read well — one for the layout and geometry
fixes, one for the test-harness fix and the assertions it unlocks, one for the
docs and stale references is a reasonable split, but use your judgment. **Stage
explicit paths on every commit** (`git add <paths>`, never bare `git add -A`)
and **never stage `AGENTS.md`** — it belongs to another agent working in this
repo. Do not push.

End every commit message with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

## Report

Write your full report to
`.superpowers/sdd/2026-09-20-goblinps-dash-second-design/fix-report.md` and
return only: status, the commits you made, a one-line gate summary, and any
concerns. In the report, state explicitly:

- for each of the three Important findings and each of the eight Minor ones,
  what you changed and which test now covers it;
- which of the three new/strengthened tests you confirmed **fail before the
  fix** (I1's no-regions test and I3's anchor-target test are both required to
  have been seen failing);
- the choice you made for `place()`'s two behaviours and why;
- anything on the fake's accepted-and-ignored list that still worries you.

Do not dispatch subagents. Review arrives after your report.

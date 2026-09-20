# Tasks 1-4 report: planner window plan

Branch: `planner-window`. All four tasks done in order, each its own commit, TDD
(RED then GREEN) as the briefs specified. Every file was transcribed byte-for-byte
from the briefs; no deviations were needed.

## Task 1: A zone destination is reached at any stop inside the zone

Files changed: `GoblinPS/Graph.lua`, `test/test_route.lua`.

**Step 1-2 (RED):** Inserted the "a zone destination" `describe` block into
`test/test_route.lua` immediately before `h.describe("Route.Hint", ...)`. Ran the
Lua tests:

```
71 passed, 2 failed
FAIL: a zone destination :: is reached at the first stop inside the zone
    expected: "ride,zeppelin"   actual: "ride,zeppelin,ride"
FAIL: a zone destination :: has no steps when you already stand in it
    expected: "0"   actual: "1"
```

Matches the brief's expected RED (`71 passed, 2 failed`; the third new test,
"still rides to an exact stop in that zone", passed before the change as
expected).

**Step 3 (GREEN):** In `GoblinPS/Graph.lua`, inside `Graph.Build`, added the
`zoneMap`/`toDest` helper right after `stops.DEST = stopFrom(...)`, and replaced
both `addEdge(edges, ..., "DEST", "ride", Graph.RideSeconds(...))` calls with
`addEdge(edges, ..., "DEST", "ride", toDest(...))` (one for `origin`, one for
`stops[key]`), exactly as the brief's diff specified.

**Step 4 (GREEN):**

```
73 passed, 0 failed
```

luacheck: `Total: 0 warnings / 0 errors in 22 files`.

**Step 5 (commit):** `50be1b5 Reach a zone destination at any stop inside the zone`
(files: `GoblinPS/Graph.lua`, `test/test_route.lua`).

## Task 2: The inn list for hearthstone binds

Files changed: created `GoblinPS/Data/Inns.lua`; modified `GoblinPS/Search.lua`,
`test/fake_world.lua`, `test/test_search.lua`, `test/test_data.lua`, `test/run.lua`,
`GoblinPS/GoblinPS.toc`.

**Step 1:** Added the `Inns` table to `test/fake_world.lua` immediately before
`Links = {`.

**Step 2 (RED):** Added the two new `Search.Exact` tests (Delta Harbour Inn,
Quiet Hollow) and the "returns nil for an inn on a map we do not have" test to
`test/test_search.lua`; added the "the inn list" `describe` block to
`test/test_data.lua`; added the `Inns` module line to `test/run.lua`. Ran the
tests:

```
74 passed, 5 failed
FAIL: Search.Exact :: follows an inn that stands beside a flight stop
    attempt to index a nil value
FAIL: Search.Exact :: places an inn in a town with no flight master
    attempt to index local 'inn' (a nil value)
FAIL: the inn list :: resolves every row for the faction that can use it
    bad argument #1 to 'pairs' (table expected, got nil)
FAIL: the inn list :: only lists names Search cannot already find
    bad argument #1 to 'pairs' (table expected, got nil)
FAIL: the inn list :: finds the binds met in game
    attempt to index a nil value
```

Matches the brief: the two Search tests that expect a match fail, and all
three inn-list data tests error because `data.Inns` is nil. The "Nowhere Inn"
test (map we do not have) passed already, as the brief's notes predicted.

**Step 4 (GREEN):** Edited `Search.Exact` in `GoblinPS/Search.lua`: inserted the
`for bind, inn in pairs(data.Inns or {}) do ... end` loop before the existing
`for _, item in ipairs(candidates(data, faction)) do` loop, exactly as given.

**Step 5:** Wrote `GoblinPS/Data/Inns.lua` verbatim from the brief (hand-written
inn list: `stop`-style rows for Grom'gol/Theramore/Feathermoon, `map/mx/my`
rows for Razor Hill, Bloodhoof Village, Brill, Goldshire, Kharanos, Dolanaar).

**Step 6:** Added `Data\Inns.lua` to `GoblinPS/GoblinPS.toc` directly after
`Data\Links.lua`.

**Step 7 (GREEN):**

```
79 passed, 0 failed
```

luacheck: `Total: 0 warnings / 0 errors in 23 files`.

**Step 8 (commit):** `6dd2970 Add the inn list for hearthstone binds`
(files: `GoblinPS/Data/Inns.lua`, `GoblinPS/Search.lua`, `GoblinPS/GoblinPS.toc`,
`test/fake_world.lua`, `test/test_search.lua`, `test/test_data.lua`, `test/run.lua`).

## Task 3: `Prefs`

Files changed: created `GoblinPS/Prefs.lua`, `test/test_prefs.lua`; modified
`test/run.lua`.

**Step 1 (RED):** Wrote `test/test_prefs.lua` verbatim from the brief (Init
defaults/repair/isolation, ToggleLayout, Remember ordering/dedup/cap/empty-name,
window positions). Added `{ "Prefs", "GoblinPS/Prefs.lua" }` to the module list
in `test/run.lua` after `Known`, and `"test/test_prefs.lua"` to the suite list
after `"test/test_known.lua"`. Ran the tests:

```
79 passed, 10 failed
FAIL: Prefs.Init :: ... attempt to index upvalue 'Prefs' (a nil value)
(all ten new tests fail the same way — Prefs is nil)
```

Matches the brief's expectation.

**Step 3 (GREEN):** Wrote `GoblinPS/Prefs.lua` verbatim from the brief:
`Prefs.Init`, `Prefs.ToggleLayout`, `Prefs.Remember`, `Prefs.SavePosition`,
`Prefs.Position`, `Prefs.MAX_RECENTS = 8`.

**Step 4 (GREEN):**

```
89 passed, 0 failed
```

luacheck: `Total: 0 warnings / 0 errors in 25 files`.

Per the brief's note, `GoblinPS/GoblinPS.toc` is deliberately NOT touched for
`Prefs.lua` in this task (a later task adds it with the rest of the window).

**Step 5 (commit):** `decb867 Add the preferences module`
(files: `GoblinPS/Prefs.lua`, `test/test_prefs.lua`, `test/run.lua`).

## Task 4: The icon

Files changed: created `tools/make_icon.py`, `GoblinPS/Media/icon.tga` (binary,
generated and committed).

**Step 1:** Wrote `tools/make_icon.py` verbatim from the brief (uses
`images/icon-source.png` if present, else draws a brass-dial placeholder;
applies a round alpha mask; writes a 256x256 RGBA TGA).

**Step 2:** Ran `python tools/make_icon.py`:

```
no D:\goblinps\images\icon-source.png - drawing the placeholder
wrote D:\goblinps\GoblinPS\Media\icon.tga
```

Matches the brief exactly (no `images/icon-source.png` exists in this repo, so
the placeholder path was used).

**Step 3:** Ran the check command:

```
python -c "from PIL import Image; im=Image.open('GoblinPS/Media/icon.tga'); print(im.size, im.mode)"
(256, 256) RGBA
```

**Step 4 (commit):** `a5c2050 Add the icon tool and a placeholder icon`
(files: `tools/make_icon.py`, `GoblinPS/Media/icon.tga`).

## Self-review

- Read back every diff before committing; each edit matches the brief's exact
  anchors and text.
- Cumulative Lua test counts matched exactly at every checkpoint: 70 (start) ->
  71/2 failed (Task 1 RED) -> 73 (Task 1 GREEN) -> 74/5 failed (Task 2 RED) ->
  79 (Task 2 GREEN) -> 79/10 failed (Task 3 RED) -> 89 (Task 3 GREEN); Task 4
  added no Lua tests.
- luacheck was `0 warnings / 0 errors` after every task.
- Only the files each brief named were staged per commit (verified with
  `git status` after each commit; the tree is clean now). Nothing under
  `.superpowers/` was staged.
- No Python test suite exists yet under `test/tools`, so
  `python -m unittest discover -s test/tools` was not applicable to any of
  these four tasks (none of them touch Python-tested code); not run.
- Git line-ending warnings ("LF will be replaced by CRLF") appeared on several
  commits; these are informational from Git's `core.autocrlf` and did not
  affect file contents (files were written with LF as instructed and the
  checked-in blobs are unaffected by the warning).

## Concerns

None. All four tasks are DONE with exact expected outputs at every checkpoint.

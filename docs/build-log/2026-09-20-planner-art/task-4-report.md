# Task 4 report: The planner frame and its chrome, from geometry

## Status: DONE

## Commit

`456206f` "The planner frame wears its art, placed from the geometry"
(2 files changed: `GoblinPS/Planner.lua`, `test/test_ui.lua`)

## What was done

Followed the brief's steps in order.

**Step 1-2**: Added the five tests to the `"the planner window"` describe
block in `test/test_ui.lua`, verbatim from the brief. Ran the suite first to
confirm they failed: 5 failures (the brief's own two named failures, plus
three cascading ones once the aspect-ratio and "no art" fixes weren't yet in
place — `ui.content`/`ui.close`/`ui.frameArt` didn't exist yet).

**Step 3-4**: Rewrote `GoblinPS/Planner.lua`:
- `Planner.SIZE` changed to `{ wide = { 650, 416 }, tall = { 384, 600 } }`
  (exact aspect ratios of the 1600x1024 / 1024x1600 art).
- Added file-local `MEDIA`, `geo(mode)`, and `art(parent, name, layer)`
  helpers exactly as specified.
- `build()` now creates a bare frame `f` (`CreateFrame` + explicit
  `SetSize(Planner.SIZE.wide[1], Planner.SIZE.wide[2])`) instead of
  `W.Panel(UIParent, ...)`. Added `flat` (its own hideable fallback frame at
  `base`), `artLayer` (`base+1`), `content` (`base+2`), and gave `results` an
  explicit `SetFrameLevel(base + 3)` so it stacks above content per the
  brief's table (it previously relied on `DIALOG` strata alone, which the new
  "stacks the art under the content" test now pins directly on frame level).
- Deleted the orange `stripe` texture entirely.
- `title`/`tagline` FontStrings moved to `content`, lost their hand-typed
  anchors (now placed by `ApplyLayout` via `W.PlaceLine`).
- Replaced `close` and `layoutButton`'s construction with the brief's
  close/dropdown/gear button block (real buttons on `content`, art via
  `art()`, hazard/steel flat-colour fallback, hover textures where the art
  provides one). `layoutButton` stays a `W.Button` parented to `f` as
  instructed, with its `SetPoint` call removed — task 4 does not reparent it,
  since the brief scopes only title/tagline/close/gear/dropdown into
  `content` and leaves `fromBox`/`toBox`/`here`/`screen`/`side`/`layoutButton`
  for Task 5, which places them from `g.fromBox`, `g.toBox`, etc.
- `ApplyLayout` rewritten per the brief: sizes the frame first, swaps
  `frameArt`'s texture (falling back to `flat`), then — inside one
  `if g then` block — places `titlePlate`/`taglinePlate` (guarded by
  `if ui.titlePlate then` / `if ui.taglinePlate then`, since `plate()` can
  return nil), the two text lines, the three circular buttons, and
  `layoutButton`'s rect.
- Extended the `ui` table with `artLayer`, `content`, `flat`, `frameArt`,
  `titlePlate`, `taglinePlate`, `title`, `tagline`, `close`, `gear`,
  `dropdown`.
- No tools button was created; `close.png` is the only X control, per the
  brief's explicit ruling.

One deviation from the brief's literal text, both justified and minimal:
- `INPUTS` and `SCREEN_SHARE` (the two file-local constants the old
  `ApplyLayout` used to lay out `screen`/`side`) became genuinely dead code
  once `ApplyLayout`'s body was replaced wholesale, and luacheck flagged them
  as unused. Removed both; nothing in Task 4 or the existing suite reads them
  (`grep` confirmed no other reference), and Task 5 places `screen`/`side`
  from the generated geometry instead, not from these hand-typed constants.
- One luacheck warning surfaced that the brief's code block itself would
  produce verbatim: `local hover` for `close-hover` shadows the unrelated
  `local hover` already declared inside the results-row loop further down in
  `build()`. Renamed the close-hover local to `closeHover` (matching the
  `dash2-stop-hover` → `stopHover` naming already used in `Dash.lua`). No
  behavior change.

**Step 5-6**: Full Lua suite green, then luacheck and lua-language-server run
from PowerShell as instructed.

**Step 7**: Committed `GoblinPS/Planner.lua` and `test/test_ui.lua` only,
verbatim commit message from the brief except for the attribution line, which
follows this session's active attribution instruction (Claude Sonnet 5, not
Opus 5 as the brief's example showed — the instruction explicitly says it
replaces any earlier copy of that guidance embedded elsewhere). `AGENTS.md`
was left untracked and unstaged, per the standing rule that it belongs to
another agent.

## Test summary

| Gate | Result | Baseline |
|---|---|---|
| Lua suite (`test/run.lua`) | 267 passed, 0 failed | 262 passed, 0 failed |
| `python -m unittest discover -s test/tools` | 42 tests, OK | 42 |
| `python tools/check_art.py` | 47 pass, 0 with problems, 0 not drawn yet | same |
| luacheck (PowerShell) | 0 warnings, 0 errors, 38 files | 0 warnings, 38 files |
| lua-language-server --check (PowerShell) | "Diagnosis completed, no problems found" | clean |

## Concerns

- `screen`, `side`, `fromBox`, `toBox`, `here`, `go`, `total`, `hint`,
  `notes` are still positioned by the old `SetPoint` calls in `build()` (or,
  for `screen`/`side`, not positioned at all now — the old `ApplyLayout` used
  to anchor them and that code was removed along with the rest of the old
  body). This is intentional and in-scope for Task 5 per the brief's
  "Produces, for Task 5" list and the geometry keys it names
  (`fromBox`, `toBox`, `hereButton`, `goButton`, `totalLine`, `hintLine`,
  `screen`, `sidePanel`, `resultsList`) — but until Task 5 lands, opening the
  real client would show a correctly-chassised, correctly-chromed window with
  the screen and step list not yet placed inside it. Not a defect in this
  task's scope, just worth flagging so it isn't mistaken for a regression
  when Task 5 starts.
- This task has not been run in the client. Everything here is verified
  against the Lua suite's fake frame API and the two Python gates; the two
  faults this task exists to pre-empt (an unhideable rectangle behind
  transparent art, and a stretched frame) are exactly the kind of thing the
  project's own history says can pass every desktop test and still draw
  wrong on screen. Recommend an in-game check before Task 5 builds further
  on top of this.

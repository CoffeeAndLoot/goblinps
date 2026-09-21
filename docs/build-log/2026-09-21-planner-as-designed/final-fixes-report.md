# Final review fix wave (plan 8) — report

Branch: `planner-as-designed`. All items from `final-fixes.md` (I1, I2, S1-S9) done.
AGENTS.md left untracked and unstaged throughout, per project rule.

## I1 — pin the strip's legs (test-only, no production change)

`test/test_ui.lua`, the it-block `"joins the stops with a solid first leg and dashed
after, tiled not stretched"` (~line 925), in `h.describe("the route strip", ...)`.

Added, per stop of the badge test's own pattern (~911-923):
- `line.points[1][1] == "LEFT"`, `line.points[1][2] == ui.frame`,
  `line.points[1][5] ≈ -t.cy`
- `dot.points[1][1] == "CENTER"`, `dot.points[1][2] == ui.frame`,
  `dot.points[1][5] ≈ -t.cy`
- `dot:GetWidth() ≈ t.thick` and `dot:GetHeight() ≈ t.thick`

Also fixed a masked bug in the existing texcoord assertion: it always read the
aspect from `ns.Data.Art["line-dashed"]`, even for leg 1, which is drawn with
`line-solid`. Now it reads `ns.Data.Art[style]` where `style` is the leg's own
part name (`line-solid` for leg 1, `line-dashed` after). This did not change the
test's pass/fail today only because `line-solid` and `line-dashed` currently
ship at the same `cw`/`ch` (128x16 each, `GoblinPS/Data/Art.lua:52-53`) — a
future regeneration that changed one part's canvas size without the other
would have slipped through the old assertion.

RED/GREEN: I1 required no production fix (`GoblinPS/Planner.lua`'s
`drawStrip` already sets these points and sizes correctly). Confirmed by
running the suite with the tightened assertions alone (before touching I2):
all of them passed on the first run — see the "GREEN evidence" run below,
which includes this test passing throughout. There is nothing to show as RED
for I1 because the code was already correct; the brief's "see it fail where
it can" was honoured by writing the strictest version of the test I could
justify (including the leg-style fix above) and confirming it still passes,
rather than manufacturing a failure.

## I2 — guard `stripMetrics` against a missing `strip` table

`GoblinPS/Planner.lua`:
- Added `stripGeo()` (new, ~line 31, beside `geo()`): returns
  `ns.Data.ArtGeometry.planner.strip` or nil, mirroring `geo()`'s own nil-safe
  shape.
- `stripMetrics(g)` → `stripMetrics(g, s)` (~line 47): no longer re-indexes
  `ns.Data.ArtGeometry.planner.strip` itself; the caller passes it in, already
  checked non-nil.
- `Planner.Refresh()` (~line 197-201): `local g = geo()` →
  `local g, s = geo(), stripGeo()`; the draw condition `if plan and routed and g then`
  → `if plan and routed and g and s then`. `ui.strip:SetShown(layout ~= nil)`
  is unchanged, so a missing `strip` table now simply leaves `layout` nil and
  hides the strip, exactly like a missing `wide` geometry already did.

No other behaviour changed: the strip still draws exactly as before whenever
both tables are present, and every other line of `Refresh` is untouched.

### Test

`test/test_ui.lua`, new it-block `"hides the strip rather than error when the
strip geometry is missing"` (~line 1069, in `h.describe("the route strip",
...)`, right after `"draws no strip without a route"`). It routes a plan
(`pickTo("delt")`), confirms the strip shows normally, nils
`ns.Data.ArtGeometry.planner.strip`, calls `Planner.Refresh()` inside `pcall`,
asserts no error and that `ui.strip` is hidden while `ui.frame` stays shown,
then restores the table and calls `Refresh()` again to confirm the strip
comes back.

### RED (before the `GoblinPS/Planner.lua` fix)

```
325 passed, 5 failed
FAIL: the route strip :: hides the strip rather than error when the strip geometry is missing
    test/test_ui.lua:1079: GoblinPS/Planner.lua:43: attempt to index local 's' (a nil value), got "false"
FAIL: /gps hearth :: takes minutes and stores seconds
    GoblinPS/Planner.lua:43: attempt to index local 's' (a nil value)
FAIL: /gps hearth :: zero means always take the fastest route, and says so plainly
    GoblinPS/Planner.lua:43: attempt to index local 's' (a nil value)
FAIL: /gps hearth :: refuses nonsense without changing the setting
    GoblinPS/Planner.lua:43: attempt to index local 's' (a nil value)
FAIL: the trip in progress :: opens the planner on the running trip's destination
    GoblinPS/Planner.lua:43: attempt to index local 's' (a nil value)
```

The four cascading failures are expected and not separate bugs: the new
test's own `h.truthy(ok, err)` assertion fails first (so the test never
reaches its own restore line), which leaves
`ns.Data.ArtGeometry.planner.strip` nilled for every test that runs after it
in the same suite process — itself further evidence that a thrown error out
of `Refresh()` is not survivable, exactly the bug I2 describes ("every /gps
open throws").

### GREEN (after the fix)

```
330 passed, 0 failed
```

329 (baseline) + 1 new test = 330, matching the brief's "should gain 1".
Confirmed again after the full S1-S9 sweep, unchanged: `330 passed, 0 failed`.

## Sweep (no behaviour change)

- **S1** `GoblinPS/Widgets.lua:110-113` (comment above `Stretch3`): reworded
  the "65 px for Here, 135 for GO" example to "one 'button' part drawn at
  whatever width the geometry gives" Start Route, matching today's controls.
  Checked the two dated-history comments the brief also named
  (`Widgets.lua:186`, "Measured before this was fixed: GO's cap drew 24 px
  in both layouts..."; `Widgets.lua:271`, "Seen in the client 2026-09-21:
  Tall, Here and GO kept the steel meant for the brass face..."). Both are
  past-tense records of specific bugs found on specific dates, not present-
  tense descriptions of today's controls, so left as-is per the brief's own
  instruction to keep dated history.
- **S2** `GoblinPS/Core.lua:125` (comment above `Core.PinStep`): "only GO
  explains itself" → "only Start Route explains itself" (and the "not only
  when GO is pressed" clause on the same line).
- **S3** `GoblinPS/Planner.lua`, the `coverCrop` comment (~330-333): replaced
  "Losing its sides is intended" with a description of which side is actually
  lost — the art's left/right when the art is wider than the opening, the
  top/bottom when the opening is wider than the art, which is today's case
  (verified: the wide screen opening is ~3.3:1 in real pixels — `(0.80625 *
  1600) / (0.382813 * 1024)` from `ArtGeometry.planner.wide.screen` and
  `.canvas` in `GoblinPS/Data/Art.lua` — against `screen-backdrop`'s ~2.5:1,
  so `coverCrop`'s `else` branch, which trims `t`/`b`, is the one that fires).
- **S4** `test/fake_frames.lua:44`: the instance-data example `results.owner`
  (a field that no longer exists) → `strip.badges` (does exist, set in
  `GoblinPS/Planner.lua`'s `build()`).
- **S5** `test/test_ui.lua:802`: `FreshPlanner.ApplyLayout("wide")` →
  `FreshPlanner.ApplyLayout()` — `Planner.ApplyLayout` takes no parameters
  today; the stray argument was silently ignored by Lua, so this is wording
  only, no behaviour change.
- **S6** `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`
  (~327-330): "Until plan 8 adapts it, the desk art tooling reports the new
  layout as mismatched... fail, by design... not been regenerated" → past
  tense, "Plan 8 has adapted the desk art tooling... are green again... has
  been regenerated." Verified true before writing it: `python -m unittest
  discover -s test/tools` → 55 tests OK; `python tools/check_art.py` → 47
  pass, 0 with problems, 0 not drawn yet.
- **S7** `docs/manual-test-checklist.md`, plan 3 section: inserted
  "Superseded by plan 8: the window has one box, one layout and no step
  list." as its own line directly above the one checklist item that still
  named two-line step rows and "... and N more steps" (~line 264-265). Left
  every other plan-3 item (crossing coordinates, the walk/ride and amber-
  warning checks) alone, since those are about ground travel and still apply
  under the strip.
- **S8** `CLAUDE.md:39` and `:94`: both present-tense "GO closes the
  planner" → "Start Route closes the planner" (once in prose, once in the
  `Dash.lua` layout-table comment). Left every dated-history sentence
  elsewhere in the file alone.
- **S9** `docs/manual-test-checklist.md`, end of the "planner as designed
  (plan 8)" section (~line 419): added the two lines the brief specified
  verbatim, checking the two end-badge names for truncation at ~65 px and a
  13-stop route for overlapping hover areas.

## Gate results (all from `D:\goblinps`, after every change above)

| Gate | Result |
|---|---|
| Lua suite (`test/run.lua` via lupa) | `330 passed, 0 failed` |
| Python (`python -m unittest discover -s test/tools`) | `Ran 55 tests ... OK` |
| Art (`python tools/check_art.py`) | `47 pass, 0 with problems, 0 not drawn yet` |
| luacheck (`GoblinPS test`, PowerShell) | `Total: 0 warnings / 0 errors in 40 files` |
| lua-language-server (`--checklevel=Warning`, PowerShell) | `Diagnosis completed, no problems found` — `[]` |

No lint or language-server warning was suppressed; none appeared during this
work (the Python-side `Image.Image.getdata` deprecation notices from Pillow
are warnings from a third-party library inside `tools/make_art.py` and
`tools/check_art.py`, unrelated to this branch's changes, and out of scope
for this fix wave).

## Files touched

- `GoblinPS/Planner.lua` (I2 fix, S3 comment)
- `GoblinPS/Core.lua` (S2)
- `GoblinPS/Widgets.lua` (S1)
- `test/test_ui.lua` (I1, I2 test, S5)
- `test/fake_frames.lua` (S4)
- `CLAUDE.md` (S8)
- `docs/manual-test-checklist.md` (S7, S9)
- `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md` (S6)

`AGENTS.md` (untracked, belongs to Codex) was never staged or modified.

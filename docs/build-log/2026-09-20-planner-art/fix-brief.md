# Fix wave — plan 6, the planner window's art

This is the **one and only** fix wave for this branch. Everything below must
land. The full argument for each finding is in `final-review.md` beside this
file; this brief carries the rulings and the exact work.

Branch `planner-art`, BASE `dde84b4`. Work in `D:\goblinps`.

## Ground rules that bind every change here

- **No coordinate may be hand-typed in `Planner.lua`.** Every position comes
  from `ns.Data.ArtGeometry.planner`. `Planner.SIZE` is the one exception.
- Plain Lua 5.1, no libraries, **no Blizzard frame templates**, no secure code.
- `API.lua` is the only file allowed to call Blizzard game APIs. `Planner.lua`
  may touch `CreateFrame`, `UIParent` and `UISpecialFrames` only.
- **Never measure a frame that only inherits its size.** A frame sized by
  `SetAllPoints` answers 0 for `GetWidth()` until the client's layout pass.
- **A missing texture must leave a working window.** Every `SetTexture` return
  value is used.
- Every FontString gets two horizontal anchors (or a width) and a decided
  wrap-or-truncate.
- Generated files are never hand-edited. `GoblinPS/Data/Art.lua` and
  `GoblinPS/Media/*.tga` come from `tools/make_art.py`.
- Zero luacheck warnings, zero language-server warnings, **no lint
  suppression**.

## Gates — all green before you commit

```bash
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```

```bash
python -m unittest discover -s test/tools
```

```bash
python tools/check_art.py
```

```bash
python tools/make_art.py
```

luacheck and lua-language-server **from PowerShell, never Git Bash** — through
Git Bash the language server mis-scopes the workspace root and reports over a
hundred bogus warnings.

Baseline to match or beat: **278 Lua, 42 Python, check_art 47/0/0,
`make_art.py` regenerating with a clean tree, luacheck 0 warnings in 38 files,
language server clean.**

---

## CRITICAL — the screen's scenery is drawn, cropped correctly, and invisible

`GoblinPS/Planner.lua:402` creates `backdrop` on `artLayer`. `:517` builds
`screen = W.Panel(content, "screen", "steel", 2)`. `ApplyLayout` then places
**both at the same `g.screen` rect**, and `Widgets.Panel` lays two fully
opaque `SetColorTexture(..., 1)` regions on the frame it creates.

I probed the built UI rather than reading the code:

```
artLayer   parentLevel=1  ownLevel=2
backdrop   on artLayer    anchor=(60.9375, -160.875104)
content    ownLevel=3
screen     on content     ownLevel=4   anchor=(60.9375, -160.875104)
screen frame owns 5 regions of its own
```

Byte-identical anchors, an opaque panel at level 4 over scenery at level 2.
In the client the screen shows flat dark green and the artist's scenery never
appears. Every test on this branch passes because they assert *where* the
backdrop is and *how big* it is, and both are correct.

This is the same fault the branch fixed one level up — the window frame's
unhideable `W.Panel`, replaced by a hideable `flat` frame — reproduced one
level down. My own ruling R18 walked straight past it: it noticed
`planner-panel` was being covered *by the backdrop* and moved the panel,
without asking what was covering the backdrop.

**Ruling: put the backdrop on the `screen` frame itself, at `"ARTWORK"`.**
That is the project's standing pattern — art over colours — and it puts the
scenery above the panel's two colour fills (`BACKGROUND` and `BORDER`) and
below the `OVERLAY` FontStrings that draw on it. The colour fills stay exactly
where they are and remain the fallback when the texture will not load.

- Create `backdrop` on `ui.screen`, not on `artLayer`, at draw layer
  `"ARTWORK"`.
- It no longer needs placing by `ApplyLayout` against `g.screen`: it fills its
  parent, which the geometry already places. Use `SetAllPoints(ui.screen)` and
  delete the `W.PlaceRect(ui.backdrop, f, g.screen)` call. **Keep the
  `coverCrop` call** — the crop is correct and hard-won, and it needs the
  screen box's pixel size, which you still compute from `g.screen` and the
  frame.
- `screen` is built after `artLayer` in `build()`; make sure the backdrop is
  created after `screen` exists.

**The test this needs, and it is the point of the whole finding.** Add a test
asserting the backdrop is **not** underneath an opaque sibling: that its parent
is the `screen` frame and its draw layer is `"ARTWORK"`, and that no region on
the same frame at an equal-or-higher layer is fully opaque over it. Assert the
mechanism, not the coordinates. It must fail against the current code — run it
before you fix and confirm it does.

---

## IMPORTANT 1 — three-slice end caps are sized once, at build time

`GoblinPS/Widgets.lua:138` computes a cap's drawn width as
`parent:GetHeight() * capAspect`, **inside `build()`**. At that moment the
control has whatever size `W.Button` or `W.EditBox` gave it. `ApplyLayout`
then re-anchors every one of them corner to corner from the geometry, changing
their height — and nothing recomputes the caps. It never re-runs per layout
either, so switching wide to tall leaves them stale a second time.

Measured against the geometry: GO's cap is 24 where the layout implies 32.5
wide and 33.7 tall (−26% / −29%); `here` is −34%; both input boxes are −34%.
The end caps are squashed in exactly the way three-slicing exists to prevent.

The fake hides it because its `GetHeight()` does not resolve a size from two
opposing anchors — another case of the harness being more helpful than the
client, which is the same class as the `SetAllPoints` fault that shipped.

**Ruling: the caps are re-measured every time the layout changes.** Store what
`Stretch3` needs to redo its work — the slice pieces and the `capAspect` — and
give `Widgets` a function that re-applies cap widths for a control whose size
has just changed. `ApplyLayout` calls it for each three-sliced control after
placing it, in the same `if g then` block. `parent.slice` already exists from
the earlier round; extend it rather than adding a second mechanism.

Add a test that places a three-sliced control, changes its size the way
`ApplyLayout` does, and asserts the caps track. Make it fail first.

---

## IMPORTANT 2 — `check_art.py`'s allow-list is silent on a new key

`planner_geometry_holds()` checks six keys named in `PLANNER_INTERIOR_KEYS`.
A seventh key added to `planner-geometry.json` gets neither a pass nor a
failure — just silence. `CLAUDE.md` has a rule about precisely this: *never
let silence read as "nothing disagrees."*

The fuse is short. Plan 7 adds the route strip's keys to that very file, and
this branch merges into `main` where plan 7 starts.

**Ruling: fix it before merge, and make it two-sided.**

- Keep the interior list. Add a second, documented list of the keys that sit
  on brass **by design** — `title_plate` and `tagline_plate` in both layouts,
  and `layout_button` in `wide` only. Those numbers are measured: the plates
  are 95–100% opaque in both layouts, `layout_button` is 85.4% in wide and
  0.0% in tall, because the wide art puts that button on the brass crest.
- **Fail when a rectangular key appears in neither list.** That converts the
  silent gap into a loud one.
- **Also assert every key named in either list is actually present** in the
  geometry, so a rename cannot slip out as silently as an addition slips in.
- Add a Python test for both directions: an unknown key fails, and a listed
  key that vanished fails.

---

## MINOR 1 — a stale plan number in the document the user reads in-game

`docs/manual-test-checklist.md:147` still calls the route strip "plan 6",
contradicting that same file's own new section header at `:362`. The strip
moved to plan 7 on this branch. One word. Build-log hits are historical and
must be left alone.

## MINOR 2 — two shipped textures that nothing draws

`button-hover` and `button-pressed` ship but no code references them. This
branch deliberately did not ship the strip's parts for exactly that reason, so
leaving these unused is inconsistent.

**Ruling: wire them, do not unship them.** The machinery already exists —
`reslice(slice, part)` swaps a three-sliced control's art by name, and
`SetButtonEnabled` already uses it for `button-disabled`. Give the three-sliced
buttons `OnEnter`/`OnLeave` to swap to `button-hover` and back, and
`OnMouseDown`/`OnMouseUp` for `button-pressed`. A disabled button must not
respond to either. If a state's part is missing or will not load, leave the
current art in place — a missing texture must never break a button. Keep it
small; if it grows past about fifteen lines, stop and say so in your report.

## MINOR 3 — the results overlay's layering works, but not for the stated reason

`results` sets `base + 3`, which **ties** with `screen` and `side` rather than
exceeding them. It draws above them because it is on the `DIALOG` strata, not
because of its level. The test that claims to prove the layering asserts the
level, so it is not testing the mechanism that actually does the work.

Fix the test to assert the real mechanism — the strata — and leave a comment
saying the level is not what carries it.

## MINOR 4 — a client-only question, onto the checklist

Whether the edit boxes' text stays legible over the new `input-box` art is a
question only the client answers. Add a checklist line asking the tester to
confirm the typed text and the placeholder are both readable against the art.

---

## Not in this wave, and why

The final review triaged the dash's build-once-singleton ordering dependency as
**do not fix before merge**. I agree. No test change durably fixes an ordering
dependency; the real remedy is a runtime guard that treats a zero measurement
inside the placement helpers as the error it is and surfaces it to
`/gps selftest` — loud in the client, and indifferent to test ordering. That is
new behaviour and belongs in its own plan. Do not build it here.

---

## Commits

Group into commits that read well — the Critical and Important 1 together as
the layering-and-sizing fix, the `check_art` work as its own, docs as its own,
is reasonable. Use your judgment. **Stage explicit paths on every commit**
(`git add <paths>`, never `git add -A`) and **never stage `AGENTS.md`** — it
belongs to another agent working in this repo. Do not push.

End every commit message with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

## Report

Write your full report to
`.superpowers/sdd/2026-09-20-goblinps-planner-art/fix-report.md` and return
only: status, the commits you made, a one-line gate summary, and any concerns.
In the report state explicitly:

- for each finding, what you changed and which test now covers it;
- that you watched the Critical's test and Important 1's test **fail before
  the fix**, with the output;
- anything you found while in these files that worries you and that this wave
  did not address.

Do not dispatch subagents. Review arrives after your report. If you make a
scratch copy of the tree, put it under the system temp directory and delete it
when done.

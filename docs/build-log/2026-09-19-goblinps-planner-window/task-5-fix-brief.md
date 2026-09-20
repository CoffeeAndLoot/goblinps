# Task 5 fix round 1 — GoblinPS planner window

Repo `D:\goblinps`, branch `planner-window` (checked out). Commands and commit rules: `implementer-common.md` in this
folder (ignore its "transcribe byte-for-byte" paragraph: this round changes behaviour, test-first where a desktop test
can see it). Keep every change as small as the ruling allows. One commit for the whole round:

    git commit -m "Planner window: fix drag, focus loss, saved position and the texture self-check" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"

Current state: Lua `103 passed, 0 failed`, luacheck 0 warnings, lua-language-server clean. All must stay green (the
count rises). Read every file you change first: `GoblinPS/Planner.lua`, `Widgets.lua`, `MinimapButton.lua`,
`SelfTest.lua`, `Prefs.lua`, `Core.lua`, `Search.lua`, `test/fake_frames.lua`, `test/test_ui.lua`, `test/test_prefs.lua`,
`test/test_search.lua`, `test/fake_world.lua`, `.luacheckrc`, `.luarc.json`, `CLAUDE.md`,
`docs/manual-test-checklist.md`. The WoW client's exact UI source is at `D:\wow-api\1.60.1.69913` if you need to check
a method.

A reviewer checked every widget call against the client source. These are its findings and the controller's rulings.

## F1. Dragging (Important)

`GoblinPS/Planner.lua`: `f:SetScript("OnDragStart", f.StartMoving)` passes the drag button string into
`StartMoving(alwaysStartFromMouse: bool)`. Ruling: `f:SetScript("OnDragStart", function(self) self:StartMoving() end)`.

## F2. The results list can be stranded open (Important)

An EditBox only loses focus on ClearFocus, Escape, Enter or another box taking focus; clicking GO, Here, the layout
button or the frame does not. Rulings:

- In `wireBox`, add `OnEditFocusLost`: hide the results list if this box owns it
  (`if ui.results.owner == self then hideResults() end`).
- Clicking a results row must still work: a plain Button click does not take EditBox focus, so the row's OnClick runs
  while the list is still shown; `pick` already clears focus afterwards. Do not add timers.
- The buttons GO, Here, the layout toggle and close, and a mouse-down on the planner frame itself, must also put the
  list away and drop the box focus: give the planner a local helper `dismiss()` that calls `ClearFocus()` on both
  boxes and `hideResults()`, call it at the start of those four buttons' click handlers, and set it as the frame's
  `OnMouseDown`.

## F3. Saved window position (Important)

`GetPoint` returns `point, relativeTo, relativePoint, x, y`; the code drops `relativePoint` and restores assuming it
equals `point`. Rulings:

- `Prefs.SavePosition(db, window, point, relativePoint, x, y)` stores `{ point, relativePoint, x, y }`;
  `Prefs.Position` returns it. A saved entry with no `relativePoint` (older data) is read as `relativePoint = point`.
- `Core.SavePosition(window, point, relativePoint, x, y)` passes all four through.
- `Planner`: on drag stop save `point, relativePoint, x, y`; on first open restore with
  `SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)`.
- Update `test/test_prefs.lua` for the new signature (and add the older-data case).

## F4. The texture self-check may be unable to fail (Important)

`SetTexture` returns a documented `success` bool. Ruling: in `GoblinPS/SelfTest.lua`, `textureLoads` becomes
`return probe:SetTexture(path) and true or false` (drop the `SetTexture(nil)` / `GetTexture` dance and fix the comment).
The fake's `SetTexture` must return `true` for a non-nil path so the smoke test still passes; add a smoke assertion
that a path the fake is told to reject (add `Fake.missingTextures = {}`, a set of paths for which the fake's
`SetTexture` returns false) makes `/gps selftest` print a FAIL line and end with `Self-test: 1 failed.`

## F5. Cheap minors, same commit

1. `Widgets.EditBox`: call `e:EnableMouse(true)` explicitly, and delete the dead default
   `e:SetScript("OnEscapePressed", e.ClearFocus)` (Planner sets its own).
2. Results panel: `results:EnableMouse(true)` so a near-miss on a row does not start a window drag.
3. Step rows: replace the over-constrained `row.left:SetPoint("RIGHT", row.right, "LEFT", -6, 0)` with
   `row.left:SetPoint("TOPRIGHT", row.right, "TOPLEFT", -6, 0)`.
4. `MinimapButton`: `b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")`.
5. Notes reach the window: when a route HAS steps, show the plan's notes (all of them, joined with two spaces) in a
   new dim one-line FontString `ui.notes` at the top of the green screen (TOPLEFT 8,-8 to TOPRIGHT -8,-8); empty when
   there are none. When there are no steps keep today's behaviour (last note in the total line) and leave `ui.notes`
   empty. Expose it in the `ui` table. Smoke-test it: with the fake API's `HearthBindName` returning an unknown inn
   name, `ui.notes` contains `Hearth: unknown inn`.
6. Inn lookup cannot loop: in `Search.Exact`, the recursive call for `inn.stop` must not consult `data.Inns` again.
   Smallest change: give `Search.Exact` a fourth parameter `skipInns` (internal), pass `true` on the recursive call,
   and skip the inn loop when it is set. Test in `test/test_search.lua`: add to `test/fake_world.lua`'s `Inns` a row
   `["Loop Inn"] = { stop = "Loop Inn" }` and assert `Search.Exact(world, "Loop Inn", "H")` is nil (today it would
   overflow the stack). Make sure the real-data test "only lists names Search cannot already find" still passes.
7. Lint configs agree: `GoblinPSMinimapButton` and `GoblinPSPlanner` are globals our code creates. List both in
   `.luacheckrc` `globals` and in `.luarc.json` `diagnostics.globals`; remove the now-redundant per-file
   `read_globals = { "GoblinPSMinimapButton" }` for `test/test_ui.lua` (keep its `globals = { "print" }`).

## F6. Make the fake frame library strict (this is why F1-F3 reached review)

`test/fake_frames.lua` answers ANY unknown method with a silent no-op, so a misspelt widget call passes. Ruling: the
catch-all `__index` may return a no-op only for names in an explicit allowlist of real widget methods the addon uses
(each one was verified to exist in the client source); any other name raises
`error("fake_frames: unknown widget method '" .. key .. "'", 2)`. Build the allowlist from what the code actually
calls today beyond the methods the fake already models, for example: `SetAllPoints`, `SetColorTexture`,
`SetTexCoord`, `SetAlpha`, `SetTextColor`, `SetJustifyH`, `SetWordWrap`, `SetFontObject`, `SetTextInsets`,
`SetMaxLetters`, `SetAutoFocus`, `EnableMouse`, `SetMovable`, `SetClampedToScreen`, `RegisterForDrag`,
`RegisterForClicks`, `StartMoving`, `StopMovingOrSizing`, `SetFrameStrata`, `SetFrameLevel`, `SetHighlightTexture`,
`RegisterEvent`, `SetOwner`, `AddLine`. Run the suite and add only names the real code needs. Add one smoke test that
calling a made-up method on a fake frame raises that error. Model in the fake whatever F2/F3/F4 need: `GetPoint`
returning the five values that were last set (so a save/restore round trip can be asserted), `SetTexture` returning
success, `ClearFocus` firing `OnEditFocusLost` (already there), and a `Fake.MouseDown(frame)` helper.

New smoke tests to add in `test/test_ui.lua` (keep the existing ones passing):
- typing in To opens the list; clicking GO (or Here) closes it and clears focus;
- a drag: call the frame's `OnDragStart` then `OnDragStop` scripts after setting a known point on the fake; the saved
  `GoblinPSDB.positions.planner` holds `point`, `relativePoint`, `x`, `y`;
- a route longer than `Planner.MAX_ROWS`: call `Planner.Refresh` through a plan you construct (or temporarily lower
  `Planner.MAX_ROWS` to 3 for one test and restore it) and assert the last row reads `... and N more steps`;
- a stale recent: put a name that matches nothing at the front of `GoblinPSDB.recents`, focus the empty To box, and
  assert the first offered row is the next real recent.

## F7. Documents

- `CLAUDE.md`, the rule about `API.lua`: say that `API.lua` is the only file that calls Blizzard game APIs and
  registers **game-data events**; UI files may register **UI layout events** (`UI_SCALE_CHANGED`,
  `DISPLAY_SIZE_CHANGED`) for their own frames. Wording only.
- `docs/manual-test-checklist.md`, in `## Planner window (plan 2)`, add as the FIRST two items:
  - `- [ ] Click into the To box: a text cursor appears and typing works (the first thing to check: an EditBox we build without a template)`
  - `- [ ] Drag the window by its body: it follows the mouse from where you grabbed it, no jump, no Lua error`
  and add after the "Click To and type" item:
  - `- [ ] With the results list open, click GO, Here, the layout button or the window body: the list closes`
  and change the existing `/gps selftest` item to also say: `rename GoblinPS\Media\icon.tga away, /reload: the icon texture line must say FAIL (then put it back)`.

## Not to change

`Planner.Debug()` and the smoke test's global `print` swap stay (plan-mandated; the harness catches failures inside
`h.it`, so `print` is restored even when a test fails). `MinimapButton`'s two layout events stay where they are.

## Report

Append a section "Fix round 1" to `D:\goblinps\.superpowers\sdd\2026-09-19-goblinps-planner-window\task-5-report.md`:
per F-item what changed (file:line), RED evidence for each new test that could fail first, GREEN evidence, final Lua
count, luacheck and lua-language-server results, and anything you could not do or chose differently, with why. If a
ruling proves impossible or breaks something it did not anticipate, STOP and report BLOCKED with specifics.

Then reply with ONLY: Status, the commit (short SHA + subject), a one-line test summary, concerns, the report path.

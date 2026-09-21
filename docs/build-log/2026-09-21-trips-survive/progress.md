# SDD ledger — plan: docs/superpowers/plans/2026-09-21-goblinps-trips-survive.md

Branch `trips-survive`, cut from `main` at `1ff0b3c`. Spec:
`docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`,
section "Plan 7" (read; binding).

## Pre-flight scan

### Task pairs that share a file or an interface

| Pair | Produced → consumed | Found |
|---|---|---|
| T1 → T2 | `Core.ClearPin`, `Core.ClearTrip` → `Dash.Stop`, `finish` | Signatures match. T1's own test calls `ns.Dash.Stop()` for cleanup while Stop still only hides; OnHide clears it then. Clean. |
| T1 → T3 | `Core.SaveTrip`, `SavedTripName`, `ClearTrip` → `Core.ResumeTrip` | Match. Clean. |
| T2 → T3 | `Dash.Tick`'s guard and `Dash.Stop`'s reset line | T3 restates both explicitly ("as Task 2 left it") and adds `state.resume`. Clean. |
| T1 → T2, T3 | `test/test_ui.lua`: `waypoint`, `waypointClears` (file-level, T1 Step 1) | Declared at file top beside `pins`, so reachable from the dash block (T2) and the end-of-file describe (T3). Clean. |
| T1 → T3 | `home()`, declared inside T1's `"the trip in progress"` describe | T3 appends its tests into that same describe, so `home()` is in scope. Clean. |
| T3 → T4 | nothing | Documents only. Clean. |

### Each task against its own text

| Task | Found |
|---|---|
| T1 | Tests call exactly the seven functions the code defines. `PlanRoute(Delta)` from `home()` has steps (verified: Delta, Westland resolve; Atlantis does not). Clean. |
| T2 | The rewritten Escape block's four tests match the four code changes. Arrival test builds its own one-step plan with `mx`/`my`, so it does not disturb the shared fixture. Clean. |
| T3 | `Search.Exact` returns a new table per call (checked), but every identity assertion passes the same object through `Resume` / `Destination` / `PlanRoute`; the login test compares by name. `Geo.ToWorld` returns nil for a nil map rather than erroring (checked), so `where.map = nil` is a safe "no position". Clean. |
| T4 | Documents only. Clean. |

### Plan text a reviewer could read as a defect

One. The Global Constraints say nothing but Stop may end a trip, "not
arriving" included, yet `finish()` -- unchanged -- sets `state.plan` to nil on
arrival.

**R1 — arrival clearing the in-memory plan is not "ending the trip".** What
makes a trip survive is its saved destination, and only `Dash.Stop` clears
that. `finish()` leaving the dash on "Arrived." with nothing in memory to tick
is the behaviour the spec itself describes: a reload at the destination replans
from where you stand, finds no steps, and shows "Arrived." again. The
constraint forbids clearing the save, not emptying the tick loop once there is
nowhere left to go. *Cost if wrong:* opening the planner after arriving does
not pre-fill the destination, because `Dash.Destination()` is nil by then.

## Codex's plan-8 geometry landed before this branch was cut

`6ebb83c` "Measure wide planner geometry for approved single-search mockup",
committed on `main` between the spec (`6156fac`) and this plan (`1ff0b3c`), so
it is on this branch too. Verified independently, not from his notes: the wide
key set is exactly the fourteen the brief asked for, the tall section is
byte-identical to `60497c6`, every number is in range, and every content
rectangle sits at 0.00% opaque frame pixels (the two plates on brass by
design). The assembled preview matches the approved design.

**Ruling: R2 — plan 7 runs against a shifted Python/art baseline, and fixes
none of it.** The new wide geometry drops `from_box`, `here_button`,
`layout_button` and `side_panel`, so 8 Python tests (6 failures, 2 errors in
`TestPlannerKeysClassified`, `TestPlannerGeometry`, `TestFrameInterior`) and 6
`check_art.py` geometry checks now fail. That is the tooling correctly
reporting that the layout changed -- the two-sided allow-list named the dropped
keys itself -- and adapting it is plan 8's work. `Data/Art.lua` has not been
regenerated, so the addon and the Lua suite are untouched. Plan 7's gates:
Lua must go green as specified; Python must stay at 43/51 and check_art at
47/6 -- no worse, not repaired. The running Task 1 implementer was told this
mid-task, and told not to run `make_art.py`.
*Cost if wrong:* none to plan 7; `main` stays red on desk tooling until plan 8,
which the owner should know.

### Four facts from Codex's handoff that plan 8's plan must carry

1. `strip_track`'s left and right are the end badges' **centres**; the screen
   already reserves the full sprite at each end. Do not inset twice.
2. `line_thickness` is now **0.02** of canvas width and means the texture's
   **full height including its glow** (0.003 drew the stroke nearly
   invisible). Keep the texture's aspect, tile at that scale, crop only the
   last tile, never stretch a line to a leg's length.
3. Solid and dashed lines tile cleanly -- edges match byte for byte, checked
   by `_planner-line-seams.png`. The brief's one art question is answered.
4. Eleven stops fit at 113 px centre spacing against 96 px rings, all visible,
   names dropped; beyond that badges would have to shrink. Total and warning
   have their own slots below the names; the results list ends above both, so
   the warning stays visible while searching; idle status lines replace the
   strip and are never drawn over a route.

## Task 1 — whose pin, and which trip

BASE `1ff0b3c`. DONE at `d611db9`. Lua 291 -> 297; Python 43/51 and check_art
47/6 unchanged, as R2 requires. Signed `Co-Authored-By: Claude Sonnet 5`
rather than the brief's Opus line: the implementer followed its own
attribution rule, which names the model that did the work. Correct.

Review: spec ✅, approved, **no findings at all**. The reviewer re-ran the Lua
suite itself (297/0), confirmed each half of "only our pin" has a test that
fails without it, checked `WaypointIs`'s field names against Blizzard's own
`WaypointLocationDataProvider.lua`, and traced that `tripSlot()` is a safe
no-op when there is no character key.

Task 1: complete (commits 1ff0b3c..d611db9, review clean)

Controller commit between tasks: `1a305d7` records Codex's verified geometry
and its four drawing facts in the spec. Task 2's BASE is `1a305d7`.

## Task 2 — only Stop ends a trip

BASE `1a305d7`. DONE at `3bdfbad`. Lua 297 -> 300; Python and check_art
baselines unchanged. Review: spec ✅, approved, **no findings**. The reviewer
confirmed `Core.ClearTrip` is called from exactly one place, `Dash.Stop`;
that `finish()` clears the pin and the in-memory plan but never the save (R1
held); that the visibility guard sits above every branch of `Dash.Tick`, so it
covers `zone` and `landed` events as well as the per-frame tick; and diffed
all of `test_ui.lua` to confirm only the Escape block and the one named
message changed.

Task 2: complete (commits 1a305d7..3bdfbad, review clean)

## Task 3 — resume after a reload

BASE `3bdfbad`. DONE at `b790269`. Lua 300 -> 306. Baselines re-checked by me
on this commit: Python 51 run / 8 failing, check_art 47 / 6 -- unchanged.

Review: spec ✅, approved. The reviewer traced the state transitions: arriving
and no-route both leave the save untouched; the only resume path that clears it
is an unresolvable name, with its chat line; no position retries each tick,
while a position with no route plans once and then falls through, so it cannot
hammer the planner. It also credited the planner prefill for *not* calling
`Core.Remember`, which would have polluted the recent destinations.

Task 3: minor (deferred): the "position known, no route" branch of
`tryResume` is verified by inspection only, not by a test. Given it is the
exact don't-hammer-the-planner behaviour the plan calls out, the final review
should decide whether it earns one before merge.

Task 3: complete (commits 3bdfbad..b790269, review clean, 1 minor deferred)

## Task 4 — documents

BASE `b790269`. DONE at `01d5525`. All gates at baseline (Lua 306/0, Python
51/8 failing, check_art 47/6, lint clean). Found and fixed a stale claim the
brief's grep terms missed -- a checklist line saying a reload ends the trip "by
design" -- by reading the whole file.

Task 4: minor (deferred): `GoblinPS/Dash.lua:245` comment "It ends the trip
exactly as Escape does" is now backwards (Escape no longer ends a trip).
Code, so out of a docs-only task's scope; the implementer rightly left it.
Carry to the final fix wave.

Task 4 review: spec ✅, approved. Verified every checklist claim against the
code and swept both files for stale Escape/OnHide/reload/GoblinPSCharDB claims
-- none left.

Task 4: minor (deferred): the `CLAUDE.md` rule says `Dash.Stop` is "the one
place the saved trip ... and the map pin are cleared", but arrival (`finish`)
clears the pin too. The load-bearing half -- only Stop clears the trip -- is
right. The wording came verbatim from **my** plan, so this is my error, not the
implementer's.

Task 4: complete (commits b790269..01d5525, review clean, 1 minor deferred)

## Deferred minors, for the final review to triage

1. Task 3 -- the "position known, no route" branch of `tryResume` has no test.
2. Task 4 -- `Dash.lua:245` comment "ends the trip exactly as Escape does" is backwards.
3. Task 4 -- `CLAUDE.md`'s "only Stop" rule wrongly implies only Stop clears the pin.

## Final whole-branch review — ready with fixes

Reviewed `1ff0b3c..01d5525` on the most capable model. Gates re-run by the
reviewer: Lua 306/0, Python and check_art at baseline, lint clean. It also ran
the new tests in reverse order and twice each: no ordering leak. Stop is the
only end in source; `OnHide` and the Escape registration are gone.

0 Critical, 1 Important, 6 Minor. Both rulings upheld: R1 (the spec itself
says arrival does not end the trip; its two side effects are by design) and R2
(baseline unchanged, documented).

**I1 (Important) — the "your own pin survives" promise overpromises**, in the
checklist, the spec and `CLAUDE.md`. The game holds one user waypoint and every
advance, replan and resume replaces it, so a player's pin survives only if
dropped after GoblinPS last moved it. Its sibling is the Task 4 Minor about my
own `CLAUDE.md` wording: two overpromises from one plan sentence of mine.

**M1 — a real bug:** in `tryResume`, an unknown position for a tick followed by
no route leaves "Waiting..." on screen under "No route found..." until Stop.
The reviewer confirmed it with a probe, and that the planner is called only
once. It lives in exactly the branch the Task 3 Minor said had no test.

**Triage of the three deferred Minors: all three fixed before merge.**

**Ruling: R3 — one fix wave carries I1, M1 plus its missing test, the
backwards `Dash.lua:245` comment, the `CLAUDE.md` pin wording, M5 (the "hidden,
hold still" comment and spec claim more than the code does -- Alt+Z hides the
interface, not the dash's own flag, so events still move a trip), and M6 (a
test that Start Route replaces a *running* trip).** Parked, no code change:
**M4** (our pin record is lost on a reload, so a pre-reload pin can linger
after an early Stop or a resume at the destination; that errs safe, and
whether a waypoint survives a reload at all is a client question -- one
checklist line added to get it answered) and **M7** (resuming by name can pick
a zone over a same-named flight node; by design of the spec).
*Cost if wrong:* M4 means a stray pin a player clears by hand; M7 a resume to
the zone rather than its flight point, then a normal replan.

## Fix wave — landed, re-reviewed clean

`054df6e` (M1 fix + the branch's first no-route test, seen failing first),
`e7a2969` (M6: Start Route replaces a running trip), `b7a9cec` (I1, the stop
comment, the `CLAUDE.md` pin wording, M5 wording, M4's checklist line). Lua
306 -> 308; Python 51/8 and check_art 47/6 unchanged; lint clean.

Scoped re-review: all seven ADDRESSED, no new breakage, every gate reproduced.
It confirmed the no-route test's call count of 1 is a real signal (the code
cannot pass it by never planning), that M5 changed only comments, and that
`ClearTrip` is still called only from `Dash.Stop` and `Core.ResumeTrip`.

**Ruling: R4 — the residual is parked.** The new M1 test restores its
`Core.PlanRoute` stub after one of its assertions, so a failure there would
leak the stub into later tests. Test hygiene only, and not load-bearing: it
can fire only when a test is already failing, so it adds cascading noise but
can never produce a false pass. No second fix wave. Worth a restore-first
`pcall` whenever that test is next touched.
*Cost if wrong:* a confusing cascade of red if that one assertion ever breaks.

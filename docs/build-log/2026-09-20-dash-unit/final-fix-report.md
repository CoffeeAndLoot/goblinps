# Final fix report — `dash-unit`, the single fix wave

Applied against `.superpowers/sdd/2026-09-20-goblinps-dash-unit/final-review.md`
(0 Critical, 4 Important, 6 Minor). All items in that report's Important and
Minor sections are fixed, plus M6 (documentation). Nits (N1-N3) and the two
deferred findings from the earlier ledger were explicitly out of scope per the
review's own recommendation and are untouched.

Verification method: for every finding, the fix's test was run RED against
the pre-fix code and GREEN after. RED was captured by `git stash push --
GoblinPS/Dash.lua GoblinPS/Trip.lua GoblinPS/SelfTest.lua` (reverting only the
three fixed source files, keeping the new tests in place), running the suite,
then `git stash pop` to restore the fixes. One test (M5's) needed a
pcall-wrapped body so a failing assertion couldn't skip its own cleanup and
cascade into later tests — that bug was caught by the RED run itself and
fixed before the numbers below were taken.

## Important findings

### I1 — "Recalculating..." never reached the screen

`GoblinPS/Dash.lua:295-317` (the `recalculate` verdict), `GoblinPS/Dash.lua:49-70`
(`Dash.Refresh`), `GoblinPS/Dash.lua:257-268` (top of `Dash.Tick`).

**Judgement call — how the message survives:** added `state.banner`.
`Dash.Refresh()` now writes `state.banner or (following and "then ..." or "")`
into `ui.next` instead of always the "then ..." text. The recalculate branch
sets `state.banner = "Recalculating..."` and calls `Refresh()`, so the banner
is what's on screen when this tick ends. The *next* call to `Dash.Tick` (the
very next tick, or the next trip event) clears the banner and calls
`Refresh()` again *before* deciding that tick's verdict — so the banner is
guaranteed at least one full tick on screen and cannot outlive the change it
announced, however long the player then stays on the new route. I chose a
tick-scoped flag over a timer because `Dash.TICK` (0.5s) is already the
addon's unit of "a frame is jitter, not accuracy" (see the comment on
`Dash.TICK`), so tying the banner's lifetime to ticks rather than wall-clock
seconds needed no new concept.

Test: `test/test_ui.lua:760` ("shows Recalculating for the tick a stray is
caught, and lets it go on the next one"), using a real reroute through
`Core.PlanRoute` over the fake world (walking from near the North Gate
crossing out to world 0,0 on map 1, exceeding `STRAY_YARDS`).

RED (`git stash` of the three source files):
```
FAIL: the dash unit drives the trip :: shows Recalculating for the tick a stray is caught, and lets it go on the next one
    test/test_ui.lua:780: the player must see the banner on the tick the stray is caught, got "nil"
```
GREEN: passes; full suite 235/235.

### I2 — the map pin did not move after a recalculation

`GoblinPS/Dash.lua:301`: `ns.Core.PinStep(replanned.result.steps[1])` added to
the success branch of the `recalculate` verdict, alongside the existing pin
call in the `advance` branch (`:292`).

Test: `test/test_ui.lua:790` ("re-pins the replanned route's first step, not
just the trip's very first one") — same stray-and-reroute setup as I1, then
asserts the pin count grew.

RED:
```
FAIL: the dash unit drives the trip :: re-pins the replanned route's first step, not just the trip's very first one
    test/test_ui.lua:801: a replan must re-pin its new first step, per spec decision 3, got "false"
```
GREEN: passes.

### I3 — the compass ignored `Trip.ROTATION_SIGN` (fixed most carefully, per instruction)

`GoblinPS/Trip.lua:64-70`: added `Trip.CompassAngle(facing)`, returning
`Trip.ROTATION_SIGN * -(facing or 0)` — the same constant `ArrowAngle` uses,
with the same "unknown facing means north" default `aimArrow` already
assumed. `GoblinPS/Dash.lua:242`:
`ui.compass:SetRotation(ns.Trip.CompassAngle(ns.API.PlayerFacing()))` replaces
the hard-coded `-(ns.API.PlayerFacing() or 0)`.

I put the helper in `Trip.lua` beside `ArrowAngle` rather than inlining the
formula in `Dash.lua`, since it's pure maths with no Blizzard dependency —
the same reasoning `ArrowAngle` itself was built on — and it gets its own
unit test independent of the frame stack.

Checklist wording check (per instruction): `docs/manual-test-checklist.md:338-339`
tells the tester "If it turns the wrong way, flip Trip.ROTATION_SIGN and
nothing else." That sentence is now true — flipping the constant moves the
arrow and the compass together, since both read `Trip.ROTATION_SIGN`. No
wording change was needed.

Tests:
- `test/test_trip.lua` (`Trip.CompassAngle` describe block): the third case,
  "flips together with ROTATION_SIGN instead of a sign hard-coded against
  it", mutates `Trip.ROTATION_SIGN` and checks the output flips — this is the
  one that would have passed against the *old* hard-coded formula if it only
  checked the default sign.
- `test/test_ui.lua:646` ("turns the compass by Trip.ROTATION_SIGN too, so
  flipping it moves both together") — the integration-level version, through
  `Dash.Tick` and a real frame.

RED:
```
FAIL: Trip.CompassAngle :: turns opposite our own facing
    test/test_trip.lua:75: attempt to call field 'CompassAngle' (a nil value)
FAIL: Trip.CompassAngle :: defaults to north when facing is unknown
    test/test_trip.lua:78: attempt to call field 'CompassAngle' (a nil value)
FAIL: Trip.CompassAngle :: flips together with ROTATION_SIGN instead of a sign hard-coded against it
    test/test_trip.lua:90: attempt to call field 'CompassAngle' (a nil value)
FAIL: the dash unit drives the trip :: turns the compass by Trip.ROTATION_SIGN too, so flipping it moves both together
    test/test_ui.lua:660: flipping ROTATION_SIGN, the checklist's own remedy for the arrow, must flip the compass with it
    expected: "0.4"
    actual:   "-0.4"
```
(The first three fail on a missing function because `Trip.CompassAngle` did
not exist pre-fix, which is itself a form of RED — the fourth is the
sign-value RED against the old formula.)
GREEN: all four pass.

### I4 — a failed arrow texture destroyed its own fallback

`GoblinPS/Dash.lua:120-130`: added the missing `else` branch —
`arrow:SetTexture("Interface\\Buttons\\WHITE8X8")` — when `arrowPart` is
absent or `SetTexture(MEDIA .. arrowPart.file)` returns false, matching what
the `art()` helper (`:29-47`) already does for every other part.

Test: `test/test_ui.lua:851` ("keeps the flat placeholder when the arrow's
own texture will not load"), using `Fake.missingTextures` on the arrow's
path, same technique as the existing `dash-body` fallback test.

RED:
```
FAIL: the dash art :: keeps the flat placeholder when the arrow's own texture will not load
    test/test_ui.lua:863: a failed arrow texture must fall back to the flat placeholder
    expected: "Interface\\Buttons\\WHITE8X8"
    actual:   "Interface\\AddOns\\GoblinPS\\Media\\arrow"
```
GREEN: passes.

## Minor findings

### M1 / M2 — stale distance and ETA

`GoblinPS/Dash.lua:68-69`: `Dash.Refresh()` now clears `ui.distance` and
`ui.eta` unconditionally. `Refresh()` is the one function called at every
"the step or trip just changed" site — `Dash.Start`, the `advance` verdict,
and the `recalculate` verdict — so adding the clear there covers both M1 (a
fresh trip) and M2 (one tick after advance/recalculate) without new state.

Tests: `test/test_ui.lua:711` ("clears the previous trip's distance and ETA
when a new one starts") and `:723` ("clears distance and ETA for the tick
after an advance, not the old step's numbers").

RED:
```
FAIL: the dash unit drives the trip :: clears the previous trip's distance and ETA when a new one starts
    test/test_ui.lua:719: a fresh trip must not show the last trip's distance
    expected: ""
    actual:   "700 yd"
FAIL: the dash unit drives the trip :: clears distance and ETA for the tick after an advance, not the old step's numbers
    test/test_ui.lua:732: the old step's distance must not sit under the new step's name
    expected: ""
    actual:   "700 yd"
```
GREEN: both pass. (I did not add a separate test for the `recalculate` branch
clearing distance/ETA — it goes through the same `Refresh()` call as
`advance`, already covered above and by the I1/I2 recalculate tests, which
would show a stale distance if `Refresh()` ever stopped clearing it.)

### M3 — Escape hid the dash without ending the trip

**Judgement call — what Escape now does:** I made Escape end the trip, the
same as Stop. `GoblinPS/Dash.lua:86-93`: added `f:SetScript("OnHide", ...)`
that clears `state.plan/index/best/banner`. `Dash.Stop()` (`:211-218`) is now
just `ui.frame:Hide()`, trusting `OnHide` to do the clearing — so Escape
(which only ever calls `:Hide()` via `UISpecialFrames`) and the Stop button
end a trip through the identical code path.

I chose "Escape ends the trip" over "the window can be reopened" because the
device has exactly one way back once hidden today — pressing GO again from
the planner — and that already starts a *new* trip, discarding whatever was
running. Building a second way to reopen the same dash (a minimap toggle, a
slash command) is new UI surface nothing in this plan or the spec asks for,
and would be scope creep against YAGNI. Making Escape behave like the button
already on the frame is the smaller, honest fix: the trip and the window it
lives in now have the same lifetime, which is what the finding asked for.

Test: `test/test_ui.lua:806` ("ends the trip like Stop does, so no hidden
trip keeps ticking or replanning unseen") — hides the frame directly (what
`UISpecialFrames` does on Escape) and checks the trip state is gone, then
ticks once more to confirm nothing resurrects or errors.

RED:
```
FAIL: the dash unit and Escape :: ends the trip like Stop does, so no hidden trip keeps ticking or replanning unseen
    test/test_ui.lua:812: the trip must not outlive the window it belongs to, got {level="60", result={...}, to={...}}
```
GREEN: passes.

### M4 — `SelfTest.lua` hard-errors when `Data/Art.lua` is absent

`GoblinPS/SelfTest.lua:20`: `pairs(ns.Data.Art)` → `pairs(ns.Data.Art or {})`,
matching the guard `Dash.lua` already uses (`ns.Data.Art and ...`).

Test: `test/test_ui.lua:906` ("loads without hard-erroring when Data/Art.lua
has not been generated yet") — loads `SelfTest.lua` fresh into a namespace
with `Data = {}` (no `Art` key) and asserts the load doesn't error and `Run`
is still defined.

RED:
```
FAIL: SelfTest.lua without generated art :: loads without hard-erroring when Data/Art.lua has not been generated yet
    test/test_ui.lua:916: GoblinPS/SelfTest.lua:20: bad argument #1 to 'pairs' (table expected, got nil), got "false"
```
GREEN: passes.

### M5 — a failed replan re-ran Dijkstra every tick

`GoblinPS/Dash.lua:308-316`: the `recalculate` verdict's new `else` branch
(when `replanned.result` is nil — no route at all) sets
`state.best = ns.Trip.DistanceTo(pos, step)`, i.e. treats the player's
current spot as the new baseline, the same reset a *successful* recalculation
already does to `state.best`. That means another full `STRAY_YARDS` (400
yards) of wandering is required before `Trip.Check` returns "recalculate"
again — no new timer or counter, reusing the mechanism that already exists
for the success path.

Test: `test/test_ui.lua:736` ("backs off after a replan finds no route,
instead of retrying every tick") — stubs `ns.Core.PlanRoute` to always report
no route, counts calls across three ticks at a fixed stray distance.

RED:
```
FAIL: the dash unit drives the trip :: backs off after a replan finds no route, instead of retrying every tick
    test/test_ui.lua:757: test/test_ui.lua:754: a failed replan must back off, not re-run Dijkstra every tick
    expected: "1"
    actual:   "2"
```
GREEN: passes (`calls` stays at 1 across the third tick).

Note: this test's stub is restored inside a `pcall`-wrapped body specifically
so a failing assertion here can't skip the restore and corrupt
`ns.Core.PlanRoute` for the tests that follow — the first RED run (before
this wrapping was added) demonstrated exactly that cascade, corrupting the
next two tests with misleading, unrelated-looking failures. Fixed before
taking the final RED/GREEN numbers above.

### M6 — documentation overstating what's verified

- `CLAUDE.md:17-19`: split the status line so plan 4 (the dash unit) is
  called out as "built and tested on the desktop only — unverified in
  game", separate from the plans 1-3 clause that legitimately says
  "confirmed in the client".
- `docs/superpowers/plans/2026-09-20-goblinps-dash-unit.md`: fixed both
  remaining copies of "closes when you get there" / "the device closes" (the
  Goal sentence and the plan's embedded checklist item) to match the wording
  already corrected in `docs/manual-test-checklist.md:351-352`.

No test applies to documentation; verified by grep after the edit
(`closes when you get there|device closes|Arrived and the device` — no
matches left in the plan doc, the checklist, or the spec).

## Gate counts

```
python -c "... test/run.lua ..."           -> 235 passed, 0 failed   (was 223)
python -m unittest discover -s test/tools  -> Ran 27 tests ... OK    (unchanged)
python tools/check_art.py                  -> 39 pass, 0 with problems, 0 not drawn yet (unchanged)
luacheck GoblinPS test tools                -> Total: 0 warnings / 0 errors in 39 files
lua-language-server --check D:\goblinps     -> Diagnosis completed, no problems found ([])
```

## What I did not do / did differently

- Did not touch the three Nits (N1 `Dash.TICK` vs. the spec's "about once a
  second", N2 `PlayerFacing()` called twice per tick in `aimArrow`, N3
  neither `finish()` nor `Stop()` clears Blizzard's waypoint) or the two
  deferred findings (Task 3's API test, Task 5's `else` branch) — the review
  explicitly said not to block on these and recommended against churn on
  Task 5's fall-through in particular.
- Did not add a distinct test for `recalculate`'s M1/M2 distance/ETA clear
  beyond what I1/I2's recalculate tests already exercise through the shared
  `Refresh()` call — adding one would have duplicated the same assertion
  against the same code path.
- `GoblinPS/Data/Art.lua`, `tools/`, `GoblinPS/Media/` — untouched, per the
  standing rule that generated files are never hand-edited.
- `AGENTS.md` — left untracked and unstaged, per standing instruction.
- Nothing pushed, merged, or branched. Two commits landed on `dash-unit`:
  one for the code + tests, one for the documentation.

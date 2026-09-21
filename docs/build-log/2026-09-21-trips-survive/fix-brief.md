# Fix wave — plan 7, trips that survive

The **one and only** fix wave for this branch. Everything below lands. The
reviewer's full argument is in `final-review.md` beside this file.

Branch `trips-survive`, BASE `01d5525`. Work in `D:\goblinps`.

## Ground rules

- **`API.lua` is the only file that calls Blizzard game APIs.**
- **Only Stop ends a trip.** Only `Dash.Stop` clears the saved trip, apart from
  `Core.ResumeTrip` dropping a name that no longer resolves, with its chat line.
- **Clear only a map pin that is still ours.**
- **Zero luacheck warnings, zero language-server warnings, no lint
  suppression.** Run both **from PowerShell, never Git Bash**.
- **Do not run `python tools/make_art.py`.** It would regenerate `Data/Art.lua`
  from plan 8's new geometry and break the current planner.
- Nothing may say plan 7 has run in the client. It has not.

## Gates

Lua suite (baseline **306 passed, 0 failed**, rising by the tests you add),
`python -m unittest discover -s test/tools` (**51 run, 8 failing** -- a known,
intended baseline pending plan 8; must stay exactly that), `python
tools/check_art.py` (**47 pass, 6 with problems** -- same), luacheck (0
warnings in 38 files) and lua-language-server (clean).

`test/test_ui.lua`'s tests share state and run in order: every new test leaves
position, dash, saved trips, planner destination and pin as it found them.

---

## IMPORTANT — the "your own pin survives" promise overpromises

`docs/manual-test-checklist.md` (around line 377) says "Drop your own map pin
mid-trip, then arrive or press Stop: your pin is still there". The spec (around
line 146) and `CLAUDE.md` (around line 260) say the same.

The game holds **one** user waypoint. Every advance, replan and resume replaces
it through `Core.PinStep`. So a pin the player drops mid-trip survives only if
it was dropped **after GoblinPS last moved the pin** -- the next time the dash
advances or replans, GoblinPS's own pin replaces it. The code is right; the
promise is wrong, and a tester would spend game time on a check whose answer is
"by design".

**Reword all three** to what is true: ending the trip (Stop or arrival) never
clears a pin the player set *since GoblinPS last moved it*; the dash does take
the waypoint back the next time it advances or replans, because the game has
only one. The checklist line should describe a check a tester can actually run:
drop your own pin after the last step starts, then arrive (or press Stop), and
it is still there.

## MINOR (a real bug) — "Waiting..." outlives a failed resume

In `tryResume` (`GoblinPS/Dash.lua`, around lines 429-441): if the position was
unknown for a tick (so `ui.distance` was set to "Waiting...") and then a route
turns out not to exist, `ui.steps[1]` shows "No route found..." but
`ui.distance` still says "Waiting..." until Stop. The reviewer confirmed it
with a probe.

**Fix:** when the no-route branch shows its message, clear `ui.distance` (and
anything else the waiting state set). **Add the test the branch never had:**
resume towards a destination with a position known but no route, and assert
the message is shown, "Waiting..." is gone, no plan is running, the saved trip
is **kept**, and the planner is asked only once across several ticks. Make it
fail against the current code first -- run it before your fix and quote the
failure.

To get "a position but no route" in the fake world, find a destination the
fixture cannot reach -- a place on another continent with no connecting link,
or stub `Core.PlanRoute` for the one test and restore it after. Use whichever
is honest; say which you chose.

## MINOR — a comment that says the opposite of the branch's rule

`GoblinPS/Dash.lua` around line 245, over the stop button: "It ends the trip
exactly as Escape does." Escape no longer touches the dash. Correct it to say
the button is the one way a trip ends.

## MINOR — `CLAUDE.md`'s rule implies only Stop clears the pin

The "Only Stop ends a trip" rule says `Dash.Stop` is "the one place the saved
trip ... and the map pin are cleared". Arrival (`finish()`) clears the pin
too, and an agent following that sentence literally could remove the pin clear
from `finish()`. **Reword:** only `Dash.Stop` clears the saved trip; Stop and
arrival both clear the map pin, and only a pin GoblinPS set. Fold in the
IMPORTANT correction above while you are in that bullet.

## MINOR — "hidden, hold still" claims more than the code does

The guard in `Dash.Tick` checks the dash's own shown flag. Alt+Z hides the
whole interface, not that flag, so zone and landing events still move a trip
along while the interface is hidden. That is harmless -- arguably right, the
trip keeps up with you -- but the comment above the guard, and the spec's
"While hidden it does not tick", say more than the code does. **Correct both to
what is true:** a dash hidden by itself holds still; hiding the whole interface
does not stop the trip. Change no behaviour.

## MINOR — the test for Start Route replacing a trip

The spec asks for a test that Start Route replaces a **running** trip's saved
destination. The existing test starts from no trip. **Add one:** save a trip to
one destination, start a route to another with `Core.Go`, and assert the saved
destination is the new one. Clean up after.

---

## Not in this wave, recorded

- **M4 — the pin set before a reload can linger.** `Core`'s record of our pin
  is in memory and gone after a reload, so Stop before the resumed trip plans,
  or a resume at the destination, leaves the pre-reload pin on the map. That
  errs on the safe side (never clears a pin that might be the player's), and
  whether a waypoint even survives a reload on this build is a client question.
  No code change. Add **one checklist line** asking the tester to note whether
  the pin is still on the map right after a `/reload`, so the question gets
  answered.
- **M7 — resuming by name can pick a zone over a same-named flight node.** By
  design of the spec. No change.

## Commits

Group them sensibly -- the bug and its test, the tests for Start Route, the
wording across the docs and comments. **Stage explicit paths on every commit**,
never `git add -A`, and **never stage `AGENTS.md`**. Do not push.

## Report

Write it to `.superpowers/sdd/2026-09-21-goblinps-trips-survive/fix-report.md`
and return only: status, commits, a one-line gate summary, concerns. In the
report, say for each finding what changed and which test covers it, quote the
new no-route test failing before the fix, and name anything you found in these
files that this wave did not address.

Do not dispatch subagents.

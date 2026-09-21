# Fix wave report — plan 7, trips that survive

Branch `trips-survive`, base `01d5525`. This is the single permitted fix wave
from `fix-brief.md`; nothing here has run in the client.

## Status

Done. Every finding in the brief is addressed. All gates pass or match their
known baseline exactly (see below). `AGENTS.md` was never staged.

## Findings, what changed, and what covers each

**IMPORTANT — the "your own pin survives" promise overpromises.**
Reworded the three places that overpromised: `docs/manual-test-checklist.md`
(the "Drop your own map pin" line), the spec
`docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md` (its
in-game line, "In game" section), and `CLAUDE.md`'s "Only Stop ends a trip"
rule. All three now describe a check a tester can actually run: drop your own
pin on the last step, then arrive (or press Stop), and it is still there —
because GoblinPS moves the one user waypoint on every advance, replan and
resume, so an earlier pin would just get overwritten by design. Documentation
only; no test (there is nothing in code to test — the code was already
right, only the promise was wrong).

**M1 (Minor, a real bug) — "Waiting..." outlives a failed resume.**
Fixed in `GoblinPS/Dash.lua`, `tryResume`'s no-route branch: added
`ui.distance:SetText("")` right after the "No route found" message is set,
clearing whatever the earlier "Waiting..." state left showing.

Covered by the new test in `test/test_ui.lua`, `"the trip in progress" ::
"clears the stale Waiting... when a resume's position has no route"`. The
fixture's rough-route fallback (`Graph.Build`'s `opts.rough` branch) reaches
every zone on this two-continent fixture map — I verified this directly
(scratch script, since deleted) before writing the test: every zone and stop
in `test/fake_world.lua` resolved to a successful `Core.PlanRoute` result from
the home position, including "Lostland", which the fixture's own comments
call "a hole in the [crossings] table". So there is no real unreachable
destination to route to on the desk. Per the brief's own permission, I
**stubbed `ns.Core.PlanRoute`** for this one test (counting calls, returning a
plan with `result = nil` and a fixed note) and restored the real function
immediately after. That is the honest option here — the alternative (hunting
for a fixture destination that fails) doesn't exist without changing
`fake_world.lua`, which is out of scope.

Seen failing against the unfixed code, exactly as required:

```
FAIL: the trip in progress :: clears the stale Waiting... when a resume's position has no route
    test/test_ui.lua:2187: Waiting... must not outlive the no-route message
    expected: ""
    actual:   "Waiting..."
```

After the fix: 307 passed, 0 failed (this test alone; 308 with M6's test
also added).

**M2 (Minor) — a comment that says the opposite of the branch's rule.**
`GoblinPS/Dash.lua`, the stop button's comment (around line 245): changed
"It ends the trip exactly as Escape does" to "It is the one way a trip ends
now that Escape does not touch the dash." Comment only; no behaviour, no
test.

**M3 (Minor) — `CLAUDE.md`'s rule implies only Stop clears the pin.**
Folded into the IMPORTANT fix above: `CLAUDE.md`'s "Only Stop ends a trip"
bullet now says only `Dash.Stop` clears the saved trip; Stop **and arrival**
both clear the map pin, and only a pin GoblinPS set. Documentation only.

**M5 (Minor) — "hidden, hold still" claims more than the code does.**
Reworded the comment above the guard in `Dash.Tick` (`GoblinPS/Dash.lua`) and
the spec's "While hidden it does not tick" line
(`docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`).
Both now say what the code does: a dash hidden by itself (`ui.frame:IsShown()`
false) holds still; hiding the whole interface (Alt+Z) does not, because
`API.OnTripEvent` still calls `Dash.Tick` on zone changes and landings
underneath the guard. No behaviour changed — confirmed by the full desk suite
staying green before and after this edit.

**M6 (Minor) — the test for Start Route replacing a trip.**
Added `test/test_ui.lua`, `"the trip in progress" :: "replaces a running
trip's saved destination when Start Route runs again"`: starts a route to
Delta with `Core.Go`, then a second route to Bravo, and asserts
`Core.SavedTripName()` is now "Bravo".

**M4 — not in this wave, recorded.** No code change, per the brief. Added one
checklist line to `docs/manual-test-checklist.md` asking the tester to note
whether the pin from before a `/reload` is still on the map right after the
reload, so the open question (whether a user waypoint survives a `/reload` at
all on this build) gets answered next session.

**M7 — resuming by name can pick a zone over a same-named flight node.** By
design of the spec, per the review. No change made; nothing in this wave
touches it.

## What this wave did not address

Nothing beyond what the brief scoped out (M4, M7, both explicitly deferred by
the brief itself). I did not find any other wording or behaviour issue in the
files the brief named (`Dash.lua`, `Core.lua`, `CLAUDE.md`,
`docs/manual-test-checklist.md`, the plan-8 planner-redesign spec) beyond the
six findings above.

## Commits (newest last)

1. `054df6e` — Fix: Waiting... outlives a resume that finds no route.
   `GoblinPS/Dash.lua` (the one-line fix) + `test/test_ui.lua` (the M1 test).
2. `e7a2969` — Test: Start Route replaces a trip already running.
   `test/test_ui.lua` only (M6).
3. `b7a9cec` — Docs: correct wording that outran the code.
   `CLAUDE.md`, `GoblinPS/Dash.lua` (M2 + M5 comments),
   `docs/manual-test-checklist.md`, and the plan-8 planner-redesign spec
   (I1, M3, M4's checklist line, M5's spec line).

All three staged explicit paths, never `git add -A`. `AGENTS.md` was never
staged. Nothing pushed.

## Gates

| Gate | Result |
|---|---|
| Lua (lupa) | 308 passed, 0 failed (baseline 306 + 2 new tests: M1, M6) |
| `python -m unittest discover -s test/tools` | 51 run, failures=6, errors=2 — unchanged from the known baseline |
| `python tools/check_art.py` | 47 pass, 6 with problems, 0 not drawn yet — unchanged from the known baseline |
| luacheck (PowerShell) | 0 warnings / 0 errors in 38 files |
| lua-language-server (PowerShell, repo root) | "Diagnosis completed, no problems found" |

`tools/make_art.py` was never run. No file under `tools/`, `test/tools/` or
`images/` was touched; `GoblinPS/Data/Art.lua` was not regenerated.

## Concerns

None that block. Two things worth the owner's attention, both already flagged
by the review and left alone by design:

- M4 (pin bookkeeping lost on reload) and M7 (name resolution ties) are
  unresolved by choice, not oversight — see above.
- The reworded pin-promise checklist lines still cannot be checked until
  someone runs plan 7 in the client, which this wave does not do and does not
  claim to do.

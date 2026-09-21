# Final whole-branch review: `trips-survive` (1ff0b3c..01d5525)

Reviewer: final review, 2026-09-21. Read: the plan, spec section "Plan 7", the
ledger, the full branch diff, `CLAUDE.md`, and the current `Dash.lua`,
`Core.lua`, `API.lua`, `Search.lua` and `test/test_ui.lua` in full where the
diff touches them. Nothing fixed, nothing committed.

## Verdict: ready with fixes

The code does what the spec says, in source. Stop is the only caller of
`Core.ClearTrip` apart from the unresolvable-name path in `Core.ResumeTrip`,
which prints its chat line. Every gate matches what was claimed. The fixes are
small: two comments or doc lines that now say the wrong thing, one checklist
line that will cost a wasted in-game check, and one stale "Waiting..." on the
dash with the missing test that would have caught it. **None of this has run in
the client, and nothing in the branch says it has.**

## Gates, observed myself

| Gate | Result |
|---|---|
| Lua (lupa) | **306 passed, 0 failed** |
| `python -m unittest discover -s test/tools` | **51 run, FAILED (failures=6, errors=2)**, the R2 baseline |
| `python tools/check_art.py` | **47 pass, 6 with problems, 0 not drawn yet**, the R2 baseline |
| luacheck (PowerShell) | **0 warnings / 0 errors in 38 files** |
| lua-language-server (PowerShell, repo root) | **"Diagnosis completed, no problems found"** |

The baseline is unchanged by construction as well as by observation. The
branch diff touches nothing under `tools/`, `test/tools/` or `images/`, and
`Data/Art.lua` was not regenerated. I did not run `make_art.py`.

Ordering check (scratch runner, since deleted): I ran the whole suite with the
tests of "the dash unit and Escape" and "the trip in progress" in **reverse
order** (306/0), and again with **each of those 15 tests run twice in a row**
(321/0). I found no ordering leak.

## Stop is the only end: the trace

| Path | Clears the save? | Clears the pin? | Notes |
|---|---|---|---|
| `Dash.Stop` (Dash.lua:354) | yes, `Core.ClearTrip` | yes, `Core.ClearPin` (only if ours) | also clears `state.resume` |
| `finish()` (Dash.lua:412) | no | yes, `ClearPin` | empties the in-memory plan (R1) |
| `tryResume` no position (:430) | no | no | keeps `state.resume`, retries next tick |
| `tryResume` no route (:438) | no | no | drops `state.resume`, so it plans once |
| `tryResume` zero steps (:442) | no | via `finish` | |
| `Core.ResumeTrip` unresolvable (Core.lua:188) | yes | no | prints the plain chat line |
| `Core.Go` (Core.lua:199) | overwrites with the new destination | `PinStep` overwrites | `Dash.Start` clears `state.resume` |
| `OnHide` | gone | gone | `CloseOnEscape(f, "GoblinPSDash")` is gone; `GoblinPSDash` is out of both lint configs |
| `Dash.Tick` failed replan (:513) | no | no | resets `best` only |
| straying / recalculate success (:502) | no | `PinStep` moves it | |

`grep ClearTrip` over `GoblinPS/` finds exactly Dash.lua:357 and Core.lua:190.
**Verified in source.**

## Findings

### Critical

None.

### Important

**I1. The checklist promises more than the code does about the player's own
pin.** `docs/manual-test-checklist.md:377` says "Drop your own map pin
mid-trip, then arrive or press Stop: your pin is still there". The client holds
one user waypoint. Every advance (Dash.lua:497), every successful replan (:506)
and a resume (:448) calls `PinStep`, which overwrites it. The player's pin
survives only if it was dropped **after the last pin move**: on the last step,
for arrival, or with no advance before Stop. A tester who drops a pin and
walks two more steps will see it gone and report a bug that is really by
design, or will see it survive by luck and tick the box without testing
anything. The spec's own line (spec:146) is also loose. Game time is the
scarce resource here, so reword the line before merge, e.g. "on the last step,
drop your own map pin, then arrive (or press Stop): your pin is still there".
The `CLAUDE.md` rule's "a waypoint the player dropped mid-trip is theirs"
(CLAUDE.md:260) has the same gap; see M3.

### Minor

**M1. A stale "Waiting..." under "No route found" on resume** (Dash.lua:429-441).
When at least one tick had no position, `tryResume` sets `ui.distance` to
"Waiting...". When the position then arrives and there is no route, it writes
the note into `steps[1]` and returns without clearing `distance`. I confirmed
this with a probe in a scratch copy. After 1 tick with no position and 3 with a
position, `PlanRoute` was called **once**, so the no-hammering behaviour holds.
The dash then reads "No route found to Delta." with "Waiting..." still showing,
and stays that way until Stop. The fix is one line (`ui.distance:SetText("")`
in that branch). This is deferred Minor 1 with a real bug inside it.

**M2. The stop button's comment is backwards** (Dash.lua:245): "It ends the trip
exactly as Escape does." This is deferred Minor 2.

**M3. The `CLAUDE.md` rule wrongly implies only Stop clears the pin**
(CLAUDE.md:258-261). This is deferred Minor 3. See the triage below.

**M4. After a reload, "ours" is forgotten until the resumed trip pins again**
(Core.lua:123, 141-146). `lastPin` lives in memory. After a reload,
`Core.ClearPin` does nothing until `tryResume` has planned and called `PinStep`.
Three cases follow:
- **Normal resume.** Nothing breaks. `PinStep(steps[1])` overwrites the
  pre-reload pin (one waypoint) and records it as ours. Correct.
- **Stop before the resume has planned** (still "Waiting...", or in an
  instance). The pin set before the reload stays on the map. The same happens
  after a no-route resume.
- **Resuming at the destination** (zero steps, `finish` → `ClearPin`). The
  pre-reload pin stays too.

This errs on the safe side of the rule: it never clears a pin that might be the
player's. It does contradict the checklist line "Press Stop: ... the map pin
clears" (checklist:373) in those cases. Two things can only be settled in the
client: **whether a user waypoint survives a `/reload` or a logout on this
build at all**, and whether `GetUserWaypoint` hands back the exact fractions
`SetWaypoint` was given (the 1e-4 tolerance in `API.WaypointIs` assumes it
does). This does not block merge. If it matters, save the pin alongside
`trips[key]` later.

**M5. The dash only holds still when it is hidden itself.** Dash.lua:454-458
says "Hidden ... hold still, so a trip never replans or moves the map pin
where nobody can see", and the spec says "While hidden it does not tick". The
guard is `ui.frame:IsShown()`, the frame's own flag. Alt+Z hides `UIParent`
and leaves the dash's `IsShown()` true. `OnUpdate` should stop, because the
frame is not visible (standard WoW behaviour, unverified on this build). But
`API.OnTripEvent` still calls `Dash.Tick` on zone changes and landings, so
under Alt+Z the trip can advance, replan and move the pin. That behaviour is
harmless, arguably good. The comment claims more than the code does. Nothing
hides the dash's own frame mid-trip any more, so this guard is now mostly a
safety net.

**M6. One spec desk test is only half covered.** Spec:137 asks for "Start Route
replaces a running trip's saved destination". The test "saves the destination
when a route starts" calls `Core.Go` with no trip running, so replacing a
running trip (and `Dash.Start` clearing a pending `state.resume`) is verified
by inspection only. It is a trivial overwrite, so this does not block.

**M7. A saved name can resolve to a different item** (Core.lua:186). The trip is
saved by name and resolved again with `Search.Exact`, which prefers a zone on a
name tie and the lowest nodeID among flight nodes. A destination picked as a
flight node that shares its name with a zone would resume as the zone. That is
the spec's chosen design ("only the destination, by name"). I note it and
recommend no change. A nil faction at `PLAYER_LOGIN` cannot falsely drop a
trip, because `legal()` treats nil as "all factions". Verified in source.

## Triage of the three deferred Minors

1. **No test for `tryResume`'s "position known, no route" branch.** **Fix before
   merge.** The test was not needed to prove the no-hammering: my probe shows
   one `PlanRoute` call over three ticks. It is needed because the branch
   *does* have a bug (M1, the stale "Waiting..."). The plan names this
   behaviour as its risk, and the fix plus a test is about ten lines. The test
   should stub `ns.Core.PlanRoute` for a no-route answer (restoring it after),
   tick once with no position and then twice with one, and assert one call,
   the note in `steps[1]`, an empty distance, and `Destination()` nil.
2. **The Dash.lua:245 comment "ends the trip exactly as Escape does".**
   **Fix before merge.** It is a one-line comment, but it states the opposite
   of the branch's central rule, in the very function that enforces it. The
   next agent to read it gets the model backwards.
3. **`CLAUDE.md` says `Dash.Stop` is the one place the pin is cleared.**
   **Fix before merge.** `CLAUDE.md` is the rulebook agents obey. A future
   agent "complying" with it could delete `ClearPin` from `finish()` and break
   the spec's arrival behaviour. Suggested wording: "`Dash.Stop` is the one
   place the saved trip is cleared; Stop and arrival clear the map pin, and
   only a pin GoblinPS set (one the player dropped after GoblinPS last moved
   the pin is theirs)." The wording came from the plan, so correct the plan
   text too if it is kept as reference.

## The two rulings

**R1 (arrival emptying the in-memory plan is not "ending the trip"): upheld.**
The spec says so directly (spec:69-72): "The trip itself is not ended by
arrival ... No special case." The Global Constraint forbids ending the trip or
clearing its save, and the save is untouched. Two consequences the owner
should know, both by design:
- after arriving, `Dash.Destination()` is nil, so the planner does not
  prefill;
- the save survives arrival. A player who arrives, walks off without pressing
  Stop and later reloads gets steered back to the old destination, while
  without the reload the dash just sits on "Arrived.".

The design accepts both; neither is a defect.

**R2 (running against a known-red desk-tooling baseline): upheld.** I verified
that the branch touches no tooling, test-tooling or image file, that
`Art.lua` is not regenerated, and that both reds match the baseline exactly
(51/8, 47/6). The cost R2 names is real and correctly disclosed in `CLAUDE.md`
and the spec: `main` stays red on desk tooling until plan 8 lands.

## Documentation honesty

`CLAUDE.md:49` ("**Plan 7 has not been run in the client**"), the checklist
section header ("not yet run in the client") and the spec ("Built 2026-09-21
-- not yet run in the client") are all correct. Nothing claims plan 7 ran in
game. The stale "reload ends the trip, by design" checklist line was fixed.
`docs/later.md`'s pin entry had already been removed on `main` (`6156fac`).
`GoblinPSCharDB` no longer appears in `CLAUDE.md` or the addon code.

## What can only be settled in the client

- Escape and Alt+Z leave the dash up (off `UISpecialFrames` is verified in
  source only).
- `PLAYER_LOGIN` resume: the dash appears, waits and then pins. The timing of
  `UnitName`/`GetRealmName`/`UnitFactionGroup` at that moment is assumed.
- `C_Map.ClearUserWaypoint` / `GetUserWaypoint` behave as the forever source
  says, and a waypoint round-trips within 1e-4.
- Whether the user waypoint itself persists across `/reload` or a logout (M4).
- `OnUpdate` stops under Alt+Z; event-driven ticks continue (M5).

## The single thing most worth the owner's attention

**The player's-own-pin promise (I1).** In code, "clear only our pin" is
correct. But the game keeps one user waypoint, and GoblinPS moves it on every
step, so a pin the player drops mid-trip survives only if it was dropped after
the last move. The checklist, the spec's in-game line and the new `CLAUDE.md`
rule all say it survives in general. Reword them before the next game session,
or the tester will spend game time on a check whose answer is "by design".

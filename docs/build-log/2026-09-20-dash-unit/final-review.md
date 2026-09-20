# Final whole-branch review — `dash-unit` (74606ed..61583d0)

Reviewer: final-review agent, 2026-09-20. Read-only on the repo apart from the
two deliberate mutations reported at the end, both restored.

**Verdict: ready with fixes.**

The branch is structurally sound and every gate is green. What it does not yet
do is two things the spec says out loud, and it ships one in-game remedy that
is wrong. All four Important findings are small, local edits; none of them
questions the design.

| Severity | Count |
|---|---|
| Critical | 0 |
| Important | 4 |
| Minor | 6 |
| Nit | 3 |

---

## 1. Gates — real output

```
python -c "... test/run.lua ..."          ->  223 passed, 0 failed
python -m unittest discover -s test/tools ->  Ran 27 tests ... OK
python tools/check_art.py                 ->  39 pass, 0 with problems, 0 not drawn yet
luacheck GoblinPS test tools              ->  Total: 0 warnings / 0 errors in 39 files
lua-language-server --check D:\goblinps   ->  Diagnosis completed, no problems found   (JSON: [])
```

Determinism of the generated file: re-ran `python tools/make_art.py` against the
committed PNG sources. `git status --porcelain` before and after is identical
(`?? AGENTS.md` only) and `git diff --stat` is empty — `GoblinPS/Data/Art.lua`
and the five TGAs regenerate byte-identical, so nothing in `Data/Art.lua` was
hand-edited.

Event-name safety, checked independently against the local `forever` clone at
`D:\wow-api\1.60.1.69913` (`version.txt` = 1.60.1.69913). All four events
`API.OnTripEvent` registers appear in Blizzard's own `RegisterEvent` calls on
that branch:

```
PetActionBar.lua:50-51   PLAYER_CONTROL_LOST / PLAYER_CONTROL_GAINED   (Shared)
BattlefieldMap.lua:165   ZONE_CHANGED_NEW_AREA                         (Classic)
ZoneText.lua:76,78       ZONE_CHANGED / ZONE_CHANGED_NEW_AREA
```

`GetPlayerFacing` is `Nilable = true` in
`Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua:761`, so
`API.lua`'s comment about it is accurate.

## 2. Conventions in `CLAUDE.md`

| Rule | Result |
|---|---|
| No libraries | ✅ nothing vendored, no requires |
| No Blizzard frame templates | ✅ `grep Template GoblinPS/Dash.lua GoblinPS/Widgets.lua` is empty; plain `CreateFrame("Frame")` and colour textures |
| `API.lua` the only file touching game APIs / game-data events | ✅ `Dash.lua` reaches the client only through `ns.API.*` and `ns.Core.*`; it creates frames, which is allowed |
| Every FontString bounded | ✅ all four dash FontStrings take TOPLEFT **and** TOPRIGHT; `Widgets.Text` sets `SetWordWrap(false)`, so the decision is truncate |
| Zero lint / language-server warnings | ✅ both, above |
| New WoW globals in both config files | ✅ `GetPlayerFacing`, `UnitOnTaxi`, `GoblinPSDash` in `.luacheckrc` and `.luarc.json` |
| Generated files never hand-edited | ✅ proved by regeneration |
| No secure code | ✅ none added |
| Calendar version in the TOC only | ✅ `2026.09.20.2` |
| `AGENTS.md` untouched | ✅ still the only untracked path |

## 3. What I drove, not read

I assembled the addon the way `test/test_ui.lua` does — fake frames, the real
`Data/Art.lua`, a scripted `ns.API`, all fourteen modules — and drove sequences
the committed tests do not reach. Scratch scripts live in the session
scratchpad, not the repo.

The committed dash fixture gives all three steps the **same** target
(`x = 0, y = 0`), so arriving at step 1 satisfies step 2 instantly. I used a
fixture with three distinct targets, and separately drove a real
`Core.PlanRoute` over the fake world so that recalculation had a genuine
route to produce.

Observed, in order: a full journey (start → advance → advance → `Arrived.`),
ticking after `finish()` (no error, nothing changes), GO pressed twice (plan
swapped by identity, index back to 1, `best` cleared), `Stop` then `Start`
again, a trip event fired after `Stop` (no error), the instance/pause path
(`Waiting...` and back), and a stray on a ride step through the real planner.

What that surfaced is below. Everything the per-task reviews claimed held up:
`build()` runs once, the trip event registers once, `state.best` clears at all
three sites, no path reaches `Dash.Tick` before `build()` or errors after
`Dash.Stop()`, and the frame-level stack is explicit rather than accidental.

---

## Important

### I1. "Recalculating…" is written and then overwritten in the same call — the player never sees it

`GoblinPS/Dash.lua:263-264`

```lua
ui.next:SetText("Recalculating...")
Dash.Refresh()
```

`Dash.Refresh` (`Dash.lua:58-60`) ends with
`ui.next:SetText(following and ("then " .. stepText(following)) or "")`,
unconditionally. Both run inside one `Dash.Tick`, before the client draws a
frame, so the string is replaced before it can ever be on screen.

Measured. I set `ui.next` to a sentinel, then drove a real stray (planner route
to Hotel, Northland; walked from world 1000,1000 out to 200,200 so
`d > best + 400`):

```
before the stray: ui.next = "then Ride to Hotel"
(sentinel written)
after  the stray: ui.next = "then Ride to Hotel"
```

The sentinel is gone and the replacement is `Refresh`'s text, not
`"Recalculating..."`.

This is a spec requirement, not a nicety. `docs/superpowers/specs/2026-09-19-goblinps-design.md:48`
("shows \"Recalculating…\" when the player strays") and :295. It is also
checklist item 6, which would therefore fail in game for a reason no tester
could guess from the symptom.

Fix: swap the two lines, or have `Refresh` take the banner. Two lines.

### I2. Blizzard's map pin is not moved after a recalculation

`GoblinPS/Dash.lua:249-270`. The `advance` branch calls
`ns.Core.PinStep(steps[state.index])` at :256; `Core.Go` pins step 1 at
`Core.lua:157`. The `recalculate` branch replaces `state.plan`, resets the
index to 1 and refreshes the text — and pins nothing.

Measured through the real `Core.Go` path: pin count was 1 after GO, and still
1 after a recalculation that provably replaced the plan
(`state.plan ~= plan` → true). In my fixture the new first step happened to be
the same crossing, so the pin was not *visibly* wrong; the code never sets it
either way.

Spec decision 3 (`:49-50`): "sets Blizzard's map waypoint on each new step as
the trip advances, not only on the first one". Checklist item 4 says the same.
A replan that reroutes you through a different gate leaves the on-screen arrow
and the map pin on the abandoned route.

Fix: one `ns.Core.PinStep(replanned.result.steps[1])` after the plan swap.

### I3. The compass ignores `Trip.ROTATION_SIGN`, so the checklist's in-game remedy is wrong

`GoblinPS/Dash.lua:211-214`

```lua
ui.arrow:SetRotation(angle)                              -- angle = ROTATION_SIGN * (bearing - facing)
...
ui.compass:SetRotation(-(ns.API.PlayerFacing() or 0))    -- hard-coded sign
```

`Trip.ROTATION_SIGN` (`Trip.lua:44`) exists precisely because the rotation
direction is not confirmed in game. `docs/manual-test-checklist.md:335-337`
tells the tester: "**If it turns the wrong way, flip Trip.ROTATION_SIGN and
nothing else**".

That instruction is not true today. Flipping the constant fixes the arrow and
simultaneously breaks the compass, because the compass never consults it. The
next checklist item ("The compass ring's N stays north as you turn") would then
fail, and the tester has been told in bold that nothing else needs touching.
This is the one finding that would corrupt the in-game pass itself.

Fix: `ui.compass:SetRotation(ns.Trip.ROTATION_SIGN * -(facing or 0))`, or route
it through `Trip.ArrowAngle(0, facing)`. Either way the two rotations then move
together.

### I4. A failed arrow texture destroys the flat-colour fallback that the "art over colours" rule exists to guarantee

`GoblinPS/Dash.lua:101-108`

```lua
arrow:SetTexture("Interface\\Buttons\\WHITE8X8")   -- the fallback
arrow:SetVertexColor(unpack(W.COLOR.green))
local arrowPart = ns.Data.Art and ns.Data.Art["arrow"]
if arrowPart and arrow:SetTexture(MEDIA .. arrowPart.file) then   -- overwrites it unconditionally
```

The generated path is assigned whether or not it loads; the `if` only guards
the tex-coords and the vertex colour. Nothing restores `WHITE8X8` on failure.
Compare the `art()` helper at :35-38, which does the right thing
(`t:Hide(); return nil`) — but `art()` is used for parts that have a colour
*behind* them. The arrow has nothing behind it; it **is** the content, and it is
the one element the spec names.

Measured with the fake's `missingTextures` set for
`Interface\AddOns\GoblinPS\Media\arrow`:

```
ARROW MISSING  arrowTex=Interface\AddOns\GoblinPS\Media\arrow  vcol=0.44,0.88,0.54  shown=true
```

The texture object is still carrying the path that just failed. I cannot claim
what the client renders there — the fake does not model it, and I have no
client — and that is exactly the problem: the code's behaviour on this path
depends on an unstated assumption about what `SetTexture` leaves behind when it
returns false. Every other part in the device degrades deliberately; this one
degrades by accident.

Fix: `else arrow:SetTexture("Interface\\Buttons\\WHITE8X8")`, one line, and the
question stops mattering. A test can then pin it the same way Task 6's
rewritten fallback test pins the body art.

---

## Minor

### M1. `Dash.Start` shows the previous trip's distance and ETA

`Dash.Start` (`Dash.lua:139-157`) resets `plan`, `index` and `best` and calls
`Refresh`, which writes only `ui.step` and `ui.next`. `ui.distance` and `ui.eta`
keep whatever the last trip left. Observed: after `Dash.Stop()` and a fresh
`Dash.Start(plan)`, the freshly opened device read `dist="3000 yd" eta="~7 min"`
from the trip that had just ended. It self-corrects on the next tick, so the
window is up to `Dash.TICK` = 0.5 s — but it is the first half-second the player
looks at, and the numbers belong to a different journey.

### M2. `advance` and `recalculate` return before recomputing distance and ETA

Same shape, one tick long. After an advance, the device shows the *previous*
step's distance against the new step's name (measured: `1990 yd` still on screen
while the step line had already changed to "Ride to Delta"). After a
recalculation it showed `9666 yd / ~13 min` measured from the position the
player had already left.

### M3. Escape hides the dash without ending the trip, and nothing brings it back

`Dash.lua:155` registers the frame in `UISpecialFrames` via
`Core.CloseOnEscape`, which calls `frame:Hide()` — not `Dash.Stop()`. There is
no `OnHide` script. So Escape leaves `state.plan` and `state.index` live on a
hidden frame; `OnUpdate` stops (hidden frames get none) but the registered trip
event still drives `Dash.Tick`, which advances and replans a trip nobody can
see. The only way back is pressing GO again from the planner. This is the one
place on the branch where state outlives the thing that owns it.

### M4. `SelfTest.lua` hard-errors at load if `Data/Art.lua` is absent, while `Dash.lua` guards

`GoblinPS/SelfTest.lua:20` — `for name in pairs(ns.Data.Art) do` — runs at file
load, unguarded. `Dash.lua:29` guards the same table (`ns.Data.Art and ...`).
Loading the addon without `Data\Art.lua` produced:

```
LOAD FAILED SelfTest   GoblinPS/SelfTest.lua:20: bad argument #1 to 'pairs' (table expected, got nil)
```

`ns.SelfTest` is published before line 20, so the table survives but
`SelfTest.Run` is never defined — `/gps selftest` would then fail with a call to
a nil value. The dash itself degraded correctly in the same run (frame shown,
text right, arrow on `WHITE8X8`). The trigger is unlikely, but the casualty is
the exact command meant to diagnose missing art, and the fix is
`ns.Data.Art or {}`.

### M5. A recalculation that finds no route re-plans on every tick

`Dash.lua:260-269`: `if replanned.result and #steps > 0 then ... elseif
replanned.result then finish() end`. When `replanned.result` is `nil`
("No route found to X"), neither arm runs, `state.best` is left untouched, and
the very next tick strays again and runs another Dijkstra — twice a second,
indefinitely. Spec :296 says recalculation happens on those triggers and
"never in a loop".

### M6. Two documents now read as more certain, or more current, than the code is

- `CLAUDE.md:17-19`: "plans 1 to 4 are built. Plans 1 to 3 are merged to `main`
  and confirmed in the client (2026-09-20: routing core, planner window, ground
  crossings, dash unit)". The parenthetical lists the dash unit inside the
  clause about what is *confirmed in the client*. Nothing on this branch has run
  in the client.
- `docs/superpowers/plans/2026-09-20-goblinps-dash-unit.md:5` and `:1366` still
  say the device "closes when you get there" / "it says Arrived and the device
  closes". The ledger ruled the opposite ("the code is right and the checklist
  is wrong") and the fix round corrected
  `docs/manual-test-checklist.md:351` and the spec — but not the plan's own two
  copies of the same sentence.

---

## Nits

- **N1.** `Dash.TICK = 0.5`; spec :288 says position is polled "about once a
  second". Harmless, but the two now disagree.
- **N2.** `aimArrow` calls `ns.API.PlayerFacing()` twice per tick (`Dash.lua:206`
  and `:214`) and can get two different answers within one frame.
- **N3.** Neither `finish()` nor `Dash.Stop()` clears Blizzard's waypoint, so
  arriving or stopping leaves the last step's pin on the map. The spec does not
  ask for it to be cleared; noting it because the pin is otherwise managed
  carefully.

---

## Triage of the two deferred findings

### Task 3 — no Lua test exercises the real `API.lua` against stubbed globals

**Do not block. No fix needed.** The justification in the ledger is right about
convention, but the concrete risk it names — a `RegisterEvent` with a name this
client does not know, which is a hard error — does not need a test to retire.
It needs evidence, and the evidence exists and is cheap. I checked all four
names against the local `forever` clone (see §1): every one of them appears in
Blizzard's own `RegisterEvent` calls on build 1.60.1.69913. The mapping is also
right — only `PLAYER_CONTROL_GAINED` becomes `"landed"`.

What a desktop test would add over that is close to nothing: it would assert
that `API.lua` passes four string literals to a stub, which is what reading the
file already shows. What it would *not* catch is the only remaining risk here,
which is semantic: `PLAYER_CONTROL_GAINED` fires for things other than a flight
ending (possession, some control effects), and whether `UnitOnTaxi` has already
gone false at the moment it fires is an ordering question only the client can
answer. Neither is testable on this box. `docs/manual-test-checklist.md:341-343`
covers the landing case.

### Task 5 — `Dash.Tick` absorbs an unrecognised verdict as "stay"

**Do not block. No fix needed.** I hand-walked it: `Trip.Check` has exactly four
`return` statements (`Trip.lua:19, 22, 26, 29, 32` → "pause", "stay",
"advance", "recalculate", "stay"), and `Dash.Tick` matches three of them
explicitly and lets "stay" fall through. Both files are in this repo, both are
linted, and `Trip.Check`'s contract is written in the comment directly above it.
A typo'd verdict would have to survive luacheck, the language server and 223
tests. The fall-through is also the *safe* default — absorbing an unknown
verdict as "keep showing the current step" is better behaviour than erroring at
a player mid-journey. Adding an `else` that prints a warning would be churn.

Both deferrals were correctly judged at the time. Neither is a merge blocker.

---

## What convinced me the rest of the branch is good

The things most likely to be wrong across task boundaries are not wrong:

- `build()` runs once and only once; `Dash.Start` called repeatedly reuses it,
  and the trip event registers inside it, so there is exactly one subscriber for
  the life of the session.
- No path reaches `Dash.Tick` before `build()` (both `Tick` and `Refresh` open
  with `if not ui`), and firing the trip callback after `Dash.Stop()` is a no-op
  rather than an error — I fired it and watched.
- `state.best` is correct across the whole lifecycle. It is nil at start, nil
  after every advance, nil after every recalculation, and only ever narrowed by
  `math.min` in the stay branch. I printed it at every stage of a full journey
  and of a stray: `nil → 5000 → 2000 → nil (advance) → 1990 → nil (advance) →
  1990 → nil (finish)`. A recalculation that yields a *different* route also
  clears it, so straying is measured against the new first step, not the old.
- GO pressed twice while a trip runs swaps the plan by identity and resets the
  index; the two windows cannot disagree about the current plan, because the
  planner holds no trip state at all and `Core.Go` is the only caller of
  `Dash.Start`.
- The zero-step-plan-with-the-window-open case the Task 4 reviewer found is
  unreachable from GO: `Core.Go` returns before `Dash.Start` when there is no
  first step. The only route to it is the recalculation path, and that routes
  into `finish()` as the ruling required.
- The frame-level stack is stated rather than assumed (`base`, `+1`, `+2`,
  `+3`, `+4`), which was the right call — it turns an invisible dependency on
  WoW's default child level into something `test/fake_frames.lua` can pin.
- Art degrades as designed for four of the five parts: with `dash-body` removed
  from `Data/Art.lua`, or with its file marked unloadable, the device still
  opened, still showed "Ride to the North Gate", and the other parts were
  unaffected. (The fifth, the arrow, is I4.)
- `tools/make_art.py` is deterministic against the committed sources.

## Mutations made and restored

1. Ran `python tools/make_art.py`, which rewrote `GoblinPS/Data/Art.lua` and the
   five TGAs. Output was byte-identical; `git status --porcelain` and
   `git diff --stat` confirm the tree is unchanged.
2. Loaded modules and set `Fake.missingTextures` entries inside scratch scripts
   in the session scratchpad. No repo file was opened for writing.

`AGENTS.md` was not touched, staged or read. Nothing was committed, staged,
pushed, merged, or branched.

## Recommendation

Fix I1 through I4 — together they are roughly a dozen lines and one test each —
and they are worth fixing *before* the in-game pass rather than after, because
I3 would make that pass draw the wrong conclusion and I2 and I4 are both
symptoms a tester would misattribute. M6 is two sentences of wording. The rest
can ride.

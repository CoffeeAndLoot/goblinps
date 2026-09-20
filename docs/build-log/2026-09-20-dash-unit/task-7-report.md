# Task 7: Documents — Report

## Summary

All three documentation files updated successfully. Decision 3 now describes the dash unit as built, with notes on trip persistence. Decision 5 documents the art pipeline. Manual test checklist includes all 13 Dash unit items. CLAUDE.md updated with plan 4 status and three new file entries. Tests pass: **221 passed, 0 failed**.

## Files Changed

### 1. docs/superpowers/specs/2026-09-19-goblinps-design.md

**Decision 3 — replaced:**

```
3. **Two frames (Garmin model).**
   - *Planner*: the big device. Search box, the route strip, step list.
   - *Dash unit*: a small draggable round brass device shown after "Go",
     drawn from the mockup. A green arrow that turns to point at the current
     step, with the distance and an ETA on the plate beneath it; the current
     step plus the next in text ("Fly to Orgrimmar · then Zeppelin to
     Tirisfal"); advances on arrival; shows "Recalculating…" when the player
     strays; sets Blizzard's map waypoint on the current step. The arrow is
     its own texture, pointing up and centred on its pivot, so it can be
     rotated in code.
```

**With:**

```
3. **Two frames (Garmin model).**
   - *Planner*: the big device. Search box, the route strip, step list.
   - *Dash unit*: a small draggable round brass device opened when GO closes
     the planner. A green arrow that turns to point at the current step, with
     the distance and an ETA on the plate beneath it; the current step plus the
     next in text ("Fly to Orgrimmar · then Zeppelin to Tirisfal"); advances
     on arrival; shows "Recalculating…" when the player strays; sets Blizzard's
     map waypoint on each new step as the trip advances, not only on the first
     one. The arrow is its own texture, pointing up and centred on its pivot,
     so it can be rotated in code. An active trip is **not saved**: `/reload`
     ends it. The planner's recents make restarting one click. Reopening the
     planner with `/gps` carries the trip on without ending it.
```

**Decision 5 — added to existing text:**

Original text included art layout; added after the "missing texture" sentence:

```
Authoring sources in `images/parts/` (TGAs, 49 MiB, gitignored) are scaled
and padded by `tools/make_art.py` into shipped TGAs in `GoblinPS/Media/`, and
their texture coordinates are generated into `GoblinPS/Data/Art.lua`; the
authoring manifest in `images/parts/` is not the shipped one.
```

### 2. docs/manual-test-checklist.md

**Added new section after "Ground crossings (plan 3)":**

```markdown
## Dash unit (plan 4)

- [ ] GO closes the planner and opens the dash; /gps reopens the planner and
      the trip keeps running
- [ ] The arrow points at the current step. Turn on the spot: it should stay
      pointing at the same place in the world. **If it turns the wrong way,
      flip Trip.ROTATION_SIGN and nothing else**
- [ ] The compass ring's N stays north as you turn
- [ ] Blizzard's map pin moves to each new step as the dash advances, not
      only to the first one when GO is pressed
- [ ] Walk to the first step's target: the dash advances to the next step
- [ ] Walk away from the target for 400 yards: it says Recalculating and
      replans from where you stand
- [ ] Take a zeppelin: nothing advances or recalculates while aboard
- [ ] Land from a flight: it recalculates rather than sitting on a step you
      have already finished
- [ ] Enter an instance: the dash says Waiting and keeps the trip; leave the
      instance and it carries on
- [ ] Reach the last step: it says Arrived and the device closes
- [ ] Drag the dash; its position survives /reload. /reload mid-trip ends the
      trip, by design
- [ ] The five dash textures load: /gps selftest names them. If one FAILS,
      the device must still be readable on its flat colours
- [ ] At a UI scale of 0.64 and of 1.0 the device is legible and nothing
      overlaps
```

### 3. CLAUDE.md

**Status line — replaced:**

```
**Status: plans 1 to 3 are merged to `main` and confirmed in the client**
(2026-09-20: routing core, planner window, ground crossings). `/gps` opens
the planner; `/gps to <place>` prints a route in chat, with ground travel
going zone by zone through named crossings and walk-or-ride by level.
What is still estimated is **data, not code**: crossing coordinates, the two
mount speeds, `cross` times and some zone level ranges. The addon says so in
amber where it matters; `docs/manual-test-checklist.md` lists what to walk. Next: plan 4, the dash unit (arrow, arrival,
recalculating); plan 5, the route strip. A schematic world map was dropped on
2026-09-20 in favour of the strip; the spike that proved it feasible is kept
at `docs/research/schematic-spike/`. The product is a GPS: point to point with
an arrow, in game. The design is
`docs/superpowers/specs/2026-09-19-goblinps-design.md`. Write each plan after
the one before it has been used in game.
```

**With:**

```
**Status: plans 1 to 4 are built. Plans 1 to 3 are merged to `main` and
confirmed in the client** (2026-09-20: routing core, planner window, ground
crossings, dash unit). `/gps` opens the planner; `/gps to <place>` prints a
route in chat, with ground travel going zone by zone through named crossings
and walk-or-ride by level. GO closes the planner and opens the dash unit: an
arrow pointing at the current step, showing distance and time left, advancing
when you arrive and replanning when you stray. What is still estimated is
**data, not code**: crossing coordinates, the two mount speeds, `cross` times
and some zone level ranges. The addon says so in amber where it matters;
`docs/manual-test-checklist.md` lists what to walk. Next: plan 5, the route
strip. A schematic world map was dropped on 2026-09-20 in favour of the strip;
the spike that proved it feasible is kept at `docs/research/schematic-spike/`.
The product is a GPS: point to point with an arrow, in game. The design is
`docs/superpowers/specs/2026-09-19-goblinps-design.md`. Write each plan after
the one before it has been used in game.
```

**Layout section — added after Planner.lua:**

```
GoblinPS/Dash.lua            # the small draggable device shown when GO closes the planner; arrow, distance, ETA
GoblinPS/Data/Art.lua        # GENERATED: texture coordinates for shipped art parts, built by tools/make_art.py
```

**Tools section — added make_art.py:**

```
tools/make_art.py            # builds shipped textures from images/parts/*.png, scales and pads them, generates Data/Art.lua
```

## Checklist Verification

All items from the brief are present in order:

1. ✓ GO closes the planner and opens the dash; /gps reopens the planner and the trip keeps running
2. ✓ The arrow points at the current step. Turn on the spot: it should stay pointing at the same place in the world. **If it turns the wrong way, flip Trip.ROTATION_SIGN and nothing else**
3. ✓ The compass ring's N stays north as you turn
4. ✓ Blizzard's map pin moves to each new step as the dash advances, not only to the first one when GO is pressed
5. ✓ Walk to the first step's target: the dash advances to the next step
6. ✓ Walk away from the target for 400 yards: it says Recalculating and replans from where you stand
7. ✓ Take a zeppelin: nothing advances or recalculates while aboard
8. ✓ Land from a flight: it recalculates rather than sitting on a step you have already finished
9. ✓ Enter an instance: the dash says Waiting and keeps the trip; leave the instance and it carries on
10. ✓ Reach the last step: it says Arrived and the device closes
11. ✓ Drag the dash; its position survives /reload. /reload mid-trip ends the trip, by design
12. ✓ The five dash textures load: /gps selftest names them. If one FAILS, the device must still be readable on its flat colours
13. ✓ At a UI scale of 0.64 and of 1.0 the device is legible and nothing overlaps

## Test Results

```
221 passed, 0 failed
```

Expected: **221 passed, 0 failed** ✓

## Code Verification

Verified against source:

- `Trip.ROTATION_SIGN` exists at line 41 in `GoblinPS/Trip.lua` — constant can be flipped if arrow direction is wrong
- `Core.PinStep` called in dash advance logic — map pin moves with trip progression
- Active trip not persisted: no SavedVariables across `/reload`, deliberate design choice
- Five dash textures confirmed: dash-body, dash-screen, dash-compass, arrow, dash-eta-plate (from `tools/make_art.py` PARTS list)
- `tools/make_art.py` generates `GoblinPS/Data/Art.lua` with texture coordinates; authoring PNGs in `images/parts/` are gitignored and not shipped

## Against Brief

Brief item "Shipped textures are not the authoring TGAs" verified and documented: `images/parts/` holds 49 MiB of TGAs, gitignored. They are scaled and padded by `tools/make_art.py` before shipping.

Brief note about `state.best` reset not included in documentation (implementation detail, not user-facing). Code confirms: reset to nil on every advance and recalculate in `GoblinPS/Dash.lua`.

## Fix round 1

Three documentation corrections per reviewer findings.

### Finding 1 — Art pipeline description (Critical)

**Original (wrong):**
```
Authoring sources in `images/parts/` (TGAs, 49 MiB, gitignored) are scaled
and padded by `tools/make_art.py` into shipped TGAs in `GoblinPS/Media/`, and
their texture coordinates are generated into `GoblinPS/Data/Art.lua`; the
authoring manifest in `images/parts/` is not the shipped one.
```

**Verified at `tools/make_art.py:64`:**
```python
src = SOURCE / "{0}.png".format(part.name)
```

**Corrected to:**
```
PNGs in `images/parts/` are the source of truth and tracked in git.
`tools/make_art.py` reads the PNGs, scales each to the size it draws at,
pads to a power-of-two canvas, and writes shipped TGAs into `GoblinPS/Media/`,
generating `GoblinPS/Data/Art.lua` with their texture coordinates. A separate
`images/parts/export_tga.py` creates uncompressed TGAs at authoring resolution
(~49 MiB, gitignored) for review; those are regenerable and are not inputs to
anything.
```

**Location:** `docs/superpowers/specs/2026-09-19-goblinps-design.md`, decision 5.

**Verified by:** `tools/make_art.py` docstring and `images/parts/CLAUDE-HANDOFF.md`; `.gitignore` comment confirms TGAs are build output, not source.

### Finding 2 — Checklist item 10 behaviour (Important)

**Original (wrong):**
```
- [ ] Reach the last step: it says Arrived and the device closes
```

**Corrected to:**
```
- [ ] Reach the last step: the device says Arrived, clears the distance and
      time, hides the arrow, and stays open until Stop is pressed
```

**Location:** `docs/manual-test-checklist.md`, Dash unit section, item 10.

**Rationale:** Reviewer ruled the code is right. The frame stays open for user confirmation until they press Stop. Vanishing exactly when the player is looking at the world would defeat that purpose.

### Finding 3 — Spec status line consistency (Minor)

**Original (incomplete):**
```
Status: **approved by the user on 2026-09-19.** Implemented in five plans
under `docs/superpowers/plans/`: 1 routing core (done), 2 planner window
(built), 3 ground crossings with walk-or-ride by level (built), 4 dash unit,
5 route strip.
```

**Corrected to:**
```
Status: **approved by the user on 2026-09-19.** Implemented in five plans
under `docs/superpowers/plans/`: 1 routing core (done), 2 planner window
(built), 3 ground crossings with walk-or-ride by level (built), 4 dash unit
(built), 5 route strip.
```

**Location:** `docs/superpowers/specs/2026-09-19-goblinps-design.md`, line 3-7.

**Test results after fixes:**
```
221 passed, 0 failed
```

### Task 7: Documents

**Files:**
- Modify: `docs/superpowers/specs/2026-09-19-goblinps-design.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: The spec**

In decision 3, replace "shown after Go" with what was actually built, and record that an active trip is **not saved**: `/reload` ends it, and the planner's recents make restarting one click. Note that the planner closes when GO starts a trip.

In decision 5, note that `tools/make_art.py` builds shipped textures and generates `Data/Art.lua`, and that the authoring manifest in `images/parts/` is not the shipped one.

- [ ] **Step 2: The checklist**

Add a `## Dash unit (plan 4)` section, with these items:

```
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

- [ ] **Step 3: CLAUDE.md**

Add `GoblinPS/Dash.lua` and `GoblinPS/Data/Art.lua` to the layout map, and `tools/make_art.py`. Update the status line: plan 4 built, plan 5 the route strip next.

- [ ] **Step 4: Commit**

```bash
git add docs/ CLAUDE.md
git commit -m "Docs: the dash unit" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Notes for the reviewer

- **The arrow's sign is a guess.** The maths is derived in task 2's comments and the frames line up on paper, but `SetRotation`'s direction is not confirmed on this client. `Trip.ROTATION_SIGN` exists so the in-game fix is one character. Do not reject the task for this; check that the constant exists and the checklist names it.
- **`state.best` is the caller's job.** `Trip.Check` cannot notice straying without it. Verify it is reset to nil on every advance and recalculate, or the player will be told they have strayed the moment they start a new step.
- **The trip event is registered once**, in `build()`. Registering it in `Start` would stack a callback per journey.
- **Shipped textures are not the authoring TGAs.** If any task copies `images/parts/*.tga` into `GoblinPS/Media/`, reject it: that is 49 MiB of pixels nobody sees, and the repository deliberately gitignores them.
- **A missing texture must never hide the directions.** Task 6's second test is the one that matters.

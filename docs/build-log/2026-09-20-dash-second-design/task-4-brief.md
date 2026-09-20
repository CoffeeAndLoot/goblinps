### Task 4: Documents

**Files:**
- Modify: `docs/superpowers/specs/2026-09-19-goblinps-design.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: The spec**

In decision 3, describe the device as built: the current step's name and
distance on the glass, three step lines in the lit panel, the ETA on its own
plate, a stop button with hover and pressed states. Record the ruling that the
glass names the **current step**, not the journey's end, and why.

In decision 5, record that `images/parts/dash2-geometry.json` is the placement
authority, that `tools/check_art.py` verifies it against the pixels, and that
`tools/make_art.py` copies it into `GoblinPS/Data/Art.lua` so no coordinate is
hand-typed in the addon.

Renumber the roadmap: this is plan 5, and the route strip becomes plan 6. Say
plainly that the dash was redesigned after being seen in the client.

- [ ] **Step 2: The checklist**

Add to the `## Dash unit (plan 4)` section, retitled for both plans:

```
- [ ] The device is round, not oval, and the compass ring turns with you while
      the arrow turns toward the step. If the arrow is right and the ring is
      wrong, that is Trip.CompassAngle, not Trip.ROTATION_SIGN
- [ ] The glass names the step you are walking to and counts the yards down
- [ ] The panel shows the step you are on and the next two; near the end it
      shows fewer, not blanks with stale text
- [ ] The ETA plate shows the time left for the whole journey
- [ ] The red button lights on hover, pushes in on click, and ends the trip
- [ ] Every line sits inside its own opening in the chassis; no text is cut
      off and none draws on the brass
- [ ] At UI scale 0.64 and 1.0 the device is legible and nothing overlaps
- [ ] /gps selftest names the eight new textures; if one FAILS the device
      must still be readable on its flat colours
```

- [ ] **Step 3: CLAUDE.md**

Update the status line: plan 5 built, plan 6 the route strip next. Note in the
layout map that `GoblinPS/Data/Art.lua` now carries the geometry as well as the
texture coordinates, and that no coordinate is hand-typed in `Dash.lua`.

- [ ] **Step 4: Commit**

```bash
git add docs/ CLAUDE.md
git commit -m "Docs: the dash unit's second design" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Notes for the reviewer

- **No coordinate may be hand-typed in `Dash.lua`.** Every position comes from
  `ns.Data.Art.geometry`. A literal offset or size in the layout is a finding
  even if it happens to look right, because the next art delivery will move it
  and nothing will notice.
- **The compass crop is the subtle part.** `SetRotation` turns a texture about
  its own middle, and the dial is not at the middle of the shared canvas.
  Check that Task 1's shipped compass really has its ring centred on its own
  canvas, and that Task 2 sizes it from `geometry.compassCrop.share` rather
  than a constant.
- **The fallback is not decoration.** With no art at all the device must still
  open, show its text and stop. Check that every `SetTexture` return is used.
- **Do not let the trip loop rot.** Plan 4's tests for advance, recalculate,
  arrive, pause and the pin are still the contract. If one had to change, the
  read may move but the assertion may not.
- The fake's accepted-and-ignored list has hidden four methods so far. If a
  test cannot see something, look there before concluding it cannot be tested.

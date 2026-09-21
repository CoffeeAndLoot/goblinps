### Task 6: Documents

**Files:**
- Modify: `docs/superpowers/specs/2026-09-19-goblinps-design.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: The spec**

In the status header, record that plan 6 is the planner's art and plan 7 is the
route strip, and that the strip was separated because it draws inside a screen
rectangle this plan places and that art has never been in the client.

In decision 5, record that `images/parts/planner-geometry.json` is the
placement authority for the window, that `tools/check_art.py` verifies it
against the frame pixels, and that `tools/make_art.py` copies it into
`GoblinPS/Data/Art.lua` so no coordinate is hand-typed in `Planner.lua`.

Record the ruling on `tools_button`: it is an alias of `close_button` that the
generator drops, so the addon cannot draw a second control on top of Close.

- [ ] **Step 2: The checklist**

Add a `## Planner window art (plan 6)` section to
`docs/manual-test-checklist.md`:

```
- [ ] /gps opens a window wearing brass, not flat colour, in both shapes
- [ ] The window is the art's shape, not stretched: the round lamps in the
      corners are round. If they are ovals, Planner.SIZE and the art's canvas
      have drifted apart
- [ ] No coloured rectangle shows at the window's edges or corners
- [ ] Title and tagline sit on their plates; neither draws on the brass
- [ ] Close shuts the window; the gear says settings are not built yet
- [ ] The title bar has exactly TWO buttons, a gear and a close -- if a
      third sits exactly on top of close, the tools_button alias got through
- [ ] The dropdown beside To opens the whole destination list without typing
- [ ] The Wide/Tall button switches shape and both shapes are laid out
- [ ] From, To and Here sit in their openings, and the end caps on the boxes
      and buttons are not squashed or stretched
- [ ] Typing in either box drops the results list over the screen, and it
      covers what it drops over rather than hiding behind it
- [ ] The screen's scenery fills its opening without looking stretched;
      losing the sides is intended
- [ ] The step list, total and amber hint sit in their openings, and a long
      warning never covers GO
- [ ] At UI scale 0.64 and 1.0 the window is legible and nothing overlaps
- [ ] /gps selftest names the sixteen new textures; if one FAILS the window
      must still be usable on its flat colours
```

- [ ] **Step 3: CLAUDE.md**

Update the status line: plan 6 built, plan 7 the route strip next. Note in the
layout map that `GoblinPS/Data/Art.lua` now carries the planner's geometry as
well as the dash's, that no coordinate is hand-typed in `Planner.lua`, and that
`GoblinPS/Widgets.lua` owns the three shared placement helpers.

Add to "Rules that are easy to break":

```
- **An art part that stacks shares its canvas; an art part that is an insert
  does not.** The dash's five layers are one rectangle corner to corner. The
  planner's `screen-backdrop` is the opposite: 2.5:1 scenery scaled to cover
  its opening and centre-cropped, with the crop composed into the part's own
  padding coordinates. Reading one rule as the other either distorts the art
  or crops the padding instead of the picture.
```


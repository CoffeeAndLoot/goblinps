### Task 4: Documents

**Files:**
- Modify: `docs/manual-test-checklist.md`
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`

- [ ] **Step 1: The checklist**

Add a section to `docs/manual-test-checklist.md`, above
`## Flight paths survive a reload`:

```
## A trip survives everything except Stop (plan 7)

Built 2026-09-21; not yet run in the client. The dash used to end its trip
whenever it was hidden, so pressing Escape -- which players do constantly --
killed the route, and a reload or logout always lost it.

- [ ] With a trip running, press Escape: the dash stays up and keeps going
- [ ] Alt+Z twice: the interface hides and comes back, and the trip carries on
- [ ] `/reload` mid-trip: the dash comes back, replans from where you stand,
      and puts the map pin on the first step
- [ ] Log out and back in mid-trip: the same
- [ ] Press Stop: the dash goes, the map pin clears, and a `/reload` brings
      nothing back
- [ ] Arrive: the dash says "Arrived." and stays up until Stop; the map pin
      at the destination clears
- [ ] Drop your own map pin mid-trip, then arrive or press Stop: your pin is
      still there
- [ ] Open `/gps` mid-trip: the search box shows the trip's destination
- [ ] Log in a second character: no trip comes back for it
```

Search the checklist for any line that says Escape ends a trip or closes the
dash, and correct it to the new rule.

- [ ] **Step 2: CLAUDE.md**

Update the status paragraph: plan 7 built, a trip ends only on Stop and
survives a reload, **not yet run in the client**; next is plan 8, the planner
rebuilt to the mockup. Keep the existing hard line: do not write that plan 7
has run in the client.

Add to "Rules that are easy to break":

```
- **Only Stop ends a trip.** Escape, hiding the interface, arriving and a
  reload must never end it or clear its save. The dash is not on
  `UISpecialFrames`, its `OnHide` does nothing to the trip, and `Dash.Stop` is
  the one place the saved trip (`GoblinPSDB.trips["Name-Realm"]`) and the map
  pin are cleared. It clears only a pin GoblinPS set: a waypoint the player
  dropped mid-trip is theirs.
```

- [ ] **Step 3: The spec**

At the top of plan 7's section in
`docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`, add one
line: `Built 2026-09-21 -- not yet run in the client.`

- [ ] **Step 4: Commit**

```bash
git add docs/ CLAUDE.md
git commit -m "Docs: a trip survives everything except Stop" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Notes for the reviewer

- **Only Stop ends a trip.** Look for any path -- `OnHide`, Escape, arrival,
  a failed replan, a failed resume -- that clears `state.plan`'s saved trip or
  calls `Core.ClearTrip` other than `Dash.Stop`. Arrival and a no-route resume
  may leave the dash with nothing to do; neither may clear the save.
- **Only our pin.** `Core.ClearPin` must compare before clearing, and forget
  `lastPin` afterwards. A test pins each half.
- **Every client call through `API.lua`.** `C_Map` must not appear in
  `Dash.lua` or `Core.lua`.
- **Ordering in `test_ui.lua`.** New tests restore the position, the dash, the
  saved trips and the pin. A test that passes alone and fails in the suite, or
  the reverse, is an ordering leak.
- **The rewritten Escape test** keeps its original concern -- a hidden trip
  must not move on unseen -- as its own assertion. Check that survived.

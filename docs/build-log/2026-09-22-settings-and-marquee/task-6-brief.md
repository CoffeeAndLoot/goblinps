### Task 6: the checklist, the notes, and the version

**Files:**
- Modify: `docs/manual-test-checklist.md`, `docs/later.md`, `CLAUDE.md`,
  `docs/superpowers/specs/2026-09-21-goblinps-settings-and-marquee-design.md`,
  `GoblinPS/GoblinPS.toc` (version)

**Interfaces:** none (documentation only).

- [ ] **Step 1: The checklist**

In `docs/manual-test-checklist.md`, add this section directly after the
plan 8 section ("The planner as designed (plan 8)") and before
"## Flight paths survive a reload":

```markdown
## Settings, scrolling dash text, a narrower drop-down (plan 9)

**Needs a full game restart, not `/reload`:** the TOC gained `Marquee.lua` and
`Settings.lua`, and the client reads the file list only at startup. Built
2026-09-22; not yet run in the client.

- [ ] The gear opens the settings panel over the planner; the gear again,
      Close, and Escape each close it; closing the planner closes it too
- [ ] `/gps settings` with the planner closed opens the planner and the panel over it
- [ ] Every row's - and + change its value by one step; each stops at its end
      and that button greys out there
- [ ] The hearthstone row and `/gps hearth` agree: change one, the other shows it
- [ ] Reset to defaults puts back 5 min, 40, 150, 800 and 300 yd
- [ ] The panel looks decent without art -- or ask Codex for some (`docs/later.md`)
- [ ] Every label and value reads in full; the transport note and the amber
      line about saved data wrap inside the panel, not past it
- [ ] About shows "GoblinPS 2026.09.22.1". If it says "(version unknown)",
      `C_AddOns.GetAddOnMetadata` is one more API present on this build that
      does not answer: note it in CLAUDE.md's list
- [ ] The feedback line reads "Feedback: a GitHub page is coming soon." and
      no address is shown
- [ ] Lower "Boat, zeppelin, tram arrival" (say to 300 yd) and take a
      zeppelin: the dash advances only once you are that close to the far
      dock. Note how far from the dock's coordinates you really step off --
      that is the measurement the 800-yard default waits for
- [ ] A long step line on the dash (a long crossing name) holds about 1.5 s,
      then creeps left a character at a time, wraps round through a gap, and
      holds again; a short one holds still. If nothing ever scrolls,
      `GetUnboundedStringWidth` answers 0 on this build: say so
- [ ] On a step advance the new line starts at its beginning, never mid-name
- [ ] The glass's destination scrolls the same way when it is too long
- [ ] Type in the planner's box: the drop-down is only a little wider than the
      longest name, its left edge where it was, and no name in it is cut off.
      If it is still full width, the font measured 0 (see the line above)
```

- [ ] **Step 2: `docs/later.md`**

Delete the whole "**Scrolling text on the dash unit**" entry (it is built).
Add, as the first entry (newest at the top):

```markdown
- **Dress the settings panel with art.** Plan 9, 2026-09-22, built the panel
  plain: the gadget palette's body and brass, flat `-` / `+` buttons, no new
  parts, because the art is Codex's and nothing was asked of Codex. A dressed
  panel wants a frame, plate and button art like the planner's, and a
  geometry file for it, so its layout numbers come out of `Settings.lua` the
  way the planner's came out of `Planner.lua`.
```

- [ ] **Step 3: `CLAUDE.md`**

- Status: `**Status: plans 1 to 8 are built.**` becomes
  `**Status: plans 1 to 9 are built.**`. After the sentence ending
  "The rest of its checklist section is still to walk." add:
  "Plan 9, built 2026-09-22, put a settings panel behind the gear (the
  hearthstone's saving, four arrival radii, Reset, About), made the dash's
  too-long lines scroll like an old car radio (the pure `Marquee.lua`), and
  drew the drop-down only a little wider than its longest name. **Plan 9 has
  not been run in the client.**"
- The sentence "amended for plans 7 and 8 by
  `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`."
  becomes "amended for plans 7 and 8 by
  `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`
  and for plan 9 by
  `docs/superpowers/specs/2026-09-21-goblinps-settings-and-marquee-design.md`."
- Layout block: after the `Strip.lua` line add
  `GoblinPS/Marquee.lua          # pure: the dash's scrolling text, a character window`;
  change the `Known.lua, Prefs.lua` comment to
  `# pure: learned flight paths; account preferences, arrival radii and their ranges`;
  after the two `Planner.lua` lines add
  `GoblinPS/Settings.lua         # the settings panel behind the gear; plain, no art yet, so its spacing is its own`.

- [ ] **Step 4: The spec's status**

In `docs/superpowers/specs/2026-09-21-goblinps-settings-and-marquee-design.md`,
add a line directly under the `Status:` paragraph:
"Built 2026-09-22 by `docs/superpowers/plans/2026-09-22-goblinps-settings-and-marquee.md`
-- not yet run in the client."

- [ ] **Step 5: Version**

`GoblinPS/GoblinPS.toc`: `## Version: 2026.09.21.6` becomes
`## Version: 2026.09.22.1` (if another commit has already used that number,
take the next free one for the day, and change the checklist's About line to
match).

- [ ] **Step 6: Run every gate, then commit**

All five gates green; Lua still `387 passed, 0 failed`.

```
git add docs/manual-test-checklist.md docs/later.md CLAUDE.md docs/superpowers/specs/2026-09-21-goblinps-settings-and-marquee-design.md GoblinPS/GoblinPS.toc
git commit -m "Docs: plan 9 built, and what to walk in game" -m "The checklist gains the settings, scrolling text and drop-down section, with the full restart the new files need; later.md trades the built scrolling entry for dressing the settings panel; CLAUDE.md names Marquee.lua and Settings.lua and says plan 9 has not been run in the client. Version 2026.09.22.1." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

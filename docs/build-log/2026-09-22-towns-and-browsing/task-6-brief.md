### Task 6: the checklist, the notes, and the version

**Files:**
- Modify: `docs/manual-test-checklist.md`, `docs/later.md`, `CLAUDE.md`,
  `docs/research/2026-09-19-api-and-data-findings.md`,
  `docs/superpowers/specs/2026-09-22-goblinps-towns-and-browsing-design.md`,
  `GoblinPS/GoblinPS.toc` (version)

**Interfaces:** none (documentation and the version only).

- [ ] **Step 1: The checklist**

In `docs/manual-test-checklist.md`, add this section directly after the plan 9
section ("## Settings, scrolling dash text, a narrower drop-down (plan 9)")
and before "## Flight paths survive a reload":

```markdown
## Towns, a scrolling list, a zone browser (plan 10)

**Needs a full game restart, not `/reload`:** the TOC gained `Data\Towns.lua`,
and the client reads the file list only at startup. Built 2026-09-22; not yet
run in the client.

- [ ] "kha" lists "Kharanos · Dun Morogh"; "darn" lists Darnassus as a place
      ("Darnassus (Alliance)" to the Horde), not "Darnassus (zone)"
- [ ] "booty bay", "gadgetzan", "everlook": one row each, your own faction's
      stop, with no "(Alliance)" or "(Horde)" twin under it
- [ ] "theramore": the Theramore flight stop once, and no "Theramore Isle" row
      beside it
- [ ] Type "a": five rows, and under them the footer "1-5 of 194" (the same
      number for either faction), in its own line, not over the fifth row
- [ ] The wheel over the list moves it one row a notch ("2-6 of 194"), over a
      row as well as over the gaps, and stops at the top and at "190-194 of
      194". If the wheel does nothing, `EnableMouseWheel`/`OnMouseWheel` is
      one more thing present on this build that does not answer: say so
- [ ] After scrolling, Enter picks the top row shown, not the first match
- [ ] Typing another letter puts the list back at its top
- [ ] ▼ with the box empty, and clicking into the empty box: the recent
      destinations first, then every zone A to Z with its count, "Ashenvale
      (17)" among them; the wheel scrolls it
- [ ] Click "Ashenvale (17)": the box reads "Ashenvale" and keeps the cursor,
      the list shows its 17 places, and nothing is planned (the strip does
      not change)
- [ ] "Alterac Mountains (1)" and "Shen'dralas (1)" each list their one
      "(zone)" row
- [ ] Walk to a town the game's table added (Moonbrook in Westfall,
      Deathknell in Tirisfal Glades): its position is the town's middle, where
      the map draws its name, not a doorway. Note how far the "arrived" point
      sits from where you would want it
- [ ] A town's faction mark is inferred from flight masters within 600 yards:
      note any that is wrong (to the Alliance, Maraudon reads "(Horde)"
      because Shadowprey Village's flight master is near)
- [ ] The drop-down is still only a little wider than its longest name, and
      no name in it is cut off
- [ ] About shows "GoblinPS 2026.09.22.2"
```

In the plan 9 section, change the About line's version
`- [ ] About shows "GoblinPS 2026.09.22.1". If it says "(version unknown)",`
to `- [ ] About shows "GoblinPS 2026.09.22.2". If it says "(version unknown)",`
(plan 9 has not been walked, and the TOC's version moves on in Step 6).

- [ ] **Step 2: `docs/later.md`**

Add these three entries directly after the intro paragraph, as the newest:

```markdown
- **Place the three towns the generator cannot.** Plan 10, 2026-09-22:
  Dun Algaz, Scholomance and Ivar's Patch sit in two or three zone rectangles
  with no AreaID or area row to choose between them, so `build_graph.py`
  skips them (it prints each). A small hand-written table of `{ poi id = map }`
  overrides, read by the generator, would place them; Scholomance alone
  would have gone into The Hinterlands by the smallest rectangle.
- **Keep a destination's zone, not only its name.** The recents and a saved
  trip hold a name, and `Search.Exact` takes the lower ID on a tie. The two
  ends of Timbermaw Hold (Felwood, Winterspring) and of The Talondeep Path
  (Ashenvale, Stonetalon Mountains) share a name, so picking the higher-ID
  end comes back as the other end after a reload or from the recents.
- **Faction-aware avoidance of enemy towns** (the plan 10 spec's step 4,
  next). The towns now carry an inferred faction; the router does not yet
  keep you out of the other side's. The inference is crude (Maraudon reads
  Horde because Shadowprey's flight master is near); `AreaTable` carries a
  `FactionGroupMask` that may say more, unverified on this build.
```

- [ ] **Step 3: `CLAUDE.md`**

- Status: `**Status: plans 1 to 9 are built.**` becomes
  `**Status: plans 1 to 10 are built.**`. After the sentence ending
  "**Plan 9 has not been run in the client.**" add: "Plan 10, built
  2026-09-22, made every named town on the world map a destination
  (`Data/Towns.lua`, 150 towns generated from the game's own `AreaPOI`), let
  the results list scroll on the wheel with a footer, and made the empty
  box's drop-down a zone browser. **Plan 10 has not been run in the client.**"
- The lines

  ```
  and for plan 9 by
  `docs/superpowers/specs/2026-09-21-goblinps-settings-and-marquee-design.md`.
  ```

  become

  ```
  for plan 9 by
  `docs/superpowers/specs/2026-09-21-goblinps-settings-and-marquee-design.md`
  and for plan 10 by
  `docs/superpowers/specs/2026-09-22-goblinps-towns-and-browsing-design.md`.
  ```

- Layout block: directly after the `GoblinPS/Data/*.lua          # GENERATED from wago.tools by tools/build_graph.py`
  line add
  `GoblinPS/Data/Towns.lua      # GENERATED from AreaPOI: every named town in its zone, an inferred faction; stops and Inns rows win`,
  and change the `Data/Inns.lua` line's comment to
  `# HAND-WRITTEN: hearthstone bind names Search cannot find alone; a row wins over a generated town of its name`.

- [ ] **Step 4: The research notes and the spec's status**

In `docs/research/2026-09-19-api-and-data-findings.md`, in the table under
"## Game data (fetched from wago.tools for build 1.60.1.69913)", add after the
`UiMapAssignment` row:

```markdown
| `AreaPOI` | 372 | named places on the world map: `Name_lang`, world `Pos_0`/`Pos_1` (the same axes as `TaxiNodes`: Thunder Bluff's label is 8 yd from its flight master), `ContinentID`, `AreaID` (0 or -1 on 63 of the 207 town-icon rows), `Icon` (4 town, 5 capital, 6 village or outpost), `WorldStateID` (non-zero on event labels). Read 2026-09-22 for plan 10 |
| `AreaTable` | 1372 | the area tree: `AreaName_lang`, `ParentAreaID` (0 at the top), `ContinentID`; climbs a POI's `AreaID`, or its own name, to its zone |
```

In `docs/superpowers/specs/2026-09-22-goblinps-towns-and-browsing-design.md`,
add a line directly under the `Status:` paragraph:
"Built 2026-09-22 by `docs/superpowers/plans/2026-09-22-goblinps-towns-and-browsing.md`
-- not yet run in the client. Its rulings (zone by name before rectangle,
duplicates by name and zone rather than 300 yards, event labels left out)
are listed there."

- [ ] **Step 5: Version**

`GoblinPS/GoblinPS.toc`: `## Version: 2026.09.22.1` becomes
`## Version: 2026.09.22.2` (if another commit has already used that number,
take the next free one for the day, and change both checklist About lines to
match).

- [ ] **Step 6: Run every gate, then commit**

All five gates green; Lua still `469 passed, 0 failed`, Python `Ran 70 tests`,
`OK`.

```
git add docs/manual-test-checklist.md docs/later.md CLAUDE.md docs/research/2026-09-19-api-and-data-findings.md docs/superpowers/specs/2026-09-22-goblinps-towns-and-browsing-design.md GoblinPS/GoblinPS.toc
git commit -m "Docs: plan 10 built, and what to walk in game" -m "The checklist gains the towns, scrolling list and zone browser section, with the full restart Data/Towns.lua needs; later.md notes the three unplaced towns, the tunnel ends that share a name, and faction-aware avoidance; CLAUDE.md names Data/Towns.lua and says plan 10 has not been run in the client; the research notes add AreaPOI and AreaTable. Version 2026.09.22.2." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Spec coverage

| Spec | Task |
|---|---|
| 1. Fetch `AreaPOI` (and `AreaTable`), emit `Data/Towns.lua` `{ name, map, mx, my, c, x, y, f? }` | 1, 2 |
| 1. Zone from AreaID via `ParentAreaID`, then fallback; report and skip unplaced; measured numbers | 1 (ruling 1), numbers above |
| 1. Faction within 600 yd of a one-faction flight master; capitals from their own stop | 1 (ruling 5) |
| 1. Duplicates: stop or inn row wins | 1 (stops), 3 (inn rows); ruling 3 |
| 1. Hand-written data still wins; Inns rows stay | 3 (ruling 4) |
| 2. Candidates offers stops, towns, inn towns; a zone only when it holds none | 3 |
| 2. Same-named enemy stop not offered | 3 |
| 2. Cross-faction tie pinned, enemy on the lower ID | 3 |
| 2. Town row reads "Kharanos · Dun Morogh", enemy mark by inferred faction | 3 (existing `rowLabel`, `enemy` from `fromTown`) |
| 3. Wheel scrolls, one row a notch, clamped; still `fit` rows | 4 |
| 3. Footer "6-10 of 23", bounded, hidden when all fits, inside the list's height | 4 (ruling 7) |
| 3. Enter picks the top shown row; typing resets | 4 |
| 3. The search returns every match | 4 (ruling 8) |
| 4. Empty box (▼ and focus): recents, then every zone A to Z with its count | 5 |
| 4. Zone row is a way in: fills the box, lists its places; never routed | 5 (ruling 9) |
| 4. Fallback zones listed like any zone | 5 |
| Tests: generator (filter, zone both ways, faction, duplicates, fields) | 1 |
| Tests: real data (loads, in rectangle, Darnassus/Kharanos/Sentinel Hill, fallback list, no duplicate within 300 yd) | 2, 3 (ruling 11) |
| Tests: search (towns, hidden enemy twin, tie) | 3 |
| Tests: planner (wheel, clamp, footer, Enter, reset, browser, zone click, never routed) | 4, 5 |
| In game checklist | 6 |

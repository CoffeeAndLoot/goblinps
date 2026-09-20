### Task 4: Documents

**Files:**
- Modify: `docs/manual-test-checklist.md`, `docs/superpowers/specs/2026-09-19-goblinps-design.md`, `CLAUDE.md`, `docs/research/2026-09-19-api-and-data-findings.md`

Read each file in full before editing. Make the listed changes and nothing else; when a sentence to change is hard-wrapped across lines, replace the whole sentence and re-wrap only that paragraph to about 78 columns, keeping its indentation.

- [ ] **Step 1: Add this section to the end of `docs/manual-test-checklist.md`**

```markdown
## Ground crossings (plan 3)

Restart the game first: the TOC changed.

- [ ] On a character below level 40 with no flight paths, plan to a zone two
      or more zones away: every ground step says "Walk to ..." and names a
      crossing; none says "(no mapped path)"
- [ ] The undead start: `/gps to mount hyjal` from Tirisfal gives the zeppelin,
      Orgrimmar's front gate, Orgrimmar's west gate, the Mor'shan Rampart, the
      road into Felwood, the Timbermaw Hold tunnels, Darkwhisper Gorge
- [ ] In the planner each ground step has a second, smaller line ("into
      Ashenvale · level 18-30"); it is amber when the zone is well above the
      character's level or the crossing has a hazard, dim otherwise
- [ ] `/gps to` prints the same detail line under each ground step in chat
- [ ] Both layouts: the two-line rows fit, nothing overlaps the hint, the
      total or GO; a route longer than 8 steps ends "... and N more steps"
- [ ] On a level 40+ character the steps say "Ride to ..." and the times are
      shorter. **Record the level at which this character got its first mount
      and its speed**, and the same for the fast mount: `GoblinPS/Travel.lua`
      holds guesses (40 and 60) until then
- [ ] GO on a crossing step puts Blizzard's pin on the crossing
- [ ] **Walk each crossing you pass and check its point.** Stand in the
      gateway, run
      `/run print(C_Map.GetBestMapForUnit("player"), C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit("player"),"player"):GetXY())`
      and compare with the row in `GoblinPS/Data/Crossings.lua`; correct the
      row if it is off by more than 0.03. Record the ones checked here
- [ ] Orgrimmar's west gate: confirm it opens into the Barrens and where
- [ ] New zones, all `unverified = true` in the table: Darkwhisper Gorge into
      Mount Hyjal, the Valley of Bones into Shen'dralas, the Riverglades
      turnoff from Redridge and its borders with the Burning Steppes, the
      Swamp of Sorrows and the Badlands. Record the real crossings
- [ ] Any step that says "(no mapped path)": record from where to where; a
      crossing row is missing
- [ ] Teldrassil still needs the boat; a Darnassus character leaves by "the
      Darnassus gate"
```

- [ ] **Step 2: Correct the spec** (`docs/superpowers/specs/2026-09-19-goblinps-design.md`):
  - In the "`Graph` (pure)" bullet, the sentence saying that from plan 3 "the Feathermoon ferry returns as an ordinary link" is wrong. Replace that clause so the sentence says: the `Islands` table and the 800-yard transfer rule are deleted, and the travel speed comes in with the options; then add the sentence: `Sardor Isle shares Feralas's map, and ground travel is per map, so the isle still counts as part of Feralas and its ferry stays out (a ride inside the zone would always undercut it).`
  - In the "Hand-written for ground travel (plan 3)" list, replace the `Data/Crossings.lua` bullet's sentences about the atlas (from "The atlas fan site has a similar table" to "are our own.") with: `Which zones border which, the place names and the level ranges are facts about Blizzard's game; the Forever Atlas fan site's table served as a checklist of those facts and supplied four crossings the first draft missed. The rows, the wording and every coordinate are our own; the atlas's prose, drawn zone shapes and code are its author's and are not used.` Change "about 55 rows" to "56 rows".
  - In decision 15, after the list of city gates, nothing changes. In "Still to verify in game", the bullet about crossing coordinates: append `Shen'dralas is entered from Desolace by the Valley of Bones (stated by Blizzard); Riverglades also borders the Burning Steppes, the Swamp of Sorrows and the Badlands (stated by Blizzard, crossing points unknown).`
  - In the status paragraph at the top, change `2 planner window (built)` to `2 planner window (built), 3 ground crossings with walk-or-ride by level (built)` and remove the now-duplicated `3 ground crossings with walk-or-ride by level,` that follows, so the list still reads 1 to 5 in order.

- [ ] **Step 3: Update `CLAUDE.md`.**
  - Status paragraph: say plans 1 to 3 are built (routing core, planner window, ground crossings); next is plan 4, the dash unit, then plan 5, the schematic map. Keep the sentence that the product is a GPS.
  - In the layout block, add after the `Data/Inns.lua` line:

```
GoblinPS/Data/Crossings.lua  # HAND-WRITTEN: zone-to-zone crossings and city gates (coords are estimates until walked)
GoblinPS/Data/Zones.lua      # HAND-WRITTEN: level range per zone, for the amber warnings
GoblinPS/Travel.lua          # pure: walk or ride by level; the ONLY place mount levels and speeds live (unconfirmed)
```

  - Under "Rules that are easy to break", add:

```markdown
- Ground travel is per zone: a ride edge joins two points only when they
  share a UiMap, and a crossing belongs to both of its zones. Every place
  handed to the router needs its `map`. A missing crossing shows up as a step
  labelled "(no mapped path)"; add the row to `Data/Crossings.lua`, do not
  loosen the rule. `test/test_crossings.lua` checks every row and that each
  continent's zones all connect.
```

- [ ] **Step 4: Correct `docs/research/2026-09-19-api-and-data-findings.md`.** In the "Forever Atlas" section, replace the sentence that begins `**No license**, so all rights reserved:` (through `its own browser route planner, which cannot know a character's flight paths.` stays) with: `The site has **no license**, which covers its author's own work: the prose, the hand-drawn zone shapes and the code. None of that is used. The facts it records (which zones border which, place names, level ranges, which routes Blizzard has announced) are facts about Blizzard's game and are used freely, as a checklist against our own tables.`

- [ ] **Step 5: Run the Lua tests and luacheck once more** (`160 passed, 0 failed`, `0 warnings`), then commit

```
git add docs CLAUDE.md
git commit -m "Docs: ground crossings checklist, spec corrections, atlas facts" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 6: Hand over.** In your report: the desktop work is verified; nothing in this plan has run in the game client; the user must restart the game (the TOC changed) and work through `## Ground crossings (plan 3)`. Do not claim any of those checks pass.

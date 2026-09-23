### Task 6: the checklist, the notes, and the version

**Files:**
- Modify: `docs/manual-test-checklist.md`, `docs/later.md`, `CLAUDE.md`,
  `docs/superpowers/specs/2026-09-22-goblinps-enemy-towns-design.md`
  (status), `GoblinPS/GoblinPS.toc` (version)

**Interfaces:** none (documentation and the version only).

- [ ] **Step 1: The checklist**

Insert into `docs/manual-test-checklist.md` directly before

```markdown
## Flight paths survive a reload
```

this section:

```markdown
## Routes round enemy towns (plan 11)

**Needs a full game restart, not `/reload`:** the TOC gained
`Data\Stopovers.lua`, and the client reads the file list only at startup.
After that one restart, editing it needs only `/reload`. Built 2026-09-22;
not yet run in the client. Plan routes on foot with no flight path learned
this session (straight after logging in), or the router will simply fly. A
town is an enemy only if it has an enemy flight master or you marked it in
`tools/town-factions.csv`; after marking one, run `python
tools/build_graph.py` and `/reload`.

- [ ] Horde, level 15, at the Talondeep Path's Ashenvale mouth (42.3, 71.1),
      `/gps to splintertree post`: the route is "Walk to the Ashenvale-Felwood
      road", then "Walk to Splintertree Post", about 11 minutes, no longer
      the straight line through Silverwind Refuge (the way by the Mor'shan
      Rampart passes Silverwing Grove, which you marked Alliance). Walk it
      with the dash: say whether the two long legs across Ashenvale are
      walkable, and whether anything attacks. If not, that is what a stopover
      is for
- [ ] Horde, from Sun Rock Retreat, `/gps to splintertree post`: down the
      Stonetalon pass, then the Mor'shan Rampart, then Splintertree Post, and
      not through the Talondeep Path any more
- [ ] Horde, from Hammerfall (Arathi Highlands), `/gps to revantusk village`:
      the last step, "Walk to Revantusk Village" (Ride from level 40), has
      the tooltip detail "in The Hinterlands · passes Aerie Peak (Alliance)"
      in amber: there is no way round under ten minutes. From level 35 the
      line under the strip reads "Revantusk Village: in The Hinterlands ·
      passes Aerie Peak (Alliance)"; below it the step before, "into The
      Hinterlands · level 40-50", is amber first and takes the line
- [ ] Horde, pick Silverwind Refuge: the line under the strip reads
      "Silverwind Refuge is an Alliance town: its guards will attack you.",
      and `/gps to silverwind refuge` prints the same line first in chat.
      Its row in the list reads "Silverwind Refuge · Ashenvale (Alliance)"
- [ ] Alliance, pick Splintertree Post: "Splintertree Post is a Horde town:
      its guards will attack you." A neutral town (Booty Bay, Gadgetzan,
      Ratchet) says nothing of the kind, to either side
- [ ] Caves and rivers are nobody's enemy now: to the Alliance "maraudon"
      lists Maraudon with no "(Horde)", and to the Horde "irontree" lists
      Irontree Cavern with no "(Alliance)"
- [ ] Walk toward Silverwind Refuge from outside and stop where its guards
      first come for you; `/gps where` there. Note the yards from the town's
      label (50.1, 66.2). The circle is 150 yards (`Graph.HOSTILE_RADIUS`) and
      400 round a capital (`Graph.CAPITAL_RADIUS`); both are guesses
- [ ] Once a stopover row is in `Data/Stopovers.lua` (measure it with
      `/gps where`, divide by 100, `/reload`): a route that passed the town
      bends through it, the step reads "Walk to <its name>", and the dash
      walks you round alive
- [ ] The dash's step lines are unchanged: the detail line with "passes" is
      only in the planner's tooltips, on its warning line and in chat
- [ ] About shows "GoblinPS 2026.09.22.3"
```

In the plan 10 section, replace the line that no longer holds,

```markdown
- [ ] A town's faction mark is inferred from flight masters within 600 yards:
      note any that is wrong (to the Alliance, Maraudon reads "(Horde)"
      because Shadowprey Village's flight master is near)
```

with

```markdown
- [ ] A town's "(Alliance)" or "(Horde)" mark comes only from
      `tools/town-factions.csv` since plan 11: to the Alliance, Maraudon no
      longer reads "(Horde)"
```

In the plan 9 section, replace

```markdown
- [ ] About shows "GoblinPS 2026.09.22.2". If it says "(version unknown)",
```

with

```markdown
- [ ] About shows "GoblinPS 2026.09.22.3". If it says "(version unknown)",
```

and in the plan 10 section replace its last line,

```markdown
- [ ] About shows "GoblinPS 2026.09.22.2"
```

with

```markdown
- [ ] About shows "GoblinPS 2026.09.22.3"
```

(neither section has been walked, and the TOC's version moves on in Step 5).

- [ ] **Step 2: `docs/later.md`**

The plan 10 entry "Faction-aware avoidance of enemy towns" graduates into
this plan, so it comes off the list, and the owner's monster camps take its
place. Replace

```markdown
- **Faction-aware avoidance of enemy towns** (the plan 10 spec's step 4,
  next). The towns now carry an inferred faction; the router does not yet
  keep you out of the other side's. The inference is crude (Maraudon reads
  Horde because Shadowprey's flight master is near); `AreaTable` carries a
  `FactionGroupMask` that may say more, unverified on this build.
```

with

```markdown
- **Monster camps that are hostile to all.** The owner's Notes column in
  `tools/town-factions.csv` says "Hostile to all" on nine camps (Boulderfist
  Outpost, Drywhisker Gorge, Bloodtooth Camp, Demon Fall Canyon, Falfarren
  River, Greenpaw Village, The Dor'Danil Barrow Den, The Ruins of Ordil'Aran,
  Xavian); plan 11 reads no Notes, so a ride leg still walks straight through
  them. A fourth faction letter (say `M`, hostile to both sides) in the
  faction column would let `Graph.Hostile` charge a leg past one for either
  side.
```

- [ ] **Step 3: `CLAUDE.md`**

Replace `**Status: plans 1 to 10 are built.**` with
`**Status: plans 1 to 11 are built.**`.

Replace

```markdown
box's drop-down a zone browser. **Plan 10 has not been run in the client.** A
```

with

```markdown
box's drop-down a zone browser. **Plan 10 has not been run in the client.**
Plan 11, built 2026-09-22, made a ride leg that passes an enemy town cost
ten minutes more, so the router goes round it and says so in amber when it
cannot; a town's faction now comes only from the owner's
`tools/town-factions.csv`, and `Data/Stopovers.lua` holds ways round.
**Plan 11 has not been run in the client.** A
```

Replace

```markdown
and for plan 10 by
`docs/superpowers/specs/2026-09-22-goblinps-towns-and-browsing-design.md`.
```

with

```markdown
for plan 10 by
`docs/superpowers/specs/2026-09-22-goblinps-towns-and-browsing-design.md`
and for plan 11 by
`docs/superpowers/specs/2026-09-22-goblinps-enemy-towns-design.md`.
```

In the Layout block, replace

```text
GoblinPS/Data/Towns.lua      # GENERATED from AreaPOI: every named town in its zone, an inferred faction; stops and Inns rows win
```

with

```text
GoblinPS/Data/Towns.lua      # GENERATED from AreaPOI: every named town in its zone, a faction only from tools/town-factions.csv; stops and Inns rows win
```

insert directly after the line

```text
GoblinPS/Data/Crossings.lua  # HAND-WRITTEN: zone-to-zone crossings and city gates (coords are estimates until walked)
```

the line

```text
GoblinPS/Data/Stopovers.lua  # HAND-WRITTEN: named points a ride may bend through round an enemy town; empty until walked
```

and insert directly after the line

```text
tools/catalog.lock           # pinned client build
```

the line

```text
tools/town-factions.csv      # HAND-WRITTEN by the owner: A, H or N per generated town; the only source of a town's faction
```

In "Rules that are easy to break", insert directly before

```markdown
- **"Zero lint warnings" is not licence to silence one instead of fixing
```

this rule:

```markdown
- **An enemy town is a penalty, never a ban, and only a known one.** A ride
  leg whose straight line passes the other side's flight master, or a town
  the owner marked in `tools/town-factions.csv`, within its radius costs
  `Graph.HOSTILE_SECONDS` more and carries `danger`; flights, links, the
  hearthstone and a tunnel's through leg are never charged, and a leg with an
  end inside the circle is exempt, so every enemy town stays reachable on
  purpose. No code guesses a town's faction (the nearest-flight-master guess
  made caves and rivers into towns). A route that walks through a town is
  fixed by marking it, or with a `Data/Stopovers.lua` row measured in game,
  never by removing the edge or shrinking the radius until a test passes.
```

- [ ] **Step 4: The spec's status**

Insert into `docs/superpowers/specs/2026-09-22-goblinps-enemy-towns-design.md`
directly before

```markdown
## Why
```

these lines:

```markdown
Built 2026-09-22 by `docs/superpowers/plans/2026-09-22-goblinps-enemy-towns.md`
-- not yet run in the client. Its rulings (a capital is the place named after
its zone, the constants in `Graph.lua`, split neutral towns never hostile, a
leg named after a flight master before a marked town, and the Talondeep
route now going round by the Ashenvale-Felwood road) are listed there.
```

- [ ] **Step 5: Version**

In `GoblinPS/GoblinPS.toc`, replace `## Version: 2026.09.22.2` with
`## Version: 2026.09.22.3` (if another commit has already used that number,
take the next free one for the day, and change all three checklist About
lines to match).

- [ ] **Step 6: Run every gate, then commit**

All five gates green; Lua still `505 passed, 0 failed`, Python `Ran 74
tests`, `OK`.

```
git add docs/manual-test-checklist.md docs/later.md CLAUDE.md docs/superpowers/specs/2026-09-22-goblinps-enemy-towns-design.md GoblinPS/GoblinPS.toc
git commit -m "Docs: plan 11 built, and what to walk in game" -m "The checklist gains the enemy towns section, with the full restart Data/Stopovers.lua needs, the Talondeep walk round Silverwind Refuge by the Ashenvale-Felwood road, Sun Rock by the Barrens, a route that still passes Aerie Peak, the destination note, caves that are nobody's enemy and the radius to measure; plan 10's inferred-faction line is corrected. later.md swaps the graduated faction-aware entry for the owner's monster camps. CLAUDE.md names tools/town-factions.csv and Data/Stopovers.lua and the known-enemies-only rule, and says plan 11 has not been run in the client. Version 2026.09.22.3." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Spec coverage

| Spec (section 1 as revised in Task 1) | Task |
|---|---|
| 1. Hostile only when the faction is known: enemy flight stops (minus split neutral towns), marked towns | 4 (`Graph.Hostile`); ruling 3 |
| 1. Town `f` only from `tools/town-factions.csv`; A/H is `f`, N/blank none; guess and Notes unread; no nearest-flight-master rule | 1 |
| 1. A row naming no generated town: printed, nothing written, Python tests fail | 1 (Step 7 shows it); ruling 4 |
| 1. `Data/Hostile.lua` dropped; Silverwind from `Towns.f` | 1 (Towns.lua), 4 (real-data test) |
| 1. Radius 150, capital 400 (named after its zone), named constants | 4; rulings 1, 2 |
| 1. Surer source names the leg: flight master, then marked town | 4 ("names a leg after the surer...") |
| 1. Hostile only to the other faction; neutral never | 4 ("never counts a neutral stop...", "leaves the leg alone...") |
| 2. Every ride edge tested against its continent's hostile places; +600 and `danger`; stable order | 4 |
| 2. Exempt when either end is inside | 4 ("exempts a leg...") |
| 2. Penalty, not ban; destination never unreachable | 4 ("still goes straight through...") |
| 2. Flights, links, hearthstone, through edges never penalised; rough edges tested | 4 ("never charges a flight, a boat, the hearthstone or a tunnel's passage", "tests a rough straight line") |
| 3. `Data/Stopovers.lua`, one-zone stops joined in their zone, "Ride to <name>", empty with a header | 3, 4 ("adds a stopover...", which reads "Ride to the north road"); ruling 8 |
| 4. Amber "passes <name> (<faction>)", replaces the level range, `warn = true`, tooltip and warning line | 5; ruling 7 |
| 4. Hostile destination note, warning line and `/gps to` | 5; rulings 5, 6 |
| 4. Dash unchanged | (untouched) |
| 5. `opts.faction`; no faction, nothing hostile | 4 ("lists the other side's flight master...") |
| Tests: pure geometry | 2 |
| Tests: graph | 4 |
| Tests: route (amber line, hostile note) | 5 |
| Tests: real data (Talondeep, Horde and Alliance) | 4; ruling 9 |
| Tests: data (the sheet names real towns and matches Towns.lua; Irontree Cavern has no `f`; stopovers on their map) | 1, 3 |
| In game checklist | 6 |

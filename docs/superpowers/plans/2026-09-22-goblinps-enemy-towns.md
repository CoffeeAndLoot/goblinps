# Routes That Go Round Enemy Towns (plan 11) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a ride leg that passes a known enemy town cost ten minutes
more, so the router goes round when it can, and say so in amber ("passes
Silverwind Refuge (Alliance)") when it cannot; give the router hand-written
stopovers to go round by; warn when the destination itself is an enemy town;
and take a town's faction only from the owner's own sheet, never a guess.

**Architecture:** `tools/build_graph.py` stops guessing town factions from
nearby flight masters and writes `f` into `Data/Towns.lua` only from the
owner's `tools/town-factions.csv` (A or H; N or blank is none), failing loudly
on a row that names no generated town. `Geo.SegmentDistance` measures how
close a straight leg passes a point. `Graph.Hostile(data, faction)` builds the
enemy places for one plan from the other side's flight masters (minus the
split neutral towns) and the other side's marked towns, each a circle of
`Graph.HOSTILE_RADIUS` or, for a capital, `Graph.CAPITAL_RADIUS`.
`Graph.Build` tests every ride edge (rough ones too) against the circles on
its continent, adds `Graph.HOSTILE_SECONDS` and `danger = { name, f }` to one
that passes a circle neither of its ends is inside, and adds each
`Data/Stopovers.lua` row as an ordinary one-zone stop. `Route` carries
`danger` onto the step and words it; `Core.PlanRoute` adds a note when the
destination stands in a circle (`Graph.HostileAt`), and the planner puts that
note first on the line under the strip.

**Tech Stack:** Lua 5.1 against the WoW Forever client API (build
1.60.1.69913, interface 16001), no libraries; desktop tests through lupa;
the generator and its tests in Python 3 (`unittest`).

**Spec:** `docs/superpowers/specs/2026-09-22-goblinps-enemy-towns-design.md`
(binding), whose section 1 Task 1 rewrites to the owner's ruling of
2026-09-22 (below).

## The owner's ruling (2026-09-22), which this plan follows

- A place is hostile only when its faction is **known**: the other side's
  flight masters (minus the split neutral towns) and the towns the owner has
  marked.
- The generator **stops inferring** town factions from nearby flight masters.
  `_town_faction` and its tests go.
- Towns get `f` only from `tools/town-factions.csv` (committed at `ba22a29`;
  columns zone, town, x, y, guess, "faction (A/H/N)", Notes). A blank or N
  means no `f`. The generator reads it like `catalog.lock`. A row naming a
  town the generator does not produce is a loud error, printed, and it fails
  the Python tests. The guess and Notes columns are ignored.
- `Data/Hostile.lua` is **dropped**: Silverwind Refuge comes from its mark in
  the sheet. `Data/Stopovers.lua` stays.
- Capitals: a hostile place named after its own zone.
- A leg that passes two is named after the surer source: a flight master,
  then a marked town.

## Global Constraints

- Plain Lua 5.1, **no libraries**, **no Blizzard frame templates**, no secure code.
- `API.lua` is the only file that calls Blizzard game APIs. This plan adds no
  API call, no event and no widget method: everything new in Lua is pure
  (`Geo`, `Graph`, `Route`) or a data file, plus a few lines of
  `Core.PlanRoute` and one branch of `Planner.Refresh`.
- **Never read a size from a frame that only inherits one**, and **a test
  that checks how big a thing is cannot tell you it is in the wrong place**:
  this plan draws nothing new. The warning line (`ui.hint`) is an existing,
  bounded FontString; only its text changes.
- Route text stays plain and glanceable. "passes Silverwind Refuge
  (Alliance)" and "Silverwind Refuge is an Alliance town: its guards will
  attack you." are facts, not jokes.
- `Data/Towns.lua`, `Data/Nodes.lua`, `Data/Places.lua` and
  `Data/Flights.lua` are **generated**; nobody edits them by hand.
  `Data/Towns.lua` is regenerated once, in Task 1, by running the generator.
  `tools/town-factions.csv` is **the owner's**: this plan reads it and never
  edits it. `Data/Stopovers.lua` is hand-written.
- Present is not the same as answering on this build (CLAUDE.md). A check
  must be able to fail: every data check here is shown failing on a planted
  row, since `Data/Stopovers.lua` starts empty and the sheet may grow.
- Lint and the language server at **zero warnings**; do not silence a
  warning, fix the code. No new `---@diagnostic disable`, `luacheck:`
  exemption or `max_line_length = false`. A new WoW global goes in **both**
  `.luacheckrc` and `.luarc.json` (this plan adds none).
- Never guess an event, API or method name: check it in
  `D:\wow-api\1.60.1.69913` (the `forever` branch). This plan names none.
- Any widget method the fake frames do not model is added to
  `test/fake_frames.lua` in the task that first calls it. This plan calls
  none that is new.
- Commit after each task. **Never stage `AGENTS.md`** (it belongs to Codex).
  Never push. Do not switch branches: the work is on `enemy-towns`.
- Gates, all green before a task is done (run from `D:\goblinps`):
  - Lua: `python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"`
  - Python: `python -m unittest discover -s test/tools`
  - Art: `python tools/check_art.py`
  - luacheck and lua-language-server **from PowerShell**, as in `CLAUDE.md`
    ("Commands"). Through Git Bash the language server mis-scopes itself and
    reports bogus warnings.
- Known state at the start (checked 2026-09-22 on this branch at `ba22a29`):
  Lua **471 passed, 0 failed**; Python **Ran 70 tests, OK**; `check_art.py`
  `47 pass, 0 with problems, 0 not drawn yet`. This plan touches no art, so
  that gate must simply stay green.
- Every count below was measured by building this plan in a scratch worktree
  from `ba22a29` and running every gate after every step.

## Dependency on plan 10

The project rule is to write each plan after the one before it has been used
in game. Plan 10 has not been run in the client; the owner is playing from
this checkout, and asked for this plan after dying at Silverwind Refuge. Plan
11 changes plan 10's generator (the faction rule only) and reads its
`Data/Towns.lua`; plan 10's Lua is untouched but for a comment in
`Search.lua`. Each task commits alone and leaves every gate green, so any
one can be reverted. `Graph.Build` reads `data.Stopovers or {}` on purpose: a
`/reload` after Task 4 without the full restart the TOC change needs still
works, just with no stopovers.

## What the data says (measured 2026-09-22 on the shipped data)

- **The sheet.** `tools/town-factions.csv` has 150 rows, one per generated
  town, keyed here by zone and town (the Talondeep Path has a row in
  Ashenvale and one in Stonetalon Mountains). Eight are marked: The Tower of
  Arathor A, Bathran's Haunt H, Forest Song A, Silverwind Refuge A,
  Silverwing Grove A, Silverwing Outpost A, The Talondeep Path N, Warsong
  Labor Camp H. Every row names a generated town. Nine rows carry "Hostile to
  all" in Notes (monster camps), which nothing reads (`later.md`, Task 6).
- **The regenerated `Data/Towns.lua`** carries `f` on 7 towns, the sheet's A
  and H marks, where the old guess put it on 28 (Maraudon, Irontree Cavern,
  Falfarren River and 25 more). 35 of its 150 lines change; nothing else in
  it does. `Places.lua`, `Nodes.lua` and `Flights.lua` come out byte-for-byte
  the same, line endings aside. Darnassus is not marked, so it loses its
  "(Alliance)" in the Horde's list and is nobody's enemy until the owner
  marks it.
- **Hostile places.** To the Horde **29**: 24 Alliance flight masters (32
  less the 8 that share a short name with a Horde one: Booty Bay, Gadgetzan,
  Everlook, Moonglade, Nighthaven, Light's Hope Chapel, Cenarion Hold,
  Thorium Point) and 5 marked towns (Forest Song, Silverwind Refuge,
  Silverwing Grove, Silverwing Outpost, The Tower of Arathor); 15 in the
  Eastern Kingdoms, 14 in Kalimdor. To the Alliance **25**: 23 Horde flight
  masters (31 less the same 8) and 2 marked towns (Bathran's Haunt, Warsong
  Labor Camp); 10 and 15.
- **Capitals (400 yards):** to the Horde Ironforge and Stormwind; to the
  Alliance Orgrimmar, Thunder Bluff and Undercity. Darnassus would be the
  third against the Horde once marked.
- **The owner's route.** From the Talondeep Path's Ashenvale mouth (42.3,
  71.1) the straight line to Splintertree Post (73.3, 61.7) passes **97
  yards** from Silverwind Refuge (50.1, 66.2). For a level 15 Horde walker
  that line is 338 s, now 938 s with Silverwind Refuge's danger. The way by
  the Mor'shan Rampart now passes Silverwing Grove (marked Alliance), so the
  router goes north instead: **"Walk to the Ashenvale-Felwood road"** (339 s),
  then **"Walk to Splintertree Post"** (307 s): 645 s, 307 s longer than
  straight, with no danger on either leg and neither within 150 yards of
  Silverwind Refuge. The same two steps at level 60 (323 s). So the spec's
  old real-data expectation ("a step with `danger` naming Silverwind Refuge,
  until a stopover exists") does not hold: there is already a way round.
  Ruling 9.
- **The Alliance on the same line** walks it straight, one step, 338 s, no
  danger: nothing on it is hostile to the Alliance any more (under the old
  guess it was charged for Falfarren River).
- **Existing real-route tests that change** (Task 4): the walk from Tirisfal
  Glades to Mount Hyjal gains a step, going from the Mor'shan Rampart round
  by the Ashenvale-Darkshore road, because the straight line to the
  Ashenvale-Felwood road passes Silverwing Outpost; its step to the Timbermaw
  Hold tunnels still passes Talonbranch Glade (Task 5 words it). From Sun
  Rock Retreat, Splintertree Post is no longer reached through the Talondeep
  Path (it goes down the Stonetalon pass and up through the Mor'shan
  Rampart), so the tunnel test goes to Zoram'gar Outpost instead.
- **Every stop-to-stop walk** on one continent with no flight path known,
  462 for the Horde and 482 for the Alliance: **106 Horde and 136 Alliance
  routes change course**, and **110 and 22 keep a danger step** because no way
  round is under ten minutes: to the Horde Talonbranch Glade (84), Aerie Peak
  (24), Forest Song (8); to the Alliance Grom'gol (18), Tarren Mill (4).
- **Hostile destinations:** 30 of the Horde's candidates and 25 of the
  Alliance's stand in an enemy circle. Every one is already marked
  "(Alliance)" or "(Horde)" by Search except Wildhammer Keep for the Horde,
  which stands inside Aerie Peak's circle, so its note names Aerie Peak. No
  neutral town (Booty Bay, Gadgetzan, Ratchet) gets a note; Maraudon and
  Irontree Cavern get none.
- **Cost, in lupa's Lua 5.1 on this box.** With every flight path known a
  `Graph.Build` goes from 4.5 ms to **5.2 ms**, and one replan (`Route.Plan`
  plus `Route.Hint`, three to four builds) from 8.8 ms to **10.7 ms**. With no
  flight path known a build goes from 2.2 to 2.7 ms. Without the bounding-box
  pre-check in `dangerOn` a build took 8.1 ms and a replan 16.2: the
  pre-check is three lines and halves the cost, so it is in. A replan happens
  on a click or when the player strays, never per frame, so 11 ms is
  acceptable. If it ever is not: build `Graph.Hostile` once per faction
  instead of once per `Graph.Build`, then share one edge-danger table across
  the builds of a single `Route.Plan`/`Route.Hint` (their stops differ only
  by known flight masters), and only then bucket the circles by zone.

## Rulings this plan makes (the owner's ruling and the spec left these open)

Record each in the ledger for the owner.

1. **A capital is the place named after its own zone** (the owner kept this):
   a hostile place whose name begins its zone's name, "Orgrimmar" in
   Orgrimmar, "Stormwind" in Stormwind City, the town "Darnassus" in
   Darnassus once marked. `Data/Towns.lua` carries no icon. The only other
   match is Moonglade's pair of flight masters, twins and never hostile.
2. **The constants live in `Graph.lua`**: `Graph.HOSTILE_SECONDS = 600`,
   `Graph.HOSTILE_RADIUS = 150`, `Graph.CAPITAL_RADIUS = 400`, beside
   `Graph.HEARTH_SECONDS`. With `Data/Hostile.lua` dropped there is no
   `Hostile` table to hold them; Task 1's spec edit names them so.
3. **An enemy flight master whose short name a usable one shares is not
   hostile.** Booty Bay, Gadgetzan, Everlook and the other five are neutral
   towns with a flight master for each side; Search already hides the enemy
   twin for the same reason.
4. **Reading the sheet.** A row is keyed by (zone, town), because two towns
   share a name in different zones. The faction cell is trimmed and read
   case-blind; anything but A, H, N or blank raises and names the row. A row
   that names no generated town (a typo, or a town a patch renamed or moved)
   is printed, and the generator exits 1 **without writing any file**. A
   Python test also reads the sheet against the committed `Data/Towns.lua`:
   it fails on such a row, and on a mark the owner made without running the
   generator again.
5. **"The destination is hostile" is the circle test.** `Graph.HostileAt`
   returns the first hostile place whose circle holds the destination, the
   same geometry that exempts the legs that arrive there, and the note names
   that place (Wildhammer Keep's note names Aerie Peak).
6. **The note wins the warning line.** `Planner.Refresh` shows
   `plan.hostile` before the strip's own amber warning; it is also the first
   of `plan.notes`, so `/gps to` prints it first in chat.
7. **The enemy town comes first on the detail line**, before a crossing's
   hazard and the unconfirmed note: the line does not wrap, and the town is
   the part that kills you. A rough straight line, which has no zone to
   name, gets "passes X (Faction)" alone. "an Alliance", "a Horde".
8. **Stopovers:** keyed `s1`, `s2`...; `unverified = true` shows "stopover
   not confirmed" (not "crossing not confirmed"); a name may not contain a
   comma, since `Search.ShortName` would cut the step text there.
9. **The real-data test is what the data says.** The Horde's straight line
   from the Talondeep mouth carries Silverwind Refuge's danger and ten
   minutes; the route goes round by the Ashenvale-Felwood road with no danger
   step and no leg within 150 yards of the town. The Alliance's is the
   straight line with none. Task 1's spec edit says so, and the checklist
   asks the owner to walk it.
10. **Two existing real-route tests follow the new data** (Task 4): the
    Tirisfal-to-Hyjal walk's steps, and the Talondeep tunnel test, now to
    Zoram'gar Outpost. Neither loosens a rule.
11. **Counts that the sheet moves are derived, not pinned.** The real-data
    test pins 24 and 23 flight masters and requires the marked towns to be
    exactly the towns `Data/Towns.lua` marks, so a new mark does not break
    it. It does pin the capitals ("Ironforge, Stormwind" to the Horde), and
    says to update that line when Darnassus is marked.
12. **A zone destination's zero-second arrival is never charged**: no leg is
    ridden, so none passes anything.

## File map

- Modify `tools/build_graph.py`: `TOWN_FACTIONS`, `FACTION_COLUMN`,
  `read_town_factions`, `mark_towns` in place of `CAPITAL_ICON`,
  `FACTION_YARDS` and `_town_faction`; `build_towns` gives no faction; `main`
  marks the towns or stops.
- Modify `test/tools/test_build_graph.py`: four faction tests go, one
  replaces them, one is corrected; classes `TownFactions` and `TheOwnersSheet`.
- Regenerate `GoblinPS/Data/Towns.lua` (Task 1, by running the generator).
- Modify `GoblinPS/Search.lua`: one comment.
- Modify `GoblinPS/Geo.lua`: `Geo.SegmentDistance`.
- Create `GoblinPS/Data/Stopovers.lua` (empty, with its header).
- Modify `GoblinPS/GoblinPS.toc` (load it after `Data\Crossings.lua`;
  version) and `test/run.lua` (module list).
- Modify `GoblinPS/Graph.lua`: the three constants, `isCapital`,
  `Graph.Hostile`, `Graph.HostileAt`, `dangerOn`, the stopovers, the pair
  loop, the `Graph.Build` comment.
- Modify `GoblinPS/Route.lua`: `tidy` and `Route.Find` carry `danger`;
  `passes`, `Route.HostileNote`, `Route.StepDetail`.
- Modify `GoblinPS/Core.lua` (`Core.PlanRoute`) and `GoblinPS/Planner.lua`
  (`Planner.Refresh`, one branch).
- Modify `test/test_data.lua`, `test/test_geo.lua`, `test/test_graph.lua`,
  `test/test_crossings.lua`, `test/test_route.lua`, `test/test_strip.lua`,
  `test/test_ui.lua`.
- Docs: the spec (section 1 and two test lines in Task 1, its status in Task
  6), `docs/manual-test-checklist.md`, `docs/later.md`, `CLAUDE.md`.

Untouched: `tools/town-factions.csv` (the owner's), `Strip.lua` (the amber
detail reaches the tooltip and the warning line through `Route.StepDetail`
as it is), `Dash.lua`, `Trip.lua`, `Places.lua`, `Nodes.lua`, `Flights.lua`,
art, geometry. There is no `Data/Hostile.lua`.

## How edits are written

Every edit below is one of four shapes, and every anchor is unique in its
file (checked): **Create** a file; **Insert** a block directly before or
after an anchor block; **Replace** a block with another; **Delete** a line.
An inserted block is set off from its neighbours by one blank line wherever
the code around it uses one (between `h.describe` blocks, between top-level
functions and classes), and by none inside a list of `h.it` tests. The
repository's Lua and Python files have CRLF line endings in the working tree
(`core.autocrlf`); the Edit tool keeps them. Blocks are shown without them.

---

### Task 1: town factions come only from the owner's sheet

**Files:**
- Modify: `docs/superpowers/specs/2026-09-22-goblinps-enemy-towns-design.md`
  (section 1; the "Real data" and "Data" test lines)
- Modify: `tools/build_graph.py` (constants, lines 35-37; `_town_faction`,
  lines 237-247; `build_towns`, lines 283-287; `main`, line 376)
- Modify: `test/tools/test_build_graph.py` (imports; `Towns`, lines 162-198;
  two classes before `Emit`)
- Regenerate: `GoblinPS/Data/Towns.lua`
- Modify: `GoblinPS/Search.lua` (the `fromTown` comment, lines 61-62)
- Test: `test/test_data.lua` ("the towns table", lines 170-181; the line to delete is 178)

**Interfaces:**
- Consumes: the existing `build_places`, `build_nodes`, `build_towns`
  (rows `{ name, map, mx, my, c, x, y }` keyed by POI ID), `emit`; the sheet
  `tools/town-factions.csv`.
- Produces:
  - `bg.TOWN_FACTIONS = "town-factions.csv"`, `bg.FACTION_COLUMN = "faction (A/H/N)"`.
  - `bg.read_town_factions(path: Path) -> {(zone: str, town: str): "A"|"H"|"N"|""}`;
    raises `RuntimeError` on a missing column or an unknown faction.
  - `bg.mark_towns(towns, places, marks) -> list[str]`: sets `town["f"]` for
    A and H, returns one error line per row that names no generated town.
  - `bg.build_towns` no longer sets `f`. `main` returns 1 and writes nothing
    when `mark_towns` returns errors.
  - `ns.Data.Towns` rows carry `f` only where the sheet says A or H (7 today).
    Tasks 4 and 5 rely on `Silverwind Refuge` being `f = "A"`.

- [ ] **Step 1: The spec follows the owner's ruling**

In `docs/superpowers/specs/2026-09-22-goblinps-enemy-towns-design.md`,
replace the whole of section 1, from `## 1. Hostile places` down to the
blank line before `## 2. The penalty`,

```markdown
## 1. Hostile places
A hostile place is a point with a name, a faction and a radius, built from three sources:
- **Enemy flight stops:** every `Data/Nodes` stop whose faction is not the player's and not neutral.
- **Enemy towns:** every `Data/Towns` row with an `f` that is not the player's.
- **Hand-written hostile towns:** `Data/Hostile.lua` (new, HAND-WRITTEN). It lists towns the generator could not give a faction to: `["Silverwind Refuge"] = { f = "A" }`, keyed by the town's name as it appears in `Data/Towns` or `Data/Nodes`. Seeded with Silverwind Refuge, known in game on 2026-09-22 because its guards killed a level 15 Horde player. Add a row whenever a town kills you.

**Ruling: the radius** is `Hostile.RADIUS = 150` yards for a town or stop, and `Hostile.CAPITAL_RADIUS = 400` for a capital (a town with icon 5 in the generated data, or a stop in one of the six capital zones). Both are named constants, and they are guesses until walked. The owner's closest reading at Silverwind was about 40 yd from its map label, so 150 errs wide.

A place is hostile only to the other faction. Neutral towns (no `f`) are never hostile.
```

with

```markdown
## 1. Hostile places
**Revised 2026-09-22 by the owner:** a place is hostile only when its faction is known. The generator no longer guesses a town's faction from nearby flight masters (plan 11's prototype found most such guesses were caves, rivers and dungeons), and `Data/Hostile.lua` is dropped.

A hostile place is a point with a name, a faction and a radius, built from two sources:
- **Enemy flight stops:** every `Data/Nodes` stop whose faction is not the player's and not neutral, except one whose short name a stop the player may use shares (Booty Bay, Gadgetzan, Everlook...: a neutral town with a flight master for each side).
- **Marked enemy towns:** every `Data/Towns` row with an `f` that is not the player's. `f` comes only from the owner's hand-written sheet `tools/town-factions.csv` (columns zone, town, x, y, guess, "faction (A/H/N)", Notes), which `tools/build_graph.py` reads the way it reads `catalog.lock`: A or H becomes `f`, N or blank gives none, and the guess and Notes columns are never read. A row that names a town the generator does not produce is a loud error: the generator prints it and writes nothing, and the Python tests fail. Silverwind Refuge is marked A, because its guards killed a level 15 Horde player on 2026-09-22. Mark a town whenever one kills you.

**Ruling: the radius** is `Graph.HOSTILE_RADIUS = 150` yards for a town or stop, and `Graph.CAPITAL_RADIUS = 400` for a capital: a hostile place named after its own zone ("Orgrimmar" in Orgrimmar, "Stormwind" in Stormwind City). Both are named constants, and they are guesses until walked. The owner's closest reading at Silverwind was about 40 yd from its map label, so 150 errs wide.

When one leg passes two hostile places, it is named after the surer source: a flight master, then a marked town.

A place is hostile only to the other faction. Neutral towns (no `f`) are never hostile.
```

In its "Tests" section, replace

```markdown
- **Real data:** a Horde level 15 route from the Talondeep Path's Ashenvale mouth to Splintertree Post has a step with `danger` naming Silverwind Refuge (until a stopover exists). An Alliance route on the same line has none.
```

with

```markdown
- **Real data:** a Horde level 15 route from the Talondeep Path's Ashenvale mouth to Splintertree Post: its straight line carries `danger` naming Silverwind Refuge, and the route goes round with no step passing within the radius (measured 2026-09-22: by the Ashenvale-Felwood road). An Alliance route on the same line is the straight line, with no `danger`.
```

and replace

```markdown
- **Data:** every `Data/Hostile.lua` key matches a real town or stop name; every stopover sits inside its zone's rectangle.
```

with

```markdown
- **Data:** every `tools/town-factions.csv` row names a town the generator produces, and `Data/Towns.lua` carries exactly its A and H marks (Python); Irontree Cavern, a cave the old guess called Alliance, has no `f`; every stopover sits inside its zone's rectangle.
```

- [ ] **Step 2: Write the failing Python tests**

In `test/tools/test_build_graph.py`, replace the imports

```python
import contextlib
import io
import sys
```

with

```python
import contextlib
import io
import re
import sys
```

In `class Towns`, replace the four faction tests,

```python
    def test_takes_the_faction_of_a_one_faction_flight_master_within_600_yards(self):
        # 500 yards from Crossroads (Horde), in The Barrens with it.
        self.assertEqual(self.towns[36]["f"], "H")

    def test_takes_no_faction_otherwise(self):
        self.assertNotIn("f", self.towns[31], "no flight master in Durotar at all")
        self.assertNotIn("f", self.towns[37], "510 yards from Orgrimmar's, but in another zone")
        self.assertNotIn("f", self.towns[1068], "Crossroads is over 3000 yards away")
        self.assertNotIn("f", self.towns[910], "no one-faction flight master within 600 yards")

    def test_a_capital_takes_the_nearest_one_faction_flight_masters_faction(self):
        # Taurajo Keep has no flight master in its own zone: Crossroads is the nearest.
        self.assertEqual(self.towns[950]["f"], "H")

    def test_both_factions_near_means_none(self):
        nodes = {1: {"f": "A", "c": 1, "map": 5, "x": 0, "y": 100},
                 2: {"f": "H", "c": 1, "map": 5, "x": 0, "y": -100},
                 3: {"f": "N", "c": 1, "map": 5, "x": 0, "y": 10}}
        town = {"c": 1, "map": 5, "x": 0, "y": 0}
        self.assertIsNone(bg._town_faction(nodes, town, False))
        self.assertEqual(bg._town_faction({3: nodes[3], 2: nodes[2]}, town, False), "H",
                         "a neutral one does not count")
        self.assertEqual(bg._town_faction(nodes, dict(town, y=90), True), "A", "a capital: the nearest")
```

with one that says there is no guess any more:

```python
    def test_guesses_no_faction_from_nearby_flight_masters(self):
        # Far Watch Post is 500 yards from Crossroads (Horde) in The Barrens, and Taurajo
        # Keep a capital with Crossroads the nearest: the generator used to call both Horde.
        for town in self.towns.values():
            self.assertNotIn("f", town, town["name"] + " has a faction nobody marked")
```

and replace

```python
    def test_rows_carry_every_field(self):
        self.assertEqual(self.towns[36], {"name": "Far Watch Post", "map": 1413, "mx": 0.46, "my": 0.4667,
                                          "c": 1, "x": -800, "y": -2300, "f": "H"})
        for town in self.towns.values():
            self.assertEqual(set(town) - {"f"}, {"name", "map", "mx", "my", "c", "x", "y"})
```

with

```python
    def test_rows_carry_every_field(self):
        self.assertEqual(self.towns[36], {"name": "Far Watch Post", "map": 1413, "mx": 0.46, "my": 0.4667,
                                          "c": 1, "x": -800, "y": -2300})
        for town in self.towns.values():
            self.assertEqual(set(town), {"name", "map", "mx", "my", "c", "x", "y"})
```

Insert directly before `class Emit(unittest.TestCase):` these two classes:

```python
class TownFactions(unittest.TestCase):
    HEADER = "zone,town,x,y,guess,faction (A/H/N),Notes\n"

    def setUp(self):
        tables = bg.load_tables(FIXTURES)
        with contextlib.redirect_stderr(io.StringIO()):
            self.places = bg.build_places(tables)
            self.towns = bg.build_towns(tables, self.places, bg.build_nodes(tables, self.places))

    def sheet(self, text):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        path = Path(tmp.name) / "town-factions.csv"
        path.write_text(text, encoding="utf-8", newline="")
        return path

    def test_reads_zone_town_and_faction_and_nothing_else(self):
        marks = bg.read_town_factions(self.sheet(self.HEADER
            + "The Barrens,Far Watch Post,46,46.7,A,H,\n"
            + "Durotar,Razor Hill,52,43,H,n,Hostile to all\n"
            + "Durotar,Valley Gate,40,20,H,,\n"
            + '"The Barrens","Wailing Caverns",46,36,H, a ,"a note, with a comma"\n'))
        self.assertEqual(marks, {("The Barrens", "Far Watch Post"): "H", ("Durotar", "Razor Hill"): "N",
                                 ("Durotar", "Valley Gate"): "", ("The Barrens", "Wailing Caverns"): "A"},
                         "guess and Notes are the owner's own and never read")

    def test_refuses_a_faction_it_does_not_know(self):
        with self.assertRaisesRegex(RuntimeError, "Far Watch Post in The Barrens: faction 'X'"):
            bg.read_town_factions(self.sheet(self.HEADER + "The Barrens,Far Watch Post,46,46.7,,X,\n"))

    def test_refuses_a_sheet_without_its_faction_column(self):
        with self.assertRaisesRegex(RuntimeError, "missing columns"):
            bg.read_town_factions(self.sheet("zone,town,x,y,guess,faction,Notes\n"))

    def test_gives_a_or_h_as_f_and_n_or_blank_none(self):
        errors = bg.mark_towns(self.towns, self.places, {("The Barrens", "Far Watch Post"): "H",
                                                         ("Durotar", "Razor Hill"): "N",
                                                         ("Durotar", "Valley Gate"): "",
                                                         ("The Barrens", "Wailing Caverns"): "A"})
        self.assertEqual(errors, [])
        self.assertEqual(self.towns[36]["f"], "H")
        self.assertEqual(self.towns[1068]["f"], "A")
        self.assertNotIn("f", self.towns[31], "N is no faction")
        self.assertNotIn("f", self.towns[37], "blank is no faction")

    def test_names_every_row_that_matches_no_generated_town(self):
        errors = bg.mark_towns(self.towns, self.places, {("Durotar", "Far Watch Post"): "H",
                                                         ("Durotar", "Nowhere Keep"): ""})
        self.assertEqual(errors, ["town-factions.csv: no generated town 'Far Watch Post' in 'Durotar'",
                                  "town-factions.csv: no generated town 'Nowhere Keep' in 'Durotar'"])
        self.assertNotIn("f", self.towns[36], "a mark in the wrong zone is not applied")


class TheOwnersSheet(unittest.TestCase):
    """tools/town-factions.csv against the committed GoblinPS/Data/Towns.lua: a typo in the
    sheet, or a mark made without running tools/build_graph.py again, fails here."""

    @staticmethod
    def lua_rows(name):
        text = (ROOT / "GoblinPS" / "Data" / f"{name}.lua").read_text(encoding="utf-8")
        return re.findall(r"^\s*\[(\d+)\]=\{(.*)\},$", text, re.M)

    @staticmethod
    def field(row, key):
        m = re.search(r"\b" + key + r'=(?:"((?:[^"\\]|\\.)*)"|([^,}]+))', row)
        return None if m is None else (m.group(1) if m.group(1) is not None else m.group(2))

    def setUp(self):
        zones = {int(i): self.field(row, "name") for i, row in self.lua_rows("Places")}
        self.towns = {(zones[int(self.field(row, "map"))], self.field(row, "name")): self.field(row, "f")
                      for _, row in self.lua_rows("Towns")}
        self.marks = bg.read_town_factions(ROOT / "tools" / bg.TOWN_FACTIONS)

    def test_every_row_names_a_generated_town(self):
        self.assertEqual(len(self.towns), 150, "every row of Towns.lua was read")
        self.assertEqual(sorted(key for key in self.marks if key not in self.towns), [])

    def test_towns_lua_carries_exactly_the_sheets_a_and_h_marks(self):
        marked = {key: f for key, f in self.marks.items() if f in ("A", "H")}
        self.assertGreater(len(marked), 0, "a sheet with no marks proves nothing")
        self.assertEqual({key: f for key, f in self.towns.items() if f}, marked,
                         "run tools/build_graph.py after marking the sheet")
```

- [ ] **Step 3: Write the failing Lua test**

In `test/test_data.lua`, in "makes Darnassus, Kharanos and Sentinel Hill
places, not zones", delete the line

```lua
            h.eq(ns.Search.Exact(data, "Darnassus", "H").enemy, "A", "a capital takes its own flight stop's faction")
```

(Darnassus is not marked in the sheet, so it has no faction now), and insert
directly after the end of that test,

```lua
            h.eq(ns.Search.Exact(data, "Sentinel Hill", "H").nodeID, 4, "the stop, not a town beside it")
        end)
```

this test:

```lua
        h.it("gives a town a faction only where the owner marked one", function()
            -- tools/town-factions.csv, and nothing else: no faction is guessed
            -- from nearby flight masters any more. test/tools/test_build_graph.py
            -- checks the whole sheet against this file.
            local byName = {}
            for _, t in pairs(towns) do
                byName[t.name] = t
            end
            h.eq(byName["Silverwind Refuge"].f, "A", "marked Alliance")
            h.eq(byName["Warsong Labor Camp"].f, "H", "marked Horde")
            for _, name in ipairs({ "Irontree Cavern", "Maraudon", "Falfarren River" }) do
                h.eq(byName[name].f, nil, name .. " is not marked, so it has no faction")
            end
            h.eq(ns.Search.Exact(data, "Silverwind Refuge", "H").enemy, "A", "the Horde's list says (Alliance)")
            h.eq(ns.Search.Exact(data, "Irontree Cavern", "H").enemy, nil, "and a cave is nobody's enemy")
        end)
```

- [ ] **Step 4: Run both gates to see them fail**

Python: `Ran 74 tests`, `FAILED (failures=2, errors=7)`. The seven errors are
the five `TownFactions` tests and the two `TheOwnersSheet` tests
(`AttributeError: module 'build_graph' has no attribute ...`: `read_town_factions`, `mark_towns` or `TOWN_FACTIONS`); the two
failures are "guesses no faction from nearby flight masters" and "rows carry
every field" (Far Watch Post still has `f = "H"`).

Lua: `471 passed, 1 failed`: "gives a town a faction only where the owner
marked one" (Silverwind Refuge has no `f`; Irontree Cavern has `f = "A"`).

- [ ] **Step 5: `tools/build_graph.py`**

Replace

```python
TOWN_ICONS = {"4", "5", "6"}
CAPITAL_ICON = "5"
FACTION_YARDS = 600.0  # a town takes the faction of a one-faction flight master this close
```

with

```python
TOWN_ICONS = {"4", "5", "6"}
# The game's tables give a town no faction. Only the owner's hand-written sheet, beside
# catalog.lock, does: guessing from nearby flight masters made caves and rivers into
# enemy towns (plan 11), so nothing here guesses any more.
TOWN_FACTIONS = "town-factions.csv"
FACTION_COLUMN = "faction (A/H/N)"
```

Replace the whole of `_town_faction`,

```python
def _town_faction(nodes, town, capital: bool) -> str | None:
    """The table does not say, so: the faction of the one-faction flight masters within
    FACTION_YARDS in the town's zone, when they are all one faction; none otherwise. A
    capital takes the faction of the nearest one-faction flight master on its continent,
    its own (Darnassus's is Rut'theran Village, across the water in Teldrassil)."""
    here = (town["x"], town["y"])
    sided = [n for n in nodes.values() if n["f"] in ("A", "H") and n["c"] == town["c"]]
    if capital:
        return min(sided, key=lambda n: math.dist(here, (n["x"], n["y"])))["f"] if sided else None
    near = {n["f"] for n in sided if n["map"] == town["map"] and math.dist(here, (n["x"], n["y"])) <= FACTION_YARDS}
    return near.pop() if len(near) == 1 else None
```

with

```python
def read_town_factions(path: Path) -> dict[tuple[str, str], str]:
    """The owner's marks: (zone name, town name) -> "A", "H", "N" or "" (not marked yet).

    tools/town-factions.csv has a row per generated town: zone, town, x, y, guess,
    "faction (A/H/N)", Notes. Only zone, town and the faction column are read; guess and
    Notes are the owner's own. A faction that is not A, H, N or blank raises."""
    marks = {}
    with path.open(encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        missing = [c for c in ("zone", "town", FACTION_COLUMN) if c not in (reader.fieldnames or ())]
        if missing:
            raise RuntimeError(f"{path.name}: missing columns {missing}")
        for row in reader:
            faction = (row[FACTION_COLUMN] or "").strip().upper()
            if faction not in ("", "A", "H", "N"):
                raise RuntimeError(f"{path.name}: {row['town']} in {row['zone']}: "
                                   f"faction {row[FACTION_COLUMN]!r} is not A, H, N or blank")
            marks[(row["zone"].strip(), row["town"].strip())] = faction
    return marks


def mark_towns(towns, places, marks) -> list[str]:
    """Give each town the owner's faction: A or H becomes its `f`; N or blank gives none.

    Returns one line for every row that names no generated town (a typo, or a town a
    patch renamed or moved): the caller prints them and writes nothing, never guesses."""
    by_name = {(places[t["map"]]["name"], t["name"]): t for t in towns.values()}
    errors = []
    for (zone, name), faction in sorted(marks.items()):
        town = by_name.get((zone, name))
        if town is None:
            errors.append(f"{TOWN_FACTIONS}: no generated town {name!r} in {zone!r}")
        elif faction in ("A", "H"):
            town["f"] = faction
    return errors
```

In `build_towns`, replace

```python
                "c": int(poi["ContinentID"]), "x": round(wx, 1), "y": round(wy, 1)}
        faction = _town_faction(nodes, town, poi["Icon"] == CAPITAL_ICON)
        if faction:
            town["f"] = faction
        towns[int(poi["ID"])] = town
```

with

```python
                "c": int(poi["ContinentID"]), "x": round(wx, 1), "y": round(wy, 1)}
        towns[int(poi["ID"])] = town
```

In `main`, insert directly after

```python
    towns = build_towns(tables, places, nodes)
```

these lines, so a bad sheet stops the run before any file is written:

```python
    errors = mark_towns(towns, places, read_town_factions(root / "tools" / TOWN_FACTIONS))
    if errors:
        for line in errors:
            print(line, file=sys.stderr)
        print(f"{len(errors)} row(s) of tools/{TOWN_FACTIONS} name no town: nothing written", file=sys.stderr)
        return 1
```

- [ ] **Step 6: Run the Python gate**

Expected: `Ran 74 tests`, `FAILED (failures=1)`: only "towns lua carries
exactly the sheet's a and h marks", because the committed `Data/Towns.lua`
still carries the old guesses. That test is the reminder to run the
generator.

- [ ] **Step 7: Run the generator**

Run: `python tools/build_graph.py`
Expected stderr: two `fetch https://wago.tools/db2/AreaPOI/...` and
`.../AreaTable/...` lines when they are not in `tools/cache/1.60.1.69913`
(which git ignores), the six `skip zone` lines, the five `skip town` lines
(Dun Algaz, Stormwind, The Undercity, Scholomance, Ivar's Patch) and the
summary `49 places, 71 nodes, 292 flights, 150 towns`, exit code 0.

Then `git diff --ignore-cr-at-eol --stat -- GoblinPS/Data/Places.lua GoblinPS/Data/Nodes.lua GoblinPS/Data/Flights.lua`
must print nothing (the generator writes LF, the checkout has CRLF): put them
back with `git checkout -- GoblinPS/Data/Places.lua GoblinPS/Data/Nodes.lua GoblinPS/Data/Flights.lua`.
If it prints any line, stop: the generator changed data it must not.

`git diff --ignore-cr-at-eol --stat -- GoblinPS/Data/Towns.lua` shows 35
lines in and 35 out. `grep -c 'f="' GoblinPS/Data/Towns.lua` prints `7`, and
the file holds

```lua
    [1242]={c=1,f="A",map=1440,mx=0.5012,my=0.6615,name="Silverwind Refuge",x=2130.3,y=-1190.2},
```

with no `f` on Maraudon (1148), Irontree Cavern (1219), Falfarren River
(1235) or Darnassus (38).

To see the loud error once (then put the sheet back): add the line
`Ashenvale,Silverwind Refuje,50,66,,A,` to `tools/town-factions.csv` and run
the generator again. It prints
`town-factions.csv: no generated town 'Silverwind Refuje' in 'Ashenvale'` and
`1 row(s) of tools/town-factions.csv name no town: nothing written`, exits
1, and `Data/Towns.lua` is unchanged; the Python gate fails both
`TheOwnersSheet` tests. `git checkout -- tools/town-factions.csv`.

- [ ] **Step 8: `GoblinPS/Search.lua`, the comment**

Replace

```lua
-- A generated town. Its faction is inferred (tools/build_graph.py) and often
-- absent; a town with none is nobody's enemy.
```

with

```lua
-- A generated town. Its faction comes only from the owner's marks in
-- tools/town-factions.csv (tools/build_graph.py), and is usually absent; a
-- town with none is nobody's enemy.
```

- [ ] **Step 9: Run every gate**

Lua `472 passed, 0 failed`. Python `Ran 74 tests`, `OK`. Art green.
luacheck and the language server from PowerShell: zero warnings.

- [ ] **Step 10: Commit**

```
git add docs/superpowers/specs/2026-09-22-goblinps-enemy-towns-design.md tools/build_graph.py test/tools/test_build_graph.py GoblinPS/Data/Towns.lua GoblinPS/Search.lua test/test_data.lua
git commit -m "Town factions come only from the owner's sheet" -m "The owner ruled on 2026-09-22 that a place is hostile only when its faction is known. tools/build_graph.py no longer gives a town the faction of nearby flight masters, which made caves and rivers into towns (Maraudon, Irontree Cavern, Falfarren River); it reads tools/town-factions.csv, A or H becoming f and N or blank none, and a row that names no generated town is printed and stops the run before anything is written. A Python test holds the sheet against the committed Towns.lua. Towns.lua regenerated: 7 towns carry a faction, Silverwind Refuge Alliance among them. The spec's section 1 follows the ruling." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `Geo.SegmentDistance`

**Files:**
- Modify: `GoblinPS/Geo.lua` (after `Geo.Distance`, line 24)
- Test: `test/test_geo.lua` (a new block before `h.describe("Geo.Nearest", ...)`)

**Interfaces:**
- Consumes: world positions `{ c, x, y }`, as `Geo.Distance` takes them.
- Produces: `Geo.SegmentDistance(a, b, p) -> number`: yards from `p` to the
  segment `a`-`b`, `math.huge` unless all three are given and on one
  continent. Task 4's `dangerOn` calls it.

- [ ] **Step 1: Write the failing tests**

Insert into `test/test_geo.lua` directly before

```lua
    h.describe("Geo.Nearest", function()
```

this block:

```lua
    h.describe("Geo.SegmentDistance", function()
        -- A leg 100 yards long along x, on continent 1.
        local a, b = { c = 1, x = 0, y = 0 }, { c = 1, x = 100, y = 0 }
        local function near(got, want) return math.abs(got - want) < 0.001 end

        h.it("is zero at either end", function()
            h.eq(Geo.SegmentDistance(a, b, { c = 1, x = 0, y = 0 }), 0)
            h.eq(Geo.SegmentDistance(a, b, { c = 1, x = 100, y = 0 }), 0)
        end)
        h.it("measures square to the leg in the middle", function()
            h.truthy(near(Geo.SegmentDistance(a, b, { c = 1, x = 50, y = 30 }), 30))
            h.truthy(near(Geo.SegmentDistance(a, b, { c = 1, x = 25, y = -40 }), 40), "either side")
        end)
        h.it("measures to the nearer end past either end, not to the line beyond it", function()
            h.truthy(near(Geo.SegmentDistance(a, b, { c = 1, x = -30, y = 40 }), 50), "before a")
            h.truthy(near(Geo.SegmentDistance(a, b, { c = 1, x = 130, y = 40 }), 50), "past b")
        end)
        h.it("treats a leg of no length as a point", function()
            h.truthy(near(Geo.SegmentDistance(a, a, { c = 1, x = 3, y = 4 }), 5))
        end)
        h.it("is infinite off the leg's continent or with a position missing", function()
            h.eq(Geo.SegmentDistance(a, b, { c = 0, x = 50, y = 0 }), math.huge)
            h.eq(Geo.SegmentDistance(a, { c = 0, x = 100, y = 0 }, { c = 1, x = 50, y = 0 }), math.huge)
            h.eq(Geo.SegmentDistance(a, b, nil), math.huge)
        end)
    end)
```

- [ ] **Step 2: Run the Lua gate to see them fail**

Expected: `472 passed, 5 failed`, all five in `Geo.SegmentDistance`, each
`attempt to call field 'SegmentDistance' (a nil value)`.

- [ ] **Step 3: Write `Geo.SegmentDistance`**

Insert into `GoblinPS/Geo.lua` directly after

```lua
    return math.sqrt(dx * dx + dy * dy)
end
```

(the end of `Geo.Distance`) a blank line and:

```lua
-- Yards from world position p to the straight segment a-b; math.huge unless
-- all three are on one continent. A ride leg is a straight line, so this is
-- how close one passes to a place.
function Geo.SegmentDistance(a, b, p)
    if not a or not b or not p or a.c ~= b.c or a.c ~= p.c then
        return math.huge
    end
    local dx, dy = b.x - a.x, b.y - a.y
    local t, length2 = 0, dx * dx + dy * dy
    if length2 > 0 then
        t = math.max(0, math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length2))
    end
    local ex, ey = a.x + t * dx - p.x, a.y + t * dy - p.y
    return math.sqrt(ex * ex + ey * ey)
end
```

- [ ] **Step 4: Run every gate**

Lua `477 passed, 0 failed`. Python `Ran 74 tests`, `OK`. Art green.
luacheck and the language server: zero warnings.

- [ ] **Step 5: Commit**

```
git add GoblinPS/Geo.lua test/test_geo.lua
git commit -m "Geo.SegmentDistance: how close a straight leg passes a point" -m "Yards from a point to a segment, measured to the nearer end past either end and to a point for a leg of no length; infinite off the leg's continent or with a position missing. The router's ride legs are straight lines, so this is how the graph will tell which ones pass an enemy town." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `Data/Stopovers.lua`, loaded and checked

**Files:**
- Create: `GoblinPS/Data/Stopovers.lua`
- Modify: `GoblinPS/GoblinPS.toc` (one line after `Data\Crossings.lua`)
- Modify: `test/run.lua` (module list)
- Test: `test/test_data.lua` (a new block before `h.describe("a real route", ...)`)

**Interfaces:**
- Consumes: `ns.Data.Places`.
- Produces: `ns.Data.Stopovers = { { name, map, mx, my, unverified? }, ... }`
  (empty), loaded in the client (TOC) and in `test/run.lua`'s shared `ns`.
  Nothing reads it until Task 4.

- [ ] **Step 1: Write the failing tests**

Insert into `test/test_data.lua` directly before

```lua
    h.describe("a real route", function()
```

this block:

```lua
    h.describe("the stopovers", function()
        -- The check returns what is wrong with the table, so it can be shown
        -- failing on planted rows: a check that cannot fail proves nothing,
        -- and Data/Stopovers.lua starts empty.
        local function badStopovers(stopovers)
            local bad = {}
            for i, s in ipairs(stopovers) do
                local onMap = data.Places[s.map] and s.mx and s.my and s.mx >= 0 and s.mx <= 1
                    and s.my >= 0 and s.my <= 1
                if not onMap or type(s.name) ~= "string" or s.name == "" or s.name:find(",", 1, true) then
                    bad[#bad + 1] = i .. " " .. tostring(s.name)
                end
            end
            return table.concat(bad, ", ")
        end

        h.it("puts every stopover on its own zone's map, under a name with no comma", function()
            h.truthy(data.Stopovers, "Data/Stopovers.lua is not loaded")
            h.eq(badStopovers(data.Stopovers), "")
        end)
        h.it("catches a stopover off its zone's map, on no zone, or with a comma in its name", function()
            h.eq(badStopovers({
                { name = "the road south of Silverwind Refuge", map = 1440, mx = 0.52, my = 0.70 },
                { name = "past the edge", map = 1440, mx = 1.2, my = 0.5 },
                { name = "on no map", map = 99999, mx = 0.5, my = 0.5 },
                { name = "a road, Ashenvale", map = 1440, mx = 0.5, my = 0.5 },
            }), "2 past the edge, 3 on no map, 4 a road, Ashenvale")
        end)
    end)
```

- [ ] **Step 2: Run the Lua gate to see them fail**

Expected: `478 passed, 1 failed`: "puts every stopover on its own zone's
map, under a name with no comma" (`Data/Stopovers.lua is not loaded, got
"nil"`). The planted-row check already passes: it proves the check can fail
before there is a row to check.

- [ ] **Step 3: Create `GoblinPS/Data/Stopovers.lua`**

```lua
-- HAND-WRITTEN. Named points inside one zone that a ride may pass through.
-- Inside a zone a ride leg is a straight line, and the router knows nothing
-- of roads, so a line between two points can run straight through an enemy
-- town (Graph.Hostile). A stopover gives it a way round: Graph.Build
-- joins it to every other point in its zone, like a tunnel's mouth, and the
-- router bends through it when that is quicker than the penalty.
--
--   { name = "...", map = <UiMap>, mx = 0.501, my = 0.662, unverified = true }
--     name   what the step says, "Ride to <name>": describe the way, and
--            include "the" ("the road south of Silverwind Refuge"). No comma:
--            everything after one is cut from the step.
--     map    the zone's UiMap ID (Data/Places.lua; /gps where prints it)
--     mx, my map coords (0..1). Stand on the spot and type /gps where: it
--            prints "Ashenvale (1440) 50.1, 66.2"; divide each by 100.
--     unverified = true   optional: placed from the map, not walked. The
--            step's detail line then says "stopover not confirmed".
--
-- test/test_data.lua checks every row sits on its zone's map.
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Stopovers = {
}
```

- [ ] **Step 4: Load it**

In `GoblinPS/GoblinPS.toc`, insert directly after the line `Data\Crossings.lua`
the line

```text
Data\Stopovers.lua
```

In `test/run.lua`, insert directly after

```lua
    { "Crossings", "GoblinPS/Data/Crossings.lua" },
```

the row

```lua
    { "Stopovers", "GoblinPS/Data/Stopovers.lua" },
```

- [ ] **Step 5: Run every gate**

Lua `479 passed, 0 failed`. Python `Ran 74 tests`, `OK`. Art green.
luacheck and the language server: zero warnings (luacheck now checks 45
files).

- [ ] **Step 6: Commit**

```
git add GoblinPS/Data/Stopovers.lua GoblinPS/GoblinPS.toc test/run.lua test/test_data.lua
git commit -m "Data/Stopovers.lua, hand-written and empty" -m "Named points a ride may bend through round an enemy town. It starts empty, with a header saying how to measure one with /gps where; the TOC and the test runner load it, and a data test checks every row sits on its zone's map under a name with no comma, shown failing on planted rows." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: the graph charges a leg past an enemy town, and bends through stopovers

**Files:**
- Modify: `GoblinPS/Graph.lua` (constants after line 18; four functions after
  `legal`, line 24; the `Graph.Build` comment, lines 97-101; the stopovers
  after the crossings loop, line 149; the pair loop, lines 170-188)
- Modify: `GoblinPS/Route.lua` (`tidy`, lines 47-49; `Route.Find`'s comment
  and `raw`, lines 56-57 and 66-69)
- Test: `test/test_graph.lua` (a new block at the end),
  `test/test_crossings.lua` (three new tests before "leaves a city by its
  gate"; two existing tests follow the new data)

**Interfaces:**
- Consumes: `Geo.SegmentDistance` (Task 2), `Geo.Distance`, `Geo.ToWorld`,
  `Search.ShortName`, `data.Towns[].f` (Task 1), `data.Stopovers` (Task 3;
  may be nil: the fake world has none).
- Produces:
  - `Graph.HOSTILE_SECONDS = 600`, `Graph.HOSTILE_RADIUS = 150`,
    `Graph.CAPITAL_RADIUS = 400`.
  - `Graph.Hostile(data, faction) -> { { name, f, c, x, y, map, radius, rank }, ... }`,
    rank 1 a flight master, 2 a marked town; sorted by `rank`, `name`, `map`,
    `x`, `y`; `{}` when `faction` is nil.
  - `Graph.HostileAt(data, faction, point) -> hostile place | nil`: the first
    whose circle (`<= radius`) holds the world point.
  - A ride edge from `Graph.Build` (shared-zone or rough) may carry
    `danger = { name, f }`, its `seconds` already including
    `Graph.HOSTILE_SECONDS`. Fly, link, hearth and through edges never do.
  - Stops `s1`, `s2`... from `data.Stopovers`, each
    `{ key, name, c, x, y, map, mx, my, unverified, stopover = true }`.
  - `Route.Find(graph)`'s `raw` rows and `steps` carry `danger` from the
    edge. Task 5 words it.

- [ ] **Step 1: Write the failing graph tests**

In `test/test_graph.lua`, the file ends

```lua
            h.falsy(edgeTo(g, "x2", "DEST"), "the near mouth is in another zone")
        end)
    end)
end
```

Insert directly before that final `end` a blank line and this block (so the
new `h.describe` sits inside the returned function, after the last one):

```lua
    h.describe("enemy towns", function()
        -- A world of its own on continent 7. Every zone is 10000 yards square,
        -- so map coords convert as world x = 10000 - my * 10000,
        -- y = 10000 - mx * 10000. Keep, an Alliance flight master, stands at
        -- world (5000, 5000) in Vale (20), right on the straight line from
        -- West (5000, 9000) to East (5000, 1000). Hill (21) shares the
        -- continent and no crossing; Castle City (22) is a capital's zone.
        local function vale()
            return {
                Places = {
                    [20] = { name = "Vale", c = 7, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.5, ay = 0.5 },
                    [21] = { name = "Hill", c = 7, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.5, ay = 0.5 },
                    [22] = { name = "Castle City", c = 7, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.5, ay = 0.5 },
                },
                Nodes = {
                    [1] = { name = "Keep, Vale", f = "A", c = 7, x = 5000, y = 5000, map = 20, mx = 0.5, my = 0.5 },
                },
                Flights = {}, Links = {}, Crossings = {},
            }
        end
        local west = { name = "West", c = 7, x = 5000, y = 9000, map = 20 }
        local east = { name = "East", c = 7, x = 5000, y = 1000, map = 20 }
        local function edge(g, a, b, kind)
            for _, e in ipairs(g.edges[a] or {}) do
                if e.to == b and (not kind or e.kind == kind) then
                    return e
                end
            end
        end
        local function straight(w, faction, from, to, extra)
            local opts = { faction = faction, known = {}, from = from, to = to }
            for k, v in pairs(extra or {}) do
                opts[k] = v
            end
            return edge(Graph.Build(w, opts), "START", "DEST")
        end
        local function names(list)
            local out = {}
            for i, place in ipairs(list) do
                out[i] = place.name .. " " .. place.radius
            end
            return table.concat(out, ", ")
        end
        local function near(a, b) return math.abs(a - b) < 0.001 end

        h.it("lists the other side's flight master, 150 yards round, and nothing to its own side", function()
            local list = Graph.Hostile(vale(), "H")
            h.eq(names(list), "Keep 150")
            h.eq(list[1].f, "A")
            h.eq(list[1].c, 7)
            h.truthy(near(list[1].x, 5000) and near(list[1].y, 5000))
            h.eq(#Graph.Hostile(vale(), "A"), 0)
            h.eq(#Graph.Hostile(vale(), nil), 0, "with no faction, nothing is hostile")
        end)
        h.it("never counts a neutral stop, a town with no faction, or your own side's town", function()
            local w = vale()
            w.Nodes[1].f = "N"
            w.Towns = { [7] = { name = "Mill", c = 7, x = 3000, y = 3000, map = 20, mx = 0.7, my = 0.7 },
                        [8] = { name = "Camp", f = "H", c = 7, x = 2000, y = 2000, map = 20, mx = 0.8, my = 0.8 } }
            h.eq(names(Graph.Hostile(w, "H")), "")
        end)
        h.it("counts a town the owner marked, after the flight masters", function()
            local w = vale()
            w.Towns = { [7] = { name = "Mill", c = 7, x = 3000, y = 3000, map = 20, mx = 0.7, my = 0.7 },
                        [8] = { name = "Abbey", f = "A", c = 7, x = 2000, y = 2000, map = 20, mx = 0.8, my = 0.8 },
                        [9] = { name = "Fort", f = "A", c = 7, x = 1000, y = 1000, map = 20, mx = 0.9, my = 0.9 } }
            h.eq(names(Graph.Hostile(w, "H")), "Keep 150, Abbey 150, Fort 150",
                 "the flight master, then the marked towns by name; Mill is not marked")
        end)
        h.it("names a leg after the surer of two enemy places it passes, not the first by name", function()
            local w = vale()
            w.Towns = { [8] = { name = "Cave", f = "A", c = 7, x = 5000, y = 6000, map = 20, mx = 0.4, my = 0.5 } }
            h.eq(straight(w, "H", west, east).danger.name, "Keep", "a flight master is surer than a marked town")
        end)
        h.it("skips an enemy flight master whose name one of your own shares: that town is neutral", function()
            local w = vale()
            w.Nodes[2] = { name = "Keep, Vale", f = "H", c = 7, x = 5050, y = 5000, map = 20, mx = 0.5, my = 0.495 }
            h.eq(names(Graph.Hostile(w, "H")), "")
        end)
        h.it("draws a capital's circle 400 yards round: the place named after its own zone", function()
            local w = vale()
            w.Nodes[3] = { name = "Castle, Castle City", f = "A", c = 7, x = 8000, y = 8000, map = 22,
                           mx = 0.2, my = 0.2 }
            h.eq(names(Graph.Hostile(w, "H")), "Castle 400, Keep 150")
        end)
        h.it("finds the hostile place a point stands in, and none outside every circle", function()
            h.eq(Graph.HostileAt(vale(), "H", { c = 7, x = 5100, y = 5000 }).name, "Keep")
            h.eq(Graph.HostileAt(vale(), "H", { c = 7, x = 5151, y = 5000 }), nil)
            h.eq(Graph.HostileAt(vale(), "A", { c = 7, x = 5000, y = 5000 }), nil, "not to its own side")
        end)
        h.it("charges a leg through an enemy town ten minutes more and names the town on it", function()
            local e = straight(vale(), "H", west, east)
            h.eq(e.kind, "ride")
            h.eq(e.danger.name, "Keep")
            h.eq(e.danger.f, "A")
            h.truthy(near(e.seconds, Graph.RideSeconds(west, east) + 600))
        end)
        h.it("counts a leg that passes right at the radius, and not one a yard wider", function()
            local w = vale()
            w.Nodes[1].x = 5150
            h.eq(straight(w, "H", west, east).danger.name, "Keep")
            w.Nodes[1].x = 5151
            local e = straight(w, "H", west, east)
            h.eq(e.danger, nil)
            h.truthy(near(e.seconds, Graph.RideSeconds(west, east)), "and no penalty")
        end)
        h.it("leaves the leg alone for the side whose town it is", function()
            local e = straight(vale(), "A", west, east)
            h.eq(e.danger, nil)
            h.truthy(near(e.seconds, Graph.RideSeconds(west, east)))
        end)
        h.it("exempts a leg that starts or ends inside the circle: you are there, or going there", function()
            local gate = { name = "Keep Gate", c = 7, x = 5000, y = 5100, map = 20 }
            h.eq(straight(vale(), "H", west, gate).danger, nil, "going there on purpose")
            h.eq(straight(vale(), "H", gate, east).danger, nil, "leaving it")
        end)
        h.it("never charges a flight, a boat, the hearthstone or a tunnel's passage, even over the town", function()
            local w = vale()
            w.Nodes[4] = { name = "Westfort, Vale", f = "H", c = 7, x = 5000, y = 9000, map = 20, mx = 0.1, my = 0.5 }
            w.Nodes[5] = { name = "Eastfort, Vale", f = "H", c = 7, x = 5000, y = 1000, map = 20, mx = 0.9, my = 0.5 }
            w.Flights = { { 4, 5, 100, 90 } }
            -- Two docks 3000 yards either side of Keep, joined by a boat.
            w.Docks = { west_dock = { name = "West Dock", map = 20, mx = 0.2, my = 0.5 },
                        east_dock = { name = "East Dock", map = 20, mx = 0.8, my = 0.5 } }
            w.Links = { { from = "west_dock", to = "east_dock", kind = "boat", minutes = 2 } }
            -- A tunnel from Vale into Hill, its mouths 1000 yards either side of Keep.
            w.Crossings = { { a = 20, b = 21, name = "the Keep tunnel", map = 20, mx = 0.5, my = 0.4,
                              far = { map = 21, mx = 0.5, my = 0.6 } } }
            local inn = { name = "Eastfort Inn", c = 7, x = 5000, y = 1100, map = 20 }
            local g = Graph.Build(w, { faction = "H", known = { [4] = true, [5] = true }, from = west, to = east,
                                       hearth = inn })
            local fly = edge(g, "f4", "f5", "fly")
            h.eq(fly.seconds, 90)
            h.eq(fly.danger, nil)
            h.eq(edge(g, "f4", "f5", "ride").danger.name, "Keep", "riding the same line is charged")
            local boat = edge(g, "west_dock", "east_dock", "boat")
            h.eq(boat.seconds, 120)
            h.eq(boat.danger, nil)
            local hearth = edge(g, "START", "HEARTH", "hearth")
            h.eq(hearth.seconds, Graph.HEARTH_SECONDS)
            h.eq(hearth.danger, nil)
            local through = edge(g, "x1", "x1far")
            h.eq(through.through, true)
            h.eq(through.danger, nil)
            h.truthy(near(through.seconds, Graph.RideSeconds(g.stops.x1, g.stops.x1far)))
        end)
        h.it("tests a rough straight line the same way", function()
            local over = { name = "Over The Hill", c = 7, x = 5000, y = 1000, map = 21 }
            local e = straight(vale(), "H", west, over, { rough = true })
            h.eq(e.rough, true)
            h.eq(e.danger.name, "Keep")
            h.truthy(near(e.seconds, Graph.RideSeconds(west, over) + 600))
        end)
        h.it("adds a stopover as an ordinary point in its zone, and the route goes round through it", function()
            local w = vale()
            -- world (5400, 5000): 400 yards north of Keep, clear of its circle
            w.Stopovers = { { name = "the north road", map = 20, mx = 0.5, my = 0.46 },
                            { name = "on no map", map = 99, mx = 0.5, my = 0.5 } }
            local g = Graph.Build(w, { faction = "H", known = {}, from = west, to = east })
            local s = g.stops.s1
            h.eq(s.name, "the north road")
            h.eq(s.map, 20)
            h.eq(s.zones, nil, "one zone only, like a tunnel's mouth")
            h.truthy(near(s.x, 5400) and near(s.y, 5000))
            h.eq(g.stops.s2, nil, "a stopover on a map we do not have is left out")
            h.eq(edge(g, "START", "s1").danger, nil)
            h.eq(edge(g, "s1", "DEST").danger, nil)
            local r = loaded.ns.Route.Find(g)
            h.eq(#r.steps, 2)
            h.eq(r.steps[1].to.key, "s1")
            h.eq(loaded.ns.Route.StepText(r.steps[1]), "Ride to the north road")
            h.eq(r.steps[2].to.key, "DEST")
            h.eq(r.steps[1].danger, nil)
            h.eq(r.steps[2].danger, nil)
        end)
        h.it("still goes straight through with no way round, the danger on its step", function()
            local r = loaded.ns.Route.Find(Graph.Build(vale(), { faction = "H", known = {}, from = west, to = east }))
            h.eq(#r.steps, 1)
            h.eq(r.steps[1].danger.name, "Keep")
            h.eq(r.raw[1].danger.name, "Keep")
        end)
    end)
```

- [ ] **Step 2: Write the failing real-data tests**

Insert into `test/test_crossings.lua` directly before

```lua
        h.it("leaves a city by its gate", function()
```

this block:

```lua
        -- The owner's route on 2026-09-22: from the Talondeep Path's Ashenvale
        -- mouth, measured in game at 42.3, 71.1, the straight line to
        -- Splintertree Post runs 97 yards from Silverwind Refuge (50.1, 66.2),
        -- whose guards killed a level 15 Horde player there more than once.
        local function fromTalondeep(faction)
            local c, x, y = ns.Geo.ToWorld(data.Places, 1440, 0.423, 0.711)
            local walker = ns.Travel.For(15)
            return { faction = faction, known = {}, speed = walker.speed, walk = walker.walk,
                     from = { name = "You", c = c, x = x, y = y, map = 1440, mx = 0.423, my = 0.711 },
                     to = ns.Search.Exact(data, "Splintertree Post", faction) }
        end
        local function straightLine(opts)
            for _, e in ipairs(ns.Graph.Build(data, opts).edges.START) do
                if e.to == "DEST" then
                    return e
                end
            end
        end
        h.it("charges the Horde's straight line past Silverwind Refuge, and walks it round by the north", function()
            local opts = fromTalondeep("H")
            local line = straightLine(opts)
            h.eq(line.danger and line.danger.name, "Silverwind Refuge")
            h.eq(line.danger.f, "A")
            local silverwind
            for _, enemy in ipairs(ns.Graph.Hostile(data, "H")) do
                if enemy.name == "Silverwind Refuge" then
                    silverwind = enemy
                end
            end
            h.truthy(silverwind, "tools/town-factions.csv marks Silverwind Refuge Alliance")
            local r = ns.Route.Plan(data, opts)
            -- 307 seconds longer on foot than the straight line, inside its ten
            -- minutes; the way by the Mor'shan Rampart passes Silverwing Grove.
            h.eq(table.concat(texts(r), " / "), "Walk to the Ashenvale-Felwood road / Walk to Splintertree Post")
            for _, s in ipairs(r.steps) do
                h.eq(s.danger, nil)
                h.truthy(ns.Geo.SegmentDistance(s.from, s.to, silverwind) > silverwind.radius,
                         ns.Route.StepText(s) .. " passes Silverwind Refuge")
            end
        end)
        h.it("walks the Alliance straight there: nothing on that line is hostile to it", function()
            for _, enemy in ipairs(ns.Graph.Hostile(data, "A")) do
                h.truthy(enemy.name ~= "Silverwind Refuge", "Silverwind Refuge is hostile to the Alliance")
            end
            local opts = fromTalondeep("A")
            h.eq(straightLine(opts).danger, nil)
            local r = ns.Route.Plan(data, opts)
            h.eq(table.concat(texts(r), " / "), "Walk to Splintertree Post")
            h.eq(r.steps[1].danger, nil)
        end)
        h.it("counts the other side's flight masters and marked towns, and draws capitals wider", function()
            local function summary(faction)
                local stops, towns, capitals = 0, 0, {}
                for _, enemy in ipairs(ns.Graph.Hostile(data, faction)) do
                    if enemy.rank == 1 then
                        stops = stops + 1
                    else
                        towns = towns + 1
                    end
                    if enemy.radius == ns.Graph.CAPITAL_RADIUS then
                        capitals[#capitals + 1] = enemy.name
                    end
                end
                table.sort(capitals)
                return stops, towns, table.concat(capitals, ", ")
            end
            local marked = { A = 0, H = 0 }
            for _, t in pairs(data.Towns) do
                if t.f then
                    marked[t.f] = marked[t.f] + 1
                end
            end
            local stops, towns, capitals = summary("H")
            h.eq(stops, 24, "32 Alliance flight masters less the 8 split neutral towns")
            h.eq(towns, marked.A, "every town the owner marked Alliance, and no other")
            h.truthy(towns > 0, "a count of nothing proves nothing")
            h.eq(capitals, "Ironforge, Stormwind", "Darnassus has no flight master and is not marked")
            stops, towns, capitals = summary("A")
            h.eq(stops, 23, "31 Horde flight masters less the same 8")
            h.eq(towns, marked.H, "every town the owner marked Horde, and no other")
            h.eq(capitals, "Orgrimmar, Thunder Bluff, Undercity")
        end)
```

- [ ] **Step 3: Bring two existing real routes up to the marked towns**

In "walks a new undead from Tirisfal to Mount Hyjal zone by zone", replace

```lua
            h.eq(t[5], "Walk to the Mor'shan Rampart")
            h.eq(t[6], "Walk to the Ashenvale-Felwood road")
            h.eq(t[7], "Walk to the Timbermaw Hold tunnels")
            h.eq(t[8], "Walk to Darkwhisper Gorge")
            h.eq(t[9], "Walk to Summit of Eternity", "on to a place in Mount Hyjal, not stopping at its border")
            h.eq(#t, 9)
```

with

```lua
            h.eq(t[5], "Walk to the Mor'shan Rampart")
            -- Round by the Darkshore road: the straight line from the rampart to
            -- the Felwood road passes Silverwing Outpost, which the owner marked
            -- Alliance in tools/town-factions.csv.
            h.eq(t[6], "Walk to the Ashenvale-Darkshore road")
            h.eq(t[7], "Walk to the Ashenvale-Felwood road")
            h.eq(t[8], "Walk to the Timbermaw Hold tunnels")
            h.eq(t[9], "Walk to Darkwhisper Gorge")
            h.eq(t[10], "Walk to Summit of Eternity", "on to a place in Mount Hyjal, not stopping at its border")
            h.eq(#t, 10)
```

In "explains each ground step and warns a low-level character", the tunnel
and Hyjal steps move down one; replace

```lua
            text, warn = ns.Route.StepDetail(data, r.steps[7], 60)
            h.eq(text, "into Winterspring · Timbermaw furbolgs attack without reputation")
            h.eq(warn, true)
            text, warn = ns.Route.StepDetail(data, r.steps[8], 60)
            h.eq(text, "into Mount Hyjal · crossing not confirmed")
```

with

```lua
            text, warn = ns.Route.StepDetail(data, r.steps[8], 60)
            h.eq(text, "into Winterspring · Timbermaw furbolgs attack without reputation")
            h.eq(warn, true)
            text, warn = ns.Route.StepDetail(data, r.steps[9], 60)
            h.eq(text, "into Mount Hyjal · crossing not confirmed")
```

Replace the tunnel test's first line,

```lua
        h.it("goes through the Talondeep Path from Sun Rock Retreat to Splintertree Post", function()
```

with

```lua
        -- Zoram'gar Outpost, not Splintertree Post: from Sun Rock the way to
        -- Splintertree now stays out of Ashenvale's marked Alliance south, down
        -- the Stonetalon pass and up through the Mor'shan Rampart.
        h.it("goes through the Talondeep Path from Sun Rock Retreat to Zoram'gar Outpost", function()
```

and in the same test replace

```lua
            local to = ns.Search.Exact(data, "Splintertree Post", "H")
            h.truthy(to, "no Splintertree Post")
```

with

```lua
            local to = ns.Search.Exact(data, "Zoram'gar Outpost", "H")
            h.truthy(to, "no Zoram'gar Outpost")
```

The rest of that test (the approach to the Stonetalon mouth, the step
through, "into Ashenvale") holds unchanged: from Sun Rock Retreat the route
to Zoram'gar Outpost is the Talondeep Path, through it, then Zoram'gar.

- [ ] **Step 4: Run the Lua gate to see them fail**

Expected: `479 passed, 18 failed`. Failing: in "enemy towns", the six that
call `Graph.Hostile` or `Graph.HostileAt` (`attempt to call field 'Hostile'
(a nil value)`) and the seven that read `danger` or `g.stops.s1` ("names a
leg after the surer...", "charges a leg...", "counts a leg that passes right
at the radius...", "never charges a flight, a boat...", "tests a rough
straight line...", "adds a stopover...", "still goes straight through...":
`attempt to index ... (a nil value)`); in "real routes on the ground", the
three new ones and the two brought up to date in Step 3 (with no penalty the
walk to Hyjal still takes the old nine steps). Two new graph tests already
pass, as they should with no penalty at all: "leaves the leg alone for the
side whose town it is" and "exempts a leg that starts or ends inside the
circle"; so does the tunnel test, now to Zoram'gar Outpost.

- [ ] **Step 5: `GoblinPS/Graph.lua`, the constants**

Insert directly after

```lua
Graph.HEARTH_SECONDS = 20          -- cast plus loading screen
```

this block:

```lua
-- A ride leg that passes an enemy town costs this much more: a penalty, not
-- a ban, so the router goes round whenever a way round is within ten minutes
-- and a destination is never made unreachable. The two radii are guesses
-- until walked: the closest reading at Silverwind Refuge, where the guards
-- killed a level 15 Horde player on 2026-09-22, was about 40 yd from its map
-- label, so 150 errs wide.
Graph.HOSTILE_SECONDS = 600
Graph.HOSTILE_RADIUS = 150         -- yards around an enemy town or flight master
Graph.CAPITAL_RADIUS = 400         -- yards around an enemy capital's
```

- [ ] **Step 6: `GoblinPS/Graph.lua`, the hostile places**

Insert directly after

```lua
local function legal(stopFaction, faction)
    return not stopFaction or stopFaction == "N" or stopFaction == faction
end
```

a blank line and this block:

```lua
-- A capital is the one place named after the zone it stands in: "Orgrimmar"
-- in Orgrimmar, "Stormwind" in Stormwind City, and the town Darnassus in
-- Darnassus once tools/town-factions.csv marks it. Moonglade's two flight
-- masters are named so too, but they are twins (see Graph.Hostile), so never
-- hostile.
local function isCapital(data, name, map)
    local zone = data.Places[map]
    return zone ~= nil and zone.name:find(name, 1, true) == 1
end

-- Every place whose guards attack this faction, as { name, f, c, x, y, map,
-- radius, rank }: only places whose faction is known. Two sources, surest
-- first:
--   rank 1  the other side's flight masters, bar one whose short name a stop
--           this faction may use shares (Booty Bay, Gadgetzan, Everlook...:
--           the town is neutral, only its flight masters are split);
--   rank 2  the other side's towns, by the `f` Data/Towns.lua carries, which
--           comes only from the owner's marks in tools/town-factions.csv.
-- A place with no faction, or "N", is nobody's enemy. No faction, no list.
-- Sorted by rank, then name, map and position: when a leg passes two, it is
-- named after the surer one, and always the same one.
function Graph.Hostile(data, faction)
    local list = {}
    if not faction then
        return list
    end
    local usable = {}
    for _, n in pairs(data.Nodes) do
        if legal(n.f, faction) then
            usable[ns.Search.ShortName(n.name)] = true
        end
    end
    local function add(name, f, place, rank)
        if f and not legal(f, faction) then
            list[#list + 1] = { name = name, f = f, c = place.c, x = place.x, y = place.y, map = place.map,
                                rank = rank, radius = isCapital(data, name, place.map) and Graph.CAPITAL_RADIUS
                                    or Graph.HOSTILE_RADIUS }
        end
    end
    for _, n in pairs(data.Nodes) do
        local name = ns.Search.ShortName(n.name)
        if not usable[name] then
            add(name, n.f, n, 1)
        end
    end
    for _, t in pairs(data.Towns or {}) do
        add(t.name, t.f, t, 2)
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.name ~= b.name then return a.name < b.name end
        if a.map ~= b.map then return a.map < b.map end
        if a.x ~= b.x then return a.x < b.x end
        return a.y < b.y
    end)
    return list
end

-- The first hostile place whose circle holds this world point, or nil. The
-- planner warns when a destination is one.
function Graph.HostileAt(data, faction, point)
    for _, h in ipairs(Graph.Hostile(data, faction)) do
        if ns.Geo.Distance(point, h) <= h.radius then
            return h
        end
    end
    return nil
end

-- The first of these hostile places (one continent's, in Graph.Hostile's
-- order) that the straight leg p->q passes within its radius of, as
-- { name, f }; nil when none does. A place is ignored when either end of the
-- leg is inside its circle: you are already there, or going there on purpose.
local function dangerOn(hostile, p, q)
    local Geo = ns.Geo
    local x0, x1 = math.min(p.x, q.x), math.max(p.x, q.x)
    local y0, y1 = math.min(p.y, q.y), math.max(p.y, q.y)
    for _, h in ipairs(hostile or {}) do
        local r = h.radius
        -- The box round the leg, widened by r, is a cheap no for most places:
        -- it halves what the test costs Graph.Build (measured 2026-09-22).
        local near = h.x >= x0 - r and h.x <= x1 + r and h.y >= y0 - r and h.y <= y1 + r
        if near and Geo.SegmentDistance(p, q, h) <= r and Geo.Distance(p, h) > r and Geo.Distance(q, h) > r then
            return { name = h.name, f = h.f }
        end
    end
    return nil
end
```

- [ ] **Step 7: `GoblinPS/Graph.lua`, the `Graph.Build` comment**

Replace

```lua
-- with the special keys START, DEST and HEARTH. A ride edge carries zone (the
-- UiMap it is walked in), walk and, in rough mode, rough. The edge between the
-- two ends of a two-ended crossing also carries through = true, and its zone
-- is the one being entered.
```

with

```lua
-- with the special keys START, DEST and HEARTH. A ride edge carries zone (the
-- UiMap it is walked in), walk, danger ({ name, f }: the enemy town its
-- straight line passes, already priced in at Graph.HOSTILE_SECONDS) and, in
-- rough mode, rough. The edge between the two ends of a two-ended crossing
-- also carries through = true, and its zone is the one being entered; it is
-- one passage, never charged for a town. Data/Stopovers.lua rows are stops
-- keyed "s1", "s2"...
```

- [ ] **Step 8: `GoblinPS/Graph.lua`, the stopovers**

Insert directly after the end of the crossings loop in `Graph.Build`,

```lua
                near.zones, near.cross = { x.a, x.b }, x.cross
                stops[key] = near
            end
        end
    end
```

this block:

```lua
    -- A stopover is an ordinary point in one zone, like a tunnel's mouth: the
    -- pair loop below joins it to every other point in its zone, so a ride
    -- can bend through it round an enemy town.
    for i, s in ipairs(data.Stopovers or {}) do
        local c, x, y = ns.Geo.ToWorld(data.Places, s.map, s.mx, s.my)
        if c then
            local key = "s" .. i
            stops[key] = { key = key, name = s.name, c = c, x = x, y = y, map = s.map, mx = s.mx, my = s.my,
                           unverified = s.unverified, stopover = true }
        end
    end
```

- [ ] **Step 9: `GoblinPS/Graph.lua`, the pair loop**

Replace

```lua
    for _, pk in ipairs(keys) do
        for _, qk in ipairs(keys) do
            -- Nothing leaves DEST; nothing but the hearthstone arrives at HEARTH; nothing arrives at START.
            if pk ~= qk and pk ~= "DEST" and qk ~= "START" and qk ~= "HEARTH" then
                local p, q = stops[pk], stops[qk]
                local zone = sharedZone(p, q)
                if zone then
                    local seconds = Graph.RideSeconds(p, q, speed)
                    if q.cross then
                        seconds = seconds + q.cross
                    end
                    if qk == "DEST" and zoneMap and inZone(p, zoneMap) then
                        seconds = 0
                    end
                    addEdge(edges, pk, qk, { kind = "ride", seconds = seconds, zone = zone, walk = opts.walk })
                elseif opts.rough and p.c == q.c and (pk == "START" or pk == "HEARTH" or qk == "DEST") then
                    addEdge(edges, pk, qk, { kind = "ride", seconds = Graph.RideSeconds(p, q, speed),
                                             walk = opts.walk, rough = true })
```

with

```lua
    -- The enemy's towns, by continent: a leg is only ever tested against its own.
    local hostile = {}
    for _, h in ipairs(Graph.Hostile(data, faction)) do
        hostile[h.c] = hostile[h.c] or {}
        table.insert(hostile[h.c], h)
    end

    for _, pk in ipairs(keys) do
        for _, qk in ipairs(keys) do
            -- Nothing leaves DEST; nothing but the hearthstone arrives at HEARTH; nothing arrives at START.
            if pk ~= qk and pk ~= "DEST" and qk ~= "START" and qk ~= "HEARTH" then
                local p, q = stops[pk], stops[qk]
                local zone = sharedZone(p, q)
                if zone then
                    local seconds, danger = Graph.RideSeconds(p, q, speed), nil
                    if q.cross then
                        seconds = seconds + q.cross
                    end
                    if qk == "DEST" and zoneMap and inZone(p, zoneMap) then
                        seconds = 0   -- already in the zone: no leg is ridden, so none passes anything
                    else
                        danger = dangerOn(hostile[p.c], p, q)
                    end
                    if danger then
                        seconds = seconds + Graph.HOSTILE_SECONDS
                    end
                    addEdge(edges, pk, qk, { kind = "ride", seconds = seconds, zone = zone, walk = opts.walk,
                                             danger = danger })
                elseif opts.rough and p.c == q.c and (pk == "START" or pk == "HEARTH" or qk == "DEST") then
                    local danger = dangerOn(hostile[p.c], p, q)
                    addEdge(edges, pk, qk, { kind = "ride", walk = opts.walk, rough = true, danger = danger,
                                             seconds = Graph.RideSeconds(p, q, speed)
                                                 + (danger and Graph.HOSTILE_SECONDS or 0) })
```

The three `end`s and `return { stops = stops, edges = edges }` after it stay
as they are.

- [ ] **Step 10: `GoblinPS/Route.lua`, carry `danger` onto the step**

In `tidy`, replace

```lua
                                  through = s.through }
```

with

```lua
                                  through = s.through, danger = s.danger }
```

Above `Route.Find`, replace

```lua
-- also carries zone, walk, rough and through (the passage of a two-ended crossing).
```

with

```lua
-- also carries zone, walk, rough, through (the passage of a two-ended
-- crossing) and danger ({ name, f }: the enemy town its straight line passes).
```

In `Route.Find`, replace

```lua
                               through = p.edge.through })
```

with

```lua
                               through = p.edge.through, danger = p.edge.danger })
```

- [ ] **Step 11: Run every gate**

Lua `497 passed, 0 failed` (479 + 18). Every other existing test still
passes: the step detail does not print `danger` until Task 5. Python `Ran 74
tests`, `OK`. Art green. luacheck and the language server: zero warnings.

- [ ] **Step 12: Commit**

```
git add GoblinPS/Graph.lua GoblinPS/Route.lua test/test_graph.lua test/test_crossings.lua
git commit -m "Graph: a ride leg past a known enemy town costs ten minutes more" -m "Graph.Hostile builds this faction's enemy places from the other side's flight masters (bar the eight split neutral towns) and the other side's towns marked in tools/town-factions.csv, flight masters first, 150 yards round or 400 for a capital (the place named after its own zone). Every ride edge, rough ones too, that passes a circle neither of its ends is inside gains Graph.HOSTILE_SECONDS and danger = { name, f }; flights, links, the hearthstone and a tunnel's through leg never do. Stopovers are ordinary one-zone stops. On the real data the Horde's straight line from the Talondeep Path to Splintertree Post carries Silverwind Refuge, and the route goes round by the Ashenvale-Felwood road; the walk to Hyjal goes round Silverwing Outpost, and the tunnel test now goes to Zoram'gar Outpost." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: saying so -- the amber detail line and the hostile-destination note

**Files:**
- Modify: `GoblinPS/Route.lua` (`passes` and `Route.HostileNote` before
  `levels`, line 210; `Route.StepDetail`, lines 217-259)
- Modify: `GoblinPS/Core.lua` (`Core.PlanRoute`, lines 115-131)
- Modify: `GoblinPS/Planner.lua` (`Planner.Refresh`, lines 228-231)
- Test: `test/test_route.lua`, `test/test_strip.lua`, `test/test_ui.lua`,
  `test/test_crossings.lua` (one expectation)

**Interfaces:**
- Consumes: `step.danger = { name, f }` (Task 4), `Graph.HostileAt` (Task 4),
  `step.to.stopover` (Task 4).
- Produces:
  - `Route.StepDetail(data, step, level)`: a ride step with `danger` returns
    `"<in|into zone> · passes <name> (<Alliance|Horde>)"` plus any hazard and
    unconfirmed note after it, and `warn = true`; the level range is left
    out. A rough step with `danger` returns `"passes <name> (<faction>)", true`.
    An unconfirmed stopover says "stopover not confirmed".
  - `Route.HostileNote(place) -> "<name> is an Alliance town: its guards will
    attack you."` (or "a Horde town").
  - `Core.PlanRoute(to, from)`'s plan gains `hostile` (that note, or nil),
    and the note is also `plan.notes[1]`.
  - `Planner.Refresh` shows `plan.hostile` on the warning line before
    anything else. `Strip.Layout` is unchanged: it already turns an amber
    detail into the tooltip's third line and the first one into
    `layout.warning`.

- [ ] **Step 1: Write the failing Route tests**

Insert into `test/test_route.lua` directly after the end of "says only the
crossing is unconfirmed when it carries no hazard":

```lua
            h.eq(text, "into Eastland · crossing not confirmed")
            h.eq(warn, true)
        end)
```

this block:

```lua
        h.it("names the enemy town a leg passes, in amber, in place of the level range", function()
            local step = { kind = "ride", zone = 1, to = { name = "Bravo, Westland" },
                           danger = { name = "Keep", f = "A" } }
            local text, warn = Route.StepDetail(world, step, 60)
            h.eq(text, "in Westland · passes Keep (Alliance)")
            h.eq(warn, true)
            step.danger.f = "H"
            h.eq((Route.StepDetail(world, step, 60)), "in Westland · passes Keep (Horde)")
        end)
        h.it("says so even on a step that arrives at the zone itself, and before a crossing's hazard", function()
            local keep = { name = "Keep", f = "A" }
            h.eq((Route.StepDetail(world, { kind = "ride", zone = 1, to = { name = "Westland" }, danger = keep }, 60)),
                 "in Westland · passes Keep (Alliance)")
            local gate = { name = "the test gate", zones = { 1, 2 }, warn = "trolls on the bridge" }
            h.eq((Route.StepDetail(world, { kind = "ride", zone = 1, to = gate, danger = keep }, 60)),
                 "into Eastland · passes Keep (Alliance) · trolls on the bridge")
        end)
        h.it("names the town a rough straight line passes, having no zone to name", function()
            local step = { kind = "ride", rough = true, to = { name = "Lostland" },
                           danger = { name = "Keep", f = "H" } }
            local text, warn = Route.StepDetail(world, step, 5)
            h.eq(text, "passes Keep (Horde)")
            h.eq(warn, true)
        end)
        h.it("says a stopover, not a crossing, is unconfirmed", function()
            local stop = { name = "the north road", map = 1, stopover = true, unverified = true }
            local text, warn = Route.StepDetail(world, { kind = "ride", zone = 1, to = stop }, 60)
            h.eq(text, "in Westland · stopover not confirmed")
            h.eq(warn, true)
        end)
```

Insert into `test/test_route.lua` directly before

```lua
    h.describe("Route text", function()
```

this block:

```lua
    h.describe("Route.HostileNote", function()
        h.it("warns of a destination whose guards will attack, with the right article", function()
            h.eq(Route.HostileNote({ name = "Silverwind Refuge", f = "A" }),
                 "Silverwind Refuge is an Alliance town: its guards will attack you.")
            h.eq(Route.HostileNote({ name = "Splintertree Post", f = "H" }),
                 "Splintertree Post is a Horde town: its guards will attack you.")
        end)
    end)
```

- [ ] **Step 2: Write the failing Strip test**

Insert into `test/test_strip.lua` directly before

```lua
        h.it("wears the walk or ride badge through a tunnel, and says through in the tooltip", function()
```

this block:

```lua
        h.it("turns the enemy town a leg passes amber and names it as the warning", function()
            local leg = step("ride", "Splintertree Post, Ashenvale",
                             { zone = 1, danger = { name = "Silverwind Refuge", f = "A" } })
            local layout = Strip.Layout(data, { leg }, OPTS)
            local detail = layout.stops[2].tooltip[3]
            h.eq(detail.text, "in Westland · passes Silverwind Refuge (Alliance)")
            h.eq(detail.amber, true)
            h.eq(layout.warning, "Splintertree Post: in Westland · passes Silverwind Refuge (Alliance)")
        end)
```

- [ ] **Step 3: Write the failing planner and chat tests**

In `test/test_ui.lua`, insert directly after the end of "draws no strip
without a route":

```lua
            h.truthy(ui.notes:IsShown())
            pickTo("delt")
            h.truthy(ui.strip:IsShown())
        end)
```

a blank line and this block:

```lua
        h.it("warns under the strip, before anything else, when the destination is an enemy town", function()
            -- Echo is an Alliance flight master and the fake player is Horde.
            -- Westland is made a 70-80 zone for the test, so the route's own
            -- steps are amber too and the note has to win the line.
            local savedZone = ns.Data.Zones[1]
            ns.Data.Zones[1] = { 70, 80 }
            local ok, err = pcall(function()
                local ui = pickTo("echo")
                local _, state = Planner.Debug()
                local note = "Echo is an Alliance town: its guards will attack you."
                h.eq(state.plan.hostile, note)
                h.eq(state.plan.notes[1], note, "and first among the notes, for /gps to")
                h.truthy(ui.strip:IsShown(), "it is still a route")
                h.eq(ui.hint:GetText(), note)
            end)
            ns.Data.Zones[1] = savedZone -- put the fixture back even when an assertion failed
            local ui = pickTo("delt")
            local _, state = Planner.Debug()
            h.truthy(ok, err)
            h.eq(state.plan.hostile, nil, "Delta is nobody's enemy")
            h.falsy(ui.hint:GetText():find("guards", 1, true))
        end)
```

The fixture is put back before any assertion outside the `pcall` runs, so a
failure here cannot leak Westland's 70-80 range into the `/gps probe zones`
tests after it.

In `test/test_ui.lua`, insert directly after the end of "takes a zone's name
to the first place in it, all the way there":

```lua
            h.truthy(saw, "the route goes on past the East Dock to Delta")
        end)
```

this block:

```lua
        h.it("says first when the destination is an enemy town", function()
            local from = #printed
            SlashCmdList.GOBLINPS("to echo")
            h.truthy(printed[from + 1]:find("Echo is an Alliance town: its guards will attack you.", 1, true),
                     printed[from + 1])
            h.truthy(printed[from + 2]:find("To Echo: ", 1, true), printed[from + 2])
        end)
```

- [ ] **Step 4: Update the one real route whose detail line changes**

In `test/test_crossings.lua`, in "explains each ground step and warns a
low-level character", replace

```lua
            h.eq(text, "into Winterspring · Timbermaw furbolgs attack without reputation")
```

with

```lua
            -- The line from the Ashenvale-Felwood road to the tunnels runs past
            -- Talonbranch Glade, an Alliance flight master, and there is no way
            -- round it: the town comes first, so the hazard is what gets cut.
            h.eq(text, "into Winterspring · passes Talonbranch Glade (Alliance) · Timbermaw furbolgs attack without "
                 .. "reputation")
```

- [ ] **Step 5: Run the Lua gate to see them fail**

Expected: `496 passed, 9 failed`: the four new `Route.StepDetail` tests
(the danger is not worded yet, and the stopover still says "crossing not
confirmed"), `Route.HostileNote` (`attempt to call field 'HostileNote'`),
the new Strip test, "explains each ground step and warns a low-level
character", "warns under the strip, before anything else, when the
destination is an enemy town" and "says first when the destination is an
enemy town". Nothing else fails.

- [ ] **Step 6: `GoblinPS/Route.lua`, the words**

Insert directly before

```lua
local function levels(range)
```

this block:

```lua
local FACTION = { A = "Alliance", H = "Horde" }

-- "passes Silverwind Refuge (Alliance)"
local function passes(danger)
    return "passes " .. danger.name .. " (" .. FACTION[danger.f] .. ")"
end

-- The plan note for a destination inside an enemy town's circle (Graph.HostileAt).
function Route.HostileNote(place)
    return ("%s is %s %s town: its guards will attack you."):format(
        place.name, place.f == "A" and "an" or "a", FACTION[place.f])
end
```

Replace the head of `Route.StepDetail` and its comment,

```lua
-- character's level, the crossing carries a hazard note, or it is
-- unconfirmed. Other step kinds have no detail ("", false). A hazard or an
-- unconfirmed note replaces the level range on the line (never both: the
-- line does not wrap, and the hazard is the part that must not be cut off).
function Route.StepDetail(data, step, level)
    if WAITS[step.kind] then
        return "includes the average wait", false
    end
    if step.kind ~= "ride" or not step.zone then
        return "", false
    end
```

with

```lua
-- character's level, the leg passes an enemy town, the crossing carries a
-- hazard note, or it is unconfirmed. Other step kinds have no detail ("",
-- false). An enemy town, a hazard or an unconfirmed note replaces the level
-- range on the line (never both: the line does not wrap, and the warning is
-- the part that must not be cut off), the enemy town first.
function Route.StepDetail(data, step, level)
    if WAITS[step.kind] then
        return "includes the average wait", false
    end
    if step.kind ~= "ride" then
        return "", false
    end
    if not step.zone then
        -- A rough straight line has no zone to name, but may still pass a town.
        if step.danger then
            return passes(step.danger), true
        end
        return "", false
    end
```

Replace the rest of `Route.StepDetail`,

```lua
        if places[zone] and ns.Search.ShortName(step.to.name) == places[zone].name then
            return "", false
        end
    end
    local warn = ns.Travel.Dangerous(zones[zone], level)
    if step.to.warn or step.to.unverified then
        warn = true
    else
        text = text .. levels(zones[zone])
    end
    if step.to.warn then
        text = text .. " · " .. step.to.warn
    end
    if step.to.unverified then
        text = text .. " · crossing not confirmed"
    end
    return text, warn
end
```

with

```lua
        if places[zone] and ns.Search.ShortName(step.to.name) == places[zone].name and not step.danger then
            return "", false
        end
    end
    local warn = ns.Travel.Dangerous(zones[zone], level)
    if step.danger or step.to.warn or step.to.unverified then
        warn = true
    else
        text = text .. levels(zones[zone])
    end
    if step.danger then
        text = text .. " · " .. passes(step.danger)
    end
    if step.to.warn then
        text = text .. " · " .. step.to.warn
    end
    if step.to.unverified then
        text = text .. (step.to.stopover and " · stopover not confirmed" or " · crossing not confirmed")
    end
    return text, warn
end
```

- [ ] **Step 7: `GoblinPS/Core.lua`, the note**

In the comment above `Core.PlanRoute`, insert directly after

```lua
--   notes   plain lines for the player; the last one explains a missing route
```

these two lines:

```lua
--   hostile the note, also first in notes, when the destination stands in an
--           enemy town (Graph.HostileAt); the planner puts it first under the strip
```

In `Core.PlanRoute`, insert directly after

```lua
        plan.notes[1] = "Can't tell where you are. Inside an instance?"
        return plan
    end
```

this block (the notes are still empty here, so the note is the first):

```lua
    local enemy = ns.Graph.HostileAt(ns.Data, faction, to)
    if enemy then
        plan.hostile = Route.HostileNote(enemy)
        plan.notes[#plan.notes + 1] = plan.hostile
    end
```

- [ ] **Step 8: `GoblinPS/Planner.lua`, the warning line**

In `Planner.Refresh`, replace

```lua
        -- One amber line under the strip. What the player must know first
        -- wins: a stop in a dangerous place, then a note about the route
        -- itself, then a flight path worth discovering.
        if layout and layout.warning then
```

with

```lua
        -- One amber line under the strip. What the player must know first
        -- wins: a destination whose guards will attack, then a stop in a
        -- dangerous place, then a note about the route itself, then a flight
        -- path worth discovering.
        if plan.hostile then
            hint = plan.hostile
        elseif layout and layout.warning then
```

- [ ] **Step 9: Run every gate**

Lua `505 passed, 0 failed` (497 + 8). Python `Ran 74 tests`, `OK`. Art
green. luacheck and the language server: zero warnings.

- [ ] **Step 10: Commit**

```
git add GoblinPS/Route.lua GoblinPS/Core.lua GoblinPS/Planner.lua test/test_route.lua test/test_strip.lua test/test_ui.lua test/test_crossings.lua
git commit -m "Say so: the leg that passes an enemy town, and a destination that is one" -m "A ride step with danger reads 'passes Silverwind Refuge (Alliance)' in amber on its detail line, in place of the level range and before a crossing's hazard, so it reaches the tooltip and the line under the strip; a rough line says it alone, and an unconfirmed stopover says so as a stopover. A destination inside an enemy town's circle gets 'Silverwind Refuge is an Alliance town: its guards will attack you.', first among the notes for /gps to and first on the planner's warning line. The walk from Tirisfal to Mount Hyjal now names Talonbranch Glade on its way to the Timbermaw tunnels." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

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

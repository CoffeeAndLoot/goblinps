# A Towns Table, a Scrolling List, a Zone Browser (plan 10) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every named town on the world map a destination, generated from
the game's own `AreaPOI` table; let the results list scroll on the mouse wheel
with a "6-10 of 23" footer; and turn the empty box's drop-down into a zone
browser (recents, then every zone with its count).

**Architecture:** `tools/build_graph.py` fetches `AreaPOI` and `AreaTable`,
places each town in its zone (AreaID, then its own name in `AreaTable`, then a
zone rectangle only when exactly one holds it), infers a faction from nearby
flight masters, drops towns that are a flight stop, and emits
`GoblinPS/Data/Towns.lua`. `Search.Candidates` offers those towns beside the
stops and the hand-written inn rows, hides an enemy stop whose name a usable
stop shares, and lets every hand-written inn row win by name. `Search.Zones`
is the browser's list. `Planner.lua` keeps the full match list, draws `fit`
rows of it from a window the wheel moves, and treats a zone row as a way in
(it fills the box), never a destination.

**Tech Stack:** Lua 5.1 against the WoW Forever client API (build
1.60.1.69913, interface 16001), no libraries; desktop tests through lupa;
the generator and its tests in Python 3 (`unittest`).

**Spec:** `docs/superpowers/specs/2026-09-22-goblinps-towns-and-browsing-design.md`
(binding). It amends the plan 8 spec
(`docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`) and
the plan 9 spec
(`docs/superpowers/specs/2026-09-21-goblinps-settings-and-marquee-design.md`).

## Global Constraints

- Plain Lua 5.1, **no libraries**, **no Blizzard frame templates**, no secure code.
- `API.lua` is the only file that calls Blizzard game APIs. UI files may use
  UI globals the siblings already use (`CreateFrame`, `UIParent`, `GameTooltip`,
  `UISpecialFrames`).
- **Never read a size from a frame that only inherits one.** Measure the frame
  given an explicit `SetSize` (the planner's `ui.frame`), never a FontString or
  a frame placed by `SetAllPoints` or two anchors. The rows that fit the list
  are worked out from the geometry and `ui.frame`'s explicit size.
- **A test that checks how big a thing is cannot tell you it is in the wrong
  place.** Pin positions, not only sizes (the footer's anchors are pinned).
- Every FontString gets two horizontal anchors (or a width) and decides wrap
  or truncate.
- A missing texture must leave a working window.
- No coordinate is hand-typed in `Planner.lua`: every position comes from
  `ns.Data.ArtGeometry`. The footer's height (`FOOTER`) is a font measure like
  `ROW`, not a position.
- Route text stays plain and glanceable.
- `Data/Towns.lua` is **generated**; nobody edits it. Hand-written data still
  wins: `Data/Inns.lua` rows stay.
- Lint and the language server at **zero warnings**; do not silence a warning,
  fix the code. No new `---@diagnostic disable`, `luacheck:` exemption or
  `max_line_length = false` (`Towns.lua`'s longest line is 103 characters, so
  it needs none). A new WoW global goes in **both** `.luacheckrc` and
  `.luarc.json` (this plan adds none).
- Never guess an event, API or method name: check it in
  `D:\wow-api\1.60.1.69913` (the `forever` branch; its `version.txt` reads
  `1.60.1.69913`). Verified for this plan:
  - `ScriptRegion:EnableMouseWheel(enable)`
    (`Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua`,
    beside `EnableMouse`, which the addon already calls). The `OnMouseWheel`
    script, `(self, delta)`, is set with `SetScript` by Blizzard's own
    `Blizzard_AccountStore/Blizzard_AccountStoreCardTemplates.lua` and
    `Blizzard_ArchaeologyUI` (`ArchaeologyFrame_OnMouseWheel(self, value)`).
  - `EditBox:SetFocus()` (`SimpleEditBoxAPIDocumentation.lua`; already
    modelled in the fake).
  - `GameFontHighlightSmall` inherits `GameFontNormalSmall` inherits
    `SystemFont_Shadow_Small`, height 10 (`Blizzard_Fonts_Shared/Shared/FontStyles.xml`,
    `Fonts.xml`): the footer's 14 px slot holds one line of it.
  - Present is not the same as answering on this build (CLAUDE.md). The wheel
    is **unverified in game**; the checklist asks for it.
- Any widget method the fake frames do not model is added to
  `test/fake_frames.lua` in the task that first calls it: modelled when it
  has an effect a test must see, `ALLOWED_NOOP` only when it has none.
  `EnableMouseWheel` is modelled (Task 4): the client sends no wheel to a
  frame that did not enable it, and `Fake.Wheel` refuses one too.
- Commit after each task. **Never stage `AGENTS.md`** (it belongs to Codex).
  Never push. Do not switch branches: the work is on `places-not-zones`.
- Gates, all green before a task is done (run from `D:\goblinps`):
  - Lua: `python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"`
  - Python: `python -m unittest discover -s test/tools`
  - Art: `python tools/check_art.py`
  - luacheck and lua-language-server **from PowerShell**, as in `CLAUDE.md`
    ("Commands"). Through Git Bash the language server mis-scopes itself and
    reports bogus warnings.
- Known state at the start (checked 2026-09-22 on this branch at `03ed7dc`):
  Lua **443 passed, 0 failed**; Python **56 tests OK**; `check_art.py`
  `47 pass, 0 with problems, 0 not drawn yet`. This plan touches no art, so
  that gate must simply stay green.

## Dependency on plan 9

The project rule is to write each plan after the one before it has been used
in game. Plan 9 has not been run in the client. Plan 10 touches plan 9 at two
seams only: the results list (`showResults`, `ApplyLayout`'s `fit`) and the
drop-down's measured width (`results.labelWidth`, which now also measures the
zone rows). The settings panel, the marquee and the arrival radii are
untouched. The owner is playing from this checkout; each task commits alone,
so any one can be reverted.

## What the data says (measured 2026-09-22 from wago.tools, build 1.60.1.69913)

`AreaPOI` has **372** rows and `AreaTable` **1372**. On continents 0 and 1:

- **207** rows carry a town icon: **6** capitals (icon 5), **35** towns
  (icon 4), **166** villages, outposts and other named spots (icon 6: caves,
  mines and dungeon entrances such as Wailing Caverns and Maraudon among them).
- **9** of those show only while a world state holds (`WorldStateID` not 0):
  five "Altar of the Blood Loa" event objectives in Stranglethorn Vale and the
  four Eastern Plaguelands towers. Left out (ruling 2), leaving **198**.
- Zone: **141** resolve through `AreaID` climbed up `AreaTable.ParentAreaID`,
  **52** through an `AreaTable` row bearing the town's own name (their
  `AreaID` is 0 or -1), **0** through the rectangle rule, and **5** are
  unplaced and skipped: Dun Algaz (in Dun Morogh's and the Wetlands'
  rectangles, and its name rows climb to three different zones), Stormwind and
  The Undercity (both are flight stops anyway), Scholomance and Ivar's Patch.
  None falls outside its zone's map.
- Duplicates dropped: **42** share a name (Search's plain rule, a leading
  "The" ignored) and a zone with a flight stop, from Aerie Peak to Zoram'gar
  Outpost; **1** more is a second label for the same place (Aldrassil, two
  POIs 18 yards apart). That leaves **150** towns in `Towns.lua`.
- Faction: **13** Alliance, **15** Horde, **122** none. Nine towns have
  flight masters of both factions within 600 yards and so get none (Browman
  Mill, Janeiro's Point, The Ruins of Kel'Theril, Moon Horror Den, Shrine of
  Remulos, Stormrage Barrow Dens, The Swarming Pillar, Bones of Grakkarond,
  Twilight Base Camp). The one capital that survives is Darnassus: Alliance,
  from Rut'theran Village 1926 yards away.
- In Search, nine generated towns give way to a hand-written `Data/Inns.lua`
  row of their name: the six inn towns (Razor Hill, Bloodhoof Village, Brill,
  Goldshire, Kharanos, Dolanaar, each 36 to 84 yards from its POI and in the
  same zone) and Grom'gol Base Camp, Theramore Isle and Feathermoon Stronghold
  (53, 193 and 87 yards from the stops their inn rows already name). Each
  faction is then offered **212** candidates: **63** stops (71 less the eight
  enemy twins), **147** towns and **2** zones.
- The fallback-zone list shrinks from "Alterac Mountains, Darnassus, Deadwind
  Pass, Shen'dralas" to **"Alterac Mountains, Shen'dralas"**.
- **The POI world axes are TaxiNodes' own.** `AreaPOI.Pos_0`/`Pos_1` go into
  the same `world_to_map` as `TaxiNodes.Pos_0`/`Pos_1`: Thunder Bluff's label
  (-1205.4, 29.4) is 8 yards from its flight master (-1197.2, 29.7), Refuge
  Pointe's 16 and Stonard's 13. Swapped axes would put Thunder Bluff's label
  some 1700 yards away. Re-running the generator leaves `Places.lua`,
  `Nodes.lua` and `Flights.lua` byte-for-byte the same (line endings aside).

## Rulings this plan makes (the spec left these open, or the data forced them)

Record each in the ledger for the owner.

1. **Zone resolution gains a middle step, and the rectangle decides only when
   it is certain.** The spec says AreaID first, then the generator's
   `_zone_for`. Measured, 63 of the 207 carry no usable AreaID, and
   `_zone_for`'s smallest-rectangle guess put ten of those that share a name
   with a flight stop in a different zone from that stop (The Crossroads in
   Durotar, Astranaar in Stonetalon Mountains, Auberdine in Felwood,
   Darkshire in Deadwind Pass, Camp Taurajo in Dustwallow Marsh...). A town's
   name carries no ", Zone" the way a flight stop's does, so the name step of
   `_zone_for` never fires for it. So: AreaID; then the `AreaTable` rows
   bearing the town's own name, when they all climb to one zone; then a zone
   rectangle only when exactly one holds the point. Otherwise the town is
   reported unplaced and skipped, as the spec says. `_zone_for` is unchanged
   and still places flight stops.
2. **A label shown only while a world state holds is left out**, like the shop
   signs and battleground markers the spec already leaves out. Otherwise the
   list offers "Altar of the Blood Loa" five times.
3. **A duplicate is a same name in the same zone, at any distance, not
   "within 300 yards".** Every same-named town and stop is within 199 yards
   except two capitals: Ironforge's label is 378 yards from its flight master
   and Orgrimmar's 301, so the 300-yard rule would offer each twice. The rule
   is applied where both sides are known: towns against flight stops (and
   against each other, lower ID kept) in the generator, towns against inn rows
   in `Search.Candidates`.
4. **Every hand-written `Data/Inns.lua` row wins by name over a generated
   town**, whatever kind of row it is. An inn town wins as the spec says; a
   `stop =` row says the name is that stop, so "Theramore Isle" is not offered
   beside the Theramore stop. The inn rows' positions are **not** replaced by
   the towns' (the spec says "may"): an inn row is where the hearthstone lands,
   and each is within 84 yards of its town. The inn-list guard test now
   compares against the data without inns and without towns: a row that
   names a generated town still earns its place.
5. **Faction.** "A flight master of a single faction" is a `Nodes` row whose
   `f` is `A` or `H`; neutral ones do not count; one of each within 600 yards
   means none. "Capitals take their known faction from their own flight
   stop" becomes: a capital takes the faction of the nearest one-faction
   flight master on its continent. For five capitals that is their own stop
   (and they are dropped as duplicates anyway); for Darnassus, which has none
   in its zone, it is Rut'theran Village.
6. **An enemy stop is hidden by short name alone**, as the spec words it: all
   eight pairs share a zone too (Booty Bay, Gadgetzan, Everlook, Moonglade,
   Nighthaven, Light's Hope Chapel, Cenarion Hold, Thorium Point).
7. **The footer has a slot measured for it**, not the last row's. `FOOTER` is
   14 px (one 10 px line), and `fit` is counted with it kept free:
   (109.69 - 4 - 14) / 18 still floors to 5, so the list shows five rows as
   today. The rows end 92 px down; the footer's top is at 93.69 px.
8. **`Search.Find` with no limit returns every match** (it stopped at 8).
   Every caller that passes a limit is unchanged.
9. **The zone browser counts what this faction is offered in each zone**
   (`Search.Candidates`), so a fallback zone counts its own "(zone)" row, 1.
   A zone row is kind `"browse"`. Clicking one, or Enter with one on top, puts
   the zone's name in the box, takes focus, and lists that zone's places; it
   never plans and never goes in the recents. The browser's labels are
   measured for the drop-down's width too.
10. **Two same-named towns order by `townID`** (the two ends of Timbermaw Hold
    and of The Talondeep Path), so the list's order is fixed.
11. **The spec's real-data check "no two offered candidates share a name
    within 300 yd" is kept in a stronger form:** no two offered rows share a
    name and a zone, at any distance. Name alone within 300 yards would fail
    on Timbermaw Hold, whose two ends are 217 yards apart in Felwood and
    Winterspring: two places, two different rows.
12. **`test_crossings`'s "leaves a city by its gate" routes to Sentinel Hill by
    name.** "Westfall" alone now finds Moonbrook first (alphabetical, rank 3),
    and the test is about the gate.

## File map

- Modify `tools/build_graph.py`: fetch `AreaPOI` and `AreaTable`; `plain`,
  `_zones_by_name`, `_area_zone`, `_town_zone`, `_town_faction`,
  `build_towns`; `main` emits `Towns`.
- Create `test/tools/fixtures/AreaPOI.csv`, `test/tools/fixtures/AreaTable.csv`.
- Modify `test/tools/test_build_graph.py`: a `Towns` test class.
- Create `GoblinPS/Data/Towns.lua` (generated by Task 2, never by hand).
- Modify `GoblinPS/GoblinPS.toc`: load `Data\Towns.lua`; version.
- Modify `test/run.lua`: load `Towns`.
- Modify `GoblinPS/Search.lua`: `fromTown`, `plain` moved up, `Search.Candidates`
  (towns, enemy twins, inn rows win), `before` (townID), `Search.Find` (every
  match), `Search.Zones`.
- Modify `GoblinPS/Data/Inns.lua`: header comment only.
- Modify `GoblinPS/Planner.lua`: `FOOTER`, `candidates`, `rowLabel`,
  `drawResults`, `scrollResults`, `showResults`, `browse`, `pick` (moved),
  Enter, `fit`, the wheel and footer in `build()`, the measured width.
- Modify `test/fake_frames.lua`: `EnableMouseWheel`, `Fake.Wheel`.
- Modify `test/test_search.lua`, `test/test_data.lua`, `test/test_crossings.lua`,
  `test/test_ui.lua`.
- Docs: `docs/manual-test-checklist.md`, `docs/later.md`, `CLAUDE.md`,
  `docs/research/2026-09-19-api-and-data-findings.md`, the spec's status.

Untouched: routing, `Strip.lua`, `Dash.lua`, `Settings.lua`, art, geometry,
`Places.lua`, `Nodes.lua`, `Flights.lua` (regenerated identical).

---

### Task 1: the generator emits the towns table

**Files:**
- Modify: `tools/build_graph.py` (imports, `TABLES`, `REQUIRED_COLUMNS`,
  constants, six new functions after `build_nodes`, `main`)
- Create: `test/tools/fixtures/AreaPOI.csv`, `test/tools/fixtures/AreaTable.csv`
- Modify: `test/tools/test_build_graph.py` (a `Towns` class before `Emit`)

**Interfaces:**
- Consumes: the existing `load_tables`, `build_places` (rows `{ name, c, x0,
  y0, x1, y1, ax, ay }` keyed by UiMap), `build_nodes` (rows `{ name, f, c, x,
  y, map, mx, my, ax, ay }` keyed by node ID, `f` in `A`/`H`/`N`),
  `world_to_map(assignments, uimap_id: str, map_id: str, wx, wy) -> (x, y) |
  None`, `index_assignments`, `emit`.
- Produces: `bg.plain(name) -> str`; `bg._zones_by_name(places) ->
  {(name, c): map}`; `bg._town_zone(places, areas, area_names, zones, poi) ->
  (map | None, "area" | "name" | "rectangle" | "unplaced")`;
  `bg._town_faction(nodes, town, capital: bool) -> "A" | "H" | None`;
  `bg.build_towns(tables, places, nodes) -> {poi_id: {name, map, mx, my, c,
  x, y[, f]}}`. Task 2 runs `main`, which writes `GoblinPS/Data/Towns.lua` as
  `ns.Data.Towns = { [id] = { c, f?, map, mx, my, name, x, y }, ... }`.

The fixture world (already in `test/tools/fixtures`) is Kalimdor with Durotar
(1411, x -2000..2000, y -5000..-2000), The Barrens (1413, x -4000..2000,
y -5000..0), Orgrimmar (1454) and Camp Taurajo (1500, x and y -1000..1000),
and three stops: Orgrimmar (23, Horde, 1600, -4400), Crossroads (25, Horde,
-400, -2600, in The Barrens) and Ratchet (80, neutral). Durotar's rectangle
lies inside The Barrens', so a point in Durotar is in both.

- [ ] **Step 1: Write the fixtures**

Create `test/tools/fixtures/AreaPOI.csv`:

```
Name_lang,Description_lang,ID,Pos_0,Pos_1,Pos_2,ContinentID,AreaID,WorldStateID,Icon
"Razor Hill",,31,-1500,-4500,0,1,362,0,6
"The Crossroads",,34,-420,-2580,0,1,380,0,4
"Far Watch Post",,36,-800,-2300,0,1,0,0,6
"Valley Gate",,37,1500,-3900,0,1,363,0,6
"Dun Baldar",,59,0,0,0,30,0,0,6
"Lost Camp",,900,0,-3500,0,1,-1,0,6
"Twin Rocks",,910,-3000,-1200,0,1,-1,0,6
"Twin Rocks",,911,-3010,-1210,0,1,-1,0,4
"Taurajo Keep",,950,0,500,0,1,-1,0,5
"Stray Post",,960,-3500,-2500,0,1,362,0,6
"Wailing Caverns",,1068,-3500,-1000,0,1,718,0,6
"Goblin Shop",,1200,-3500,-1000,0,1,0,0,9
"Blood Altar",,7713,-3600,-1100,0,1,-1,25764,6
```

Create `test/tools/fixtures/AreaTable.csv`:

```
ID,ZoneName,AreaName_lang,ContinentID,ParentAreaID
10,FarWatchPost,"Far Watch Post",1,17
14,Durotar,Durotar,1,0
17,Barrens,"The Barrens",1,0
362,RazorHill,"Razor Hill",1,14
363,ValleyGate,"Valley Gate",1,14
380,Crossroads,"The Crossroads",1,17
718,WailingCaverns,"Wailing Caverns",1,0
```

What each row is for: 31 and 37 place by AreaID (31 sits in both
rectangles); 36 has AreaID 0 and places by its own name, where the smallest
rectangle (Durotar) would be wrong, and is 500 yards from Crossroads; 37 is
510 yards from Orgrimmar's stop but in another zone; 34 is the Crossroads stop
("The" dropped, same zone); 59 is on continent 30; 900 is in two rectangles
with nothing else to go on; 910 and 911 are one place labelled twice; 950 is a
capital with no stop in its zone; 960's AreaID says Durotar but it stands west
of Durotar's rectangle; 1068's AreaID climbs to no zone and only The Barrens
holds it; 1200 is a shop sign; 7713 shows only while a world state holds.

- [ ] **Step 2: Write the failing tests**

In `test/tools/test_build_graph.py`, add this class directly before
`class Emit(unittest.TestCase):`

```python
class Towns(unittest.TestCase):
    def setUp(self):
        self.tables = bg.load_tables(FIXTURES)
        self.log = io.StringIO()
        with contextlib.redirect_stderr(self.log):
            self.places = bg.build_places(self.tables)
            self.nodes = bg.build_nodes(self.tables, self.places)
            self.towns = bg.build_towns(self.tables, self.places, self.nodes)

    def zone(self, poi_id):
        areas = {a["ID"]: a for a in self.tables["AreaTable"]}
        names = {}
        for a in self.tables["AreaTable"]:
            names.setdefault((a["AreaName_lang"], a["ContinentID"]), []).append(a["ID"])
        poi = next(p for p in self.tables["AreaPOI"] if p["ID"] == str(poi_id))
        return bg._town_zone(self.places, areas, names, bg._zones_by_name(self.places), poi)

    def test_keeps_town_icons_on_the_two_continents_and_no_event_markers(self):
        # 59 is on continent 30, 1200 is a shop sign (icon 9), 7713 shows only while a
        # world state holds; 34 and 911 are duplicates, 900 is unplaced, 960 is off its map.
        self.assertEqual(sorted(self.towns), [31, 36, 37, 910, 950, 1068])

    def test_the_zone_comes_from_the_area_id_first(self):
        # Razor Hill sits inside both the Durotar and the Barrens rectangles.
        self.assertEqual(self.zone(31), (1411, "area"))
        self.assertEqual(self.towns[31]["map"], 1411)
        self.assertEqual(self.zone(37), (1411, "area"))

    def test_then_from_an_area_row_that_bears_the_towns_name(self):
        # AreaID 0; the smallest rectangle holding it is Durotar, which is wrong.
        self.assertEqual(self.zone(36), (1413, "name"))

    def test_then_from_a_rectangle_but_only_when_one_zone_holds_the_town(self):
        # Wailing Caverns' AreaID climbs to no zone; only The Barrens holds the point.
        self.assertEqual(self.zone(1068), (1413, "rectangle"))
        self.assertEqual(self.zone(950), (1500, "rectangle"))

    def test_reports_and_skips_a_town_no_zone_holds_for_certain(self):
        self.assertEqual(self.zone(900), (None, "unplaced"))
        self.assertNotIn(900, self.towns)
        self.assertIn("skip town 900 Lost Camp: no zone holds it for certain", self.log.getvalue())

    def test_skips_a_town_outside_its_own_zones_map(self):
        # Its AreaID says Durotar, but it stands west of Durotar's rectangle.
        self.assertEqual(self.zone(960), (1411, "area"))
        self.assertNotIn(960, self.towns)
        self.assertIn("skip town 960 Stray Post: outside Durotar's map", self.log.getvalue())

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

    def test_drops_a_town_that_is_a_flight_stop_in_the_same_zone(self):
        # "The Crossroads" is the Crossroads stop once "The" is dropped.
        self.assertNotIn(34, self.towns)

    def test_keeps_the_lower_id_of_two_towns_with_one_name_in_one_zone(self):
        self.assertIn(910, self.towns)
        self.assertNotIn(911, self.towns)

    def test_rows_carry_every_field(self):
        self.assertEqual(self.towns[36], {"name": "Far Watch Post", "map": 1413, "mx": 0.46, "my": 0.4667,
                                          "c": 1, "x": -800, "y": -2300, "f": "H"})
        for town in self.towns.values():
            self.assertEqual(set(town) - {"f"}, {"name", "map", "mx", "my", "c", "x", "y"})

    def test_plain_matches_search_lua(self):
        self.assertEqual(bg.plain("The Crossroads"), "crossroads")
        self.assertEqual(bg.plain("Theramore Isle"), "theramore isle")
```

Far Watch Post's map position, worked by hand: The Barrens' map x is
(y1 - wy) / (y1 - y0) = 2300 / 5000 = 0.46, and map y is (x1 - wx) / (x1 - x0)
= 2800 / 6000 = 0.4667 to four places.

- [ ] **Step 3: Run the Python gate to see them fail**

Run: `python -m unittest discover -s test/tools`
Expected: `Ran 70 tests`, `FAILED (errors=14)`: every `Towns` test errors in
`setUp` with `AttributeError: module 'build_graph' has no attribute
'build_towns'`. The other 56 still pass (the loader ignores the two new CSVs
until `TABLES` names them).

- [ ] **Step 4: Write the generator code in `tools/build_graph.py`**

Add `import re` between `import math` and `import sys`.

Replace the `TABLES` line with:

```python
TABLES = ["TaxiNodes", "TaxiPath", "TaxiPathNode", "UiMap", "UiMapAssignment", "AreaPOI", "AreaTable"]
```

In `REQUIRED_COLUMNS`, after the `"UiMapAssignment": [...]` entry, add:

```python
    "AreaPOI": ["ID", "Name_lang", "Pos_0", "Pos_1", "ContinentID", "AreaID", "Icon", "WorldStateID"],
    "AreaTable": ["ID", "AreaName_lang", "ContinentID", "ParentAreaID"],
```

After the `FLIGHT_YARDS_PER_SECOND = 32.0 ...` line, add:

```python
# AreaPOI.Icon for a named place on the world map: 4 a town, 5 a capital, 6 a village or
# outpost. Every other icon is a shop sign or a battleground marker.
TOWN_ICONS = {"4", "5", "6"}
CAPITAL_ICON = "5"
FACTION_YARDS = 600.0  # a town takes the faction of a one-faction flight master this close
```

Directly after `build_nodes` (before `def _path_lengths(tables)`), add:

```python
def plain(name: str) -> str:
    """Search.lua's own rule for a name: case folded, a leading "The" dropped."""
    return re.sub(r"^the\s+", "", name.lower())


def _zones_by_name(places) -> dict[tuple[str, int], int]:
    """(zone name, continent) -> UiMap, for the zones whose name is not shared on a continent."""
    seen: dict[tuple[str, int], list[int]] = {}
    for map_id, p in places.items():
        seen.setdefault((p["name"], p["c"]), []).append(map_id)
    return {key: ids[0] for key, ids in seen.items() if len(ids) == 1}


def _area_zone(areas, zones, area_id: str, continent: int) -> int | None:
    """Climb AreaTable.ParentAreaID to the top area and name the zone in Places it is."""
    row, seen = areas.get(area_id), set()
    while row is not None and row["ParentAreaID"] != "0" and row["ID"] not in seen:
        seen.add(row["ID"])
        row = areas.get(row["ParentAreaID"])
    return zones.get((row["AreaName_lang"], continent)) if row is not None else None


def _town_zone(places, areas, area_names, zones, poi) -> tuple[int | None, str]:
    """The UiMap a town is in, and how it was found: "area", "name", "rectangle" or "unplaced".

    Zone rectangles overlap, so the rectangle comes last. First the POI's own AreaID,
    climbed to its zone. Many POIs carry none (0 or -1), so next the AreaTable rows that
    bear the town's own name, when they all climb to one zone. Last a zone rectangle, but
    only when exactly one holds the point: where several do, the smallest is a guess, and
    for a town (whose name carries no ", Zone" the way a flight stop's does) a wrong one.
    """
    continent, wx, wy = int(poi["ContinentID"]), float(poi["Pos_0"]), float(poi["Pos_1"])
    if int(poi["AreaID"]) > 0:
        zone = _area_zone(areas, zones, poi["AreaID"], continent)
        if zone is not None:
            return zone, "area"
    rows = area_names.get((poi["Name_lang"], poi["ContinentID"]), ())
    named = {_area_zone(areas, zones, i, continent) for i in rows}
    if len(named) == 1 and None not in named:
        return named.pop(), "name"
    inside = [m for m, p in places.items()
              if p["c"] == continent and p["x0"] <= wx <= p["x1"] and p["y0"] <= wy <= p["y1"]]
    if len(inside) == 1:
        return inside[0], "rectangle"
    return None, "unplaced"


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


def build_towns(tables, places, nodes) -> dict[int, dict]:
    """Every named town on the two continents' world maps (AreaPOI), in its zone.

    A town that shares its name (Search's plain rule) and its zone with a flight stop is
    that stop, and is left out: the stop wins. Two towns that share both are one place
    labelled twice (Aldrassil is), and the lower ID is kept. A label shown only while a
    world state holds (an event's objective, a PvP tower) is not a place, and is left out.
    """
    assignments = index_assignments(tables)
    areas = {a["ID"]: a for a in tables["AreaTable"]}
    area_names: dict[tuple[str, str], list[str]] = {}
    for a in tables["AreaTable"]:
        area_names.setdefault((a["AreaName_lang"], a["ContinentID"]), []).append(a["ID"])
    zones = _zones_by_name(places)
    taken = {(plain(n["name"].split(",")[0].strip()), n["map"]) for n in nodes.values()}
    towns = {}
    for poi in sorted(tables["AreaPOI"], key=lambda p: int(p["ID"])):
        if poi["ContinentID"] not in CONTINENTS or poi["Icon"] not in TOWN_ICONS or poi["WorldStateID"] != "0":
            continue
        map_id, how = _town_zone(places, areas, area_names, zones, poi)
        if map_id is None:
            print(f"skip town {poi['ID']} {poi['Name_lang']}: no zone holds it for certain", file=sys.stderr)
            continue
        wx, wy = float(poi["Pos_0"]), float(poi["Pos_1"])
        spot = world_to_map(assignments, str(map_id), poi["ContinentID"], wx, wy)
        if spot is None:
            print(f"skip town {poi['ID']} {poi['Name_lang']}: outside {places[map_id]['name']}'s map", file=sys.stderr)
            continue
        if (plain(poi["Name_lang"]), map_id) in taken:
            continue
        taken.add((plain(poi["Name_lang"]), map_id))
        mx, my = spot
        town = {"name": poi["Name_lang"], "map": map_id, "mx": mx, "my": my,
                "c": int(poi["ContinentID"]), "x": round(wx, 1), "y": round(wy, 1)}
        faction = _town_faction(nodes, town, poi["Icon"] == CAPITAL_ICON)
        if faction:
            town["f"] = faction
        towns[int(poi["ID"])] = town
    return towns
```

In `main`, after `flights = build_flights(tables, nodes)`, add
`towns = build_towns(tables, places, nodes)`; after
`emit(out, build, "Flights", flights)`, add `emit(out, build, "Towns", towns)`;
and change the closing print to:

```python
    print(f"{len(places)} places, {len(nodes)} nodes, {len(flights)} flights, {len(towns)} towns", file=sys.stderr)
```

- [ ] **Step 5: Run every gate**

Python: `Ran 70 tests`, `OK` (56 + 14). Lua still `443 passed, 0 failed`;
art green; luacheck and the language server from PowerShell: zero warnings.
Do **not** run the generator yet: Task 2 does, and commits what it writes.

- [ ] **Step 6: Commit**

```
git add tools/build_graph.py test/tools/test_build_graph.py test/tools/fixtures/AreaPOI.csv test/tools/fixtures/AreaTable.csv
git commit -m "Generator: every named town from AreaPOI, in its zone" -m "build_towns places each town by its AreaID, then by an AreaTable row bearing its own name, then by a zone rectangle only when exactly one holds it; anything else is reported and skipped. A town takes the faction of one-faction flight masters within 600 yards in its zone, a capital the nearest one's. A town that is a flight stop (same name, same zone) or a second label for another town is dropped, and event labels are left out." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: generate `Data/Towns.lua` and load it

**Files:**
- Create: `GoblinPS/Data/Towns.lua` (by running the generator; never by hand)
- Modify: `GoblinPS/GoblinPS.toc` (add `Data\Towns.lua` after `Data\Flights.lua`)
- Modify: `test/run.lua` (module list)
- Modify: `test/test_data.lua` (a "the towns table" block)

**Interfaces:**
- Consumes: Task 1's `main`.
- Produces: `ns.Data.Towns = { [poi_id] = { name, map, mx, my, c, x, y, f? } }`,
  150 rows, loaded in the client (TOC) and in `test/run.lua`'s shared `ns`.
  Search does not read it until Task 3.

- [ ] **Step 1: Write the failing tests**

In `test/test_data.lua`, directly before `h.describe("a real route", function()`,
add:

```lua
    h.describe("the towns table", function()
        local towns, count = data.Towns, 0
        for _ in pairs(towns or {}) do
            count = count + 1
        end

        h.it("loads, generated from the game's AreaPOI table", function()
            h.eq(count, 150, "207 on the two continents with a town icon; 9 event markers, 5 unplaced, 43 duplicates")
        end)
        h.it("puts every town inside its own zone's rectangle, with every field", function()
            for id, t in pairs(towns) do
                local p = data.Places[t.map]
                h.truthy(p, "town " .. id .. " " .. tostring(t.name) .. " has no zone")
                h.eq(t.c, p.c, t.name .. " is on its zone's continent")
                h.truthy(p.x0 <= t.x and t.x <= p.x1 and p.y0 <= t.y and t.y <= p.y1,
                         t.name .. " lies outside " .. p.name)
                h.truthy(t.mx >= 0 and t.mx <= 1 and t.my >= 0 and t.my <= 1, t.name .. " map coords")
                local c, x, y = ns.Geo.ToWorld(data.Places, t.map, t.mx, t.my)
                h.truthy(c == t.c and math.abs(x - t.x) < 10 and math.abs(y - t.y) < 10,
                         t.name .. ": its map coords and world coords are one point")
                h.truthy(t.f == nil or t.f == "A" or t.f == "H", t.name .. " faction")
            end
        end)
        h.it("never repeats a flight stop in the stop's own zone", function()
            local stops = {}
            for _, n in pairs(data.Nodes) do
                stops[ns.Search.ShortName(n.name):lower():gsub("^the%s+", "") .. "@" .. n.map] = true
            end
            for _, t in pairs(towns) do
                h.falsy(stops[t.name:lower():gsub("^the%s+", "") .. "@" .. t.map], t.name .. " is a flight stop")
            end
        end)
    end)

```

- [ ] **Step 2: Run the Lua gate to see them fail**

Expected: `443 passed, 3 failed`: the three new tests, since `data.Towns` is
nil (the count is 0 and `pairs(nil)` raises).

- [ ] **Step 3: Run the generator**

Run: `python tools/build_graph.py`
Expected stderr: two `fetch https://wago.tools/db2/AreaPOI/csv?build=1.60.1.69913`
and `.../AreaTable/csv?...` lines (the other five tables are already in
`tools/cache/1.60.1.69913`, which git ignores), the six existing `skip zone`
lines, exactly these five:

```
skip town 5 Dun Algaz: no zone holds it for certain
skip town 16 Stormwind: no zone holds it for certain
skip town 18 The Undercity: no zone holds it for certain
skip town 710 Scholomance: no zone holds it for certain
skip town 1702 Ivar's Patch: no zone holds it for certain
```

and the summary `49 places, 71 nodes, 292 flights, 150 towns`.

Then `git status --short` must show `?? GoblinPS/Data/Towns.lua` and nothing
under `GoblinPS/Data` besides. If it lists `Places.lua`, `Nodes.lua` or
`Flights.lua`, run
`git diff --ignore-cr-at-eol --stat -- GoblinPS/Data/Places.lua GoblinPS/Data/Nodes.lua GoblinPS/Data/Flights.lua`:
it must print nothing (the generator writes LF, the checkout has CRLF); put
them back with `git checkout -- GoblinPS/Data/Places.lua GoblinPS/Data/Nodes.lua GoblinPS/Data/Flights.lua`.
If it prints any line, stop: the generator changed data it must not.

Spot-check `GoblinPS/Data/Towns.lua`: it opens with
`-- Generated by tools/build_graph.py from build 1.60.1.69913. Do not edit.`
and holds, among its 150 rows,

```
    [9]={c=0,map=1426,mx=0.4638,my=0.5205,name="Kharanos",x=-5586,y=-482.1},
    [12]={c=0,map=1436,mx=0.4304,my=0.693,name="Moonbrook",x=-11017.1,y=1510.2},
    [38]={c=1,f="A",map=1457,mx=0.6462,my=0.4061,name="Darnassus",x=9951.8,y=2254.5},
```

and no row named Sentinel Hill, The Crossroads, Orgrimmar or Ironforge (each
is its flight stop).

- [ ] **Step 4: Load it**

In `GoblinPS/GoblinPS.toc`, add `Data\Towns.lua` on its own line directly
after `Data\Flights.lua`.

In `test/run.lua`, add `{ "Towns",   "GoblinPS/Data/Towns.lua" },` to
`modules` directly after the `Links` row.

- [ ] **Step 5: Run every gate**

Lua: `446 passed, 0 failed` (443 + 3). Python `Ran 70 tests`, `OK`. Art green.
luacheck and the language server from PowerShell: zero warnings (Towns.lua's
longest line is 103 characters, under the 120 limit, so no exemption).

- [ ] **Step 6: Commit**

```
git add GoblinPS/Data/Towns.lua GoblinPS/GoblinPS.toc test/run.lua test/test_data.lua
git commit -m "Data/Towns.lua: 150 towns generated from the game's own map labels" -m "Run of tools/build_graph.py against build 1.60.1.69913: 207 town-icon labels on the two continents, 9 event markers left out, 141 placed by AreaID and 52 by their own name, 5 unplaced and skipped, 43 duplicates of a flight stop or of each other dropped. Loaded by the TOC and the test runner; Search does not offer them yet." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Search offers towns, and never one place twice

**Files:**
- Modify: `GoblinPS/Search.lua` (header comment, `fromTown`, `plain` moved up,
  `Search.Candidates`, `before`)
- Modify: `GoblinPS/Data/Inns.lua` (header comment only)
- Modify: `test/test_search.lua` (two new blocks)
- Modify: `test/test_data.lua` (the inn guard, the fallback list, one test in
  "the towns table", a "no place offered twice" block)
- Modify: `test/test_crossings.lua` ("leaves a city by its gate")

**Interfaces:**
- Consumes: `ns.Data.Towns` (Task 2) or none (`data.Towns` may be nil: the fake
  world has none).
- Produces: `Search.Candidates(data, faction)` rows gain kind `"town"` rows
  from `data.Towns` with `townID = <poi id>` and `enemy = "A"|"H"|nil` from
  the inferred faction; enemy stops that share a short name with a usable stop
  are gone; a generated town whose plain name is an `Inns` key is gone.
  `before` orders same-named towns by `townID`. Tasks 4 and 5 rely on
  `Search.Candidates` and on the item fields `kind, name, zone, map, enemy,
  townID, nodeID`.

- [ ] **Step 1: Write the failing tests**

In `test/test_search.lua`, directly after the `end)` that closes
`h.describe("Search.Find", ...)` and before `h.describe("Search.Candidates", ...)`,
add:

```lua
    h.describe("generated towns", function()
        -- The fake world with a towns table shaped as tools/build_graph.py
        -- emits Data/Towns.lua. Map coords and world coords are one point.
        local function withTowns()
            local w = dofile("test/fake_world.lua")()
            w.Towns = {
                [101] = { name = "Mike", map = 1, mx = 0.3, my = 0.3, c = 1, x = 7000, y = 7000 },
                [102] = { name = "November", map = 4, mx = 0.6, my = 0.6, c = 1, x = 4000, y = 4000, f = "A" },
                -- The game's own label for the hand-written inn town, 100 yards off it.
                [103] = { name = "Quiet Hollow", map = 1, mx = 0.26, my = 0.5, c = 1, x = 5000, y = 7400 },
                -- In Lostland, which held nothing until now.
                [104] = { name = "Oscar", map = 5, mx = 0.5, my = 0.5, c = 1, x = 5000, y = 5000, f = "H" },
            }
            return w
        end

        h.it("offers a town as a place of kind town, in its zone", function()
            local mike = Search.Find(withTowns(), "mike", "H")[1]
            h.eq(mike.kind, "town")
            h.eq(mike.townID, 101)
            h.eq(mike.name, "Mike")
            h.eq(mike.zone, "Westland")
            h.eq(mike.enemy, nil, "a town with no inferred faction is nobody's enemy")
            h.eq(mike.map, 1)
            h.eq(mike.x, 7000)
            h.eq(mike.y, 7000)
        end)
        h.it("marks a town with the other faction's inferred faction", function()
            local w = withTowns()
            h.eq(Search.Find(w, "november", "H")[1].enemy, "A")
            h.eq(Search.Find(w, "november", "A")[1].enemy, nil, "an Alliance town is no enemy to the Alliance")
            h.eq(Search.Find(w, "oscar", "A")[1].enemy, "H")
        end)
        h.it("lets the hand-written inn town win over the game's town of its name", function()
            local found = Search.Find(withTowns(), "quiet", "H")
            h.eq(#found, 1, "one Quiet Hollow, not two")
            h.eq(found[1].townID, nil, "the inn row's")
            h.eq(found[1].y, 7500, "at the inn row's own position")
        end)
        h.it("takes a zone off the list once a town stands in it", function()
            local w = withTowns()
            local count = { stop = 0, town = 0, zone = 0 }
            for _, item in ipairs(Search.Candidates(w, "H")) do
                count[item.kind] = count[item.kind] + 1
            end
            h.eq(count.stop, 8)
            h.eq(count.town, 6, "three inn towns and Mike, November and Oscar")
            h.eq(count.zone, 0, "Oscar stands in Lostland")
            h.eq(Search.Exact(w, "Lostland", "H"), nil)
            h.eq(Search.Exact(w, "Oscar", "H").map, 5)
        end)
    end)

    h.describe("two stops of one name", function()
        -- Booty Bay, Gadgetzan and Everlook each have one stop per faction, a
        -- few yards apart. Kilo is that town. The enemy's stop is on the LOWER
        -- ID, so a tie broken by ID alone would pick the one you cannot use.
        local function withTwins()
            local w = dofile("test/fake_world.lua")()
            w.Nodes[11] = { name = "Kilo, Westland", f = "A", c = 1, x = 3000, y = 3000, map = 1, mx = 0.7, my = 0.7 }
            w.Nodes[12] = { name = "Kilo, Westland", f = "H", c = 1, x = 3010, y = 3010,
                            map = 1, mx = 0.699, my = 0.699 }
            return w
        end

        h.it("offers only the stop this faction may use", function()
            local w = withTwins()
            local horde = Search.Find(w, "kilo", "H")
            h.eq(#horde, 1, "the Alliance's Kilo is not offered to the Horde")
            h.eq(horde[1].nodeID, 12)
            h.eq(horde[1].enemy, nil)
            local alliance = Search.Find(w, "kilo", "A")
            h.eq(#alliance, 1)
            h.eq(alliance[1].nodeID, 11)
        end)
        h.it("still offers an enemy stop that has no twin of your own", function()
            local echo = Search.Find(withTwins(), "echo", "H")
            h.eq(#echo, 1)
            h.eq(echo[1].enemy, "A")
        end)
        h.it("pins the tie: the stop you may use wins, though the enemy's ID is lower", function()
            local w = withTwins()
            h.eq(Search.Exact(w, "Kilo", "H").nodeID, 12)
            h.eq(Search.Exact(w, "Kilo", "A").nodeID, 11)
            local any = Search.Find(w, "kilo")
            h.eq(#any, 2, "with no faction, neither is an enemy, so both are offered")
            h.eq(any[1].nodeID, 11, "and the lower ID comes first")
            h.eq(Search.Exact(w, "Kilo").nodeID, 11)
        end)
    end)

```

In `test/test_data.lua`:

1. In "only lists names Search cannot already find", replace

```lua
        h.it("only lists names Search cannot already find", function()
            local without = {}
            for k, v in pairs(data) do
                without[k] = v
            end
            without.Inns = nil
```

with

```lua
        h.it("only lists names Search cannot already find", function()
            -- Without the generated towns too: a row that names one of them
            -- still earns its place, because hand-written data wins -- it
            -- says what the name is ("Theramore Isle" is the Theramore stop,
            -- "Kharanos" the inn town) and keeps the town from being offered
            -- a second time.
            local without = {}
            for k, v in pairs(data) do
                without[k] = v
            end
            without.Inns, without.Towns = nil, nil
```

2. Change the fallback-zone expectation
`h.eq(table.concat(zones, ", "), "Alterac Mountains, Darnassus, Deadwind Pass, Shen'dralas")`
to `h.eq(table.concat(zones, ", "), "Alterac Mountains, Shen'dralas")`.

3. At the end of `h.describe("the towns table", ...)` (Task 2's block, after
"never repeats a flight stop in the stop's own zone"), add:

```lua
        h.it("makes Darnassus, Kharanos and Sentinel Hill places, not zones", function()
            for _, name in ipairs({ "Darnassus", "Kharanos", "Sentinel Hill" }) do
                for _, faction in ipairs({ "A", "H" }) do
                    local place = ns.Search.Exact(data, name, faction)
                    h.truthy(place, name .. " cannot be found by the " .. faction)
                    h.truthy(place.kind ~= "zone", name .. " is still only a zone")
                end
            end
            h.eq(ns.Search.Exact(data, "Darnassus", "H").enemy, "A", "a capital takes its own flight stop's faction")
            h.eq(ns.Search.Exact(data, "Sentinel Hill", "H").nodeID, 4, "the stop, not a town beside it")
        end)
```

4. Directly before `h.describe("a real route", function()`, add:

```lua
    h.describe("no place offered twice", function()
        -- Stronger than "no two of one name within 300 yards": two rows with
        -- one name and one zone would read the same at any distance. The two
        -- ends of a tunnel share a name 217 yards apart (Timbermaw Hold) but
        -- not a zone, and are two places.
        h.it("never offers two rows that read the same", function()
            for _, faction in ipairs({ "A", "H" }) do
                local seen, rows = {}, 0
                for _, item in ipairs(ns.Search.Candidates(data, faction)) do
                    local label = item.name .. " @ " .. tostring(item.zone)
                    h.falsy(seen[label], faction .. ": " .. label .. " is offered twice")
                    seen[label] = true
                    rows = rows + 1
                end
                h.truthy(rows > 200, "a check that saw no rows proves nothing")
            end
        end)
        h.it("hides the other faction's stop where one of your own has its name", function()
            for _, name in ipairs({ "Booty Bay", "Gadgetzan", "Everlook" }) do
                local found = ns.Search.Find(data, name, "H")
                h.eq(found[1].name, name)
                h.eq(found[1].enemy, nil, name .. ": the Horde's own stop")
                h.truthy(not found[2] or found[2].name ~= name, name .. " is offered twice to the Horde")
            end
        end)
    end)

```

In `test/test_crossings.lua`, in "leaves a city by its gate", replace

```lua
            local r = ns.Route.Plan(data, { faction = "A", known = {}, from = place("Stormwind City", "A"),
                                            to = place("Westfall", "A") })
```

with

```lua
            -- Sentinel Hill by name: "Westfall" alone now finds Moonbrook first, a
            -- town off the road, and this test is about the gate, not the town.
            local r = ns.Route.Plan(data, { faction = "A", known = {}, from = place("Stormwind City", "A"),
                                            to = place("Sentinel Hill", "A") })
```

- [ ] **Step 2: Run the Lua gate to see them fail**

Expected: `448 passed, 8 failed`. Failing: "offers a town as a place of kind
town, in its zone", "marks a town with the other faction's inferred
faction", "takes a zone off the list once a town stands in it", "offers only
the stop this faction may use", "offers a zone only where it holds no stop and
no inn town, and these are all of them" (still four zones), "makes
Darnassus, Kharanos and Sentinel Hill places, not zones" (Darnassus is a
zone), "never offers two rows that read the same" and "hides the other
faction's stop where one of your own has its name" (Booty Bay twice).
Passing already, and pinned from here on: "lets the hand-written inn town
win" (towns are not read yet), "still offers an enemy stop that has no twin"
and "pins the tie" (`before` already puts a usable stop first). The changed
inn guard and the crossings test pass both ways.

- [ ] **Step 3: `GoblinPS/Search.lua`**

Replace the header comment

```lua
-- Pure lookup of destinations by name: flight stops, inn towns, and a zone
-- only when it holds neither.
```

with

```lua
-- Pure lookup of destinations by name: flight stops, towns (the game's own
-- AreaPOI table, Data/Towns.lua), hand-written inn towns, and a zone only
-- when it holds none of these.
```

Directly after `fromInn`'s closing `end`, add:

```lua
-- A generated town. Its faction is inferred (tools/build_graph.py) and often
-- absent; a town with none is nobody's enemy.
local function fromTown(data, id, t, faction)
    return { kind = "town", townID = id, name = t.name, zone = zoneOf(data, t.map),
             enemy = t.f and not legal(t, faction) and t.f or nil,
             c = t.c, x = t.x, y = t.y, map = t.map, mx = t.mx, my = t.my }
end

-- The game says "The Crossroads" where the flight stop is "Crossroads".
local function plain(name)
    return ((name or ""):lower():gsub("^the%s+", ""))
end
```

and **delete** the same `plain` function (with its comment) from its old place
directly above the `Search.Exact` comment, so it is defined once, above its
first use.

Replace the whole of `Search.Candidates` and the comment above it with:

```lua
-- Every destination the search can offer: every flight stop, the other
-- faction's marked enemy (faction nil means none is), every town and every
-- inn town. A zone is offered only when it holds none of these, so that no
-- zone is out of reach; one that holds a place is only a search word,
-- because a zone destination routes to its border. The planner measures its
-- drop-down over this.
--
-- Two rows are never one place. An enemy stop that shares its name with a
-- stop this faction may use (Booty Bay, Gadgetzan, Everlook) is left out:
-- the usable one is the same town. A generated town whose name is a
-- hand-written inn row's is left out too: the hand-written row says what
-- that name is, whether a stop ("Theramore Isle") or an inn town
-- ("Kharanos"). The generator has already dropped every town that shares a
-- name and a zone with a flight stop.
function Search.Candidates(data, faction)
    local list, held, usable, written = {}, {}, {}, {}
    for _, n in pairs(data.Nodes) do
        if legal(n, faction) then
            usable[Search.ShortName(n.name)] = true
        end
    end
    for id, n in pairs(data.Nodes) do
        if legal(n, faction) or not usable[Search.ShortName(n.name)] then
            list[#list + 1] = fromNode(data, id, n, faction)
        end
    end
    for bind, inn in pairs(data.Inns or {}) do
        written[plain(bind)] = true
        list[#list + 1] = fromInn(data, bind, inn)
    end
    for id, t in pairs(data.Towns or {}) do
        if not written[plain(t.name)] then
            list[#list + 1] = fromTown(data, id, t, faction)
        end
    end
    for _, item in ipairs(list) do
        held[item.map] = true
    end
    for map, p in pairs(data.Places) do
        if not held[map] then
            list[#list + 1] = fromZone(data, map, p)
        end
    end
    return list
end
```

Replace `before` and its comment with:

```lua
-- Which of two same-named places comes first: a place this faction may use,
-- then a stop, then a town, then a zone; among stops the lowest nodeID, among
-- towns the lowest townID (the two ends of a tunnel share a name).
local ORDER = { stop = 1, town = 2, zone = 3 }
local function before(a, b)
    local aEnemy, bEnemy = a.enemy ~= nil, b.enemy ~= nil
    if aEnemy ~= bEnemy then return bEnemy end
    if a.kind ~= b.kind then return ORDER[a.kind] < ORDER[b.kind] end
    return (a.nodeID or a.townID or 0) < (b.nodeID or b.townID or 0)
end
```

- [ ] **Step 4: `GoblinPS/Data/Inns.lua`, the header comment**

Replace

```lua
--                                      A town is also a destination the planner
--                                      offers, as "<name> · <zone>".
```

with

```lua
--                                      A town is also a destination the planner
--                                      offers, as "<name> · <zone>". It wins
--                                      over the game's own town of its name
--                                      (Data/Towns.lua), which is not offered.
```

and after the line `-- Add a row whenever the addon prints "Hearth: unknown inn (...)".`
add:

```lua
-- Every row here wins by name over a generated town: "Theramore Isle" is the
-- Theramore stop, and the game's own Theramore Isle label is not offered too.
```

(No row changes. Their positions stay the inn's own: the hearthstone lands
there, and each is within 84 yards of its town's label.)

- [ ] **Step 5: Run every gate**

Lua: `456 passed, 0 failed` (446 + 7 in `test_search.lua` + 3 in
`test_data.lua`). Python `Ran 70 tests`, `OK`. Art green. luacheck and the
language server from PowerShell: zero warnings.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Search.lua GoblinPS/Data/Inns.lua test/test_search.lua test/test_data.lua test/test_crossings.lua
git commit -m "Search: towns are places, and no place is offered twice" -m "Candidates offers every generated town beside the stops and the inn rows, marked with its inferred faction when that is the other side's. An enemy stop whose name a usable stop shares is not offered, a generated town whose name is a hand-written inn row's gives way to that row, and same-named towns order by ID. Darnassus is a place now; only Alterac Mountains and Shen'dralas are still offered as zones." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: the list scrolls on the wheel, with a footer

**Files:**
- Modify: `GoblinPS/Search.lua` (`Search.Find`: every match when no limit)
- Modify: `GoblinPS/Planner.lua` (`FOOTER`, `candidates`, `drawResults`,
  `scrollResults`, `showResults`, Enter, `fit` in `ApplyLayout`, the wheel and
  footer in `build()`)
- Modify: `test/fake_frames.lua` (`EnableMouseWheel`, `Fake.Wheel`)
- Modify: `test/test_search.lua`, `test/test_ui.lua`

**Interfaces:**
- Consumes: Task 3's `Search.Candidates`; the geometry's `resultsList = {
  left = 0.20625, top = 0.371094, right = 0.88125, bottom = 0.634766 }`
  (109.69 px tall at the planner's 416).
- Produces: `Search.Find(data, text, faction, limit)` returns every match when
  `limit` is nil. On the planner: `ui.results.items` (the full list),
  `ui.results.offset` (0-based index of the top row shown),
  `ui.results.footer` (FontString, 14 px, two bottom anchors),
  `ui.results.fit` (5 at 416 px); the list's `OnMouseWheel(self, delta)`
  script. The fake's `Region:EnableMouseWheel(enable)` sets `mouseWheel`, and
  `Fake.Wheel(frame, delta)` raises unless it is set. Task 5 builds on all of
  these and on `showResults`/`drawResults`.

Numbers: the list is (0.634766 - 0.371094) x 416 = 109.69 px. Rows start
2 px down and are 18 px each; five end at 92 px. The footer's slot is 14 px on
the bottom edge's 2 px inset, so its top is at 109.69 - 2 - 14 = 93.69 px, and
(109.69 - 4 - 14) / 18 = 5.09 still floors to 5 rows. In the fake world
"westland" matches six places (Alpha, Bravo, Charlie, Echo, Juliet, Quiet
Hollow), one more than fits, and "a" matches ten for the Horde.

- [ ] **Step 1: Teach the fake the wheel**

In `test/fake_frames.lua`, directly before the comment
`-- Modelled, not swallowed: the feedback box selects its whole address when`,
add:

```lua
-- Modelled, not swallowed: the client delivers the mouse wheel only to a
-- frame that enabled it, so Fake.Wheel refuses a frame that did not, and a
-- list that forgot the call fails on the desktop instead of lying still in
-- game. Verified present on SimpleScriptRegionAPIDocumentation.lua.
function Region:EnableMouseWheel(enable) self.mouseWheel = enable and true or false end

```

and directly after `function Fake.MouseDown(frame) ... end`, add:

```lua
-- One notch of the wheel over `frame`: 1 up, -1 down, as the client passes it.
function Fake.Wheel(frame, delta)
    assert(frame.mouseWheel, "the client sends no wheel to a frame that did not EnableMouseWheel")
    frame.scripts.OnMouseWheel(frame, delta)
end
```

- [ ] **Step 2: Write the failing tests**

In `test/test_search.lua`, inside `h.describe("Search.Find", ...)`, directly
after "respects the limit", add:

```lua
        h.it("returns every match when no limit is given", function()
            local all = Search.Find(world, "a", "H")
            h.eq(#all, 10, "more than the eight it used to stop at")
            h.eq(#all, #Search.Find(world, "a", "H", 100))
        end)
```

In `test/test_ui.lua`, in "keeps every result row inside the list's box":

1. Replace

```lua
            -- ROW mirrors Planner.lua's private row-height constant (18px);
            -- it has no other home to be read from.
```

with

```lua
            -- ROW mirrors Planner.lua's private row-height constant (18px);
            -- it has no other home to be read from. The footer's slot is
            -- read off the footer, which is given an explicit height.
```

2. Replace

```lua
            -- Real numbers at 416px: (109.69 - 4) / 18 floors to 5.
            h.eq(ui.results.fit, 5, "5 rows fit the 416px-tall window's list")
```

with

```lua
            local footerTop = listHeight - 2 - ui.results.footer:GetHeight()
            -- Real numbers at 416px: (109.69 - 4 - 14) / 18 floors to 5.
            h.eq(ui.results.fit, 5, "5 rows fit the 416px-tall window's list, the footer's slot kept free")
```

3. Replace

```lua
                    h.truthy(bottom <= listHeight,
                              "row " .. i .. " bottom edge must stay inside the list's own height")
```

with

```lua
                    h.truthy(bottom <= footerTop,
                              "row " .. i .. " bottom edge must stay above the footer's slot")
```

Then, directly before `h.describe("the route strip", function()`, add:

```lua
    h.describe("the results list scrolls, and browses zones", function()
        local function open()
            if not Planner.Debug().frame:IsShown() then
                Planner.Toggle()
            end
            return Planner.Debug()
        end
        local function labels(ui)
            local out = {}
            for _, row in ipairs(ui.results.rows) do
                if row:IsShown() then
                    out[#out + 1] = row.label:GetText()
                end
            end
            return table.concat(out, " | ")
        end
        local WESTLAND = { "Alpha · Westland", "Bravo · Westland", "Charlie · Westland",
                           "Echo · Westland (Alliance)", "Juliet · Westland", "Quiet Hollow · Westland" }

        h.it("keeps the footer in its own slot at the bottom of the list, bounded", function()
            local ui = open()
            local footer = ui.results.footer
            h.eq(footer:GetHeight(), 14)
            h.eq(#footer.points, 2, "two horizontal anchors, so it truncates")
            h.eq(footer.points[1][1], "BOTTOMLEFT")
            h.eq(footer.points[1][4], 8, "the label's own inset: row edge 2 plus label edge 6")
            h.eq(footer.points[1][5], 2, "on the list's bottom edge, inside its inset")
            h.eq(footer.points[2][1], "BOTTOMRIGHT")
            h.eq(footer.points[2][4], -8)
            h.eq(footer.points[2][5], 2)
            h.eq(footer.wordWrap, false, "one line")
            h.truthy(footer.points[1][2] == nil and footer.parent == ui.results, "it lives on the list")
        end)

        h.it("shows only what fits, and says where the window is when there is more", function()
            local ui = open()
            Fake.Type(ui.toBox, "westland")
            h.eq(labels(ui), table.concat(WESTLAND, " | ", 1, 5))
            h.truthy(ui.results.footer:IsShown())
            h.eq(ui.results.footer:GetText(), "1-5 of 6")
        end)

        h.it("scrolls one row a notch on the wheel, and clamps at both ends", function()
            local ui = open()
            h.truthy(ui.results.mouseWheel, "the list asked the client for the wheel")
            Fake.Wheel(ui.results, -1)
            h.eq(labels(ui), table.concat(WESTLAND, " | ", 2, 6), "one notch down, one row on")
            h.eq(ui.results.footer:GetText(), "2-6 of 6")
            Fake.Wheel(ui.results, -1)
            h.eq(ui.results.footer:GetText(), "2-6 of 6", "clamped at the bottom")
            h.eq(ui.results.rows[5].label:GetText(), WESTLAND[6])
            Fake.Wheel(ui.results, 1)
            Fake.Wheel(ui.results, 1)
            h.eq(ui.results.footer:GetText(), "1-5 of 6", "clamped at the top")
            h.eq(ui.results.rows[1].label:GetText(), WESTLAND[1])
        end)

        h.it("hides the footer when everything fits", function()
            local ui = open()
            Fake.Type(ui.toBox, "delt")
            h.eq(labels(ui), "Delta · Eastland")
            h.falsy(ui.results.footer:IsShown())
        end)

        h.it("starts again at the top whenever you type", function()
            local ui = open()
            Fake.Type(ui.toBox, "westland")
            Fake.Wheel(ui.results, -1)
            h.eq(ui.results.rows[1].label:GetText(), WESTLAND[2])
            Fake.Type(ui.toBox, "westlan")
            h.eq(ui.results.rows[1].label:GetText(), WESTLAND[1])
            h.eq(ui.results.footer:GetText(), "1-5 of 6")
        end)

        h.it("Enter picks the top row on screen, wherever the wheel left it", function()
            local ui, state = open()
            Fake.Type(ui.toBox, "westland")
            Fake.Wheel(ui.results, -1)
            ui.toBox.scripts.OnEnterPressed(ui.toBox)
            h.eq(state.to.nodeID, 2, "Bravo, the top row shown, not Alpha above it")
            -- put the destination back for the tests that follow
            Fake.Type(ui.toBox, "delt")
            Fake.Click(ui.results.rows[1])
            h.eq(state.to.nodeID, 4)
        end)
    end)

```

- [ ] **Step 3: Run the Lua gate to see them fail**

Expected: `455 passed, 8 failed`: "returns every match when no limit is
given" (8, not 10), "keeps every result row inside the list's box" (no
footer to read), and the six new planner tests (no footer, no wheel).

- [ ] **Step 4: `GoblinPS/Search.lua`, every match**

In `Search.Find`, change the comment's last line
`-- it; alphabetical inside each group.` to
`-- it; alphabetical inside each group. Every match, unless a limit is given.`
and the loop head `for i = 1, math.min(limit or 8, #ranked) do` to
`for i = 1, math.min(limit or #ranked, #ranked) do`.

- [ ] **Step 5: `GoblinPS/Planner.lua`**

After `local ROW_INSET = 2 * ROW_EDGE`, add:

```lua
-- The footer's own slot at the bottom of the list, "6-10 of 23": one line of
-- the rows' small font (GameFontHighlightSmall, 10 px on this build's
-- Fonts.xml) with room for its descenders. The rows that fit are counted
-- with this slot kept free, so the footer never sits on a row.
local FOOTER = 14
```

Replace `candidates` and its comment:

```lua
-- Matches for the text; with an empty box, the recent destinations. Asks for
-- only as many as the list's own box can show (ui.results.fit), not the
-- pool size, so Enter still picks the first of what is actually on screen.
local function candidates()
    local text = ui.toBox:GetText()
    local fit = ui.results.fit or Planner.MAX_RESULTS
    if text ~= "" then
        return ns.Search.Find(ns.Data, text, ns.Core.Faction(), fit)
    end
```

with

```lua
-- Every match for the text, however many: the list shows `fit` of them at a
-- time and the wheel moves over the rest. With an empty box, the recent
-- destinations.
local function candidates()
    local text = ui.toBox:GetText()
    if text ~= "" then
        return ns.Search.Find(ns.Data, text, ns.Core.Faction())
    end
```

(the recents loop and `return out` below it are unchanged).

Directly before `local function showResults()`, add:

```lua
-- Paint the `fit` rows from the list's window onto its items, and the footer
-- when there is more than fits. The window is results.offset, 0 at the top.
local function drawResults()
    local r = ui.results
    local fit = r.fit or Planner.MAX_RESULTS
    local shown = 0
    for i = 1, Planner.MAX_RESULTS do
        local row, item = r.rows[i], (i <= fit) and r.items[r.offset + i] or nil
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            row.label:SetText(rowLabel(item))
            shown = shown + 1
        end
    end
    local more = #r.items > fit
    r.footer:SetText(more and ((r.offset + 1) .. "-" .. (r.offset + shown) .. " of " .. #r.items) or "")
    r.footer:SetShown(more)
end

-- One notch of the wheel moves the window one row, clamped at both ends.
-- delta is the client's: 1 for a notch up, -1 for a notch down.
local function scrollResults(delta)
    local r = ui.results
    local last = math.max(0, #r.items - (r.fit or Planner.MAX_RESULTS))
    r.offset = math.max(0, math.min(last, r.offset - delta))
    drawResults()
end

```

In `showResults`, replace everything after the settings-panel guard (from
`local items = candidates()` to the function's end):

```lua
    local items = candidates()
    if #items == 0 then
        hideResults()
        return
    end
    local fit = ui.results.fit or Planner.MAX_RESULTS
    for i = 1, Planner.MAX_RESULTS do
        local row, item = ui.results.rows[i], (i <= fit) and items[i] or nil
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            row.label:SetText(rowLabel(item))
        end
    end
    ui.results:Show()
end
```

with

```lua
    -- A fresh list always starts at its top: typing resets the window.
    ui.results.items, ui.results.offset = candidates(), 0
    if #ui.results.items == 0 then
        hideResults()
        return
    end
    drawResults()
    ui.results:Show()
end
```

In `wireBox`, the `OnEnterPressed` script's first line
`local first = candidates()[1]` becomes:

```lua
        -- The top row on screen, wherever the wheel has moved the list to.
        local r = ui.results
        local first = r:IsShown() and r.items[r.offset + 1] or candidates()[1]
```

In `ApplyLayout`, replace

```lua
    ui.results.fit = math.max(1, math.min(Planner.MAX_RESULTS, math.floor(
        ((g.resultsList.bottom - g.resultsList.top) * f:GetHeight() - ROW_INSET) / ROW)))
```

with

```lua
    -- The footer's slot is kept free: 109.7 px of list at 416 px tall, less
    -- the insets and the footer, still holds 5 rows.
    ui.results.fit = math.max(1, math.min(Planner.MAX_RESULTS, math.floor(
        ((g.resultsList.bottom - g.resultsList.top) * f:GetHeight() - ROW_INSET - FOOTER) / ROW)))
```

In `build()`, directly after
`results.fit = Planner.MAX_RESULTS -- ApplyLayout narrows this once geometry is known`,
add:

```lua
    results.items, results.offset = {}, 0
    -- The wheel scrolls the list. EnableMouseWheel is present on build
    -- 1.60.1.69913 (SimpleScriptRegionAPIDocumentation.lua) and Blizzard's
    -- own UI sets OnMouseWheel scripts with SetScript; without the enable the
    -- client never delivers the wheel to this frame.
    results:EnableMouseWheel(true)
    results:SetScript("OnMouseWheel", function(_, delta) scrollResults(delta) end)
    -- "6-10 of 23", in its own slot under the rows: bounded by two anchors,
    -- one line, truncated. Hidden when everything fits.
    results.footer = W.Text(results, "dim", nil, "RIGHT")
    results.footer:SetHeight(FOOTER)
    results.footer:SetPoint("BOTTOMLEFT", ROW_EDGE + LABEL_EDGE, ROW_EDGE)
    results.footer:SetPoint("BOTTOMRIGHT", -(ROW_EDGE + LABEL_EDGE), ROW_EDGE)
    results.footer:Hide()
```

(`W.Text` already calls `SetWordWrap(false)`.)

- [ ] **Step 6: Run every gate**

Lua: `463 passed, 0 failed` (456 + 7). Python `Ran 70 tests`, `OK`. Art
green. luacheck and the language server from PowerShell: zero warnings.

- [ ] **Step 7: Commit**

```
git add GoblinPS/Search.lua GoblinPS/Planner.lua test/fake_frames.lua test/test_search.lua test/test_ui.lua
git commit -m "Planner: the results list scrolls on the wheel, with a footer" -m "The search returns every match and the list keeps them all, drawing its five rows from a window one wheel notch moves, clamped at both ends. A footer in its own 14 px slot under the rows reads 1-5 of 6 when there is more than fits, and hides otherwise. Typing starts the window again at the top; Enter picks the top row on screen. The fake models EnableMouseWheel and refuses a wheel a frame did not ask for." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: the zone browser

**Files:**
- Modify: `GoblinPS/Search.lua` (`Search.Zones`)
- Modify: `GoblinPS/Planner.lua` (`candidates`, `rowLabel`, `browse`, `pick`
  moved, the measured width)
- Modify: `test/test_search.lua`, `test/test_ui.lua`

**Interfaces:**
- Consumes: Task 3's `Search.Candidates`; Task 4's `showResults`,
  `ui.results.items`, `ui.results.offset`, `ui.results.footer`, `Fake.Wheel`,
  and the `open`, `labels`, `WESTLAND` helpers in Task 4's test block;
  `EditBox:SetFocus()` (the fake fires `OnEditFocusGained` and sets `focused`).
- Produces: `Search.Zones(data, faction)` -> list sorted by name of
  `{ kind = "browse", name = <zone name>, map = <UiMap>, count = <places> }`.
  With the box empty, `ui.results.items` is the resolved recents followed by
  `Search.Zones`. A `"browse"` row's label is `"<zone> (<count>)"`.

In the fake world the Horde is offered, per zone: Eastland 1 (Delta), Isle 2
(Foxtrot, Golf), Lostland 1 (its own "(zone)" row), Northland 2 (Hotel,
Gatehouse), Westland 6.

- [ ] **Step 1: Write the failing tests**

In `test/test_search.lua`, inside `h.describe("two stops of one name", ...)`
after "pins the tie", add:

```lua
        h.it("is counted once in the zone browser", function()
            for _, zone in ipairs(Search.Zones(withTwins(), "H")) do
                if zone.name == "Westland" then
                    h.eq(zone.count, 7, "six places and one Kilo, not two")
                end
            end
        end)
```

and directly after the `end)` that closes that describe (before
`h.describe("Search.Candidates", ...)`), add:

```lua
    h.describe("Search.Zones", function()
        h.it("lists every zone A to Z with how many places it holds", function()
            local out = {}
            for i, zone in ipairs(Search.Zones(world, "H")) do
                h.eq(zone.kind, "browse", zone.name .. " is a way in, not a destination")
                out[i] = zone.name .. " " .. zone.count
            end
            h.eq(table.concat(out, ", "), "Eastland 1, Isle 2, Lostland 1, Northland 2, Westland 6",
                 "Lostland holds only its own (zone) row")
        end)
    end)

```

In `test/test_ui.lua`, at the end of
`h.describe("the results list scrolls, and browses zones", ...)` (after
"Enter picks the top row on screen, wherever the wheel left it"), add:

```lua

        h.it("with the box empty, lists the recent destinations, then every zone with its count", function()
            local ui = open()
            local saved = GoblinPSDB.recents
            GoblinPSDB.recents = { "Delta", "Juliet" }
            Fake.Type(ui.toBox, "")
            h.eq(labels(ui), "Delta · Eastland | Juliet · Westland | Eastland (1) | Isle (2) | Lostland (1)")
            h.eq(ui.results.footer:GetText(), "1-5 of 7")
            Fake.Wheel(ui.results, -1)
            Fake.Wheel(ui.results, -1)
            h.eq(ui.results.rows[4].label:GetText(), "Northland (2)")
            h.eq(ui.results.rows[5].label:GetText(), "Westland (6)")
            GoblinPSDB.recents = saved
            ui.toBox:SetText("Delta")
            ui.toBox:ClearFocus()
        end)

        h.it("the dropdown opens the same browser", function()
            local ui = open()
            ui.toBox:SetText("")
            Fake.MouseDown(GoblinPSPlanner) -- the list starts put away
            Fake.Click(ui.dropdown)
            h.truthy(ui.results:IsShown())
            local items = ui.results.items
            h.eq(items[1].name, GoblinPSDB.recents[1], "the newest recent first")
            h.truthy(items[1].kind ~= "browse", "a recent is a place")
            h.eq(items[#items].kind, "browse")
            h.eq(items[#items].name, "Westland", "and the last zone, A to Z, at the end")
            ui.toBox:SetText("Delta")
            ui.toBox:ClearFocus()
        end)

        h.it("a zone row fills the box and lists that zone's places, and is never routed to", function()
            local ui, state = open()
            local saved, to, plan = GoblinPSDB.recents, state.to, state.plan
            GoblinPSDB.recents = {} -- the five zones fill the list exactly
            ui.toBox:SetText("")
            ui.toBox.scripts.OnEditFocusGained(ui.toBox)
            h.eq(ui.results.rows[5].label:GetText(), "Westland (6)")
            Fake.Click(ui.results.rows[5])
            h.eq(ui.toBox:GetText(), "Westland", "exactly as typing it would")
            h.truthy(ui.toBox.focused, "the box keeps the search going")
            h.truthy(ui.results:IsShown())
            h.eq(labels(ui), table.concat(WESTLAND, " | ", 1, 5), "the zone's places")
            h.truthy(state.to == to and state.plan == plan, "nothing was planned")
            h.eq(#GoblinPSDB.recents, 0, "and nothing remembered")
            GoblinPSDB.recents = saved
            ui.toBox:SetText("Delta")
            ui.toBox:ClearFocus()
        end)

        h.it("Enter on a zone row at the top browses too, and never routes", function()
            local ui, state = open()
            local saved, to = GoblinPSDB.recents, state.to
            GoblinPSDB.recents = {}
            Fake.Type(ui.toBox, "")
            h.eq(ui.results.rows[1].label:GetText(), "Eastland (1)")
            ui.toBox.scripts.OnEnterPressed(ui.toBox)
            h.eq(ui.toBox:GetText(), "Eastland")
            h.eq(labels(ui), "Delta · Eastland")
            h.truthy(state.to == to, "nothing was planned")
            GoblinPSDB.recents = saved
            ui.toBox:SetText("Delta")
            ui.toBox:ClearFocus()
        end)
```

- [ ] **Step 2: Run the Lua gate to see them fail**

Expected: `463 passed, 6 failed`: the two Search tests (`Search.Zones` is
nil) and the four planner tests (an empty box lists the recents only).

- [ ] **Step 3: `GoblinPS/Search.lua`, `Search.Zones`**

Directly before the comment `-- Which of two same-named places comes first`,
add:

```lua
-- The zone browser: every zone that holds something to pick, A to Z, each
-- with how many it holds (a zone that holds no place holds its own "(zone)"
-- row, so it counts one). A row here is a way in, never a destination: its
-- kind is "browse", and picking one searches for the zone's name, which
-- lists the zone's places (Find's zone rank).
function Search.Zones(data, faction)
    local count = {}
    for _, item in ipairs(Search.Candidates(data, faction)) do
        count[item.map] = (count[item.map] or 0) + 1
    end
    local out = {}
    for map, n in pairs(count) do
        local p = data.Places[map]
        if p then
            out[#out + 1] = { kind = "browse", name = p.name, map = map, count = n }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

```

- [ ] **Step 4: `GoblinPS/Planner.lua`**

In `candidates`, change the comment's last line `-- destinations.` to
`-- destinations, then the zone browser's rows.`, and directly before its
final `return out` add:

```lua
    for _, zone in ipairs(ns.Search.Zones(ns.Data, ns.Core.Faction())) do
        out[#out + 1] = zone
    end
```

In `rowLabel`'s comment, replace

```lua
-- place. The drop-down's width is measured over this too.
local function rowLabel(item)
```

with

```lua
-- place, "Ashenvale (6)" for the zone browser's way into a zone. The
-- drop-down's width is measured over this too.
local function rowLabel(item)
    if item.kind == "browse" then
        return item.name .. " (" .. item.count .. ")"
    end
```

**Move `pick`.** Delete the whole `local function pick(item) ... end` from
its place after `dismiss` (it must now call `browse`, which is defined below
`showResults`; a Lua local is only visible after its definition). Then,
directly after `showResults`'s closing `end` (before `local function
wireBox(box)`), add:

```lua

-- A zone browser row is a way in, never a destination: it puts the zone's
-- name in the box, exactly as typing it would, and the list shows the
-- zone's places. Nothing is planned and nothing is remembered.
local function browse(item)
    ui.toBox:SetText(item.name)
    W.UpdatePlaceholder(ui.toBox)
    ui.toBox:SetFocus()
    showResults()
end

local function pick(item)
    if item.kind == "browse" then
        browse(item)
        return
    end
    hideResults()
    state.to = item
    ns.Core.Remember(item.name)
    ui.toBox:SetText(item.name)
    ui.toBox:ClearFocus()
    W.UpdatePlaceholder(ui.toBox)
    replan()
end
```

(`SetFocus` fires `OnEditFocusGained`, which lists too; the explicit
`showResults()` covers Enter, where the box already has focus and the client
fires nothing.)

In `build()`, the drop-down measurement also measures the browser's rows.
Replace

```lua
    for _, item in ipairs(ns.Search.Candidates(ns.Data, ns.Core.Faction())) do
        ruler:SetText(rowLabel(item))
        widest = math.max(widest, ruler:GetUnboundedStringWidth())
    end
```

with

```lua
    for _, list in ipairs({ ns.Search.Candidates(ns.Data, ns.Core.Faction()),
                            ns.Search.Zones(ns.Data, ns.Core.Faction()) }) do
        for _, item in ipairs(list) do
            ruler:SetText(rowLabel(item))
            widest = math.max(widest, ruler:GetUnboundedStringWidth())
        end
    end
```

(The widest label in the fake world is still "Echo · Westland (Alliance)",
135 px, so "draws the drop-down only a little wider than its longest name"
is unchanged.)

- [ ] **Step 5: Run every gate**

Lua: `469 passed, 0 failed` (463 + 6). Python `Ran 70 tests`, `OK`. Art
green. luacheck and the language server from PowerShell: zero warnings.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Search.lua GoblinPS/Planner.lua test/test_search.lua test/test_ui.lua
git commit -m "Planner: the empty box browses recents, then every zone" -m "With the box empty, the drop-down and the focused box list the recent destinations, then every zone A to Z with how many places it holds (Search.Zones). A zone row is a way in, never a destination: clicking it, or Enter with it on top, puts the zone's name in the box and lists its places; nothing is planned or remembered. The browser's labels are measured for the drop-down's width too." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

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

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


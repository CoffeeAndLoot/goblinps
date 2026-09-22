import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import build_graph as bg  # noqa: E402

FIXTURES = Path(__file__).parent / "fixtures"


class LoadTables(unittest.TestCase):
    def test_loads_every_table(self):
        tables = bg.load_tables(FIXTURES)
        self.assertEqual(set(tables), set(bg.TABLES))

    def test_missing_table_raises(self):
        with self.assertRaises(FileNotFoundError):
            bg.load_tables(FIXTURES / "nope")

    def test_missing_column_raises(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name in bg.TABLES:
                (Path(tmp) / f"{name}.csv").write_text((FIXTURES / f"{name}.csv").read_text(encoding="utf-8"),
                                                       encoding="utf-8")
            (Path(tmp) / "TaxiPath.csv").write_text("ID,FromTaxiNode,ToTaxiNode\n1,2,3\n", encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "TaxiPath: missing columns \\['Cost'\\]"):
                bg.load_tables(Path(tmp))

    def test_read_lock_strips_whitespace(self):
        self.assertEqual(bg.read_lock(ROOT / "tools" / "catalog.lock"), "1.60.1.69913")


class Faction(unittest.TestCase):
    def test_flag_bits(self):
        self.assertEqual(bg.faction_of("1025"), "A")
        self.assertEqual(bg.faction_of("1026"), "H")
        self.assertEqual(bg.faction_of("1027"), "N")
        self.assertIsNone(bg.faction_of("1024"))
        self.assertIsNone(bg.faction_of("0"))


class Places(unittest.TestCase):
    def setUp(self):
        self.tables = bg.load_tables(FIXTURES)
        with contextlib.redirect_stderr(io.StringIO()):
            self.places = bg.build_places(self.tables)

    def test_keeps_zones_on_the_continents_only(self):
        self.assertEqual(sorted(self.places), [1411, 1413, 1454, 1500])

    def test_carries_world_bounds_and_azeroth_centre(self):
        barrens = self.places[1413]
        self.assertEqual((barrens["x0"], barrens["y0"], barrens["x1"], barrens["y1"]), (-4000, -5000, 2000, 0))
        self.assertEqual(barrens["c"], 1)
        # centre is world (-1000, -2500); Azeroth spans x 0..0.5 over world y 10000..-10000
        self.assertEqual((barrens["ax"], barrens["ay"]), (0.3125, 0.55))

    def test_loads_a_zone_whose_full_coverage_is_written_as_floats(self):
        taurajo = self.places[1500]
        self.assertEqual(taurajo["c"], 1)
        self.assertEqual((taurajo["x0"], taurajo["y0"], taurajo["x1"], taurajo["y1"]), (-1000, -1000, 1000, 1000))

    def test_skips_a_type_3_zone_off_the_two_continents(self):
        buf = io.StringIO()
        with contextlib.redirect_stderr(buf):
            places = bg.build_places(self.tables)
        self.assertNotIn(1700, places)
        self.assertIn("skip zone 1700 Zephras Isle: not on the two continents", buf.getvalue())


class Nodes(unittest.TestCase):
    def setUp(self):
        tables = bg.load_tables(FIXTURES)
        self.nodes = bg.build_nodes(tables, bg.build_places(tables))

    def test_skips_non_player_offworld_stale_and_unmapped_nodes(self):
        self.assertEqual(sorted(self.nodes), [23, 25, 80])

    def test_trusts_the_zone_in_the_name_over_the_smallest_rectangle(self):
        # Crossroads sits inside both the Durotar and Barrens rectangles.
        self.assertEqual(self.nodes[25]["map"], 1413)

    def test_a_city_named_first_wins(self):
        self.assertEqual(self.nodes[23]["map"], 1454)

    def test_map_coords_follow_the_wow_axes(self):
        crossroads = self.nodes[25]
        # Barrens: map x = (y1 - wy) / (y1 - y0) = 2600 / 5000; map y = (x1 - wx) / (x1 - x0) = 2400 / 6000
        self.assertEqual((crossroads["mx"], crossroads["my"]), (0.52, 0.4))
        self.assertEqual((crossroads["x"], crossroads["y"], crossroads["c"], crossroads["f"]), (-400, -2600, 1, "H"))


class Flights(unittest.TestCase):
    def setUp(self):
        tables = bg.load_tables(FIXTURES)
        self.flights = bg.build_flights(tables, bg.build_nodes(tables, bg.build_places(tables)))

    def test_time_comes_from_path_length(self):
        self.assertIn([23, 25, 110, 100], self.flights)   # 3200 yards, points given out of order
        self.assertIn([25, 23, 110, 100], self.flights)   # three points
        self.assertIn([25, 80, 60, 20], self.flights)

    def test_falls_back_to_straight_line_without_points(self):
        self.assertIn([80, 25, 60, 41], self.flights)     # 1300 yards

    def test_drops_paths_to_missing_nodes(self):
        self.assertEqual(len(self.flights), 4)


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


class Emit(unittest.TestCase):
    def test_lua_value(self):
        self.assertEqual(bg.lua_value({"name": 'A "b"', "c": 1, "x": -2.5, "ok": True}),
                         '{c=1,name="A \\"b\\"",ok=true,x=-2.5}')
        self.assertEqual(bg.lua_value([1, 2, 110, 95]), "{1,2,110,95}")
        self.assertEqual(bg.lua_value(3.0), "3")

    def test_emit_writes_a_namespaced_lua_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            bg.emit(Path(tmp), "9.9.9", "Flights", [[1, 2, 3, 4]])
            text = (Path(tmp) / "Flights.lua").read_text(encoding="utf-8")
        self.assertTrue(text.startswith("-- Generated by tools/build_graph.py from build 9.9.9. Do not edit.\n"))
        self.assertIn("local _, ns = ...\nns.Data = ns.Data or {}\nns.Data.Flights = {\n    {1,2,3,4},\n}\n", text)


if __name__ == "__main__":
    unittest.main()

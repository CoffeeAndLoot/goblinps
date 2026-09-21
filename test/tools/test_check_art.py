import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import check_art


def geometry():
    with open(ROOT / "images" / "parts" / "planner-geometry.json", encoding="utf-8") as handle:
        return json.load(handle)


class TestPlannerKeysClassified(unittest.TestCase):
    """The allow-list has to be loud in both directions.

    It used to be silent one way: a key added to planner-geometry.json that
    was in no list got neither a pass nor a failure. Plan 7 adds the route
    strip's keys to that very file.
    """

    def test_the_shipped_geometry_is_fully_classified(self):
        self.assertEqual(check_art.planner_keys_classified(geometry()), [])

    def test_a_key_in_neither_list_fails(self):
        g = copy.deepcopy(geometry())
        g["wide"]["compass_rose"] = {"left": 0.1, "top": 0.1, "right": 0.2, "bottom": 0.2}
        problems = check_art.planner_keys_classified(g)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("wide.compass_rose", problems[0])
        self.assertIn("neither", problems[0])

    def test_a_listed_key_that_vanished_fails(self):
        g = copy.deepcopy(geometry())
        del g["tall"]["screen"]
        problems = check_art.planner_keys_classified(g)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("tall.screen", problems[0])

    def test_a_renamed_key_fails_twice_over(self):
        # A rename is both directions at once: the old name is gone and the
        # new one is unclassified. Neither half may be silent.
        g = copy.deepcopy(geometry())
        g["wide"]["side_list"] = g["wide"].pop("side_panel")
        problems = check_art.planner_keys_classified(g)
        self.assertEqual(len(problems), 2, problems)
        self.assertTrue(any("wide.side_list" in p for p in problems), problems)
        self.assertTrue(any("wide.side_panel" in p for p in problems), problems)

    def test_a_circle_key_is_not_asked_to_be_a_rectangle(self):
        # Only rectangular keys are classified; the four round buttons carry
        # cx/cy/r and are none of the interior list's business.
        g = copy.deepcopy(geometry())
        g["wide"]["compass_button"] = {"cx": 0.5, "cy": 0.5, "r": 0.02}
        self.assertEqual(check_art.planner_keys_classified(g), [])


class TestBrassKeys(unittest.TestCase):
    def test_the_layout_button_is_brass_in_wide_and_checked_in_tall(self):
        # The measured reason the brass list is per layout at all: the wide
        # art mounts that button on the crest (85.4% opaque under it), the
        # tall art does not (0.0%).
        self.assertIn("layout_button", check_art.PLANNER_BRASS_KEYS["wide"])
        self.assertNotIn("layout_button", check_art.PLANNER_BRASS_KEYS["tall"])
        self.assertIn("layout_button", check_art.PLANNER_INTERIOR_KEYS)


if __name__ == "__main__":
    unittest.main()

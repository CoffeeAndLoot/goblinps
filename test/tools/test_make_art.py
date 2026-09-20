import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import make_art


class TestPowerOfTwo(unittest.TestCase):
    def test_leaves_a_power_of_two_alone(self):
        self.assertEqual(make_art.next_power_of_two(256), 256)
        self.assertEqual(make_art.next_power_of_two(1), 1)

    def test_rounds_up(self):
        self.assertEqual(make_art.next_power_of_two(192), 256)
        self.assertEqual(make_art.next_power_of_two(768), 1024)
        self.assertEqual(make_art.next_power_of_two(1600), 2048)

    def test_rejects_nonsense(self):
        for bad in (0, -8):
            with self.assertRaises(ValueError):
                make_art.next_power_of_two(bad)


class TestTexCoords(unittest.TestCase):
    def test_art_filling_its_canvas_uses_the_whole_texture(self):
        self.assertEqual(make_art.tex_coords(256, 256, 256, 256), (0.0, 1.0, 0.0, 1.0))

    def test_padding_shrinks_the_coordinates(self):
        self.assertEqual(make_art.tex_coords(192, 192, 256, 256), (0.0, 0.75, 0.0, 0.75))

    def test_the_two_axes_are_independent(self):
        left, right, top, bottom = make_art.tex_coords(1600, 640, 2048, 1024)
        self.assertEqual((left, right), (0.0, 0.78125))
        self.assertEqual((top, bottom), (0.0, 0.625))


class TestPlan(unittest.TestCase):
    def test_every_dash_part_is_planned(self):
        self.assertEqual({p.name for p in make_art.PARTS},
                         {"dash-body", "dash-screen", "dash-compass",
                          "arrow", "dash-eta-plate",
                          "dash2-housing", "dash2-glass", "dash2-compass",
                          "dash2-steps-screen", "dash2-eta-screen",
                          "dash2-stop", "dash2-stop-hover", "dash2-stop-pressed"})

    def test_the_stacked_layers_share_one_canvas(self):
        stacked = [p for p in make_art.PARTS
                   if p.name in ("dash-body", "dash-screen", "dash-compass")]
        self.assertEqual(len({(p.width, p.height) for p in stacked}), 1,
                         "the dash layers must stay aligned after scaling")

    def test_every_planned_part_has_a_source_png(self):
        for part in make_art.PARTS:
            self.assertTrue((make_art.SOURCE / f"{part.name}.png").is_file(), part.name)


class TestDashTwo(unittest.TestCase):
    def test_every_new_part_is_planned(self):
        names = {p.name for p in make_art.PARTS}
        for part in ("dash2-housing", "dash2-glass", "dash2-compass",
                     "dash2-steps-screen", "dash2-eta-screen",
                     "dash2-stop", "dash2-stop-hover", "dash2-stop-pressed"):
            self.assertIn(part, names)

    def test_the_shared_layers_go_to_one_rectangle(self):
        shared = [p for p in make_art.PARTS
                  if p.name in ("dash2-housing", "dash2-glass",
                                "dash2-steps-screen", "dash2-eta-screen")]
        self.assertEqual(len(shared), 4)
        self.assertEqual(len({(p.width, p.height) for p in shared}), 1,
                         "layers stacked corner to corner must ship at one size")

    def test_the_compass_is_not_one_of_them(self):
        # It is cropped and re-centred on the dial so it can be rotated, so it
        # must NOT share the rectangle the others are scaled into.
        compass = next(p for p in make_art.PARTS if p.name == "dash2-compass")
        shared = next(p for p in make_art.PARTS if p.name == "dash2-glass")
        self.assertNotEqual((compass.width, compass.height),
                            (shared.width, shared.height))
        self.assertEqual(compass.width, compass.height, "it must be square to rotate")

    def test_the_button_states_share_one_size(self):
        states = [p for p in make_art.PARTS if p.name.startswith("dash2-stop")]
        self.assertEqual(len(states), 3)
        self.assertEqual(len({(p.width, p.height) for p in states}), 1)


class TestCompassCrop(unittest.TestCase):
    def test_the_crop_is_centred_on_the_dial(self):
        box = make_art.compass_crop_box()
        cx = (box[0] + box[2]) / 2
        cy = (box[1] + box[3]) / 2
        g = make_art.geometry()
        self.assertAlmostEqual(cx, g["glass"]["cx"] * g["canvas"][0], delta=1)
        self.assertAlmostEqual(cy, g["glass"]["cy"] * g["canvas"][1], delta=1)

    def test_the_crop_is_square_and_holds_the_ring_at_any_angle(self):
        box = make_art.compass_crop_box()
        w, h = box[2] - box[0], box[3] - box[1]
        self.assertEqual(w, h)
        g = make_art.geometry()
        ring = g["compass_ring"]["r"] * g["canvas"][0]
        self.assertGreaterEqual(w / 2, ring, "half the crop must clear the ring's radius")

    def test_the_crop_stays_inside_the_canvas(self):
        box = make_art.compass_crop_box()
        w, h = make_art.geometry()["canvas"]
        self.assertGreaterEqual(box[0], 0)
        self.assertGreaterEqual(box[1], 0)
        self.assertLessEqual(box[2], w)
        self.assertLessEqual(box[3], h)


class TestGeometryExport(unittest.TestCase):
    def test_the_lua_table_carries_what_the_addon_needs(self):
        lua = make_art.geometry_lua()
        for key in ("canvas", "glass", "compassRing", "compassCrop",
                    "stepsText", "etaText", "destination", "distance", "stop",
                    "arrow"):
            self.assertIn(key, lua, f"{key} is missing; Dash.lua would have to guess it")

    def test_it_reports_the_crop_as_a_fraction_of_the_device(self):
        lua = make_art.geometry_lua()
        share = lua["compassCrop"]["share"]
        self.assertGreater(share, 0.0)
        self.assertLess(share, 1.0)


if __name__ == "__main__":
    unittest.main()

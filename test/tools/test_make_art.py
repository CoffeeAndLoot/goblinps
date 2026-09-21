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
        # A subset check, not equality: PARTS now also carries the planner's
        # parts (see TestShipsThePlannerParts), and a later plan will add the
        # route strip's. This test's job is only that the dash's own parts
        # are still there, not that PARTS contains nothing else.
        names = {p.name for p in make_art.PARTS}
        self.assertTrue(
            names.issuperset(
                {"dash-body", "dash-screen", "dash-compass",
                 "arrow", "dash-eta-plate",
                 "dash2-housing", "dash2-glass", "dash2-compass",
                 "dash2-steps-screen", "dash2-eta-screen",
                 "dash2-stop", "dash2-stop-hover", "dash2-stop-pressed"}))

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
        # Dash.lua sizes the compass by multiplying the device's width by this
        # number and nothing else, so it has to BE the crop's width against
        # the canvas. "Somewhere between 0 and 1" would pass for any wrong
        # answer in that range, including one that draws the ring at half
        # size.
        lua = make_art.geometry_lua()
        box = make_art.compass_crop_box()
        canvas_w = make_art.geometry()["canvas"][0]
        self.assertAlmostEqual(lua["compassCrop"]["share"],
                               (box[2] - box[0]) / canvas_w, places=12)


class TestShipsThePlannerParts(unittest.TestCase):
    def test_ships_the_planner_parts_at_their_source_aspect(self):
        """A Part whose aspect differs from its PNG's distorts the art.

        The frames are the whole window; a frame stretched by a few percent
        is the fault that made the dash's first design render as an oval,
        and it took a client run to see it.
        """
        from PIL import Image
        import tools.make_art as make_art
        wanted = {
            "planner-frame-wide", "planner-frame-tall", "planner-panel",
            "screen-backdrop", "title-plate", "tagline-plate", "input-box",
            "dropdown-button", "button", "button-hover", "button-pressed",
            "button-disabled", "close", "close-hover", "gear", "gear-hover",
        }
        by_name = {p.name: p for p in make_art.PARTS}
        missing = wanted - set(by_name)
        self.assertEqual(missing, set(), "these planner parts are not shipped")
        for name in sorted(wanted):
            part = by_name[name]
            with Image.open(make_art.SOURCE / (name + ".png")) as im:
                sw, sh = im.size
            source = sw / sh
            shipped = part.width / part.height
            self.assertLess(
                abs(source - shipped) / source, 0.005,
                "{0}: source aspect {1:.4f} but shipped {2:.4f}".format(
                    name, source, shipped))

    def test_does_not_ship_the_strip_parts_yet(self):
        """They belong to plan 7. A texture nothing draws is dead weight."""
        import tools.make_art as make_art
        names = {p.name for p in make_art.PARTS}
        for name in ("node-current", "line-solid", "icon-walk"):
            self.assertNotIn(name, names)


class TestShippedCompass(unittest.TestCase):
    """The crop arithmetic is covered above; this measures what actually shipped.

    SetRotation turns a texture about the middle of its own canvas, so the
    compass only spins instead of orbiting if the drawn ring really is centred
    on the shipped TGA. Every step between the artist's PNG and that file --
    the crop box, the resize, the power-of-two padding -- can move it, and
    nothing else looks at the result.
    """

    def test_the_shipped_compass_is_centred_on_its_own_canvas(self):
        import numpy as np
        from PIL import Image

        tga = (Path(make_art.MEDIA) / "dash2-compass.tga")
        self.assertTrue(tga.is_file(), "run tools/make_art.py: the compass has not been built")
        im = Image.open(tga).convert("RGBA")
        w, h = im.size
        alpha = np.asarray(im.getchannel("A"))
        ys, xs = np.nonzero(alpha > 0)
        self.assertTrue(len(xs), "the shipped compass is blank")
        cx, cy = (int(xs.min()) + int(xs.max())) / 2, (int(ys.min()) + int(ys.max())) / 2
        self.assertAlmostEqual(cx, (w - 1) / 2, delta=0.5,
                               msg="the ring is off centre left to right; it would orbit as it turns")
        self.assertAlmostEqual(cy, (h - 1) / 2, delta=0.5,
                               msg="the ring is off centre top to bottom; it would orbit as it turns")


class TestPlannerGeometry(unittest.TestCase):
    def test_planner_geometry_reaches_the_addon_whole(self):
        """Both layouts, the same keys, and every number still normalised."""
        import tools.make_art as make_art
        g = make_art.planner_geometry_lua()
        self.assertIn("wide", g)
        self.assertIn("tall", g)
        self.assertEqual(set(g["wide"]) - {"canvas"}, set(g["tall"]) - {"canvas"})
        self.assertEqual(g["wide"]["canvas"], {"w": 1600, "h": 1024})
        self.assertEqual(g["tall"]["canvas"], {"w": 1024, "h": 1600})
        for layout in ("wide", "tall"):
            for key, box in g[layout].items():
                if key == "canvas":
                    continue
                for edge, value in box.items():
                    self.assertGreaterEqual(value, 0.0, "{0}.{1}.{2}".format(layout, key, edge))
                    self.assertLessEqual(value, 1.0, "{0}.{1}.{2}".format(layout, key, edge))

    def test_planner_geometry_drops_the_tools_alias(self):
        """tools_button is close_button under another name.

        Codex shipped it for schema compatibility and said plainly: never draw
        it twice. A key that must not be instantiated has no business reaching
        the addon, where somebody will wire it to a second button sitting
        exactly on top of Close.
        """
        import tools.make_art as make_art
        g = make_art.planner_geometry_lua()
        self.assertNotIn("toolsButton", g["wide"])
        self.assertIn("closeButton", g["wide"])

    def test_planner_geometry_names_are_camel_case(self):
        import tools.make_art as make_art
        g = make_art.planner_geometry_lua()
        for key in g["wide"]:
            self.assertNotIn("_", key, "{0} still carries the file's underscores".format(key))
        self.assertIn("fromBox", g["wide"])
        self.assertIn("strip", g)
        self.assertIn("nodeDiameter", g["strip"])


if __name__ == "__main__":
    unittest.main()

# GoblinPS Dash Unit, Second Design: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the dash unit around the second art set: destination and distance on the glass, three step lines in a lit panel, the ETA on its own plate, and a real stop button with hover and pressed states — every position taken from the artist's geometry file rather than hand-typed.

**Architecture:** The eight new parts are already drawn, verified and committed. Five of them share one 1024x1280 canvas and one origin, so they stack corner to corner with no scaling; three button states share a 256 square. `images/parts/dash2-geometry.json` is the placement authority and is already checked against the pixels by `tools/check_art.py`. This plan extends `tools/make_art.py` to ship those parts and to copy the geometry into a generated `GoblinPS/Data/Art.lua`, then rebuilds `GoblinPS/Dash.lua`'s layout to read from it. The trip loop, the arrival rules and `Trip.lua` are untouched: this is what the device looks like, not what it does.

**Tech Stack:** Lua 5.1 on the WoW Forever client (1.60.1.69913, interface 16001), no libraries. Python 3 with Pillow for the texture tool. Tests through lupa; luacheck and lua-language-server at zero warnings.

**Spec:** `docs/superpowers/specs/2026-09-19-goblinps-design.md`, decisions 3, 5 and 7. Read it and `CLAUDE.md` first. Read `images/parts/dash2-notes.md`, the artist's handoff, before Task 1.

## Global Constraints

- Plain Lua 5.1, **no libraries**, **no secure code**, no Blizzard frame templates.
- `GoblinPS/API.lua` is the **only** file that calls Blizzard game APIs or registers game-data events. `Dash.lua` goes through `ns.API`.
- `GoblinPS/Trip.lua` stays pure and **is not touched by this plan**. The trip loop in `Dash.Tick` is not touched either, beyond the widgets it writes to.
- Generated files are never hand-edited: `GoblinPS/Data/Art.lua`, everything under `GoblinPS/Media/`, and `tools/` output.
- **No position, size or offset is hand-typed.** Every one comes from `ns.Data.ArtGeometry`, which `tools/make_art.py` copies from the artist's file. A magic number in `Dash.lua` is a defect.
- Art is laid **over** flat colours. A missing or unloadable texture must leave a working, readable device; `SetTexture` returns whether the file loaded.
- Every FontString gets two horizontal anchors or an explicit width, and a decision to wrap or truncate.
- luacheck and the CLI `lua-language-server --check` stay at **zero** warnings. An editor's live analysis is not the gate.
- Version `2026.09.20.3` in the TOC only. **Nothing is pushed.**
- Do not stage `AGENTS.md`.

## What the last round taught, which this plan must not repeat

Four of these cost a fix round each on plan 4. They are constraints, not advice.

1. **Parts drawn to stack must be drawn at one size.** The first set was three concentric images at different scales; rendering them at different sizes made the compass vanish behind the brass. The five shared layers here fill the same rectangle, always.
2. **A child frame draws above every draw layer of its parent**, and within one frame and layer the later-created region wins. Set frame levels explicitly; never rely on creation order.
3. **The flat-colour fallback is a rectangle.** Behind round art it shows as a box. Hide it when the art it stands in for loads.
4. **`SetRotation` turns a texture about its own centre.** The dial sits at (516, 469) on a 1024x1280 canvas whose middle is (512, 640), so a compass shipped on the shared canvas would orbit a point 171 px below the dial. Task 1 re-centres it.
5. **`test/fake_frames.lua` has an accepted-and-ignored list**, and four methods have been found hiding in it (`SetTexCoord`, `SetFrameLevel`, `SetWordWrap`, `SetAllPoints`). If a test cannot see something, check that list before concluding the fake cannot model it.
6. **A table of parts holds parts.** Every data table in this project is a sibling under `ns.Data` — Places, Nodes, Flights, Crossings, Zones, Inns, and `Links.lua` declares two rather than nesting. The geometry is `ns.Data.ArtGeometry`, never a key inside `ns.Data.Art`: putting it there breaks the invariant that every value in that table is a part, and `SelfTest` iterates it.

## Commands

```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
python -m unittest discover -s test/tools
python tools/check_art.py
python tools/make_art.py
```

PowerShell:

```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
$env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test tools --no-color --no-cache
lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json
```

Baseline before this plan: **239 Lua tests, 27 Python tests, 47 art parts, 0 lint warnings.**

## File Structure

| File | Responsibility |
|---|---|
| `tools/make_art.py` | **Modify.** Ship the eight new parts; re-centre the compass on the dial; copy the geometry into `Data/Art.lua`. |
| `GoblinPS/Data/Art.lua` | **Regenerated.** Gains the new parts and a `geometry` table. Never hand-edited. |
| `GoblinPS/Dash.lua` | **Modify.** New layout from the geometry. The trip loop is untouched. |
| `test/tools/test_make_art.py` | **Modify.** The re-centring and the geometry export. |
| `test/test_ui.lua` | **Modify.** The dash's new widgets and positions. |
| `GoblinPS/GoblinPS.toc` | **Modify.** Version `2026.09.20.3`. |
| `docs/...` | **Modify.** Spec, checklist, CLAUDE.md. |

---

### Task 1: Ship the new parts, and re-centre the compass

**Files:**
- Modify: `tools/make_art.py`
- Regenerate: `GoblinPS/Data/Art.lua`, `GoblinPS/Media/dash2-*.tga`
- Test: `test/tools/test_make_art.py`

**Interfaces:**
- Consumes: the eight PNGs and `images/parts/dash2-geometry.json`, all committed and passing `python tools/check_art.py`.
- Produces, for Tasks 2 and 3:
  - `GoblinPS/Media/dash2-<name>.tga` for all eight parts.
  - `ns.Data.Art["dash2-<name>"] = { file, l, r, t, b }`, as today.
  - `ns.Data.ArtGeometry`, a Lua copy of the artist's placement numbers, shaped exactly as given in Step 3. Every position in `Dash.lua` comes from this and nothing is hand-typed.

Read `images/parts/dash2-notes.md` first. The facts that bind this task:

- The five layers `dash2-housing`, `dash2-glass`, `dash2-compass`, `dash2-steps-screen`, `dash2-eta-screen` share one 1024x1280 canvas and one origin. **Scale them together, by the same factor, to the same shipped rectangle.** They are stacked corner to corner and never centred or scaled independently.
- The three button states share a 256 square and keep it.
- `arrow.png` is already shipped and working. Its SHA-256 is recorded in the geometry file. **Do not rebuild or alter it.**

**The compass needs different treatment from the other four.**

The dial's centre is at (516, 469) on a 1024x1280 canvas whose own centre is (512, 640). `texture:SetRotation` turns a texture about its own middle. So a compass shipped on the shared canvas would turn about a point 171 px below the dial and orbit instead of spin.

Fix it in the tool, not in the addon: crop a square out of `dash2-compass.png` centred on the dial, so the shipped texture's own middle **is** the dial. The crop must be large enough to hold the ring at any rotation — the ring's radius is 262 px, so a half-width of at least 262. Use 280 for margin, giving a 560 square, which fits inside the canvas on both axes (x 236 to 796, y 189 to 749).

Record the crop's size as a fraction of canvas width in the geometry, so `Dash.lua` knows how big to draw it relative to the device.

**Shipped sizes.**

| Part | Source | Shipped | Why |
|---|---|---|---|
| the five shared layers | 1024x1280 | 256x320 | The device draws about 230 px wide; 256 keeps it sharp. |
| `dash2-compass` | cropped 560 square | 256x256 | Its own square, centred on the dial so it can rotate. |
| the three button states | 256x256 | 64x64 | The button draws about 24 px across. |

256x320 pads to 256x512, and 64 and 256 are already powers of two.

- [ ] **Step 1: Write the failing tests**

Add to `test/tools/test_make_art.py`:

```python
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
                    "stepsText", "etaText", "destination", "distance", "stop"):
            self.assertIn(key, lua, f"{key} is missing; Dash.lua would have to guess it")

    def test_it_reports_the_crop_as_a_fraction_of_the_device(self):
        lua = make_art.geometry_lua()
        share = lua["compassCrop"]["share"]
        self.assertGreater(share, 0.0)
        self.assertLess(share, 1.0)
```

- [ ] **Step 2: Run to verify they fail**

Run: `python -m unittest discover -s test/tools`
Expected: FAIL with `AttributeError` for `compass_crop_box`, `geometry` and `geometry_lua`.

- [ ] **Step 3: Extend the tool**

In `tools/make_art.py`, add beside the existing constants:

```python
GEOMETRY = SOURCE / "dash2-geometry.json"

# Half the compass crop, in source pixels. The ring's radius is 262, so this
# clears it with margin and still fits inside the 1024x1280 canvas.
COMPASS_HALF = 280
```

Extend `PARTS` with the eight new entries — the four stacked layers at one
rectangle, the compass at its own square, the buttons at theirs:

```python
PARTS += [
    Part("dash2-housing", 256, 320),
    Part("dash2-glass", 256, 320),
    Part("dash2-steps-screen", 256, 320),
    Part("dash2-eta-screen", 256, 320),
    Part("dash2-compass", 256, 256),      # cropped square, see compass_crop_box
    Part("dash2-stop", 64, 64),
    Part("dash2-stop-hover", 64, 64),
    Part("dash2-stop-pressed", 64, 64),
]
```

Add the geometry helpers:

```python
def geometry():
    """The artist's placement file, which tools/check_art.py checks against the pixels."""
    import json
    return json.loads(GEOMETRY.read_text(encoding="utf-8"))


def compass_crop_box():
    """The square to cut out of the compass so it can be rotated.

    texture:SetRotation turns a texture about its own middle, and the dial is
    not at the middle of the shared canvas, so a compass shipped whole would
    orbit rather than spin. Cutting a square centred on the dial makes the
    shipped texture's own middle the dial.
    """
    g = geometry()
    w, h = g["canvas"]
    cx, cy = g["glass"]["cx"] * w, g["glass"]["cy"] * h
    left, top = round(cx - COMPASS_HALF), round(cy - COMPASS_HALF)
    right, bottom = round(cx + COMPASS_HALF), round(cy + COMPASS_HALF)
    if left < 0 or top < 0 or right > w or bottom > h:
        raise ValueError(f"the compass crop {left, top, right, bottom} leaves the canvas")
    return (left, top, right, bottom)
```

Give `build_one` a special case, keeping everything else as it is:

```python
def build_one(part):
    src = SOURCE / "{0}.png".format(part.name)
    if not src.is_file():
        raise FileNotFoundError("{0} is missing; the art has not been delivered".format(src))
    art = Image.open(src).convert("RGBA")
    if part.name == "dash2-compass":
        art = art.crop(compass_crop_box())
    art = art.resize((part.width, part.height), Image.LANCZOS)
    cw, ch = next_power_of_two(part.width), next_power_of_two(part.height)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.paste(art, (0, 0))
    MEDIA.mkdir(parents=True, exist_ok=True)
    canvas.save(MEDIA / "{0}.tga".format(part.name))
    return tex_coords(part.width, part.height, cw, ch), (cw, ch)
```

Add the geometry export:

```python
def geometry_lua():
    """The placement numbers the addon needs, as plain fractions.

    Everything Dash.lua positions comes from here. The addon never hand-types
    a coordinate, so a change in the art reaches the layout by regenerating
    this file rather than by editing Lua.
    """
    g = geometry()
    w, h = g["canvas"]
    box = compass_crop_box()

    def rect(r):
        return {"left": r["left"], "top": r["top"], "right": r["right"], "bottom": r["bottom"]}

    return {
        "canvas": {"w": w, "h": h},
        "glass": {"cx": g["glass"]["cx"], "cy": g["glass"]["cy"], "r": g["glass"]["r"]},
        "compassRing": {"r": g["compass_ring"]["r"]},
        # How wide the cropped compass is against the whole device, so the
        # addon can size it without knowing anything about the crop.
        "compassCrop": {"share": (box[2] - box[0]) / w},
        "arrow": {"share": g["_assembly"]["arrow"]["display_size_pixels"][0] / w},
        "stepsText": rect(g["_assembly"]["steps_text_safe_box"]),
        "etaText": rect(g["_assembly"]["eta_text_safe_box"]),
        "destination": rect(g["destination_line"]),
        "distance": rect(g["distance_line"]),
        "stop": {"cx": g["stop_button"]["cx"], "cy": g["stop_button"]["cy"],
                 "r": g["stop_button"]["r"]},
    }
```

And write it into the generated Lua. After the existing rows are built, append a
`geometry` entry. Keep the formatting plain and deterministic — the file is
compared byte for byte by the reviewer:

```python
def lua_value(v, indent):
    pad = " " * indent
    if isinstance(v, dict):
        inner = ",\n".join('{0}["{1}"] = {2}'.format(pad + "    ", k, lua_value(x, indent + 4))
                           for k, x in sorted(v.items()))
        return "{\n" + inner + "\n" + pad + "}"
    if isinstance(v, float):
        return "{0:.6g}".format(v)
    return str(v)
```

Then in `main()`, after the parts loop, add the geometry table to the text it
writes, as `ns.Data.ArtGeometry = <table>`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest discover -s test/tools`
Expected: PASS, the existing tests plus the new ones.

- [ ] **Step 5: Build, and check the compass really is centred**

Run: `python tools/make_art.py`
Then confirm the shipped compass has its ring centred on its own middle, which
is the whole point of the crop. Put this in your session scratchpad, not the repo:

```python
from PIL import Image
import numpy as np
a = np.asarray(Image.open("GoblinPS/Media/dash2-compass.tga").convert("RGBA").getchannel("A"))
ys, xs = np.nonzero(a > 32)
w, h = a.shape[1], a.shape[0]
print("bbox centre", (xs.min()+xs.max())/2, (ys.min()+ys.max())/2, "canvas centre", (w-1)/2, (h-1)/2)
```

Both centres must agree within a pixel or two. Report the numbers.

- [ ] **Step 6: Confirm nothing else regressed**

Run `python tools/check_art.py` — expected `47 pass, 0 with problems`.
Run the Lua suite — expected 239 passed, since no Lua changed.

- [ ] **Step 7: Commit**

```bash
git add tools/make_art.py test/tools/test_make_art.py GoblinPS/Data/Art.lua GoblinPS/Media
git commit -m "Ship the second dash set, with the compass re-centred on the dial" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: The device, rebuilt from the geometry

**Files:**
- Modify: `GoblinPS/Dash.lua`
- Modify: `GoblinPS/GoblinPS.toc` (version `2026.09.20.3`)
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `ns.Data.Art["dash2-*"]` and `ns.Data.ArtGeometry` from Task 1.
- Produces, for Task 3: a `ui` table whose art and frames are in place, with `ui.artLayer`, `ui.glass`, `ui.compass`, `ui.arrow`, `ui.stepsScreen`, `ui.etaScreen`, `ui.housingFrame`, `ui.housing` and `ui.content`; and a file-local `place(region, parent, rect)` that Task 3 calls directly. `place` is **not** put on the `ui` table: both tasks edit the same file, so the local is already in scope, and an export nothing reads is dead weight.

This task replaces the device's **appearance** only. Do not touch `Dash.Tick`, `Dash.Refresh`, `Dash.Start`, `Dash.Stop` or anything in `Trip.lua`. The old widgets keep their names so the trip loop still writes to them; Task 3 moves the text.

**The shape of it.** The device is one rectangle, 1024 by 1280 in the art, drawn at `Dash.SIZE`. Five layers fill that rectangle corner to corner, in this order, bottom to top: glass, compass, arrow, steps screen, ETA screen, then the housing over all of them. The compass and the arrow are the exceptions: both are square textures centred on the dial, because both rotate.

**Frame levels, set explicitly.** Plan 4 lost an afternoon to this: a child frame draws above every draw layer of its parent, and within one frame and layer the later-created region wins. So:

| Level | Frame | Holds |
|---|---|---|
| base | `f` | the flat-colour fallback |
| base + 1 | `artLayer` | glass, compass, arrow, both screens |
| base + 2 | `housing` | the chassis, over the art, with its holes |
| base + 3 | `content` | every FontString (Task 3) |
| base + 4 | `stop` | the button (Task 3) |

- [ ] **Step 1: Write the failing tests**

Add to `test/test_ui.lua`, in the dash block:

```lua
        h.it("lays the five shared layers on one rectangle", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            -- They were drawn corner to corner on one canvas: any that is
            -- sized differently is drawn somewhere the artist did not mean.
            for _, name in ipairs({ "glass", "stepsScreen", "etaScreen", "housing" }) do
                h.truthy(ui[name], name .. " is missing")
                h.eq(ui[name]:GetWidth(), ui.artLayer:GetWidth(), name .. " must fill the device")
                h.eq(ui[name]:GetHeight(), ui.artLayer:GetHeight(), name .. " must fill the device")
            end
        end)

        h.it("makes the compass and the arrow square, because both turn", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            for _, name in ipairs({ "compass", "arrow" }) do
                h.eq(ui[name]:GetWidth(), ui[name]:GetHeight(),
                     name .. " rotates about its own middle, so it must be square")
            end
        end)

        h.it("takes every position from the generated geometry, not from constants", function()
            local g = ns.Data.ArtGeometry
            h.truthy(g, "Task 1 must have written ns.Data.ArtGeometry")
            Dash.Start(plan)
            local ui = Dash.Debug()
            -- The compass is sized as a share of the device, so a change in
            -- the art reaches the layout by regenerating Art.lua.
            local expect = ui.artLayer:GetWidth() * g.compassCrop.share
            h.truthy(math.abs(ui.compass:GetWidth() - expect) < 1,
                     "the compass is sized from geometry.compassCrop.share")
        end)

        h.it("stacks the housing above the art and the text above the housing", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            h.truthy(ui.housingFrame:GetFrameLevel() > ui.artLayer:GetFrameLevel(),
                     "the housing covers the art")
            h.truthy(ui.content:GetFrameLevel() > ui.housingFrame:GetFrameLevel(),
                     "nothing the player reads is ever behind the chassis")
        end)
```

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: FAIL, `ui.artLayer` is nil.

- [ ] **Step 3: Rebuild the layout**

In `GoblinPS/Dash.lua`, replace the geometry constants:

```lua
-- The device's rectangle on screen. The art is 1024x1280, so this keeps that
-- shape; everything inside is placed as a fraction of it, from the geometry
-- the art tool generates. Nothing here is a measured guess.
Dash.SIZE = { 230, 288 }
local PAD = 8
local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"
```

Add two helpers above `build()`:

```lua
local function geometry()
    return ns.Data.Art and ns.Data.ArtGeometry
end

-- Put a region where the geometry says, as a fraction of `parent`. `rect` is
-- { left, top, right, bottom } in 0..1 with the origin at the top left, which
-- is how the artist's file states every box.
local function place(region, parent, rect)
    local w, h = parent:GetWidth(), parent:GetHeight()
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", rect.left * w, -rect.top * h)
    region:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", rect.right * w, -rect.bottom * h)
end
```

Then in `build()`, after the drag wiring and `f:Hide()`, replace everything from
the old `device` frame down to the old `bodyArt` with:

```lua
    local base = f:GetFrameLevel()
    local g = geometry()

    -- One rectangle for the five layers that were drawn to stack.
    local artLayer = CreateFrame("Frame", nil, f)
    artLayer:SetAllPoints(f)
    artLayer:SetFrameLevel(base + 1)

    -- The flat colour is the fallback for art that will not load. It is a
    -- rectangle, so it goes the moment the glass arrives, or it boxes in a
    -- round device.
    local flat = W.Fill(artLayer, "BACKGROUND", "screen")
    local glass = art(artLayer, "dash2-glass", "BORDER")
    if glass then
        flat:Hide()
    end

    -- The compass and the arrow turn, so each is a square texture centred on
    -- the dial. SetRotation turns a texture about its own middle, and Task 1
    -- cropped the compass so that its middle IS the dial.
    local dial = g and { x = g.glass.cx, y = g.glass.cy } or { x = 0.5, y = 0.4 }
    local function centreOnDial(region, share)
        local side = f:GetWidth() * share
        region:SetSize(side, side)
        region:ClearAllPoints()
        region:SetPoint("CENTER", artLayer, "TOPLEFT",
                        dial.x * artLayer:GetWidth(), -dial.y * artLayer:GetHeight())
    end

    local compass = artLayer:CreateTexture(nil, "ARTWORK")
    local compassPart = ns.Data.Art and ns.Data.Art["dash2-compass"]
    if compassPart and compass:SetTexture(MEDIA .. compassPart.file) then
        compass:SetTexCoord(compassPart.l, compassPart.r, compassPart.t, compassPart.b)
    else
        compass:Hide()
    end
    centreOnDial(compass, g and g.compassCrop.share or 0.55)

    local arrow = artLayer:CreateTexture(nil, "OVERLAY")
    local arrowPart = ns.Data.Art and ns.Data.Art["arrow"]
    if arrowPart and arrow:SetTexture(MEDIA .. arrowPart.file) then
        arrow:SetTexCoord(arrowPart.l, arrowPart.r, arrowPart.t, arrowPart.b)
    else
        arrow:SetTexture("Interface\\Buttons\\WHITE8X8")
        arrow:SetVertexColor(unpack(W.COLOR.green))
    end
    centreOnDial(arrow, g and g.arrow.share or 0.45)

    local stepsScreen = art(artLayer, "dash2-steps-screen", "BACKGROUND")
    local etaScreen = art(artLayer, "dash2-eta-screen", "BACKGROUND")

    -- The chassis, over the art, with its holes letting the art show through.
    local housingFrame = CreateFrame("Frame", nil, f)
    housingFrame:SetAllPoints(f)
    housingFrame:SetFrameLevel(base + 2)
    local housing = art(housingFrame, "dash2-housing", "ARTWORK")

    local content = CreateFrame("Frame", nil, f)
    content:SetAllPoints(f)
    content:SetFrameLevel(base + 3)
```

Keep the existing FontStrings for now, parented to `content`, so the trip loop
still has somewhere to write; Task 3 moves them onto the glass and into the
panel. Extend the `ui` table with the new names:

```lua
    ui = { frame = f, artLayer = artLayer, flat = flat, glass = glass,
           compass = compass, arrow = arrow, stepsScreen = stepsScreen,
           etaScreen = etaScreen, housingFrame = housingFrame, housing = housing,
           content = content,
           distance = distance, eta = eta, step = step, next = following, stop = stop }
```

Set `## Version: 2026.09.20.3` in the TOC.

- [ ] **Step 4: Run the tests to verify they pass**

Run the Lua suite. Expected: green.

- [ ] **Step 5: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 6: Commit**

```bash
git add GoblinPS/Dash.lua GoblinPS/GoblinPS.toc test/test_ui.lua
git commit -m "Dash unit: rebuild the layout from the generated geometry" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: The words, and a stop button that presses

**Files:**
- Modify: `GoblinPS/Dash.lua`
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `ui.place`, `ui.content`, `ui.artLayer` and `ns.Data.ArtGeometry` from Task 2.
- Produces: the device as designed. Nothing later in this plan depends on it.

**What the device says, and where.** The art puts four pieces of text in four boxes, and the geometry names all four:

| Box | What goes in it |
|---|---|
| `destination` | the name of the step you are walking to, on the glass |
| `distance` | how far that is, in yards, under the name |
| `stepsText` | three lines: the step you are on, then the next two |
| `etaText` | the time left for the whole journey |

**A decision this plan makes, and the reason.** The name on the glass is the **current step's target**, not the final destination. The arrow points at the current step; the distance counts down to the current step. Putting a third thing on the same glass — a destination the arrow is not pointing at — invites the player to read the arrow as pointing there. Arrow, name and number describe one thing. The step lines underneath carry the journey.

**The stop button.** Three states are shipped: `dash2-stop`, `dash2-stop-hover`, `dash2-stop-pressed`. The housing has a transparent socket for it, and the geometry gives its centre and radius. It replaces the old text button.

- [ ] **Step 1: Write the failing tests**

```lua
        h.it("puts the current step's name and distance on the glass", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            standAt(700, 0)
            Dash.Tick("tick")
            h.eq(ui.destination:GetText(), "the North Gate",
                 "the glass names what the arrow points at, not the journey's end")
            h.eq(ui.distance:GetText(), "700 yd")
        end)

        h.it("shows the step you are on and the next two", function()
            Dash.Start(plan)
            local ui, state = Dash.Debug()
            h.eq(ui.steps[1]:GetText(), "Ride to the North Gate")
            h.eq(ui.steps[2]:GetText(), "Zeppelin to East Dock")
            h.eq(ui.steps[3]:GetText(), "Ride to Delta")
            state.index = 3
            Dash.Refresh()
            h.eq(ui.steps[1]:GetText(), "Ride to Delta")
            h.eq(ui.steps[2]:GetText(), "", "nothing follows the last step")
            h.eq(ui.steps[3]:GetText(), "")
        end)

        h.it("bounds every line it draws", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            local lines = { ui.destination, ui.distance, ui.eta, ui.steps[1], ui.steps[2], ui.steps[3] }
            for i, fs in ipairs(lines) do
                h.truthy(fs.points and #fs.points >= 2,
                         "line " .. i .. " needs two horizontal anchors or it draws past the frame")
            end
        end)

        h.it("gives the stop button its three states and puts it in the socket", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            local g = ns.Data.ArtGeometry
            h.eq(ui.stop:GetWidth(), ui.stop:GetHeight(), "the button is round art on a square")
            local expect = ui.frame:GetWidth() * g.stop.r * 2
            h.truthy(math.abs(ui.stop:GetWidth() - expect) < 2, "sized from geometry.stop.r")
            h.truthy(ui.stopNormal, "the unpressed cap")
            h.truthy(ui.stopPressed, "the pushed cap")
        end)

        h.it("still ends the trip when the button is clicked", function()
            Dash.Start(plan)
            local ui, state = Dash.Debug()
            h.truthy(state.plan)
            Fake.Click(ui.stop)
            h.falsy(ui.frame:IsShown())
            h.falsy(state.plan, "clicking Stop ends the trip, as Escape does")
        end)

        h.it("keeps a usable button when its art will not load", function()
            Fake.missingTextures[MEDIA_STOP] = true
            Dash.Stop()
            local FreshDash = assert(loadfile("GoblinPS/Dash.lua"))("GoblinPS", ns)
            FreshDash.Start(plan)
            h.truthy(FreshDash.Debug().stop, "a missing texture must not lose the button")
            Fake.missingTextures[MEDIA_STOP] = nil
        end)
```

Define `MEDIA_STOP` near the top of the dash block as
`"Interface\\AddOns\\GoblinPS\\Media\\dash2-stop"`, and reuse whatever helper
the existing "keeps a working device when a texture will not load" test uses to
load a second copy of the module. If that helper is inline, lift it to a local
so both tests share it rather than copying it.

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: FAIL, `ui.destination` and `ui.steps` are nil.

- [ ] **Step 3: Write the text and the button**

Replace the old FontStrings in `build()` with these, all on `content`, all
positioned by `place`:

```lua
    local g = geometry()

    -- On the glass: what the arrow points at, and how far.
    local destination = W.Text(content, "green", "GameFontNormalSmall", "CENTER")
    local distance = W.Text(content, "green", "GameFontNormalLarge", "CENTER")
    if g then
        place(destination, content, g.destination)
        place(distance, content, g.distance)
    end

    -- In the lit panel: the step you are on, then the next two. The panel is
    -- one box in the art, so the three lines share it, each a third tall.
    local steps = {}
    for i = 1, 3 do
        steps[i] = W.Text(content, i == 1 and "green" or "dim", "GameFontNormalSmall", "LEFT")
    end
    if g then
        local box, third = g.stepsText, (g.stepsText.bottom - g.stepsText.top) / 3
        for i = 1, 3 do
            place(steps[i], content, {
                left = box.left, right = box.right,
                top = box.top + third * (i - 1), bottom = box.top + third * i,
            })
        end
    end

    -- On its own plate: the time left.
    local eta = W.Text(content, "green", "GameFontNormalSmall", "CENTER")
    if g then
        place(eta, content, g.etaText)
    end
```

The stop button, replacing the old text button:

```lua
    -- A real button in the housing's socket, with the three caps the artist
    -- drew. It ends the trip exactly as Escape does.
    local stop = CreateFrame("Button", nil, f)
    stop:SetFrameLevel(base + 4)
    if g then
        local side = f:GetWidth() * g.stop.r * 2
        stop:SetSize(side, side)
        stop:SetPoint("CENTER", f, "TOPLEFT", g.stop.cx * f:GetWidth(), -g.stop.cy * f:GetHeight())
    else
        stop:SetSize(20, 20)
        stop:SetPoint("TOPRIGHT", -PAD, -PAD)
    end
    stop:RegisterForClicks("LeftButtonUp")
    stop:SetScript("OnClick", function() Dash.Stop() end)

    local function cap(name, setter)
        local part = ns.Data.Art and ns.Data.Art[name]
        if not part then
            return nil
        end
        local t = stop:CreateTexture(nil, "ARTWORK")
        if not t:SetTexture(MEDIA .. part.file) then
            return nil
        end
        t:SetTexCoord(part.l, part.r, part.t, part.b)
        t:SetAllPoints(stop)
        if setter then
            setter(t)
        end
        return t
    end

    local stopNormal = cap("dash2-stop")
    local stopPressed = cap("dash2-stop-pressed")
    if stopPressed then
        stopPressed:Hide()
        stop:SetScript("OnMouseDown", function()
            stopPressed:Show()
            if stopNormal then stopNormal:Hide() end
        end)
        stop:SetScript("OnMouseUp", function()
            stopPressed:Hide()
            if stopNormal then stopNormal:Show() end
        end)
    end
    local hover = ns.Data.Art and ns.Data.Art["dash2-stop-hover"]
    if hover then
        stop:SetHighlightTexture(MEDIA .. hover.file, "ADD")
    end
    if not stopNormal then
        -- No art: a flat coloured square still presses and still stops.
        W.Fill(stop, "ARTWORK", "hazard")
    end
```

Then update `Dash.Refresh` to fill the three lines and the glass. It currently
writes `ui.step` and `ui.next`; replace that with:

```lua
    for i = 1, 3 do
        ui.steps[i]:SetText(stepText(steps[state.index + i - 1]))
    end
    ui.destination:SetText(step.to and ns.Search.ShortName(step.to.name) or "")
```

**The banner needs somewhere to go, and this is the subtle part.** Plan 4's fix
wave made "Recalculating..." survive by holding it in `state.banner`, which
`Dash.Refresh` reads *instead of* the normal text for `ui.next`, and which the
top of `Dash.Tick` clears on the following tick. `ui.next` no longer exists, so
the banner must move without losing that behaviour. Put it on the first step
line, and blank the other two, so the panel reads as one message rather than a
message with stale directions under it:

```lua
    if state.banner then
        ui.steps[1]:SetText(state.banner)
        ui.steps[2]:SetText("")
        ui.steps[3]:SetText("")
    else
        for i = 1, 3 do
            ui.steps[i]:SetText(stepText(steps[state.index + i - 1]))
        end
    end
```

Leave the clearing in `Dash.Tick` exactly as it is: it already blanks
`state.banner` and calls `Refresh()` before evaluating the next verdict, which
is what stops the message sticking. Change only the widget, never the timing.

Elsewhere in `Dash.Tick`, wherever it writes "Arrived." to `ui.step`, write to
`ui.steps[1]` and blank `ui.steps[2]` and `ui.steps[3]`.

Add all the new names to the `ui` table: `destination`, `steps`, `eta`, `stop`,
`stopNormal`, `stopPressed`.

- [ ] **Step 4: Re-point the plan 4 tests that read the old widgets**

`ui.step` and `ui.next` are gone, so the tests that read them must read
`ui.steps[1]` and `ui.steps[2]` instead. **Change the read, never the
assertion** — these are plan 4's contract for the trip loop and they still
hold. In `test/test_ui.lua` they are at roughly lines 528, 529, 535, 536, 633,
652, 755, 828, 832 and 895.

Two need more than a rename:

- The wrap test at 583-585 asserted `ui.step.wordWrap` was true because the old
  single line had to wrap to fit a long stop name. The panel now gives three
  short lines inside a box the artist sized, so wrapping is wrong there: each
  line truncates. Replace that test with one asserting all three lines
  truncate and sit inside `geometry.stepsText`.
- The fallback test at 882 loads a second copy of the module
  (`local FreshDash = assert(loadfile("GoblinPS/Dash.lua"))("GoblinPS", ns)`)
  because `build()` runs once per instance. Reuse that exact idiom for the new
  stop-button fallback test rather than inventing another; if you use it twice,
  lift it to a local helper.

- [ ] **Step 5: Run the tests to verify they pass**

Run the Lua suite. Expected: green.

- [ ] **Step 6: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 7: Commit**

```bash
git add GoblinPS/Dash.lua test/test_ui.lua
git commit -m "Dash unit: the words on the glass, three steps, and a button that presses" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Documents

**Files:**
- Modify: `docs/superpowers/specs/2026-09-19-goblinps-design.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: The spec**

In decision 3, describe the device as built: the current step's name and
distance on the glass, three step lines in the lit panel, the ETA on its own
plate, a stop button with hover and pressed states. Record the ruling that the
glass names the **current step**, not the journey's end, and why.

In decision 5, record that `images/parts/dash2-geometry.json` is the placement
authority, that `tools/check_art.py` verifies it against the pixels, and that
`tools/make_art.py` copies it into `GoblinPS/Data/Art.lua` so no coordinate is
hand-typed in the addon.

Renumber the roadmap: this is plan 5, and the route strip becomes plan 6. Say
plainly that the dash was redesigned after being seen in the client.

- [ ] **Step 2: The checklist**

Add to the `## Dash unit (plan 4)` section, retitled for both plans:

```
- [ ] The device is round, not oval, and the compass ring turns with you while
      the arrow turns toward the step. If the arrow is right and the ring is
      wrong, that is Trip.CompassAngle, not Trip.ROTATION_SIGN
- [ ] The glass names the step you are walking to and counts the yards down
- [ ] The panel shows the step you are on and the next two; near the end it
      shows fewer, not blanks with stale text
- [ ] The ETA plate shows the time left for the whole journey
- [ ] The red button lights on hover, pushes in on click, and ends the trip
- [ ] Every line sits inside its own opening in the chassis; no text is cut
      off and none draws on the brass
- [ ] At UI scale 0.64 and 1.0 the device is legible and nothing overlaps
- [ ] /gps selftest names the eight new textures; if one FAILS the device
      must still be readable on its flat colours
```

- [ ] **Step 3: CLAUDE.md**

Update the status line: plan 5 built, plan 6 the route strip next. Note in the
layout map that `GoblinPS/Data/Art.lua` now carries the geometry as well as the
texture coordinates, and that no coordinate is hand-typed in `Dash.lua`.

- [ ] **Step 4: Commit**

```bash
git add docs/ CLAUDE.md
git commit -m "Docs: the dash unit's second design" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Notes for the reviewer

- **No coordinate may be hand-typed in `Dash.lua`.** Every position comes from
  `ns.Data.ArtGeometry`. A literal offset or size in the layout is a finding
  even if it happens to look right, because the next art delivery will move it
  and nothing will notice.
- **The compass crop is the subtle part.** `SetRotation` turns a texture about
  its own middle, and the dial is not at the middle of the shared canvas.
  Check that Task 1's shipped compass really has its ring centred on its own
  canvas, and that Task 2 sizes it from `geometry.compassCrop.share` rather
  than a constant.
- **The fallback is not decoration.** With no art at all the device must still
  open, show its text and stop. Check that every `SetTexture` return is used.
- **Do not let the trip loop rot.** Plan 4's tests for advance, recalculate,
  arrive, pause and the pin are still the contract. If one had to change, the
  read may move but the assertion may not.
- The fake's accepted-and-ignored list has hidden four methods so far. If a
  test cannot see something, look there before concluding it cannot be tested.

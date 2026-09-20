# GoblinPS Dash Unit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After GO, a small draggable device shows the step you are on, an arrow that turns to point at it, the distance and the time left; it advances when you arrive, says "Recalculating..." when you wander off, and closes when you get there.

**Architecture:** `Trip.lua` already holds the pure arrival rules and is tested; this plan adds the bearing and time-left maths beside them, the client facts `API.lua` must supply (facing, taxi state, the three arrival events), and `Dash.lua`, which owns the frame and the tick loop. The dash is built on flat colours first, exactly as the planner was, so a texture that does not load leaves a working device; `tools/make_art.py` then produces shipped-size textures from the PNG sources and a generated `Data/Art.lua` of texture coordinates, and task 6 lays them over the colours. An active trip is deliberately not saved: `/reload` ends it.

**Tech Stack:** Lua 5.1 on the WoW Forever client (1.60.1.69913, interface 16001), no libraries. Python 3 with Pillow for the texture tool. Tests through lupa; luacheck and lua-language-server at zero warnings.

**Spec:** `docs/superpowers/specs/2026-09-19-goblinps-design.md`, decisions 3, 5 and 7. Read it and `CLAUDE.md` first. Read `images/parts/CLAUDE-HANDOFF.md` before task 1: it is Codex's handoff for the artwork and states the alignment facts the tool must preserve.

## Global Constraints

- Plain Lua 5.1, **no libraries**, **no secure code**, no Blizzard frame templates.
- `GoblinPS/API.lua` is the **only** file that calls Blizzard game APIs and registers game-data events. UI files may register only UI layout events (`UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED`) for their own frames.
- Pure modules (`Geo`, `Travel`, `Search`, `Graph`, `Route`, `Trip`, `Known`, `Prefs`) touch no Blizzard global.
- `RegisterEvent` with a name the client does not know is a **hard error**. Every event in this plan is confirmed present in `docs/research/2026-09-19-api-and-data-findings.md`: `ZONE_CHANGED`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_CONTROL_LOST`, `PLAYER_CONTROL_GAINED`. Add no others.
- Art is laid **over** flat colours. A missing or unloadable texture must leave a working, readable device. `SetTexture` returns whether the file loaded; `/gps selftest` checks the list.
- Every FontString gets two horizontal anchors or an explicit width, and a decision to wrap or truncate. A one-anchor FontString fed a sentence draws over its neighbours.
- Route and step text stays plain. Jokes live in the frame, the tagline and tooltips.
- Generated files (`GoblinPS/Data/Places.lua`, `Nodes.lua`, `Flights.lua`, and the new `Art.lua`) are never hand-edited.
- luacheck and lua-language-server stay at **zero** warnings; a new WoW global goes in both `.luacheckrc` and `.luarc.json`.
- Version `2026.09.20.2` in the TOC only. **Nothing is pushed.**
- Do not stage `AGENTS.md`. Another agent owns it.

## Commands

```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
python -m unittest discover -s test/tools
python tools/check_art.py
```

luacheck and the language server, from PowerShell:

```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
$env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test tools --no-color --no-cache
lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json
```

Baseline before this plan: **185 Lua tests, 18 Python tests, 39 art parts, 0 lint warnings.**

## File Structure

| File | Responsibility |
|---|---|
| `tools/make_art.py` | **Create.** PNG sources to shipped TGAs in `GoblinPS/Media/`, plus the generated `GoblinPS/Data/Art.lua`. Downscales per part, pads to power-of-two, recomputes texture coordinates. |
| `GoblinPS/Data/Art.lua` | **Create, GENERATED.** `{ name = { file, l, r, t, b } }`. Never hand-edited. |
| `GoblinPS/Trip.lua` | **Modify.** Add `Bearing`, `ArrowAngle`, `Remaining`, `DistanceTo`. Stays pure. |
| `GoblinPS/API.lua` | **Modify.** Add `PlayerFacing`, `OnTaxi`, `OnTripEvent`. |
| `GoblinPS/Dash.lua` | **Create.** The device: frame, arrow, texts, drag, tick loop, trip state. |
| `GoblinPS/Core.lua` | **Modify.** `Core.Go` starts a trip instead of only setting a pin; expose `Core.Here`. |
| `GoblinPS/Planner.lua` | **Modify.** Close the planner when GO starts a trip. |
| `GoblinPS/SelfTest.lua` | **Modify.** Check the dash textures. |
| `GoblinPS/GoblinPS.toc` | **Modify.** Add `Data\Art.lua` and `Dash.lua`; version `2026.09.20.2`. |
| `test/fake_frames.lua` | **Modify.** Model `SetRotation`, `SetVertexColor` and `SetDrawLayer`, and make `SetTexCoord` record instead of being swallowed. |
| `test/test_trip.lua` | **Modify.** Bearing, arrow angle, time left. |
| `test/test_ui.lua` | **Modify.** The dash smoke tests join the existing UI suite; see the note below. |
| `test/tools/test_make_art.py` | **Create.** The tool's sizing, padding and coordinate maths. |

---

### Task 1: The shipped-texture tool

**Files:**
- Create: `tools/make_art.py`
- Create: `GoblinPS/Data/Art.lua` (written by running the tool, never by hand)
- Test: `test/tools/test_make_art.py`

**Interfaces:**
- Consumes: the 39 PNGs in `images/parts/`, which `python tools/check_art.py` already passes.
- Produces: `GoblinPS/Media/<name>.tga` for the five dash parts, and
  `ns.Data.Art[name] = { file = "<name>", l = <number>, r = <number>, t = <number>, b = <number> }`
  in `GoblinPS/Data/Art.lua`. Task 6 reads that table. `file` is the base name only; the caller builds the full path.

Read `images/parts/CLAUDE-HANDOFF.md` before starting. The facts that bind this task:

- The TGAs in `images/parts/` are **not** what ships. They are authoring resolution, about 49 MiB, and gitignored. Do not copy them into `GoblinPS/Media/`.
- The authoring `texture-manifest.json` is **not** the shipped manifest. Its coordinates belong to authoring canvases. Recompute them.
- The dash stack is screen, compass, arrow, body. The three 1024 px layers share centre (512,512) and **must stay aligned after downscaling**, which holds only if all three go to the same shipped canvas.
- `arrow.png` is 512 square with generous glow padding; the visible arrow is about 245 px of that. Do not confuse visible width with canvas width when choosing a size.

Shipped sizes. Only the five dash parts are built here; plan 5 extends the same tool to the other 34.

| Part | Source | Shipped | Why |
|---|---|---|---|
| `dash-body` | 1024 | 256 | The device draws about 200 px wide. |
| `dash-screen` | 1024 | 256 | Same canvas as the body, so it stays concentric. |
| `dash-compass` | 1024 | 256 | Same canvas; it rotates about the centre. |
| `arrow` | 512 | 128 | Drawn about 90 px inside the screen. |
| `dash-eta-plate` | 512x128 | 128x32 | A small plate under the device. |

All five shipped sizes are already powers of two, so padding is a no-op for them today. The padding code still has to be correct, because plan 5's parts (192, 768x192, 1600x640) are not.

- [ ] **Step 1: Write the failing test**

Create `test/tools/test_make_art.py`:

```python
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
                          "arrow", "dash-eta-plate"})

    def test_the_stacked_layers_share_one_canvas(self):
        stacked = [p for p in make_art.PARTS
                   if p.name in ("dash-body", "dash-screen", "dash-compass")]
        self.assertEqual(len({(p.width, p.height) for p in stacked}), 1,
                         "the dash layers must stay aligned after scaling")

    def test_every_planned_part_has_a_source_png(self):
        for part in make_art.PARTS:
            self.assertTrue((make_art.SOURCE / f"{part.name}.png").is_file(), part.name)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `python -m unittest discover -s test/tools`
Expected: FAIL with `ModuleNotFoundError: No module named 'make_art'`.

- [ ] **Step 3: Write the tool**

Create `tools/make_art.py`:

```python
#!/usr/bin/env python3
"""Build GoblinPS/Media/*.tga and GoblinPS/Data/Art.lua from images/parts/*.png.

The PNGs are the source of truth and are authoring resolution: a route icon is
256 square and draws at about 24 pixels. Shipping them whole would make the
addon tens of megabytes of pixels nobody sees, so each part is scaled to the
size it actually draws at, then padded up to a power-of-two canvas, the
conservative choice for texture compatibility on this client.

Padding means the art no longer fills its texture, so each part carries the
coordinates that crop the padding away. Those live in the generated
GoblinPS/Data/Art.lua and are read by the UI; nothing hand-types them.

Run from anywhere: python tools/make_art.py
"""

from dataclasses import dataclass
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "images" / "parts"
MEDIA = ROOT / "GoblinPS" / "Media"
TABLE = ROOT / "GoblinPS" / "Data" / "Art.lua"


@dataclass(frozen=True)
class Part:
    name: str
    width: int
    height: int


# The size each part is drawn at in the UI. The three 1024 px dash layers share
# one shipped canvas so that stacking them still lines up: their artwork is
# concentric on (512,512) and stays concentric only under one common scale.
# See images/parts/CLAUDE-HANDOFF.md.
PARTS = [
    Part("dash-body", 256, 256),
    Part("dash-screen", 256, 256),
    Part("dash-compass", 256, 256),
    Part("arrow", 128, 128),
    Part("dash-eta-plate", 128, 32),
]


def next_power_of_two(n):
    """The smallest power of two that is at least n."""
    if n < 1:
        raise ValueError("size must be positive, got {0}".format(n))
    p = 1
    while p < n:
        p *= 2
    return p


def tex_coords(art_w, art_h, canvas_w, canvas_h):
    """left, right, top, bottom for art sitting at the top-left of its canvas."""
    return (0.0, art_w / canvas_w, 0.0, art_h / canvas_h)


def build_one(part):
    src = SOURCE / "{0}.png".format(part.name)
    if not src.is_file():
        raise FileNotFoundError("{0} is missing; the art has not been delivered".format(src))
    art = Image.open(src).convert("RGBA").resize((part.width, part.height), Image.LANCZOS)
    cw, ch = next_power_of_two(part.width), next_power_of_two(part.height)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.paste(art, (0, 0))            # top-left, as the authoring export does
    MEDIA.mkdir(parents=True, exist_ok=True)
    canvas.save(MEDIA / "{0}.tga".format(part.name))
    return tex_coords(part.width, part.height, cw, ch), (cw, ch)


HEADER = """-- Generated by tools/make_art.py. Do not edit.
-- Each part was scaled to the size it draws at, then padded up to a
-- power-of-two canvas. l, r, t, b crop that padding away: pass them straight
-- to texture:SetTexCoord(l, r, t, b).
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Art = {
"""


def main():
    rows, total = [], 0
    for part in PARTS:
        (left, right, top, bottom), (cw, ch) = build_one(part)
        size = (MEDIA / "{0}.tga".format(part.name)).stat().st_size
        total += size
        rows.append(
            '    ["{0}"] = {{ file = "{0}", l = {1:g}, r = {2:g}, t = {3:g}, b = {4:g} }},'
            "  -- {5}x{6} art on {7}x{8}".format(
                part.name, left, right, top, bottom,
                part.width, part.height, cw, ch))
        print("{0}: {1}x{2} on {3}x{4}, {5:.0f} KB".format(
            part.name, part.width, part.height, cw, ch, size / 1024))
    TABLE.write_text(HEADER + "\n".join(rows) + "\n}\n", encoding="utf-8")
    print("wrote {0}".format(TABLE))
    print("{0} textures, {1:.2f} MB total".format(len(PARTS), total / 1024 / 1024))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest discover -s test/tools`
Expected: PASS. 18 existing plus 9 new.

- [ ] **Step 5: Generate the textures and the table**

Run: `python tools/make_art.py`
Expected: five lines naming each part, `wrote ...Art.lua`, and a total well under 1 MB. Open `GoblinPS/Data/Art.lua`: five rows, every one `l = 0, r = 1, t = 0, b = 1`, because all five shipped sizes are already powers of two so nothing is cropped yet.

- [ ] **Step 6: Commit**

```bash
git add tools/make_art.py test/tools/test_make_art.py GoblinPS/Data/Art.lua GoblinPS/Media
git commit -m "Build shipped-size dash textures from the PNG sources" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Bearing, distance and time left

**Files:**
- Modify: `GoblinPS/Trip.lua`
- Test: `test/test_trip.lua`

**Interfaces:**
- Consumes: `ns.Geo.Distance(a, b)`; world positions shaped `{ c, x, y }`.
- Produces, all pure:
  - `Trip.Bearing(from, to)` returns radians, or nil when either is missing, they are on different continents, or they are the same point.
  - `Trip.ArrowAngle(bearing, facing)` returns radians to pass to `texture:SetRotation`, or nil when either input is nil.
  - `Trip.DistanceTo(pos, step)` returns yards, or nil.
  - `Trip.Remaining(result, index, pos, speed)` returns seconds left for the whole journey, or nil.

The coordinate facts this rests on, so nobody has to rediscover them:

- `Geo.ToWorld` gives `wx = x1 - my * (x1 - x0)` and `wy = y1 - mx * (y1 - y0)`. So **world x increases north and world y increases west**, which is Blizzard's own world convention.
- `GetPlayerFacing()` returns radians with **0 = north, increasing counter-clockwise**, the same frame.
- Therefore `atan2(dy, dx)` over (north, west) is directly comparable with facing, and the arrow's angle is simply `bearing - facing`.
- `texture:SetRotation(a)` rotates counter-clockwise. An arrow drawn pointing up, rotated by `bearing - facing`, points at the target. **The sign is unverified in game**, which is why `Trip.ROTATION_SIGN` exists: if the arrow mirrors, flip that one constant rather than hunting through the maths.

- [ ] **Step 1: Write the failing tests**

Append to `test/test_trip.lua`, inside the returned function:

```lua
    h.describe("Trip.Bearing", function()
        local origin = { c = 1, x = 0, y = 0 }
        h.it("points along +x for due north", function()
            h.eq(Trip.Bearing(origin, { c = 1, x = 100, y = 0 }), 0)
        end)
        h.it("points a quarter turn for due west", function()
            local b = Trip.Bearing(origin, { c = 1, x = 0, y = 100 })
            h.truthy(math.abs(b - math.pi / 2) < 1e-9, "west is +pi/2, got " .. tostring(b))
        end)
        h.it("points a negative quarter turn for due east", function()
            local b = Trip.Bearing(origin, { c = 1, x = 0, y = -100 })
            h.truthy(math.abs(b + math.pi / 2) < 1e-9, "east is -pi/2, got " .. tostring(b))
        end)
        h.it("gives up across continents and on the same spot", function()
            h.eq(Trip.Bearing(origin, { c = 0, x = 100, y = 0 }), nil)
            h.eq(Trip.Bearing(origin, { c = 1, x = 0, y = 0 }), nil)
            h.eq(Trip.Bearing(nil, origin), nil)
            h.eq(Trip.Bearing(origin, nil), nil)
        end)
    end)

    h.describe("Trip.ArrowAngle", function()
        h.it("points straight up when the target is dead ahead", function()
            h.eq(Trip.ArrowAngle(1.2, 1.2), 0)
        end)
        h.it("turns by the difference between bearing and facing", function()
            h.eq(Trip.ArrowAngle(1.0, 0.25), Trip.ROTATION_SIGN * 0.75)
        end)
        h.it("gives up when the client will not say which way you face", function()
            h.eq(Trip.ArrowAngle(1.0, nil), nil)
            h.eq(Trip.ArrowAngle(nil, 1.0), nil)
        end)
    end)

    h.describe("Trip.Remaining", function()
        local result = { steps = {
            { kind = "ride", seconds = 100, to = { c = 1, x = 0, y = 0 } },
            { kind = "zeppelin", seconds = 240, to = { c = 1, x = 0, y = 0 } },
            { kind = "ride", seconds = 50, to = { c = 1, x = 0, y = 0 } },
        } }
        h.it("adds the ground still to cover to every step after it", function()
            -- 70 yards from the first step's target at 7 yards a second is 10s,
            -- then 240 and 50 as planned.
            local left = Trip.Remaining(result, 1, { c = 1, x = 70, y = 0 }, 7)
            h.truthy(math.abs(left - 300) < 0.001, "expected 300, got " .. tostring(left))
        end)
        h.it("uses the planned seconds for a step you cannot walk", function()
            local left = Trip.Remaining(result, 2, { c = 1, x = 9999, y = 0 }, 7)
            h.eq(left, 290, "a zeppelin's time does not shrink as you stand nearer")
        end)
        h.it("is just the last step at the end", function()
            local left = Trip.Remaining(result, 3, { c = 1, x = 0, y = 0 }, 7)
            h.eq(left, 0)
        end)
        h.it("gives up on an index that is not there", function()
            h.eq(Trip.Remaining(result, 9, { c = 1, x = 0, y = 0 }, 7), nil)
            h.eq(Trip.Remaining(nil, 1, nil, 7), nil)
        end)
    end)
```

If `test/test_trip.lua` does not already have `Trip` in scope, take it from the loaded namespace exactly as the existing tests in that file do.

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: failures naming `Trip.Bearing`, `Trip.ArrowAngle`, `Trip.Remaining` as nil.

- [ ] **Step 3: Implement**

Add to `GoblinPS/Trip.lua`, above `return Trip`:

```lua
-- Which way to turn the arrow. Geo puts world x north and world y west, and
-- GetPlayerFacing uses the same frame: 0 north, growing counter-clockwise. So
-- bearing minus facing is the turn, and SetRotation turns counter-clockwise.
-- The sign is NOT confirmed in game; if the arrow mirrors, flip this and
-- nothing else.
Trip.ROTATION_SIGN = 1

-- Radians from `from` to `to`, in the same frame as GetPlayerFacing. Nil when
-- the question has no answer: different continents, or the very same spot.
function Trip.Bearing(from, to)
    if not from or not to or from.c ~= to.c then
        return nil
    end
    local dx, dy = to.x - from.x, to.y - from.y
    if dx == 0 and dy == 0 then
        return nil
    end
    return math.atan2(dy, dx)
end

-- What to hand texture:SetRotation for an arrow drawn pointing up.
function Trip.ArrowAngle(bearing, facing)
    if not bearing or not facing then
        return nil
    end
    return Trip.ROTATION_SIGN * (bearing - facing)
end

-- Yards from a world position to a step's target, or nil.
function Trip.DistanceTo(pos, step)
    if not pos or not step or not step.to then
        return nil
    end
    local d = ns.Geo.Distance(pos, step.to)
    return d < math.huge and d or nil
end

-- Seconds left for the whole journey: the ground still to cover on the step
-- you are on, plus every step after it as planned. Only a ride shrinks as you
-- walk; a zeppelin takes as long whether you are beside it or not.
function Trip.Remaining(result, index, pos, speed)
    local step = result and result.steps and result.steps[index]
    if not step then
        return nil
    end
    local total = 0
    for i = index + 1, #result.steps do
        total = total + (result.steps[i].seconds or 0)
    end
    local d = step.kind == "ride" and speed and speed > 0 and Trip.DistanceTo(pos, step) or nil
    return total + (d and d / speed or (step.kind == "ride" and 0 or step.seconds or 0))
end
```

- [ ] **Step 4: Run to verify they pass**

Run the Lua suite. Expected: all green, 185 plus 14 new.

- [ ] **Step 5: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 6: Commit**

```bash
git add GoblinPS/Trip.lua test/test_trip.lua
git commit -m "Trip: bearing, arrow angle and time left" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: What the client has to tell us

**Files:**
- Modify: `GoblinPS/API.lua`
- Modify: `GoblinPS/Core.lua` (expose `Core.Here`)
- Modify: `test/fake_frames.lua` (model `SetRotation`)
- Test: `test/test_ui.lua` (the fake API gains the new calls)

**Interfaces:**
- Produces, for task 5:
  - `API.PlayerFacing()` returns radians or nil.
  - `API.OnTaxi()` returns true or false, never nil.
  - `API.OnTripEvent(callback)` calls `callback(kind)` with `"zone"` or `"landed"`.
  - `Core.Here()` returns `{ name = "You", c, x, y, map, mx, my }` or nil, the same table the planner already plans from.

`API.lua` is the only file allowed to touch these. Every event below is confirmed present in `docs/research/2026-09-19-api-and-data-findings.md`; registering a name this client does not know is a hard error, so add none.

- [ ] **Step 1: Write the failing test**

In `test/test_ui.lua`, extend the scripted `ns.API` table with the three new calls, beside the existing ones:

```lua
        PlayerFacing = function() return facing end,
        OnTaxi = function() return onTaxi end,
        OnTripEvent = function(callback) tripCallbacks[#tripCallbacks + 1] = callback end,
```

and declare their state near `local level = 60`:

```lua
    local facing, onTaxi, tripCallbacks = 0, false, {}
```

Then add, beside the other describe blocks:

```lua
    h.describe("the fake frames model what the dash needs", function()
        h.it("a texture can be rotated", function()
            local f = CreateFrame("Frame")
            local t = f:CreateTexture(nil, "ARTWORK")
            t:SetRotation(1.25)
            h.eq(t.rotation, 1.25, "the fake must record the angle so tests can read it")
        end)
        h.it("a texture records its coordinates, tint and layer", function()
            local f = CreateFrame("Frame")
            local t = f:CreateTexture(nil, "ARTWORK")
            t:SetTexCoord(0, 0.75, 0, 0.5)
            h.eq(t.texCoord[2], 0.75, "SetTexCoord must record, not be swallowed")
            h.eq(t.texCoord[4], 0.5)
            t:SetVertexColor(1, 0, 0, 1)
            h.eq(t.vertexColor[1], 1)
            t:SetDrawLayer("OVERLAY")
            h.eq(t.drawLayer, "OVERLAY")
        end)
    end)
```

- [ ] **Step 2: Run to verify it fails**

Run the Lua suite. Expected: FAIL with the strict fake's `unknown widget method` error for `SetRotation`.

- [ ] **Step 3: Teach the fake to rotate**

In `test/fake_frames.lua`, beside the other texture methods, add:

```lua
    SetRotation = function(self, radians) self.rotation = radians end,
    SetVertexColor = function(self, r, g, b, a) self.vertexColor = { r, g, b, a } end,
    SetDrawLayer = function(self, layer) self.drawLayer = layer end,
```

and change `SetTexCoord` so it **records** instead of being swallowed. Today it
sits in the accepted-and-ignored list at the top of the file, which means
`texture.texCoord` is never set and task 6 could not check its own work:

```lua
    SetTexCoord = function(self, l, r, t, b) self.texCoord = { l, r, t, b } end,
```

Remove `SetTexCoord` from the ignored list when you add the recording version,
or the ignored entry will win.

Match the file's existing style for texture methods exactly; the fake is strict
on purpose, so an unmodelled PascalCase method raises rather than silently
passing. Tasks 4 and 6 call `SetVertexColor` and `SetDrawLayer`, so without
these three additions they would fail on the fake, not on their own behaviour.

- [ ] **Step 4: Add the client calls**

In `GoblinPS/API.lua`, beside `API.Level`:

```lua
-- Which way the player faces, in radians: 0 north, growing counter-clockwise.
-- Documented Nilable, and it has no answer in some places, so callers must
-- cope with nil by hiding the arrow rather than pointing it somewhere wrong.
function API.PlayerFacing()
    if not GetPlayerFacing then
        return nil
    end
    return GetPlayerFacing()
end

-- On a flight path, where the player steers nothing and straying is meaningless.
function API.OnTaxi()
    return UnitOnTaxi and UnitOnTaxi("player") and true or false
end
```

and beside `API.OnTaxiMapOpened`:

```lua
-- The moments worth re-checking an active trip, beyond the dash's own ticking:
-- crossing into a new zone, and a flight ending. Calls back with "zone" or
-- "landed". All four events are confirmed present on this build; do not add
-- others without checking the forever branch first.
function API.OnTripEvent(callback)
    local f = CreateFrame("Frame")
    f:RegisterEvent("ZONE_CHANGED")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("PLAYER_CONTROL_LOST")
    f:RegisterEvent("PLAYER_CONTROL_GAINED")
    f:SetScript("OnEvent", function(_, event)
        callback(event == "PLAYER_CONTROL_GAINED" and "landed" or "zone")
    end)
end
```

Add `GetPlayerFacing` and `UnitOnTaxi` to `API.SelfCheck`'s list, and to both `.luacheckrc` and `.luarc.json`.

In `GoblinPS/Core.lua`, make the existing local `here` reachable:

```lua
-- Where the player stands, as a place the router understands. Nil inside an
-- instance, where the client gives no useful position.
function Core.Here() return here() end
```

- [ ] **Step 5: Run the tests and the linters**

Run the Lua suite, luacheck and the language server. Expected: green, zero warnings. `PlayerFacing`, `OnTaxi` and `OnTripEvent` are not called by anything yet; that is task 5.

- [ ] **Step 6: Commit**

```bash
git add GoblinPS/API.lua GoblinPS/Core.lua test/fake_frames.lua test/test_ui.lua .luacheckrc .luarc.json
git commit -m "API: facing, taxi state and the arrival events" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: The device, on flat colours

**Files:**
- Create: `GoblinPS/Dash.lua`
- Modify: `GoblinPS/GoblinPS.toc`
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `ns.Widgets` (`Panel`, `Text`, `Button`, `Fill`, `COLOR`), `ns.Core.Position` and `ns.Core.SavePosition`.
- Produces, for task 5: `Dash.Start(plan)`, `Dash.Stop()`, `Dash.Debug()` returning `ui, state`, and `Dash.SIZE = { 200, 250 }`.

This task draws the device and nothing else: no trip, no ticking, no events. It must look right and survive dragging before it is given a job.

The layout, top to bottom, inside a 200 by 250 frame:

- a round screen area, 180 square, `screen` coloured, at the top;
- the arrow, 90 square, centred on that screen, drawn from `Interface\Buttons\WHITE8X8` tinted green until task 6 gives it real art;
- the distance, large, centred under the screen;
- the ETA plate: one line, centred;
- the current step, two lines' worth of width, wrapping off;
- the next step, dimmer;
- a small "Stop" button at the bottom right.

- [ ] **Step 1: Write the failing test**

Add to `test/test_ui.lua`, beside its other describe blocks:

```lua
-- Smoke test of the dash unit against test/fake_frames.lua. It catches our own
-- mistakes: nil calls, text in the wrong widget, a FontString with one anchor.
-- Real frame behaviour is checked in game from docs/manual-test-checklist.md.
return function(h, loaded)
    local ns = loaded.ns
    local Dash = ns.Dash

    local plan = {
        level = 60,
        result = {
            seconds = 600,
            steps = {
                { kind = "ride", seconds = 200, to = { name = "the North Gate", c = 1, x = 0, y = 0 } },
                { kind = "zeppelin", seconds = 240, to = { name = "East Dock", c = 1, x = 0, y = 0 } },
                { kind = "ride", seconds = 160, to = { name = "Delta", c = 1, x = 0, y = 0 } },
            },
        },
    }

    h.describe("the dash unit", function()
        h.it("opens on Start and shows the first step and the one after", function()
            Dash.Start(plan)
            local ui, state = Dash.Debug()
            h.truthy(ui.frame:IsShown())
            h.eq(state.index, 1)
            h.eq(ui.step:GetText(), "Ride to the North Gate")
            h.eq(ui.next:GetText(), "then Zeppelin to East Dock")
        end)
        h.it("says nothing follows the last step", function()
            local ui, state = Dash.Debug()
            state.index = 3
            Dash.Refresh()
            h.eq(ui.step:GetText(), "Ride to Delta")
            h.eq(ui.next:GetText(), "")
            state.index = 1
            Dash.Refresh()
        end)
        h.it("every line of text is bounded", function()
            local ui = Dash.Debug()
            for _, name in ipairs({ "step", "next", "distance", "eta" }) do
                local fs = ui[name]
                h.truthy(fs.points and #fs.points >= 2,
                         name .. " needs two horizontal anchors or it will draw past the frame")
            end
        end)
        h.it("dragging saves the position", function()
            local ui = Dash.Debug()
            ui.frame:SetPoint("TOP", UIParent, "BOTTOM", 7, -11)
            ui.frame.scripts.OnDragStart(ui.frame)
            ui.frame.scripts.OnDragStop(ui.frame)
            local p = GoblinPSDB.positions.dash
            h.eq(p.point, "TOP")
            h.eq(p.relativePoint, "BOTTOM")
            h.eq(p.x, 7)
            h.eq(p.y, -11)
        end)
        h.it("Stop closes it", function()
            local ui = Dash.Debug()
            Dash.Stop()
            h.falsy(ui.frame:IsShown())
        end)
        h.it("Start with no steps does not open", function()
            Dash.Start({ result = { steps = {} } })
            h.falsy(Dash.Debug().frame:IsShown())
        end)
    end)
end
```

- [ ] **Step 2: Run to verify it fails**

Add `"Dash"` to the module list inside `test/test_ui.lua` (the `for _, file in ipairs({...})` line), after `"Planner"` and before `"MinimapButton"`. Run the Lua suite. Expected: FAIL, `ns.Dash` is nil.

- [ ] **Step 3: Write the device**

Create `GoblinPS/Dash.lua`. It owns one frame and never builds a second set of widgets:

```lua
local _, ns = ...

-- The dash unit: a small draggable device showing the step you are on, an
-- arrow that turns to point at it, how far is left and how long. Built on flat
-- colours; task 6 lays the art over them, and a texture that does not load
-- must leave this readable.
local Dash = {}
ns.Dash = Dash

local W = ns.Widgets

Dash.SIZE = { 200, 250 }
local PAD, SCREEN = 10, 180

local ui              -- built on first Start
local state = {}      -- plan, index, best (closest yet to the current target)

local function stepText(step)
    return step and ns.Route.StepText(step) or ""
end

-- Draws whatever is in `state`. Safe to call at any time.
function Dash.Refresh()
    if not ui or not state.plan then
        return
    end
    local steps = state.plan.result and state.plan.result.steps or {}
    local step = steps[state.index]
    if not step then
        return
    end
    ui.step:SetText(stepText(step))
    local following = steps[state.index + 1]
    ui.next:SetText(following and ("then " .. stepText(following)) or "")
end

local function build()
    local f = W.Panel(UIParent, "body", "brass", 3)
    f:SetSize(Dash.SIZE[1], Dash.SIZE[2])
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        ns.Core.SavePosition("dash", point, relativePoint, x, y)
    end)
    f:Hide()

    local screen = W.Panel(f, "screen", "steel", 2)
    screen:SetSize(SCREEN, SCREEN)
    screen:SetPoint("TOP", 0, -PAD)

    local arrow = screen:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(90, 90)
    arrow:SetPoint("CENTER")
    arrow:SetTexture("Interface\\Buttons\\WHITE8X8")
    arrow:SetVertexColor(unpack(W.COLOR.green))

    local distance = W.Text(f, "green", "GameFontNormalLarge", "CENTER")
    distance:SetPoint("TOPLEFT", screen, "BOTTOMLEFT", 0, -4)
    distance:SetPoint("TOPRIGHT", screen, "BOTTOMRIGHT", 0, -4)

    local eta = W.Text(f, "dim", "GameFontNormalSmall", "CENTER")
    eta:SetPoint("TOPLEFT", distance, "BOTTOMLEFT", 0, -2)
    eta:SetPoint("TOPRIGHT", distance, "BOTTOMRIGHT", 0, -2)

    local step = W.Text(f, "green", "GameFontNormalSmall", "CENTER")
    step:SetPoint("TOPLEFT", eta, "BOTTOMLEFT", 0, -6)
    step:SetPoint("TOPRIGHT", eta, "BOTTOMRIGHT", 0, -6)

    local following = W.Text(f, "dim", "GameFontHighlightSmall", "CENTER")
    following:SetPoint("TOPLEFT", step, "BOTTOMLEFT", 0, -2)
    following:SetPoint("TOPRIGHT", step, "BOTTOMRIGHT", 0, -2)

    local stop = W.Button(f, "Stop", 48, 20, function() Dash.Stop() end)
    stop:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    ui = { frame = f, screen = screen, arrow = arrow, distance = distance,
           eta = eta, step = step, next = following, stop = stop }
    ns.Core.CloseOnEscape(f, "GoblinPSDash")
end

-- Begin a trip. A plan with no steps is not a trip, and opens nothing.
function Dash.Start(plan)
    if not ui then
        build()
        local p = ns.Core.Position("dash")
        ui.frame:ClearAllPoints()
        if p then
            ui.frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
        else
            ui.frame:SetPoint("CENTER", UIParent, "CENTER", -260, 0)
        end
    end
    local steps = plan and plan.result and plan.result.steps or {}
    if #steps == 0 then
        return
    end
    state.plan, state.index, state.best = plan, 1, nil
    Dash.Refresh()
    ui.frame:Show()
end

function Dash.Stop()
    state.plan, state.index, state.best = nil, nil, nil
    if ui then
        ui.frame:Hide()
    end
end

-- For the desktop smoke test only.
function Dash.Debug()
    return ui, state
end

return Dash
```

Add to `GoblinPS/GoblinPS.toc`, after `Planner.lua` and before `MinimapButton.lua`:

```
Dash.lua
```

and `Data\Art.lua` after `Data\Zones.lua`. Set `## Version: 2026.09.20.2`.

- [ ] **Step 4: Run the tests to verify they pass**

Run the Lua suite. Expected: green.

- [ ] **Step 5: Lint**

Run luacheck and the language server. Expected: zero warnings. Add `GoblinPSDash` to both config files.

- [ ] **Step 6: Commit**

```bash
git add GoblinPS/Dash.lua GoblinPS/GoblinPS.toc test/test_ui.lua .luacheckrc .luarc.json
git commit -m "Dash unit: the device on flat colours" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: Making it drive

**Files:**
- Modify: `GoblinPS/Dash.lua`
- Modify: `GoblinPS/Core.lua`
- Modify: `GoblinPS/Planner.lua`
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `Trip.Check`, `Trip.Bearing`, `Trip.ArrowAngle`, `Trip.DistanceTo`, `Trip.Remaining` (task 2); `API.PlayerFacing`, `API.OnTaxi`, `API.OnTripEvent`, `Core.Here` (task 3); `Dash.Start`, `Dash.Stop`, `Dash.Refresh` (task 4).
- Produces: `Dash.Tick(event)`, called by the frame's own OnUpdate and by trip events. Pressing GO closes the planner and opens the dash.

The rules, all of which `Trip.Check` already decides:

- **advance** moves to the next step; on the last step the journey is over: say "Arrived" and stop.
- **recalculate** replans from where the player now stands and starts again at step 1.
- **pause** means the client will not say where the player is, usually an instance. Say "Waiting..." and change nothing.
- **stay** redraws distance, time left and the arrow.

Two things `Trip.Check` needs that only the caller can keep: `state.best`, the closest the player has been to this step's target, which is how straying is noticed; and whether the player is on a taxi.

Ticking every frame is wasteful and jittery. Tick on a timer of `Dash.TICK` seconds, and immediately on a trip event.

- [ ] **Step 1: Write the failing tests**

Append to `test/test_ui.lua`, beside the dash tests from task 4.

`test/test_ui.lua` already scripts where the player stands: its `where` table
feeds `PlayerMapPosition`, which `Core.Here` reads through. Use that rather
than inventing a new seam, and add two locals beside `level` for the facts
task 3 introduced:

```lua
    local facing, onTaxi = 0, false
```

wired into the scripted `ns.API` as:

```lua
        PlayerFacing = function() return facing end,
        OnTaxi = function() return onTaxi end,
        OnTripEvent = function(callback) tripCallbacks[#tripCallbacks + 1] = callback end,
```

The fake world's maps are 10000 yards square, with `world x = 10000 - my * 10000`
and `world y = 10000 - mx * 10000`. A helper keeps that arithmetic out of every
test, and keeps `Core.Here` and `Geo.ToWorld` in the path being exercised:

```lua
    -- Stand the player at a world position on map 1.
    local function standAt(x, y)
        where.map, where.mx, where.my = 1, (10000 - y) / 10000, (10000 - x) / 10000
    end
```

The steps in `plan` all target world `(0, 0)` on continent 1, so `standAt(0, 0)`
is "arrived" and larger values are further away.

```lua
    h.describe("the dash unit drives the trip", function()
        h.it("advances when you reach the step's target", function()
            Dash.Start(plan)
            local ui, state = Dash.Debug()
            standAt(5000, 0); facing = 0
            Dash.Tick("tick")
            h.eq(state.index, 1, "still on the way")
            standAt(10, 0)
            Dash.Tick("tick")
            h.eq(state.index, 2, "arriving moves on")
            h.eq(ui.step:GetText(), "Zeppelin to East Dock")
        end)

        h.it("moves Blizzard's pin onto each new step, not just the first", function()
            Dash.Start(plan)
            local _, state = Dash.Debug()
            local before = #pins
            standAt(10, 0)
            Dash.Tick("tick")
            h.eq(state.index, 2)
            h.truthy(#pins > before, "the spec puts the pin on the step you are on")
        end)

        h.it("says Arrived and stops at the end", function()
            Dash.Start(plan)
            local ui, state = Dash.Debug()
            state.index = #plan.result.steps
            standAt(0, 0)
            Dash.Tick("tick")
            h.eq(ui.step:GetText(), "Arrived.")
            h.falsy(state.plan, "the trip is over")
        end)

        h.it("shows the distance and the time left while travelling", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            standAt(700, 0)
            Dash.Tick("tick")
            h.eq(ui.distance:GetText(), "700 yd")
            h.truthy(ui.eta:GetText():find("min", 1, true), ui.eta:GetText())
        end)

        h.it("turns the arrow toward the step and hides it when facing is unknown", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            standAt(-100, 0); facing = 0
            Dash.Tick("tick")
            h.truthy(ui.arrow:IsShown())
            h.eq(ui.arrow.rotation, 0, "the target is due north of us and we face north")
            facing = nil
            Dash.Tick("tick")
            h.falsy(ui.arrow:IsShown(), "never point somewhere we cannot work out")
            facing = 0
        end)

        h.it("does not advance or stray while on a zeppelin", function()
            Dash.Start(plan)
            local _, state = Dash.Debug()
            state.index = 2
            onTaxi = true
            standAt(0, 0)
            Dash.Tick("tick")
            h.eq(state.index, 2, "aboard, arriving at the target means nothing")
            onTaxi = false
        end)

        h.it("waits, without losing the trip, when the client will not place you", function()
            Dash.Start(plan)
            local ui, state = Dash.Debug()
            where.map = nil
            Dash.Tick("tick")
            h.eq(ui.distance:GetText(), "Waiting...")
            h.truthy(state.plan, "an instance must not end the trip")
            where.map, where.mx, where.my = 1, 0.89, 0.9
        end)

        h.it("does nothing at all when no trip is running", function()
            Dash.Stop()
            standAt(10, 0)
            Dash.Tick("tick")           -- must not error
            h.falsy(Dash.Debug().frame:IsShown())
        end)
    end)
```

Leave `where` as the other tests expect it when your block finishes; the suite
shares one planner and runs in order.

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: FAIL, `Dash.Tick` is nil.

- [ ] **Step 3: Implement the tick**

In `GoblinPS/Dash.lua`, add above `Dash.Debug`:

```lua
Dash.TICK = 0.5        -- seconds between checks; every frame is jitter, not accuracy

local function yards(d)
    return ("%d yd"):format(math.floor(d + 0.5))
end

-- Point the arrow at the current step, or hide it. The client can decline to
-- say which way the player faces, and an arrow pointing the wrong way is worse
-- than no arrow at all.
local function aimArrow(pos, step)
    local angle = ns.Trip.ArrowAngle(ns.Trip.Bearing(pos, step.to), ns.API.PlayerFacing())
    if not angle then
        ui.arrow:Hide()
        return
    end
    ui.arrow:SetRotation(angle)
    ui.arrow:Show()
end

local function finish()
    ui.step:SetText("Arrived.")
    ui.next:SetText("")
    ui.distance:SetText("")
    ui.eta:SetText("")
    ui.arrow:Hide()
    state.plan, state.index, state.best = nil, nil, nil
end

-- One look at where the player is against the step they are on. `event` is
-- "tick", "zone" or "landed" and is handed straight to Trip.Check.
function Dash.Tick(event)
    if not ui or not state.plan then
        return
    end
    local steps = state.plan.result.steps
    local step = steps[state.index]
    if not step then
        return
    end
    local pos = ns.Core.Here()
    local verdict = ns.Trip.Check(step, {
        pos = pos, onTaxi = ns.API.OnTaxi(), event = event, best = state.best,
    })

    if verdict == "pause" then
        ui.distance:SetText("Waiting...")
        ui.eta:SetText("")
        ui.arrow:Hide()
        return
    end
    if verdict == "advance" then
        if state.index >= #steps then
            finish()
            return
        end
        state.index, state.best = state.index + 1, nil
        Dash.Refresh()
        ns.Core.PinStep(steps[state.index])   -- the pin follows the step you are on
        return
    end
    if verdict == "recalculate" then
        local replanned = ns.Core.PlanRoute(state.plan.to, pos)
        if replanned.result and #replanned.result.steps > 0 then
            state.plan, state.index, state.best = replanned, 1, nil
            ui.next:SetText("Recalculating...")
            Dash.Refresh()
        end
        return
    end

    local d = ns.Trip.DistanceTo(pos, step)
    if d then
        state.best = math.min(state.best or d, d)
        ui.distance:SetText(yards(d))
        aimArrow(pos, step)
    else
        ui.distance:SetText("")
        ui.arrow:Hide()
    end
    local travel = ns.Travel.For(state.plan.level)
    local left = ns.Trip.Remaining(state.plan.result, state.index, pos, travel.speed)
    ui.eta:SetText(left and ns.Route.FormatTime(left) or "")
end
```

In `build()`, after the frame is made, drive it:

```lua
    local since = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        since = since + elapsed
        if since >= Dash.TICK then
            since = 0
            Dash.Tick("tick")
        end
    end)
    ns.API.OnTripEvent(function(kind) Dash.Tick(kind) end)
```

Register the trip event **once**, inside `build()`, not on every `Start`.

In `GoblinPS/Core.lua`, make GO start a trip. Replace the body of `Core.Go`:

```lua
-- Blizzard's map pin and on-screen arrow for one step. Spec decision 3 puts
-- the pin on the step you are ON, so the dash calls this again each time it
-- advances, not only when GO is pressed. Quiet: only GO explains itself.
function Core.PinStep(step)
    if not step or step.kind == "hearth" or not step.to.map then
        return false
    end
    return API.SetWaypoint(step.to.map, step.to.mx, step.to.my) and true or false
end

-- Go: pin the first step, say what happened, and hand the plan to the dash
-- unit, which takes over from here.
function Core.Go(plan)
    local step = plan and plan.result and plan.result.steps[1]
    if not step then
        return
    end
    if step.kind == "hearth" then
        say("Use your hearthstone, then press GO again.")
    elseif Core.PinStep(step) then
        say("Pin set: " .. Route.StepText(step) .. ".")
    else
        say("Can't put a map pin there. " .. Route.StepText(step) .. ".")
    end
    ns.Dash.Start(plan)
end
```

In `GoblinPS/Planner.lua`, close the planner when GO starts the trip. In the GO button's handler, after `ns.Core.Go(state.plan)`:

```lua
        if ui.frame:IsShown() and state.plan and state.plan.result
           and #state.plan.result.steps > 0 then
            ui.frame:Hide()
        end
```

The Garmin model: plan the route, then drive. `/gps` reopens the planner without ending the trip.

- [ ] **Step 4: Run to verify they pass**

Run the Lua suite. Expected: green.

- [ ] **Step 5: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 6: Commit**

```bash
git add GoblinPS/Dash.lua GoblinPS/Core.lua GoblinPS/Planner.lua test/
git commit -m "Dash unit: advance, recalculate and arrive" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: The art over the colours

**Files:**
- Modify: `GoblinPS/Dash.lua`
- Modify: `GoblinPS/SelfTest.lua`
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `ns.Data.Art` from task 1, shaped `{ [name] = { file, l, r, t, b } }`.
- Produces: nothing new. The device looks like the mockup and still works without a single texture.

The stacking order, from Codex's handoff: **screen, compass, arrow, body**. The body has a transparent hole; the screen shows through it. Draw layers accordingly: screen `BACKGROUND`, compass `BORDER`, arrow `ARTWORK`, body `OVERLAY`.

`SetTexture` returns whether the file loaded. That return is the fallback test: if it is false, leave the flat colour showing and never hide it behind an invisible texture.

- [ ] **Step 1: Write the failing test**

Append to `test/test_ui.lua`:

```lua
    h.describe("the dash art", function()
        h.it("lays every part on with the coordinates the tool generated", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            for _, pair in ipairs({ { ui.bodyArt, "dash-body" }, { ui.screenArt, "dash-screen" },
                                    { ui.compass, "dash-compass" }, { ui.arrow, "arrow" } }) do
                local texture, name = pair[1], pair[2]
                local art = ns.Data.Art[name]
                h.truthy(art, name .. " is missing from the generated table")
                h.eq(texture:GetTexture(), "Interface\\AddOns\\GoblinPS\\Media\\" .. art.file)
                h.eq(texture.texCoord[1], art.l)
                h.eq(texture.texCoord[2], art.r)
            end
        end)
        h.it("keeps a working device when a texture will not load", function()
            Fake.missingTextures["Interface\\AddOns\\GoblinPS\\Media\\dash-body"] = true
            Dash.Stop()
            Dash.Start(plan)
            local ui = Dash.Debug()
            h.truthy(ui.frame:IsShown(), "a missing texture must not take the window with it")
            h.truthy(ui.step:GetText() ~= "", "the directions must still be readable")
            Fake.missingTextures["Interface\\AddOns\\GoblinPS\\Media\\dash-body"] = nil
        end)
    end)
```

`Fake.missingTextures` already exists in `test/fake_frames.lua`; it is how the planner's texture fallback is tested. If `texCoord` is not recorded by the fake's `SetTexCoord`, record it there the same way `SetRotation` was added in task 3.

- [ ] **Step 2: Run to verify it fails**

Run the Lua suite. Expected: FAIL, `ui.bodyArt` is nil.

- [ ] **Step 3: Lay the art on**

In `GoblinPS/Dash.lua`, add a helper and use it in `build()`:

```lua
local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"

-- Lay a generated part over a flat colour. Returns the texture, or nil when
-- the part is unknown or the file will not load, leaving the colour showing.
local function art(parent, name, layer)
    local part = ns.Data.Art and ns.Data.Art[name]
    if not part then
        return nil
    end
    local t = parent:CreateTexture(nil, layer)
    if not t:SetTexture(MEDIA .. part.file) then
        t:Hide()
        return nil
    end
    t:SetTexCoord(part.l, part.r, part.t, part.b)
    t:SetAllPoints(parent)
    return t
end
```

Then in `build()`, after the screen panel and before the arrow:

```lua
    local screenArt = art(screen, "dash-screen", "BACKGROUND")
    local compass = art(screen, "dash-compass", "BORDER")
```

and after the arrow is created, replace its placeholder texture:

```lua
    local arrowPart = ns.Data.Art and ns.Data.Art["arrow"]
    if arrowPart and arrow:SetTexture(MEDIA .. arrowPart.file) then
        arrow:SetTexCoord(arrowPart.l, arrowPart.r, arrowPart.t, arrowPart.b)
        arrow:SetVertexColor(1, 1, 1)
    end
```

and after everything else, the body on top:

```lua
    local bodyArt = art(f, "dash-body", "OVERLAY")
```

The ETA plate is its own part, sitting behind the time-left line rather than
over the device, so it is laid on its own small frame:

```lua
    local plate = CreateFrame("Frame", nil, f)
    plate:SetPoint("TOPLEFT", eta, "TOPLEFT", -6, 4)
    plate:SetPoint("BOTTOMRIGHT", eta, "BOTTOMRIGHT", 6, -4)
    local plateArt = art(plate, "dash-eta-plate", "BACKGROUND")
    eta:SetDrawLayer("OVERLAY")
```

Add `screenArt`, `compass`, `bodyArt` and `plateArt` to the `ui` table so the
test can reach them, and include `dash-eta-plate` in the loop in step 1's first
test. All five parts the tool builds must be used; a texture generated and never
drawn is weight in the addon for nothing.

The compass turns with the player, not with the arrow: in `aimArrow`, after setting the arrow's rotation, add

```lua
    if ui.compass then
        ui.compass:SetRotation(-(ns.API.PlayerFacing() or 0))
    end
```

so north on the ring stays north in the world.

In `GoblinPS/SelfTest.lua`, add the five shipped textures to `SelfTest.TEXTURES`, built from `ns.Data.Art` rather than typed by hand, so the list cannot drift from what the tool produced.

- [ ] **Step 4: Run to verify it passes**

Run the Lua suite. Expected: green.

- [ ] **Step 5: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 6: Commit**

```bash
git add GoblinPS/Dash.lua GoblinPS/SelfTest.lua test/
git commit -m "Dash unit: the art over the colours" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: Documents

**Files:**
- Modify: `docs/superpowers/specs/2026-09-19-goblinps-design.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: The spec**

In decision 3, replace "shown after Go" with what was actually built, and record that an active trip is **not saved**: `/reload` ends it, and the planner's recents make restarting one click. Note that the planner closes when GO starts a trip.

In decision 5, note that `tools/make_art.py` builds shipped textures and generates `Data/Art.lua`, and that the authoring manifest in `images/parts/` is not the shipped one.

- [ ] **Step 2: The checklist**

Add a `## Dash unit (plan 4)` section, with these items:

```
- [ ] GO closes the planner and opens the dash; /gps reopens the planner and
      the trip keeps running
- [ ] The arrow points at the current step. Turn on the spot: it should stay
      pointing at the same place in the world. **If it turns the wrong way,
      flip Trip.ROTATION_SIGN and nothing else**
- [ ] The compass ring's N stays north as you turn
- [ ] Blizzard's map pin moves to each new step as the dash advances, not
      only to the first one when GO is pressed
- [ ] Walk to the first step's target: the dash advances to the next step
- [ ] Walk away from the target for 400 yards: it says Recalculating and
      replans from where you stand
- [ ] Take a zeppelin: nothing advances or recalculates while aboard
- [ ] Land from a flight: it recalculates rather than sitting on a step you
      have already finished
- [ ] Enter an instance: the dash says Waiting and keeps the trip; leave the
      instance and it carries on
- [ ] Reach the last step: it says Arrived and the device closes
- [ ] Drag the dash; its position survives /reload. /reload mid-trip ends the
      trip, by design
- [ ] The five dash textures load: /gps selftest names them. If one FAILS,
      the device must still be readable on its flat colours
- [ ] At a UI scale of 0.64 and of 1.0 the device is legible and nothing
      overlaps
```

- [ ] **Step 3: CLAUDE.md**

Add `GoblinPS/Dash.lua` and `GoblinPS/Data/Art.lua` to the layout map, and `tools/make_art.py`. Update the status line: plan 4 built, plan 5 the route strip next.

- [ ] **Step 4: Commit**

```bash
git add docs/ CLAUDE.md
git commit -m "Docs: the dash unit" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Notes for the reviewer

- **The arrow's sign is a guess.** The maths is derived in task 2's comments and the frames line up on paper, but `SetRotation`'s direction is not confirmed on this client. `Trip.ROTATION_SIGN` exists so the in-game fix is one character. Do not reject the task for this; check that the constant exists and the checklist names it.
- **`state.best` is the caller's job.** `Trip.Check` cannot notice straying without it. Verify it is reset to nil on every advance and recalculate, or the player will be told they have strayed the moment they start a new step.
- **The trip event is registered once**, in `build()`. Registering it in `Start` would stack a callback per journey.
- **Shipped textures are not the authoring TGAs.** If any task copies `images/parts/*.tga` into `GoblinPS/Media/`, reject it: that is 49 MiB of pixels nobody sees, and the repository deliberately gitignores them.
- **A missing texture must never hide the directions.** Task 6's second test is the one that matters.

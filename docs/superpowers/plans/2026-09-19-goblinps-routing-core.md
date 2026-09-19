# GoblinPS Routing Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A working route planner with no window yet: `/gps to <place>` prints the fastest route from where the character stands, with times, fares and the "discover X" hint, and `/gps probe` settles the design's open in-game questions.

**Architecture:** A Python generator turns wago.tools DB2 tables into Lua data files. Pure Lua modules (`Geo`, `Search`, `Graph`, `Route`, `Trip`) do all the thinking and are unit-tested on the desktop through lupa. `API.lua` is the only file that touches Blizzard globals; `Core.lua` wires a slash command to it.

**Tech Stack:** Lua 5.1 (WoW Forever client 1.60.1.69913, interface 16001), no libraries. Python 3 standard library for the generator. Tests: lupa for Lua, `unittest` for Python. Lint: luacheck, lua-language-server.

**Spec:** `docs/superpowers/specs/2026-09-19-goblinps-design.md`. Read it and `CLAUDE.md` first.

**This is plan 1 of 2.** Plan 2 (planner window, schematic map, dash unit, minimap button, saved variables, self-test, art) is written after this one is running in game, because it builds on these interfaces and on what `/gps probe` reports.

## Global Constraints

- Plain Lua 5.1 against the Blizzard API. **No libraries.**
- `GoblinPS/API.lua` is the **only** file that touches Blizzard globals. Every other module is pure.
- Each module opens with `local _, ns = ...` (or `local addonName, ns = ...`) and publishes itself on `ns`.
- **No secure code**: no casting, no protected frames.
- Never save "this flight path is known". The client is the source, read live.
- Never guess an API, event, template or atlas name. Check it in `D:\wow-api\1.60.1.69913` first. This plan registers **no events**.
- Route text is plain and glanceable. No jokes in the directions.
- `GoblinPS/Data/Places.lua`, `Nodes.lua` and `Flights.lua` are **generated**: never edit them by hand. `GoblinPS/Data/Links.lua` is **hand-written**.
- luacheck and lua-language-server stay at zero warnings. A new WoW global goes in both `.luacheckrc` and `.luarc.json`.
- Version `2026.09.19`, written only in the TOC.
- Commit after each task. Do not push. Another agent (Codex) may also commit: re-read a file before editing it.

**Commands** (run from `D:\goblinps`):

Lua tests:

```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```

It prints `N passed, M failed`, then each failure, then `0` or `1`. `test/run.lua` skips module and suite files that do not exist yet, so it works from Task 1 onward.

Python tests: `python -m unittest discover -s test/tools`

luacheck (PowerShell):

```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
$env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
```

Expected: `Total: 0 warnings / 0 errors`.

## File Structure

| File | Responsibility |
|---|---|
| `test/harness.lua`, `test/run.lua` | Desktop test runner (harness copied from LooseEnds) |
| `test/fake_world.lua` | A tiny two-continent world for unit tests |
| `.luacheckrc`, `.luarc.json` | Lint and language-server config |
| `tools/build_graph.py`, `tools/catalog.lock` | Generator and the pinned client build |
| `test/tools/` | Generator tests and CSV fixtures |
| `GoblinPS/Geo.lua` | Map coords to world yards; distance |
| `GoblinPS/Data/Places.lua`, `Nodes.lua`, `Flights.lua` | Generated: zones, flight nodes, flight edges |
| `GoblinPS/Data/Links.lua` | Hand-written docks and boat/zeppelin/tram links |
| `GoblinPS/Search.lua` | Find a destination by name |
| `GoblinPS/Graph.lua` | Stops and edges this character can use |
| `GoblinPS/Route.lua` | Shortest path, hint, step text |
| `GoblinPS/Trip.lua` | Arrival rules (used by the dash unit in plan 2) |
| `GoblinPS/API.lua` | Blizzard globals |
| `GoblinPS/Core.lua`, `GoblinPS/GoblinPS.toc` | Slash command and manifest |

Shared shapes, used across tasks:

- **World place**: `{ name, c, x, y, map, mx, my }`. `c` is the continent (0 Eastern Kingdoms, 1 Kalimdor), `x`/`y` world yards, `map`/`mx`/`my` a UiMap and 0..1 coords on it (for the waypoint in plan 2).
- **Stop**: a world place plus `key` (`"f<nodeID>"`, a dock id, or `START`/`DEST`/`HEARTH`) and `nodeID` for flight stops.
- **Step**: `{ kind, from = stop, to = stop, seconds, copper }`; `kind` is `ride`, `fly`, `zeppelin`, `boat`, `tram` or `hearth`.

---

### Task 1: Test toolchain and `Geo`

**Files:**
- Create: `test/harness.lua` (copy), `test/run.lua`, `test/fake_world.lua`, `test/test_geo.lua`, `.luacheckrc`, `.luarc.json`, `GoblinPS/Geo.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: `ns.Geo.ToWorld(places, map, mx, my) -> c, x, y` (nil when the map is unknown or coords are nil). `ns.Geo.Distance(a, b) -> yards` (`math.huge` across continents or when either is nil). Test suites are `return function(h, loaded) ... end` with `h.describe`, `h.it`, `h.eq`, `h.truthy`, `h.falsy`, and modules at `loaded.ns`.

- [ ] **Step 1: Copy the harness**

```
Copy-Item D:\looseEnds\test\harness.lua D:\goblinps\test\harness.lua
```

(Create `D:\goblinps\test` first if it does not exist.)

- [ ] **Step 2: Write `test/run.lua`**

```lua
-- Run from the repository root through lupa (see CLAUDE.md).
local harness = dofile("test/harness.lua")

-- Same (addonName, ns) the client passes, loaded in TOC order into one ns.
-- API.lua and Core.lua touch Blizzard globals, so they are not loaded here.
local modules = {
    { "Geo",     "GoblinPS/Geo.lua" },
    { "Places",  "GoblinPS/Data/Places.lua" },
    { "Nodes",   "GoblinPS/Data/Nodes.lua" },
    { "Flights", "GoblinPS/Data/Flights.lua" },
    { "Links",   "GoblinPS/Data/Links.lua" },
    { "Search",  "GoblinPS/Search.lua" },
    { "Graph",   "GoblinPS/Graph.lua" },
    { "Route",   "GoblinPS/Route.lua" },
    { "Trip",    "GoblinPS/Trip.lua" },
}

local ns = {}
local loaded = { ns = ns }
for i = 1, #modules do
    local name, path = modules[i][1], modules[i][2]
    local f = io.open(path, "r")
    if f then
        f:close()
        loaded[name] = assert(loadfile(path))("GoblinPS", ns)
    end
end

local suites = {
    "test/test_geo.lua",
    "test/test_search.lua",
    "test/test_graph.lua",
    "test/test_route.lua",
    "test/test_trip.lua",
    "test/test_data.lua",
}

for i = 1, #suites do
    local f = io.open(suites[i], "r")
    if f then
        f:close()
        dofile(suites[i])(harness, loaded)
    end
end

os.exit(harness.run())
```

- [ ] **Step 3: Write `test/fake_world.lua`**

```lua
-- A tiny two-continent world. Both maps are 10000 x 10000 yards, so a map
-- coord converts as: world x = 10000 - my * 10000, world y = 10000 - mx * 10000.
local function world()
    return {
        Places = {
            [1] = { name = "Westland", c = 1, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.2, ay = 0.5 },
            [2] = { name = "Eastland", c = 0, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.8, ay = 0.5 },
        },
        Nodes = {
            [1] = { name = "Alpha, Westland", f = "H", c = 1, x = 1000, y = 1000, map = 1, mx = 0.9, my = 0.9 },
            [2] = { name = "Bravo, Westland", f = "H", c = 1, x = 1000, y = 9000, map = 1, mx = 0.1, my = 0.9 },
            [3] = { name = "Charlie, Westland", f = "N", c = 1, x = 5000, y = 9000, map = 1, mx = 0.1, my = 0.5 },
            [4] = { name = "Delta, Eastland", f = "H", c = 0, x = 5000, y = 5000, map = 2, mx = 0.5, my = 0.5 },
            [5] = { name = "Echo, Westland", f = "A", c = 1, x = 9000, y = 9000, map = 1, mx = 0.1, my = 0.1 },
        },
        -- { from, to, copper, seconds }
        Flights = {
            { 1, 2, 100, 250 }, { 2, 1, 100, 250 },
            { 2, 3, 50, 125 }, { 3, 2, 50, 125 },
        },
        Docks = {
            west_dock = { name = "West Dock", map = 1, mx = 0.05, my = 0.9 }, -- world 1000, 9500
            east_dock = { name = "East Dock", map = 2, mx = 0.45, my = 0.5 }, -- world 5000, 5500
        },
        Links = {
            { from = "west_dock", to = "east_dock", kind = "zeppelin", minutes = 4, faction = "H" },
        },
    }
end

return world
```

- [ ] **Step 4: Write the failing test `test/test_geo.lua`**

```lua
return function(h, loaded)
    local Geo = loaded.ns.Geo
    local world = dofile("test/fake_world.lua")()

    h.describe("Geo.ToWorld", function()
        h.it("converts map coords to continent and world yards", function()
            local c, x, y = Geo.ToWorld(world.Places, 1, 0.25, 0.5)
            h.eq(c, 1)
            h.eq(x, 5000)
            h.eq(y, 7500)
        end)
        h.it("returns nil for a map it does not know", function()
            h.eq(Geo.ToWorld(world.Places, 99, 0.5, 0.5), nil)
        end)
        h.it("returns nil without coordinates", function()
            h.eq(Geo.ToWorld(world.Places, 1, nil, nil), nil)
        end)
    end)

    h.describe("Geo.Distance", function()
        h.it("measures yards on one continent", function()
            h.eq(Geo.Distance({ c = 1, x = 0, y = 0 }, { c = 1, x = 300, y = 400 }), 500)
        end)
        h.it("is infinite across continents", function()
            h.eq(Geo.Distance({ c = 1, x = 0, y = 0 }, { c = 0, x = 0, y = 0 }), math.huge)
        end)
        h.it("is infinite when a position is missing", function()
            h.eq(Geo.Distance(nil, { c = 0, x = 0, y = 0 }), math.huge)
        end)
    end)
end
```

- [ ] **Step 5: Run the Lua tests and see them fail**

Expected: failures like `attempt to index local 'Geo' (a nil value)`, last line `1`.

- [ ] **Step 6: Write `GoblinPS/Geo.lua`**

```lua
local _, ns = ...

-- Pure geometry. World positions are { c = continent, x = yards, y = yards }.
local Geo = {}
ns.Geo = Geo

-- Map coords (0..1) on a UiMap to continent and world yards. The inverse of
-- world_to_map in tools/build_graph.py: map x runs along world -y, map y
-- along world -x.
function Geo.ToWorld(places, map, mx, my)
    local p = places and places[map]
    if not p or not mx or not my then
        return nil
    end
    return p.c, p.x1 - my * (p.x1 - p.x0), p.y1 - mx * (p.y1 - p.y0)
end

-- Yards between two world positions; math.huge across continents.
function Geo.Distance(a, b)
    if not a or not b or a.c ~= b.c then
        return math.huge
    end
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

return Geo
```

- [ ] **Step 7: Run the Lua tests**

Expected: `6 passed, 0 failed`, last line `0`.

- [ ] **Step 8: Write `.luacheckrc`**

```lua
std = "lua51"
max_line_length = 120
self = false
globals = {
    "SLASH_GOBLINPS1", "SlashCmdList",
}
read_globals = {
    "print",
    "UnitFactionGroup", "GetBindLocation",
    "C_TaxiMap", "C_Map", "C_Item",
}
files["GoblinPS/Data/Places.lua"] = { max_line_length = false }
files["GoblinPS/Data/Nodes.lua"] = { max_line_length = false }
files["GoblinPS/Data/Flights.lua"] = { max_line_length = false }
```

- [ ] **Step 9: Write `.luarc.json`**

```json
{
  "runtime.version": "Lua 5.1",
  "workspace.ignoreDir": [".remember", ".superpowers", "tools"],
  "diagnostics.globals": [
    "SLASH_GOBLINPS1", "SlashCmdList",
    "UnitFactionGroup", "GetBindLocation",
    "C_TaxiMap", "C_Map", "C_Item"
  ]
}
```

- [ ] **Step 10: Run luacheck**

Expected: `Total: 0 warnings / 0 errors`.

- [ ] **Step 11: Commit**

```
git add test .luacheckrc .luarc.json GoblinPS/Geo.lua
git commit -m "Add the test toolchain and Geo"
```

---

### Task 2: The data generator

**Files:**
- Create: `tools/build_graph.py`, `tools/catalog.lock`, `test/tools/__init__.py` (empty), `test/tools/test_build_graph.py`, `test/tools/fixtures/{UiMap,UiMapAssignment,TaxiNodes,TaxiPath,TaxiPathNode}.csv`
- Generated and committed: `GoblinPS/Data/Places.lua`, `GoblinPS/Data/Nodes.lua`, `GoblinPS/Data/Flights.lua`

**Interfaces:**
- Consumes: nothing.
- Produces, as Lua:
  - `ns.Data.Places[uiMapID] = { name, c, x0, y0, x1, y1, ax, ay }` (world bounds; `ax`/`ay` is the centre on the Azeroth map 947, for the schematic in plan 2)
  - `ns.Data.Nodes[nodeID] = { name, f, c, x, y, map, mx, my, ax, ay }` (`f` is `"A"`, `"H"` or `"N"`)
  - `ns.Data.Flights = { { from, to, copper, seconds }, ... }`

Facts the generator encodes, all found by running it against the real tables:

- `TaxiNodes.Flags` bit 1 = Alliance, bit 2 = Horde; both = neutral; neither = not a player node (skipped).
- Nodes off the two continents (Alterac Valley, continent 30) are skipped.
- Names starting `zzOLD` are Blizzard's abandoned rows with junk positions (three stale Riverglades nodes on this build): skipped.
- 13 `TaxiPath` rows point at nodes that do not exist: dropped.
- Zone rectangles in `UiMapAssignment` overlap (Crossroads is inside both Durotar's and The Barrens'), so the zone comes from the node's own name first.
- Flight time = path polyline length / 32 yards per second. Checked against four community-measured Classic times: within about 15%. No third-party timing data is needed.

- [ ] **Step 1: Write the lock file `tools/catalog.lock`**

```
1.60.1.69913
```

- [ ] **Step 2: Write the fixtures**

`test/tools/fixtures/UiMap.csv`:

```
Name_lang,ID,ParentUiMapID,Type
Azeroth,947,0,1
Kalimdor,1414,947,2
Durotar,1411,1414,3
"The Barrens",1413,1414,3
Orgrimmar,1454,1414,3
"Deadmines",291,0,4
```

`test/tools/fixtures/UiMapAssignment.csv`:

```
UiMin_0,UiMin_1,UiMax_0,UiMax_1,Region_0,Region_1,Region_2,Region_3,Region_4,Region_5,ID,UiMapID,MapID
0,0,0.5,1,-10000,-10000,-1000000,10000,10000,1000000,1,947,1
0,0,1,1,-2000,-5000,-1000000,2000,-2000,1000000,2,1411,1
0,0,1,1,-4000,-5000,-1000000,2000,0,1000000,3,1413,1
0,0,1,1,1300,-4800,-1000000,2100,-4000,1000000,4,1454,1
0,0,1,1,-100,-100,-1000000,100,100,1000000,5,291,36
```

`test/tools/fixtures/TaxiNodes.csv`:

```
Name_lang,Pos_0,Pos_1,Pos_2,ID,ContinentID,Flags
"Test Abbey",0,-3000,0,1,1,1024
"Stormwind, Elwynn",-8840,489,0,2,0,1025
"Orgrimmar, Durotar",1600,-4400,0,23,1,1026
"Crossroads, The Barrens",-400,-2600,0,25,1,1026
"Dun Baldar, Alterac Valley",0,0,0,59,30,1025
"Ratchet, The Barrens",-900,-3800,0,80,1,1027
"zzOLDPowderfuse Port, Riverglades",0,-3000,0,3208,1,1027
```

`test/tools/fixtures/TaxiPath.csv`:

```
ID,FromTaxiNode,ToTaxiNode,Cost
1,23,25,110
2,25,23,110
3,25,80,60
4,25,999,60
5,80,25,60
```

`test/tools/fixtures/TaxiPathNode.csv`:

```
Loc_0,Loc_1,Loc_2,ID,PathID,NodeIndex
3200,0,0,2,1,1
0,0,0,1,1,0
0,0,0,3,2,0
1600,0,0,4,2,1
1600,1600,0,5,2,2
0,0,0,6,3,0
640,0,0,7,3,1
```

- [ ] **Step 3: Write the failing tests `test/tools/test_build_graph.py`** (and an empty `test/tools/__init__.py`)

```python
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
        self.places = bg.build_places(bg.load_tables(FIXTURES))

    def test_keeps_zones_on_the_continents_only(self):
        self.assertEqual(sorted(self.places), [1411, 1413, 1454])

    def test_carries_world_bounds_and_azeroth_centre(self):
        barrens = self.places[1413]
        self.assertEqual((barrens["x0"], barrens["y0"], barrens["x1"], barrens["y1"]), (-4000, -5000, 2000, 0))
        self.assertEqual(barrens["c"], 1)
        # centre is world (-1000, -2500); Azeroth spans x 0..0.5 over world y 10000..-10000
        self.assertEqual((barrens["ax"], barrens["ay"]), (0.3125, 0.55))


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
```

- [ ] **Step 4: Run them and see them fail**

Run: `python -m unittest discover -s test/tools`
Expected: `ModuleNotFoundError: No module named 'build_graph'`.

- [ ] **Step 5: Write `tools/build_graph.py`**

```python
"""Build GoblinPS/Data/*.lua from wago.tools DB2 tables for the pinned build."""

from __future__ import annotations

import csv
import math
import sys
import urllib.request
from pathlib import Path

TABLES = ["TaxiNodes", "TaxiPath", "TaxiPathNode", "UiMap", "UiMapAssignment"]
WAGO = "https://wago.tools/db2/{table}/csv?build={build}"
USER_AGENT = "Mozilla/5.0 (GoblinPS build tool)"

REQUIRED_COLUMNS = {
    "TaxiNodes": ["ID", "Name_lang", "Pos_0", "Pos_1", "ContinentID", "Flags"],
    "TaxiPath": ["ID", "FromTaxiNode", "ToTaxiNode", "Cost"],
    "TaxiPathNode": ["PathID", "NodeIndex", "Loc_0", "Loc_1", "Loc_2"],
    "UiMap": ["ID", "Name_lang", "Type"],
    "UiMapAssignment": ["UiMapID", "MapID", "Region_0", "Region_1", "Region_3", "Region_4",
                        "UiMin_0", "UiMin_1", "UiMax_0", "UiMax_1"],
}

CONTINENTS = {"0", "1"}  # TaxiNodes.ContinentID / UiMapAssignment.MapID: Eastern Kingdoms, Kalimdor
AZEROTH = "947"
ZONE_TYPE = "3"
STALE_PREFIX = "zzOLD"  # Blizzard's marker for abandoned rows; their positions are junk
FLIGHT_YARDS_PER_SECOND = 32.0  # calibrated against measured Classic times, within ~15%


def read_lock(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip()


def _missing_columns(name: str, fieldnames) -> list[str]:
    have = set(fieldnames or ())
    return [c for c in REQUIRED_COLUMNS[name] if c not in have]


def load_tables(directory: Path) -> dict[str, list[dict[str, str]]]:
    tables = {}
    for name in TABLES:
        path = directory / f"{name}.csv"
        if not path.is_file():
            raise FileNotFoundError(path)
        with path.open(encoding="utf-8", newline="") as fh:
            reader = csv.DictReader(fh)
            rows = list(reader)
            missing = _missing_columns(name, reader.fieldnames)
        if missing:
            raise RuntimeError(f"{name}: missing columns {missing}")
        tables[name] = rows
    return tables


def fetch_tables(build: str, cache_dir: Path) -> None:
    cache_dir.mkdir(parents=True, exist_ok=True)
    for name in TABLES:
        path = cache_dir / f"{name}.csv"
        if path.is_file() and path.stat().st_size > 0:
            continue
        url = WAGO.format(table=name, build=build)
        print(f"fetch {url}", file=sys.stderr)
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = resp.read()
        header = data.split(b"\n", 1)[0].decode("utf-8", errors="replace").strip()
        missing = _missing_columns(name, header.split(","))
        if missing:
            raise RuntimeError(f"{name}: missing columns {missing}")
        path.write_bytes(data)


def faction_of(flags: str) -> str | None:
    """TaxiNodes.Flags bit 1 = Alliance, bit 2 = Horde. Neither = not a player node."""
    bits = int(flags) & 3
    return {1: "A", 2: "H", 3: "N"}.get(bits)


def _region(a) -> tuple[float, float, float, float]:
    return tuple(float(a[k]) for k in ("Region_0", "Region_1", "Region_3", "Region_4"))


def index_assignments(tables) -> dict[str, list[dict]]:
    index: dict[str, list[dict]] = {}
    for a in tables["UiMapAssignment"]:
        index.setdefault(a["UiMapID"], []).append(a)
    return index


def world_to_map(assignments, uimap_id: str, map_id: str, wx: float, wy: float):
    for a in assignments.get(uimap_id, ()):
        if a["MapID"] != map_id:
            continue
        x0, y0, x1, y1 = _region(a)
        if x1 == x0 or y1 == y0:
            continue
        if not (x0 <= wx <= x1 and y0 <= wy <= y1):
            continue
        ux0, uy0, ux1, uy1 = (float(a[k]) for k in ("UiMin_0", "UiMin_1", "UiMax_0", "UiMax_1"))
        x = ux0 + (ux1 - ux0) * (y1 - wy) / (y1 - y0)
        y = uy0 + (uy1 - uy0) * (x1 - wx) / (x1 - x0)
        return round(x, 4), round(y, 4)
    return None


def build_places(tables) -> dict[int, dict]:
    """Zones and cities on the two continents, with the world bounds Geo.ToWorld needs."""
    assignments = index_assignments(tables)
    places = {}
    for m in tables["UiMap"]:
        if m["Type"] != ZONE_TYPE:
            continue
        for a in assignments.get(m["ID"], ()):
            full = (a["UiMin_0"], a["UiMin_1"], a["UiMax_0"], a["UiMax_1"]) == ("0", "0", "1", "1")
            if a["MapID"] not in CONTINENTS or not full:
                continue
            x0, y0, x1, y1 = _region(a)
            azeroth = world_to_map(assignments, AZEROTH, a["MapID"], (x0 + x1) / 2, (y0 + y1) / 2)
            if azeroth is None:
                continue
            places[int(m["ID"])] = {
                "name": m["Name_lang"], "c": int(a["MapID"]),
                "x0": round(x0, 1), "y0": round(y0, 1), "x1": round(x1, 1), "y1": round(y1, 1),
                "ax": azeroth[0], "ay": azeroth[1],
            }
            break
    return places


def _zone_for(places: dict[int, dict], continent: int, wx: float, wy: float, node_name: str) -> int | None:
    """Zone rectangles overlap, so trust the node's own name first: "Crossroads, The Barrens".

    A city named before the comma wins, then the zone named after it, then the smallest
    rectangle containing the point.
    """
    inside = {
        map_id: p for map_id, p in places.items()
        if p["c"] == continent and p["x0"] <= wx <= p["x1"] and p["y0"] <= wy <= p["y1"]
    }
    for part in [s.strip() for s in node_name.split(",")][:2]:
        for map_id in sorted(inside):
            if part and inside[map_id]["name"].startswith(part):
                return map_id
    if not inside:
        return None
    return min(inside, key=lambda m: (inside[m]["x1"] - inside[m]["x0"]) * (inside[m]["y1"] - inside[m]["y0"]))


def build_nodes(tables, places) -> dict[int, dict]:
    assignments = index_assignments(tables)
    nodes = {}
    for n in tables["TaxiNodes"]:
        faction = faction_of(n["Flags"])
        if faction is None or n["ContinentID"] not in CONTINENTS or n["Name_lang"].startswith(STALE_PREFIX):
            continue
        wx, wy, continent = float(n["Pos_0"]), float(n["Pos_1"]), int(n["ContinentID"])
        map_id = _zone_for(places, continent, wx, wy, n["Name_lang"])
        azeroth = world_to_map(assignments, AZEROTH, n["ContinentID"], wx, wy)
        if map_id is None or azeroth is None:
            print(f"skip node {n['ID']} {n['Name_lang']}: not on a known map", file=sys.stderr)
            continue
        mx, my = world_to_map(assignments, str(map_id), n["ContinentID"], wx, wy)
        nodes[int(n["ID"])] = {
            "name": n["Name_lang"], "f": faction, "c": continent,
            "x": round(wx, 1), "y": round(wy, 1),
            "map": map_id, "mx": mx, "my": my, "ax": azeroth[0], "ay": azeroth[1],
        }
    return nodes


def _path_lengths(tables) -> dict[str, float]:
    points: dict[str, list] = {}
    for p in tables["TaxiPathNode"]:
        points.setdefault(p["PathID"], []).append(
            (int(p["NodeIndex"]), float(p["Loc_0"]), float(p["Loc_1"]), float(p["Loc_2"])))
    lengths = {}
    for path_id, pts in points.items():
        pts.sort()
        if len(pts) >= 2:
            lengths[path_id] = sum(math.dist(a[1:], b[1:]) for a, b in zip(pts, pts[1:]))
    return lengths


def build_flights(tables, nodes) -> list[list[int]]:
    """Rows of [from, to, copper, seconds], only between nodes we kept."""
    lengths = _path_lengths(tables)
    flights = []
    for p in tables["TaxiPath"]:
        a, b = int(p["FromTaxiNode"]), int(p["ToTaxiNode"])
        if a not in nodes or b not in nodes or a == b:
            continue
        yards = lengths.get(p["ID"])
        if yards is None:
            yards = math.dist((nodes[a]["x"], nodes[a]["y"]), (nodes[b]["x"], nodes[b]["y"]))
        flights.append([a, b, int(p["Cost"]), max(1, round(yards / FLIGHT_YARDS_PER_SECOND))])
    flights.sort()
    return flights


HEADER = "-- Generated by tools/build_graph.py from build {build}. Do not edit.\n"


def lua_value(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return str(int(v)) if v == int(v) else repr(v)
    if isinstance(v, str):
        out = ""
        for ch in v:
            if ch == "\\":
                out += "\\\\"
            elif ch == '"':
                out += '\\"'
            elif ord(ch) < 0x20:
                out += f"\\{ord(ch):03d}"
            else:
                out += ch
        return '"' + out + '"'
    if isinstance(v, list):
        return "{" + ",".join(lua_value(x) for x in v) + "}"
    if isinstance(v, dict):
        parts = []
        for k in sorted(v, key=lambda k: (isinstance(k, str), k)):
            key = f"[{k}]" if isinstance(k, int) else k
            parts.append(f"{key}={lua_value(v[k])}")
        return "{" + ",".join(parts) + "}"
    raise TypeError(type(v))


def _table_lines(rows) -> str:
    if isinstance(rows, dict):
        return "".join(f"    [{k}]={lua_value(rows[k])},\n" for k in sorted(rows))
    return "".join(f"    {lua_value(r)},\n" for r in rows)


def emit(out_dir: Path, build: str, name: str, rows) -> None:
    text = (HEADER.format(build=build)
            + "local _, ns = ...\nns.Data = ns.Data or {}\n"
            + f"ns.Data.{name} = {{\n{_table_lines(rows)}}}\n")
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / f"{name}.lua").write_text(text, encoding="utf-8", newline="\n")


def main(argv=None) -> int:
    root = Path(__file__).resolve().parents[1]
    build = read_lock(root / "tools" / "catalog.lock")
    cache = root / "tools" / "cache" / build
    fetch_tables(build, cache)
    tables = load_tables(cache)
    places = build_places(tables)
    nodes = build_nodes(tables, places)
    flights = build_flights(tables, nodes)
    out = root / "GoblinPS" / "Data"
    emit(out, build, "Places", places)
    emit(out, build, "Nodes", nodes)
    emit(out, build, "Flights", flights)
    print(f"{len(places)} places, {len(nodes)} nodes, {len(flights)} flights", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 6: Run the Python tests**

Expected: `Ran 16 tests`, `OK`. The `skip node 2 Stormwind, Elwynn: not on a known map` lines on stderr are expected: the fixture has no Eastern Kingdoms maps.

- [ ] **Step 7: Generate the real data**

Run: `python tools/build_graph.py`
Expected on stderr: five `fetch https://wago.tools/...` lines the first time, then `49 places, 71 nodes, 292 flights`. `tools/cache/` is already gitignored.

- [ ] **Step 8: Spot-check the output**

Open `GoblinPS/Data/Nodes.lua`. Node 25 must read `map=1413` (The Barrens, not Durotar), node 23 `map=1454` (Orgrimmar), node 2 `map=1453` (Stormwind City).

- [ ] **Step 9: Run luacheck** (the generated files are exempt from the line-length rule in `.luacheckrc`)

Expected: `Total: 0 warnings / 0 errors`.

- [ ] **Step 10: Commit**

```
git add tools test/tools GoblinPS/Data
git commit -m "Add the graph data generator and generated data"
```

---

### Task 3: `Search`

**Files:**
- Create: `GoblinPS/Search.lua`, `test/test_search.lua`

**Interfaces:**
- Consumes: `ns.Geo.ToWorld`; data shaped as in Task 2.
- Produces: `ns.Search.ShortName(name) -> string`; `ns.Search.Find(data, text, faction, limit) -> { place, ... }` where each place is a world place plus `kind` (`"zone"` or `"stop"`) and `nodeID` for stops, `limit` defaults to 8, `faction` nil means any; `ns.Search.Exact(data, name) -> place or nil`.

- [ ] **Step 1: Write the failing test `test/test_search.lua`**

```lua
return function(h, loaded)
    local Search = loaded.ns.Search
    local world = dofile("test/fake_world.lua")()

    h.describe("Search.ShortName", function()
        h.it("drops the zone after the comma", function()
            h.eq(Search.ShortName("Crossroads, The Barrens"), "Crossroads")
        end)
        h.it("leaves a plain name alone", function()
            h.eq(Search.ShortName("Moonglade"), "Moonglade")
        end)
    end)

    h.describe("Search.Find", function()
        h.it("matches without caring about case", function()
            local found = Search.Find(world, "ALP", "H")
            h.eq(#found, 1)
            h.eq(found[1].name, "Alpha")
            h.eq(found[1].nodeID, 1)
        end)
        h.it("puts names that start with the text first", function()
            local found = Search.Find(world, "e", "H")
            h.eq(found[1].name, "Eastland")
        end)
        h.it("hides the other faction's flight stops", function()
            h.eq(#Search.Find(world, "echo", "H"), 0)
            h.eq(#Search.Find(world, "echo", "A"), 1)
        end)
        h.it("gives a zone its centre as the target", function()
            local zone = Search.Find(world, "westland", "H")[1]
            h.eq(zone.kind, "zone")
            h.eq(zone.c, 1)
            h.eq(zone.x, 5000)
            h.eq(zone.y, 5000)
        end)
        h.it("returns nothing for empty text", function()
            h.eq(#Search.Find(world, "", "H"), 0)
        end)
        h.it("respects the limit", function()
            h.eq(#Search.Find(world, "a", "H", 2), 2)
        end)
    end)

    h.describe("Search.Exact", function()
        h.it("finds a bind name that matches a stop", function()
            h.eq(Search.Exact(world, "delta").nodeID, 4)
        end)
        h.it("returns nil for an inn it does not know", function()
            h.eq(Search.Exact(world, "Some Backwater Inn"), nil)
        end)
    end)
end
```

- [ ] **Step 2: Run the Lua tests and see the new suite fail**

Expected: failures mentioning `Search` being nil.

- [ ] **Step 3: Write `GoblinPS/Search.lua`**

```lua
local _, ns = ...

-- Pure lookup of destinations by name: flight stops and zones.
local Search = {}
ns.Search = Search

-- "Crossroads, The Barrens" -> "Crossroads"
function Search.ShortName(name)
    return (name:match("^([^,]+)") or name)
end

local function fromNode(id, n)
    return { kind = "stop", nodeID = id, name = Search.ShortName(n.name),
             c = n.c, x = n.x, y = n.y, map = n.map, mx = n.mx, my = n.my }
end

local function fromPlace(data, map, p)
    local c, x, y = ns.Geo.ToWorld(data.Places, map, 0.5, 0.5)
    return { kind = "zone", name = p.name, c = c, x = x, y = y, map = map, mx = 0.5, my = 0.5 }
end

local function legal(n, faction)
    return not faction or n.f == "N" or n.f == faction
end

-- Every candidate, zones first on a name tie so "Orgrimmar" means the city.
local function candidates(data, faction)
    local list = {}
    for map, p in pairs(data.Places) do
        list[#list + 1] = fromPlace(data, map, p)
    end
    for id, n in pairs(data.Nodes) do
        if legal(n, faction) then
            list[#list + 1] = fromNode(id, n)
        end
    end
    return list
end

-- Case-insensitive plain-text search. Names that start with the text come
-- first, then names that contain it; alphabetical inside each group.
function Search.Find(data, text, faction, limit)
    local needle = (text or ""):lower()
    if needle == "" then
        return {}
    end
    local ranked = {}
    for _, item in ipairs(candidates(data, faction)) do
        local at = item.name:lower():find(needle, 1, true)
        if at then
            item.rank = (at == 1) and 1 or 2
            ranked[#ranked + 1] = item
        end
    end
    table.sort(ranked, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.name ~= b.name then return a.name < b.name end
        return a.kind > b.kind
    end)
    local out = {}
    for i = 1, math.min(limit or 8, #ranked) do
        out[i] = ranked[i]
    end
    return out
end

-- Exact name match, used for the hearthstone bind name. Nil when unknown.
function Search.Exact(data, name)
    local needle = (name or ""):lower()
    for _, item in ipairs(Search.Find(data, name, nil, 50)) do
        if item.name:lower() == needle then
            return item
        end
    end
    return nil
end

return Search
```

- [ ] **Step 4: Run the Lua tests**

Expected: `16 passed, 0 failed`.

- [ ] **Step 5: Run luacheck, then commit**

```
git add GoblinPS/Search.lua test/test_search.lua
git commit -m "Add destination search"
```

---

### Task 4: `Graph`

**Files:**
- Create: `GoblinPS/Graph.lua`, `test/test_graph.lua`

**Interfaces:**
- Consumes: `ns.Geo`; data with `Places`, `Nodes`, `Flights`, `Docks`, `Links` (the fake world has all five; the real `Docks` and `Links` arrive in Task 6).
- Produces: `ns.Graph.Build(data, opts) -> { stops = { [key] = stop }, edges = { [key] = { { to, kind, seconds, copper }, ... } } }`. `opts = { faction = "A"|"H", known = { [nodeID] = true }, from = place, to = place, hearth = place or nil }`. Constants `Graph.RIDE_YARDS_PER_SECOND`, `Graph.RIDE_DETOUR`, `Graph.TRANSFER_YARDS`, `Graph.HEARTH_SECONDS`.

Rules: a flight stop exists only if it is known and faction-legal; a flight edge needs both ends. A link needs a legal faction and runs both ways. Stops within `TRANSFER_YARDS` (800) of each other get ride edges, which is how a flight master connects to the dock in its town. 800 is deliberate: at 2000 the router rode through a mountain from Ironforge to Menethil. `START` (and `HEARTH`, when offered) ride to every stop on their continent and to `DEST`; every stop rides to `DEST` on its continent.

- [ ] **Step 1: Write the failing test `test/test_graph.lua`**

```lua
return function(h, loaded)
    local Graph = loaded.ns.Graph
    local world = dofile("test/fake_world.lua")()

    local nearAlpha = { name = "You", c = 1, x = 1000, y = 1100 }
    local nearDelta = { name = "Delta Inn", c = 0, x = 5000, y = 5100 }

    h.describe("Graph.Build", function()
        h.it("keeps a flight only when both ends are known", function()
            local g = Graph.Build(world, { faction = "H", known = { [1] = true }, from = nearAlpha, to = nearDelta })
            h.truthy(g.stops.f1)
            h.falsy(g.stops.f2)
            for _, e in ipairs(g.edges.f1 or {}) do
                h.truthy(e.kind ~= "fly", "no flight out of a lone known node")
            end
        end)
        h.it("drops the other faction's stops and links", function()
            local g = Graph.Build(world, { faction = "A", known = { [1] = true, [5] = true },
                                           from = nearAlpha, to = nearDelta })
            h.falsy(g.stops.f1)
            h.truthy(g.stops.f5)
            h.falsy(g.stops.west_dock)
        end)
        h.it("places a dock from its map coords", function()
            local g = Graph.Build(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta })
            h.eq(g.stops.west_dock.c, 1)
            h.truthy(math.abs(g.stops.west_dock.x - 1000) < 0.001)
            h.truthy(math.abs(g.stops.west_dock.y - 9500) < 0.001)
        end)
        h.it("joins a flight master to a dock in the same town", function()
            local g = Graph.Build(world, { faction = "H", known = { [2] = true }, from = nearAlpha, to = nearDelta })
            local found
            for _, e in ipairs(g.edges.f2) do
                found = found or (e.to == "west_dock" and e.kind == "ride")
            end
            h.truthy(found, "Bravo to West Dock is 500 yards")
        end)
        h.it("links run both ways", function()
            local g = Graph.Build(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta })
            h.eq(g.edges.west_dock[1].to, "east_dock")
            h.eq(g.edges.east_dock[1].to, "west_dock")
            h.eq(g.edges.west_dock[1].seconds, 240)
        end)
        h.it("adds the hearthstone only when offered", function()
            local opts = { faction = "H", known = {}, from = nearAlpha, to = nearDelta }
            h.falsy(Graph.Build(world, opts).stops.HEARTH)
            opts.hearth = { name = "Delta Inn", c = 0, x = 5000, y = 5050 }
            local g = Graph.Build(world, opts)
            h.truthy(g.stops.HEARTH)
            h.eq(g.edges.START[1].kind, "hearth")
        end)
    end)
end
```

- [ ] **Step 2: Run the Lua tests and see the new suite fail**

- [ ] **Step 3: Write `GoblinPS/Graph.lua`**

```lua
local _, ns = ...

-- Pure: turns the data plus what this character can use into stops and
-- weighted edges. Never touches a Blizzard global.
local Graph = {}
ns.Graph = Graph

Graph.RIDE_YARDS_PER_SECOND = 11.2 -- a 100% mount; every ride time is a "~"
Graph.RIDE_DETOUR = 1.3            -- roads are not straight lines
Graph.TRANSFER_YARDS = 800         -- flight master to the dock in the same town, no further
Graph.HEARTH_SECONDS = 20          -- cast plus loading screen

local function legal(stopFaction, faction)
    return stopFaction == "N" or stopFaction == faction
end

local function rideSeconds(a, b)
    return ns.Geo.Distance(a, b) * Graph.RIDE_DETOUR / Graph.RIDE_YARDS_PER_SECOND
end

local function addEdge(edges, from, to, kind, seconds, copper)
    local list = edges[from]
    if not list then
        list = {}
        edges[from] = list
    end
    list[#list + 1] = { to = to, kind = kind, seconds = seconds, copper = copper or 0 }
end

local function stopFrom(key, p)
    return { key = key, nodeID = p.nodeID, name = p.name, c = p.c, x = p.x, y = p.y,
             map = p.map, mx = p.mx, my = p.my }
end

local function dockStop(data, stops, id)
    if stops[id] then
        return stops[id]
    end
    local d = data.Docks[id]
    if not d then
        return nil
    end
    local c, x, y = ns.Geo.ToWorld(data.Places, d.map, d.mx, d.my)
    if not c then
        return nil
    end
    stops[id] = { key = id, name = d.name, c = c, x = x, y = y, map = d.map, mx = d.mx, my = d.my }
    return stops[id]
end

-- opts: faction "A"/"H"; known = { [nodeID] = true }; from and to are world
-- places { name, c, x, y, map, mx, my }; hearth is one too, or nil.
-- Returns { stops = { [key] = stop }, edges = { [key] = { edge, ... } } }
-- with the special keys START, DEST and HEARTH.
function Graph.Build(data, opts)
    local stops, edges = {}, {}
    local faction, known = opts.faction, opts.known or {}

    for id, n in pairs(data.Nodes) do
        if known[id] and legal(n.f, faction) then
            local key = "f" .. id
            stops[key] = stopFrom(key, n)
            stops[key].nodeID = id
        end
    end
    for _, f in ipairs(data.Flights) do
        local a, b = "f" .. f[1], "f" .. f[2]
        if stops[a] and stops[b] then
            addEdge(edges, a, b, "fly", f[4], f[3])
        end
    end
    for _, link in ipairs(data.Links) do
        if legal(link.faction, faction) then
            local a, b = dockStop(data, stops, link.from), dockStop(data, stops, link.to)
            if a and b then
                addEdge(edges, a.key, b.key, link.kind, link.minutes * 60)
                addEdge(edges, b.key, a.key, link.kind, link.minutes * 60)
            end
        end
    end

    local keys = {}
    for key in pairs(stops) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    for i = 1, #keys do
        for j = i + 1, #keys do
            local a, b = stops[keys[i]], stops[keys[j]]
            if ns.Geo.Distance(a, b) <= Graph.TRANSFER_YARDS then
                addEdge(edges, a.key, b.key, "ride", rideSeconds(a, b))
                addEdge(edges, b.key, a.key, "ride", rideSeconds(b, a))
            end
        end
    end

    stops.START = stopFrom("START", opts.from)
    stops.DEST = stopFrom("DEST", opts.to)
    local origins = { stops.START }
    if opts.hearth then
        stops.HEARTH = stopFrom("HEARTH", opts.hearth)
        addEdge(edges, "START", "HEARTH", "hearth", Graph.HEARTH_SECONDS)
        origins[2] = stops.HEARTH
    end
    for _, origin in ipairs(origins) do
        for _, key in ipairs(keys) do
            if stops[key].c == origin.c then
                addEdge(edges, origin.key, key, "ride", rideSeconds(origin, stops[key]))
            end
        end
        if origin.c == stops.DEST.c then
            addEdge(edges, origin.key, "DEST", "ride", rideSeconds(origin, stops.DEST))
        end
    end
    for _, key in ipairs(keys) do
        if stops[key].c == stops.DEST.c then
            addEdge(edges, key, "DEST", "ride", rideSeconds(stops[key], stops.DEST))
        end
    end

    return { stops = stops, edges = edges }
end

return Graph
```

- [ ] **Step 4: Run the Lua tests**

Expected: `22 passed, 0 failed`.

- [ ] **Step 5: Run luacheck, then commit**

```
git add GoblinPS/Graph.lua test/test_graph.lua
git commit -m "Add the travel graph"
```

---

### Task 5: `Route`

**Files:**
- Create: `GoblinPS/Route.lua`, `test/test_route.lua`

**Interfaces:**
- Consumes: `ns.Graph.Build`, `ns.Search.ShortName`.
- Produces:
  - `ns.Route.Find(graph) -> { steps, raw, seconds, copper } or nil`. `raw` is every edge walked; `steps` merges a chain of flights into one step and drops rides under 5 seconds.
  - `ns.Route.Plan(data, opts) -> same` (builds the graph, then finds).
  - `ns.Route.Hint(data, opts, result) -> { names = { ... up to 2 }, seconds = saved or nil } or nil`. Nil unless knowing every flight path saves at least 120 seconds (or opens a route where there was none).
  - `ns.Route.StepText(step)`, `ns.Route.HintText(hint)`, `ns.Route.FormatTime(seconds)`, `ns.Route.FormatMoney(copper)`.

- [ ] **Step 1: Write the failing test `test/test_route.lua`**

```lua
return function(h, loaded)
    local Graph, Route = loaded.ns.Graph, loaded.ns.Route
    local world = dofile("test/fake_world.lua")()

    local nearAlpha = { name = "You", c = 1, x = 1000, y = 1100 }
    local nearDelta = { name = "Delta Inn", c = 0, x = 5000, y = 5100 }
    local nearCharlie = { name = "Charlie Field", c = 1, x = 5000, y = 9100 }

    local function kinds(result)
        local out = {}
        for i, s in ipairs(result.steps) do
            out[i] = s.kind
        end
        return table.concat(out, ",")
    end

    h.describe("Route.Plan", function()
        h.it("chains ride, flight, transfer, zeppelin and ride", function()
            local r = Route.Plan(world, { faction = "H", known = { [1] = true, [2] = true, [4] = true },
                                          from = nearAlpha, to = nearDelta })
            h.eq(kinds(r), "ride,fly,ride,zeppelin,ride")
            h.eq(r.copper, 100)
            h.eq(r.steps[2].to.nodeID, 2)
            h.eq(r.steps[4].seconds, 240)
        end)
        h.it("merges a chain of flights into one step", function()
            local r = Route.Plan(world, { faction = "H", known = { [1] = true, [2] = true, [3] = true },
                                          from = nearAlpha, to = nearCharlie })
            h.eq(kinds(r), "ride,fly,ride")
            h.eq(r.steps[2].to.nodeID, 3)
            h.eq(r.steps[2].seconds, 375)
            h.eq(r.steps[2].copper, 150)
            h.eq(#r.raw, 4)
        end)
        h.it("drops a ride too short to mention", function()
            local r = Route.Plan(world, { faction = "H", known = { [1] = true, [2] = true },
                                          from = { name = "You", c = 1, x = 1000, y = 1010 },
                                          to = { name = "Bravo Gate", c = 1, x = 1000, y = 8990 } })
            h.eq(kinds(r), "fly")
        end)
        h.it("rides the whole way when no flight is known", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = nearCharlie })
            h.eq(kinds(r), "ride")
        end)
        h.it("returns nil when the other continent cannot be reached", function()
            h.eq(Route.Plan(world, { faction = "A", known = { [5] = true }, from = nearAlpha, to = nearDelta }), nil)
        end)
        h.it("uses the hearthstone when it is offered", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta,
                                          hearth = { name = "Delta Inn", c = 0, x = 5000, y = 5050 } })
            h.eq(r.steps[1].kind, "hearth")
            h.eq(r.steps[1].seconds, Graph.HEARTH_SECONDS)
        end)
        h.it("ignores the hearthstone when it is not offered", function()
            local r = Route.Plan(world, { faction = "H", known = {}, from = nearAlpha, to = nearDelta })
            h.eq(kinds(r), "ride,zeppelin,ride")
        end)
    end)

    h.describe("Route.Hint", function()
        local opts = { faction = "H", known = {}, from = nearAlpha, to = nearDelta }
        h.it("names the missing flight stops and the saving", function()
            local hint = Route.Hint(world, opts, Route.Plan(world, opts))
            h.eq(table.concat(hint.names, ","), "Alpha,Bravo")
            h.truthy(hint.seconds > 600)
            h.eq(Route.HintText(hint), "Discover Alpha and Bravo to save ~11 min")
        end)
        h.it("stays quiet when the saving is small", function()
            local o = { faction = "H", known = { [1] = true, [2] = true, [4] = true },
                        from = nearAlpha, to = nearDelta }
            h.eq(Route.Hint(world, o, Route.Plan(world, o)), nil)
        end)
        h.it("stays quiet when nothing would help", function()
            local o = { faction = "A", known = {}, from = nearAlpha, to = nearDelta }
            h.eq(Route.Hint(world, o, nil), nil)
        end)
    end)

    h.describe("Route text", function()
        h.it("formats time and money", function()
            h.eq(Route.FormatTime(20), "~1 min")
            h.eq(Route.FormatTime(840), "~14 min")
            h.eq(Route.FormatMoney(0), "free")
            h.eq(Route.FormatMoney(110), "1s 10c")
            h.eq(Route.FormatMoney(12005), "1g 20s 5c")
        end)
        h.it("writes plain steps", function()
            local r = Route.Plan(world, { faction = "H", known = { [1] = true, [2] = true, [4] = true },
                                          from = nearAlpha, to = nearDelta })
            h.eq(Route.StepText(r.steps[1]), "Ride to Alpha")
            h.eq(Route.StepText(r.steps[2]), "Fly to Bravo")
            h.eq(Route.StepText(r.steps[4]), "Zeppelin to East Dock (~4 min incl. wait)")
            h.eq(Route.StepText(r.steps[5]), "Ride to Delta Inn")
        end)
        h.it("words a hint with no existing route", function()
            h.eq(Route.HintText({ names = { "Ratchet" } }), "Discover Ratchet to open a route")
        end)
    end)
end
```

- [ ] **Step 2: Run the Lua tests and see the new suite fail**

- [ ] **Step 3: Write `GoblinPS/Route.lua`**

```lua
local _, ns = ...

-- Pure: shortest path by seconds, the "discover X" hint, and the plain text.
local Route = {}
ns.Route = Route

Route.MIN_RIDE_SECONDS = 5   -- shorter rides mean "you are already there"
Route.HINT_MIN_SECONDS = 120 -- only mention a saving worth having

-- Dijkstra with a linear scan; the graph has about a hundred stops.
local function shortest(graph)
    local dist, prev, done = { START = 0 }, {}, {}
    while true do
        local best, bestKey = math.huge, nil
        for key, d in pairs(dist) do
            if not done[key] and d < best then
                best, bestKey = d, key
            end
        end
        if not bestKey or bestKey == "DEST" then
            break
        end
        done[bestKey] = true
        for _, e in ipairs(graph.edges[bestKey] or {}) do
            local nd = best + e.seconds
            if nd < (dist[e.to] or math.huge) then
                dist[e.to] = nd
                prev[e.to] = { from = bestKey, edge = e }
            end
        end
    end
    return dist.DEST and prev or nil
end

-- One "Fly to X" per flight master visit; drop rides too short to mention.
local function tidy(raw)
    local steps = {}
    for _, s in ipairs(raw) do
        local last = steps[#steps]
        local tooShort = s.kind == "ride" and s.seconds < Route.MIN_RIDE_SECONDS
        if last and last.kind == "fly" and s.kind == "fly" and last.to.key == s.from.key then
            last.to = s.to
            last.seconds = last.seconds + s.seconds
            last.copper = last.copper + s.copper
        elseif not tooShort then
            steps[#steps + 1] = { kind = s.kind, from = s.from, to = s.to,
                                  seconds = s.seconds, copper = s.copper }
        end
    end
    return steps
end

-- Returns { steps, raw, seconds, copper } or nil when there is no route.
-- A step is { kind, from = stop, to = stop, seconds, copper }.
function Route.Find(graph)
    local prev = shortest(graph)
    if not prev then
        return nil
    end
    local raw, key = {}, "DEST"
    while prev[key] do
        local p = prev[key]
        table.insert(raw, 1, { kind = p.edge.kind, from = graph.stops[p.from], to = graph.stops[key],
                               seconds = p.edge.seconds, copper = p.edge.copper })
        key = p.from
    end
    local seconds, copper = 0, 0
    for _, s in ipairs(raw) do
        seconds, copper = seconds + s.seconds, copper + s.copper
    end
    return { steps = tidy(raw), raw = raw, seconds = seconds, copper = copper }
end

function Route.Plan(data, opts)
    return Route.Find(ns.Graph.Build(data, opts))
end

-- Would knowing every flight path help? Returns { names = {...}, seconds =
-- saved or nil when there was no route at all }, or nil when it would not.
function Route.Hint(data, opts, result)
    local all, o = {}, {}
    for id in pairs(data.Nodes) do
        all[id] = true
    end
    for k, v in pairs(opts) do
        o[k] = v
    end
    o.known = all
    local better = Route.Plan(data, o)
    if not better then
        return nil
    end
    if result and result.seconds - better.seconds < Route.HINT_MIN_SECONDS then
        return nil
    end
    local names, seen, known = {}, {}, opts.known or {}
    for _, s in ipairs(better.raw) do
        if s.kind == "fly" then
            for _, stop in ipairs({ s.from, s.to }) do
                if not known[stop.nodeID] and not seen[stop.nodeID] and #names < 2 then
                    seen[stop.nodeID] = true
                    names[#names + 1] = ns.Search.ShortName(stop.name)
                end
            end
        end
    end
    if #names == 0 then
        return nil
    end
    return { names = names, seconds = result and (result.seconds - better.seconds) or nil }
end

local VERB = {
    ride = "Ride to", fly = "Fly to", zeppelin = "Zeppelin to",
    boat = "Boat to", tram = "Tram to", hearth = "Hearthstone to",
}
local WAITS = { zeppelin = true, boat = true, tram = true }

function Route.FormatTime(seconds)
    return "~" .. math.max(1, math.floor(seconds / 60 + 0.5)) .. " min"
end

function Route.FormatMoney(copper)
    if copper <= 0 then
        return "free"
    end
    local parts = {}
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

-- Plain and glanceable. No jokes in the directions.
function Route.StepText(step)
    local text = VERB[step.kind] .. " " .. ns.Search.ShortName(step.to.name)
    if WAITS[step.kind] then
        text = text .. " (" .. Route.FormatTime(step.seconds) .. " incl. wait)"
    end
    return text
end

function Route.HintText(hint)
    local who = table.concat(hint.names, " and ")
    if hint.seconds then
        return "Discover " .. who .. " to save " .. Route.FormatTime(hint.seconds)
    end
    return "Discover " .. who .. " to open a route"
end

return Route
```

- [ ] **Step 4: Run the Lua tests**

Expected: `35 passed, 0 failed`.

- [ ] **Step 5: Run luacheck, then commit**

```
git add GoblinPS/Route.lua test/test_route.lua
git commit -m "Add routing, the discover hint and step text"
```

---

### Task 6: Hand-written links and the real-data checks

**Files:**
- Create: `GoblinPS/Data/Links.lua`, `test/test_data.lua`

**Interfaces:**
- Consumes: everything above, plus the generated data from Task 2.
- Produces: `ns.Data.Docks[id] = { name, map, mx, my }` and `ns.Data.Links = { { from, to, kind, minutes, faction }, ... }`.

Dock names must not contain a comma: `Search.ShortName` cuts a name at the first comma. Dock coordinates are approximate and `minutes` are estimates; both go on the manual checklist in Task 8. The three new Forever boat routes are left out until seen in game.

- [ ] **Step 1: Write the failing test `test/test_data.lua`**

```lua
-- Integrity of the shipped data: generated tables and the hand-written links.
return function(h, loaded)
    local ns = loaded.ns
    local data = ns.Data

    local function findNode(prefix)
        for id, n in pairs(data.Nodes) do
            if n.name:find(prefix, 1, true) == 1 then
                return id, n
            end
        end
    end

    local function allKnown()
        local known = {}
        for id in pairs(data.Nodes) do
            known[id] = true
        end
        return known
    end

    local function placeOf(n)
        return { name = n.name, c = n.c, x = n.x, y = n.y, map = n.map, mx = n.mx, my = n.my }
    end

    h.describe("shipped data", function()
        h.it("has every table", function()
            for _, name in ipairs({ "Places", "Nodes", "Flights", "Docks", "Links" }) do
                h.truthy(data and data[name], name .. " is missing")
            end
        end)
        h.it("has flights only between nodes that exist", function()
            for _, f in ipairs(data.Flights) do
                h.truthy(data.Nodes[f[1]] and data.Nodes[f[2]], "flight " .. f[1] .. "->" .. f[2])
                h.truthy(f[4] > 0, "flight time")
            end
        end)
        h.it("puts every node on a known map", function()
            for id, n in pairs(data.Nodes) do
                h.truthy(data.Places[n.map], "node " .. id .. " map")
            end
        end)
        h.it("can place every dock a link uses", function()
            for _, link in ipairs(data.Links) do
                for _, id in ipairs({ link.from, link.to }) do
                    local d = data.Docks[id]
                    h.truthy(d, "dock " .. id)
                    h.truthy(ns.Geo.ToWorld(data.Places, d.map, d.mx, d.my), "dock " .. id .. " map")
                end
            end
        end)
        h.it("gives every link sane fields", function()
            for _, link in ipairs(data.Links) do
                h.truthy(link.minutes > 0, link.from .. " minutes")
                h.truthy(link.faction == "A" or link.faction == "H" or link.faction == "N", link.from .. " faction")
            end
        end)
        h.it("never lets a ride transfer undercut a link", function()
            for _, link in ipairs(data.Links) do
                local a, b = data.Docks[link.from], data.Docks[link.to]
                local ac, ax, ay = ns.Geo.ToWorld(data.Places, a.map, a.mx, a.my)
                local bc, bx, by = ns.Geo.ToWorld(data.Places, b.map, b.mx, b.my)
                local yards = ns.Geo.Distance({ c = ac, x = ax, y = ay }, { c = bc, x = bx, y = by })
                h.truthy(yards > ns.Graph.TRANSFER_YARDS, link.from .. " to " .. link.to .. " is within riding range")
            end
        end)
        h.it("puts every dock within a transfer of a flight master, bar the Forgotten Coast", function()
            for id, d in pairs(data.Docks) do
                local c, x, y = ns.Geo.ToWorld(data.Places, d.map, d.mx, d.my)
                local best = math.huge
                for _, n in pairs(data.Nodes) do
                    best = math.min(best, ns.Geo.Distance({ c = c, x = x, y = y }, n))
                end
                if id ~= "forgotten" then
                    h.truthy(best <= ns.Graph.TRANSFER_YARDS,
                             id .. " is " .. math.floor(best) .. " yards from a flight master")
                end
            end
        end)
    end)

    h.describe("a real route", function()
        h.it("takes a Horde character from Thunder Bluff to Undercity by zeppelin", function()
            local _, tb = findNode("Thunder Bluff")
            local _, uc = findNode("Undercity")
            local r = ns.Route.Plan(data, { faction = "H", known = allKnown(), from = placeOf(tb), to = placeOf(uc) })
            h.truthy(r, "no route")
            local kinds = {}
            for i, s in ipairs(r.steps) do
                kinds[i] = s.kind
            end
            h.eq(table.concat(kinds, ","), "fly,ride,zeppelin,ride")
            h.eq(ns.Route.StepText(r.steps[1]), "Fly to Orgrimmar")
        end)
        h.it("takes an Alliance character from Stormwind to Ironforge", function()
            local _, sw = findNode("Stormwind")
            local _, ironforge = findNode("Ironforge")
            local r = ns.Route.Plan(data, { faction = "A", known = allKnown(),
                                            from = placeOf(sw), to = placeOf(ironforge) })
            h.truthy(r, "no route")
            h.eq(ns.Route.StepText(r.steps[2]), "Tram to Ironforge Tram Station (~2 min incl. wait)")
        end)
    end)
end
```

- [ ] **Step 2: Run the Lua tests and see the new suite fail**

Expected: `Docks is missing`, `Links is missing`.

- [ ] **Step 3: Write `GoblinPS/Data/Links.lua`**

```lua
-- HAND-WRITTEN. Boats, zeppelins and the tram: nothing in Blizzard's tables
-- describes them. Later, zone-to-zone ground crossings go here too, as more
-- rows, not a redesign.
--
-- Dock positions are map coords (0..1) on a zone map and are APPROXIMATE:
-- each one is checked in game from docs/manual-test-checklist.md.
-- minutes = the ride plus about half the loop, the average wait. Estimates
-- until timed in game.
-- Every link runs both ways. faction: "A", "H" or "N" (both).
--
-- Not listed until confirmed in game (see the spec): Stormwind Harbor to
-- Auberdine, Menethil to Southshore to Auberdine, Steamwheedle to Powderfuse.
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Docks = {
    org_zep      = { name = "Orgrimmar Zeppelin Tower", map = 1411, mx = 0.508, my = 0.130 },
    uc_zep       = { name = "Undercity Zeppelin Tower", map = 1420, mx = 0.610, my = 0.590 },
    gromgol_zep  = { name = "Grom'gol Zeppelin Tower",  map = 1434, mx = 0.315, my = 0.295 },
    menethil     = { name = "Menethil Harbor Docks",    map = 1437, mx = 0.050, my = 0.600 },
    auberdine    = { name = "Auberdine Docks",          map = 1439, mx = 0.328, my = 0.420 },
    theramore    = { name = "Theramore Docks",          map = 1445, mx = 0.715, my = 0.564 },
    rutheran     = { name = "Rut'theran Village Docks", map = 1438, mx = 0.549, my = 0.968 },
    bootybay     = { name = "Booty Bay Docks",          map = 1434, mx = 0.259, my = 0.731 },
    ratchet      = { name = "Ratchet Docks",            map = 1413, mx = 0.637, my = 0.386 },
    feathermoon  = { name = "Feathermoon Docks",        map = 1444, mx = 0.310, my = 0.398 },
    forgotten    = { name = "Forgotten Coast Docks",    map = 1444, mx = 0.434, my = 0.428 },
    tram_sw      = { name = "Stormwind Tram Station",   map = 1453, mx = 0.640, my = 0.080 },
    tram_if      = { name = "Ironforge Tram Station",   map = 1455, mx = 0.768, my = 0.512 },
}

ns.Data.Links = {
    { from = "org_zep",     to = "uc_zep",      kind = "zeppelin", minutes = 4, faction = "H" },
    { from = "org_zep",     to = "gromgol_zep", kind = "zeppelin", minutes = 4, faction = "H" },
    { from = "uc_zep",      to = "gromgol_zep", kind = "zeppelin", minutes = 4, faction = "H" },
    { from = "menethil",    to = "auberdine",   kind = "boat",     minutes = 4, faction = "A" },
    { from = "menethil",    to = "theramore",   kind = "boat",     minutes = 4, faction = "A" },
    { from = "auberdine",   to = "rutheran",    kind = "boat",     minutes = 3, faction = "A" },
    { from = "bootybay",    to = "ratchet",     kind = "boat",     minutes = 4, faction = "N" },
    { from = "feathermoon", to = "forgotten",   kind = "boat",     minutes = 3, faction = "A" },
    { from = "tram_sw",     to = "tram_if",     kind = "tram",     minutes = 2, faction = "A" },
}
```

- [ ] **Step 4: Run the Lua tests**

Expected: `44 passed, 0 failed`. If "never lets a ride transfer undercut a link" or "within a transfer of a flight master" fails after a data regeneration, fix the dock coordinate; do not widen `TRANSFER_YARDS`.

- [ ] **Step 5: Run luacheck, then commit**

```
git add GoblinPS/Data/Links.lua test/test_data.lua
git commit -m "Add boat, zeppelin and tram links with real-data checks"
```

---

### Task 7: `Trip`

**Files:**
- Create: `GoblinPS/Trip.lua`, `test/test_trip.lua`

**Interfaces:**
- Consumes: `ns.Geo.Distance`; a step from `Route`.
- Produces: `ns.Trip.Check(step, state) -> "advance" | "recalculate" | "stay" | "pause"`. `state = { pos = { c, x, y } or nil, onTaxi = bool, event = "tick"|"landed"|"zone", best = closest yards so far }`. Constants `Trip.ARRIVE[kind]` and `Trip.STRAY_YARDS`. Plan 2's dash unit is the caller.

Arrival is positional for every step kind (inside the step's radius and not on a taxi), which covers the spec's per-kind rules with one test. Events only make the dash check sooner; `landed` away from the expected node means recalculate.

- [ ] **Step 1: Write the failing test `test/test_trip.lua`**

```lua
return function(h, loaded)
    local Trip = loaded.ns.Trip
    local target = { name = "Bravo", c = 1, x = 1000, y = 9000 }
    local function at(x, y) return { c = 1, x = x, y = y } end

    h.describe("Trip.Check", function()
        h.it("pauses when the position is unknown", function()
            h.eq(Trip.Check({ kind = "ride", to = target }, { event = "tick" }), "pause")
        end)
        h.it("advances a ride inside the arrival radius", function()
            h.eq(Trip.Check({ kind = "ride", to = target }, { pos = at(1000, 8970), event = "tick" }), "advance")
        end)
        h.it("stays on a ride that is still closing in", function()
            local state = { pos = at(1000, 8000), best = 1100, event = "tick" }
            h.eq(Trip.Check({ kind = "ride", to = target }, state), "stay")
        end)
        h.it("recalculates a ride that strays", function()
            h.eq(Trip.Check({ kind = "ride", to = target }, { pos = at(1000, 8000), best = 500, event = "tick" }),
                 "recalculate")
        end)
        h.it("never advances while on a taxi", function()
            local state = { pos = at(1000, 9000), onTaxi = true, event = "tick" }
            h.eq(Trip.Check({ kind = "fly", to = target }, state), "stay")
        end)
        h.it("advances a flight that landed at its node", function()
            h.eq(Trip.Check({ kind = "fly", to = target }, { pos = at(1000, 8900), event = "landed" }), "advance")
        end)
        h.it("recalculates a flight that landed somewhere else", function()
            h.eq(Trip.Check({ kind = "fly", to = target }, { pos = at(5000, 5000), event = "landed" }), "recalculate")
        end)
        h.it("waits for a boat on the far continent", function()
            h.eq(Trip.Check({ kind = "boat", to = target }, { pos = { c = 0, x = 0, y = 0 }, event = "zone" }), "stay")
        end)
        h.it("advances a boat that docked", function()
            h.eq(Trip.Check({ kind = "boat", to = target }, { pos = at(1500, 9000), event = "zone" }), "advance")
        end)
    end)
end
```

- [ ] **Step 2: Run the Lua tests and see the new suite fail**

- [ ] **Step 3: Write `GoblinPS/Trip.lua`**

```lua
local _, ns = ...

-- Pure arrival rules for an active trip. The dash unit feeds it the current
-- step and what the client reports; it answers what to do.
local Trip = {}
ns.Trip = Trip

-- Yards from a step's target that count as "arrived".
Trip.ARRIVE = { ride = 40, fly = 150, zeppelin = 800, boat = 800, tram = 800, hearth = 300 }
Trip.STRAY_YARDS = 400

-- state: pos = { c, x, y } or nil (instances); onTaxi = bool; event =
-- "tick" | "landed" | "zone"; best = closest the player has been to the
-- step's target so far, tracked by the caller.
-- Returns "advance", "recalculate", "stay" or "pause".
function Trip.Check(step, state)
    if not state.pos then
        return "pause"
    end
    if state.onTaxi then
        return "stay"
    end
    local d = ns.Geo.Distance(state.pos, step.to)
    if d <= Trip.ARRIVE[step.kind] then
        return "advance"
    end
    if step.kind == "ride" and state.best and d > state.best + Trip.STRAY_YARDS then
        return "recalculate"
    end
    if step.kind == "fly" and state.event == "landed" then
        return "recalculate"
    end
    return "stay"
end

return Trip
```

- [ ] **Step 4: Run the Lua tests**

Expected: `53 passed, 0 failed`.

- [ ] **Step 5: Run luacheck, then commit**

```
git add GoblinPS/Trip.lua test/test_trip.lua
git commit -m "Add the arrival rules"
```

---

### Task 8: `API`, `Core`, the TOC and the in-game check

**Files:**
- Create: `GoblinPS/API.lua`, `GoblinPS/Core.lua`, `GoblinPS/GoblinPS.toc`
- Modify: `docs/manual-test-checklist.md`, `CLAUDE.md` (status line)

**Interfaces:**
- Consumes: every module above.
- Produces: `ns.API.Faction() -> "A"|"H"|nil`; `ns.API.TaxiNodes() -> { { nodeID, name, known }, ... }`; `ns.API.KnownNodes() -> { [nodeID] = true }`; `ns.API.PlayerMapPosition(places) -> map, x, y or nil`; `ns.API.HearthBindName() -> string or nil` (nil when the hearthstone is missing or on cooldown). Slash commands `/gps to <place>` and `/gps probe`.

These cannot run on the desktop. Every Blizzard name used was checked in `D:\wow-api\1.60.1.69913`: `C_TaxiMap.GetTaxiNodesForMap`, `C_Map.GetBestMapForUnit`, `C_Map.GetMapInfo` (`parentMapID`), `C_Map.GetPlayerMapPosition`, `C_Item.GetItemCount`, `C_Item.GetItemCooldown`, `GetBindLocation`, `UnitFactionGroup`. No events are registered.

- [ ] **Step 1: Write `GoblinPS/API.lua`**

```lua
local _, ns = ...

-- The ONLY file that touches Blizzard globals. Everything is defensive: a
-- missing API or an odd return means "unknown", never an error.
local API = {}
ns.API = API

local CONTINENT_MAPS = { 1414, 1415 } -- Kalimdor, Eastern Kingdoms
local HEARTHSTONE = 6948
local REAL_COOLDOWN_SECONDS = 30      -- longer than any global cooldown

-- "A", "H" or nil.
function API.Faction()
    local group = UnitFactionGroup("player")
    if group == "Alliance" then
        return "A"
    elseif group == "Horde" then
        return "H"
    end
    return nil
end

-- The client's view of the flight nodes: { { nodeID, name, known }, ... }.
-- Read live every time; never saved.
function API.TaxiNodes()
    local out = {}
    if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then
        return out
    end
    for _, map in ipairs(CONTINENT_MAPS) do
        for _, info in ipairs(C_TaxiMap.GetTaxiNodesForMap(map) or {}) do
            out[#out + 1] = { nodeID = info.nodeID, name = info.name, known = not info.isUndiscovered }
        end
    end
    return out
end

-- { [nodeID] = true } for every flight path this character has discovered.
-- If the in-game probe shows isUndiscovered is unreliable, only this function
-- changes (to recording C_TaxiMap.GetAllTaxiNodes at flight masters).
function API.KnownNodes()
    local known = {}
    for _, node in ipairs(API.TaxiNodes()) do
        if node.known then
            known[node.nodeID] = true
        end
    end
    return known
end

-- The player's position on the nearest map we have data for: uiMapID, x, y
-- (0..1). Nil inside instances or on a map we do not know.
function API.PlayerMapPosition(places)
    local map = C_Map.GetBestMapForUnit("player")
    while map and map ~= 0 and not places[map] do
        local info = C_Map.GetMapInfo(map)
        map = info and info.parentMapID
    end
    if not map or map == 0 then
        return nil
    end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then
        return nil
    end
    local x, y = pos:GetXY()
    return map, x, y
end

-- The hearthstone's bind name, or nil when it is missing or on cooldown.
-- Absent means absent: the router never waits for it.
function API.HearthBindName()
    if not (C_Item and C_Item.GetItemCount and C_Item.GetItemCooldown) then
        return nil
    end
    if C_Item.GetItemCount(HEARTHSTONE) == 0 then
        return nil
    end
    local start, duration = C_Item.GetItemCooldown(HEARTHSTONE)
    if start and start > 0 and duration and duration > REAL_COOLDOWN_SECONDS then
        return nil
    end
    return GetBindLocation()
end

return API
```

- [ ] **Step 2: Write `GoblinPS/Core.lua`**

```lua
local _, ns = ...

-- Slash commands. For now the whole addon is "/gps to <place>" printed in
-- chat; the planner window and dash unit come in the next plan.
local API, Geo, Search, Route = ns.API, ns.Geo, ns.Search, ns.Route

local function say(text)
    print("|cff6fe08aGoblinPS|r " .. text)
end

local function here()
    local map, mx, my = API.PlayerMapPosition(ns.Data.Places)
    local c, x, y = Geo.ToWorld(ns.Data.Places, map, mx, my)
    if not c then
        return nil
    end
    return { name = "You", c = c, x = x, y = y, map = map, mx = mx, my = my }
end

local function routeTo(text)
    local faction = API.Faction()
    if not faction then
        say("Pick a faction first.")
        return
    end
    local dest = Search.Find(ns.Data, text, faction, 1)[1]
    if not dest then
        say('No place matches "' .. text .. '".')
        return
    end
    local from = here()
    if not from then
        say("Can't tell where you are. Inside an instance?")
        return
    end
    local bindName = API.HearthBindName()
    local bind = bindName and Search.Exact(ns.Data, bindName) or nil
    if bindName and not bind then
        say("Hearth: unknown inn (" .. bindName .. "), left out.")
    end

    local opts = { faction = faction, known = API.KnownNodes(), from = from, to = dest, hearth = bind }
    local result = Route.Plan(ns.Data, opts)
    if result then
        say("To " .. dest.name .. ": " .. Route.FormatTime(result.seconds) .. ", " .. Route.FormatMoney(result.copper))
        for i, step in ipairs(result.steps) do
            say(i .. ". " .. Route.StepText(step))
        end
    else
        say("No route found to " .. dest.name .. ".")
    end
    local hint = Route.Hint(ns.Data, opts, result)
    if hint then
        say(Route.HintText(hint))
    end
end

-- Answers the design's open questions in one command: does the client report
-- discovered flight paths, and do its node IDs match our generated table?
local function probe()
    local nodes = API.TaxiNodes()
    local known, missing, renamed = 0, 0, 0
    for _, node in ipairs(nodes) do
        if node.known then
            known = known + 1
        end
        local ours = ns.Data.Nodes[node.nodeID]
        if not ours then
            missing = missing + 1
            say("not in our data: " .. tostring(node.nodeID) .. " " .. tostring(node.name))
        elseif ours.name ~= node.name then
            renamed = renamed + 1
            say("name differs: " .. node.nodeID .. " ours '" .. ours.name .. "' client '" .. tostring(node.name) .. "'")
        end
    end
    say(("Client reports %d flight nodes, %d known. %d not in our data, %d named differently.")
        :format(#nodes, known, missing, renamed))
end

SLASH_GOBLINPS1 = "/gps"
SlashCmdList.GOBLINPS = function(msg)
    local command, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
    if command == "to" and rest ~= "" then
        routeTo(rest)
    elseif command == "probe" then
        probe()
    else
        say("/gps to <place>   plan a route from where you stand")
        say("/gps probe        check the flight path data against the client")
    end
end
```

- [ ] **Step 3: Write `GoblinPS/GoblinPS.toc`**

```
## Interface: 16001
## Title: GoblinPS
## Notes: Goblin Positioning System. The fastest route from where you stand. Accuracy not guaranteed. No refunds.
## Author: CoffeeAndLoot
## X-Website: https://github.com/CoffeeAndLoot/goblinps
## Version: 2026.09.19

API.lua
Geo.lua
Data\Places.lua
Data\Nodes.lua
Data\Flights.lua
Data\Links.lua
Search.lua
Graph.lua
Route.lua
Trip.lua
Core.lua
```

- [ ] **Step 4: Run the Lua tests and luacheck**

Expected: still `53 passed, 0 failed` and `Total: 0 warnings / 0 errors`.

- [ ] **Step 5: Run the language server check**

```
lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json
```

Expected: `Diagnosis completed, no problems found`. A reported undefined global goes in both `.luacheckrc` and `.luarc.json`.

- [ ] **Step 6: Create the junction** (skip if it exists)

```
New-Item -ItemType Junction -Path "D:\World of Warcraft\_classic_beta_\Interface\AddOns\GoblinPS" -Target "D:\goblinps\GoblinPS"
```

- [ ] **Step 7: Add these entries to `docs/manual-test-checklist.md`** under a new heading `## Routing core (plan 1)`

```markdown
## Routing core (plan 1)

- [ ] The addon loads with no Lua error; `/gps` prints the two usage lines
- [ ] `/gps probe` prints "Client reports N flight nodes, K known. 0 not in our
      data, 0 named differently." Record N and K. K must match the flight
      paths this character really has. Any "not in our data" or "name
      differs" line: record it here, it decides `API.KnownNodes`
- [ ] `/gps to <a city you can reach>` prints numbered steps, a total time
      and a fare; the steps are the route you would actually take
- [ ] `/gps to <zone with no known flight path>` ends with a
      "Discover ... to save ~N min" line
- [ ] With the hearthstone ready and a better route through the inn, step 1
      is "Hearthstone to ..."; on cooldown it never appears
- [ ] `/gps to qqqq` prints `No place matches "qqqq".`
- [ ] Inside an instance `/gps to orgrimmar` prints "Can't tell where you are"
- [ ] Stand on each dock and compare `/dump C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit("player"), "player"):GetXY()`
      with its row in `GoblinPS/Data/Links.lua`; correct the row if it is off
      by more than 0.02
- [ ] Time one full zeppelin and one boat loop; correct `minutes` (ride plus
      half the loop)
```

- [ ] **Step 8: Update the status line in `CLAUDE.md`**

Replace the paragraph that starts `**Status:` with:

```markdown
**Status: routing core built (plan 1); no window yet.** `/gps to <place>`
prints a route in chat and `/gps probe` checks the flight data against the
client. The design is `docs/superpowers/specs/2026-09-19-goblinps-design.md`;
plan 2 (planner window, schematic map, dash unit) is written once the
routing core's manual checks have been run in game.
```

- [ ] **Step 9: Commit**

```
git add GoblinPS docs/manual-test-checklist.md CLAUDE.md
git commit -m "Add API, the /gps command and the TOC"
```

- [ ] **Step 10: Hand over to the user for the in-game checks**

Report that the desktop work is done and verified, that nothing has been run in the game client, and list the `Routing core (plan 1)` checklist entries for the user to run. Do not claim any of them pass.

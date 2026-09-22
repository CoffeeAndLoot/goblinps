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


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

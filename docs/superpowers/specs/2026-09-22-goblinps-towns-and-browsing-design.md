# GoblinPS: a towns table, a scrolling list, a zone browser (plan 10)

Status: **approved by the owner in chat, 2026-09-22.** They asked for it ("can we begin building up a location database for people to pick from"), agreed to generate it from the game's own table, and folded in scrolling and zone browsing ("make it scrollable... maybe by scrolling through"). Decisions the owner did not state are marked **Ruling**. This spec amends the plan 8 and plan 9 specs.

## Why
- Since 2026-09-22 a destination is a place, never a zone. The places are flight stops (both factions, enemy ones marked) plus six hand-written inn towns. Four zones hold no place and fall back to the zone itself. Many real towns cannot be picked: Kharanos's inn is the only way to reach Kharanos, and Darnassus is a fallback zone.
- The game ships a table of every named town on the world map: **`AreaPOI`**, on wago.tools for build 1.60.1.69913. It has 372 rows, with `Name_lang`, world `Pos_0`/`Pos_1`, `ContinentID`, `AreaID` and `Icon`. On continents 0 and 1:
  - Icon 5 is a capital (6 rows: Ironforge, Stormwind, The Undercity, Thunder Bluff, Orgrimmar, Darnassus).
  - Icon 4 is a town (about 34, e.g. Sentinel Hill, Tarren Mill, Kargath).
  - Icon 6 is a village or outpost (about 150, e.g. Brill, Goldshire, Kharanos).
  - Continent 30 is Alterac Valley's battleground objects, and other icons are shop signs and battleground markers. **Ruling:** those are left out.
- Checked 2026-09-22 by fetching the CSV. The positions are where the world map draws each town's label: roughly its middle, not a doorway.

## 1. The towns table (generated)
- `tools/build_graph.py` fetches `AreaPOI`, and `AreaTable` if the zone lookup needs it, like the other tables. It emits **`GoblinPS/Data/Towns.lua`**: `ns.Data.Towns = { [id] = { name, map, mx, my, c, x, y, f? }, ... }`. It is generated; nobody edits it.
- **Zone:** each town gets the UiMap of the zone it is in. Zone rectangles overlap, so the rectangle alone is not enough. Prefer the POI's `AreaID` climbed to its zone through `AreaTable.ParentAreaID`, then matched to a zone in `Places` by name. Fall back to the generator's existing `_zone_for` rule. Report any town still unplaced, and skip it. **Ruling:** the plan measures how many resolve each way and states the numbers.
- **Faction:** the table does not say. **Ruling:** a town takes the faction of a flight master of a single faction within 600 yards in the same zone. Otherwise it has none: no mark, and routed as neutral. Capitals take their known faction from their own flight stop.
- **Duplicates:** when a town and a flight stop, or a town and a hand-written inn town, share a name and lie within 300 yards, **the flight stop or inn row wins** and the town is not offered twice.
- **Hand-written data still wins.** `Data/Inns.lua` rows stay for hearthstone bind names. Their map positions may be replaced by the matching town where one exists.

## 2. Search
- `Search.Candidates` offers flight stops, towns and hand-written inn towns (deduplicated as above), and a zone only when it holds none of these.
- **Folded minor:** when a flight stop the faction may use and an enemy stop share a name (Gadgetzan, Everlook, Booty Bay), the enemy row is not offered.
- **Folded minor:** a fixture pins the cross-faction name tie, with two stops of the same name and different factions, the enemy one on the lower ID.
- A town row reads like a stop's: "Kharanos · Dun Morogh", with " (Alliance)" or " (Horde)" when its inferred faction is the enemy's.

## 3. A scrolling list
- The results list scrolls on the mouse wheel. `EnableMouseWheel` and `OnMouseWheel` are verified present on this build (`SimpleScriptRegionAPIDocumentation.lua`), and no template is used.
- It still shows only as many rows as fit (`results.fit`, 5 today). The wheel moves a window over the full list, one row per notch, clamped at both ends.
- A footer line on the list, bounded, reads "6-10 of 23" whenever there is more than fits, and is hidden otherwise. **Ruling:** the list keeps its geometry height, so the footer sits inside it, in its last row's slot or a slot measured for it. The plan works out which without overlapping a row.
- Enter still picks the top shown row. Typing resets the window to the start.
- **Ruling:** the search now returns every match, not only `fit` of them, so the wheel has something to scroll. Sorting stays as today.

## 4. A zone browser
- With the box empty, the dropdown button (and focusing the empty box) lists **recent destinations first, then every zone A to Z** that holds at least one place, each with its count: "Ashenvale (6)".
- **A zone row is a way in, never a destination.** Clicking it puts the zone's name in the box, exactly as typing it would, so the list shows that zone's places. Typing a zone name already lists its places (rank 3), so this is the same rule reached by clicking.
- The four fallback zones, if any remain, are listed like any zone. Clicking one lists its single "(zone)" row.
- The list scrolls, as in section 3.

## Out of scope
Faction-aware avoidance of enemy towns (step 4, next), stopover points, quests, and dressing the list with art.

## Tests
- **Generator (Python, `test/tools/test_build_graph.py`, fixture CSVs):**
  - towns are filtered by continent and icon;
  - the zone comes from AreaID when it resolves, and from the rectangle rule otherwise;
  - the inferred faction appears within 600 yd of a single-faction flight master and not otherwise;
  - duplicates are dropped;
  - output rows have every field.
- **Real data (`test/test_data.lua`):**
  - Towns.lua loads;
  - every town sits inside its zone's rectangle;
  - Darnassus, Kharanos and Sentinel Hill are places;
  - the fallback-zone list is updated and pinned (expect it to shrink, likely to Alterac Mountains, Deadwind Pass or Shen'dralas, or to none);
  - no two offered candidates share a name within 300 yd.
- **Search:**
  - towns are offered;
  - a same-named enemy stop is hidden when a legal one exists;
  - the cross-faction tie is pinned.
- **Planner:**
  - the wheel scrolls and clamps;
  - the footer text is right, and hidden when everything fits;
  - Enter picks the top shown row;
  - typing resets the window;
  - with the box empty, the list is recents then zones with counts;
  - clicking a zone row fills the box and lists that zone's places;
  - no zone row is ever routed to.

## In game (checklist)
- "kha" finds Kharanos, and "darn" finds Darnassus as a place, not "(zone)".
- The wheel scrolls a long list, and the footer reads right.
- ▼ with an empty box shows recents, then zones with counts. Clicking Ashenvale lists its towns.
- A town's position is its middle. Walk to one and note how far the "arrived" point sits from where you would want it.

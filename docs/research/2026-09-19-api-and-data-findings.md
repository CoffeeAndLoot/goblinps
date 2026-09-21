# API and data findings, 2026-09-19

Gathered while porting HealMe to the WoW Forever beta. Everything marked
**source-verified** was read in the `forever` branch of
github.com/Gethe/wow-ui-source (build 1.60.1.69913) or fetched from
wago.tools for that build. **Nothing here has been run in game yet**, except
where stated. The in-game probes are in `docs/manual-test-checklist.md`.

## The client

- Install: `D:\World of Warcraft\_classic_beta_`, product `wow_classic_beta`,
  build **1.60.1.69913**, TOC interface **16001**.
- It is a Classic-data client on the **Retail 12.0.7 engine**: it ships
  `Blizzard_Deprecated/Mainline/Deprecated_12_0_7.lua`, and every modern API
  HealMe uses (C_Spell, C_AddOns, TabSystem, WowStyle1Dropdown, EditMode,
  AddonCompartment, duration objects) exists.
- Its TOC game type appears to be **`camelot`** (inferred from
  `AllowLoadGameType: classic, standard, camelot` and `Camelot/` source
  folders; not confirmed by the client).
- No flying. Ground mounts and the built-in transport network only. Blizzard
  intends to grow the game "horizontally" rather than by expansions.
- **`SavedVariablesPerCharacter` is written and never loaded** (verified in
  game 2026-09-21, character "Coffee Issues" on realm "Classic Beta PvE 2").
  After a `/reload`, before any GoblinPS window opened,
  `/run print(GoblinPSCharDB, GoblinPSDB)` printed `nil` for the
  per-character table and a table for the account-wide one -- while the
  per-character file on disk, rewritten by that same reload, held the two
  learned flight paths. The account-wide save round-trips; the per-character
  one does not. The account folder holds two realm directories created in the
  same minute: `70/` (where every per-character save is written, Blizzard's
  own included, under folders like `Coffee-Issues`) and
  `Classic Beta PvE 2/` (holding only `AddOns.txt`, under folders cut off at
  the space: `Coffee`). Every character tested has a two-word name, so the
  likely cause is how this beta names per-character folders -- **unconfirmed**,
  and nothing depends on it. GoblinPS now keeps learned flight paths in the
  account-wide save under `"Name-Realm"` and declares no per-character
  variable. That makes three things on this client that are present and do
  not work.
- **`C_Map.GetMapLevels` is DEAD on this build** (verified in game
  2026-09-20). `/gps probe zones` asked it for all 60 zones and it answered
  for **none**. It is present — `/gps selftest` reports it `ok` — and it is
  documented, and it returns nothing useful, which is the second API on this
  client to behave that way. **`Data/Zones.lua` stays hand-written**, and the
  level ranges must be read off the world map's zone tooltips after all.
  Keep the probe: it costs nothing, and it will start working by itself if a
  later build fixes the function.
  This is now a pattern worth stating plainly: on this beta, *present* and
  *documented* say nothing about *answers*. Two for two. Any future API this
  project leans on gets a probe that counts its answers and says so when there
  are none, rather than letting silence read as agreement.
- **`C_Map.GetMapLevels(uiMapID)` exists in this build's source** and is what
  draws the level range on Blizzard's own world map. It returns
  `playerMinLevel, playerMaxLevel, petMinLevel, petMaxLevel`;
  `Blizzard_SharedMapDataProviders/AreaLabelDataProvider.lua:86` calls it and
  guards with `> 0` on line 87; its documentation block opens at
  `MapDocumentation.lua:346`, with `Name = "GetMapLevels"` on 347 and
  `MayReturnNothing = true` on 349. **Unverified in game**: `isUndiscovered` is
  proof that a function can exist and answer uselessly, so `/gps probe zones`
  asks it for every zone and says plainly when it answers for none.
  **It did answer for none: see the entry above.** The design held — the
  probe reported the silence instead of reading it as agreement — but the
  hoped-for outcome did not arrive.
  The DB2 route is a dead end on this build and was tried first, by fetching
  the tables from wago.tools for build 1.60.1.69913 on 2026-09-20 (the same
  URL pattern `tools/build_graph.py` uses; the cache is gitignored, so re-run
  it to see for yourself): `UiMap` has a `ContentTuningID` column but **all 60
  rows are 0**, and `ContentTuning` has no min or max level columns at all,
  only `LfgMinLevel`, `LfgMaxLevel` and `MinLevelSquish`/`MaxLevelSquish`.
  `WorldMapArea` returns 404 for this build. So zone level ranges cannot be
  generated from wago.tools; they come from the client or from hand.
- **The client loads the TGAs our tools write** (verified in game 2026-09-20).
  `/gps selftest` reported `ok` for all five dash textures under
  `Interface\AddOns\GoblinPS\Media\`, and `SetTexture` returns whether the
  file actually loaded, so this is a real load and not a path check. They are
  256-square and 128x32 power-of-two uncompressed 32-bit TGAs written by
  Pillow in `tools/make_art.py` from Codex's PNGs. **This retires the open
  question about the art pipeline**: the remaining 34 parts can ship the same
  way, and no BLP conversion is needed.
- **Base movement is exactly 7 yards a second** (verified in game 2026-09-20).
  `GetUnitSpeed("player")` unmounted returned `0, 7, 7, 4.7222218513489`:
  current, run, flight, swim. `Travel.WALK_YARDS_PER_SECOND = 7` is therefore
  measured, not assumed, and every walking time the addon prints rests on it.
  Swimming at 4.72 is not modelled. The two **mount** speeds follow from the
  user's statement (2026-09-20) that Forever uses vanilla riding, so +60% and
  +100% of that measured base: 11.2 and 14. Stated rather than measured, on a
  measured base. `GetUnitSpeed` from horseback would confirm it in five
  seconds and is worth doing when convenient, but nothing is blocked on it.
- **`GetPlayerFacing` and `UnitOnTaxi` are present** (`/gps selftest`,
  2026-09-20). Presence only: neither has been seen to return a useful value
  yet, and the arrow's rotation direction remains underived from anything the
  client has told us. `C_Map.GetMapLevels` is present too, which is not the
  same as answering — `/gps probe zones` is still the test that settles it.
- **Riding is learned at the Classic levels** (verified in game 2026-09-20,
  from the riding trainer's list): Apprentice Riding requires level 40 and
  costs 95 gold; Journeyman Riding requires level 60 and Apprentice, and
  costs 950 gold. The trainer names no speed, so `Travel.MOUNTS` still
  assumes the Classic +60% and +100% (11.2 and 14 yards a second against 7
  on foot). To settle it, ride and run `/run print(GetUnitSpeed("player"))`,
  which reports yards per second directly.
- **Known Blizzard bug on this build:** `Blizzard_EnvironmentCleanup.toc`'s
  dependency on `Blizzard_RestrictedAddOnEnvironment` omits `camelot`, so it
  loads first and nils `loadstring_untainted`; every secure snippet then fails
  at `RestrictedExecution.lua:79`. Seen in game with HealMe. GoblinPS needs no
  secure code, so it is unaffected.

## Flight paths — the key API (source-verified, in-game unverified)

`Blizzard_APIDocumentationGenerated/TaxiMapDocumentation.lua`:

- `C_TaxiMap.GetTaxiNodesForMap(uiMapID)` — documented as "Returns information
  on taxi nodes for a given map, **without considering the current flight
  master**." Returns `MapTaxiNodeInfo`: `nodeID`, `position`, `name`,
  `atlasName`, `faction` (`Enum.FlightPathFaction`: Neutral/Horde/Alliance),
  `textureKit`, **`isUndiscovered`**.
- `C_TaxiMap.GetAllTaxiNodes(uiMapID)` — only meaningful at a flight master.
  Returns `TaxiNodeInfo` with `state` (`Enum.FlightPathState`: Current,
  Reachable, Unreachable), `slotIndex`, `position`.
- `C_TaxiMap.ShouldMapShowTaxiNodes(uiMapID)`.
- Events: `TAXI_NODE_STATUS_CHANGED`, `TAXIMAP_OPENED`, `TAXIMAP_CLOSED`.

Blizzard's own world map uses exactly this:
`Blizzard_SharedMapDataProviders/FlightPointDataProvider.lua` calls
`GetTaxiNodesForMap(mapID)`, labels `isUndiscovered` nodes, and refreshes on
`TAXI_NODE_STATUS_CHANGED`. On old Classic clients known flight paths were
only readable with the taxi map open and had to be cached; here they should
not need caching.

**Verified in game 2026-09-19 (Horde character, `/gps probe` and `/run`):**

- `GetTaxiNodesForMap(1414)` + `(1415)` return **74 nodes**: our 71 plus the
  three `zzOLD` Riverglades rows. The continent maps aggregate every node.
- API `nodeID` **equals** `TaxiNodes.ID`, and names match: 0 differences.
- **`isUndiscovered` is dead on this build.** It is `false` for every node,
  including Sun Rock Retreat (29) on a character who has never been there,
  asked on the continent map (1414) and on the zone map (1442) alike. The
  field exists but is never filled in. It cannot be used.

So known flight paths must be learned the old Classic way: read
`C_TaxiMap.GetAllTaxiNodes(uiMapID)` while a flight master's map is open
(`TAXIMAP_OPENED`) and remember the result per character. The source ships
both a modern `Blizzard_FlightMap` (uses `GetAllTaxiNodes`) and the legacy
`TaxiFrame.lua` (`NumTaxiNodes`, `TaxiNodeGetType`).

**Verified in game 2026-09-19 at the Thunder Bluff flight master** (dump
captured on `TAXIMAP_OPENED`, identical 0.5 s later):

- `TAXIMAP_OPENED` fires, with `system = 1`. `GetTaxiMapID()` returns 1464.
- While the map is open, `C_TaxiMap.GetAllTaxiNodes(map)` returns the same 22
  nodes for 1464, the continent (1414), Azeroth (947) and the player's own
  map (1456): every Horde and neutral node on Kalimdor, discovered or not.
  Asked for the other continent (1415) it returns nothing. With no flight
  map open it returns nothing at all, and `GetTaxiMapID()` is nil.
- `state` is truthful: 0 current (Thunder Bluff), 1 reachable (Orgrimmar,
  Crossroads, Camp Taurajo, Ratchet: exactly the character's paths),
  2 unreachable (the other 17, including Sun Rock Retreat, never visited).
- The legacy calls agree: `NumTaxiNodes()` is 22 and `TaxiNodeGetType` gives
  CURRENT / REACHABLE / DISTANT for the same nodes.
- The list includes Mount Hyjal flight points (Summit of Eternity 3242,
  Tainted Foothills 559) and the stale `zzOLDPowderfuse Port` (3208).

## Position, waypoints, hearthstone (source-verified)

- `C_Map.GetPlayerMapPosition(uiMapID, "player")` — nil inside instances.
- `C_Map.GetWorldPosFromMapPos`, `C_Map.GetBestMapForUnit`.
- `C_Map.SetUserWaypoint` + `C_SuperTrack.SetSuperTrackedUserWaypoint` — the
  built-in map pin and on-screen arrow. The world map's Ctrl-click creates a
  user waypoint; listen for `USER_WAYPOINT_UPDATED`.
- Events confirmed present for arrival detection: `USER_WAYPOINT_UPDATED`,
  `SUPER_TRACKING_CHANGED`, `ZONE_CHANGED`, `ZONE_CHANGED_NEW_AREA`,
  `PLAYER_CONTROL_LOST` / `PLAYER_CONTROL_GAINED` (taxi start/end),
  `HEARTHSTONE_BOUND`. `UnitOnTaxi` is also documented.
- `GetBindLocation()` — hearthstone bind name (a string; mapping it to a graph
  node needs a name table or the nearest-inn approach).

## Embedded map (source-verified)

`Blizzard_MapCanvas/Blizzard_MapCanvas.xml` ships `MapCanvasFrameTemplate`,
`MapCanvasFrameScrollContainerTemplate`, `MapCanvasDetailLayerTemplate`.
`MapCanvasMixin` offers `SetMapID`, `AddDataProvider`, `AcquirePin`,
`NavigateToParentMap`, `AddCanvasClickHandler`, `GetNormalizedCursorPosition`,
`SetShouldZoomInOnClick`, `SetShouldNavigateOnClick`. `Blizzard_BattlefieldMap`
is Blizzard's own small embedded canvas and is the model to read.
`FlightPointDataProviderMixin` can be added to our canvas to draw flight
masters with discovered state for free. The canvas is the most intricate
Blizzard UI piece we touch: build it behind a fallback.

## Game data (fetched from wago.tools for build 1.60.1.69913)

Snapshots are in `docs/research/data/`. URL form:
`https://wago.tools/db2/<Table>/csv?build=1.60.1.69913`

| Table | Rows | Use |
|---|---|---|
| `TaxiNodes` | 100 | flight masters: `ID`, `Name_lang`, world `Pos_0..2`, `ContinentID`, `Flags` |
| `TaxiPath` | 328 | directed flight edges: `FromTaxiNode`, `ToTaxiNode`, **`Cost`** (copper) |
| `TaxiPathNode` | ~10,800 (754 KB, not snapshotted) | spline points per path; path length gives a flight-time estimate |
| `UiMap` | 60 | map tree: `ID`, `Name_lang`, `ParentUiMapID`, `Type` (1 world, 2 continent, 3 zone) |
| `UiMapAssignment` | 61 | world-coordinate bounds per UiMap; converts `TaxiNodes.Pos` to map x/y |

- `TaxiNodes.Flags` seen: 1024, 1025, 1026, 1027, 1152, 0. Inferred: bit 1 =
  Alliance, bit 2 = Horde (so 1027 = both), 1024 = shown on map. **Verify**
  against known nodes (Stormwind is 1025, so Alliance fits).
- `ContinentID`: 0 Eastern Kingdoms, 1 Kalimdor, 30 Alterac Valley.
- UiMap IDs are the Classic set: 947 Azeroth, 1414 Kalimdor, 1415 Eastern
  Kingdoms, 1411 Durotar, 1412 Mulgore, 1413 The Barrens, 1453 Stormwind,
  1454 Orgrimmar, 1455 Ironforge, 1456 Thunder Bluff, 1457 Darnassus,
  1458 Undercity, zones 1416–1452.
- **New in Forever:** 2482 Mount Hyjal, 2521/2665 Zephras Isle,
  2524 Darkspear Islands, 2548 Riverglades, 2652 Shen'dralas. How these are
  reached is unknown; find out in game and add hand-written links.
- Not in any table we found: boats, zeppelins, the Deeprun Tram, zone border
  crossings. These are the hand-written `Links` data.

## Forever Atlas (fan web map), read 2026-09-19

`https://benjamh681.github.io/wow-forever-atlas/` (repo
`benjamh681/wow-forever-atlas`, a single `index.html`). The site has **no
license**, which covers its author's own work: the prose, the hand-drawn zone
shapes and the code. None of that is used. The facts it records (which zones
border which, place names, level ranges, which routes Blizzard has
announced) are facts about Blizzard's game and are used freely, as a
checklist against our own tables. It has its own browser route planner,
which cannot know a character's flight paths.

Its `ROUTES` table carries a confidence mark per route. Marked "stated by
Blizzard" and new in Forever (all **unverified in game**):

- Stormwind Harbor ↔ Auberdine, Alliance boat.
- Menethil ↔ Southshore ↔ Auberdine on one line; whether the classic direct
  Menethil ↔ Auberdine boat stays is unconfirmed.
- Steamwheedle Port ↔ Powderfuse Port, neutral boat (Powderfuse looks to be
  on the Riverglades coast).

Classic carry-overs listed: zeppelins Orgrimmar ↔ Undercity, Orgrimmar ↔
Grom'gol, Undercity ↔ Grom'gol; boats Menethil ↔ Theramore, Auberdine ↔
Rut'theran, Booty Bay ↔ Ratchet, Feathermoon ↔ Forgotten Coast; Deeprun Tram.
It also has a `LAND_EDGES` table of walkable zone crossings with warnings
(for the later ground-crossings work), and notes Quel'Thalas and Gilneas as
closed. Its sources include Blizzard's two panel recaps and Wowhead's
datamined maps.

**Flight times:** the atlas uses community-measured times from the InFlight
addon (`github.com/BLCtbc/inflight`), in seconds per node pair. Measured
times beat a spline-length estimate. Check InFlight's license before using
its numbers; keep the spline estimate as the fallback for unmeasured paths.

## The generator to copy

`D:\looseEnds\tools\build_catalog.py`: `TABLES` list, `WAGO` URL template,
`tools/catalog.lock` build pin, CSV cache under `tools/cache/` (gitignored),
`fetch_tables`, `load_tables` with missing-column checks, `world_to_map`
(UiMapAssignment world→map conversion, exactly what flight master positions
need), `lua_value` emitter, `HEADER` "Generated ... Do not edit." Python
tests live in `test/tools/`. Patch day = bump the lock, re-run.

## Patterns to borrow from the siblings

- LooseEnds: `API.lua` as the single file touching Blizzard globals, so tests
  stub it; `Events.lua` pub/sub; pure `Scan`/`Tree` modules feeding the window.
- HealMe: `Widgets.lua` constructors that check for a template or atlas and
  fall back; `SelfTest.lua` in-game check of every template and atlas;
  draggable minimap button; `AddonCompartmentFunc`; options on
  `PortraitFrameTemplate`; destructive actions through `Widgets.Confirm`.
- Both: lupa test runner, luacheck, lua-language-server, calendar versions,
  junction install, Wago release flow with `## X-Wago-ID`.

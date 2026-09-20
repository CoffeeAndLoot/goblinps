# GoblinPS design

Status: **approved by the user on 2026-09-19.** Implemented in four plans
under `docs/superpowers/plans/`: 1 routing core (done), 2 planner window,
3 schematic map, 4 dash unit. Each is written after the one before it has
been used in game. Update this file whenever behaviour changes.

## Purpose

A route planner for WoW Forever. "I'm in Thunder Bluff and need to get to
Undercity: what's my route?" Forever has no flying, so routes combine flight
paths, boats, zeppelins, the tram, the hearthstone and riding. For everyone:
newcomers who don't know the world and veterans on alts missing flight paths.

Not a quest guide. It never says what to do, only how to get there.

The name is a Garmin joke: Goblin Positioning System. Slash command `/gps`.

## Decisions

1. **Routing is per character.** A flight edge is usable only if both ends
   are discovered. The client's live flag (`isUndiscovered` from
   `C_TaxiMap.GetTaxiNodesForMap`) is **dead on build 1.60.1.69913**: false
   for every node, verified in game. So discovered paths are learned at
   flight masters: on `TAXIMAP_OPENED`, `C_TaxiMap.GetAllTaxiNodes` marks
   each node on the continent current, reachable or unreachable, and the
   flyable ones are remembered per character. Flight paths are never
   unlearned, so the memory only grows; one flight master visit per
   continent gives the full picture. Before any visit the character is
   treated as knowing none, and the addon says so.
2. **Start defaults to where the player stands**; a "From:" control can
   change it to any stop or zone.
3. **Two frames (Garmin model).**
   - *Planner*: the big device. Search box, schematic map, step list, route
     line drawn on the map.
   - *Dash unit*: a small draggable device shown after "Go". Current step
     plus the next ("Fly to Orgrimmar · then Zeppelin to Tirisfal"), advances
     on arrival, shows "Recalculating…" when the player strays, sets
     Blizzard's map waypoint and arrow on the current step.
4. **Destination input, three ways:** type-ahead search over cities, zones
   and flight masters with recents on top; click a zone or stop on the
   schematic map; Ctrl-click on Blizzard's world map for an exact spot
   (react to `USER_WAYPOINT_UPDATED`).
5. **The map is our own schematic, not Blizzard's canvas.** One hand-drawn
   world texture in a transit-map style (both continents, zone blobs, the
   new Forever zones). Our own pins for stops; the route drawn over it with
   `CreateLine`. No zoom, no `MapCanvasFrameTemplate`. Stop positions come
   from the generator: one linear world-to-schematic transform per continent,
   with hand overrides where a pin lands in the wrong blob. The art is ours;
   the Forever Atlas fan map is a style reference only (it has no license).
   **Palette: green screen** (chosen from mockups over navy and amber).
   Faction zones are subtle tints; the amber route is the only bright thing.
   The art is greyscale layers (base, Horde zones, Alliance zones) tinted in
   code, so the palette is colour constants, not a redraw.
6. **v1 graph scope:** flight edges (generated), boats, zeppelins and the
   tram (hand-written, about a dozen), the hearthstone, and a straight-line
   ride at each end. Zone-to-zone ground crossings are **later**, and must
   arrive as more rows in the same links table, not a redesign.
7. **Look: "Goblin Gadget".** A dented brass device: rivets, hazard-stripe
   trim, a green screen. Palette: brass/copper, oily dark steel, screen
   green, hazard orange. Humour in the frame, tagline and tooltips
   ("Accuracy not guaranteed. No refunds.", "May explode."), never in the
   directions, which stay plain and glanceable. A few small custom textures;
   colours and fonts otherwise. The window uses no Blizzard frame templates
   at all: plain frames in the palette's flat colours, with art laid over
   them (docs/art-specs.md), so a missing texture or a renamed template
   cannot break it.
8. **Show the fare.** `TaxiPath.Cost` is in the data; per step and in total.
9. **No class travel in v1.** No mage teleports or portals, druid Moonglade
   or warlock summons. The hearthstone is the only personal teleport. The
   links table leaves room for a `requires` field later.
10. **Hearthstone: available or absent.** If the hearthstone is on cooldown
    (or missing), it is simply not part of the calculation; the router never
    says "wait, then hearth". The bind point comes from `GetBindLocation()`,
    matched by name against generated flight-node, zone and city names. No
    match means no hearth edge and a small "Hearth: unknown inn" note, never
    an error. Hand-written rows in Data/Inns.lua cover inns beside a
    differently named flight stop and towns with an inn but no flight
    master; add a row whenever "unknown inn" is seen in game.
11. **Boats, zeppelins and the tram carry a fixed average wait.** Each link's
    `minutes` is ride time plus about half its loop, so the router compares
    them fairly against flights. The step shows it plainly:
    "Zeppelin to Tirisfal (~5 min incl. wait)".
12. **"Discover X to save ~N min" is in v1.** `Route` runs a second time with
    every faction-legal flight node treated as known. If that route is at
    least 2 minutes faster, one line under the step list names the first two
    missing stops and says how many more it needs when there are more
    ("Discover Alpha, Bravo and 3 more to save ~8 min").
13. **Two planner layouts with a toggle.** Wide (map left, steps right, about
    640×380) and tall (map on top, steps below, about 380×560). Hard rule:
    one set of widgets; a single `ApplyLayout(mode)` changes only anchors and
    frame size. The mode is a saved preference. Every planner UI change is
    checked in both modes. If it ever needs two sets of widgets, cut one.
14. **Entry points:** `/gps`, a draggable minimap button, and an addon
    compartment entry, as in HealMe.

## Data

Game data is fetched ahead of time and shipped as Lua. The addon never
fetches anything in game.

**Generated** by `tools/build_graph.py` from wago.tools (`TaxiNodes`,
`TaxiPath`, `TaxiPathNode`, `UiMap`, `UiMapAssignment`), pinned by
`tools/catalog.lock`, modelled on `D:\looseEnds\tools\build_catalog.py`:

- Flight nodes: id, name, faction, continent, zone, schematic position, real
  map position (uiMapID, x, y) for the waypoint.
- Flight edges: from, to, fare in copper, seconds. Seconds are the path's
  polyline length (`TaxiPathNode`) divided by 32 yards per second. Checked
  against four community-measured Classic times: within about 15%, which is
  fine for a "~" figure, so no third-party timing data is used.
- The generator skips nodes with no faction bit, nodes off the two
  continents, Blizzard's abandoned `zzOLD` rows, and paths to missing nodes.
  Zone rectangles overlap, so a node's zone comes from its own name first.
- Search index: zones, cities and stops.

The Blizzard developer web API is not a source: it has no taxi data and no
beta build match.

**Hand-written** `Data/Links.lua`: rows of
`{from, to, kind, minutes, faction}` for boats, zeppelins and the tram, with
hand-placed dock positions. New Forever routes (Stormwind Harbor ↔ Auberdine,
Menethil ↔ Southshore ↔ Auberdine, Steamwheedle ↔ Powderfuse) go in only
once confirmed in game.

## Modules

Each opens with `local addonName, ns = ...` and publishes itself on `ns`.

- **`API`**: the only file that calls Blizzard game APIs (`C_*`, unit, item,
  map functions). `Core` additionally registers the slash command
  (`SLASH_*`, `SlashCmdList`) and prints to chat. `KnownNodes()`,
  `PlayerPosition()`, `HearthNode()` (nil when on cooldown or unmatched),
  `SetWaypoint()` / `ClearWaypoint()`, faction. `OpenTaxiNodes()` reads the open flight master's map and
  `OnTaxiMapOpened()` reports when one opens; the pure `Known` module turns
  that into the remembered set. `Graph` and `Route` only ever see a
  `{ [nodeID] = true }` set, so they did not change when the live flag
  turned out to be dead.
- **`Graph`** (pure): takes the data, a known-node set, the faction and an
  optional hearth node. Flight edges need both ends known; link edges are
  filtered by faction; the hearth is one edge from the start. Start and
  destination are temporary nodes with "ride" edges to nearby stops on the
  same continent, timed as straight-line distance over mount speed. This
  undersells mountains; it is an honest "~" until ground crossings arrive.
  A ride edge never joins two different landmasses, even on the same
  continent: a hand-written `Islands` table (`Data/Links.lua`) names the
  UiMaps that are their own landmass (Teldrassil today); a map not listed
  is the mainland. Sardor Isle is treated as joined to the mainland until
  ground crossings arrive, so its Feathermoon ↔ Forgotten Coast ferry is
  deferred with them. A zone destination is reached at any place on the
  zone's map: that ride to the destination costs nothing, so hearthing to
  Crossroads for "The Barrens" does not add a ride to the zone's centre.
- **`Route`** (pure): Dijkstra by seconds. Returns steps
  `{kind, from, to, seconds, copper}` plus totals. `Route.Hint` does the
  "discover X" comparison. One plain step-text formatter, no jokes.
- **`Trip`** (pure): the arrival rules. Given the current step, a position
  and an event, answers advance, recalculate or stay.
- **`Events`**: pub/sub, as in LooseEnds.
- **`Widgets`**: constructors that check for a template or atlas and fall
  back to a plain control, as in HealMe.
- **`Planner`**, **`MapView`**, **`Dash`**, **`SelfTest`**, **`Core`**.

## Behaviour

**Planner.** Re-plans when the start or destination changes, when GO is
pressed, and when a flight master visit teaches it a new path
(`TAXIMAP_OPENED`). Shows steps, the hint line, total time and fare, and Go.

**Dash.** Sets the waypoint on the current step's target. Its close button
ends the trip and clears the waypoint only if it is still the one we set.

**Arrival detection.** `Trip.Check` implements the rules below with one
positional test: inside the step kind's arrival radius and not on a taxi.
The events only make the dash check sooner. Per step kind:

- Ride: within a small radius of the stop. Position is polled about once a
  second, only while a trip is active.
- Flight: `PLAYER_CONTROL_GAINED` after being on a taxi, and near the
  expected node.
- Boat, zeppelin, tram: zone change (`ZONE_CHANGED_NEW_AREA`) and now on the
  target continent or zone.
- Hearthstone: zone change and near the bind node.
- Strayed (far from the current step, or landed somewhere unexpected):
  "Recalculating…" and re-plan from the current position. Only on those
  triggers, never in a loop.
- In an instance the position is nil: the dash pauses and does not guess.

## Failure handling

Degrade, never error.

- Map texture missing: the planner is search + step list.
- Template or atlas missing: plain control.
- No route: "No route found to <place>." and, when knowing more flight
  paths would help, the "Discover ..." line.
- Unknown hearth bind name: no hearth edge, small note.
- Every event name is checked against the local Forever source
  (`D:\wow-api\1.60.1.69913`) before it is registered.
- `/gps selftest` checks every template, atlas and texture in game.
- No secure code, anywhere.

## Saved variables

Per character (`GoblinPSCharDB`): `known`, the flight paths learned at
flight masters. Written only by `Known.Learn`; it only grows.

Account-wide (plan 2): preferences only: layout mode, window positions,
recent destinations, minimap button angle.

## Testing

- `Graph`, `Route`, `Trip` and the step formatter: desktop unit tests over a
  small fake world, run through lupa.
- The generator: Python tests under `test/tools/`.
- Frames and live game data: `docs/manual-test-checklist.md`, planner
  entries in both layouts.
- luacheck and lua-language-server stay at zero warnings.

## Prior art (searched 2026-09-19)

Nothing Forever-specific in game. ClassicPathCalculator (CurseForge) is the
closest: alt-click the map, shortest path with times, for Classic; no live
per-character discovery, no dash unit, no fares. FlightPath,
ClassicTravelPoints and HandyNotes_TravelGuide are pins and lists. The
Forever Atlas web map has a browser route planner that cannot know a
character's flight paths or position. classictinker.com's Flight Master tool
helps check the hand-written links.

## Still to verify in game

These do not block the plan; each has a designed fallback.

- ~~`isUndiscovered` is truthful and API `nodeID` equals `TaxiNodes.ID`.~~
  Settled 2026-09-19: node IDs and names match exactly (74 nodes: our 71
  plus three `zzOLD` rows); `isUndiscovered` is dead, so paths are learned
  at flight masters. Still to see: a known node that the current flight
  master cannot reach reads as unreachable there; it is learned on a later
  visit to a flight master that can reach it.
- `TaxiNodes.Flags` faction bits (1 = Alliance, 2 = Horde).
- How the new zones are reached (Mount Hyjal, Zephras Isle, Darkspear
  Islands, Riverglades, Shen'dralas) and the three new boat routes.
- The rest of the probes in `docs/manual-test-checklist.md`.

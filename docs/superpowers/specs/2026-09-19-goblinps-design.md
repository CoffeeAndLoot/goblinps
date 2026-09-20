# GoblinPS design

Status: **approved by the user on 2026-09-19.** Implemented in five plans
under `docs/superpowers/plans/`: 1 routing core (done), 2 planner window
(built), 3 ground crossings with walk-or-ride by level (built), 4 dash unit
(built), 5 route strip. Each is written after the one before it has been used in
game. Update this file whenever behaviour changes.

**What the product is** (the user, 2026-09-19, after trying a level-1
character): a GPS. Point to point to point, with the arrow and the map pin on
the next turn, advancing as you arrive. A web atlas can list a route; only an
addon can walk you along it. That is why ground crossings (the turns) and the
dash unit (the arrow) come before the route strip (the display), and why
decision 6's "ground crossings later" moved up: a new character with no
flight paths gets almost nothing from a straight line to a zone's centre.

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
   - *Planner*: the big device. Search box, the route strip, step list.
   - *Dash unit*: a small draggable round brass device opened when GO closes
     the planner. A green arrow that turns to point at the current step, with
     the distance and an ETA on the plate beneath it; the current step plus the
     next in text ("Fly to Orgrimmar · then Zeppelin to Tirisfal"); advances
     on arrival; shows "Recalculating…" when the player strays; sets Blizzard's
     map waypoint on each new step as the trip advances, not only on the first
     one. The arrow is its own texture, pointing up and centred on its pivot,
     so it can be rotated in code. An active trip is **not saved**: `/reload`
     ends it. The planner's recents make restarting one click. Reopening the
     planner with `/gps` carries the trip on without ending it.
4. **Destination input, two ways:** type-ahead search over cities, zones and
   flight masters with recents on top; Ctrl-click on Blizzard's world map for
   an exact spot (react to `USER_WAYPOINT_UPDATED`). A third way, clicking a
   zone on our own schematic map, went away with decision 5.
5. **The route is shown as a strip, not a map.** The middle of the planner is
   a horizontal run of stops: a brass ring per stop, an icon for how you get
   there (flight, boat, zeppelin, tram, hearthstone, gate, walk, ride), and a
   glowing line between them, solid behind you and dashed ahead. It is drawn
   straight from the step list, so it needs no world projection, no hand-drawn
   world texture and no pin placement. Chosen by the user on 2026-09-20 over a
   schematic world map ("the mockup, not an actual map"): a GPS shows the next
   few turns, not the whole country, and a strip stays readable at any window
   size, which a map does not.
   **Palette: green screen** (chosen from mockups over navy and amber). The
   glowing green route is the only bright thing; amber is for warnings only.
   The art is separate transparent parts specified in
   `docs/art-parts-brief.md`, laid over plain colour, so a missing texture
   still leaves a working window. PNGs in `images/parts/` are the source of
   truth and tracked in git. `tools/make_art.py` reads the PNGs, scales each
   to the size it draws at, pads to a power-of-two canvas, and writes shipped
   TGAs into `GoblinPS/Media/`, generating `GoblinPS/Data/Art.lua` with their
   texture coordinates. A separate `images/parts/export_tga.py` creates
   uncompressed TGAs at authoring resolution (~49 MiB, gitignored) for review;
   those are regenerable and are not inputs to anything.
   The schematic world map is **not being built.** The spike that proved it
   feasible is kept at `docs/research/schematic-spike/` in case a later
   version wants an overview panel; until then the generator's schematic
   positions are unused.
6. **Graph scope:** flight edges (generated), boats, zeppelins and the tram
   (hand-written, about a dozen), the hearthstone, and travel on the ground.
   Plans 1 and 2 shipped the ground as one straight-line ride at each end;
   plan 3 replaces that with zone-to-zone **ground crossings** (decisions
   15 to 19). That changes how `Graph` builds ride edges, which the first
   draft hoped to avoid; the straight line turned out to be useless for a
   character with no flight paths.
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
    `GetBindLocation()` returns the **subzone**, which inside a town is usually
    the inn building ("Gallows' End Tavern" for Brill, seen in game
    2026-09-20), so a building shares the row of the town it stands in.
    **The hearthstone must earn its cooldown.** The graph can price the cast
    and the loading screen (20s) but not the half-hour wait, so left alone the
    router spends the stone to save seconds: seen in game on 2026-09-20 taking
    it for a 0.4-second gain. `Route.Plan` plans both ways and keeps the
    hearthstone only when it saves at least `opts.hearthSaving`. That is a
    player preference (`GoblinPSDB.hearthSaving`, default five minutes,
    `/gps hearth <minutes>`, 0 meaning always fastest) because how freely to
    spend a hearthstone is a judgement about play, not about routing. It
    belongs in the settings panel when one exists. Refusing the stone never
    costs a route: the plain plan is returned instead.
11. **Boats, zeppelins and the tram carry a fixed average wait.** Each link's
    `minutes` is ride time plus about half its loop, so the router compares
    them fairly against flights. The step reads "Zeppelin to Tirisfal" with
    "includes the average wait" on its detail line; the minutes themselves go
    in the planner's own column and beside the step in chat. The step text
    carried them too until 2026-09-20, which printed the figure twice and ran
    the longest names past the right edge, where the client truncated them.
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
15. **Ground travel goes zone by zone, through named crossings.** Riding
    happens only inside one zone. To reach the next zone you pass a crossing:
    a named point on the border ("Mor'shan Rampart"). Cities are zones too,
    with their gates as crossings (Orgrimmar's front gate into Durotar and
    west gate into the Barrens; Undercity to Tirisfal; Thunder Bluff's lifts
    to Mulgore; Stormwind to Elwynn; Ironforge to Dun Morogh; Darnassus to
    Teldrassil). A long trip is a chain of short legs, each ending at a place
    an arrow can point at, which is what the dash unit needs. Inside a zone a
    leg is still a straight line (a cliff or a lake can be in the way): the
    error is bounded to one zone, and the "~" stays. A road network is out
    of scope unless play shows it matters. An island is just a zone with no
    land crossing, so the `Islands` table and the 800-yard "same town"
    transfer rule both go away.
16. **A crossing step reads as the turn, with the zone as detail:**
    "Walk to the Mor'shan Rampart" over a smaller line "into Ashenvale ·
    level 18-30". Every planner step becomes two lines (step, detail). A
    crossing's name reads the same whichever way you are going ("the
    Ashenvale-Felwood road", not "the road into Felwood"); the detail line
    gives the direction. When the crossing has a hazard or is unconfirmed,
    the hazard replaces the level range on the detail line, never both, so
    it is never the part that gets cut off.
17. **Walk or ride by level, as settings.** Below the first mount level the
    step says "Walk to" and uses walking speed; at or above it, "Ride to" and
    the mount's speed. The levels and speeds are named settings in one
    place. The **levels are confirmed** in game (2026-09-20, the riding
    trainer: Apprentice Riding requires level 40, Journeyman requires 60).
    The **speeds are not**: 11.2 and 14 yards a second are the Classic values
    the two skill names imply (+60% and +100% of 7 on foot), not yet
    measured. Level is a deliberate approximation of "has a mount"; the
    riding-skill and mount-list APIs are unverified on this client.
18. **Warn, never reroute.** The route is always the fastest. A step's detail
    line turns amber when its zone's level range starts well above the
    character's level, or when its crossing carries a hand-written hazard
    ("Timbermaw furbolgs attack until you have reputation with them"). The
    player decides. A "prefer safer routes" setting can come later.
19. **A hole in the crossings table never becomes "No route".** If no chain
    of crossings reaches the destination, the router falls back to the old
    straight line and labels the step "Walk toward Mount Hyjal (no mapped
    path)". The player still gets a direction; the label names the row to
    add. The desktop tests (below) are there so this is rare.

## Data

Game data is fetched ahead of time and shipped as Lua. The addon never
fetches anything in game.

**Generated** by `tools/build_graph.py` from wago.tools (`TaxiNodes`,
`TaxiPath`, `TaxiPathNode`, `UiMap`, `UiMapAssignment`), pinned by
`tools/catalog.lock`, modelled on `D:\looseEnds\tools\build_catalog.py`:

- Flight nodes: id, name, faction, continent, zone, schematic position, real
  map position (uiMapID, x, y) for the waypoint. The schematic position is
  generated but unused while decision 5 stands.
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

**Hand-written for ground travel (plan 3):**

- `Data/Crossings.lua`: 56 rows, six of them for Forever's new zones. Each
  row: the two zone UiMaps, the crossing's name, one map point, an optional
  hazard note, an optional `cross` seconds (a tunnel, a lift or a mountain
  pass takes time to walk even though the point is one for both zones, so
  the passage time is paid once per traversal), an optional faction. Which
  zones border which, the place names and the level ranges are facts about
  Blizzard's game; the Forever Atlas fan site's table served as a checklist
  of those facts and supplied four crossings the first draft missed. The
  rows, the wording and every coordinate are our own; the atlas's prose,
  drawn zone shapes and code are its author's and are not used. Coordinates
  start as estimates and are corrected in game, like the dock positions.
  Unverified rows (the new zones and Orgrimmar's west gate, whose crossing
  is a guess or unwalked) say "crossing not confirmed" in amber on the
  step's detail line until walked and cleared.
- `Data/Zones.lua`: level range per zone (about 45 rows), for the warnings.
- Travel settings (speeds and mount levels) as named constants in one place.

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
  destination are temporary nodes. **Until plan 3:** ride edges run to
  nearby stops on the same continent as straight lines, never between two
  landmasses (a hand-written `Islands` table), with Sardor Isle treated as
  mainland and its ferry deferred. **From plan 3:** a ride edge joins two
  points only when they are in the same zone; a crossing is a point that
  belongs to both of its zones, so Dijkstra chains zones through crossings.
  The `Islands` table and the 800-yard transfer rule are deleted, and the
  travel speed comes in with the options (walk or mount, by level). Sardor
  Isle shares Feralas's map, and ground travel is per map, so the isle still
  counts as part of Feralas and its ferry stays out (a ride inside the zone
  would always undercut it). If no route exists with
  crossings alone, the graph is rebuilt with the old continent-wide straight
  lines and those steps are flagged rough. A zone destination is reached at
  any place on the
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
- No chain of crossings to the destination: the straight line, labelled
  "(no mapped path)", never "No route" (decision 19).
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
- Ground crossings: an **all-pairs test** over the real data. Every zone to
  every other zone on its continent must connect through crossings alone,
  except a short written list of allowed exceptions (islands, closed zones);
  a forgotten crossing fails on the desktop. Each row is checked too: its
  zones exist and its point lies in or near both. A real-route test pins the
  example that prompted the feature: Deathknell to Mount Hyjal, Horde, no
  flight paths, by zeppelin and then zone by zone.
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
- ~~Mount levels on Forever.~~ Settled 2026-09-20 at the riding trainer:
  Apprentice Riding requires level 40, Journeyman requires 60, exactly as
  Classic. The **speeds** are still assumed from the skill names (+60% and
  +100%): measure them with `GetUnitSpeed("player")` while mounted.
- Every crossing point's coordinates, and which crossings Forever added or
  closed (Mount Hyjal by Darkwhisper Gorge, Riverglades, Shen'dralas).
  Shen'dralas is entered from Desolace by the Valley of Bones (stated by
  Blizzard); Riverglades also borders the Burning Steppes, the Swamp of
  Sorrows and the Badlands (stated by Blizzard, crossing points unknown).
- The rest of the probes in `docs/manual-test-checklist.md`.

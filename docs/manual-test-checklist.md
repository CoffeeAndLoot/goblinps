# GoblinPS manual test checklist

Frames and live game data cannot run outside the client. Add an entry for
every UI change.

## Probes to run before any code (WoW Forever beta, 1.60.1.69913)

These decide the design. Record the result beside each one.

- [ ] `/dump C_TaxiMap.GetTaxiNodesForMap(1411)` (Durotar) away from any
      flight master: returns nodes, each with `isUndiscovered` true or false
- [ ] Same call for a zone where the character knows no flight paths:
      `isUndiscovered` is true there and false for a known one
- [ ] A returned `nodeID` matches the `ID` of the same-named row in
      `docs/research/data/TaxiNodes.csv`
- [ ] Learn a new flight path: `TAXI_NODE_STATUS_CHANGED` fires
      (`/etrace` or `/eventtrace`) and the call above flips to discovered
- [ ] `/dump C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit("player"), "player")`
      returns a position in the open world
- [ ] `/dump GetBindLocation()` returns the inn's area name
- [ ] Ctrl-click the world map: a waypoint pin appears; note which event
      fires in `/etrace`
- [ ] `/run C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(1411, 0.5, 0.5)); C_SuperTrack.SetSuperTrackedUserWaypoint(true)`
      shows the pin and the on-screen arrow
- [ ] Note how each new zone is reached: Mount Hyjal, Zephras Isle,
      Darkspear Islands, Riverglades, Shen'dralas

## Routing core (plan 1)

- [x] The addon loads with no Lua error; `/gps` prints the two usage lines
      (2026-09-19: loads and `/gps to` runs; usage lines not yet looked at)
- [x] `/gps probe`: node IDs and names match the client. 2026-09-19: 74
      nodes listed, 0 named differently; the 3 "not in our data" are
      Blizzard's `zzOLD` Riverglades rows, skipped on purpose. It also showed
      every node as known: `isUndiscovered` is dead on this build, which is
      why flight paths are now learned at flight masters
- [x] On a fresh character file, `/gps to orgrimmar` says "Visit a flight
      master so GoblinPS can learn your flight paths" and offers no flights
      (2026-09-19: `/gps to stonetalon` printed the notice, a ride-only
      route, and "Discover Crossroads and Sun Rock Retreat to save ~4 min".
      A misspelt place printed `No place matches`.)
- [x] Open a flight master's map: chat says "Learned N flight paths here
      (M known)", and N matches the paths lit up on that map
      (2026-09-19 at Crossroads: learned 5 = Crossroads, Orgrimmar, Ratchet,
      Camp Taurajo, Thunder Bluff, exactly the five on the flight map.
      Forever shows the legacy parchment flight map, not the zoomable one.)
- [x] After that, `/gps to stonetalon` (or any zone whose flight path you
      lack) no longer flies there; it ends with a "Discover ..." line
      (2026-09-19: no flight to Sun Rock Retreat; hint "to save ~4 min".
      `/gps to undercity` flies to Orgrimmar, a path the character has.)
- [ ] `/gps probe` reports "Learned from flight masters so far: M"
- [ ] Open the same flight map again: no "Learned" message (nothing new)
- [ ] `/reload`, then `/gps to orgrimmar`: the flights are still known
- [ ] Visit a flight master on the other continent: its paths are added and
      the first continent's are kept
- [ ] `/gps to <a city you can reach>` prints numbered steps, a total time
      and a fare; the steps are the route you would actually take
      (2026-09-19, Horde near Thunder Bluff, `/gps to undercity`: ride to
      Thunder Bluff, fly to Orgrimmar, ride to the tower, zeppelin, ride to
      Undercity; ~10 min, 50c. The route was right, but it proved nothing
      about discovery: at that point every node read as known. Re-run after
      a flight master visit.)
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
- [ ] `/gps probe`'s node count N is about 71: this proves
      `C_TaxiMap.GetTaxiNodesForMap(continent map)` returns every node on the
      continent, not only the displayed zone's. If N is far lower, record it:
      `API.TaxiNodes` must then walk every zone map.
- [ ] Standing on Zephras Isle or the Darkspear Islands, `/gps to orgrimmar`
      says it cannot tell where you are: these maps are off the two
      continents and are not routable yet. Record how each is reached.

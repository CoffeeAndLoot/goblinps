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

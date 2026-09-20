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
      (Moot: isUndiscovered is dead on this build. GoblinPS registers
      TAXIMAP_OPENED only; do not add this event.)
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
      (2026-09-19: loads and `/gps to` runs; usage lines not yet looked at.
      Since plan 2, /gps opens the planner; /gps help (any unknown word)
      prints five usage lines.)
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
- [x] Open the same flight map again: no "Learned" message (nothing new)
      (2026-09-19: reopened Crossroads, chat stayed quiet)
- [x] `/reload`, then `/gps to orgrimmar`: the flights are still known
      (2026-09-19: after a /reload in Undercity, `/gps to thunder bluff`
      still flew Crossroads to Thunder Bluff)
- [x] Visit a flight master on the other continent: its paths are added and
      the first continent's are kept
      (2026-09-19 at Undercity: "Learned 3 flight paths here (8 known)" =
      5 Kalimdor + 3 Eastern Kingdoms. Note: it learns when the flight MAP
      opens, not when you only talk to the flight master.)
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
      (2026-09-19, bound at the Crossroads inn, from Undercity: first run
      said "unknown inn (The Crossroads)": the bind name carries "The", fixed
      in Search.Exact. After the fix: "Hearthstone to Crossroads, Fly to
      Thunder Bluff", ~3 min, 1s 10c. The on-cooldown half is still to see.)
- [x] Known wart for plan 2: a zone destination aims at the zone's centre, so
      hearthing to Crossroads for "The Barrens" adds "Ride to The Barrens".
      Arriving at any stop inside the destination zone should count. (done in plan 2)
- [x] Inns in towns with no flight master (Brill, Razor Hill, Goldshire,
      Kharanos ...) do not match a bind name; plan 2 adds a hand-written
      inn list (done in plan 2)
- [ ] `/gps to qqqq` prints `No place matches "qqqq".`
- [ ] Inside an instance `/gps to orgrimmar` prints "Can't tell where you are"
- [ ] Stand on each dock and compare `/dump C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit("player"), "player"):GetXY()`
      with its row in `GoblinPS/Data/Links.lua`; correct the row if it is off
      by more than 0.02
      (2026-09-19 measured: Orgrimmar tower 1411 0.5089, 0.1399; Tirisfal
      tower 1420 0.6077, 0.5873. Both guesses were within 35 yards; rows
      updated. Still to measure: Grom'gol, Menethil, Auberdine, Theramore,
      Rut'theran, Booty Bay, Ratchet, both tram stations.)
- [ ] Time one full zeppelin and one boat loop; correct `minutes` (ride plus
      half the loop)
      (2026-09-19, one sample: Orgrimmar platform to Tirisfal platform in
      2 min 24 s with a short wait. `minutes = 4` kept until more samples.)
- [ ] `/gps probe`'s node count N is about 71: this proves
      `C_TaxiMap.GetTaxiNodesForMap(continent map)` returns every node on the
      continent, not only the displayed zone's. If N is far lower, record it:
      `API.TaxiNodes` must then walk every zone map.
- [ ] Standing on Zephras Isle or the Darkspear Islands, `/gps to orgrimmar`
      says it cannot tell where you are: these maps are off the two
      continents and are not routable yet. Record how each is reached.

## Planner window (plan 2): check every line in BOTH layouts

Restart the game first: the TOC changed.

- [ ] Click into the To box: a text cursor appears and typing works (the
      first thing to check: an EditBox we build without a template)
- [ ] Drag the window by its body: it follows the mouse from where you
      grabbed it, no jump, no Lua error
- [ ] `/gps selftest` ends "Self-test passed."; record any FAIL line here
      (rename GoblinPS\Media\icon.tga away, /reload: the icon texture line
      must say FAIL, then put it back)
- [ ] A GoblinPS button is on the minimap ring with the dial icon; its tooltip
      has three lines and "May explode."; dragging moves it round the ring and
      the position survives `/reload`; `/gps minimap` hides and shows it
- [ ] The addon compartment (top right of the minimap) lists GoblinPS with the
      icon, and clicking it opens the planner
- [ ] `/gps` opens the window: brass border, orange strip, title and tagline,
      From and To boxes, a green screen, a step panel. Escape closes it
- [ ] The green screen says "Flight paths known: N" with the right N
- [ ] Click To and type "und": a list drops under the box with Undercity;
      click it; the steps, per-step time and fare, total and hint appear
- [ ] With the results list open, click GO, Here, the layout button or the
      window body: the list closes
- [ ] Press Enter with text in To: the first match is taken
- [ ] Empty the To box and click it: recent destinations are offered
- [ ] Type a start in From and pick it: the route re-plans from there;
      "Here" goes back to where you stand
- [ ] GO with a flight or ride first step: Blizzard's map pin and the
      on-screen arrow appear at the step's target, and chat says "Pin set"
- [ ] GO when step 1 is the hearthstone: chat says to use it; no pin
- [ ] With no destination, and with a destination that has no route, GO is
      grey and does nothing
- [ ] Pick the zone you are standing in: no steps, GO grey, the screen says
      "You're already at <zone>."
- [ ] GO, ride part of the way, GO again: the pin moves to the step that is
      first from where you now stand
- [ ] Step 1 is the hearthstone: GO says to use it; use it, press GO again:
      the pin is set for the next step
- [ ] Open the planner inside an instance with a destination set: the screen
      says it cannot tell where you are, the text stays inside the window,
      GO is grey
- [ ] Every message on the green screen wraps or truncates inside the
      screen; nothing draws over GO or past the frame, in both layouts
- [ ] /reload with the planner open: it stays closed afterwards (by design);
      /gps reopens it where it was
- [ ] A second character on the same account: its "Flight paths known" is
      its own; layout, window position, recents and the minimap button angle
      are shared
- [ ] Right-clicking the minimap button does nothing; left-click opens the
      planner
- [ ] The Tall/Wide button flips the layout; nothing overlaps, nothing is cut
      off, the steps stay; the choice survives `/reload`
- [ ] Drag the window; its position survives `/reload`
- [ ] Open a flight master's map with the planner open and a route showing:
      if paths were learned, the route and "Flight paths known" update
- [ ] `/gps to barrens` bound at the Crossroads inn: "Hearthstone to
      Crossroads" and no "Ride to The Barrens"
- [ ] Bound in Brill, Razor Hill, Goldshire, Kharanos, Dolanaar or Bloodhoof
      Village: no "unknown inn" line. Stand in the inn and compare
      `/run print(C_Map.GetBestMapForUnit("player"), C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit("player"),"player"):GetXY())`
      with the row in `GoblinPS/Data/Inns.lua`
- [ ] Any other "Hearth: unknown inn (...)" line seen: add the name to
      `GoblinPS/Data/Inns.lua`

# GoblinPS manual test checklist

Frames and live game data cannot run outside the client. Add an entry for
every UI change.

## Start here: a suggested order for the next session

Plans 2 and 3 are built and reviewed, and neither has been run in the client.
**This is a recommendation, not a gate.** Whether it is enough to merge is the
repository owner's call; what follows is only the order that gets the most
answered per minute in game, cheapest and most decisive first. The sections
below hold the full detail, and nothing here replaces them.

**This needs a full game restart, not `/reload`: the TOC changed after plan 3.**

1. **Does it still load?** `/gps` opens the planner, and `/gps selftest`
   passes. If either fails nothing else matters, and the answer will be in
   the first Lua error.
2. ~~**Click a destination in the dropdown.**~~ Done 2026-09-20: typed "S",
   clicked Stonetalon Mountains in the list, the route drew. The plan 2 click
   fix works in the client.
3. **`/gps probe zones`.** One command, and it replaces reading sixty zone
   tooltips by hand. Then log out so SavedVariables is written, and say so.
4. **Orgrimmar's west gate.** Stand in the gateway and record the position.
   Every Horde route north depends on this one row and it fails quietly, not
   loudly, when it is wrong.
5. **The other five suspect crossings**, listed under "Which crossings to
   check first". Fifty of the fifty-six rows are already provably inside both
   of their zones; these are not.
6. **`/run print(GetUnitSpeed("player"))` while mounted.** Yards per second,
   directly. Every ground time the addon prints scales off this number, and
   it is currently assumed rather than measured.

Everything after that is worth doing, but none of it changes an answer above.

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

Superseded by plan 8: the window has one box, one layout and no step list.

Restart the game first: the TOC changed.

- [ ] Click into the To box: a text cursor appears and typing works (the
      first thing to check: an EditBox we build without a template)
- [ ] Drag the window by its body: it follows the mouse from where you
      grabbed it, no jump, no Lua error
- [x] `/gps selftest` ends "Self-test passed."; record any FAIL line here.
      **2026-09-20: passed, and it answered the question plan 7 (the route
      strip) was waiting on.** All five dash textures reported `ok`, so this
      client loads the power-of-two TGAs `tools/make_art.py` writes from the
      PNG sources. The remaining 34 art parts can ship the same way; no BLP
      conversion needed.
      `GetPlayerFacing` and `UnitOnTaxi` are present.
      **This quietly answers a question plan 4 depends on.** One of the
      textures it checks is `Interface\AddOns\GoblinPS\Media\icon`, a TGA
      written by Pillow in `tools/make_icon.py`, and `SetTexture` returns
      whether the file actually loaded. So a pass means this client accepts
      the TGAs our tools produce, and the 39 art parts can be shipped the same
      way. A FAIL on that one line means the format is wrong (BLP may be
      needed) and is worth knowing before the art is wired in, not after
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
- [x] Click To and type "und": a list drops under the box with Undercity;
      click it; the steps, per-step time and fare, total and hint appear
      (2026-09-20: clicked the To box, typed "S", Stonetalon Mountains
      appeared in the list, clicked it and the route drew. **This is the fix
      from 2341cf2 confirmed** -- the client drops edit focus on mouse-down,
      so the list now survives focus loss while the cursor is over it. It had
      been unconfirmed since before plan 3 began.)
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

## Ground crossings (plan 3)

**First in-game run, 2026-09-20**, a level-5 undead at Gallows' End Tavern in
Brill, destination Stonetalon Mountains. The window drew correctly in the wide
layout and the route was right:

    1. Walk to Undercity Zeppelin Tower      in Tirisfal Glades · level 1-10
    2. Zeppelin to Orgrimmar Zeppelin Tower  (time truncated, see below)
    3. Walk to the Southfury bridge          into The Barrens · level 10-25
    4. Walk to the Stonetalon pass           into Stonetalon Mountains · level 15-27

Confirmed by that run: the addon loads, the planner opens, two-line step rows
draw, ground travel chains zones through crossings, "Walk" is chosen below the
mount level, the amber level warnings fire on the two zones above the
character, the discover hint appears, and the no-flight-paths message shows.

Two faults it found, both fixed in `a8ae73a`:
- Step 2 was cut off mid-word because the step text repeated the time the
  planner already prints in its own column. The time is gone from the step
  text; link steps now say "includes the average wait" on the detail line.
- The hearthstone was dropped as "unknown inn (Gallows' End Tavern)" although
  Brill was already in `Data/Inns.lua`. `GetBindLocation()` returns the
  SUBZONE, and inside a town that is usually the inn building. **Expect this
  at every inn**: record the name each time and add a line to `Data/Inns.lua`.

The destination was chosen by clicking a row in the dropdown (typed "S", then
clicked Stonetalon Mountains), which confirms the plan 2 click fix as well.

Restart the game first: the TOC changed.

- [ ] FIRST: every Horde route north depends on it. Orgrimmar's west gate:
      confirm it opens into the Barrens and where
- [ ] On a character below level 40 with no flight paths, plan to a zone two
      or more zones away: every ground step says "Walk to ..." and names a
      crossing; none says "(no mapped path)"
- [ ] The undead start: `/gps to mount hyjal` from Tirisfal gives the zeppelin,
      Orgrimmar's front gate, Orgrimmar's west gate, the Mor'shan Rampart, the
      Ashenvale-Felwood road, the Timbermaw Hold tunnels, Darkwhisper Gorge
- [ ] In the planner each ground step has a second, smaller line ("into
      Ashenvale · level 18-30"); it is amber when the zone is well above the
      character's level or the crossing has a hazard, dim otherwise
- [ ] `/gps to` prints the same detail line under each ground step in chat

Superseded by plan 8: the window has one box, one layout and no step list.

- [ ] Both layouts: the two-line rows fit, nothing overlaps the hint, the
      total or GO; a route longer than 8 steps ends "... and N more steps"
- [x] ~~The levels at which riding is learned.~~ 2026-09-20, from the riding
      trainer: Apprentice Riding requires level 40, Journeyman requires 60.
      `GoblinPS/Travel.lua` already held both; they are now evidence, not a guess
- [ ] On a level 40+ character the steps say "Ride to ..." and the times are
      shorter
- [x] ~~Confirm the base walking speed.~~ 2026-09-20:
      `GetUnitSpeed("player")` unmounted returned `0, 7, 7, 4.7222218513489`
      (current, run, flight, swim). Run speed is exactly 7, so
      `Travel.WALK_YARDS_PER_SECOND` is measured rather than assumed
- [ ] *Optional, nothing blocked on it:* confirm the two mount speeds with
      `/run print(GetUnitSpeed("player"))` from horseback. Expect 11.2 with
      Apprentice Riding and 14 with Journeyman. Those follow from vanilla's
      +60% and +100% applied to the measured base of 7, which the user
      confirmed Forever uses; this would turn a stated number into a measured
      one. Original wording follows
- [ ] ~~**Measure the two mount speeds.**~~ `Travel.lua` assumes +60% and +100%
      of 7 yards a second (11.2 and 14) from the skill names alone. While
      mounted, run `/run print(GetUnitSpeed("player"))`: it reports yards per
      second directly. Do it on each mount and correct `Travel.MOUNTS`
- [ ] GO on a crossing step puts Blizzard's pin on the crossing
- [ ] **Walk each crossing you pass and check its point.** Stand in the
      gateway, run
      `/run print(C_Map.GetBestMapForUnit("player"), C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit("player"),"player"):GetXY())`
      and compare with the row in `GoblinPS/Data/Crossings.lua`; correct the
      row if it is off by more than 0.03. Record the ones checked here

#### Which crossings to check first

All 56 coordinates are estimates, but they are not equally likely to be wrong.
Each zone has a world rectangle from the generator, and a border can only lie
where two zones' rectangles overlap. **Fifty of the 56 rows already sit inside
both of their zones. Six do not**, and those are the ones worth a detour:

| Yards off | Crossing | Between | Note |
|---|---|---|---|
| 250 | the Timbermaw Hold tunnels | Felwood and Moonglade | the worst row in the table |
| 192 | the Feralas-Desolace road | Feralas and Desolace | |
| 110 | Darkwhisper Gorge | Winterspring and Mount Hyjal | already flagged unverified |
| 75 | the Timbermaw Hold tunnels | Winterspring and Moonglade | |
| 72 | Orgrimmar's west gate | Orgrimmar and the Barrens | already flagged unverified, and every Horde route north needs it |
| 7 | the Ruins of Lordaeron | Undercity and Tirisfal Glades | noise; ignore it |

Being inside both rectangles does **not** prove a row is right: the rectangles
are bounding boxes, they overlap generously, and a point can sit inside both
and still be in the wrong gully. It only means nothing detectable is wrong from
the desk. So the 50 still want walking eventually; these six want it first.

Regenerate this table after correcting rows:

```bash
python -c "import lupa.lua51 as L; L.LuaRuntime().execute(open('tools/survey_crossings.lua').read())"
```

`test/test_crossings.lua` pins the count at six, so correcting a row in game
turns that test red. That is the prompt to update this table, not a bug.
- [x] ~~Run `/gps probe zones` instead of reading sixty tooltips.~~
      **2026-09-20: it is dead.** The command reported "C_Map.GetMapLevels
      answered for no zone at all: it is dead on this build, like
      isUndiscovered." The guard did its job — silence was reported as
      silence rather than read as "nothing disagrees" — but the shortcut is
      gone. Keep running it after a client patch; it will start working by
      itself if the function is ever fixed
- [ ] **Read the zone level ranges off the world map's tooltips** and correct
      `GoblinPS/Data/Zones.lua`, since the probe cannot. Hover a zone on the
      world map: the name carries its range in brackets. Forever may have
      moved some. Do this a few zones at a time rather than in one sitting;
      nothing else depends on it, and a wrong range only costs a misplaced
      amber warning
- [ ] ~~Run `/gps probe zones` instead of reading sixty tooltips.~~ The client
      draws its own level range on the world map, and
      `C_Map.GetMapLevels(uiMapID)` is where that comes from. The command asks
      it for every zone, names the ones that disagree with
      `GoblinPS/Data/Zones.lua`, and saves the full table to
      `GoblinPSDB.probe.zones`. Log out afterwards so SavedVariables is
      written, then say so and the table can be read from the desktop.
      **The API is verified in source but not in game**, and `isUndiscovered`
      already proved a function can exist and answer uselessly. If it says
      `dead on this build`, fall back to hovering the zone tooltips
- [ ] Time the passages that carry a cross time in Data/Crossings.lua
      (Blackrock Mountain, the Timbermaw tunnels, Dun Algaz, Darkwhisper
      Gorge, the Great Lift, the Thunder Bluff lifts, the Talondeep Path)
      and correct the seconds
- [ ] Orgrimmar's west gate and the six new-zone crossings show "crossing not
      confirmed" in amber until their rows lose unverified = true
- [ ] A route with more than 8 steps shows the first six, "... and N more
      steps", and the final step
- [ ] The ramp in Un'Goro Crater's north-west corner: confirm it is the way
      into Silithus (a reviewer doubted it; the classic world and the atlas
      both say yes)
- [ ] New zones, all `unverified = true` in the table: Darkwhisper Gorge into
      Mount Hyjal, the Valley of Bones into Shen'dralas, the Riverglades
      turnoff from Redridge and its borders with the Burning Steppes, the
      Swamp of Sorrows and the Badlands. Record the real crossings
- [ ] Any step that says "(no mapped path)": record from where to where; a
      crossing row is missing
- [ ] Teldrassil still needs the boat; a Darnassus character leaves by "the
      Darnassus gate"

## A trip survives everything except Stop (plan 7)

Built 2026-09-21; not yet run in the client. The dash used to end its trip
whenever it was hidden, so pressing Escape -- which players do constantly --
killed the route, and a reload or logout always lost it.

- [ ] With a trip running, press Escape: the dash stays up and keeps going
- [ ] Alt+Z twice: the interface hides and comes back, and the trip carries on
- [ ] `/reload` mid-trip: the dash comes back, replans from where you stand,
      and puts the map pin on the first step
- [ ] Note whether the map pin from before the `/reload` is still on the map
      right in the moment after the reload, before the dash replans (M4: our
      record of "is this pin ours" lives only in memory and is gone after a
      reload, so it cannot be cleared until the resumed trip pins again;
      whether a user waypoint even survives a `/reload` at all is unknown)
- [ ] Log out and back in mid-trip: the same
- [ ] Press Stop: the dash goes, the map pin clears, and a `/reload` brings
      nothing back
- [ ] Arrive: the dash says "Arrived." and stays up until Stop; the map pin
      at the destination clears
- [ ] On the last step, drop your own map pin, then arrive (or press Stop):
      it is still there (GoblinPS moves the one map pin on every advance and
      replan, so a pin dropped earlier would just get overwritten -- that is
      by design, not a bug)
- [ ] Open `/gps` mid-trip: the search box shows the trip's destination
- [ ] Log in a second character: no trip comes back for it

## The planner as designed (plan 8)

Needs a full game restart, not `/reload`: the TOC gained `Strip.lua`.

- [x] `/gps` opens one wide window: one search box, the screen, Start Route.
      No From, no Here, no Wide/Tall button, no step list
      (2026-09-21: as the mockup, against a plain sky; no gap at any edge)
- [ ] With nothing picked, the screen shows the two status lines and no strip
- [x] Brill to Orgrimmar reads crest, boot or horseshoe, zeppelin, signpost;
      the first leg solid, the rest dashed, a glowing dot mid-leg; the badges
      sit on the line, not above or below it
      (2026-09-21, a low-level Horde character in Durotar to Silverpine Forest:
      crest, boot, boot, zeppelin, signpost; solid then dashed, on the line.
      The signpost is labelled with the border crossing, "the Tirisfal-...",
      not the destination searched for)
- [x] Hover each badge: the step, its time, and its detail line where it has
      one; a zeppelin says it includes the wait
      (2026-09-21: "Walk to Orgrimmar Zeppelin Tower / ~4 min / in Durotar ·
      level 1-10", title in gold, detail dim, above the badge. The zeppelin:
      "Zeppelin to Undercity Zeppelin Tower / ~4 min / includes the average wait")
- [ ] A long route (try a far city on the other continent) shows every stop;
      when they crowd, the names go and the tooltips still say everything
- [ ] A leg into a zone above your level: its tooltip detail is amber and the
      amber line under the strip names that stop; the line itself is not
      coloured and no badge changes (the skull is day 2)
- [x] The total under the strip reads like "~15 min · free"
      (2026-09-21: "~14 min · free")
- [ ] Type in the box: the results list drops over the screen and the amber
      line stays visible under it, and every row sits inside the list's
      panel, none hanging below it
      (seen failing in game 2026-09-21: typing "a" showed 8 rows and two,
      Booty Bay and Brackenwall Village, hung below the panel)
- [x] Start Route closes the planner and opens the dash; `/gps` mid-trip
      shows the trip's destination in the box
      (2026-09-21: Start Route opened the dash, and a whole trip from the
      Crossroads to Silverpine Forest ran end to end in game -- ground legs,
      the zeppelin and the zone crossings -- with every step advancing as it
      should. The mid-trip `/gps` half is not yet looked at)
- [ ] `/gps selftest` lists the fifteen strip textures, all `ok`
- [ ] Nothing reads past the brass or overlaps: names under the end badges
      stay on the glass
- [ ] A long note (e.g. an unknown inn plus no flight paths) on the one-line
      status or warning line: it truncates cleanly rather than overflowing
- [ ] The names under the two end badges read in full (they get about 65 px);
      note any that truncate, e.g. "You are here" or a long destination
      (2026-09-21: "You are here" reads in full; "the Tirisfal-..." and the
      middle names "Orgrimmar Zeppelin..." and "Undercity Zeppelin T..." truncate)
- [ ] A 13-stop route: rings may touch and each badge's hover area overlaps
      its neighbour's; note whether the right tooltip comes up
- [ ] No gold rectangle round Start Route or the search box, at rest or on hover
- [ ] The scenery fills the frame's whole inside, edge to edge, behind the box and Start Route; nothing of the old dark tiled backing shows

## Flight paths survive a reload

**Blocked by the client** (2026-09-21): build 1.60.1.69913 writes every
addon's saves and loads none of them, so these fail today through no fault of
GoblinPS. Re-run them after each beta update, starting with the marker test:
`/run GoblinPSDB.test = 42`, `/reload`, `/run print(GoblinPSDB.test)` -- 42
means saves load again. The plan 7 resume items above are blocked the same
way.

- [ ] The four screen lines (names, total, amber line, idle status) read
      clearly over the scenery now that the screen has no dark edge
- [ ] Log in or `/reload`: chat says "No flight paths known this session:
      open any flight master's map." Open one, `/reload` again: while saves
      do not load, the line comes back; once they load, it stays quiet
- [ ] Open a flight master's map, then `/reload`, then open `/gps` **without**
      visiting a flight master: it says "Flight paths known: N", not "No
      flight paths yet"
- [ ] `/gps selftest` prints "flight paths learned: N for <Name>-<Realm>"
      naming this character, and reports `ok` for the character key
- [ ] Log in a second character: it knows none of the first one's paths
- [ ] Log back into the first: its paths are still there

## Planner window art (plan 6)

Superseded by plan 8: the window has one box, one layout and no step list.

First run in the client 2026-09-21, in front of a plain sky set up so any gap
in the art shows. It found three faults, fixed in the commit after: the world
showing between the panels and the frame on the left, right and bottom; the
title and tagline drawn a second time as text over the plates' own lettering;
and dark button labels on the art's dark glass. The rest of this section is
still unconfirmed.

- [ ] /gps opens a window wearing brass, not flat colour, in both shapes
- [ ] The window is the art's shape, not stretched: the round lamps in the
      corners are round. If they are ovals, Planner.SIZE and the art's canvas
      have drifted apart
- [ ] No coloured rectangle shows at the window's edges or corners
- [ ] Title and tagline each read once, in the plates' own lettering --
      "GOBLINPS / Goblin Positioning System" and "Time is money, friend." --
      with no plain-text "GoblinPS" or "Accuracy not guaranteed" over them
- [ ] Against a plain sky, nothing shows between the panels and the frame's
      inner edge on any side, in both shapes. The backing fills the frame's
      opening as measured from its own alpha and is tucked under the brass;
      a sliver here means that measurement and the art have drifted apart
- [ ] The labels on Tall, Here and GO are readable: green on the glass, dim
      when the button is disabled
- [ ] Close shuts the window; the gear says settings are not built yet
- [ ] The title bar has exactly TWO buttons, a gear and a close -- if a
      third sits exactly on top of close, the tools_button alias got through
- [ ] The dropdown beside To opens the whole destination list without typing
- [ ] The Wide/Tall button switches shape and both shapes are laid out; in
      wide the button sits mostly on brass -- confirm it is visible and
      clickable there, not only in tall (it was reparented once already to
      fix an ambiguous draw order against that brass)
- [ ] From, To and Here sit in their openings, and the end caps on the boxes
      and buttons are not squashed or stretched
- [ ] Toggle Wide/Tall and look at those end caps AGAIN. A cap sized for one
      layout and left there is the fault this is watching for, and it only
      shows after a switch: the controls change height between the two shapes.
      If a cap is right in one shape and squashed or stretched in the other,
      the height ApplyLayout hands Restretch3 is wrong for that layout
- [ ] Type into From and To: the typed text AND the grey placeholder are both
      readable against the `input-box` art. Only the client can answer this --
      the art arrived after the text colours were chosen. If either washes
      out, say which and against which part of the box
- [ ] Hover a button and then hold the mouse down on it: the art lights
      (`button-hover`) and then presses (`button-pressed`), and a disabled GO
      does neither
- [ ] Typing in either box drops the results list over the screen, and it
      covers what it drops over rather than hiding behind it
- [ ] The screen's scenery fills its opening without looking stretched;
      losing the sides is intended, but the view should read as generous, not
      as a narrow crop
- [ ] With no destination or an unreachable one, GO reads as disabled from
      its own art -- a duller `button-disabled` texture -- not from a colour
      tint; if it looks the same lit and unlit, the art swap did not happen
- [ ] The step list, total and amber hint sit in their openings, and a long
      warning never covers GO
- [ ] At UI scale 0.64 and 1.0 the window is legible and nothing overlaps
- [ ] /gps selftest names the sixteen new textures; if one FAILS the window
      must still be usable on its flat colours

## Dash unit (plans 4 and 5)

- [ ] GO closes the planner and opens the dash; /gps reopens the planner and
      the trip keeps running
- [ ] The arrow points at the current step. Turn on the spot: it should stay
      pointing at the same place in the world. **If it turns the wrong way,
      flip Trip.ROTATION_SIGN and nothing else**
- [ ] The compass ring's N stays north as you turn
- [ ] Turning in place, the arrow and compass swing smoothly, not in
      half-second jumps; on a step advance the arrow glides to the new target
- [ ] Blizzard's map pin moves to each new step as the dash advances, not
      only to the first one when GO is pressed
- [ ] Walk to the first step's target: the dash advances to the next step
- [ ] Walk away from the target for 400 yards: it says Recalculating and
      replans from where you stand
- [ ] Take a zeppelin: nothing advances or recalculates while aboard
- [ ] Land from a flight: it recalculates rather than sitting on a step you
      have already finished
- [ ] Enter an instance: the dash says Waiting and keeps the trip; leave the
      instance and it carries on
- [ ] Reach the last step: the device says Arrived, clears the distance and
      time, hides the arrow, and stays open until Stop is pressed
- [ ] Drag the dash; its position survives /reload. A trip now survives a
      /reload too -- see "A trip survives everything except Stop (plan 7)"
      above; only Stop ends it
- [ ] The device is round, not oval, and the compass ring turns with you while
      the arrow turns toward the step. If the arrow is right and the ring is
      wrong, that is Trip.CompassAngle, not Trip.ROTATION_SIGN
- [ ] The glass names the step you are walking to and counts the yards down
- [ ] The panel shows the step you are on and the next two; near the end it
      shows fewer, not blanks with stale text
- [ ] The ETA plate shows the time left for the whole journey
- [ ] The red button lights on hover, pushes in on click, and ends the trip
- [ ] Every line sits inside its own opening in the chassis; no text is cut
      off and none draws on the brass
- [ ] Every line of text sits on its opening and is legible: the destination,
      the yards, the three steps and the ETA. The device is 288x360; if a line
      is cramped or swims in its opening, that number is the one to change
- [ ] At UI scale 0.64 and 1.0 the device is legible and nothing overlaps
- [ ] /gps selftest names the eight second-design textures; if one FAILS the
      device must still be readable on its flat colours. It also names the
      first design's five parts (`dash-body`, `dash-screen`, `dash-compass`,
      `dash-eta-plate`, `arrow`), which are kept on disk on purpose; only
      `arrow` is drawn, so a FAIL on the other four costs nothing today

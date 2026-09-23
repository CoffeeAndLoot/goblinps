# Later

Ideas worth doing that are not a plan yet. One line each, newest at the top.
A thing here is not a commitment -- it is a note so it stops living in a chat
log. When one graduates, it becomes a plan in `docs/superpowers/plans/` and
comes off this list.

- **Two drop-downs: a zone, then a place in it.** The owner, 2026-09-22,
  after walking the zone browser: one list for the zone, a second for the
  places in the chosen zone. Today the one list does both (a zone row fills
  the box and lists its places), which works; this is an idea, not a fault.
- **The drop-down is still wider than it needs to be.** Seen 2026-09-22
  after plan 9 narrowed it to the widest label: it hugs the widest label the
  search can ever offer, so it is wide even when every row shown is short.
  Not a priority.
- **Place the three towns the generator cannot.** Plan 10, 2026-09-22:
  Dun Algaz, Scholomance and Ivar's Patch sit in two or three zone rectangles
  with no AreaID or area row to choose between them, so `build_graph.py`
  skips them (it prints each). A small hand-written table of `{ poi id = map }`
  overrides, read by the generator, would place them; Scholomance alone
  would have gone into The Hinterlands by the smallest rectangle.
- **Keep a destination's zone, not only its name.** The recents and a saved
  trip hold a name, and `Search.Exact` takes the lower ID on a tie. The two
  ends of Timbermaw Hold (Felwood, Winterspring) and of The Talondeep Path
  (Ashenvale, Stonetalon Mountains) share a name, so picking the higher-ID
  end comes back as the other end after a reload or from the recents.
- **Monster camps that are hostile to all.** The owner's Notes column in
  `tools/town-factions.csv` says "Hostile to all" on nine camps (Boulderfist
  Outpost, Drywhisker Gorge, Bloodtooth Camp, Demon Fall Canyon, Falfarren
  River, Greenpaw Village, The Dor'Danil Barrow Den, The Ruins of Ordil'Aran,
  Xavian); plan 11 reads no Notes, so a ride leg still walks straight through
  them. A fourth faction letter (say `M`, hostile to both sides) in the
  faction column would let `Graph.Hostile` charge a leg past one for either
  side.
- **Route to a quest.** Day 2. A quest's location from the game data is a point (name, map, x, y), the same shape as every destination since 2026-09-22, so the router takes it as is; what is new is finding and listing quests.
- **Dress the settings panel with art.** Plan 9, 2026-09-22, built the panel
  plain: the gadget palette's body and brass, flat `-` / `+` buttons, no new
  parts, because the art is Codex's and nothing was asked of Codex. A dressed
  panel wants a frame, plate and button art like the planner's, and a
  geometry file for it, so its layout numbers come out of `Settings.lua` the
  way the planner's came out of `Planner.lua`.
- **The skull badge: mark the dangerous stop on the route strip.** Day 2,
  decided 2026-09-21 while designing plan 8. `icon-warning` (the skull) is
  drawn and waiting. The idea: at any stop in a zone above your level, the
  skull replaces that stop's travel icon, so the strip shows exactly where the
  risk is; the stop's tooltip still says how you get there, plus the level
  range. Until then the warning lives where it always has -- in amber, in the
  stop's tooltip and printed under the strip. It stays a warning, never a
  reroute.
- **Shorter step text on the dash:** run step names through
  Search.Label/ShortName before scrolling, so a line only scrolls when it is
  genuinely long. (Left over from the marquee entry when plan 9 built the
  scrolling.)
- **The dash says nothing when a replan brings in danger.** A replan that adds a 'passes X' leg or a hostile destination shows no warning on the dash (Dash.lua ~621); the player follows the dash, so a short banner would help.

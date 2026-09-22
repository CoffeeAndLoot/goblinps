# Later

Ideas worth doing that are not a plan yet. One line each, newest at the top.
A thing here is not a commitment -- it is a note so it stops living in a chat
log. When one graduates, it becomes a plan in `docs/superpowers/plans/` and
comes off this list.

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
- **Faction-aware avoidance of enemy towns** (the plan 10 spec's step 4,
  next). The towns now carry an inferred faction; the router does not yet
  keep you out of the other side's. The inference is crude (Maraudon reads
  Horde because Shadowprey's flight master is near); `AreaTable` carries a
  `FactionGroupMask` that may say more, unverified on this build.
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

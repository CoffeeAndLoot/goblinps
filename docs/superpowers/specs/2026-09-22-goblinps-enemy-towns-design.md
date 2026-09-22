# GoblinPS: routes that go round enemy towns (plan 11)

Status: **asked for by the owner in chat on 2026-09-22.** A Horde level 15 mage following the route from the Talondeep Path to Splintertree Post was walked straight through Silverwind Refuge, an Alliance town, and died there more than once. The owner agreed to the fix proposed in chat: enemy towns become penalty circles, and hand-written stopover points give the router a way round them. Decisions the owner did not state are marked **Ruling**.

## Why
Inside a zone, a ride leg is a straight line between two points. The router knows nothing about roads, cliffs or towns in between. On the real data, the straight leg from the Talondeep Path's Ashenvale mouth (42.3, 71.1) to Splintertree Post (73.3, 61.7) runs through Silverwind Refuge (50.1, 66.2).

## 1. Hostile places
**Revised 2026-09-22 by the owner:** a place is hostile only when its faction is known. The generator no longer guesses a town's faction from nearby flight masters (plan 11's prototype found most such guesses were caves, rivers and dungeons), and `Data/Hostile.lua` is dropped.

A hostile place is a point with a name, a faction and a radius, built from two sources:
- **Enemy flight stops:** every `Data/Nodes` stop whose faction is not the player's and not neutral, except one whose short name a stop the player may use shares (Booty Bay, Gadgetzan, Everlook...: a neutral town with a flight master for each side).
- **Marked enemy towns:** every `Data/Towns` row with an `f` that is not the player's. `f` comes only from the owner's hand-written sheet `tools/town-factions.csv` (columns zone, town, x, y, guess, "faction (A/H/N)", Notes), which `tools/build_graph.py` reads the way it reads `catalog.lock`: A or H becomes `f`, N or blank gives none, and the guess and Notes columns are never read. A row that names a town the generator does not produce is a loud error: the generator prints it and writes nothing, and the Python tests fail. Silverwind Refuge is marked A, because its guards killed a level 15 Horde player on 2026-09-22. Mark a town whenever one kills you.

**Ruling: the radius** is `Graph.HOSTILE_RADIUS = 150` yards for a town or stop, and `Graph.CAPITAL_RADIUS = 400` for a capital: a hostile place named after its own zone ("Orgrimmar" in Orgrimmar, "Stormwind" in Stormwind City). Both are named constants, and they are guesses until walked. The owner's closest reading at Silverwind was about 40 yd from its map label, so 150 errs wide.

When one leg passes two hostile places, it is named after the surer source: a flight master, then a marked town.

A place is hostile only to the other faction. Neutral towns (no `f`) are never hostile.

## 2. The penalty
**Revised 2026-09-22 after review:** the exemption covers only the ends the player chose, and the penalty is a routing cost that is never shown as time.

- In `Graph.Build`, each ride edge p->q is tested against every hostile place on the same continent. If the straight segment passes within the place's radius, the edge carries `danger = { name, f }`. It takes the first hostile place, in stable order, as its name.
- **The penalty steers but never shows.** Every edge keeps its real `seconds` and gains a `cost`: its seconds, plus `Graph.HOSTILE_SECONDS` (**Ruling: 600**, ten minutes) on a `danger` edge. `Route.Find`'s Dijkstra minimises cost. Its result carries both `seconds` (the real travel time, the sum of the steps' real seconds, which is all the player is ever shown: totals, step times, tooltips, the ETA) and `cost`. Putting the penalty in `seconds` showed a phantom ten minutes everywhere.
- **Comparisons.** `Route.Plan`'s hearthstone bar compares real seconds, the unit it names ("must save N min"): the stone is kept only when `plain.seconds - best.seconds >= bar`, for every bar including 0. It never compares cost: `best` is already the router's pick by cost, and comparing cost let the 600 s penalty alone spend the stone, even on a slower trip. A refused stone leaves the plain route with its danger step, so the player sees the warning. `Route.Hint` offers a hint only when the better route beats the current one by `HINT_MIN_SECONDS` both in cost and in real seconds, and states the saving in real seconds. A route that only goes round a town, no faster, earns no "save" line (its saving would read as nothing or less).
- `tidy`'s too-short rule never drops a step carrying `danger`: its warning must reach the player.
- **Exemptions.** A hostile place is ignored for an edge only when an end the player chose lies inside its circle: START (you are there), HEARTH (the stone lands you there), DEST (an enemy town you picked) or a stopover (placed inside one knowingly). That keeps a trip TO Silverwind Refuge from being impossible. A crossing end, a tunnel mouth or a flight master inside the circle gets the plain segment test and no exemption: it is on the way, not the goal. Exempting "either end" let an Alliance level 15 walk from the Orgrimmar zeppelin tower to Astranaar go in at Orgrimmar's front gate and out at its west gate with no warning; it now goes round by the Southfury bridge.
- It is a penalty, not a ban, so a destination is never made unreachable. The router takes a way round whenever one exists within ten minutes.
- Flights, boats, zeppelins, trams and the hearthstone are never penalised. Through edges (tunnels) are not either: they are one passage.
- Rough straight-line edges get the same test.

## 3. Stopover points
- `Data/Stopovers.lua` (new, HAND-WRITTEN) lists named points inside one zone that a ride may pass through: `{ name = "...", map = <zone>, mx, my, unverified = true? }`.
- The Graph adds each as an ordinary one-zone stop, like a crossing end, joined by ride edges to every other point in its zone.
- A step to a stopover reads "Ride to <name>" like any other. **Ruling:** stopover names describe the way: "the road south of Silverwind Refuge".
- It starts empty, with a header explaining the format and how to measure one with `/gps where`. The owner is measuring the Horde way round Silverwind. Until a stopover exists, the route still goes through, now with the warning below.

## 4. Saying so
- A ride step with `danger` gets an amber detail line: "passes <name> (<Alliance|Horde>)". It replaces the level range the way a crossing's `warn` does. `Route.StepDetail` returns `warn = true` for it, so it shows in the tooltip and on the warning line under the strip, like the level warning.
- **A destination that is itself hostile** (an enemy town or stop the player picked) gets a plan note: "<name> is a <Alliance|Horde> town: its guards will attack you." It is shown on the warning line under the strip and in chat for `/gps to`.
- The dash's step lines already show step text. The detail is not shown on the dash, which is unchanged.

## 5. Which faction is "the player's"
`opts.faction` is what the graph already uses (`API.Faction()`, "H" or "A"). Hostile places are built per plan for that faction. With no faction, nothing is hostile.

## Out of scope
- Level-aware danger. Guards kill at any level the owner is likely to be, so danger always applies.
- Auto-generating roads. Stopovers are hand-written.
- Changing any existing crossing.

## Tests
- **Pure geometry:** segment-to-point distance (`Geo.SegmentDistance`) at the ends, in the middle and past both ends.
- **Graph:**
  - an edge through a hostile circle carries `danger` and costs 600 s more, its `seconds` unchanged;
  - an edge that misses the circle does not;
  - an edge with START, HEARTH, DEST or a stopover inside the circle is exempt; one with only a crossing end or a flight master inside is not;
  - a friendly or neutral town is never hostile;
  - flights and through edges are never penalised;
  - given a stopover beside the circle, the route goes round it.
- **Route:** the "passes X (Alliance)" detail line is amber, and a hostile destination gets its note.
- **Real data:** a Horde level 15 route from the Talondeep Path's Ashenvale mouth to Splintertree Post: its straight line carries `danger` naming Silverwind Refuge, and the route goes round with no step passing within the radius (measured 2026-09-22: by the Ashenvale-Felwood road). An Alliance route on the same line is the straight line, with no `danger`.
- **Data:** every `tools/town-factions.csv` row names a town the generator produces, and `Data/Towns.lua` carries exactly its A and H marks (Python); Irontree Cavern, a cave the old guess called Alliance, has no `f`; every stopover sits inside its zone's rectangle.

## In game (checklist)
- Horde, Talondeep Path to Splintertree Post: the tooltip for the leg past Silverwind reads "passes Silverwind Refuge (Alliance)" in amber, and so does the line under the strip.
- Once a stopover is added: the route goes round it, and the dash walks you round alive.
- Pick an enemy town on purpose: the warning line says its guards will attack you.

# GoblinPS: trips that survive, and the planner as designed

Status: **approved by the user, section by section, on 2026-09-21.** This
amends `docs/superpowers/specs/2026-09-19-goblinps-design.md`, which stays
the project's spec; where the two disagree, this one wins. It is built as two
plans:

- **Plan 7 — a trip survives everything except Stop.** Needs nothing from
  anyone else, and fixes a live bug, so it ships first.
- **Plan 8 — the planner rebuilt to the mockup, with the route strip.** Waits
  on one geometry delivery from Codex for its drawing tasks only.

## Why

Two things came up on 2026-09-21, after plan 6 was first seen in the client.

**The planner had drifted from the design.** The Codex mockup
(`images/parts/_planner-wide-assembled.png`) is one search box, a screen
holding a strip of travel icons, and a Start Route button. The planner that
shipped is the plan-2 window -- From, To, Here, a step list, a wide/tall
toggle -- wearing the new art. The drift happened in the art brief: the
existing window was treated as the spec and the mockup as art to fit onto it,
and Codex was asked where to put nine widgets rather than whether they should
stay. **The mockup is the spec.** The route strip, the heart of it, was held
back as a later plan and never drawn.

**Trips die too easily.** The dash registers for Escape and ends its trip
whenever it is hidden, so pressing Escape -- which players do constantly --
ends the trip. Anything else that hides the whole interface (Alt+Z, a
cutscene) very likely does the same, since the dash lives inside it; that is
the usual WoW behaviour, unconfirmed on this build. A `/reload`, disconnect or
logout loses the trip for certain, because it lives only in memory.

## Decisions (each the user's call, 2026-09-21)

1. **The mockup is the spec.** The current window is scaffolding to replace.
2. **No "From".** The route always starts where you stand. The From box, the
   Here button and the planner's "from" state go. The router keeps its
   `from` parameter: that is how the dash replans from your position.
3. **Wide only.** The wide/tall toggle and every line of tall code go, with
   the tall texture shipped to the addon and the tall geometry it reads. The
   tall **source** art stays in `images/parts`.
4. **No step list.** Each leg's detail moves to a tooltip on its stop. The
   total and the amber level warning stay printed under the strip, always.
5. **Each stop shows how you get there.** One badge per stop: your faction
   crest at the start, the travel icon at each stop after, the signpost at
   the end. The badges are joined by the glowing line from the mockup.
6. **Always show the whole route.** Stops are spaced evenly however many there
   are; names drop into the tooltips when they are too crowded to read.
7. **A pure `Strip.lua`** decides the layout; `Planner.lua` only draws it.
8. **A trip ends only when you press Stop**, and survives a `/reload` and a
   logout.

**Deferred to "day 2"** (on `docs/later.md`): the skull badge marking a stop
in a zone above your level. **Unused, by choice**: the stone gate badge and the
green-dot ring; their art stays on disk.

---

## Plan 7 — a trip survives everything except Stop

Built 2026-09-21 -- not yet run in the client.

### Behaviour

- **Stop is the only thing that ends a trip.** Pressing it ends the trip,
  clears the saved trip, clears the map pin if it is still the one GoblinPS
  set (see below), and hides the dash.
- **Arriving** shows "Arrived." and leaves it up until Stop, as today, and
  clears the map pin if it is still ours. The trip itself is not ended by
  arrival: a reload at the destination replans from where you stand, finds no
  steps left, and shows "Arrived." again. No special case.
- **Escape never touches the dash.** It comes off `UISpecialFrames`. It is a
  heads-up display like the minimap, not a dialog. The planner stays on
  Escape: closing the planner now loses nothing.
- **Hiding the dash any other way only hides it.** Its `OnHide` no longer ends
  the trip. While hidden it does not tick; it picks up where it was when shown
  again.
- **Start Route in the planner replaces the running trip.** That is the one
  deliberate way to change destination.
- **Opening the planner mid-trip shows the trip's destination** when the
  planner has none of its own.

### What is saved

Only the destination, by name, in the **account-wide** save:

```lua
GoblinPSDB.trips = { ["Name-Realm"] = { to = "Orgrimmar" } }
```

Account-wide and keyed by `API.CharacterKey()`, because on build 1.60.1.69913
`SavedVariablesPerCharacter` is written and never loaded (verified in game
2026-09-21; see `docs/research/2026-09-19-api-and-data-findings.md`).
`Prefs.Init` guarantees `trips` is a table, as it does `known`. Two characters
can each have their own trip underway.

The saved step list and step index are deliberately **not** stored: the
player may be anywhere when they log back in, and the route always starts
where you stand, so resuming is simply planning again.

### Resuming

On login (`API.OnLogin`, which fires on `PLAYER_LOGIN`, after saved variables
load): if this character has a saved trip, look the destination up by name
with `Search.Exact(ns.Data, name, faction)`.

- **Found:** the dash comes back and **replans from wherever you stand as soon
  as the client knows your position** -- the dash already pauses on "Waiting..."
  while there is none -- then sets the pin on the first step.
- **Not found** (a beta patch renamed the place): drop the saved trip and say
  so in one chat line, e.g. `Couldn't resume your trip to Orgrimmar: that
  place isn't in GoblinPS's data any more.` Never silently.

### The map pin

`C_Map.ClearUserWaypoint`, `C_Map.HasUserWaypoint` and `C_Map.GetUserWaypoint`
are all on this build (`MapDocumentation.lua`; Blizzard's own
`WaypointLocationDataProvider.lua` calls the clear). They go through
`API.lua`. **Clear only a pin that is still ours:** remember the last point
`Core.PinStep` set and compare it with `C_Map.GetUserWaypoint()` before
clearing, so a waypoint the player dropped mid-trip survives. This absorbs
the "clear the pin on arrival and on Stop" entry from `docs/later.md`, which
comes off that list.

### Tests (desk)

- The dash is not in `UISpecialFrames`.
- Hiding the dash leaves the trip intact.
- Stop ends the trip, clears the saved trip and clears our pin.
- Stop does **not** clear a pin that is no longer ours.
- Arrival clears our pin and keeps "Arrived." showing.
- A simulated reload -- account save serialised and reloaded, per-character
  save nil, as the client really does it -- resumes the same destination.
- Another character's saved trip does not resume.
- A destination that no longer resolves is dropped, with the message.
- Start Route replaces a running trip's saved destination.

### In game

- With a trip running: Escape, then Alt+Z twice -- the dash is still going.
- `/reload` mid-trip: the dash comes back, replans from here, pin set.
- Log out and back in mid-trip: the same.
- Press Stop: the dash goes, the pin clears, and a `/reload` brings nothing
  back.
- Drop your own map pin mid-trip, then arrive: your pin is still there.
- Log in a second character: no trip.

---

## Plan 8 — the planner rebuilt to the mockup

### The window

One wide shape, 650x416, exactly the art's 25:16. Top to bottom:

- **Title and tagline plates**, carrying their own lettering. Gear and close,
  top right.
- **One search box**, placeholder "To: city, zone or flight stop", with the
  dropdown beside it. Typing, or the arrow, drops the results list over the
  screen.
- **The screen**, full width, scenery behind it, **the strip centred in it**.
- **Under the strip, always visible:** the total ("~15 min · free") and the
  amber warning.
- **Start Route**, centred under the screen. Disabled until there is a route;
  closes the planner and opens the dash.

With no destination picked, the screen shows the status lines it shows today
("Flight paths known: 3", "Visit a flight master…") and no strip.

### What comes out

- From, Here, and the planner's "from" state (the router keeps its parameter).
- `Planner.SIZE.tall`, the Wide/Tall button, the mode switching in
  `ApplyLayout`, the `layout` preference and `Core.Layout`/`ToggleLayout`,
  and any stale `layout` key in a player's save.
- `planner-frame-tall` from `make_art.py`'s parts and from `GoblinPS/Media`;
  the tall geometry from `Data/Art.lua` -- the generator emits wide only.
- The side panel and its step rows.
- Every tall test and checklist line; `check_art.py` and the generator tests
  stop comparing wide against tall.

Untouched on disk: `images/parts/planner-frame-tall.png` and the tall section
of `images/parts/planner-geometry.json`.

### `Strip.lua` — the pure layout

Pure: reads `ns.Route` and data, touches no Blizzard global, owns no frame.

```lua
-- steps: the planned route's steps. opts: { faction = "H"|"A"|nil,
-- level = number, trackWidth = px, badgeWidth = px }.
local layout = Strip.Layout(data, steps, opts)
-- layout = {
--   stops = { { x = 0..1, badge = "<part name>", label = "...",
--               tooltip = { { text = "...", amber = bool }, ... } }, ... },
--   legs  = { { from = i, to = i + 1, style = "solid"|"dashed", mid = 0..1 }, ... },
--   labels = bool,
-- }
```

**Stops.** One more stop than there are steps.

| stop | badge |
|---|---|
| the start | `icon-horde` for "H", `icon-alliance` for "A", `icon-neutral` otherwise |
| after a `ride` step | `icon-walk` when `step.walk`, else `icon-ride` -- the same test `Route.StepText` uses to say Walk or Ride |
| after `fly`, `zeppelin`, `boat`, `tram`, `hearth` | `icon-flight`, `icon-zeppelin`, `icon-boat`, `icon-tram`, `icon-hearth` |
| the last stop | `node-destination` (the signpost), whatever the leg |
| after a kind it does not know | `node-ring`, never an error |

The start's label is "You are here". Every other stop's label is
`Search.ShortName` of its step's destination.

**Placement.** `x = (i - 1) / (n - 1)` for `n` stops. A one-step route is two
stops at the two ends. A zero-step route ("you're already there") returns no
stops; the planner draws no strip and says so in words.

**Names.** `labels` is true while the space between badge centres,
`trackWidth / (n - 1)`, is at least `Strip.LABEL_ROOM` (2) badge widths. Below
that every name is dropped and lives only in the tooltips. Each shown name is
truncated to that space.

**The line.** The first leg -- the one you are about to start -- is `solid`;
every leg after is `dashed`. Each leg carries its midpoint for the glowing dot.
No trip tracking is needed: the route always starts where you stand, so
reopening the planner mid-trip replans and the first leg is always the current
one.

**Tooltips.** The start: "You are here". Every other stop, from its step:

1. `Route.StepText(step)` -- e.g. "Zeppelin to Orgrimmar"
2. `Route.FormatTime(step.seconds)` -- e.g. "~4 min"
3. `Route.StepDetail(data, step, level)` when it returns text -- e.g.
   "includes the average wait", "into Silverpine Forest · level 10-20" --
   with `amber` set from its warning flag.

### Drawing it

`Planner.lua` draws the layout and decides nothing.

- **Parts** -- `make_art.py` ships fifteen: `node-ring`, `node-destination`,
  `line-solid`, `line-dashed`, `line-dot`, the seven travel icons and the three
  crests. `node-current`, `icon-gate` and `icon-warning` stay unshipped. The
  geometry's `node_diameter` is the badge's **visible ring**; the full sprite
  is 1.5 times that (a 128 px ring on a 192 px canvas) -- size from the ring
  and every stop draws a third too small.
- **Badges** -- small Buttons so they can take a hover, pooled and reused,
  hidden when a route needs fewer, the pool growing only for a longer route.
  Placed along the strip track from the geometry. A badge whose texture will
  not load still draws as a flat circle.
- **The line** -- drawn under the badges, so they cover its ends. The dashed
  part **tiles** rather than stretches, so a dash keeps its length on any leg;
  that needs the line parts shipped unpadded, as `planner-panel` is. The dot
  sits at each leg's midpoint.
- **Names** -- a FontString under each badge, two horizontal anchors spanning
  the space between badges, truncating; hidden when `labels` is false.
- **Tooltips** -- Blizzard's standard `GameTooltip`, amber for warnings, through
  a small `W.ShowTooltip(owner, lines)` in `Widgets.lua`. The minimap button
  keeps its own tooltip code; changing it is not this job.
- **Nothing opaque over the strip.** The screen is a solid panel. Today's
  invisible-scenery bug was exactly that shape, so the strip is drawn above the
  screen's colour fills and a test pins it.

### Tests

- `Strip.lua` as data: the badge for every step kind and walk/ride, the crest
  for each faction, the signpost, the ring for an unknown kind; spacing; the
  one-step and zero-step cases; names on either side of the threshold; solid
  then dashed; midpoints; every tooltip line and its amber flag.
- The window: an N-step route draws N + 1 badges at the positions the layout
  gives (positions, not just sizes); spare badges hidden; hovering a stop
  shows its lines; no strip without a route; From, Here, Tall and the step
  list are gone.
- Visibility: the line under the badges; the strip above the screen's opaque
  fills.
- The art tool: the fifteen strip parts ship at their source aspect, the line
  parts unpadded; `node-current`, `icon-gate`, `icon-warning` and
  `planner-frame-tall` do not ship; `Art.lua` carries wide geometry only.
- A composite of the strip from the real art at its geometry, looked at.

### In game

- Brill to Orgrimmar reads crest, boot, zeppelin, signpost -- the first leg
  solid, the rest dashed.
- A long route shows every stop; names give way to tooltips when crowded.
- Each tooltip says the right thing. A leg into a zone above your level has
  its detail line in amber, and the warning under the strip names it; the
  line itself is not coloured and no badge changes (the skull is day 2).
- `/gps selftest` names the strip's textures; if one fails, that stop is a
  flat circle and the strip still reads.
- No From, no Here, no Wide/Tall button.

### The dependency

Codex redraws `images/parts/planner-geometry.json` for this layout -- one
layout, the same rules. Brief: `docs/art-parts-brief-planner-mockup.md`. It
blocks only the drawing tasks: the removals, the parts and `Strip.lua` do not
need it. The measured `interior` from 2026-09-21 carries over unchanged.

**Delivered 2026-09-21** (`6ebb83c`), verified here: `wide` holds exactly the
fourteen requested regions, `tall` is byte-identical to before, every value is
in range, and every content rectangle sits at 0% opaque frame pixels. Four
facts from Codex's handoff (`images/parts/QUESTIONS.md`) bind the drawing:

1. `strip_track`'s left and right are the end badges' **centres**, not edges;
   the screen already reserves the full sprite at each end. Do not inset twice.
2. `line_thickness` is now **0.02** of canvas width and means the texture's
   **full height, glow included**. Keep the texture's aspect, tile at that
   scale, crop only the last tile, never stretch a line to a leg's length.
3. `line-solid` and `line-dashed` tile cleanly -- their edges match byte for
   byte (`_planner-line-seams.png`).
4. Eleven stops fit at 113 px centre spacing against 96 px rings; names drop,
   stops do not scroll. The total and warning have their own slots below the
   names, the results list ends above both so the warning stays visible while
   searching, and the idle status lines replace the strip rather than drawing
   over it.

Until plan 8 adapts it, the desk art tooling reports the new layout as
mismatched: 8 Python tests and 6 `check_art.py` geometry checks fail, by
design, naming the dropped keys. The addon is unaffected -- `Data/Art.lua` has
not been regenerated from the new geometry.

---

## Out of scope

- The skull badge (day 2), the gate badge, the green-dot ring.
- A settings panel. The gear still says "Settings are not built yet."
- Any change to the dash's layout or art, or to routing itself.

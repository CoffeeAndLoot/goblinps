# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

GoblinPS ("Goblin Positioning System") is a World of Warcraft addon for the
**WoW Forever** client (beta build 1.60.1.69977, interface `16001`): a route
planner. Pick a destination, get the fastest route from where you stand using
flight paths *this character has discovered*, boats, zeppelins, the tram and
the hearthstone. Forever has no flying, so travel is a real puzzle.

Plain Lua 5.1 against the Blizzard API, **no libraries** (no Ace3, no vendored
libs). Sibling projects `D:\healme` and `D:\looseEnds` share these conventions;
borrow patterns from them, not code.

**What it does today.** `/gps` opens the planner: one search box, the route
drawn as a strip of badges (a tooltip on each), the total and one amber
warning line, and Start Route. `/gps to <place>` prints the route in chat.
Start Route opens the dash unit: an arrow pointing at the current step, the
distance and time left, advancing when you arrive and replanning when you
stray. Ground travel goes zone by zone through named crossings, walking or
riding by level. The gear opens a settings panel. Right-clicking the minimap
button (or `/gps where`) gives a copyable position line for measuring data.

**Status (2026-09-22): plans 1 to 11 are built and on `main`.** This project draws a hard line between **verified in source** and
**verified in game**, because its history is faults that passed every desktop
test and showed only on screen. Seen in the client so far:

- Plans 1-3 (routing core, planner, ground crossings): confirmed 2026-09-20.
- Plans 4-5 (the dash): both drew wrong on first run and were fixed on
  screen -- an oval from a stretched square texture (`5858643`), a compass
  behind the brass (`2d58322`), the compass and every line of text misplaced
  because build() read sizes from frames that only inherit them (`2a9e856`).
  Since then the smooth-turning arrow was seen (2026-09-21).
- Plans 6 and 8 (the planner art, then the planner rebuilt to the mockup):
  seen 2026-09-21 -- sealed against a plain sky, the strip's badges on the
  line, the tooltips, the level warning, the zeppelin wait, Close and the gear
  on the brass, scenery edge to edge. A whole trip from the Crossroads to
  Silverpine Forest ran end to end on the dash.
- Plan 7 (only Stop ends a trip): Escape leaves the dash alone (seen). Resume
  after `/reload` is blocked by the client: saves never load (rule below).
- The signpost naming the destination and labels without "the": seen
  2026-09-22. The where-am-I line is in use for measuring.
- Walked 2026-09-22 before the first Wago upload (the checklist's first
  section): plan 9's settings panel, About, scrolling dash text and its Off
  setting; plan 10's wheel scrolling, zone browser and places; the To box
  selecting on focus; the hearthstone badge; and plan 11's warning for an
  enemy town picked on purpose.
- **Not yet run in the client:** the raised arrow and its darker tint, a walk
  through a two-ended crossing (the Talondeep Path), a route walked round an
  enemy town, and a stopover (none exist yet). Do not write that they have
  been.

What is still estimated is **data, not code**: most crossing coordinates
(five measured so far -- see the checklist's "Measured in game so far"), the
two mount speeds, `cross` times, some zone level ranges, the enemy-town radii,
and town factions (only the owner's marks). The addon says so in amber where
it matters; `docs/manual-test-checklist.md` lists what to walk.

The design is `docs/superpowers/specs/2026-09-19-goblinps-design.md`,
amended by the later specs in the same folder (planner redesign, settings and
marquee, towns and browsing, enemy towns); each plan in
`docs/superpowers/plans/` names its spec, and `docs/build-log/` keeps how
each was built: rulings, review findings and fixes. A schematic world map
was dropped on 2026-09-20 in favour of the strip (spike kept at
`docs/research/schematic-spike/`). Ideas not yet planned live in
`docs/later.md`. Write each plan after the one before it has been used in
game.

Everything known about the client API and data sources is in
`docs/research/2026-09-19-api-and-data-findings.md`. Read it first. It marks
what is **verified in source** versus **unverified in game**; do not promote
the second to the first without an in-game check.

## Layout

```
GoblinPS/GoblinPS.toc        # manifest; Interface 16001
GoblinPS/API.lua             # the ONLY file that calls Blizzard game APIs and registers game-data
                              # events (LooseEnds pattern); UI files may register UI layout events
                              # (UI_SCALE_CHANGED, DISPLAY_SIZE_CHANGED) for their own frames
GoblinPS/Data/*.lua          # GENERATED from wago.tools by tools/build_graph.py (Places, Nodes, Flights, Towns)
GoblinPS/Data/Towns.lua      # GENERATED from AreaPOI: every named town in its zone, a faction only from tools/town-factions.csv; stops and Inns rows win
GoblinPS/Data/Links.lua      # HAND-WRITTEN: boats, zeppelins, tram
GoblinPS/Graph.lua           # pure: nodes + edges, filtered by what the character knows
GoblinPS/Route.lua           # pure: shortest path (Dijkstra on cost), step list, step text and detail lines
GoblinPS/Geo.lua             # pure: map to world yards, distances, segment distance, nearest crossing or dock
GoblinPS/Search.lua          # pure: the places a player can pick (stops, towns, inns), zone words, the zone browser
GoblinPS/Trip.lua            # pure: arrival, straying and bearing rules for the dash
GoblinPS/Strip.lua           # pure: the route strip as data -- badges, spacing, tooltips, solid/dashed legs
GoblinPS/Marquee.lua         # pure: the dash's scrolling text, a character window
GoblinPS/Known.lua, Prefs.lua  # pure: learned flight paths; account preferences, arrival radii and their ranges
GoblinPS/Data/Inns.lua       # HAND-WRITTEN: hearthstone bind names Search cannot find alone; a row wins over a generated town of its name
GoblinPS/Data/Crossings.lua  # HAND-WRITTEN: zone-to-zone crossings and city gates (coords are estimates until walked)
GoblinPS/Data/Stopovers.lua  # HAND-WRITTEN: named points a ride may bend through round an enemy town; empty until walked
GoblinPS/Data/Zones.lua      # HAND-WRITTEN: level range per zone, for the amber warnings
                              # HAND-WRITTEN and staying that way: C_Map.GetMapLevels is dead on this
                              # build (answers for no zone), so /gps probe zones can only report that
GoblinPS/Travel.lua          # pure: walk or ride by level; the ONLY place mount levels and speeds live
                              # (levels 40/60 confirmed in game 2026-09-20; the two speeds are still assumed)
GoblinPS/Widgets.lua         # plain controls in the gadget palette; NO Blizzard frame templates; owns the
                              # shared placement helpers (PlaceRect, PlaceLine, PlaceCircle) and the Stretch3
                              # three-slice stretcher that both windows read their geometry through
GoblinPS/Planner.lua         # the window; draws Strip.lua's layout and decides nothing; no coordinate
                              # is hand-typed here -- every position comes from ns.Data.ArtGeometry.planner.wide
GoblinPS/Settings.lua        # the settings panel behind the gear; plain, no art yet, so its spacing is its own
GoblinPS/Dash.lua            # the small draggable device shown when Start Route closes the planner; arrow, distance, ETA
GoblinPS/Data/Art.lua        # GENERATED: texture coordinates AND placement geometry (ns.Data.ArtGeometry) for
                              # shipped art parts, built by tools/make_art.py from images/parts/dash2-geometry.json
                              # and images/parts/planner-geometry.json; no coordinate is hand-typed in Dash.lua
                              # or Planner.lua
GoblinPS/MinimapButton.lua   # the minimap button; right-click opens the copyable where-am-I line
GoblinPS/SelfTest.lua, Core.lua  # /gps selftest; glue, the slash commands and saved variables
test/fake_frames.lua         # fake frame API: smoke-tests OUR window code, not Blizzard's
tools/build_graph.py         # generator, modelled on D:\looseEnds\tools\build_catalog.py
tools/make_art.py            # builds shipped textures from images/parts/*.png, scales and pads them, generates Data/Art.lua
tools/catalog.lock           # pinned client build
tools/survey_crossings.lua   # lupa script: how far each crossing sits from its two zones' shared edge
tools/town-factions.csv      # HAND-WRITTEN by the owner: A, H or N per generated town; the only source of a town's faction
test/run.lua                 # desktop Lua test runner
docs/                        # specs, research, manual test checklist
docs/build-log/              # how each plan was built: its ledger, rulings, briefs and review fixes
```

Each module opens with `local addonName, ns = ...` and publishes itself on the
shared `ns` table. Pure logic (graph, routing, step text) gets unit tests;
frames and live game data are verified in game via
`docs/manual-test-checklist.md`. This addon needs **no secure code**: no
casting, no combat lockdown, no protected frames. Keep it that way.

## Commands (same toolchain as the siblings; this Windows box)

No Lua interpreter and Docker is usually off. Run Lua tests through `lupa`:

```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```

luacheck from PowerShell:

```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
$env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
```

lua-language-server batch check, **from PowerShell** (run against the repo
root so `.luarc.json` loads): `lua-language-server --check D:\goblinps
--checklevel=Warning --check_out_path=<file.json>`. Through Git Bash it
silently mis-scopes the workspace root to the `GoblinPS/` subfolder, never
loads `.luarc.json`, and reports over a hundred bogus "undefined global"
warnings -- a false red tree, not a real one; do not go fix what those
warnings name.

Copy `.luacheckrc`, `.luarc.json` and the `test/` harness from `D:\looseEnds`
when code starts; a new WoW global goes in both config files. Keep lint and
the language server at zero warnings.

In-game testing uses a directory junction, so `/reload` picks up edits:

```
New-Item -ItemType Junction -Path "D:\World of Warcraft\_classic_beta_\Interface\AddOns\GoblinPS" -Target "D:\goblinps\GoblinPS"
```

The beta client lives in `_classic_beta_`, not `_retail_`.

**The owner plays from this checkout.** The junction points the game at
`D:\goblinps\GoblinPS`, so whatever branch is checked out here is what a
`/reload` loads, half-finished edits included. So:

- Build in a separate worktree (`git worktree add ..\goblinps-wt\<name>`),
  never in the checkout the owner is playing from, and bring finished,
  reviewed work across with a fast-forward. Say plainly when a `/reload` is
  safe.
- A change that adds a file to the TOC needs a **full client restart**, not a
  `/reload`; say so every time.
- Measuring data in game: stand on the spot (for a crossing, where the zone
  name flips), right-click the minimap button or `/gps where`, and paste the
  line. `test/test_crossings.lua` refuses a crossing that is not on both
  zones' shared edge, which catches a reading taken short of the border.

## Verifying against Blizzard's UI source

Never guess a template, atlas, event or API name. The beta's exact UI source
is the **`forever` branch** of github.com/Gethe/wow-ui-source (its
`version.txt` reads the build, `1.60.1.69977` today). Clone it shallow into a scratch folder
and grep:

```
git clone --depth 1 --branch forever https://github.com/Gethe/wow-ui-source.git
```

A local clone already lives at `D:\wow-api\1.60.1.69977` (check its
`version.txt`; `git pull` or re-clone when the beta updates). The sibling
folder `D:\wow-api\12.1.5.69594` is **Retail** source: fine for HealMe, never
the authority for GoblinPS.

API docs are in `Interface/AddOns/Blizzard_APIDocumentationGenerated/`.
Game data tables come from `https://wago.tools/db2/<Table>/csv?build=<build>`.
When the beta updates, re-check both against the new build number (read it
from `D:\World of Warcraft\.build.info`, product `wow_classic_beta`).

## Versions and git

Calendar versions (`2026.09.19`, `.2` for a second release that day), written
only in the TOC. Commit after each change. Never push or merge to `main`
unless the owner says so.

**Releasing.** GoblinPS is on Wago Addons (project `aND9d26o`,
https://addons.wago.io/addons/goblinps, stable channel) and the repository is
public. A release is a tag `v<version>` whose version equals the TOC's:
pushing it runs `.github/workflows/release-addon.yml`, which zips `GoblinPS/`,
makes the GitHub release and uploads to Wago under Forever's live patch
(`supported_forever_patches`); a tag containing `beta` or `alpha` publishes at
that stability. Pushing a tag publishes to players: only on the owner's word,
every time. The `WAGO_API_TOKEN` secret is the owner's; never read or set it.

Another agent, **Codex**, owns the artwork and commits here too, on whatever
branch is checked out; re-read files before editing. Its `AGENTS.md` is in
`.gitignore` and is never committed. The art's placement files
(`images/parts/planner-geometry.json`, `dash2-geometry.json`) are rewritten by
Codex's own scripts, so a placement change goes to Codex as a short brief in
`docs/art-parts-brief-*.md`, never as a hand edit; then regenerate
`Data/Art.lua` with `tools/make_art.py`.

## Rules that are easy to break

- `RegisterEvent` with a name the client does not know is a hard error.
  Check every event against the `forever` branch first.
- Known flight paths are **learned at flight masters**. `isUndiscovered` is
  dead on build 1.60.1.69913 (false for every node, verified in game), so the
  only truthful moment is `TAXIMAP_OPENED`, when `C_TaxiMap.GetAllTaxiNodes`
  marks each node current, reachable or unreachable. `Known.Learn` adds the
  flyable ones to `GoblinPSDB.known["Name-Realm"]` -- the **account-wide**
  save, one table per character, keyed by `API.CharacterKey()`. That store
  only ever grows and is never edited by hand or by any other code path. If
  a later build fixes `isUndiscovered`, switch back to the live read.
- **On this build, an API being present says nothing about whether it
  answers.** Two so far return nothing useful for every input:
  `isUndiscovered` (false for every node) and `C_Map.GetMapLevels` (no range
  for any of the 60 zones). A third is a whole feature:
  **SavedVariables are written and never loaded -- for every addon,
  account-wide and per character.** Verified 2026-09-21: `GoblinPSDB.test =
  42`, `/reload`, and the file on disk held 42 while the table read `nil`;
  Wowhead Looter, a plain folder with no GoblinPS code, forgets its settings
  the same way. An earlier check "proved" the account-wide save loaded by
  seeing a table after a reload -- a table GoblinPS itself creates at
  `PLAYER_LOGIN`. Still true on build 1.60.1.69977 (the owner, 2026-09-22).
  **A check must be able to fail**: plant a value only a
  real load could bring back. Until a build fixes this, learned flight paths
  and a trip in progress last one session; keep the account-wide save keyed
  by `"Name-Realm"` (the right shape once loading works) and declare no
  per-character variable. Do not build a persistence workaround on macros
  or CVars. The APIs are present, documented, and
  `/gps selftest` reports both `ok` — because `ok` there means the function
  exists, not that it works. So: any probe that reads an API across many
  inputs must **count its answers and say plainly when there are none**,
  never let silence read as "nothing disagrees", and never promote a source
  check to a verified fact without running it in the client. `/gps probe
  zones` is the worked example; keep probes after they fail, since a later
  build may fix the function and the probe will notice by itself.
- The window uses **no Blizzard frame templates**: plain frames and colour
  textures, so a template renamed by a beta patch cannot break it. Art is
  laid over the colours (`docs/art-specs.md`); a missing texture must leave a
  working window. `/gps selftest` checks fonts, stock textures and APIs.
- Route text must stay plain and glanceable. The goblin jokes live in the
  frame, the tagline and the tooltips, never in the directions.
- Known Blizzard bug on 1.60.1.69913: all secure snippets fail
  (`loadstring_untainted` is nil). GoblinPS uses none, so it is unaffected;
  do not add any.
- **Never read a size from a frame that only inherits one.** A frame sized
  by `SetAllPoints` has no resolved size until the client's layout pass, so
  `GetWidth()` on one during `build()` answers **0** -- silently, since 0
  multiplies fine. Measure the frame given an explicit `SetSize`. Caught in
  the client 2026-09-20, after 257 tests passed: the fake copied the size
  across on `SetAllPoints`, so every derived size answered correctly at the
  one moment the client would not. `Fake.Layout()` now marks the layout pass;
  a test wanting a resolved size must call it, and by calling it says out
  loud that it is past build time.
- **A test that checks how big a thing is cannot tell you it is in the wrong
  place.** Two tests pinned the compass's size and none its position, which
  is how a device drawn off its own frame passed a green suite. Pin both.
- Text in the window must be bounded: give every FontString two horizontal
  anchors (or a width) and decide wrap or truncate. A one-anchor FontString
  fed a sentence draws over its neighbours and past the frame.
- Ground travel is per zone: a ride edge joins two points only when they
  share a UiMap, and a crossing belongs to both of its zones. A tunnel or
  lift is a crossing with two ends (`far`), each in its own zone, joined by a
  through edge. Every place handed to the router needs its `map`. A missing crossing shows up as a step
  labelled "(no mapped path)"; add the row to `Data/Crossings.lua`, do not
  loosen the rule. `test/test_crossings.lua` checks every row and that each
  continent's zones all connect. A crossing's name must read correctly
  whichever way you are going; the detail line gives the direction.
- **A part's texture coordinates and its canvas dimensions must come from
  the same place, and that place is the generated part entry.**
  `tools/make_art.py` emits `cw` and `ch` -- the part's padded canvas's own
  pixel size -- on every `Art.lua` row, because a part's `l/r/t/b` are
  fractions of that padded shipped canvas, never of the master PNG. Passing
  the master's 1600x640 alongside those fractions cropped the planner
  screen's scenery 15.33% per side where 6.66% was intended -- under half
  the intended picture, without crashing or distorting. Read `cw`/`ch` off
  the part; never recompute a size or borrow one from source art.
- **An art part that stacks shares its canvas; an art part that is an insert
  does not.** The dash's five layers are one rectangle corner to corner. The
  planner's `screen-backdrop` is the opposite: 2.5:1 scenery scaled to cover
  its opening and centre-cropped, with the crop composed into the part's own
  padding coordinates. Reading one rule as the other either distorts the art
  or crops the padding instead of the picture.
- **Only Stop ends a trip.** Escape, hiding the interface, arriving and a
  reload must never end it or clear its save. The dash is not on
  `UISpecialFrames`, its `OnHide` does nothing to the trip, and `Dash.Stop` is
  the one place the saved trip (`GoblinPSDB.trips["Name-Realm"]`) is cleared.
  Stop and arrival both clear the map pin, and only a pin GoblinPS set. The
  game holds one user waypoint, which GoblinPS moves on every advance, replan
  and resume, so a waypoint the player drops mid-trip is theirs only until
  the next move -- it survives ending the trip in general only if it was
  dropped after GoblinPS's last move, typically on the trip's last step.
- **An enemy town is a penalty, never a ban, and only a known one.** A ride
  leg whose straight line passes the other side's flight master, or a town
  the owner marked in `tools/town-factions.csv`, within its radius costs
  `Graph.HOSTILE_SECONDS` more and carries `danger`; flights, links, the
  hearthstone and a tunnel's through leg are never charged. The penalty
  steers the router but is never shown: every edge keeps its real `seconds`,
  and the player is only ever shown real travel time, never the penalty.
  A leg is excused from a circle only when it is leaving it -- it starts
  inside and never comes closer to the centre than where it starts -- or
  when it ends at your destination or a stopover inside it, so every enemy
  town stays reachable on purpose. Anything else is charged: a gate, a
  tunnel mouth or a flight master on the way, and a replan from a town's
  edge that cuts through its middle. (Excusing any end let an Alliance walk
  go in at Orgrimmar's front gate and out at its west gate unwarned;
  excusing where you stand let a replan 145 yd from Silverwind walk through
  its centre; charging both ends of a gate doubled detours to 20 minutes.)
  No code guesses a town's faction (the nearest-flight-master guess made
  caves and rivers into towns). A route that walks through a town
  is fixed by marking it, or with a `Data/Stopovers.lua` row measured in
  game, never by removing the edge or shrinking the radius until a test
  passes.
- **"Zero lint warnings" is not licence to silence one instead of fixing
  it.** `.luacheckrc` carries per-file `max_line_length = false` for five
  files, four of them generated -- nobody reads generated Lua, and line
  length is a readability rule for humans, so that exemption is fine and
  established. It covers exactly that: a rule that does not apply to
  generated output. It is not a precedent for a future file. Do not add
  `---@diagnostic disable`, a `luacheck:` exemption, or another
  `max_line_length = false` entry to make a real warning on hand-written
  code go away; fix the code, or, if the check itself is wrong, say so and
  change the check.
- **A destination is a place; a zone is offered only when it holds no place.** Every destination is a point with a name and a map position -- a flight stop (the other faction's too, marked, and ridden to, never flown to), an inn town, and later a quest. A zone name is otherwise only a search word that finds the places in it (decided 2026-09-22: a zone destination routed to its border and read as broken). A zone with no stop and no town is offered as itself so that no zone is out of reach; `test/test_data.lua` lists exactly which ones.

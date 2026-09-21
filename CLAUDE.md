# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

GoblinPS ("Goblin Positioning System") is a World of Warcraft addon for the
**WoW Forever** client (beta build 1.60.1.69913, interface `16001`): a route
planner. Pick a destination, get the fastest route from where you stand using
flight paths *this character has discovered*, boats, zeppelins, the tram and
the hearthstone. Forever has no flying, so travel is a real puzzle.

Plain Lua 5.1 against the Blizzard API, **no libraries** (no Ace3, no vendored
libs). Sibling projects `D:\healme` and `D:\looseEnds` share these conventions;
borrow patterns from them, not code.

**Status: plans 1 to 8 are built.** Plans 1 to 3 are merged to `main` and
confirmed in the client (2026-09-20: routing core, planner window, ground
crossings). Plan 4, the dash unit's first design, ran in the client twice on
2026-09-20: the round art rendered as an oval (a square texture stretched
across a non-square frame, `5858643`) and the compass vanished behind the
brass (its stacked layers drawn at different sizes, `2d58322`); both were
seen on screen and fixed. The device was then redesigned around a second art
set -- plan 5, this work: the current step's name and distance on the glass,
three step lines in a lit panel, the ETA on its own plate, a stop button with
hover and pressed states, every position read from a generated geometry
file. Plan 5 ran in the client on 2026-09-20 and drew wrong: the compass
and arrow sat off the device and every line of text was invisible, because
build() read sizes from frames that only inherit them (`2a9e856`). The art,
the stop button and the housing were right on the first try. Plan 6 re-clad
the planner window the same way it redid the dash: sixteen art parts, a
placement geometry file (`images/parts/planner-geometry.json`) copied into
`GoblinPS/Data/Art.lua`, and `Planner.lua` now hand-types no coordinate.
**Plan 6 has not been run in the client.** Do not write that it has: this
project draws a hard line between verified in source and verified in game,
and this branch's own history is faults that passed every desktop test and
were only visible on screen. `/gps` opens the planner;
`/gps to <place>` prints a route in chat, with ground travel going zone by
zone through named crossings and walk-or-ride by level. GO closes the
planner and opens the dash unit: an arrow pointing at the current step,
showing distance and time left, advancing when you arrive and replanning
when you stray. What is still estimated is **data, not code**: crossing
coordinates, the two mount speeds, `cross` times and some zone level ranges.
The addon says so in amber where it matters;
`docs/manual-test-checklist.md` lists what to walk. Plan 7, built 2026-09-21,
made a trip end only on Stop: the dash comes off `UISpecialFrames`, hiding it
no longer ends the trip, and the destination is saved by name in the
account-wide `GoblinPSDB.trips` so a `/reload` or logout resumes it --
once the client loads saves, which build 1.60.1.69913 does not (see the
SavedVariables rule below).
**Plan 7 has not been run in the client**, for the same reason as plan 6
above: verified in source is not verified in game. Plan 8, built 2026-09-21,
rebuilt the planner to the mockup: one search box, the route strip drawn by
the pure `Strip.lua`, a tooltip on every stop, wide only. **Plan 8 has not
been run in the client.** A schematic world map was dropped on 2026-09-20 in
favour of the strip; the spike that proved it feasible is kept at
`docs/research/schematic-spike/`. The product is a GPS: point to point with
an arrow, in game. The design is
`docs/superpowers/specs/2026-09-19-goblinps-design.md`, amended for plans 7
and 8 by
`docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`.
Write each plan after the one before it has been used in game.

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
GoblinPS/Data/*.lua          # GENERATED from wago.tools by tools/build_graph.py
GoblinPS/Data/Links.lua      # HAND-WRITTEN: boats, zeppelins, tram
GoblinPS/Graph.lua           # pure: nodes + edges, filtered by what the character knows
GoblinPS/Route.lua           # pure: shortest path (Dijkstra), step list
GoblinPS/Strip.lua           # pure: the route strip as data -- badges, spacing, tooltips, solid/dashed legs
GoblinPS/Known.lua, Prefs.lua  # pure: learned flight paths; account preferences
GoblinPS/Data/Inns.lua       # HAND-WRITTEN: hearthstone bind names Search cannot find alone
GoblinPS/Data/Crossings.lua  # HAND-WRITTEN: zone-to-zone crossings and city gates (coords are estimates until walked)
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
GoblinPS/Dash.lua            # the small draggable device shown when GO closes the planner; arrow, distance, ETA
GoblinPS/Data/Art.lua        # GENERATED: texture coordinates AND placement geometry (ns.Data.ArtGeometry) for
                              # shipped art parts, built by tools/make_art.py from images/parts/dash2-geometry.json
                              # and images/parts/planner-geometry.json; no coordinate is hand-typed in Dash.lua
                              # or Planner.lua
GoblinPS/MinimapButton.lua, SelfTest.lua, Core.lua
test/fake_frames.lua         # fake frame API: smoke-tests OUR window code, not Blizzard's
tools/build_graph.py         # generator, modelled on D:\looseEnds\tools\build_catalog.py
tools/make_art.py            # builds shipped textures from images/parts/*.png, scales and pads them, generates Data/Art.lua
tools/catalog.lock           # pinned client build
test/run.lua                 # desktop Lua test runner
docs/                        # specs, research, manual test checklist
docs/build-log/              # why plans 2 and 3 went the way they did: rulings and review findings
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

## Verifying against Blizzard's UI source

Never guess a template, atlas, event or API name. The beta's exact UI source
is the **`forever` branch** of github.com/Gethe/wow-ui-source (its
`version.txt` reads `1.60.1.69913`). Clone it shallow into a scratch folder
and grep:

```
git clone --depth 1 --branch forever https://github.com/Gethe/wow-ui-source.git
```

A local clone already lives at `D:\wow-api\1.60.1.69913` (check its
`version.txt`; `git pull` or re-clone when the beta updates). The sibling
folder `D:\wow-api\12.1.5.69594` is **Retail** source: fine for HealMe, never
the authority for GoblinPS.

API docs are in `Interface/AddOns/Blizzard_APIDocumentationGenerated/`.
Game data tables come from `https://wago.tools/db2/<Table>/csv?build=<build>`.
When the beta updates, re-check both against the new build number (read it
from `D:\World of Warcraft\.build.info`, product `wow_classic_beta`).

## Versions and git

Calendar versions (`2026.09.19`, `.2` for a second release that day), written
only in the TOC. Commit after each change. Another agent (Codex) may also
commit; re-read files before editing.

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
  `PLAYER_LOGIN`. **A check must be able to fail**: plant a value only a
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
  share a UiMap, and a crossing belongs to both of its zones. Every place
  handed to the router needs its `map`. A missing crossing shows up as a step
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

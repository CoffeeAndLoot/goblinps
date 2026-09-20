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

**Status: routing core and planner window built (plans 1 and 2).** `/gps`
opens the planner; `/gps to <place>` prints a route in chat. Next: plan 3,
the schematic map on the green screen (approach proven in
`docs/research/schematic-spike/`), then plan 4, the dash unit. The design is
`docs/superpowers/specs/2026-09-19-goblinps-design.md`. Write each plan after
the one before it has been used in game.

Everything known about the client API and data sources is in
`docs/research/2026-09-19-api-and-data-findings.md`. Read it first. It marks
what is **verified in source** versus **unverified in game**; do not promote
the second to the first without an in-game check.

## Intended layout (from the sibling projects; nothing exists yet)

```
GoblinPS/GoblinPS.toc        # manifest; Interface 16001
GoblinPS/API.lua             # the ONLY file that calls Blizzard game APIs and registers game-data
                              # events (LooseEnds pattern); UI files may register UI layout events
                              # (UI_SCALE_CHANGED, DISPLAY_SIZE_CHANGED) for their own frames
GoblinPS/Data/*.lua          # GENERATED from wago.tools by tools/build_graph.py
GoblinPS/Data/Links.lua      # HAND-WRITTEN: boats, zeppelins, tram (and later ground crossings)
GoblinPS/Graph.lua           # pure: nodes + edges, filtered by what the character knows
GoblinPS/Route.lua           # pure: shortest path (Dijkstra), step list
GoblinPS/Known.lua, Prefs.lua  # pure: learned flight paths; account preferences
GoblinPS/Data/Inns.lua       # HAND-WRITTEN: hearthstone bind names Search cannot find alone
GoblinPS/Widgets.lua         # plain controls in the gadget palette; NO Blizzard frame templates
GoblinPS/Planner.lua         # the window; one set of widgets, ApplyLayout moves them
GoblinPS/MinimapButton.lua, SelfTest.lua, Core.lua
test/fake_frames.lua         # fake frame API: smoke-tests OUR window code, not Blizzard's
tools/build_graph.py         # generator, modelled on D:\looseEnds\tools\build_catalog.py
tools/catalog.lock           # pinned client build
test/run.lua                 # desktop Lua test runner
docs/                        # specs, research, manual test checklist
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

lua-language-server batch check (run against the repo root so `.luarc.json`
loads): `lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=<file.json>`

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
  flyable ones to `GoblinPSCharDB.known` (per character). That store only
  ever grows and is never edited by hand or by any other code path. If a
  later build fixes `isUndiscovered`, switch back to the live read.
- The window uses **no Blizzard frame templates**: plain frames and colour
  textures, so a template renamed by a beta patch cannot break it. Art is
  laid over the colours (`docs/art-specs.md`); a missing texture must leave a
  working window. `/gps selftest` checks fonts, stock textures and APIs.
- Route text must stay plain and glanceable. The goblin jokes live in the
  frame, the tagline and the tooltips, never in the directions.
- Known Blizzard bug on 1.60.1.69913: all secure snippets fail
  (`loadstring_untainted` is nil). GoblinPS uses none, so it is unaffected;
  do not add any.

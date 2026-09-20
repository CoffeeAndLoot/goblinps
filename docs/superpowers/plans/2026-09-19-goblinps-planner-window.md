# GoblinPS Planner Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Status: executed 2026-09-19.** This plan is a historical record. Two review rounds changed some of the code
> shown below: dragging, focus loss, the saved window position (now with `relativePoint`), the texture self-check,
> messages bounded inside the window, GO re-planning from where you stand, a guarded `Prefs.Position`, an inn-lookup
> loop guard, and a strict fake frame library. The code in the repo and the spec are the truth, not these listings.

**Goal:** `/gps`, a minimap button and the addon compartment open a Goblin Gadget planner window: pick a destination (and optionally a start) from a type-ahead list, read the steps, times, fares and the discover hint, flip between a wide and a tall layout, and press GO to drop Blizzard's map pin on the first step.

**Architecture:** Three small routing improvements first (a zone destination is reached at any stop inside it; a hand-written inn list for hearthstone binds; a pure `Prefs` module). Then the window: plain frames in our own palette with **no Blizzard frame templates**, built lazily, one set of widgets moved by `Planner.ApplyLayout`. `Core.PlanRoute` becomes the single planner that both the chat command and the window use. A fake frame library lets the window code be smoke-tested on the desktop.

**Tech Stack:** Lua 5.1 on the WoW Forever client (1.60.1.69913, interface 16001), no libraries. Python 3 + Pillow for the icon. Tests through lupa; luacheck and lua-language-server at zero warnings.

**Spec:** `docs/superpowers/specs/2026-09-19-goblinps-design.md`. Read it and `CLAUDE.md` first.

**This is plan 2 of 4.** Plan 3 is the schematic map on the green screen (approach proven in `docs/research/schematic-spike/`). Plan 4 is the dash unit (active trip, `Trip.Check`, arrival detection). Each is written after the one before it has been used in game.

## Global Constraints

- Plain Lua 5.1 against the Blizzard API. **No libraries.**
- Pure modules (`Geo`, `Search`, `Graph`, `Route`, `Trip`, `Known`, `Prefs`) touch no Blizzard global at all.
- `GoblinPS/API.lua` is the only file that calls Blizzard **game APIs** (`C_*`, unit, item, map functions) and registers game events. UI files (`Widgets`, `Planner`, `MinimapButton`, `SelfTest`) may create frames and use `UIParent`, `Minimap`, `GameTooltip`, `GetCursorPosition`. `Core.lua` registers the slash command, the compartment function and prints.
- **No Blizzard frame templates** in the window: plain `Frame`, `Button`, `EditBox` with colour textures. Art, when it exists, is laid over the colours; a missing texture must leave a working window.
- **No secure code.** Never guess an API, event, texture or font name: check `D:\wow-api\1.60.1.69913`. Names this plan adds, all checked: events `PLAYER_LOGIN`, `UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED`; `C_Map.SetUserWaypoint`, `C_Map.CanSetUserWaypointOnMap`, `UiMapPoint.CreateFromCoordinates`, `C_SuperTrack.SetSuperTrackedUserWaypoint`; textures `Interface\Minimap\MiniMap-TrackingBorder`, `Interface\Minimap\UI-Minimap-ZoomButton-Highlight`.
- Known flight paths are learned only by `Known.Learn` into `GoblinPSCharDB.known`. `GoblinPSDB` (account-wide) holds preferences, recents and window positions, nothing else.
- Two planner layouts, **one set of widgets**; `Planner.ApplyLayout(mode)` changes only size and anchors.
- Route text stays plain. Jokes live in the tagline and tooltips only.
- Generated files under `GoblinPS/Data/` (`Places`, `Nodes`, `Flights`) are never edited by hand.
- luacheck and lua-language-server stay at zero warnings; a new global goes in both `.luacheckrc` and `.luarc.json`.
- Version `2026.09.19.2`, written only in the TOC.
- Commit after each task with the trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` as a second `-m`. Do not push.

**Commands** (run from `D:\goblinps`):

Lua tests:

```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```

Python tests: `python -m unittest discover -s test/tools`

luacheck (PowerShell):

```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
$env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
```

Starting point: `70 passed, 0 failed`, luacheck `0 warnings / 0 errors`.

All code in this plan was run together in a scratch copy before the plan was written: 103 Lua tests pass and luacheck is clean. If a count or output differs from what a step expects, stop and report; do not edit code to force a match.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `GoblinPS/Graph.lua` | modify | a zone destination is reached at any place on the zone's map |
| `GoblinPS/Search.lua` | modify | `Search.Exact` consults the inn list |
| `GoblinPS/Data/Inns.lua` | create, hand-written | hearthstone bind names Search cannot find alone |
| `GoblinPS/Prefs.lua` | create, pure | account-wide preferences table |
| `tools/make_icon.py`, `GoblinPS/Media/icon.tga` | create | the addon icon (placeholder until art arrives) |
| `GoblinPS/API.lua` | modify | `SetWaypoint`, `OnLogin`, `SelfCheck` |
| `GoblinPS/Widgets.lua` | create | plain controls in the gadget palette |
| `GoblinPS/Planner.lua` | create | the window |
| `GoblinPS/MinimapButton.lua` | create | the minimap button |
| `GoblinPS/SelfTest.lua` | create | `/gps selftest` |
| `GoblinPS/Core.lua` | replace | saved variables, `Core.PlanRoute`, `Core.Go`, slash, compartment |
| `GoblinPS/GoblinPS.toc` | replace | new files, saved variables, icon, compartment |
| `test/fake_frames.lua`, `test/test_ui.lua` | create | desktop smoke test of the window code |
| `test/run.lua`, `.luacheckrc`, `.luarc.json` | replace | new modules, suites and globals |
| `docs/...`, `CLAUDE.md` | modify | checklist, art specs, spec roadmap, layout |

---

### Task 1: A zone destination is reached anywhere inside the zone

Seen in game: bound at the Crossroads inn, `/gps to barrens` printed "Hearthstone to Crossroads" then a pointless "Ride to The Barrens", because a zone destination aimed at the zone's centre.

**Files:**
- Modify: `GoblinPS/Graph.lua`, `test/test_route.lua`

**Interfaces:**
- Consumes: `opts.to.kind` and `opts.to.map` (places from `Search.Find` carry `kind = "zone"` and the zone's `map`); every stop carries `map`.
- Produces: no new names. When `opts.to.kind == "zone"`, a ride from a place whose `map` equals `opts.to.map` to `DEST` costs 0 seconds; `Route` already drops rides under 5 seconds. A route with zero steps means "already there" (`Core` prints that).

- [ ] **Step 1: Add the failing tests.** In `test/test_route.lua`, insert this block immediately before the line `    h.describe("Route.Hint", function()`:

```lua
    h.describe("a zone destination", function()
        local westland = loaded.ns.Search.Find(world, "westland", "H", 1)[1]
        h.it("is reached at the first stop inside the zone", function()
            local r = Route.Plan(world, { faction = "H", known = { [4] = true }, from = nearDelta, to = westland })
            h.eq(kinds(r), "ride,zeppelin")
            h.eq(r.steps[2].to.key, "west_dock")
        end)
        h.it("has no steps when you already stand in it", function()
            local inWestland = { name = "You", c = 1, x = 1000, y = 1100, map = 1, mx = 0.89, my = 0.9 }
            local r = Route.Plan(world, { faction = "H", known = {}, from = inWestland, to = westland })
            h.eq(#r.steps, 0)
        end)
        h.it("still rides to an exact stop in that zone", function()
            local charlie = loaded.ns.Search.Find(world, "charlie", "H", 1)[1]
            local inWestland = { name = "You", c = 1, x = 1000, y = 1100, map = 1, mx = 0.89, my = 0.9 }
            local r = Route.Plan(world, { faction = "H", known = {}, from = inWestland, to = charlie })
            h.eq(kinds(r), "ride")
        end)
    end)

```

- [ ] **Step 2: Run the Lua tests.** Expected: `71 passed, 2 failed`; the first two new tests fail (`ride,zeppelin,ride` and `1` step).

- [ ] **Step 3: Change `GoblinPS/Graph.lua`.** Three edits inside `Graph.Build`.

Replace

```lua
    stops.START = stopFrom("START", opts.from)
    stops.DEST = stopFrom("DEST", opts.to)
```

with

```lua
    stops.START = stopFrom("START", opts.from)
    stops.DEST = stopFrom("DEST", opts.to)

    -- A zone destination means "anywhere in the zone": a place already on the
    -- zone's map has arrived, so its ride to DEST costs nothing (and Route
    -- drops a ride that short). A stop or an exact spot is ridden to as usual.
    local zoneMap = opts.to.kind == "zone" and opts.to.map or nil
    local function toDest(place)
        if zoneMap and place.map == zoneMap then
            return 0
        end
        return Graph.RideSeconds(place, stops.DEST)
    end
```

Replace `addEdge(edges, origin.key, "DEST", "ride", Graph.RideSeconds(origin, stops.DEST))` with `addEdge(edges, origin.key, "DEST", "ride", toDest(origin))`.

Replace `addEdge(edges, key, "DEST", "ride", Graph.RideSeconds(stops[key], stops.DEST))` with `addEdge(edges, key, "DEST", "ride", toDest(stops[key]))`.

- [ ] **Step 4: Run the Lua tests.** Expected: `73 passed, 0 failed`. Run luacheck: `0 warnings / 0 errors`.

- [ ] **Step 5: Commit**

```
git add GoblinPS/Graph.lua test/test_route.lua
git commit -m "Reach a zone destination at any stop inside the zone" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: The inn list

`GetBindLocation()` returns the inn's area name. Most match a flight stop or zone once a leading "The" is ignored (done already). Two kinds do not: inns beside a flight stop with a different name, and towns with an inn but no flight master (Brill, Razor Hill, Goldshire ...).

**Files:**
- Create: `GoblinPS/Data/Inns.lua`
- Modify: `GoblinPS/Search.lua`, `test/fake_world.lua`, `test/test_search.lua`, `test/test_data.lua`, `test/run.lua`, `GoblinPS/GoblinPS.toc`

**Interfaces:**
- Consumes: `Search.Exact(data, name, faction)`, `ns.Geo.ToWorld`.
- Produces: `ns.Data.Inns[bindName] = { stop = "<short flight stop name>" }` or `{ map, mx, my }`. `Search.Exact` returns the flight stop for the first kind, and for the second a place `{ kind = "inn", name, c, x, y, map, mx, my }`. `data.Inns` may be nil.

- [ ] **Step 1: Add inns to the fake world.** In `test/fake_world.lua`, insert immediately before the line `        Links = {`:

```lua
        Inns = {
            ["Delta Harbour Inn"] = { stop = "Delta" },                 -- an inn beside a flight stop
            ["Quiet Hollow"] = { map = 1, mx = 0.25, my = 0.5 },        -- a town with no flight master
            ["Nowhere Inn"] = { map = 99, mx = 0.5, my = 0.5 },         -- a map we do not have
        },
```

- [ ] **Step 2: Add the failing tests.** In `test/test_search.lua`, insert immediately before the line `        h.it("returns nil for an inn it does not know", function()`:

```lua
        h.it("follows an inn that stands beside a flight stop", function()
            h.eq(Search.Exact(world, "Delta Harbour Inn", "H").nodeID, 4)
        end)
        h.it("places an inn in a town with no flight master", function()
            local inn = Search.Exact(world, "quiet hollow", "H")
            h.eq(inn.kind, "inn")
            h.eq(inn.name, "Quiet Hollow")
            h.eq(inn.c, 1)
            h.eq(inn.x, 5000)
            h.eq(inn.y, 7500)
        end)
        h.it("returns nil for an inn on a map we do not have", function()
            h.eq(Search.Exact(world, "Nowhere Inn", "H"), nil)
        end)
```

In `test/test_data.lua`, insert immediately before the line `    h.describe("a real route", function()`:

```lua
    h.describe("the inn list", function()
        h.it("resolves every row for the faction that can use it", function()
            for bind in pairs(data.Inns) do
                local found = ns.Search.Exact(data, bind, "H") or ns.Search.Exact(data, bind, "A")
                h.truthy(found, bind .. " does not resolve")
            end
        end)
        h.it("only lists names Search cannot already find", function()
            local without = {}
            for k, v in pairs(data) do
                without[k] = v
            end
            without.Inns = nil
            for bind in pairs(data.Inns) do
                h.falsy(ns.Search.Exact(without, bind, nil), bind .. " already resolves; drop the row")
            end
        end)
        h.it("finds the binds met in game", function()
            h.eq(ns.Search.Exact(data, "The Crossroads", "H").nodeID, 25)
            h.eq(ns.Search.Exact(data, "Brill", "H").kind, "inn")
        end)
    end)

```

In `test/run.lua`, add the module line `    { "Inns",    "GoblinPS/Data/Inns.lua" },` directly after the `Links` line.

- [ ] **Step 3: Run the Lua tests.** Expected: failures in the two new Search tests that expect a match, and in all three inn-list data tests (`data.Inns` is nil).

- [ ] **Step 4: Change `Search.Exact` in `GoblinPS/Search.lua`.** Replace

```lua
    local best
    for _, item in ipairs(candidates(data, faction)) do
```

with

```lua
    local best
    for bind, inn in pairs(data.Inns or {}) do
        if plain(bind) == needle then
            if inn.stop then
                return Search.Exact(data, inn.stop, faction)
            end
            local c, x, y = ns.Geo.ToWorld(data.Places, inn.map, inn.mx, inn.my)
            if c then
                return { kind = "inn", name = bind, c = c, x = x, y = y, map = inn.map, mx = inn.mx, my = inn.my }
            end
        end
    end
    for _, item in ipairs(candidates(data, faction)) do
```

- [ ] **Step 5: Write `GoblinPS/Data/Inns.lua`**

```lua
-- HAND-WRITTEN. Hearthstone bind names that Search cannot find by itself.
-- GetBindLocation() returns the inn's area name. Most match a flight stop or
-- a zone once a leading "The" is ignored ("The Crossroads" -> Crossroads).
-- These do not:
--   stop = "<short flight stop name>"  the inn stands beside that flight stop
--   map, mx, my                        a town with an inn and no flight master;
--                                      map coords (0..1), APPROXIMATE until
--                                      checked from docs/manual-test-checklist.md
-- Add a row whenever the addon prints "Hearth: unknown inn (...)".
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Inns = {
    ["Grom'gol Base Camp"]     = { stop = "Grom'gol" },
    ["Theramore Isle"]         = { stop = "Theramore" },
    ["Feathermoon Stronghold"] = { stop = "Feathermoon" },

    ["Razor Hill"]        = { map = 1411, mx = 0.515, my = 0.416 }, -- Durotar
    ["Bloodhoof Village"] = { map = 1412, mx = 0.466, my = 0.611 }, -- Mulgore
    ["Brill"]             = { map = 1420, mx = 0.617, my = 0.520 }, -- Tirisfal Glades
    ["Goldshire"]         = { map = 1429, mx = 0.438, my = 0.658 }, -- Elwynn Forest
    ["Kharanos"]          = { map = 1426, mx = 0.474, my = 0.525 }, -- Dun Morogh
    ["Dolanaar"]          = { map = 1438, mx = 0.556, my = 0.598 }, -- Teldrassil
}
```

- [ ] **Step 6: Load it in the addon.** In `GoblinPS/GoblinPS.toc` add the line `Data\Inns.lua` directly after `Data\Links.lua`.

- [ ] **Step 7: Run the Lua tests.** Expected: `79 passed, 0 failed`. Run luacheck: `0 warnings / 0 errors`.

- [ ] **Step 8: Commit**

```
git add GoblinPS/Data/Inns.lua GoblinPS/Search.lua GoblinPS/GoblinPS.toc test/fake_world.lua test/test_search.lua test/test_data.lua test/run.lua
git commit -m "Add the inn list for hearthstone binds" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: `Prefs`

**Files:**
- Create: `GoblinPS/Prefs.lua`, `test/test_prefs.lua`
- Modify: `test/run.lua`

**Interfaces:**
- Produces: `ns.Prefs.Init(db) -> db` (fills `layout` = `"wide"`|`"tall"`, `recents` = list of names, `positions`, `minimap = { angle, hide }`); `Prefs.ToggleLayout(db) -> mode`; `Prefs.Remember(db, name)` (newest first, no duplicates, at most `Prefs.MAX_RECENTS` = 8); `Prefs.SavePosition(db, window, point, x, y)`; `Prefs.Position(db, window) -> { point, x, y } or nil`.

- [ ] **Step 1: Write the failing test `test/test_prefs.lua`**

```lua
return function(h, loaded)
    local Prefs = loaded.ns.Prefs

    h.describe("Prefs.Init", function()
        h.it("fills an empty table with the defaults", function()
            local db = Prefs.Init(nil)
            h.eq(db.layout, "wide")
            h.eq(#db.recents, 0)
            h.eq(db.minimap.angle, 215)
            h.eq(db.minimap.hide, false)
        end)
        h.it("keeps what the player already chose", function()
            local db = Prefs.Init({ layout = "tall", minimap = { angle = 10 } })
            h.eq(db.layout, "tall")
            h.eq(db.minimap.angle, 10)
            h.eq(db.minimap.hide, false)
        end)
        h.it("repairs a layout it does not know", function()
            h.eq(Prefs.Init({ layout = "sideways" }).layout, "wide")
        end)
        h.it("gives every table its own copy of the defaults", function()
            local a, b = Prefs.Init(nil), Prefs.Init(nil)
            a.recents[1] = "Orgrimmar"
            h.eq(#b.recents, 0)
        end)
    end)

    h.describe("Prefs.ToggleLayout", function()
        h.it("flips between wide and tall", function()
            local db = Prefs.Init(nil)
            h.eq(Prefs.ToggleLayout(db), "tall")
            h.eq(Prefs.ToggleLayout(db), "wide")
            h.eq(db.layout, "wide")
        end)
    end)

    h.describe("Prefs.Remember", function()
        h.it("puts the newest destination first", function()
            local db = Prefs.Init(nil)
            Prefs.Remember(db, "Orgrimmar")
            Prefs.Remember(db, "Undercity")
            h.eq(table.concat(db.recents, ","), "Undercity,Orgrimmar")
        end)
        h.it("moves a repeat to the front instead of listing it twice", function()
            local db = Prefs.Init(nil)
            Prefs.Remember(db, "Orgrimmar")
            Prefs.Remember(db, "Undercity")
            Prefs.Remember(db, "Orgrimmar")
            h.eq(table.concat(db.recents, ","), "Orgrimmar,Undercity")
        end)
        h.it("keeps only the newest eight", function()
            local db = Prefs.Init(nil)
            for i = 1, 10 do
                Prefs.Remember(db, "Place " .. i)
            end
            h.eq(#db.recents, Prefs.MAX_RECENTS)
            h.eq(db.recents[1], "Place 10")
            h.eq(db.recents[8], "Place 3")
        end)
        h.it("ignores an empty name", function()
            local db = Prefs.Init(nil)
            Prefs.Remember(db, "")
            Prefs.Remember(db, nil)
            h.eq(#db.recents, 0)
        end)
    end)

    h.describe("Prefs window positions", function()
        h.it("saves and returns a position per window", function()
            local db = Prefs.Init(nil)
            h.eq(Prefs.Position(db, "planner"), nil)
            Prefs.SavePosition(db, "planner", "CENTER", 12, -30)
            local p = Prefs.Position(db, "planner")
            h.eq(p.point, "CENTER")
            h.eq(p.x, 12)
            h.eq(p.y, -30)
        end)
    end)
end
```

In `test/run.lua` add the module line `    { "Prefs",   "GoblinPS/Prefs.lua" },` after the `Known` line, and the suite line `    "test/test_prefs.lua",` after `"test/test_known.lua",`.

- [ ] **Step 2: Run the Lua tests.** Expected: the ten new tests fail (`Prefs` is nil).

- [ ] **Step 3: Write `GoblinPS/Prefs.lua`**

```lua
local _, ns = ...

-- Pure: the account-wide preferences table (GoblinPSDB). Preferences, recent
-- destinations and window positions only. Known flight paths live per
-- character in GoblinPSCharDB and are owned by Known.lua.
local Prefs = {}
ns.Prefs = Prefs

Prefs.MAX_RECENTS = 8
local LAYOUTS = { wide = "tall", tall = "wide" } -- each layout's other one

-- Returns db (or a new table) with every missing preference filled in.
function Prefs.Init(db)
    db = type(db) == "table" and db or {}
    if not LAYOUTS[db.layout] then
        db.layout = "wide"
    end
    db.recents = type(db.recents) == "table" and db.recents or {}
    db.positions = type(db.positions) == "table" and db.positions or {}
    db.minimap = type(db.minimap) == "table" and db.minimap or {}
    if type(db.minimap.angle) ~= "number" then
        db.minimap.angle = 215
    end
    db.minimap.hide = db.minimap.hide == true
    return db
end

function Prefs.ToggleLayout(db)
    db.layout = LAYOUTS[db.layout] or "wide"
    return db.layout
end

-- Newest first, no duplicates, capped.
function Prefs.Remember(db, name)
    if not name or name == "" then
        return
    end
    for i = #db.recents, 1, -1 do
        if db.recents[i] == name then
            table.remove(db.recents, i)
        end
    end
    table.insert(db.recents, 1, name)
    while #db.recents > Prefs.MAX_RECENTS do
        table.remove(db.recents)
    end
end

function Prefs.SavePosition(db, window, point, x, y)
    db.positions[window] = { point = point, x = x, y = y }
end

function Prefs.Position(db, window)
    return db.positions[window]
end

return Prefs
```

- [ ] **Step 4: Run the Lua tests.** Expected: `89 passed, 0 failed`. luacheck clean.

- [ ] **Step 5: Commit** (the TOC gets `Prefs.lua` in Task 5, with the rest of the window)

```
git add GoblinPS/Prefs.lua test/test_prefs.lua test/run.lua
git commit -m "Add the preferences module" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: The icon

**Files:**
- Create: `tools/make_icon.py`, `GoblinPS/Media/icon.tga` (generated, committed)

**Interfaces:**
- Produces: the texture path `Interface\AddOns\GoblinPS\Media\icon` (256x256 RGBA TGA, round alpha mask) used by the TOC, the minimap button and the self-test. If `images/icon-source.png` exists it is used; otherwise a placeholder is drawn. Art can arrive later without touching code.

- [ ] **Step 1: Write `tools/make_icon.py`**

```python
#!/usr/bin/env python3
"""Build GoblinPS/Media/icon.tga (256x256 RGBA, round).

If images/icon-source.png exists (square art, any size: from an artist or an
image generator) it is used. Otherwise a placeholder is drawn: a brass dial
with a green screen and an amber route, so the addon always has an icon.
Run from anywhere: python tools/make_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "images" / "icon-source.png"
DEST = ROOT / "GoblinPS" / "Media" / "icon.tga"
SIZE = 256

BRASS, STEEL, SCREEN, GREEN, AMBER = (184, 134, 59), (29, 26, 20), (8, 30, 16), (112, 224, 138), (240, 182, 74)


def placeholder() -> Image.Image:
    big = SIZE * 4  # draw large, shrink for smooth edges
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, big - 1, big - 1), fill=BRASS)
    d.ellipse((big * 0.04, big * 0.04, big * 0.96, big * 0.96), outline=STEEL, width=big // 40)
    d.ellipse((big * 0.14, big * 0.14, big * 0.86, big * 0.86), fill=SCREEN, outline=STEEL, width=big // 50)
    route = [(0.30, 0.68), (0.44, 0.52), (0.58, 0.58), (0.70, 0.34)]
    d.line([(x * big, y * big) for x, y in route], fill=AMBER, width=big // 22, joint="curve")
    for x, y in route[:-1]:
        r = big * 0.035
        d.ellipse((x * big - r, y * big - r, x * big + r, y * big + r), fill=GREEN)
    x, y = route[-1]
    r = big * 0.06
    d.ellipse((x * big - r, y * big - r, x * big + r, y * big + r), fill=AMBER, outline=STEEL, width=big // 80)
    return im.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> int:
    if SOURCE.is_file():
        im = Image.open(SOURCE).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)
        print("using", SOURCE)
    else:
        im = placeholder()
        print("no", SOURCE, "- drawing the placeholder")
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse((2, 2, SIZE - 3, SIZE - 3), fill=255)
    im.putalpha(mask)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    im.save(DEST)
    print("wrote", DEST)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 2: Run it.** `python tools/make_icon.py`. Expected: `no ...icon-source.png - drawing the placeholder` then `wrote ...GoblinPS\Media\icon.tga`.

- [ ] **Step 3: Check the file.** `python -c "from PIL import Image; im=Image.open('GoblinPS/Media/icon.tga'); print(im.size, im.mode)"` prints `(256, 256) RGBA`.

- [ ] **Step 4: Commit**

```
git add tools/make_icon.py GoblinPS/Media/icon.tga
git commit -m "Add the icon tool and a placeholder icon" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: The window

One task because the pieces only run together: `Core` wires the planner, the minimap button and the self-test, and one smoke suite covers them all.

**Files:**
- Create: `GoblinPS/Widgets.lua`, `GoblinPS/Planner.lua`, `GoblinPS/MinimapButton.lua`, `GoblinPS/SelfTest.lua`, `test/fake_frames.lua`, `test/test_ui.lua`
- Replace: `GoblinPS/Core.lua`, `GoblinPS/GoblinPS.toc`, `test/run.lua`, `.luacheckrc`, `.luarc.json`
- Modify: `GoblinPS/API.lua`

**Interfaces:**
- Consumes: everything from Tasks 1-4 and plan 1.
- Produces:
  - `ns.API.SetWaypoint(map, x, y) -> bool`, `ns.API.OnLogin(callback)`, `ns.API.SelfCheck() -> { { name, present }, ... }`
  - `ns.Core.PlanRoute(to, from) -> { to, notes = { ... }, result = Route result or nil, hint = Route hint or nil }` (`from` nil means where the player stands), `ns.Core.Go(plan)`, and small accessors: `KnownCount`, `Faction`, `Recents`, `Remember`, `Layout`, `ToggleLayout`, `Position`, `SavePosition`, `MinimapPrefs`, `CloseOnEscape(frame, globalName)`, `Say`
  - `ns.Planner.Toggle()`, `ns.Planner.Replan()`, `ns.Planner.ApplyLayout(mode)`, `ns.Planner.Refresh()`, `ns.Planner.Debug() -> ui, state` (tests only)
  - `ns.MinimapButton.Initialize()`, `ns.MinimapButton.SetHidden(bool)`; `ns.SelfTest.Run(say) -> bool`
  - global `GoblinPS_OnAddonCompartmentClick`, saved variables `GoblinPSDB` (account) and `GoblinPSCharDB` (character)
  - slash: `/gps` opens the planner; `/gps to <place>`, `/gps minimap`, `/gps probe`, `/gps selftest`

- [ ] **Step 1: Write the fake frame library `test/fake_frames.lua`**

```lua
-- A tiny stand-in for the WoW frame API, enough to build the GoblinPS windows
-- on the desktop and poke at them. It proves OUR code paths run (no nil
-- calls, no bad field names, the right text lands in the right widget). It
-- proves nothing about how Blizzard's real frames behave: that is what
-- docs/manual-test-checklist.md is for.
local Fake = {}

local Region = {}
Region.__index = function(_, key)
    return Region[key] or function() end -- any method we did not model is a no-op
end

local function new(kind, parent)
    return setmetatable({ kind = kind, parent = parent, shown = true, text = "", scripts = {}, points = {},
                          width = 0, height = 0 }, Region)
end

function Region:CreateTexture() return new("Texture", self) end
function Region:CreateFontString() return new("FontString", self) end
function Region:SetText(text) self.text = text or "" end
function Region:GetText() return self.text end
function Region:Show() self.shown = true end
function Region:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Region:SetShown(shown) self.shown = shown and true or false end
function Region:IsShown() return self.shown end
function Region:SetScript(name, fn) self.scripts[name] = fn end
function Region:GetScript(name) return self.scripts[name] end
function Region:SetSize(w, h) self.width, self.height = w, h end
function Region:SetWidth(w) self.width = w end
function Region:SetHeight(h) self.height = h end
function Region:GetWidth() return self.width end
function Region:GetHeight() return self.height end
function Region:ClearAllPoints() self.points = {} end
function Region:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Region:GetPoint(i)
    local p = self.points[i or 1] or { "CENTER", nil, "CENTER", 0, 0 }
    return p[1], p[2], p[3], p[4] or 0, p[5] or 0
end
function Region:SetEnabled(enabled) self.enabled = enabled end
function Region:SetTexture(path) self.texture = path end
function Region:GetTexture() return self.texture end
function Region:GetCenter() return 100, 100 end
function Region:GetEffectiveScale() return 1 end
function Region:ClearFocus()
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end

-- Test helpers: act like the player.
function Fake.Type(editBox, text)
    editBox:SetText(text)
    editBox.scripts.OnTextChanged(editBox, true)
end
function Fake.Click(button)
    button.scripts.OnClick(button, "LeftButton")
end

-- Installs the globals the UI files use. Returns a table of what was printed.
function Fake.Install()
    local printed = {}
    _G.CreateFrame = function(kind, name, parent)
        local f = new(kind, parent)
        if name then _G[name] = f end
        return f
    end
    _G.UIParent = new("Frame")
    _G.Minimap = new("Frame")
    _G.Minimap.width = 140
    _G.GameTooltip = new("GameTooltip")
    _G.UISpecialFrames = {}
    _G.GetCursorPosition = function() return 150, 100 end
    _G.SlashCmdList = {}
    _G.print = function(text) printed[#printed + 1] = text end
    return printed
end

return Fake
```

- [ ] **Step 2: Write the failing smoke test `test/test_ui.lua`**

```lua
-- Smoke test of the window code against test/fake_frames.lua. It catches our
-- own mistakes (nil calls, wrong fields, text in the wrong widget). Real frame
-- behaviour is checked in game from docs/manual-test-checklist.md.
return function(h)
    local Fake = dofile("test/fake_frames.lua")
    local realPrint = print
    local printed = Fake.Install()

    -- A private addon namespace over the fake world, with a scripted API.
    local ns = { Data = dofile("test/fake_world.lua")() }
    local where = { map = 1, mx = 0.89, my = 0.9 } -- world 1000, 1100: beside Alpha
    local pins, loginCallbacks = {}, {}
    ns.API = {
        Faction = function() return "H" end,
        PlayerMapPosition = function() return where.map, where.mx, where.my end,
        HearthBindName = function() return nil end,
        TaxiNodes = function() return {} end,
        OpenTaxiNodes = function() return {} end,
        OnTaxiMapOpened = function() end,
        OnLogin = function(callback) loginCallbacks[#loginCallbacks + 1] = callback end,
        SetWaypoint = function(map, x, y)
            pins[#pins + 1] = { map, x, y }
            return true
        end,
        SelfCheck = function() return { { name = "Fake.API", present = true } } end,
    }
    for _, file in ipairs({ "Geo", "Search", "Graph", "Route", "Trip", "Known", "Prefs",
                            "Widgets", "Planner", "MinimapButton", "SelfTest", "Core" }) do
        assert(loadfile("GoblinPS/" .. file .. ".lua"))("GoblinPS", ns)
    end
    GoblinPSDB, GoblinPSCharDB = nil, { known = { [1] = true, [2] = true, [4] = true } }

    local Planner = ns.Planner

    h.describe("the planner window", function()
        h.it("opens from the slash command with both layouts' widgets built once", function()
            SlashCmdList.GOBLINPS("")
            local ui = Planner.Debug()
            h.truthy(ui.frame:IsShown())
            h.eq(ui.frame:GetWidth(), Planner.SIZE.wide[1])
            h.eq(ui.known:GetText(), "Flight paths known: 3")
            h.eq(UISpecialFrames[1], "GoblinPSPlanner")
        end)

        h.it("offers matches as you type and plans when you pick one", function()
            local ui, state = Planner.Debug()
            Fake.Type(ui.toBox, "delt")
            h.truthy(ui.results:IsShown())
            h.eq(ui.results.rows[1].label:GetText(), "Delta  (flight stop)")
            Fake.Click(ui.results.rows[1])
            h.falsy(ui.results:IsShown())
            h.eq(state.to.nodeID, 4)
            h.eq(ui.toBox:GetText(), "Delta")
            h.eq(ui.rows[1].left:GetText(), "1. Ride to Alpha")
            h.eq(ui.rows[2].left:GetText(), "2. Fly to Bravo")
            h.eq(ui.rows[2].right:GetText(), "~4 min  1s")
            h.eq(ui.rows[4].left:GetText(), "4. Zeppelin to East Dock (~4 min incl. wait)")
            h.eq(ui.rows[5].left:GetText(), "5. Ride to Delta")
            h.eq(ui.rows[6].left:GetText(), "")
            h.eq(ui.total:GetText(), "~10 min  1s")
            h.truthy(ui.go.enabled)
        end)

        h.it("remembers the destination and offers it when the box is empty", function()
            local ui = Planner.Debug()
            h.eq(GoblinPSDB.recents[1], "Delta")
            Fake.Type(ui.toBox, "")
            h.eq(ui.results.rows[1].label:GetText(), "Delta  (flight stop)")
        end)

        h.it("plans from another place", function()
            local ui, state = Planner.Debug()
            Fake.Type(ui.fromBox, "brav")
            Fake.Click(ui.results.rows[1])
            h.eq(state.from.nodeID, 2)
            h.eq(ui.rows[1].left:GetText(), "1. Ride to West Dock")
        end)

        h.it("GO drops a pin on the first step", function()
            local ui = Planner.Debug()
            Fake.Click(ui.go)
            h.eq(#pins, 1)
            h.eq(pins[1][1], 1)
            h.truthy(printed[#printed]:find("Pin set: Ride to West Dock", 1, true))
        end)

        h.it("switches layout with one set of widgets and saves the choice", function()
            local ui = Planner.Debug()
            local rowsBefore = ui.rows
            Fake.Click(ui.layoutButton)
            h.eq(ui.frame:GetWidth(), Planner.SIZE.tall[1])
            h.eq(ui.frame:GetHeight(), Planner.SIZE.tall[2])
            h.eq(GoblinPSDB.layout, "tall")
            h.eq(ui.layoutButton.label:GetText(), "Wide")
            h.truthy(ui.rows == rowsBefore, "the same row widgets")
            h.eq(ui.rows[1].left:GetText(), "1. Ride to West Dock")
        end)

        h.it("Here plans from where you stand again", function()
            local ui, state = Planner.Debug()
            Fake.Click(ui.here)
            h.eq(state.from, nil)
            h.eq(ui.fromBox:GetText(), "")
            h.eq(ui.rows[1].left:GetText(), "1. Ride to Alpha")
        end)

        h.it("explains itself when it cannot tell where you are", function()
            local ui = Planner.Debug()
            where.map = nil
            Fake.Click(ui.here)
            h.eq(ui.rows[1].left:GetText(), "")
            h.eq(ui.total:GetText(), "Can't tell where you are. Inside an instance?")
            h.falsy(ui.go.enabled)
            where.map = 1
            Fake.Click(ui.here)
            h.truthy(ui.go.enabled)
        end)

        h.it("closes and reopens without rebuilding", function()
            local ui = Planner.Debug()
            SlashCmdList.GOBLINPS("")
            h.falsy(ui.frame:IsShown())
            SlashCmdList.GOBLINPS("")
            h.truthy(ui.frame:IsShown())
            h.truthy(Planner.Debug() == ui)
        end)
    end)

    h.describe("the minimap button and the compartment", function()
        h.it("appears at login at the saved angle, and hides on request", function()
            h.eq(#loginCallbacks, 1)
            loginCallbacks[1]()
            h.truthy(GoblinPSMinimapButton:IsShown())
            SlashCmdList.GOBLINPS("minimap")
            h.falsy(GoblinPSMinimapButton:IsShown())
            h.eq(GoblinPSDB.minimap.hide, true)
            SlashCmdList.GOBLINPS("minimap")
            h.truthy(GoblinPSMinimapButton:IsShown())
        end)
        h.it("dragging stores the angle from the cursor", function()
            GoblinPSMinimapButton.scripts.OnDragStart(GoblinPSMinimapButton)
            GoblinPSMinimapButton.scripts.OnUpdate(GoblinPSMinimapButton)
            GoblinPSMinimapButton.scripts.OnDragStop(GoblinPSMinimapButton)
            h.eq(GoblinPSDB.minimap.angle, 0) -- cursor is due east of the fake minimap's centre
        end)
        h.it("the compartment entry toggles the planner", function()
            local ui = Planner.Debug()
            local before = ui.frame:IsShown()
            GoblinPS_OnAddonCompartmentClick()
            h.eq(ui.frame:IsShown(), not before)
        end)
    end)

    h.describe("/gps selftest", function()
        h.it("reports every check and the verdict", function()
            local from = #printed
            SlashCmdList.GOBLINPS("selftest")
            h.truthy(#printed - from >= 5)
            h.truthy(printed[#printed]:find("Self%-test"))
        end)
    end)

    h.describe("/gps to still prints a route in chat", function()
        h.it("uses the same planner as the window", function()
            local from = #printed
            SlashCmdList.GOBLINPS("to delta")
            h.truthy(printed[from + 1]:find("To Delta: ~10 min, 1s", 1, true))
            h.truthy(printed[from + 2]:find("1. Ride to Alpha", 1, true))
        end)
    end)

    print = realPrint
end
```

- [ ] **Step 3: Replace `test/run.lua`**

```lua
-- Run from the repository root through lupa (see CLAUDE.md).
local harness = dofile("test/harness.lua")

-- Same (addonName, ns) the client passes, loaded in TOC order into one ns.
-- API.lua and Core.lua touch Blizzard globals, so they are not loaded here.
local modules = {
    { "Geo",     "GoblinPS/Geo.lua" },
    { "Places",  "GoblinPS/Data/Places.lua" },
    { "Nodes",   "GoblinPS/Data/Nodes.lua" },
    { "Flights", "GoblinPS/Data/Flights.lua" },
    { "Links",   "GoblinPS/Data/Links.lua" },
    { "Inns",    "GoblinPS/Data/Inns.lua" },
    { "Search",  "GoblinPS/Search.lua" },
    { "Graph",   "GoblinPS/Graph.lua" },
    { "Route",   "GoblinPS/Route.lua" },
    { "Trip",    "GoblinPS/Trip.lua" },
    { "Known",   "GoblinPS/Known.lua" },
    { "Prefs",   "GoblinPS/Prefs.lua" },
}

local ns = {}
local loaded = { ns = ns }
for i = 1, #modules do
    local name, path = modules[i][1], modules[i][2]
    local f = io.open(path, "r")
    if f then
        f:close()
        loaded[name] = assert(loadfile(path))("GoblinPS", ns)
    end
end

local suites = {
    "test/test_geo.lua",
    "test/test_search.lua",
    "test/test_graph.lua",
    "test/test_route.lua",
    "test/test_trip.lua",
    "test/test_known.lua",
    "test/test_prefs.lua",
    "test/test_ui.lua",
    "test/test_data.lua",
}

for i = 1, #suites do
    local f = io.open(suites[i], "r")
    if f then
        f:close()
        dofile(suites[i])(harness, loaded)
    end
end

os.exit(harness.run())
```

- [ ] **Step 4: Run the Lua tests.** Expected: an error from `test/test_ui.lua` while loading (`GoblinPS/Widgets.lua` does not exist). That is the RED.

- [ ] **Step 5: Add three functions to `GoblinPS/API.lua`.** Insert this block immediately before the comment line `-- Calls back every time a flight master's map opens.`:

```lua
-- Blizzard's own map pin plus the on-screen arrow. False when this client or
-- this map cannot take a pin.
function API.SetWaypoint(map, x, y)
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end
    if not (map and x and y) or (C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(map)) then
        return false
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    return true
end

-- Calls back once, when the character is in the world and saved variables
-- have loaded.
function API.OnLogin(callback)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN") -- verified in the forever source
    frame:SetScript("OnEvent", callback)
end

```

And replace the final line `return API` with:

```lua
-- For /gps selftest: every client API this file leans on, and whether it is
-- there. { { name, present }, ... }
function API.SelfCheck()
    local checks = {
        { "C_TaxiMap.GetAllTaxiNodes", C_TaxiMap and C_TaxiMap.GetAllTaxiNodes },
        { "C_TaxiMap.GetTaxiNodesForMap", C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap },
        { "Enum.FlightPathState", Enum and Enum.FlightPathState },
        { "C_Map.GetBestMapForUnit", C_Map and C_Map.GetBestMapForUnit },
        { "C_Map.GetPlayerMapPosition", C_Map and C_Map.GetPlayerMapPosition },
        { "C_Map.SetUserWaypoint", C_Map and C_Map.SetUserWaypoint },
        { "UiMapPoint.CreateFromCoordinates", UiMapPoint and UiMapPoint.CreateFromCoordinates },
        { "C_SuperTrack.SetSuperTrackedUserWaypoint", C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint },
        { "C_Item.GetItemCooldown", C_Item and C_Item.GetItemCooldown },
        { "GetBindLocation", GetBindLocation },
        { "UnitFactionGroup", UnitFactionGroup },
    }
    local out = {}
    for i, check in ipairs(checks) do
        out[i] = { name = check[1], present = check[2] ~= nil and check[2] ~= false }
    end
    return out
end

return API
```

- [ ] **Step 6: Write `GoblinPS/Widgets.lua`**

```lua
local _, ns = ...

-- Plain controls in the Goblin Gadget palette. No Blizzard frame templates on
-- purpose: a template renamed by a beta patch cannot break the window. Art
-- textures, when they exist, are laid over these flat colours; a missing
-- texture just leaves the colour showing.
local Widgets = {}
ns.Widgets = Widgets

Widgets.COLOR = {
    brass  = { 0.72, 0.53, 0.23 },
    body   = { 0.23, 0.18, 0.11 },
    steel  = { 0.11, 0.10, 0.08 },
    screen = { 0.03, 0.12, 0.06 },
    green  = { 0.44, 0.88, 0.54 },
    amber  = { 0.94, 0.71, 0.29 },
    hazard = { 0.88, 0.44, 0.11 },
    dim    = { 0.61, 0.56, 0.43 },
}

local function rgb(name)
    local c = Widgets.COLOR[name] or Widgets.COLOR.dim
    return c[1], c[2], c[3]
end

-- A flat colour filling the whole frame.
function Widgets.Fill(frame, layer, color, alpha)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(frame)
    local r, g, b = rgb(color)
    t:SetColorTexture(r, g, b, alpha or 1)
    return t
end

-- A frame with a one-pixel-style border: an outer fill and an inset fill.
function Widgets.Panel(parent, fill, border, inset)
    local f = CreateFrame("Frame", nil, parent)
    Widgets.Fill(f, "BACKGROUND", border or "steel")
    local inner = f:CreateTexture(nil, "BORDER")
    inner:SetPoint("TOPLEFT", inset or 2, -(inset or 2))
    inner:SetPoint("BOTTOMRIGHT", -(inset or 2), inset or 2)
    local r, g, b = rgb(fill)
    inner:SetColorTexture(r, g, b, 1)
    return f
end

function Widgets.Text(parent, color, fontObject, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
    fs:SetTextColor(rgb(color or "green"))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

function Widgets.Button(parent, text, width, height, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    Widgets.Fill(b, "BACKGROUND", "steel")
    local face = b:CreateTexture(nil, "BORDER")
    face:SetPoint("TOPLEFT", 1, -1)
    face:SetPoint("BOTTOMRIGHT", -1, 1)
    face:SetColorTexture(rgb("brass"))
    b.face = face
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(face)
    hover:SetColorTexture(1, 1, 1, 0.18)
    b.label = Widgets.Text(b, "steel", "GameFontNormalSmall", "CENTER")
    b.label:SetPoint("CENTER")
    b.label:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- Buttons go grey and stop answering clicks; SetEnabled exists on Button.
function Widgets.SetButtonEnabled(button, enabled)
    button:SetEnabled(enabled)
    local r, g, b = rgb(enabled and "brass" or "dim")
    button.face:SetColorTexture(r, g, b, 1)
end

function Widgets.EditBox(parent, width, height, placeholder)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width, height)
    e:SetAutoFocus(false)
    e:SetFontObject("GameFontHighlightSmall")
    e:SetTextInsets(6, 6, 0, 0)
    e:SetMaxLetters(60)
    Widgets.Fill(e, "BACKGROUND", "brass")
    local inner = e:CreateTexture(nil, "BORDER")
    inner:SetPoint("TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", -1, 1)
    inner:SetColorTexture(rgb("steel"))
    e.placeholder = Widgets.Text(e, "dim", "GameFontDisableSmall")
    e.placeholder:SetPoint("LEFT", 6, 0)
    e.placeholder:SetText(placeholder or "")
    e:SetScript("OnEscapePressed", e.ClearFocus)
    return e
end

-- Show the grey hint only while the box is empty.
function Widgets.UpdatePlaceholder(editBox)
    editBox.placeholder:SetShown(editBox:GetText() == "")
end

return Widgets
```

- [ ] **Step 7: Write `GoblinPS/Planner.lua`**

```lua
local _, ns = ...

-- The big device: From and To boxes, the green screen, the step list, the
-- total, the hint and Go. One set of widgets; ApplyLayout only moves them.
-- The schematic map and the dash unit arrive in later plans: for now the
-- screen shows what the device knows, and Go drops Blizzard's map pin on
-- the first step.
local Planner = {}
ns.Planner = Planner

local W = ns.Widgets

Planner.SIZE = { wide = { 660, 400 }, tall = { 390, 600 } }
Planner.MAX_ROWS = 12
Planner.MAX_RESULTS = 8
local PAD, HEADER, INPUTS, FOOTER, ROW = 10, 30, 26, 64, 18

local ui          -- built on first open
local state = {}  -- from = place or nil ("where you stand"), to = place, plan = Core.PlanRoute's answer

local function stepLine(i, step)
    local cost = ns.Route.FormatTime(step.seconds)
    if step.copper > 0 then
        cost = cost .. "  " .. ns.Route.FormatMoney(step.copper)
    end
    return i .. ". " .. ns.Route.StepText(step), cost
end

-- Paint whatever state.plan holds.
function Planner.Refresh()
    if not ui then
        return
    end
    local plan = state.plan
    local steps = plan and plan.result and plan.result.steps or {}
    for i = 1, Planner.MAX_ROWS do
        local row, step = ui.rows[i], steps[i]
        local left, right = "", ""
        if step and i == Planner.MAX_ROWS and #steps > Planner.MAX_ROWS then
            left = "... and " .. (#steps - i + 1) .. " more steps"
        elseif step then
            left, right = stepLine(i, step)
        end
        row.left:SetText(left)
        row.right:SetText(right)
    end

    local total, hint = "", ""
    if plan and #steps > 0 then
        total = ns.Route.FormatTime(plan.result.seconds) .. "  " .. ns.Route.FormatMoney(plan.result.copper)
    elseif plan then
        total = plan.notes[#plan.notes] or ""
    end
    if plan and plan.hint then
        hint = ns.Route.HintText(plan.hint)
    end
    ui.total:SetText(total)
    ui.hint:SetText(hint)
    W.SetButtonEnabled(ui.go, #steps > 0)

    local known = ns.Core.KnownCount()
    ui.known:SetText(known == 0 and "No flight paths learned yet. Open a flight master's map."
        or ("Flight paths known: " .. known))
end

local function replan()
    state.plan = state.to and ns.Core.PlanRoute(state.to, state.from) or nil
    Planner.Refresh()
end

-- ---- the results list under whichever box has focus ----

local function hideResults()
    ui.results:Hide()
    ui.results.owner = nil
end

local function pick(box, item)
    hideResults()
    if box == ui.toBox then
        state.to = item
        ns.Core.Remember(item.name)
    else
        state.from = item
    end
    box:SetText(item.name)
    box:ClearFocus()
    W.UpdatePlaceholder(box)
    replan()
end

-- Matches for the text; with an empty To box, the recent destinations.
local function candidatesFor(box)
    local text = box:GetText()
    if text ~= "" then
        return ns.Search.Find(ns.Data, text, ns.Core.Faction(), Planner.MAX_RESULTS)
    end
    local out = {}
    if box == ui.toBox then
        for _, name in ipairs(ns.Core.Recents()) do
            out[#out + 1] = ns.Search.Exact(ns.Data, name, ns.Core.Faction())
        end
    end
    return out
end

local function showResults(box)
    local items = candidatesFor(box)
    if #items == 0 then
        hideResults()
        return
    end
    for i = 1, Planner.MAX_RESULTS do
        local row, item = ui.results.rows[i], items[i]
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            row.label:SetText(item.name .. (item.kind == "zone" and "" or "  (flight stop)"))
        end
    end
    ui.results.owner = box
    ui.results:ClearAllPoints()
    ui.results:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
    ui.results:SetSize(box:GetWidth(), math.min(#items, Planner.MAX_RESULTS) * ROW + 4)
    ui.results:Show()
end

local function wireBox(box)
    box:SetScript("OnTextChanged", function(self, userInput)
        W.UpdatePlaceholder(self)
        if userInput then
            showResults(self)
        end
    end)
    box:SetScript("OnEditFocusGained", showResults)
    box:SetScript("OnEnterPressed", function(self)
        local first = candidatesFor(self)[1]
        if first then
            pick(self, first)
        else
            self:ClearFocus()
        end
    end)
    box:SetScript("OnEscapePressed", function(self)
        hideResults()
        self:ClearFocus()
    end)
end

-- ---- layout: the only thing that differs between wide and tall ----

function Planner.ApplyLayout(mode)
    if not ui then
        return
    end
    local size = Planner.SIZE[mode] or Planner.SIZE.wide
    local f = ui.frame
    f:SetSize(size[1], size[2])

    ui.screen:ClearAllPoints()
    ui.side:ClearAllPoints()
    local top = -(HEADER + INPUTS + PAD)
    if mode == "tall" then
        ui.screen:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, top)
        ui.screen:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, top)
        ui.screen:SetHeight(190)
        ui.side:SetPoint("TOPLEFT", ui.screen, "BOTTOMLEFT", 0, -PAD)
        ui.side:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
    else
        ui.screen:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, top)
        ui.screen:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD)
        ui.screen:SetWidth(math.floor(size[1] * 0.56))
        ui.side:SetPoint("TOPLEFT", ui.screen, "TOPRIGHT", PAD, 0)
        ui.side:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
    end
    ui.layoutButton.label:SetText(mode == "tall" and "Wide" or "Tall")
end

-- ---- construction ----

local function build()
    local f = W.Panel(UIParent, "body", "brass", 3)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        ns.Core.SavePosition("planner", point, x, y)
    end)
    f:Hide()

    local stripe = f:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", 3, -3)
    stripe:SetPoint("TOPRIGHT", -3, -3)
    stripe:SetHeight(4)
    stripe:SetColorTexture(W.COLOR.hazard[1], W.COLOR.hazard[2], W.COLOR.hazard[3], 1)

    local title = W.Text(f, "amber", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, -11)
    title:SetText("GoblinPS")
    local tagline = W.Text(f, "dim", "GameFontDisableSmall")
    tagline:SetPoint("LEFT", title, "RIGHT", 8, -1)
    tagline:SetText("Accuracy not guaranteed. No refunds.")

    local close = W.Button(f, "X", 20, 18, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", -PAD, -10)
    local layoutButton = W.Button(f, "Tall", 44, 18, function()
        Planner.ApplyLayout(ns.Core.ToggleLayout())
    end)
    layoutButton:SetPoint("RIGHT", close, "LEFT", -6, 0)

    local fromBox = W.EditBox(f, 150, 20, "From: where you stand")
    fromBox:SetPoint("TOPLEFT", PAD, -(HEADER + 4))
    local toBox = W.EditBox(f, 170, 20, "To: city, zone or flight stop")
    toBox:SetPoint("LEFT", fromBox, "RIGHT", 6, 0)
    local here = W.Button(f, "Here", 40, 20, function()
        state.from = nil
        ui.fromBox:SetText("")
        W.UpdatePlaceholder(ui.fromBox)
        replan()
    end)
    here:SetPoint("LEFT", toBox, "RIGHT", 6, 0)

    local screen = W.Panel(f, "screen", "steel", 2)
    local known = W.Text(screen, "green")
    known:SetPoint("BOTTOMLEFT", 8, 8)
    known:SetPoint("BOTTOMRIGHT", -8, 8)
    local device = W.Text(screen, "green", "GameFontNormalHuge", "CENTER")
    device:SetPoint("CENTER")
    device:SetText("GoblinPS")
    device:SetAlpha(0.25)

    local side = W.Panel(f, "steel", "steel", 1)
    local rows = {}
    for i = 1, Planner.MAX_ROWS do
        local row = { left = W.Text(side, "green"), right = W.Text(side, "dim", nil, "RIGHT") }
        row.left:SetPoint("TOPLEFT", 8, -(6 + (i - 1) * ROW))
        row.right:SetPoint("TOPRIGHT", -8, -(6 + (i - 1) * ROW))
        row.left:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
        rows[i] = row
    end
    local hint = W.Text(side, "amber")
    hint:SetPoint("BOTTOMLEFT", 8, FOOTER - 18)
    hint:SetPoint("BOTTOMRIGHT", -8, FOOTER - 18)
    local total = W.Text(side, "green", "GameFontNormal")
    total:SetPoint("BOTTOMLEFT", 8, 12)
    local go = W.Button(side, "GO", 56, 24, function() ns.Core.Go(state.plan) end)
    go:SetPoint("BOTTOMRIGHT", -8, 8)

    local results = W.Panel(f, "steel", "brass", 1)
    results:SetFrameStrata("DIALOG")
    results:Hide()
    results.rows = {}
    for i = 1, Planner.MAX_RESULTS do
        local row = CreateFrame("Button", nil, results)
        row:SetHeight(ROW)
        row:SetPoint("TOPLEFT", 2, -(2 + (i - 1) * ROW))
        row:SetPoint("TOPRIGHT", -2, -(2 + (i - 1) * ROW))
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(row)
        hover:SetColorTexture(1, 1, 1, 0.15)
        row.label = W.Text(row, "green")
        row.label:SetPoint("LEFT", 6, 0)
        row.label:SetPoint("RIGHT", -6, 0)
        row:SetScript("OnClick", function(self) pick(results.owner, self.item) end)
        results.rows[i] = row
    end

    ui = { frame = f, fromBox = fromBox, toBox = toBox, screen = screen, side = side, rows = rows,
           hint = hint, total = total, go = go, here = here, known = known, results = results,
           layoutButton = layoutButton }
    wireBox(fromBox)
    wireBox(toBox)
    f:SetScript("OnHide", hideResults)
    ns.Core.CloseOnEscape(f, "GoblinPSPlanner")
end

function Planner.Toggle()
    if not ui then
        build()
        local p = ns.Core.Position("planner")
        ui.frame:ClearAllPoints()
        if p then
            ui.frame:SetPoint(p.point, UIParent, p.point, p.x, p.y)
        else
            ui.frame:SetPoint("CENTER")
        end
        Planner.ApplyLayout(ns.Core.Layout())
    end
    if ui.frame:IsShown() then
        ui.frame:Hide()
    else
        ui.frame:Show()
        replan()
    end
end

-- Called when something the route depends on changed (a flight path learned).
function Planner.Replan()
    if ui and ui.frame:IsShown() then
        replan()
    end
end

-- For the desktop smoke test only.
function Planner.Debug()
    return ui, state
end

return Planner
```

- [ ] **Step 8: Write `GoblinPS/MinimapButton.lua`**

```lua
local _, ns = ...

-- A draggable button on the minimap's ring; click opens the planner. Hand
-- rolled like HealMe's (no LibDBIcon). The angle and the hidden flag live in
-- the account-wide preferences.
local MinimapButton = {}
ns.MinimapButton = MinimapButton

local ICON = "Interface\\AddOns\\GoblinPS\\Media\\icon"

local button

-- From the minimap's real size: a fixed radius of 80 is right only for the
-- default 140px minimap and lands inside a resized one.
local function ringRadius()
    local width = Minimap:GetWidth()
    if not width or width <= 0 then
        width = 140
    end
    return (width / 2) + 10
end

local function place()
    if not button then
        return
    end
    local angle = math.rad(ns.Core.MinimapPrefs().angle)
    local radius = ringRadius()
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function angleFromCursor()
    local mx, my = Minimap:GetCenter()
    if not mx then
        return nil
    end
    local scale = Minimap:GetEffectiveScale()
    local px, py = GetCursorPosition()
    return math.deg(math.atan2(py / scale - my, px / scale - mx))
end

local function whileDragging()
    local angle = angleFromCursor()
    if angle then
        ns.Core.MinimapPrefs().angle = angle
        place()
    end
end

local function showTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("GoblinPS")
    GameTooltip:AddLine("Click to open the planner.", 1, 1, 1)
    GameTooltip:AddLine("Drag to move this button.", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("May explode.", 0.88, 0.44, 0.11)
    GameTooltip:Show()
end

local function build()
    local b = CreateFrame("Button", "GoblinPSMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- trim so a square icon reads as round in the ring

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    b:SetScript("OnClick", function() ns.Planner.Toggle() end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", whileDragging)
        GameTooltip:Hide()
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", showTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Call once at PLAYER_LOGIN, when the minimap and saved variables exist.
function MinimapButton.Initialize()
    if button or not Minimap then
        return
    end
    button = build()
    place()
    button:SetShown(not ns.Core.MinimapPrefs().hide)

    -- The minimap can be resized in Edit Mode or by a UI scale change.
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:SetScript("OnEvent", place)
end

function MinimapButton.SetHidden(hidden)
    ns.Core.MinimapPrefs().hide = hidden and true or false
    if button then
        button:SetShown(not hidden)
    end
end

return MinimapButton
```

- [ ] **Step 9: Write `GoblinPS/SelfTest.lua`**

```lua
local _, ns = ...

-- /gps selftest: checks, in the real client, the few things the window leans
-- on that a beta patch could take away. The window uses no Blizzard frame
-- templates, so this is fonts, stock textures, our own art and the APIs
-- (API.SelfCheck lists those, since only API.lua touches game APIs).
local SelfTest = {}
ns.SelfTest = SelfTest

SelfTest.FONTS = {
    "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge", "GameFontNormalHuge",
    "GameFontHighlightSmall", "GameFontDisableSmall",
}
SelfTest.TEXTURES = {
    "Interface\\AddOns\\GoblinPS\\Media\\icon",
    "Interface\\Minimap\\MiniMap-TrackingBorder",
    "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
}
local COLOUR = { pass = "|cff6fe08aok|r  ", fail = "|cffe0501cFAIL|r" }

-- A texture that failed to load reports no file; GetTexture is nil then.
local function textureLoads(probe, path)
    probe:SetTexture(nil)
    probe:SetTexture(path)
    return probe:GetTexture() ~= nil
end

function SelfTest.Run(say)
    local failed = 0
    local function report(ok, text)
        if not ok then
            failed = failed + 1
        end
        say(COLOUR[ok and "pass" or "fail"] .. " " .. text)
    end

    for _, name in ipairs(SelfTest.FONTS) do
        report(_G[name] ~= nil, "font " .. name)
    end
    local holder = CreateFrame("Frame")
    local probe = holder:CreateTexture()
    for _, path in ipairs(SelfTest.TEXTURES) do
        report(textureLoads(probe, path), "texture " .. path)
    end
    for _, check in ipairs(ns.API.SelfCheck()) do
        report(check.present, "api " .. check.name)
    end
    report(ns.Core.KnownCount() >= 0, "flight paths learned: " .. ns.Core.KnownCount())

    say(failed == 0 and "Self-test passed." or ("Self-test: " .. failed .. " failed."))
    return failed == 0
end

return SelfTest
```

- [ ] **Step 10: Replace `GoblinPS/Core.lua`**

```lua
local _, ns = ...

-- Glue: saved variables, route planning for both the chat command and the
-- planner window, the slash command and the addon compartment entry.
local API, Geo, Search, Route, Known, Prefs = ns.API, ns.Geo, ns.Search, ns.Route, ns.Known, ns.Prefs

local Core = {}
ns.Core = Core

local function say(text)
    print("|cff6fe08aGoblinPS|r " .. text)
end
Core.Say = say

-- ---- saved variables; looked up lazily because they load after this file ----

-- This character's discovered flight paths, learned at flight masters.
local function knownStore()
    GoblinPSCharDB = GoblinPSCharDB or {}
    GoblinPSCharDB.known = GoblinPSCharDB.known or {}
    return GoblinPSCharDB.known
end

-- Account-wide preferences.
local function prefs()
    GoblinPSDB = Prefs.Init(GoblinPSDB)
    return GoblinPSDB
end

function Core.KnownCount() return Known.Count(knownStore()) end
function Core.Faction() return API.Faction() end
function Core.Recents() return prefs().recents end
function Core.Remember(name) Prefs.Remember(prefs(), name) end
function Core.Layout() return prefs().layout end
function Core.ToggleLayout() return Prefs.ToggleLayout(prefs()) end
function Core.Position(window) return Prefs.Position(prefs(), window) end
function Core.SavePosition(window, point, x, y) Prefs.SavePosition(prefs(), window, point, x, y) end
function Core.MinimapPrefs() return prefs().minimap end

-- Escape closes a frame only through its global name.
function Core.CloseOnEscape(frame, globalName)
    _G[globalName] = frame
    table.insert(UISpecialFrames, globalName)
end

-- ---- planning ----

local function here()
    local map, mx, my = API.PlayerMapPosition(ns.Data.Places)
    local c, x, y = Geo.ToWorld(ns.Data.Places, map, mx, my)
    if not c then
        return nil
    end
    return { name = "You", c = c, x = x, y = y, map = map, mx = mx, my = my }
end

-- Plans a route to a place (from Search), from another place or, when from is
-- nil, from where the player stands. Always returns a table:
--   result  Route.Plan's answer, or nil
--   hint    Route.Hint's answer, or nil
--   notes   plain lines for the player; the last one explains a missing route
function Core.PlanRoute(to, from)
    local plan = { to = to, notes = {} }
    local faction = API.Faction()
    if not faction then
        plan.notes[1] = "Pick a faction first."
        return plan
    end
    from = from or here()
    if not from then
        plan.notes[1] = "Can't tell where you are. Inside an instance?"
        return plan
    end
    local bindName = API.HearthBindName()
    local bind = bindName and Search.Exact(ns.Data, bindName, faction) or nil
    if bindName and not bind then
        plan.notes[#plan.notes + 1] = "Hearth: unknown inn (" .. bindName .. "), left out."
    end
    local known = knownStore()
    if not next(known) then
        plan.notes[#plan.notes + 1] =
            "Visit a flight master so GoblinPS can learn your flight paths. Until then, no flights."
    end

    local opts = { faction = faction, known = known, from = from, to = to, hearth = bind }
    plan.result = Route.Plan(ns.Data, opts)
    if not plan.result then
        plan.notes[#plan.notes + 1] = "No route found to " .. to.name .. "."
    elseif #plan.result.steps == 0 then
        plan.notes[#plan.notes + 1] = "You're already at " .. to.name .. "."
        return plan
    end
    plan.hint = Route.Hint(ns.Data, opts, plan.result)
    return plan
end

-- Go: for now, Blizzard's map pin and arrow on the first step you travel to.
-- The dash unit takes this over in a later plan.
function Core.Go(plan)
    local step = plan and plan.result and plan.result.steps[1]
    if not step then
        return
    end
    if step.kind == "hearth" then
        say("Use your hearthstone, then press GO again.")
    elseif step.to.map and API.SetWaypoint(step.to.map, step.to.mx, step.to.my) then
        say("Pin set: " .. Route.StepText(step) .. ".")
    else
        say("Can't put a map pin there. " .. Route.StepText(step) .. ".")
    end
end

local function routeTo(text)
    local dest = Search.Find(ns.Data, text, API.Faction(), 1)[1]
    if not dest then
        say('No place matches "' .. text .. '".')
        return
    end
    local plan = Core.PlanRoute(dest)
    for _, note in ipairs(plan.notes) do
        say(note)
    end
    local steps = plan.result and plan.result.steps or {}
    if #steps > 0 then
        say("To " .. dest.name .. ": " .. Route.FormatTime(plan.result.seconds) .. ", "
            .. Route.FormatMoney(plan.result.copper))
        for i, step in ipairs(steps) do
            say(i .. ". " .. Route.StepText(step))
        end
    end
    if plan.hint then
        say(Route.HintText(plan.hint))
    end
end

-- Do the client's flight node IDs and names match our generated table, and
-- how many flight paths has this character taught us so far?
local function probe()
    local nodes = API.TaxiNodes()
    local missing, renamed = 0, 0
    for _, node in ipairs(nodes) do
        local ours = ns.Data.Nodes[node.nodeID]
        if not ours then
            missing = missing + 1
            say("not in our data: " .. tostring(node.nodeID) .. " " .. tostring(node.name))
        elseif ours.name ~= node.name then
            renamed = renamed + 1
            say("name differs: " .. node.nodeID .. " ours '" .. ours.name .. "' client '" .. tostring(node.name) .. "'")
        end
    end
    say(("Client lists %d flight nodes. %d not in our data, %d named differently.")
        :format(#nodes, missing, renamed))
    say(("Learned from flight masters so far: %d flight paths."):format(Core.KnownCount()))
end

-- The only moment the client says which flight paths are discovered.
API.OnTaxiMapOpened(function()
    local store = knownStore()
    local added = Known.Learn(store, API.OpenTaxiNodes())
    if added > 0 then
        say(("Learned %d flight path%s here (%d known)."):format(added, added == 1 and "" or "s", Known.Count(store)))
        ns.Planner.Replan()
    end
end)

API.OnLogin(function()
    ns.MinimapButton.Initialize()
end)

local function slash(msg)
    local command, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" then
        ns.Planner.Toggle()
    elseif command == "to" and rest ~= "" then
        routeTo(rest)
    elseif command == "probe" then
        probe()
    elseif command == "selftest" then
        ns.SelfTest.Run(say)
    elseif command == "minimap" then
        ns.MinimapButton.SetHidden(not Core.MinimapPrefs().hide)
        say(Core.MinimapPrefs().hide and "Minimap button hidden. /gps minimap shows it again."
            or "Minimap button shown.")
    else
        say("/gps              open the planner")
        say("/gps to <place>   print a route in chat")
        say("/gps minimap      show or hide the minimap button")
        say("/gps probe        check the flight path data against the client")
        say("/gps selftest     check textures and fonts")
    end
end

SLASH_GOBLINPS1 = "/gps"
SlashCmdList.GOBLINPS = slash

-- Named in the TOC's AddonCompartmentFunc line.
function GoblinPS_OnAddonCompartmentClick()
    ns.Planner.Toggle()
end

return Core
```

- [ ] **Step 11: Replace `GoblinPS/GoblinPS.toc`**

```
## Interface: 16001
## Title: GoblinPS
## Notes: Goblin Positioning System. The fastest route from where you stand. Accuracy not guaranteed. No refunds.
## Author: CoffeeAndLoot
## X-Website: https://github.com/CoffeeAndLoot/goblinps
## IconTexture: Interface\AddOns\GoblinPS\Media\icon
## Version: 2026.09.19.2
## SavedVariables: GoblinPSDB
## SavedVariablesPerCharacter: GoblinPSCharDB
## AddonCompartmentFunc: GoblinPS_OnAddonCompartmentClick

API.lua
Geo.lua
Data\Places.lua
Data\Nodes.lua
Data\Flights.lua
Data\Links.lua
Data\Inns.lua
Search.lua
Graph.lua
Route.lua
Trip.lua
Known.lua
Prefs.lua
Widgets.lua
Planner.lua
MinimapButton.lua
SelfTest.lua
Core.lua
```

- [ ] **Step 12: Replace `.luacheckrc`**

```lua
std = "lua51"
max_line_length = 120
self = false
globals = {
    "SLASH_GOBLINPS1", "SlashCmdList", "GoblinPSDB", "GoblinPSCharDB",
    "GoblinPS_OnAddonCompartmentClick", "UISpecialFrames",
}
read_globals = {
    "print",
    "UnitFactionGroup", "GetBindLocation",
    "C_TaxiMap", "C_Map", "C_Item", "C_SuperTrack", "UiMapPoint",
    "CreateFrame", "Enum",
    "UIParent", "Minimap", "GameTooltip", "GetCursorPosition",
}
files["GoblinPS/Data/Places.lua"] = { max_line_length = false }
files["GoblinPS/Data/Nodes.lua"] = { max_line_length = false }
files["GoblinPS/Data/Flights.lua"] = { max_line_length = false }
-- The UI smoke test installs a fake frame API into the globals.
files["test/fake_frames.lua"] = { globals = { "print" } }
files["test/test_ui.lua"] = { globals = { "print" }, read_globals = { "GoblinPSMinimapButton" } }
```

- [ ] **Step 13: Replace `.luarc.json`**

```json
{
  "runtime.version": "Lua 5.1",
  "workspace.ignoreDir": [".remember", ".superpowers", "tools", "docs"],
  "diagnostics.globals": [
    "SLASH_GOBLINPS1", "SlashCmdList", "GoblinPSDB", "GoblinPSCharDB",
    "GoblinPS_OnAddonCompartmentClick", "UISpecialFrames", "GoblinPSMinimapButton",
    "UnitFactionGroup", "GetBindLocation",
    "C_TaxiMap", "C_Map", "C_Item", "C_SuperTrack", "UiMapPoint",
    "CreateFrame", "Enum",
    "UIParent", "Minimap", "GameTooltip", "GetCursorPosition"
  ]
}
```

- [ ] **Step 14: Run the Lua tests.** Expected: `103 passed, 0 failed`.

- [ ] **Step 15: Run luacheck** (`Total: 0 warnings / 0 errors`) **and the language server:**

```
lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json
```

Expected: `Diagnosis completed, no problems found`. Report anything else verbatim; do not "fix" code from this plan to silence it.

- [ ] **Step 16: Commit**

```
git add GoblinPS test .luacheckrc .luarc.json
git commit -m "Add the planner window, minimap button, compartment entry and self-test" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Documents

**Files:**
- Create: `docs/art-specs.md`
- Modify: `docs/manual-test-checklist.md`, `CLAUDE.md`, `docs/superpowers/specs/2026-09-19-goblinps-design.md`

- [ ] **Step 1: Write `docs/art-specs.md`**

```markdown
# GoblinPS art specs

The addon works with no art at all: every surface is a flat colour in the
Goblin Gadget palette. Art is laid over those colours, so any piece can arrive
at any time, from an artist or an image generator, without a code change
beyond dropping the file in. The schematic map is NOT art: it is generated
from game data (`docs/research/schematic-spike/`), so its pins stay exact.

Palette: brass `#B8873B`, body `#3B2E1C`, oily steel `#1C1A14`, screen green
`#081F0F` with `#70E08A` text, amber `#F0B54A`, hazard orange `#E0701C`.
Look: a dented brass goblin gadget, rivets, hazard-stripe trim, a green CRT
screen. Slightly battered, hand-built, not sleek.

## Wired today

| Piece | Drop the source at | Spec | Then run |
|---|---|---|---|
| Addon icon (TOC, minimap button) | `images/icon-source.png` | Square PNG, 1024x1024 or larger, subject centred with a margin: it is cropped to a circle. A brass gadget face or dial with a green screen and an amber route reads well at 20 pixels. No text. | `python tools/make_icon.py` |

## Wanted next (not wired yet; plan 3 and later hook them up)

| Piece | Spec |
|---|---|
| Window frame, wide | PNG with transparency, 1024x512 canvas holding a 660x400 frame: brass border about 12 px, rivets at corners and along edges, a hazard-stripe strip across the top, the middle fully transparent. |
| Window frame, tall | Same style, 512x1024 canvas holding a 390x600 frame. |
| Screen glass | 512x512 PNG, mostly transparent: faint scanlines, a soft corner glare, slight vignette. Tiled or stretched over the green screen. |
| Button face | 128x64 PNG, brass plate with a stamped edge, plus a pressed variant. |
| Dash unit body | 512x256 PNG with transparency, a small dashboard device with a suction-cup mount. |

WoW loads TGA or BLP with power-of-two sides. Source art stays PNG under
`images/`; a tool converts it into `GoblinPS/Media/`.
```

- [ ] **Step 2: Add this section to the end of `docs/manual-test-checklist.md`**

```markdown
## Planner window (plan 2): check every line in BOTH layouts

Restart the game first: the TOC changed.

- [ ] `/gps selftest` ends "Self-test passed."; record any FAIL line here
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
- [ ] Press Enter with text in To: the first match is taken
- [ ] Empty the To box and click it: recent destinations are offered
- [ ] Type a start in From and pick it: the route re-plans from there;
      "Here" goes back to where you stand
- [ ] GO with a flight or ride first step: Blizzard's map pin and the
      on-screen arrow appear at the step's target, and chat says "Pin set"
- [ ] GO when step 1 is the hearthstone: chat says to use it; no pin
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
```

Also, in the existing `## Routing core (plan 1)` section, tick the two items that begin `- [ ] Known wart for plan 2:` and `- [ ] Inns in towns with no flight master` by changing `[ ]` to `[x]` and appending ` (done in plan 2)` to each item's last line.

- [ ] **Step 3: Update `CLAUDE.md`.** Replace the paragraph that starts `**Status:` with:

```markdown
**Status: routing core and planner window built (plans 1 and 2).** `/gps`
opens the planner; `/gps to <place>` prints a route in chat. Next: plan 3,
the schematic map on the green screen (approach proven in
`docs/research/schematic-spike/`), then plan 4, the dash unit. The design is
`docs/superpowers/specs/2026-09-19-goblinps-design.md`. Write each plan after
the one before it has been used in game.
```

In the "Intended layout" code block, replace the line that lists `Trip (pure arrival rules), planner window, dash unit, schematic map, Core` with these lines:

```
GoblinPS/Known.lua, Prefs.lua  # pure: learned flight paths; account preferences
GoblinPS/Data/Inns.lua       # HAND-WRITTEN: hearthstone bind names Search cannot find alone
GoblinPS/Widgets.lua         # plain controls in the gadget palette; NO Blizzard frame templates
GoblinPS/Planner.lua         # the window; one set of widgets, ApplyLayout moves them
GoblinPS/MinimapButton.lua, SelfTest.lua, Core.lua
test/fake_frames.lua         # fake frame API: smoke-tests OUR window code, not Blizzard's
```

Under "Rules that are easy to break", replace the bullet that begins `- Every constructor that leans on a Blizzard template or atlas` with:

```markdown
- The window uses **no Blizzard frame templates**: plain frames and colour
  textures, so a template renamed by a beta patch cannot break it. Art is
  laid over the colours (`docs/art-specs.md`); a missing texture must leave a
  working window. `/gps selftest` checks fonts, stock textures and APIs.
```

- [ ] **Step 4: Update the spec.** In `docs/superpowers/specs/2026-09-19-goblinps-design.md`:

Replace the status paragraph at the top (from `Status:` to the blank line after it) with:

```markdown
Status: **approved by the user on 2026-09-19.** Implemented in four plans
under `docs/superpowers/plans/`: 1 routing core (done), 2 planner window,
3 schematic map, 4 dash unit. Each is written after the one before it has
been used in game. Update this file whenever behaviour changes.

```

In decision 7, replace the sentence `Falls back to stock Blizzard templates if a texture is missing.` with `The window uses no Blizzard frame templates at all: plain frames in the palette's flat colours, with art laid over them (docs/art-specs.md), so a missing texture or a renamed template cannot break it.`

In decision 10, replace `Add hand-written name rows only for misses met in game.` with `Hand-written rows in Data/Inns.lua cover inns beside a differently named flight stop and towns with an inn but no flight master; add a row whenever "unknown inn" is seen in game.`

In the "`Graph` (pure)" bullet, append: ` A zone destination is reached at any place on the zone's map: that ride to the destination costs nothing, so hearthing to Crossroads for "The Barrens" does not add a ride to the zone's centre.`

- [ ] **Step 5: Run the Lua tests and luacheck once more** (docs only, so: `103 passed, 0 failed`, `0 warnings`), then commit

```
git add docs CLAUDE.md
git commit -m "Docs: planner window checklist, art specs, four-plan roadmap" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 6: Hand over.** Report that the desktop work is verified and that nothing in this plan has run in the game client. The user must restart the game (the TOC changed) and work through `## Planner window (plan 2)` in both layouts. Do not claim any of those checks pass.

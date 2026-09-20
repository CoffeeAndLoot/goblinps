# Global constraints that bind every GoblinPS ground-crossings task

Copied from the plan's Global Constraints and the spec (decisions 15 to 19).

- Plain Lua 5.1, **no libraries**, **no secure code**, no Blizzard frame templates in the window.
- Pure modules (`Geo`, `Travel`, `Search`, `Graph`, `Route`, `Trip`, `Known`, `Prefs`) touch no Blizzard global. `GoblinPS/API.lua` is the only file that calls Blizzard game APIs and registers game-data events. The one API this plan adds is `UnitLevel`. No new events.
- Generated files under `GoblinPS/Data/` (`Places`, `Nodes`, `Flights`) are never edited. `Links.lua`, `Inns.lua`, `Crossings.lua`, `Zones.lua` are hand-written.
- Mount levels and speeds are **unconfirmed** for Forever: they live only in `GoblinPS/Travel.lua` as named settings, and nothing else may hard-code them.
- Ground travel is per zone: a ride edge joins two points only when they share a UiMap; a crossing belongs to both of its zones; cities are zones and their gates are crossings; an island is a zone with no crossing.
- Crossing coordinates are estimates until checked in game; crossings for Forever's new zones carry `unverified = true`.
- The route is always the fastest; danger only warns (amber), never reroutes.
- A hole in the crossings table must never produce "No route": `Route.Plan` falls back to the old straight line, labelled "(no mapped path)", and only when no chain of crossings exists.
- A crossing step reads as the turn ("Walk to the Mor'shan Rampart") with the zone as a smaller detail line ("into Ashenvale · level 18-30"). "Walk" below the first mount level, "Ride" from it.
- Route text stays plain. Every FontString in the window is bounded (two horizontal anchors or a width). Two planner layouts, one set of widgets.
- luacheck and lua-language-server stay at zero warnings; a new global goes in both `.luacheckrc` and `.luarc.json`.
- Version `2026.09.19.3`, written only in the TOC. Nothing is pushed.
- The task brief contains the complete intended content of every file it changes. The implementer was told to write each file exactly as listed; a deviation from the brief's content is a finding.

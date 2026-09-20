# Global constraints that bind every GoblinPS planner-window task

Copied from the plan's Global Constraints and the spec.

- Plain Lua 5.1 against the Blizzard API. **No libraries.** **No secure code.**
- Pure modules (`Geo`, `Search`, `Graph`, `Route`, `Trip`, `Known`, `Prefs`) touch no Blizzard global at all.
- `GoblinPS/API.lua` is the only file that calls Blizzard **game APIs** (`C_*`, unit, item, map functions) and registers game events. UI files (`Widgets`, `Planner`, `MinimapButton`, `SelfTest`) may create frames and use `UIParent`, `Minimap`, `GameTooltip`, `GetCursorPosition`. `Core.lua` registers the slash command, the compartment function and prints.
- **No Blizzard frame templates** in the window: plain `Frame`, `Button`, `EditBox` with colour textures. A missing texture must leave a working window.
- Never guess an API, event, texture or font name: each must exist in `D:\wow-api\1.60.1.69913`.
- Known flight paths are learned only by `Known.Learn` into `GoblinPSCharDB.known`. `GoblinPSDB` (account-wide) holds preferences, recents and window positions, nothing else.
- Two planner layouts, **one set of widgets**; `Planner.ApplyLayout(mode)` changes only size and anchors.
- Route text stays plain. Jokes live in the tagline and tooltips only.
- Generated files under `GoblinPS/Data/` (`Places`, `Nodes`, `Flights`) are never edited by hand.
- luacheck and lua-language-server stay at zero warnings; a new global goes in both `.luacheckrc` and `.luarc.json`.
- Version `2026.09.19.2`, written only in the TOC.
- Nothing is pushed.
- The task brief contains the complete intended code. The implementer was told to transcribe it byte-for-byte; a deviation from the brief's code is a finding.

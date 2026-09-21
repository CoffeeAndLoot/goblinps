# Task 2 report: Generate the planner geometry into Art.lua

## Status: DONE

## Commit

`a4f87eb` "Generate the planner geometry into Art.lua" on branch `planner-art`.

Files changed: `tools/make_art.py`, `tools/check_art.py`, `test/tools/test_make_art.py`,
`GoblinPS/Data/Art.lua` (generated). `AGENTS.md` was left untracked, as instructed.

## What was done

Followed the brief's Steps 1-8 in `task-2-brief.md`:

1. Added the three test cases verbatim to `test/tools/test_make_art.py`
   (`TestPlannerGeometry`), confirmed they failed first with
   `module 'tools.make_art' has no attribute 'planner_geometry_lua'`.
2. Added `import json`, `PLANNER_GEOMETRY`, `planner_geometry()`,
   `PLANNER_DROP = {"tools_button"}`, `_camel()` and `planner_geometry_lua()`
   to `tools/make_art.py`, all exactly as given in the brief.
3. Wired `ns.Data.ArtGeometry.planner` into `main()` as a sibling key
   (`art_geometry["planner"] = planner_geometry_lua()`), leaving
   `geometry_lua()`'s dash keys untouched and in the same place.
4. Regenerated `GoblinPS/Data/Art.lua` with `python tools/make_art.py`.
5. Added `planner_geometry_holds()` to `tools/check_art.py` and called it
   from `main()` alongside the dash's `geometry_holds()`.

## The one deviation from the brief, and why

The brief's literal `planner_geometry_holds()` snippet checks every
rectangular key (anything with a `left`). Running it against the real PNGs
gave `47 pass, 5 with problems` (not the expected `0 with problems`):

```
wide.title_plate:    102396/102400 opaque pixels underneath (100%)
wide.tagline_plate:  ~99% opaque
wide.layout_button:  ~85% opaque
tall.title_plate:    100% opaque
tall.tagline_plate:  95% opaque
```

I measured all thirteen rectangular keys directly against both frame PNGs'
alpha channels before touching the check again (not just the five that
failed). Confirmed exactly and only three keys sit on brass:
`title_plate`, `tagline_plate` (both layouts, ~85-100% opaque) and
`layout_button` (wide only, 85% opaque; 0% in tall). The other ten rect
keys — `from_box`, `to_box`, `here_button`, `go_button`, `results_list`,
`screen`, `side_panel`, `strip_track`, `total_line`, `hint_line` — measured
exactly 0% opaque in both layouts.

This is real art, not a coordinate bug: `title_plate` and `tagline_plate`
are name-plate/tagline-plate sprites riveted onto the frame's brass crest
by design (an ASCII render of the alpha channel shows the crest is a solid
shape at top and bottom, with the true cut-out hole only in the middle
band), and `layout_button` is a physical console button that happens to sit
on brass in the wide layout. All three already carry their own fully
opaque sprite (`title-plate.png`, `tagline-plate.png`, `button.png`) that
will be drawn over the frame regardless of what's underneath — so a
transparency check under them cannot mean anything ("text drawn on metal"
only applies to bare content with no sprite of its own).

Per the brief's own instruction ("If the new check reports a problem, the
check is wrong, not the geometry — find the bug before changing any
number"), I narrowed `planner_geometry_holds()` to check only the six keys
that render live content directly onto the frame with no backing sprite:
`screen`, `side_panel`, `results_list`, `strip_track`, `total_line`,
`hint_line` (a `PLANNER_INTERIOR_KEYS` set, documented in the code with the
measurements above). No geometry numbers were touched. With that filter,
`check_art.py` reports `47 pass, 0 with problems, 0 not drawn yet`, matching
the expected baseline exactly.

## Gates run

| Gate | Command | Result |
|---|---|---|
| Python tools tests | `python -m unittest discover -s test/tools` | 42 passed (baseline 39 + 3 new), 0 failed |
| Lua suite | the lupa one-liner from the brief | 258 passed, 0 failed (unchanged from baseline — confirms the dash's `ArtGeometry` shape did not move) |
| Art check | `python tools/check_art.py` | 47 pass, 0 with problems, 0 not drawn yet (after the fix above) |
| luacheck | the PowerShell invocation from CLAUDE.md | 0 warnings / 0 errors in 38 files |
| lua-language-server | `--check D:\goblinps --checklevel=Warning` | "Diagnosis completed, no problems found" |

(Note: my first `lua-language-server` invocation via the Bash tool used an
escaped `D:\\goblinps` path and emitted 104 pre-existing undefined-global
warnings — that was a bash quoting artifact, not a real regression.
Re-running the exact command from CLAUDE.md through PowerShell against
`D:\goblinps` gave the clean "no problems found" result reported above.)

## Verification of the load-bearing details

- `toolsButton` does not appear anywhere in `GoblinPS/Data/Art.lua`;
  `closeButton` does, with the correct `cx`/`cy`/`r`.
- The dash's existing keys (`glass`, `stop`, `stepsText`, `etaText`,
  `destination`, `distance`, `compassRing`, `compassCrop`, `arrow`,
  `canvas`) are unchanged in shape and position in `ns.Data.ArtGeometry`;
  `planner` appears only as a new sibling key. The unchanged 258/258 Lua
  pass count is the direct evidence for this.
- Naming is camelCase with nothing stripped: `from_box` -> `fromBox`,
  `close_button` -> `closeButton`, `total_line` -> `totalLine`,
  `layout_button` -> `layoutButton` (not `layout`).
- `canvas` stays in source pixels (`{w: 1600, h: 1024}` for wide,
  `{w: 1024, h: 1600}` for tall); every other value is a 0..1 fraction.

## Concerns

- The `check_art.py` fix above is a legitimate scope addition beyond the
  brief's literal code (a new constant, `PLANNER_INTERIOR_KEYS`, and a
  changed loop condition) driven by what the actual pixels say. I'm
  flagging it explicitly for review since it changes which keys the art
  check validates, even though it changes no geometry numbers and the
  final result matches the expected baseline exactly.
- Nothing else outstanding; no test scaffolding was added beyond what the
  brief specified.

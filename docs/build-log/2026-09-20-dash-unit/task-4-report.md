# Task 4 report: The device, on flat colours

## Summary

Followed the brief exactly. No defects found in the brief this time — the
provided `Dash.lua`, TOC changes and test both transcribed cleanly and passed
on the first run once the harness wiring was correct. One adaptation was
needed (see "Deviation from the brief's literal text" below), which the brief
itself anticipated in the task instructions given to me.

## Files changed

### `GoblinPS/Dash.lua` (new, 120 lines)

Created verbatim from the brief's Step 3 code block: `Dash.SIZE`, `Dash.Start`,
`Dash.Stop`, `Dash.Refresh`, `Dash.Debug`, the module-level `ui`/`state`
upvalues, `build()` with the panel/screen/arrow/distance/eta/step/next/stop
widgets, drag handling via `ns.Core.SavePosition`, and `ns.Core.CloseOnEscape(f,
"GoblinPSDash")`. No changes from the brief's text.

### `GoblinPS/GoblinPS.toc`

- Line 7: `## Version: 2026.09.20` -> `## Version: 2026.09.20.2`
- Line 21 (new): `Data\Art.lua` inserted after `Data\Zones.lua` (line 20),
  before `Travel.lua`.
- Line 31 (new): `Dash.lua` inserted after `Planner.lua` (line 30), before
  `MinimapButton.lua`.

```diff
-## Version: 2026.09.20
+## Version: 2026.09.20.2
@@
 Data\Zones.lua
+Data\Art.lua
 Travel.lua
@@
 Planner.lua
+Dash.lua
 MinimapButton.lua
```

### `test/test_ui.lua`

- Module list (the `for _, file in ipairs({...})` loop, originally line 52-53):
  added `"Dash"` after `"Planner"`, before `"MinimapButton"`.
- Added a new `h.describe("the dash unit", ...)` block with the brief's five
  `h.it` cases, inserted directly before the existing
  `h.describe("the fake frames model what the dash needs", ...)` block (i.e.
  at the end of the file, after `/gps to still prints a route in chat`).

## Deviation from the brief's literal text (not a defect — anticipated by the task)

The brief's Step 1 code sample is written as
`return function(h, loaded) local ns = loaded.ns ... end`, the shape used by
the *other* individual test files (e.g. `test/test_trip.lua`), which each get
their own fresh `Fake.Install()` and a `loaded` table. `test/test_ui.lua`,
however, is a single `return function(h) ... end` chunk that installs the fake
frame library exactly once and builds its own `ns` and scripted `ns.API`
in-line; the task's own "Context the brief cannot know" section explicitly
warned that a second `Fake.Install()` call in this file would reassign globals
and silently break the existing tests, and told me to add `"Dash"` to the
existing module-loading loop instead of creating a new file.

So I transcribed the body of the brief's test (the `local plan = {...}` and
`h.describe("the dash unit", ...)` block) directly into `test/test_ui.lua`,
using the file's own outer `ns` local (already in scope) in place of
`loaded.ns`, and dropped the `return function(h, loaded) ... end` wrapper
since it would have been a second, unreachable top-level return in a file
that already returns once at its close. This is exactly what the task's own
guidance called for, not an improvisation against the brief.

Everything else — the file `GoblinPS/Dash.lua`, the TOC edits, and the
test's own assertions and plan fixture — was transcribed as given, with no
renames, reformatting or "improvements."

## RED (before creating GoblinPS/Dash.lua)

Command:
```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```

Output:
```
Traceback (most recent call last):
  ...
lupa.lua51.LuaError: test/test_ui.lua:54: cannot open GoblinPS/Dash.lua: No such file or directory
stack traceback:
	[C]: in function 'assert'
	test/test_ui.lua:54: in function <test/test_ui.lua:8>
	[string "<python>"]:53: in main chunk
```

This is the module-loading loop in `test_ui.lua` (`assert(loadfile("GoblinPS/"
.. file .. ".lua"))(...)`) failing on the newly-added `"Dash"` entry, i.e. the
expected failure named in the brief ("`ns.Dash` is nil" manifests here as the
file itself not existing yet, one step earlier in the same loop — the effect
is the same: the suite cannot get as far as running the dash tests without the
file).

## GREEN (after creating GoblinPS/Dash.lua and the TOC edits)

Same command. Output:
```
0
210 passed, 0 failed
```

## Final Lua test count

**210 passed, 0 failed.**

(The brief's note that "the suite total moves while you work because another
agent is committing" applies — this is the count at the moment this task's
tests were run, after `git log` showed `f9f3fd2` as the most recent commit on
`dash-unit` from the other agent's Trip/API work, which this task did not
touch.)

## luacheck

Command:
```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"; $env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"; lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test tools --no-color --no-cache
```

Output (39 files, `GoblinPS\Dash.lua` included and OK):
```
Checking GoblinPS\API.lua                         OK
Checking GoblinPS\Core.lua                        OK
Checking GoblinPS\Dash.lua                        OK
Checking GoblinPS\Data\Art.lua                    OK
...
Checking test\test_ui.lua                         OK
Checking tools\survey_crossings.lua               OK

Total: 0 warnings / 0 errors in 39 files
```

## lua-language-server

Command:
```
lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json
```

Output: `Diagnosis completed, no problems found`, and the JSON report at
`$env:TEMP\goblinps-lls.json` is `[]` (empty — zero diagnostics).

## Config file diffs (exact lines added)

`.luacheckrc`, inside the existing `globals = { ... }` table:
```diff
     "GoblinPS_OnAddonCompartmentClick", "UISpecialFrames",
-    "GoblinPSMinimapButton", "GoblinPSPlanner",
+    "GoblinPSMinimapButton", "GoblinPSPlanner", "GoblinPSDash",
 }
```

`.luarc.json`, inside `diagnostics.globals`:
```diff
-    "GoblinPS_OnAddonCompartmentClick", "UISpecialFrames", "GoblinPSMinimapButton", "GoblinPSPlanner",
+    "GoblinPS_OnAddonCompartmentClick", "UISpecialFrames", "GoblinPSMinimapButton", "GoblinPSPlanner", "GoblinPSDash",
```

## Commit

```
git add GoblinPS/Dash.lua GoblinPS/GoblinPS.toc test/test_ui.lua .luacheckrc .luarc.json
git commit -m "Dash unit: the device on flat colours" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" -- GoblinPS/Dash.lua GoblinPS/GoblinPS.toc test/test_ui.lua .luacheckrc .luarc.json
```

Result: `[dash-unit b7d3fb3] Dash unit: the device on flat colours`,
5 files changed, 193 insertions(+), 4 deletions(-), `GoblinPS/Dash.lua` created.

`git status --short` before staging showed only this task's five files plus
the pre-existing untracked `AGENTS.md`, which was left untracked and
unstaged, per the working rules (it belongs to another agent). Nothing else
was swept in; the commit's file list was passed explicitly on both `git add`
and `git commit`.

## Not done / chosen differently

- Did not touch `GoblinPS/Trip.lua` or `test/test_trip.lua`, per instruction
  (another agent is editing those).
- Did not push, merge or switch branches.
- Did not run the WoW client; no claim is made about in-game appearance or
  dragging feel — only what the desktop fake and the two static checkers
  confirm.
- No subagents were dispatched; all work done directly in this session.

## Anything that looked off but wasn't changed

Nothing. Unlike task 3 (per the brief's mention of "two defects" previously
found), this task's brief matched the codebase's actual conventions
(`Widgets.Panel`/`Text`/`Button` signatures, `Core.Position`/`SavePosition`,
`CloseOnEscape`, the `fake_frames.lua` widget model) exactly, and the fake
already modelled every method `Dash.lua` calls (`SetRotation`,
`SetVertexColor`, `SetDrawLayer`, `SetTexCoord` were called out as already
present from the previous task, and this task's `Dash.lua` does not call
`SetRotation`/`SetTexCoord`/`SetDrawLayer` at all — only `SetVertexColor`,
which the fake already models). No workaround or silent fix was needed.

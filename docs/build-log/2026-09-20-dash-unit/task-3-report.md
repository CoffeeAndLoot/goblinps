# Task 3 report: What the client has to tell us

## Summary

Status: DONE. All steps from `task-3-brief.md` completed as specified, with
one deliberate deviation from the brief's suggested placement of `Core.Here()`
(explained below, under "Deviation").

## Changes per file

### `test/test_ui.lua`
- Line 18 area: added `local facing, onTaxi, tripCallbacks = 0, false, {}`
  beside `local level = 60`.
- In the scripted `ns.API` table, beside `OnTaxiMapOpened`/`OnLogin`, added:
  - `PlayerFacing = function() return facing end,`
  - `OnTaxi = function() return onTaxi end,`
  - `OnTripEvent = function(callback) tripCallbacks[#tripCallbacks + 1] = callback end,`
- After the `"/gps to still prints a route in chat"` describe block and before
  `print = realPrint`, added the new describe block
  `"the fake frames model what the dash needs"` with its two `it` cases
  (`"a texture can be rotated"`, `"a texture records its coordinates, tint and
  layer"`), transcribed verbatim from the brief.

### `test/fake_frames.lua`
- Removed `SetTexCoord` from the `ALLOWED_NOOP` ignored-list table (was
  originally in the list starting `SetAllPoints = true, SetColorTexture =
  true, SetTexCoord = true, SetAlpha = true,` — now reads `SetAllPoints =
  true, SetColorTexture = true, SetAlpha = true,`).
- Added four new `Region:` methods, placed beside the existing texture
  methods (`SetTexture`/`GetTexture`), matching the file's existing
  colon-method style rather than the brief's table-literal-with-commas
  formatting (see "Deviation" below):
  ```lua
  function Region:SetTexCoord(l, r, t, b) self.texCoord = { l, r, t, b } end
  function Region:SetRotation(radians) self.rotation = radians end
  function Region:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
  function Region:SetDrawLayer(layer) self.drawLayer = layer end
  ```
  These now sit at lines 114-118 (right after `GetTexture`).

### `GoblinPS/API.lua`
- Beside `API.Level` (before `API.ZoneLevels`), added:
  ```lua
  function API.PlayerFacing()
      if not GetPlayerFacing then
          return nil
      end
      return GetPlayerFacing()
  end

  function API.OnTaxi()
      return UnitOnTaxi and UnitOnTaxi("player") and true or false
  end
  ```
  (with the brief's comments, transcribed verbatim) — lines ~30-43.
- Beside `API.OnTaxiMapOpened` (before `API.PlayerMapPosition`), added:
  ```lua
  function API.OnTripEvent(callback)
      local f = CreateFrame("Frame")
      f:RegisterEvent("ZONE_CHANGED")
      f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
      f:RegisterEvent("PLAYER_CONTROL_LOST")
      f:RegisterEvent("PLAYER_CONTROL_GAINED")
      f:SetScript("OnEvent", function(_, event)
          callback(event == "PLAYER_CONTROL_GAINED" and "landed" or "zone")
      end)
  end
  ```
  Only the four named events are registered — no others.
- In `API.SelfCheck`'s checks list, added two rows beside the existing ones:
  `{ "GetPlayerFacing", GetPlayerFacing },` and `{ "UnitOnTaxi", UnitOnTaxi },`.

### `GoblinPS/Core.lua`
- Added, immediately after the `local function here()` definition (right
  after its closing `end`, before `-- Plans a route to a place ...`):
  ```lua
  -- Where the player stands, as a place the router understands. Nil inside an
  -- instance, where the client gives no useful position.
  function Core.Here() return here() end
  ```
  See "Deviation" below for why this is not "near the top" with the other
  small `Core.X()` accessors.

### `.luacheckrc`
Added one line to `read_globals`, right after the `UnitFactionGroup`/
`GetBindLocation`/`UnitLevel` line:
```lua
    "GetPlayerFacing", "UnitOnTaxi",
```

### `.luarc.json`
Added the same two globals to `diagnostics.globals`, on their own line right
after `"UnitFactionGroup", "GetBindLocation", "UnitLevel",`:
```json
    "GetPlayerFacing", "UnitOnTaxi",
```

## Deviation: `Core.Here()` placement

The task's own briefing note said: "Put the accessor with the other small
`function Core.X()` accessors near the top." I tried that first (right after
`Core.MinimapPrefs`, before the `-- ---- planning ----` section where `local
function here()` is declared) and it is **broken**: Lua resolves a bare
identifier lexically at the point in the source text where it is written, not
by name lookup at call time. Since `local function here()` is declared later
in the file, a `Core.Here` defined textually *before* that declaration closes
over a nonexistent local and falls through to the (nil) global `here`,
raising `attempt to call global 'here' (a nil value)` the moment it is
called.

I proved this both in isolation and against the real file:

```
$ python -c "... local M={}; function M.Here() return here() end; local function here() return 42 end; return M.Here() ..."
ERROR [string "<python>"]:3: attempt to call global 'here' (a nil value)
```

And loading the actual (first-draft) `GoblinPS/Core.lua` with `Core.Here`
placed near the top and calling it directly:
```
ok=	false	result=	GoblinPS/Core.lua:43: attempt to call global 'here' (a nil value)
```

None of the existing 198 tests catch this, because nothing calls `Core.Here`
yet (as the brief says, that's task 5's job) — it would have shipped silently
broken.

I moved `function Core.Here() return here() end` to directly after `local
function here() ... end`'s closing `end`, and re-ran the same direct check:
```
ok=	true	result=	table: ...
y	1100
x	1000
name	You
my	0.9
mx	0.89
map	1
c	1
```
This matches the interface contract exactly: `{ name = "You", c, x, y, map,
mx, my }`. I did not move `local function here()` itself, and did not rewrite
its body — only relocated the one-line accessor so it can actually see its
own upvalue.

## RED (Step 2)

Ran:
```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```
Output:
```
1
196 passed, 2 failed
FAIL: the fake frames model what the dash needs :: a texture can be rotated
    test/test_ui.lua:494: fake_frames: unknown widget method 'SetRotation'
FAIL: the fake frames model what the dash needs :: a texture records its coordinates, tint and layer
    test/test_ui.lua:501: attempt to index field 'texCoord' (a nil value)
```
This matches the brief's prediction exactly: the strict fake's "unknown
widget method" error for `SetRotation`, and (for the second test) `texCoord`
never being set because `SetTexCoord` was still in the ignored list at that
point.

## GREEN (after Step 3, fake_frames fix)

Same command, output:
```
0
198 passed, 0 failed
```

## Proof `SetTexCoord` now records, and is removed from the ignored list

- Removed from `ALLOWED_NOOP` in `test/fake_frames.lua` — confirmed by
  re-reading the file after the edit: the list no longer contains
  `SetTexCoord = true` (it now reads `SetAllPoints = true, SetColorTexture =
  true, SetAlpha = true,` — `SetTexCoord` gone from that line).
- The new `function Region:SetTexCoord(l, r, t, b) self.texCoord = { l, r, t, b } end`
  is defined below, so it wins over the metatable's `ALLOWED_NOOP` fallback.
- Direct test-suite proof: the brief's own test
  `"a texture records its coordinates, tint and layer"` passes as part of the
  198-green run above; it calls `t:SetTexCoord(0, 0.75, 0, 0.5)` then asserts
  `t.texCoord[2] == 0.75` and `t.texCoord[4] == 0.5`, which only succeeds if
  `SetTexCoord` records into `self.texCoord` (if the ignored-list entry had
  still been active, `t.texCoord` would be `nil` and the test would error
  with "attempt to index field 'texCoord' (a nil value)" — exactly the RED
  failure captured above).

## Final Lua test count

**198 passed, 0 failed** (up from the 196 baseline; the 2 new tests from the
brief's Step 1 both pass).

## luacheck output

Command:
```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"; $env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"; lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test tools --no-color --no-cache
```
Output: `Total: 0 warnings / 0 errors in 38 files` (all 38 files, including
`GoblinPS/API.lua`, `GoblinPS/Core.lua`, `test/fake_frames.lua`,
`test/test_ui.lua`, report `OK`).

## lua-language-server output

Command:
```
lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json
```
Output: `Diagnosis completed, no problems found`, and the JSON report at
`$env:TEMP\goblinps-lls.json` is `[]` (empty — no diagnostics).

## Exact lines added to `.luacheckrc` and `.luarc.json`

`.luacheckrc` (inside `read_globals`, one new line):
```lua
    "GetPlayerFacing", "UnitOnTaxi",
```

`.luarc.json` (inside `diagnostics.globals`, one new line):
```json
    "GetPlayerFacing", "UnitOnTaxi",
```

## Commit

```
git add GoblinPS/API.lua GoblinPS/Core.lua test/fake_frames.lua test/test_ui.lua .luacheckrc .luarc.json
git commit -m "API: facing, taxi state and the arrival events" -- GoblinPS/API.lua GoblinPS/Core.lua test/fake_frames.lua test/test_ui.lua .luacheckrc .luarc.json
```
Result: `[dash-unit 8d68010] API: facing, taxi state and the arrival events`,
`6 files changed, 67 insertions(+), 1 deletion(-)`.

`git status` afterward shows only the pre-existing untracked `AGENTS.md`
(not staged, not committed — belongs to another agent per project memory)
and a clean working tree otherwise.

## What I could not do, or chose differently, and why

- **`Core.Here()` placement**: moved from "near the top with the other small
  accessors" (as the task's context note suggested) to directly after
  `local function here()`'s definition. Explained in full under "Deviation"
  above — the suggested placement is a hard runtime bug (calls a nil global),
  proven both in isolation and against the real file. Everything else about
  the brief was transcribed verbatim, including comments.
- **Texture method style**: the brief's Step 3 snippet formats the three new
  methods as comma-terminated table entries (`SetRotation = function(self,
  radians) ... end,`). That is a Lua syntax error as a bare top-level
  statement (a trailing comma after `end` outside a table constructor) and
  does not match how any existing texture method in `fake_frames.lua` is
  written. Per the task's own instruction to "match the file's existing style
  for texture methods exactly," I wrote them as `function Region:Name(...)
  ... end` (the same form as `SetTexture`/`GetTexture`/`GetCenter` etc.)
  instead of transcribing the brief's comma'd fragment literally. Behaviour
  (fields set, values recorded) is identical either way.
- Did not touch `GoblinPS/Trip.lua`, `test/test_trip.lua`, `tools/`,
  `GoblinPS/Data/`, or `GoblinPS/Media/`, per the task's constraints.
- Did not stage or commit `AGENTS.md`.
- Did not push, merge, or switch branches.
- `PlayerFacing`, `OnTaxi`, and `OnTripEvent` are not called by anything yet
  (confirmed by grep — only defined in `API.lua` and scripted in
  `test_ui.lua`'s fake); wiring them up is task 5, as stated in the brief.

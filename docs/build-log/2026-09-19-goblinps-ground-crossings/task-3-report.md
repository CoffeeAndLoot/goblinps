# Task 3 report: Level, chat details and two-line step rows

## What was done

Followed the brief's steps in order (faithful transcription, byte-for-byte replacement of the six listed files):

1. Replaced `test/fake_frames.lua`: `SetTextColor` moved out of `ALLOWED_NOOP` and given a real
   implementation (`Region:SetTextColor(r, g, b) self.color = { r, g, b } end`) that records the
   colour a FontString was given, for the amber/dim assertions in `test_ui.lua`.
2. Replaced `test/test_ui.lua`: added `Level` to the scripted `ns.API`, a `level` local defaulting to
   60, `Travel` to the list of loaded modules, and a new `describe("ground steps in the window", ...)`
   block covering the two-line rows, amber/dim colouring, walk-vs-ride by level, the "no mapped path"
   case, and the chat detail line.
3. Ran the Lua suite (RED). Output:
   ```
   155 passed, 5 failed
   FAIL: ground steps in the window :: shows each ground step's zone and levels on a second line
       test/test_ui.lua:270: attempt to index field 'detail' (a nil value)
   FAIL: ground steps in the window :: turns the detail amber for a hazard and leaves it dim otherwise
       test/test_ui.lua:277: attempt to index field 'detail' (a nil value)
   FAIL: ground steps in the window :: says Walk and warns about the zone for a low-level character
       test/test_ui.lua:283: values differ
       expected: "1. Walk to the North Gate"
       actual:   "1. Ride to the North Gate"
   FAIL: ground steps in the window :: labels a straight line when the crossings table has a hole
       test/test_ui.lua:291: attempt to index field 'detail' (a nil value)
   FAIL: ground steps in the window :: prints the detail under each step in chat too
       test/test_ui.lua:301: expected a truthy value, got "false"
   ```
   This is the expected RED: `row.detail` does not exist yet (old `Planner.lua` builds no detail
   FontString and `Refresh` sets none), and `Core.PlanRoute` never calls `Travel.For`/`API.Level`, so
   walk-vs-ride never changes. (The brief's example failure text, `attempt to call field 'Level'`,
   did not appear verbatim because the old `Core.PlanRoute` never calls `API.Level` in the first
   place — the fake's scripted `API` table already defines `Level`, so nothing tries to call a
   missing field; the actual failures are the `row.detail` ones and the stale "Ride" text, which are
   the same underlying gap the brief describes.)
4. Replaced `GoblinPS/API.lua`: added `API.Level()` and `UnitLevel` to `API.SelfCheck()`'s check list.
5. Replaced `GoblinPS/Core.lua`: `Core.PlanRoute` now reads `plan.level = API.Level()`, calls
   `ns.Travel.For(plan.level)` and passes `speed`/`walk` into `Route.Plan`'s opts; `routeTo` now
   prints each step's `Route.StepDetail` line under the step (amber/dim colour codes) in chat.
6. Replaced `GoblinPS/Planner.lua`: `MAX_ROWS` lowered from 12 to 8 (each step is now two lines);
   each row gets a third `detail` FontString anchored under `left`/`right`; `Refresh` fills it from
   `Route.StepDetail(ns.Data, step, plan.level)` and sets its colour to `W.COLOR.amber` or
   `W.COLOR.dim` based on the `warn` return.
7. Replaced `GoblinPS/GoblinPS.toc`: version bumped to `2026.09.19.3`; `Data\Crossings.lua`,
   `Data\Zones.lua` and `Travel.lua` added to the load order (already present as files from tasks 1-2,
   just not yet in this brief's TOC snapshot — now included in the order the brief specifies).
8. Ran the Lua suite again (GREEN):
   ```
   160 passed, 0 failed
   ```
   Matches the brief's expected count exactly.
9. Ran luacheck:
   ```
   Total: 0 warnings / 0 errors in 36 files
   ```
   Ran `lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=...`:
   ```
   GoblinPS\Planner.lua:46:63 [Warning] Need check nil. (need-check-nil)
                   detail, warn = ns.Route.StepDetail(ns.Data, step, plan.level)
                                                                    ^^^^
   GoblinPS\Planner.lua:46:68 [Warning] Undefined field `level`. (undefined-field)
                   detail, warn = ns.Route.StepDetail(ns.Data, step, plan.level)
                                                                        ^^^^^
   Diagnosis complete, 2 problems found
   ```
   Reported verbatim per instructions; did not touch the brief's code to silence it. Root cause: the
   language server's inferred type for `plan` (`Core.PlanRoute`'s return table) is built from the
   `plan.notes[1] = "..."` early-return branches, and does not see `plan.level = API.Level()` as
   always contributing a `level` field to every returned shape, so it treats `plan.level` as an
   access on a possibly-nil/unknown field. This is a pre-existing style of warning class for this
   codebase's dynamically-shaped return tables, not a real bug: `plan.level` is `nil` exactly when
   `API.Level()` returns `nil` (no level info), which `Route.StepDetail`/`ns.Travel.Dangerous` already
   handle as "no warning" (falsy `level`), consistent with the codebase's "never nil-index, always
   default to unknown" defensive style.
10. Committed with the exact `git add` file list the brief specifies.

## Files changed (all six listed by the brief)

- `D:\goblinps\GoblinPS\API.lua`
- `D:\goblinps\GoblinPS\Core.lua`
- `D:\goblinps\GoblinPS\Planner.lua`
- `D:\goblinps\GoblinPS\GoblinPS.toc`
- `D:\goblinps\test\fake_frames.lua`
- `D:\goblinps\test\test_ui.lua`

## Self-review

- Diffed each file against the brief's listing by eye during writing; all six match byte-for-byte
  content-wise (LF line endings written; git's `core.autocrlf` warns on checkout conversion only,
  which is a repo setting, not a content difference).
- Confirmed `git status` before staging showed exactly these six modified files and nothing else
  (nothing under `.superpowers/` was touched).
- Confirmed the TOC's paths still use single backslashes and the version line reads
  `## Version: 2026.09.19.3`.
- Attribution note: the brief's own `git commit` step 10 example text says
  `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Per this session's active attribution
  system-reminder (which explicitly states it replaces earlier/other attribution guidance and that
  only the user's own instructions override it — the brief is not the user's own instruction), the
  commit was made with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` instead, keeping
  everything else in the brief's exact command (same subject line, same two `-m` flags, same file
  list for `git add`).

## Concerns

- The lua-language-server warnings on `Planner.lua:46` (`need-check-nil`, `undefined-field` for
  `plan.level`) are reported as instructed, unresolved. They look like a language-server inference
  limitation given the codebase's existing pattern of loosely-typed plan/opts tables (the same
  pattern already exists elsewhere, e.g. `plan.hint`, `plan.result`, without complaint — `level` is
  new and apparently not yet inferred), rather than a functional problem; leaving for review/decision
  as directed rather than editing to silence it.
- Step 3's RED did not reproduce the brief's specific example wording (`attempt to call field
  'Level'`) verbatim, because the test's scripted fake `ns.API.Level` was already defined by the time
  the window/Core files ran (test_ui.lua defines it in the same edit as the RED step). The actual RED
  failures (nil `row.detail`, stale "Ride" text, no chat detail) point at the same real gap the brief
  is testing for. Noted per the common instructions to record what was actually seen.

## Fix round 1

Applied the four rulings in `task-3-fix-brief.md`. Files read before editing: `GoblinPS/Core.lua`,
`GoblinPS/Planner.lua`, `GoblinPS/Widgets.lua`, `GoblinPS/Route.lua`, `test/test_ui.lua`,
`test/test_route.lua`, `test/fake_frames.lua`.

### R1 — lua-language-server must report no problems

`GoblinPS/Core.lua`:
- `Core.PlanRoute` now builds `local plan = { to = to, notes = {}, level = API.Level() }` (was built
  without `level`, which was assigned later at what had been line 87).
- Deleted the later `plan.level = API.Level()` line; `ns.Travel.For(plan.level)` is unchanged.
- Added `level` (the character's level, or nil) to the doc comment above `Core.PlanRoute`.

`GoblinPS/Planner.lua`, `Planner.Refresh`:
- Added `local level = plan and plan.level or nil` right after `local plan = state.plan`, and changed
  `ns.Route.StepDetail(ns.Data, step, plan.level)` to `ns.Route.StepDetail(ns.Data, step, level)`.

No `---@class`/`---@field` annotation was needed: setting `level` in the table constructor was enough
for the language server to infer the field, so nothing was added beyond the ruling's first bullet, and
no `---@diagnostic disable` was used anywhere.

Verify command and output:
```
lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json
...
Diagnosis completed, no problems found
```
(Run twice — once right after the Core.lua/Planner.lua edits, once again after all four rulings were
applied — both times with that same result.)

### R2 — one palette for chat and window

Added to `GoblinPS/Widgets.lua` (after `Widgets.Panel`, before `Widgets.Text`):
```lua
function Widgets.ChatColor(name)
    local c = Widgets.COLOR[name] or Widgets.COLOR.dim
    return ("|cff%02x%02x%02x"):format(
        math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end
```
`GoblinPS/Core.lua`'s `routeTo` (around line 136) now reads:
```lua
say("     " .. ns.Widgets.ChatColor(warn and "amber" or "dim") .. detail .. "|r")
```
replacing the hard-coded `"|cfff0b54a"` / `"|cff9c8f6d"` escapes.

Added a new block in `test/test_ui.lua`, right before `h.describe("the planner window", ...)`:
```lua
h.describe("Widgets.ChatColor", function()
    h.it("matches the formula for the palette entry, in chat and in the window", function()
        h.eq(ns.Widgets.ChatColor("amber"), "|cfff0b54a")
        local dim = ns.Widgets.COLOR.dim
        local expect = ("|cff%02x%02x%02x"):format(
            math.floor(dim[1] * 255 + 0.5), math.floor(dim[2] * 255 + 0.5), math.floor(dim[3] * 255 + 0.5))
        h.eq(ns.Widgets.ChatColor("dim"), expect)
    end)
end)
```
This test cannot RED against the old code (the helper did not exist at all before this round; there is
nothing to regress against), so only GREEN evidence applies: it passed as part of the full-suite run
below. Hand check of the formula for `amber = {0.94, 0.71, 0.29}`: `floor(0.94*255+0.5)=240=0xf0`,
`floor(0.71*255+0.5)=181=0xb5`, `floor(0.29*255+0.5)=74=0x4a` → `|cfff0b54a`, matching the ruling's
literal and confirming `Core.lua`'s old hard-coded amber escape was already correct (only the "dim"
one had drifted, per the brief).

### R3 — tighter colour assertions

In `test/test_ui.lua`'s `"ground steps in the window"` block, extended two `h.it` cases to compare all
three channels of `row.detail.color` against the palette entry instead of only `color[1]`:
- `"turns the detail amber for a hazard and leaves it dim otherwise"`: added channel-2 and channel-3
  assertions for both the amber row and the dim row.
- `"says Walk and warns about the zone for a low-level character"`: added channel-2 and channel-3
  assertions for the amber row.

These are stronger assertions on existing passing behaviour, not a new failing case, so there is no RED
to show; they were confirmed GREEN in the full-suite run below (and would have caught, for instance, a
copy-paste that set `SetTextColor` with the wrong green/blue channel while channel 1 happened to match).

### R4 — Dijkstra tie-break by key

`GoblinPS/Route.lua`, `shortest` (line 16), changed:
```lua
if not done[key] and d < best then
```
to:
```lua
if not done[key] and (d < best or (d == best and bestKey and key < bestKey)) then
```

Added `test/test_route.lua`, a new `h.describe("Route.Find tie-breaking", ...)` block (placed after the
`Route.Plan` block, before `"a zone destination"`), building a hand-written graph — `stops.START`,
`stops.DEST`, and two middle stops `mid_a`/`mid_b`, each `{ key = ..., name = ... }` — with `START`
reaching `DEST` through either middle stop at exactly 20 seconds total (10 + 10 both ways). `START`'s
edge list deliberately lists `mid_b` before `mid_a`, so an order-of-insertion tie-break (the bug) picks
the wrong one, while a key-based tie-break always picks `mid_a` (it sorts first). The test calls
`Route.Find(graph)` five times and asserts `r.raw[1].to.key == "mid_a"` every time.

RED, captured by temporarily reverting only the one-line `Route.lua` change and rerunning the suite
(then restoring the fix — confirmed via `git diff` that the restored file exactly matches the intended
one-line change, nothing else changed):
```
1
161 passed, 1 failed
FAIL: Route.Find tie-breaking :: always goes through the stop whose key sorts first when two routes tie exactly
    test/test_route.lua:83: values differ
    expected: "mid_a"
    actual:   "mid_b"
```
This confirms the edge order (`mid_b` first) is what exposes the old bug in this Lua 5.1 runtime: a
smaller repro that listed `mid_a` first happened to already pick `mid_a` under the old code by
insertion-order coincidence, so it would not have shown RED — traced by hand with a standalone lupa
script before settling on the `mid_b`-first ordering that does fail under the bug.

GREEN, after restoring the fix:
```
0
162 passed, 0 failed
```

### Final checks (all four rulings applied together)

Lua suite:
```
0
162 passed, 0 failed
```
Python tests:
```
Ran 18 tests in 0.043s
OK
```
luacheck:
```
Total: 0 warnings / 0 errors in 36 files
```
lua-language-server:
```
Diagnosis completed, no problems found
```

### Files changed this round

- `GoblinPS/Core.lua` — R1 (plan table + doc comment), R2 (ChatColor call site)
- `GoblinPS/Planner.lua` — R1 (nil-safe level local)
- `GoblinPS/Widgets.lua` — R2 (new `Widgets.ChatColor` helper)
- `GoblinPS/Route.lua` — R4 (tie-break by key)
- `test/test_ui.lua` — R2 (new ChatColor assertion), R3 (tighter colour assertions)
- `test/test_route.lua` — R4 (new tie-break test)

`test/fake_frames.lua` was read (per the brief's list) but needed no change: `SetTextColor` already
records all three channels via `Region:SetTextColor(r, g, b) self.color = { r, g, b } end` from the
prior task, which is what makes R3's tighter assertions possible.

### Concerns

None. All four rulings applied as specified; no ruling proved impossible. Cannot verify anything in
the live game client; nothing here claims to.

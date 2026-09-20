# Scoped re-review — final fix wave, GoblinPS ground crossings

Reviewed commits `981e045`, `8399fe6`, `ed9e8ba` (branch `ground-crossings`, checked out, not switched, not
committed). `c3bc9a7` and later commits on the branch are out of scope and were not judged. `git diff 051e935..ed9e8ba`
matches `review-051e935..ed9e8ba.diff` exactly (`git diff --stat` on the same range, `images` excluded, produced the
same 11 files).

## Verdict: **approved**

All nine F-items are done, done completely, and none breaks anything else. All four gates are green. The three
documentation edits in commit 3 match the brief's specified wording verbatim, including the manual-checklist
reordering. Ten planned routes over the real data (three named by the brief, both directions through Blackrock
Mountain and the Timbermaw tunnels, two overflow routes) show correct names, correct once-per-traversal `cross`
costs, correctly-ordered and correctly-truncated detail text, and no `(no mapped path)` gaps. One minor test-coverage
gap is noted below; it is not a functional defect (verified by a direct synthetic call, not just by reading code).

## F-item table

| Item | Verdict | Evidence |
|---|---|---|
| F1 names read both ways | Done | `GoblinPS/Data/Crossings.lua` — all 30 rename-table rows checked one by one against the brief's table; every new name matches exactly (e.g. line 35 `the Mulgore pass`, line 48 `the Ashenvale-Felwood road`, lines 93-95 the three Riverglades border names). All 21 "leave as is" names (line 29 `Orgrimmar's front gate` … line 92 `the Riverglades turnoff`) are byte-for-byte unchanged. Guard test `test/test_crossings.lua:33-42` ("names read the same whichever way you are going"). |
| F2 `cross` seconds | Done | `GoblinPS/Graph.lua:150-153`: `seconds = seconds + q.cross` is added only when `q` (the edge's destination) is the crossing stop; a crossing's own stop never carries this addition when it is the edge's *origin* (departure), so it is paid exactly once per traversal, in both directions of travel, and whether or not the crossing is the router's final destination. `test/test_graph.lua:153-176` confirms with a synthetic tunnel. Values match the brief exactly: Blackrock Mountain 120 (`Crossings.lua:78`), Timbermaw Hold tunnels 90×3 (lines 50, 52, 55), Dun Algaz tunnels 90 (line 74), Darkwhisper Gorge 60 (line 54), the Great Lift 45 (line 39), the Thunder Bluff lifts 30 (line 31), the Talondeep Path 45 (line 46). |
| F3 `unverified` shown | Done | `Graph.lua:120` copies `unverified` onto the crossing stop; `Route.lua:203,211-213` appends " · crossing not confirmed" and forces `warn = true`. `test/test_crossings.lua:48-66` pins exactly 7 rows (the 6 new-zone rows plus Orgrimmar's west gate, `Crossings.lua:30`) and asserts `count == 7`; verified directly against the file — no other row carries `unverified = true`. |
| F4 pinch points | Done | `test/test_crossings.lua:69-84`. Hand-counted against `Crossings.lua` directly: Un'Goro Crater 2 (lines 42,43), Silithus 1 (43), Moonglade 2 (lines 52,55), Dustwallow Marsh 1 (38), Teldrassil 1 (32), Blasted Lands 1 (89), Darnassus 1 (32), Azshara 1 (49). All match. |
| F5 `legal`'s nil case | Done | `Graph.lua:18-19`: "nil means open to both: only crossings and links carry a faction at all, and most crossings have none." |
| F6 hazard never truncated | Done | `Route.lua:202-213`: level clause is added only in the `else` branch, i.e. only when neither `step.to.warn` nor `step.to.unverified` is set; the hazard is appended first, the unconfirmed note second. Confirmed both by reading and by a synthetic combined call (see Findings). 66-char test `test/test_crossings.lua:187-197` runs over `data.Crossings` (the real table) in both directions (`for _, from in ipairs({x.a, x.b})`). Ten real routes planned in the scratchpad script (see Routes below) show every detail line ≤ 65 chars. |
| F7 do not say the obvious | Done | `Route.lua:196-200`: only in the non-gate branch, returns `"", false` when `ns.Search.ShortName(step.to.name) == places[zone].name`. `test/test_route.lua:186-190` confirms. |
| F8 last step always visible | Done | `GoblinPS/Planner.lua:38-49`. Traced the arithmetic for `#steps == MAX_ROWS` (no overflow row, all steps shown), `MAX_ROWS+1` (`N = #steps - headCount - 1 = 2`, one step at `MAX_ROWS-1` overflow row, last step at `MAX_ROWS`), and a 20-step case (`headCount=6`, `N=13`, `6+13+1=20`, no double-count, no skip). `test/test_ui.lua:205-217` pins the `MAX_ROWS=3`/5-step case row by row. |
| F9 one source of mount speed | Done | `Graph.RIDE_YARDS_PER_SECOND` is gone from `Graph.lua`; `grep` across `GoblinPS/` and `test/` for `RIDE_YARDS_PER_SECOND` finds nothing (only stale historical plan docs under `docs/superpowers/plans/`, which are out of scope). `Graph.lua:28`: `speed or ns.Travel.MOUNTS[1].yardsPerSecond` — a Lua default-argument expression evaluated inside the function body, i.e. at call time, not at module load. `Travel.lua:12-14` is the only place a mount speed number appears in `GoblinPS/`. |
| Commit 3 docs | Done | `CLAUDE.md:10` clause removed, `CLAUDE.md:150-151` sentence added to the ground-travel rule. `docs/superpowers/specs/2026-09-19-goblinps-design.md:121-128` and `:178-186` match the brief's wording. `docs/manual-test-checklist.md:176-177` — Orgrimmar's west gate moved to the top of "## Ground crossings (plan 3)" with "FIRST: every Horde route north depends on it." in front; lines 200-209 add the four new checklist items verbatim; line 183 updates the stale crossing name. |

## Findings

**Minor — hazard+unverified ordering is untested by any row in real data (test-coverage gap, not a defect).**
No row in `GoblinPS/Data/Crossings.lua` currently sets both `warn` and `unverified = true` (Timbermaw rows have
`warn` only; Darkwhisper Gorge has `unverified` only), so the 66-char test and the route-planning below never
exercise the "hazard, then unconfirmed" ordering rule that F6 added. I confirmed the ordering is implemented
correctly by direct code reading (`Route.lua:208-213`, hazard clause before unconfirmed clause) and by calling
`Route.StepDetail` on a synthetic combined step from the scratchpad harness:

```
step.to = { zones = {1413, 1448}, warn = "a made-up hazard", unverified = true, name = "a synthetic crossing" }
Route.StepDetail(data, step, 60)
=> "into Felwood · a made-up hazard · crossing not confirmed", warn = true   (58 chars)
```

This is correct and matches the brief's ruling exactly. It is not a defect in the fix wave — it is a suggestion that
if a future row ever carries both fields, there is currently no automated test that would catch a regression in
their order. Not blocking.

No Critical or Important findings.

## Gates (all green)

**Lua tests:**
```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
0
168 passed, 0 failed
```
(Brief's "current state" baseline before the wave was 162 passed; the wave added 6 new tests — the F1 guard, the F3
unverified pin, the F4 pinch-point counts, the F2 graph cost test, the F6 66-char test, and the F8 overflow rewrite —
which accounts for the delta.)

**Python tests:**
```
python -m unittest discover -s test/tools
Ran 18 tests in 0.035s
OK
```

**luacheck:**
```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"; $env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"; lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
Total: 0 warnings / 0 errors in 36 files
```

**lua-language-server:**
```
lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls-rereview.json
Diagnosis completed, no problems found
[]
```

## Planned routes (real data, via a scratchpad script loading modules the way `test/run.lua` does)

Script: `C:\Users\druid\AppData\Local\Temp\claude\D--goblinps\8d6893be-78b4-43f6-840f-8dd1fefd4055\scratchpad\plan_routes.lua`
(scratchpad only, not staged, not part of the repo).

```
==== Tirisfal Glades -> Mount Hyjal (level 60, no known flights) ====
  steps: 8   total: ~30 min (1800.7580903917s)   copper: 0
  1. Ride to Undercity Zeppelin Tower   [32 chars]
     -> in Tirisfal Glades · level 1-10   [32 chars, warn=false]
  2. Zeppelin to Orgrimmar Zeppelin Tower (~4 min incl. wait)   [56 chars]
  3. Ride to Orgrimmar's front gate   [30 chars]
     -> into Orgrimmar   [14 chars, warn=false]
  4. Ride to Orgrimmar's west gate   [29 chars]
     -> into The Barrens · crossing not confirmed   [42 chars, warn=true]
  5. Ride to the Mor'shan Rampart   [28 chars]
     -> into Ashenvale · level 18-30   [29 chars, warn=false]
  6. Ride to the Ashenvale-Felwood road   [34 chars]
     -> into Felwood · level 48-55   [27 chars, warn=false]
  7. Ride to the Timbermaw Hold tunnels   [34 chars]
     -> into Winterspring · Timbermaw furbolgs attack without reputation   [65 chars, warn=true]
  8. Ride to Darkwhisper Gorge   [25 chars]
     -> into Mount Hyjal · crossing not confirmed   [42 chars, warn=true]

==== Orgrimmar -> Undercity (level 60, no known flights) ====
  steps: 4   total: ~6 min (345.11259810275s)   copper: 0
  1. Ride to Orgrimmar's front gate   [30 chars]
     -> into Durotar · level 1-10   [26 chars, warn=false]
  2. Ride to Orgrimmar Zeppelin Tower   [32 chars]
     -> in Durotar · level 1-10   [24 chars, warn=false]
  3. Zeppelin to Undercity Zeppelin Tower (~4 min incl. wait)   [56 chars]
  4. Ride to the Ruins of Lordaeron   [30 chars]
     -> into Undercity   [14 chars, warn=false]

==== Ironforge -> Gadgetzan (level 60, no known flights) ====
  steps: 9   total: ~30 min (1788.4916538023s)   copper: 0
  1. Ride to the gates of Ironforge   [30 chars]
     -> into Dun Morogh · level 1-10   [29 chars, warn=false]
  2. Ride to the Valley of Kings gates   [33 chars]
     -> into Loch Modan · level 10-20   [30 chars, warn=false]
  3. Ride to the Dun Algaz tunnels   [29 chars]
     -> into Wetlands · level 20-30   [28 chars, warn=false]
  4. Ride to Menethil Harbor Docks   [29 chars]
     -> in Wetlands · level 20-30   [26 chars, warn=false]
  5. Boat to Theramore Docks (~4 min incl. wait)   [43 chars]
  6. Ride to the Dustwallow road   [27 chars]
     -> into The Barrens · level 10-25   [31 chars, warn=false]
  7. Ride to the Great Lift   [22 chars]
     -> into Thousand Needles · level 25-35   [36 chars, warn=false]
  8. Ride to the Thousand Needles-Tanaris pass   [41 chars]
     -> into Tanaris · level 40-50   [27 chars, warn=false]
  9. Ride to Gadgetzan   [17 chars]
     -> in Tanaris · level 40-50   [25 chars, warn=false]

==== Searing Gorge -> Burning Steppes (through Blackrock Mountain) ====
  steps: 1   total: ~3 min (190.39364259779s)   copper: 0
  1. Ride to Blackrock Mountain   [26 chars]
     -> into Burning Steppes · through Blackrock Mountain   [50 chars, warn=true]

==== Burning Steppes -> Searing Gorge (through Blackrock Mountain, reverse) ====
  steps: 1   total: ~4 min (225.50755897874s)   copper: 0
  1. Ride to Blackrock Mountain   [26 chars]
     -> into Searing Gorge · through Blackrock Mountain   [48 chars, warn=true]

==== Felwood -> Winterspring (through the Timbermaw Hold tunnels) ====
  steps: 1   total: ~5 min (301.99998152975s)   copper: 0
  1. Ride to the Timbermaw Hold tunnels   [34 chars]
     -> into Winterspring · Timbermaw furbolgs attack without reputation   [65 chars, warn=true]

==== Winterspring -> Felwood (through the Timbermaw Hold tunnels, reverse) ====
  steps: 1   total: ~5 min (309.36174443264s)   copper: 0
  1. Ride to the Timbermaw Hold tunnels   [34 chars]
     -> into Felwood · Timbermaw furbolgs attack without reputation   [60 chars, warn=true]

==== Felwood -> Moonglade (through the Timbermaw Hold tunnels) ====
  steps: 1   total: ~6 min (365.95183553087s)   copper: 0
  1. Ride to the Timbermaw Hold tunnels   [34 chars]
     -> into Moonglade · Timbermaw furbolgs attack without reputation   [62 chars, warn=true]

==== Tirisfal Glades -> Silithus (overflow candidate, no known flights) ====
  steps: 7   total: ~33 min (1980.8966164926s)   copper: 0
  1. Ride to Undercity Zeppelin Tower   [32 chars]
     -> in Tirisfal Glades · level 1-10   [32 chars, warn=false]
  2. Zeppelin to Orgrimmar Zeppelin Tower (~4 min incl. wait)   [56 chars]
  3. Ride to the Southfury bridge   [28 chars]
     -> into The Barrens · level 10-25   [31 chars, warn=false]
  4. Ride to the Great Lift   [22 chars]
     -> into Thousand Needles · level 25-35   [36 chars, warn=false]
  5. Ride to the Thousand Needles-Tanaris pass   [41 chars]
     -> into Tanaris · level 40-50   [27 chars, warn=false]
  6. Ride to the Un'Goro ramp from Tanaris   [37 chars]
     -> into Un'Goro Crater · level 48-55   [34 chars, warn=false]
  7. Ride to the Un'Goro-Silithus ramp   [33 chars]
     -> into Silithus · level 55-60   [28 chars, warn=false]

==== Ironforge -> Silithus (overflow candidate, no known flights) ====
  steps: 10   total: ~38 min (2269.5655609056s)   copper: 0
  1. Ride to the gates of Ironforge   [30 chars]
     -> into Dun Morogh · level 1-10   [29 chars, warn=false]
  2. Ride to the Valley of Kings gates   [33 chars]
     -> into Loch Modan · level 10-20   [30 chars, warn=false]
  3. Ride to the Dun Algaz tunnels   [29 chars]
     -> into Wetlands · level 20-30   [28 chars, warn=false]
  4. Ride to Menethil Harbor Docks   [29 chars]
     -> in Wetlands · level 20-30   [26 chars, warn=false]
  5. Boat to Theramore Docks (~4 min incl. wait)   [43 chars]
  6. Ride to the Dustwallow road   [27 chars]
     -> into The Barrens · level 10-25   [31 chars, warn=false]
  7. Ride to the Great Lift   [22 chars]
     -> into Thousand Needles · level 25-35   [36 chars, warn=false]
  8. Ride to the Thousand Needles-Tanaris pass   [41 chars]
     -> into Tanaris · level 40-50   [27 chars, warn=false]
  9. Ride to the Un'Goro ramp from Tanaris   [37 chars]
     -> into Un'Goro Crater · level 48-55   [34 chars, warn=false]
  10. Ride to the Un'Goro-Silithus ramp   [33 chars]
     -> into Silithus · level 55-60   [28 chars, warn=false]
```

Observations from these routes:
- The Tirisfal → Mount Hyjal route matches `docs/manual-test-checklist.md`'s pinned sequence exactly (zeppelin,
  Orgrimmar's front gate, Orgrimmar's west gate, the Mor'shan Rampart, the Ashenvale-Felwood road, the Timbermaw
  Hold tunnels, Darkwhisper Gorge) and is exactly 8 steps.
- Every detail line printed across all ten routes is 65 characters or fewer; none is truncated; no name reads
  backwards for the direction travelled; no passage time is missing or doubled (Blackrock Mountain and the
  Timbermaw tunnels each add their `cross` seconds exactly once, confirmed against `Graph.RideSeconds` by code
  reading since the scratchpad harness prints only the final total).
- Orgrimmar's west gate and Darkwhisper Gorge both show "crossing not confirmed" with no level clause; the two
  Timbermaw rows show the hazard with no level clause; all other ground steps still show their level range.
- The Ironforge → Silithus route naturally overflows the planner's 8-row `MAX_ROWS` (10 steps), confirming the F8
  fix is exercised by real, not just synthetic, data — though the planner's row-painting itself is only exercised by
  the `test/test_ui.lua` fake-frame suite (this scratchpad harness does not load `Planner.lua`, which touches
  Blizzard globals it cannot fake here).
- No route produced "(no mapped path)".

I cannot run the game client and make no claim about in-game behaviour; all of the above is from the desktop tests
and the scratchpad script against the real, checked-in data.

# Overnight review: b09ba4c..987ce18 (branch ground-crossings)

Reviewed read-only. No files in the real repo were changed; scratch copies used
for the mutation test and the independent geometry re-derivation lived under
the session scratchpad and a temp folder, not under D:\goblinps.

## Verdict: approved with minors

Nothing here is unsafe, destructive, or reaches outside the stated scope. The
geometry and the counting logic are correct by independent re-derivation. The
defects found are a real test-coverage gap and a documented-contract
violation, both fixable in a few lines; neither should block merging the
branch, but both are worth the owner's five minutes.

## The four changes

| # | Change | Verdict | Evidence |
|---|---|---|---|
| 1 | `tools/survey_crossings.lua` + `test_crossings.lua` strip test | **Good** | Geometry independently re-derived from raw `Places.lua`/`Crossings.lua` data with a fresh script (not reusing the tool): got the same 6 offenders at the same distances (250, 192, 110, 75, 72, 7 yards) as both the tool's own output and the table in the checklist. Mutating one coordinate in a scratch copy flipped the pinned count from 6 to 7 and failed with a clear message — the test is not a rubber stamp. |
| 2 | `/gps probe zones` (`API.ZoneLevels`, `Core.probeZones`, tests) | **Minors** | `API.lua` rule respected. Counting logic (agree/differ/unlisted/lost) verified correct by hand-trace. But the new tests never exercise the "we list it, client doesn't answer" (`lost`) branch — see Important #1. `GoblinPSDB.probe.zones` write bypasses `Prefs.lua`'s own stated scope — see Important #2. Chat output is capped (12 lines + summary), not a flood risk. |
| 3 | `.gitignore` + `images/parts/README.md` (39 TGAs untracked) | **Good** | Ran `python images/parts/export_tga.py`: regenerates all 39 TGAs byte-for-byte, confirming the tool still works and nothing was lost. `git status` after regenerating showed only the pre-existing untracked `AGENTS.md` — the ignore pattern works. No other file in the repo references the removed tracked TGAs; `check_art.py` and the art brief only ever touch the PNGs. Cleaned up the regenerated TGAs afterward. |
| 4 | `docs/manual-test-checklist.md` rewrite (+ research doc addendum) | **Minors** | Every factual claim I could check against the repo or the pinned `forever` UI source checked out true (see below). The "six items block the merge, everything else doesn't" framing is an editorial call the agent made unilaterally — reasonable and well-supported, but flagged under over-reach below. |

## Findings

### Critical
None.

### Important

**1. The new `/gps probe zones` tests don't test what their own comments say they test.**
`test/test_ui.lua:18-21` sets up `clientLevels` and comments: *"Isle has a range
we do not list, and Lostland answers nothing though we do list it."* That
implies `Data.Zones` has an entry for Lostland (map 5). It does not:
`test/fake_world.lua:19` reads `Zones = { [1] = { 1, 10 }, [4] = { 30, 40 } }` —
no key `5`. Neither new test (`test/test_ui.lua:384` and `:398`) ever asserts
on `by[5]`, or on the "N we list and it does not" (`lost`) count in the printed
text. So the fourth of the four combinations the feature is supposed to
handle — client silent, we have a row — is exercised by nothing. I hand-traced
`Core.probeZones` (`GoblinPS/Core.lua:170-214`) and the `lost` branch looks
correct (`elseif ours then lost = lost + 1 end`, message
`"%d we list and it does not."` fed `lost`), but a regression there (wrong
branch, swapped `unlisted`/`lost` argument order, off-by-one) would pass every
existing test. Fix: add `[5] = { 20, 25 }` (or similar) to `fake_world.lua`'s
`Zones` table and assert on it, or add a dedicated case. This is a real gap,
not a style nit — the task explicitly asked "can each test actually fail?"
and this one branch's answer is no.

**2. `GoblinPSDB.probe.zones` violates `Prefs.lua`'s own documented scope.**
`GoblinPS/Prefs.lua:3-5`: *"Pure: the account-wide preferences table
(GoblinPSDB). Preferences, recent destinations and window positions only."*
`Core.probeZones` (`GoblinPS/Core.lua:203`) writes `prefs().probe = { zones =
dump }` directly onto that same table, and `Prefs.Init` was not touched to
default or manage a `probe` field. Functionally it's harmless (Lua tables
tolerate extra keys, and nothing else reads `db.probe` back), and it's a
reasonable one-off way to get a large diagnostic table onto the desk via
SavedVariables — but it contradicts the file's own header, which nobody
updated. Either update the `Prefs.lua` comment to acknowledge the new use, or
put the diagnostic dump in its own global (not `GoblinPSDB`) so the
preferences table keeps growing only when its whitelisted operations touch
it. Small fix, but the codebase makes a point of exactly-scoped comments
(`API.lua`'s "the ONLY file..." for example), so this deserves a decision
either way, not silence.

### Minor

**3. Pinning `offenders == 6` is a deliberately brittle tripwire — by design, not a mistake.**
`test/test_crossings.lua:150` hard-codes 6. The comment explains this is
intentional: fixing a crossing in game is meant to turn the test red as a
prompt to update the checklist table too. That's a defensible pattern (a
"living document" test), but it is genuinely brittle: every real coordinate
fix requires touching this test file, and a future contributor who doesn't
read the comment could be annoyed by an assertion that reads as arbitrary. Not
a defect — a matter of taste. If it were mine, I'd keep it; the alternative
(no pinned count) lets the crossing table and the checklist silently drift
apart, which is the worse failure mode for hand-typed coordinates.

**4. The "same condition... measured in yards" claim in the new test's comment slightly overstates the relationship.**
`near()` (existing, `test_crossings.lua:16-20`) and `fromSharedEdge()` (new)
are not the same check with a different unit — they use different slack
strategies (10% of each zone's own rectangle vs. a flat 300-yard distance to
the *unpadded* intersection of both rectangles), and this matters: all 56 rows
already pass `near()` today, while 6 fail the new test. So the two are
complementary, not redundant, exactly because a fixed-yard test catches what a
percentage-of-a-huge-zone slack cannot (the comment says as much a few lines
later, about the Barrens' 10% being "over a thousand yards" — so the author
clearly understood this; the topic sentence just states the shared
*intuition* more strongly than the literal math). Not a bug; worth a precise
read if anyone revisits the comment.

**5. Two source citations in the research doc are a few lines off.**
`docs/research/2026-09-19-api-and-data-findings.md` cites
`Blizzard_SharedMapDataProviders/AreaLabelDataProvider.lua:86` for the
`C_Map.GetMapLevels` call — checked against the pinned `D:\wow-api\1.60.1.69913`
clone (`forever`, `version.txt` matches) and is exactly right, line 86, guard
`> 0` on the next line as described. `MapDocumentation.lua:346` is cited for
`MayReturnNothing`; line 346 is actually the opening `{` of the `GetMapLevels`
doc block (`Name = "GetMapLevels"` is 347, `MayReturnNothing = true` is 349).
Correct block, off by up to three lines. Trivial, but since the whole point of
this doc is "verified in source, cite it precisely," worth a one-line fix.

**6. The DB2 dead-end claim (ContentTuningID all zero, no WorldMapArea table) was not independently re-checked.**
I had no network access and the local `tools/cache/` is empty (gitignored), so
I could not pull `wago.tools` CSVs myself to confirm this. It's presented
consistent with the project's own "verified in source vs. unverified in game"
discipline (it doesn't claim to be verified in-game), so I'm not calling it
wrong — just noting I couldn't check it, so it's still resting on the
overnight agent's own say-so.

## Over-reach

- **The checklist's "Start here" ordering asserts a merge-readiness
  conclusion** ("Plans 2 and 3 are built, reviewed and unmerged, waiting only
  on this... the list below is everything blocking the merge") that the owner
  did not ask for and might reasonably want to make themselves. Every
  individual claim inside it checked out true against the code and commit
  history (verified below), so this isn't fabricated — but deciding *what
  counts as a merge blocker* is a judgment call, and an unattended agent
  asserting it as settled fact is a step further than "write the checklist."
  Not harmful (nothing was actually merged), just worth the owner's eyes
  before treating the list as gospel.
- Everything else is squarely inside what was asked: a survey tool for a
  named suspicion (bad coordinates), a probe command following the exact
  pattern of the existing `/gps probe`, a build-hygiene fix for an
  oversized-file complaint already logged in `.remember/now.md`, and checklist
  updates. No scope creep into unrelated files, no dependency additions, no
  behavior changes to shipped routing/UI code.

## Claims checked against code/history and confirmed true

- TOC restart requirement: `GoblinPS.toc` last changed in `587b3cd` (adds
  `Data/Crossings.lua`, `Data/Zones.lua`, `Travel.lua`), which is an ancestor
  of `b09ba4c` (`git merge-base --is-ancestor` confirms) — i.e. the TOC change
  predates this review's range and predates any in-game session since, so
  "restart, not /reload" is accurate, not stale.
- Checklist item 2 ("the one plan 2 fix nobody has confirmed," a dropdown
  click surviving focus loss) is a real, already-committed fix:
  `2341cf2 Planner: a click on the results list survives the box losing
  focus`.
- Checklist's selftest/icon paragraph: `tools/make_icon.py` does write
  `GoblinPS/Media/icon.tga` via Pillow; `SelfTest.lua:15,21-23` does call
  `SetTexture` on exactly that path and reports pass/fail on its return value.
- The crossing table in the checklist matches an independent re-derivation
  from `Places.lua`/`Crossings.lua` exactly (see below).

## Independent re-derivation of the crossing survey

Wrote a fresh Python script (not reusing `tools/survey_crossings.lua`) that
parses `GoblinPS/Data/Places.lua` and `GoblinPS/Data/Crossings.lua` directly,
reimplements `Geo.ToWorld` and the rectangle-overlap distance from scratch,
and ranks all 56 rows. Result, independently:

```
250  the Timbermaw Hold tunnels     Felwood / Moonglade
192  the Feralas-Desolace road      Feralas / Desolace
110  Darkwhisper Gorge              Winterspring / Mount Hyjal   (unverified=True)
 75  the Timbermaw Hold tunnels     Winterspring / Moonglade
 72  Orgrimmar's west gate          Orgrimmar / The Barrens      (unverified=True)
  7  the Ruins of Lordaeron         Undercity / Tirisfal Glades
```

Matches the tool's own output and the table in `docs/manual-test-checklist.md`
exactly, including which two are already flagged `unverified`. Also confirmed
`Geo.ToWorld` is the exact algebraic inverse of `world_to_map` in
`tools/build_graph.py` (worked the substitution by hand: `mx = (y1-wy)/(y1-y0)`,
`my = (x1-wx)/(x1-x0)` inverts cleanly to the formulas in `Geo.lua`), so the
"map x runs along world -y, map y along world -x" comment is correct.

## Mutation test (scratch copy only)

Copied `GoblinPS/`, `test/`, `tools/` into the session scratchpad. Changed the
Southfury bridge row's `mx, my` from `(0.345, 0.425)` to `(0.020, 0.001)` —
still inside Durotar's own map, but far enough to leave the Durotar/Barrens
shared strip. Reran the suite:

```
FAIL: the crossings table :: puts every point on the strip its two zones share
    test/test_crossings.lua:150: rows off the shared edge; worst is the Timbermaw
    Hold tunnels at 249 yards
    expected: "6"
    actual:   "7"
```

The test catches a real, non-obvious coordinate error (this one didn't even
leave the zone's own valid map area). Nothing in the real repository was
touched; the scratch copy is disposable.

## Gate output (verbatim)

**Lua suite (lupa):**
```
0
174 passed, 0 failed
```

**`python -m unittest discover -s test/tools`:**
```
Ran 18 tests in 0.032s
OK
```
(the "skip zone 1700 Zephras Isle" / "skip node 2 Stormwind, Elwynn" lines are
pre-existing informational prints from the discovery tests, not failures.)

**`python tools/check_art.py`:**
```
39 pass, 0 with problems, 0 not drawn yet
```
All 39 parts, including `screen-backdrop.png`, which now correctly requires
opaque (not transparent) corners under the new `"solid"` flag in
`tools/check_art.py`.

**luacheck (`GoblinPS test tools`):**
```
Total: 0 warnings / 0 errors in 37 files
```

**lua-language-server (`--checklevel=Warning`):**
```
Diagnosis completed, no problems found
```

## Summary for the owner

Approved with minors. The two Important items (untested `lost` branch in the
new probe-zones tests, and the `GoblinPSDB.probe` write ignoring `Prefs.lua`'s
stated scope) are both quick fixes and don't affect anything already shipped.
The crossing-survey geometry is solid — I re-derived it independently and
tried to break the pinned test, and both held up. The one thing most worth
your attention: the checklist now unilaterally declares six items as *the*
merge blockers for plans 2 and 3; every individual fact behind that claim
checked out, but the judgment call itself ("this and only this is what's
blocking merge") is one the agent made for you rather than for you to make.

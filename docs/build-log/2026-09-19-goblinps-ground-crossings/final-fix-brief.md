# Final-review fix wave — GoblinPS ground crossings

Repo `D:\goblinps`, branch `ground-crossings` (checked out). Commands and commit rules: `implementer-common.md` in this
folder (ignore its "transcribe byte-for-byte" paragraph: this wave changes data, code and docs; test-first where a
desktop test can see it). Smallest change per ruling. Three commits:

    git commit -m "Crossings: names that read both ways, passage times, unconfirmed rows shown" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
    git commit -m "Planner and route text: hazard first, last step always visible, one source of mount speed" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
    git commit -m "Docs: crossings follow-ups from the final review" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"

Current state: Lua `162 passed, 0 failed`, Python 18 OK, luacheck 0, lua-language-server clean. Keep all four green.
Read each file before changing it. An untracked `AGENTS.md` in the repo root is not yours: never stage it.

## Commit 1: the crossings data (`GoblinPS/Data/Crossings.lua`, `GoblinPS/Graph.lua`, `GoblinPS/Route.lua`, tests)

**F1. Names must read the same in both directions (Important).** `Route.StepText` prints a row's one name whichever way the
leg runs, so "Walk to the road into Felwood" appears on the way OUT of Felwood with the detail "into Ashenvale". Rename
every directional row to a landmark or a neutral pair name. Use exactly these names (rows identified by their zone pair):

| Zones (a, b) | New name |
|---|---|
| 1413, 1412 The Barrens, Mulgore | the Mulgore pass |
| 1413, 1445 The Barrens, Dustwallow Marsh | the Dustwallow road |
| 1441, 1444 Thousand Needles, Feralas | the Feralas-Thousand Needles road |
| 1441, 1446 Thousand Needles, Tanaris | the Thousand Needles-Tanaris pass |
| 1446, 1449 Tanaris, Un'Goro Crater | the Un'Goro ramp from Tanaris |
| 1449, 1451 Un'Goro Crater, Silithus | the Un'Goro-Silithus ramp |
| 1444, 1443 Feralas, Desolace | the Feralas-Desolace road |
| 1443, 1442 Desolace, Stonetalon Mountains | the Charred Vale pass |
| 1440, 1439 Ashenvale, Darkshore | the Ashenvale-Darkshore road |
| 1440, 1448 Ashenvale, Felwood | the Ashenvale-Felwood road |
| 1440, 1447 Ashenvale, Azshara | the Ashenvale-Azshara road |
| 1448, 1450 Felwood, Moonglade | the Timbermaw Hold tunnels |
| 1452, 1450 Winterspring, Moonglade | the Timbermaw Hold tunnels |
| 1420, 1421 Tirisfal Glades, Silverpine Forest | the Tirisfal-Silverpine road |
| 1421, 1424 Silverpine Forest, Hillsbrad Foothills | the Silverpine-Hillsbrad road |
| 1424, 1416 Hillsbrad Foothills, Alterac Mountains | the Hillsbrad-Alterac road |
| 1424, 1425 Hillsbrad Foothills, The Hinterlands | the Hillsbrad-Hinterlands road |
| 1416, 1422 Alterac Mountains, Western Plaguelands | the Alterac-Plaguelands road |
| 1432, 1418 Loch Modan, Badlands | the Loch Modan-Badlands road |
| 1418, 1427 Badlands, Searing Gorge | the Badlands-Searing Gorge pass |
| 1428, 1433 Burning Steppes, Redridge Mountains | the Burning Steppes-Redridge pass |
| 1433, 1431 Redridge Mountains, Duskwood | the Redridge-Duskwood bridge |
| 1436, 1431 Westfall, Duskwood | the Westfall-Duskwood bridge |
| 1431, 1434 Duskwood, Stranglethorn Vale | the Duskwood-Stranglethorn road |
| 1431, 1430 Duskwood, Deadwind Pass | the Duskwood-Deadwind road |
| 1430, 1435 Deadwind Pass, Swamp of Sorrows | the Deadwind-Swamp road |
| 1435, 1419 Swamp of Sorrows, Blasted Lands | the Swamp-Blasted Lands road |
| 1428, 2548 Burning Steppes, Riverglades | the Riverglades-Burning Steppes border |
| 1435, 2548 Swamp of Sorrows, Riverglades | the Riverglades-Swamp border |
| 1418, 2548 Badlands, Riverglades | the Riverglades-Badlands border |

Leave every other name as it is (they already read both ways: the gates, the Southfury bridge, the Mor'shan Rampart, the
Stonetalon pass, the Great Lift, the Talondeep Path, the Timbermaw Hold tunnels, Darkwhisper Gorge, the Valley of Bones,
the Ruins of Lordaeron, the Bulwark, Thoradin's Wall, the Thondroril River bridge, the Thandol Span, the Dun Algaz
tunnels, the Valley of Kings gates, Blackrock Mountain, the Three Corners road, the Westfall bridge, the bridge south of
Goldshire, the Riverglades turnoff). Update the file's header comment: a name must read correctly whichever way you are
going; the detail line gives the direction. Add a test in `test/test_crossings.lua`: no name contains the words
" into " or " to " followed by one of its own two zones' names (a cheap guard against a directional name returning), and
update every test and doc string that pinned an old name (`test/test_crossings.lua`'s Hyjal route, `docs/manual-test-checklist.md`).

**F2. Passing through a tunnel, a lift or a mountain takes time (Important).** A crossing is one point in both zones, so
going through costs nothing. Add an optional field `cross = <seconds>` to a row; in `Graph.Build`, add it to the cost of
every ride edge whose destination is that crossing stop (so it is paid once per traversal, including when the crossing is
where a zone destination is reached). Document the field in the header. Values (estimates, to be timed in game):
Blackrock Mountain 120, the Timbermaw Hold tunnels 90 (all three rows), the Dun Algaz tunnels 90, Darkwhisper Gorge 60,
the Great Lift 45, the Thunder Bluff lifts 30, the Talondeep Path 45. Tests: a fake-world crossing with `cross` makes the
leg to it that much longer; the row check accepts `cross` only as a positive number.

**F3. Unconfirmed crossings must be visible, and the flag must not rot (Important).** `unverified = true` is read by
nothing. Rulings:
- `Graph.Build` copies it onto the crossing stop; `Route.StepDetail` appends ` · crossing not confirmed` for a step whose
  target crossing is unverified, and returns warn = true.
- Mark `Orgrimmar's west gate` (1454, 1413) `unverified = true` too: every Horde route north depends on it and nobody has
  walked it on this client.
- Test: `unverified` is set on exactly these rows and no others: the three with a Forever zone on either side
  (2482 Mount Hyjal, 2652 Shen'dralas, 2548 Riverglades: six rows) plus Orgrimmar's west gate.

**F4. Pinch points (Minor, cheap truth test).** In `test/test_crossings.lua` assert the number of crossings touching these
zones, so a fictional border fails loudly: Un'Goro Crater 2, Silithus 1, Moonglade 2, Dustwallow Marsh 1, Teldrassil 1,
Blasted Lands 1, Darnassus 1, Azshara 1.

**F5. `legal`'s nil case (Minor).** In `Graph.lua`, comment that a nil faction means "open to both" and exists for
crossings, which have no faction unless a row gives one.

Run the Lua tests and luacheck. Commit 1.

## Commit 2: text and window (`GoblinPS/Route.lua`, `GoblinPS/Graph.lua`, `GoblinPS/Planner.lua`, tests)

**F6. The hazard must never be the part that gets cut off (Important).** The detail line is about 62 characters wide in the
wide layout and does not wrap, and the longest real string is 78, so the client truncates the hazard note. Ruling in
`Route.StepDetail`: when the crossing has a `warn`, or is unverified, leave out the ` · level low-high` clause:
`into Winterspring · Timbermaw furbolgs attack without reputation`, `into Mount Hyjal · crossing not confirmed`. When a
row has both a hazard and is unverified, show the hazard, then the unconfirmed note. Add a test over the real data: for
every crossing, in both directions, the detail text is at most 66 characters; shorten a `warn` string if one breaks it.

**F7. Do not say the obvious (Minor).** `Route.StepDetail`: for a non-crossing ground step, when the target's short name
equals the zone's name (for example "Walk to Orgrimmar" / "in Orgrimmar"), return an empty detail (warn still follows
the zone's danger, but with empty text return warn = false so no empty amber line is drawn).

**F8. The last step is always visible (Minor).** `Planner.Refresh`: when a route has more steps than `Planner.MAX_ROWS`,
show steps 1 to MAX_ROWS-2, then a row reading `... and N more steps`, then the FINAL step (with its detail) in the last
row. N counts the steps hidden between. Update the existing overflow smoke test and assert the last row shows the
arrival.

**F9. One source of mount speed (Minor; spec decision 17 and CLAUDE.md both promise it).** Remove
`Graph.RIDE_YARDS_PER_SECOND`. `Graph.RideSeconds(a, b, speed)` with no speed uses `ns.Travel.MOUNTS[1].yardsPerSecond`
(looked up at call time; `Travel.lua` loads before `Graph.lua` in the TOC and in `test/run.lua`). Update any test that
referred to the removed constant (a test may read the value from `ns.Travel`).

Run the Lua tests, luacheck and
`lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls.json`. Commit 2.

## Commit 3: documents

- `docs/superpowers/specs/2026-09-19-goblinps-design.md`: in the ground-travel data list, "56 rows plus Forever's new
  zones" becomes "56 rows, six of them for Forever's new zones"; describe the optional `cross` seconds and that
  unverified rows (the new zones and Orgrimmar's west gate) say "crossing not confirmed" in amber; in decision 16 note
  that a crossing's name reads the same in both directions and the detail line gives the direction, and that a hazard
  replaces the level range on the detail line so it is never the part cut off.
- `CLAUDE.md`: the layout line for `Data/Links.lua` still says "(and later ground crossings)": remove that clause.
  In the ground-travel rule add: crossing names must read correctly in both directions.
- `docs/manual-test-checklist.md`, section `## Ground crossings (plan 3)`: update any old crossing name; add
  - `- [ ] Check the level ranges in GoblinPS/Data/Zones.lua against the in-game map's zone tooltips; Forever may have moved some`
  - `- [ ] Time the passages that carry a cross time in Data/Crossings.lua (Blackrock Mountain, the Timbermaw tunnels, Dun Algaz, Darkwhisper Gorge, the Great Lift, the Thunder Bluff lifts, the Talondeep Path) and correct the seconds`
  - `- [ ] Orgrimmar's west gate and the six new-zone crossings show "crossing not confirmed" in amber until their rows lose unverified = true`
  - `- [ ] A route with more than 8 steps shows the first six, "... and N more steps", and the final step`
  and move the existing "Orgrimmar's west gate" item to the TOP of the section with the words
  `FIRST: every Horde route north depends on it.` in front.

Run the Lua tests and luacheck once more. Commit 3.

## Not in this wave (ledgered as deferred)

Amber saturating for very low characters; a per-zone detour multiplier for mountain zones; tightening the row check to
"near the shared edge"; Sardor Isle's ferry.

## Report

Write `D:\goblinps\.superpowers\sdd\2026-09-19-goblinps-ground-crossings\final-fix-report.md`: per F-item what changed
(file:line), RED then GREEN for each new test that can fail first, final counts, lint and language-server output, the
printed Tirisfal to Mount Hyjal route (steps, details, total) after the changes, and anything you could not do or chose
differently, with why. If a ruling proves impossible or breaks something it did not anticipate, STOP and report BLOCKED
with specifics. You cannot run the game client; claim nothing about in-game behaviour. Do not push.

Then reply with ONLY: Status, the commits (short SHA + subject), a one-line test summary, concerns, the report path.

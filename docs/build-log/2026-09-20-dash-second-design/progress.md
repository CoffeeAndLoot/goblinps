# SDD ledger — plan: docs/superpowers/plans/2026-09-20-goblinps-dash-second-design.md

Spec: docs/superpowers/specs/2026-09-19-goblinps-design.md (decisions 3, 5, 7). Branch: dash-second-design, from main 9f80ca7.

Ruling: plain branch, not a worktree — the game junction targets D:\goblinps\GoblinPS and follows whatever is checked out, so a worktree would hide the work from the client the user tests in. Same as plans 3, 4. — if wrong: nothing depends on the layout.

## Pre-flight scan

| Pair / task | Produces vs consumes | Found |
|---|---|---|
| T1 -> T2 | `ns.Data.Art.geometry`: canvas, glass, compassRing, compassCrop, arrow, stepsText, etaText, destination, distance, stop | shapes agree; T2 reads glass.cx/cy, compassCrop.share, arrow.share |
| T1 -> T3 | the same table, plus `ns.Data.Art["dash2-stop*"]` | T3 reads destination, distance, stepsText, etaText, stop.cx/cy/r — all present |
| T1 self | tests vs code | **P1 below**: the key list the test pins omits `arrow`, which T2 depends on |
| T2 -> T3 | file-locals `place`, `base`, `PAD`, `MEDIA`, `stepText`, and `ui.content` | all in scope; both tasks edit one function |
| T2 self | the replacement block vs what is left behind | **P2 below**: the old ETA plate survives it |
| T2 -> existing tests | the `ui` table's field names | **P3 below**: eleven reads across five tests break |
| T3 self | tests vs code | consistent; `ShortName("the North Gate")` is unchanged, so the glass test's expectation holds |
| T3 -> plan 4's trip tests | ui.step / ui.next | already named by line in the brief, with change-the-read-never-the-assertion |
| T4 | docs only | no code |
| harness | `test/test_ui.lua:18` already loads the generated `Data/Art.lua` | so `ns.Data.Art.geometry` is reachable from the tests with no new plumbing |

**P1. Task 1's geometry test does not require the key Task 2 needs.** Its `test_the_lua_table_carries_what_the_addon_needs` lists canvas, glass, compassRing, compassCrop, stepsText, etaText, destination, distance and stop — but not `arrow`, which `geometry_lua` produces and which Task 2 reads as `g.arrow.share` to size the arrow. The code is right and the test is incomplete, so a later edit could drop `arrow` and only Task 2 would notice, at runtime.

Ruling: Task 1's dispatch adds `arrow` to that key list. One word, and it closes a gap between a producer's test and a consumer's need. — if wrong: nothing; the key is already produced.

**P2. Task 2's replacement block leaves the old ETA plate drawing.** The brief says to replace "everything from the old `device` frame down to the old `bodyArt`", which is `GoblinPS/Dash.lua` lines 113 to 160. But `plateArt = art(content, "dash-eta-plate", "BACKGROUND", eta)` is at line 194, **after** `content`, so it survives — and would draw the first design's brass plate over the second design's panel.

Ruling: Task 2 removes every texture belonging to the first design — `dash-screen`, `dash-compass`, `dash-body` and `dash-eta-plate` — wherever they appear in `build()`, not merely the contiguous block the brief describes. The parts themselves stay in `Data/Art.lua` and `GoblinPS/Media/`: nothing draws them, they cost about 0.8 MB, and leaving them means the first design's art is still on disk if the second turns out wrong in the client. A follow-up removes them once the new device is confirmed in game. — if wrong: 0.8 MB of unused texture, against a visible artefact drawn over the new panel.

**P3. Eleven reads across five existing tests name first-design widgets.** `ui.device`, `ui.screen`, `ui.screenArt`, `ui.screenFlat`, `ui.bezel`, `ui.bodyArt`, `ui.plateArt` are read at lines 546, 549, 564, 565, 575, 576, 871, 873, 896, 923, 925 and 927. Task 2 replaces that vocabulary with `artLayer`, `glass`, `flat`, `housingFrame`, `housing`, and the five tests would fail on nil.

Ruling: Task 2 re-points them, and each keeps its meaning rather than being deleted:
- "keeps the round art on a square frame so it cannot render as an oval" (540) — the second design's device is the whole frame and the art is 1024x1280, so squareness is no longer the property that matters. Replace it with one asserting the frame keeps the art's aspect ratio, which is the same defect stated for the new shape.
- "draws the three stacked layers at one square, as the art requires" (553) — still exactly right, now over `artLayer` and the five new layers.
- "hides the square fallback colour once the round glass loads" (569) — still right, now `ui.glass` and `ui.flat`.
- The art and fallback tests at 871-902 — re-point to the `dash2-` parts; the arrow fallback assertion stays as it is.
- The stacking test at 923-927 — re-point to artLayer, housingFrame, content, and keep the added assertion that content outranks the housing.
— if wrong: the tests are the contract for four fix rounds' worth of lessons, and deleting any of them would quietly discard one.

Scan complete: 3 findings, all ruled on above.

## Progress
Carried in from plan 4, to be folded into Task 2's dispatch rather than done separately: two tests in `test/test_ui.lua` restore the shared `where` fixture on a bare final line, after several assertions, with no pcall. A failing assertion earlier in either would skip the restore and corrupt the fixture for everything after. Plan 4's final re-review proved it does not cascade today, so it was parked as latent fragility rather than a fault, and recorded as first on plan 5's list.

Ruling: Task 2 fixes it, not a separate change of mine. Task 2 is already rewriting large parts of that file, so doing it separately would collide, and the controller does not edit files a live subagent owns — nor fix findings itself, since controller fixes skip review. The remedy is to wrap each restore the way a third test in the same file already does. — if wrong: the fix moves to Task 3, which also edits the file.
Task 1: implemented 516eacd (DONE_WITH_CONCERNS). 36 Python tests, 47 art parts, 239 Lua. The compass crop is measured correct: the shipped 256x256 dash2-compass.tga has its ring centred at (127.5, 127.5), exactly its own canvas centre, which is the whole point of the task. Three brief defects found and fixed rather than worked around: the missing `arrow` key the controller had already flagged; `PARTS += [...]` breaking a pre-existing exact-equality test the brief never mentioned; and, the serious one, nesting `geometry` inside `ns.Data.Art` **crashing the entire Lua suite** because SelfTest's shippedArt() iterates that table assuming every entry is a part with a `.file`.

Ruling: the implementer's guard is right and stays, but the shape that made it necessary is a controller defect and gets fixed. Every other data table in this project is a sibling under `ns.Data` — Places, Nodes, Flights, Crossings, Zones, Inns — and `Data/Links.lua` declares two siblings rather than nesting one inside the other. `ns.Data.Art.geometry` breaks that convention and breaks the invariant that every value in Data.Art is a part, which is exactly what crashed the suite. It becomes `ns.Data.ArtGeometry`. Doing it now costs one small fix round; leaving it lays the same trap for every future iterator over Data.Art, and SelfTest was merely the first to find it. — if wrong: one table name, changed in a generated file and two reads.
Task 1: fix round 1/5 dispatched (resumed the original implementer), FIX_BASE 516eacd
Task 1: fix round 1/5 applied (commit 4b173e4). Geometry is now the sibling `ns.Data.ArtGeometry`, the SelfTest guard was kept with a comment saying why, and the implementer proved the guard fires by feeding the parts table a junk entry.
Task 1: review (sonnet) — **spec ✅, quality approved**, 0 Critical, 1 Important. The reviewer measured the shipped compass itself rather than trusting the report: bbox centre (127.5, 127.5) on a 256x256 canvas, an exact match with its own centre, and it re-derived the crop arithmetic (dial at 516,469; COMPASS_HALF 280 gives 236,189,796,749, inside the canvas, with 18px of margin over the ring's 262 radius). It repeated the junk-entry experiment independently and watched the guard exclude it, re-ran make_art.py and confirmed Art.lua reproduces byte-for-byte, and recomputed arrow.png's SHA-256 against the artist's recorded value.

Task 1 Important: the fix for the defect that took down the **entire** Lua suite has no automated regression test. The pre-existing test covers `Data.Art` being absent, not a malformed entry inside a present one. The guard's correctness rests on manual verification only, which this project's own convention says should be pinned.

Ruling: real, and it is fixed in **Task 3**, not a Task 1 fix round. The test belongs in `test/test_ui.lua`, because that is the only suite that loads `SelfTest.lua`; `test/test_data.lua` cannot reach it without new plumbing, and `test/run.lua` does not load SelfTest at all. Task 2 owns test_ui.lua right now and Task 3 owns it next, so folding it into Task 3 keeps one owner per file instead of opening a fix round that would collide with live work. — if wrong: the test lands one task later than it might have, and the guard is manually verified twice in the meantime.

Task 1: minor (no action): the implementer's summary said it "found and fixed" three brief defects, but the first was supplied by the controller's dispatch. The reviewer caught the overclaim. Worth noting only because an accurate account of who found what is what makes these reports worth reading.
Task 1: complete (commits 9f80ca7..4b173e4, 1 fix round, review clean)
Task 2: implemented 3ace247 (DONE_WITH_CONCERNS), 243 Lua tests, both linters clean. Four concerns raised, two of them worth acting on.

Ruling on the aspect ratio: fix it rather than tolerate it. The implementer's re-pointed test compares the frame's ratio with the art's using a `< 0.01` tolerance, because `Dash.SIZE = {230, 288}` is 0.798611 against the art's exact 0.8. But 232x290 is exactly 0.8, and so is 240x300. A tolerance that exists only because a constant was rounded is a tolerance hiding a choice, and it would quietly accept a future size that is genuinely wrong. Change the constant, make the assertion exact. — if wrong: two numbers, and the device draws two pixels wider.

Ruling on the unused helper: delete it here rather than suppress it. The implementer added `-- luacheck: ignore 211` to `place`, correctly flagged by luacheck as unused, because my plan declared it as Task 2's output when only Task 3 calls it. That was a sequencing error in the plan, not a reason to silence a true warning. Since a fix round is being dispatched anyway, `place` goes, and Task 3 introduces it at the point it is first used — so no suppression ever enters the branch's history. — if wrong: Task 3 writes ten lines it would otherwise have inherited.

Accepted without change: extending the replacement to absorb the old `content` frame, which the brief's own snippet would otherwise have double-declared; and re-anchoring the four kept FontStrings at zero offset as a placeholder, since Task 3 replaces their positions with the geometry's text-safe boxes. Both are sound.
Task 2: fix round 1/5 dispatched (resumed the original implementer), FIX_BASE 3ace247
Task 2: fix round 1/5 applied (13b5b5e). Dash.SIZE is {232, 290}, exactly the art's 1024:1280, and the assertion cross-multiplies against ns.Data.ArtGeometry.canvas rather than hard-coding 0.8. The unused helper and its lint suppression are gone.
Task 2: review (sonnet) — **spec ✅, quality approved**, 0 Critical, 1 Important, minors. Everything proven by experiment rather than reading: it injected a failure into each of the two previously-fragile tests and confirmed the restore still ran and nothing cascaded; it set the size back to {230,288} and watched the ratio assertion fail with 294400 against 294912; it probed the live device and measured every layer at 232x290 with levels f=1, artLayer=2, housingFrame=3, content=4, stop=5; and it confirmed the compass and arrow are sized exactly to geometry.compassCrop.share and geometry.arrow.share. Trip.lua has zero diff and the trip loop's bodies are byte-identical.

Task 2 Important: the three geometry-absent fallback literals — the dial at {x=0.5, y=0.4}, the compass share 0.55, the arrow share 0.45 — are legitimate under the plan, which permits a fallback when the geometry is missing, but none is marked as such. In a plan whose central rule is that no coordinate is hand-typed, an unmarked literal that looks like a coordinate is exactly the thing a later reader misreads, or copies.

Ruling: real, and fixed in **Task 3** rather than a Task 2 fix round. Task 3 rewrites the layout text and the button in the same function and the same file, so a separate round would collide with it for the sake of three comments. Task 3's dispatch carries it and Task 3's review verifies it. Same pattern as Task 1's regression test. — if wrong: the comments land one task later.

Task 2 note carried to Task 3, and this one is the reviewer's own catch rather than mine: the stop button currently sits at `BOTTOM, 0, PAD` — a pre-existing placeholder from the first design, untouched and correctly out of Task 2's scope. But `ns.Data.ArtGeometry.stop` puts it at cx 0.837, cy 0.170, which is the **top right**, where the second design's housing actually has its socket. Task 3 must consume `g.stop`, or the button will sit at the bottom of a device whose hole is at the top.
Task 2: complete (commits 4b173e4..13b5b5e, 1 fix round, review clean)
Task 3: implemented f616d9c, 250 Lua tests (up from 243), both linters clean. Three deviations reported, all sound: PAD dropped entirely rather than kept in the fallback branch; a stale "then " prefix removed from a re-pointed assertion because the new panel never writes it; and `place()` had actually been DELETED in Task 2's fix round rather than merely unused, so it was re-added where first called — which is exactly the sequencing the fix-round ruling intended.
Controller check before review: the editor's live analysis reported `PAD` as an undefined global at five sites and `place` as unused. Both were stale mid-edit snapshots — `grep` finds zero occurrences of PAD in the file and five of `place`, and both CLI linters are clean. That is the third time today the IDE has disagreed with the project's stated gate; CLAUDE.md names the CLI check as authoritative and it has been right each time.
Controller check: the stop button's geometry resolves to centre (194.2, 49.4) on the 232x290 device, diameter 22.2px — the top right, matching the housing's socket, which is what the Task 2 reviewer warned would otherwise have been wrong. The three fallback literals now each carry a comment saying they are only reached when the generated geometry is absent.
Task 3: review dispatched (sonnet).
Task 3: review (sonnet) — **spec ✅, quality needs fixes**: 0 Critical, 1 Important, 1 Minor. The banner was driven rather than read, and both failure modes were checked: on the recalculating tick steps[1] reads "Recalculating..." with 2 and 3 blank, and on the following tick it is fully replaced by ordinary text. It proved the new SelfTest guard test bites by removing the guard and watching the suite fail with "attempt to concatenate field 'file'". It confirmed the stop button lands at (194.2, 49.4) with a 22.2px diameter and that PAD is gone from the file entirely. All three deviations upheld.

Task 3 Important: with the generated geometry absent, six FontStrings — destination, distance, the three step lines and eta — receive **no anchors at all**. They are placed only inside `if g then place(...) end`, with no else, unlike the compass, arrow, dial and stop button, which all have a commented fallback. SetText still succeeds and nothing errors, so it is silent: in the real client a region with no anchors does not draw, so the device would open, the button would still stop the trip, and every word would be invisible. The code before this task anchored the same lines unconditionally, so this is a regression, and the reviewer found it by building a Dash with the generated file never loaded — which no test in the suite does.

Ruling: fix it, and add the test that would have caught it. This breaks two standing rules simultaneously — every FontString gets two horizontal anchors or a width, and art that will not load must leave a **readable** device, not merely a device that opens. The whole fallback path exists for the case where the generated file fails to load, and it currently produces the worst possible version of that: no error, no warning, no text. — if wrong: a handful of anchor lines on a path that should never run in a healthy install.

Task 3 Minor: the new stop-button fallback test sets `Fake.missingTextures[MEDIA_STOP]` and clears it on a bare final line, so a failing assertion leaves it stuck true for every later test. It copies a pre-existing idiom with the same gap in two sibling tests. Folded into the same fix round, and the two siblings go with it: this exact class of fragility has now been flagged in three separate reviews across two plans, so the pattern is worth ending rather than matching.
Task 3: fix round 1/5 dispatched (resumed the original implementer), FIX_BASE f616d9c
Task 3: fix round 1/5 applied (78b657d), 251 Lua tests, both linters clean. Controller verified independently by building a Dash with ns.Data.Art and ns.Data.ArtGeometry never loaded: destination, distance, steps[1..3] and eta now each report 2 anchors where they previously reported 0. The stop button reports 1, which is correct and not a finding — it is a Button frame with an explicit 20x20 size, and one anchor plus a size fully places a frame; the two-anchor rule exists for FontStrings, which have no intrinsic dimensions. The controller's first probe applied the rule too bluntly and would have raised a false alarm.
Task 3: scoped re-review dispatched (sonnet), FIX_BASE f616d9c.
Task 3: fix round 1/5 re-review (sonnet) — both findings ADDRESSED, no new breakage. It built a Dash with the generated file never loaded and measured all six FontStrings at 2 anchors, confirmed the fallback is a single downward stack so the lines cannot overlap, and correctly did NOT report the stop button's single anchor as a defect. For the restores it injected a failure inside the shared helper's body and proved three things at once: the failure was reported rather than swallowed, the flag was cleared anyway, and nothing cascaded.
Task 3: complete (commits 13b5b5e..78b657d, 1 fix round, re-review clean)
Task 4: implementer dispatched (sonnet, not haiku — plan 4's documentation task ran on haiku and produced a Critical factual error about the art pipeline that its review caught; accuracy against source is the whole job here), BASE 78b657d.
Task 4: implemented 4bbec9e (DONE_WITH_CONCERNS). It challenged the controller's own framing — that the dash was redesigned after being seen in the client — as false against source, and wrote the opposite into both status lines: "the assembled device was never run as a whole in the WoW client".

Ruling: the challenge was right to make and wrong on the facts, and it goes back for a fix round. The git history records both in-game runs explicitly. Commit 5858643: "First in-game run. The device rendered as an oval and the step name was cut in half by the Stop button." Commit 2d58322: "The compass vanished and a dark square framed the device." Both faults were found by looking at the device on screen; neither could have been found any other way, since the desktop fake does no compositing. The first design ran in the client on 2026-09-20. What has never run is the SECOND design.

The implementer checked CLAUDE.md's status line and the build-log ledger, both written before those runs, and trusted them. That is a real finding in its own right and the more useful half of its report: **the status line it read was stale**, and stale documentation is exactly what this task exists to fix. It reasoned correctly from bad sources rather than reasoning badly, and challenging a controller instruction instead of quietly complying is the behaviour I want — the instruction simply happened to be right this time.

— if wrong: two sentences in two files. Against which: a document asserting the device was never seen in game, while the branch it sits on contains two commits fixing faults that were seen in game, is the kind of contradiction that makes a reader distrust everything around it.
Task 4: fix round 1/5 dispatched (resumed the original implementer), FIX_BASE 4bbec9e
Task 4: fix round 1/5 applied (0db3921). The status lines now draw the distinction correctly and cite 5858643 and 2d58322 as evidence rather than asserting.
Task 4: review (sonnet) — **spec ✅, quality approved**, 0 Critical, 0 Important, 1 Minor. It checked thirteen factual claims against source with a file:line for each, independently re-verified both commit hashes the corrected text cites, and confirmed the first-design / second-design distinction is now drawn correctly everywhere. It found no third false documentation claim. The reviewer also disclosed creating a stray scratch file in the repo root by a shell redirection mistake and deleting it; git status confirms the tree is clean.
Task 4: minor (deferred to the final review's triage): docs/manual-test-checklist.md:147 says "the question plan 5 was waiting on" in the OLD numbering, written when plan 5 meant the route strip. After the renumbering, plan 5 means the dash unit's second design, so that dated line now reads ambiguously. It sits outside the task's touched region and is a historical annotation rather than a current-state claim.
Task 4: complete (commits 78b657d..0db3921, 1 fix round, review clean)

All four tasks complete. Dispatching the final whole-branch review.

## Final whole-branch review — verdict and the one fix wave

Reviewed `main..dash-second-design` (9 commits, BASE `0db3921`) on the most
capable model. **Verdict: ready with fixes — 0 Critical, 3 Important, 8 Minor.**
All gates green at review time: 251 Lua, 36 Python, check_art 47/0/0,
`make_art.py` reproduces `Art.lua` and all 13 TGAs with an empty diff, luacheck
0 warnings in 39 files, language server clean, no lint suppression.

Verified clean by the reviewer: the compass crop agrees at every link (crop
centre = dial (516,469); shipped TGA bbox centre exactly (127.5,127.5); share
0.546875 = 560/1024; drawn at 126.88 px; H/V scales bit-identical so squares
stay square), `Trip.lua`'s diff is empty, the banner shows for exactly one
tick, and the docs carry no third false claim.

Ruling: dispatched ONE fix wave (`fix-brief.md`) carrying all three Important
findings, all eight Minor, and the triaged deferred finding. One scoped
re-review follows; residuals get adjudicated, not a second wave.

### Ruling on Important 1 — the frame's own brass rectangle

`W.Panel` lays two opaque textures directly on the device frame and returns
only the frame, so nothing can hide them, while six lines below `flat` IS
hidden for exactly the reason that matters ("it boxes in a round device").
The composited art leaves 39.65% of the canvas transparent. Ruled: the device
frame carries no art of its own — build it bare, and give the no-art fallback
its own hideable frame at the base level. Same class as the in-game fault fixed
in `2d58322`. Cost if wrong: the fallback loses its border, which is cosmetic
and visible in one glance.

### Ruling on Important 2 — the text boxes against the client's fonts

Two parts, because the finding is two problems wearing one coat.

**A. `place()` stops constraining height.** The artist named those rects
`destination_line` and `distance_line` — 30 and 26 px tall on a 1280 canvas,
against `steps_screen` at 226. They are lines to sit on, not boxes to fit in;
the `_screen` rects are the areas and are sized like areas. Forcing a
FontString into a 6.8 px rect was our error, not the artist's. A line anchors
LEFT/RIGHT on its rect's vertical centre: two horizontal anchors, so the
bounding rule and truncation both hold, and the font decides the height.

**B. `Dash.SIZE` goes to {288, 360}.** 232 was hand-typed and is the one layout
number not derived from the geometry — on a branch that spent real effort
making every other coordinate generated. 288x360 is exactly 4:5, matching the
art's 1024:1280, and brings each step line to 21.19 px and the ETA plate to
19.12 px. Declined to chase the 200 px step-line width that commit `5858643`
recorded as insufficient in a real client run: truncation is this design's
decided behaviour and long stop names get their room in the route strip.
Cost if wrong: the device is the wrong size on screen, which one look in the
client settles — so it goes on the checklist as the one number still owed an
in-game look.

### Ruling on Important 3 — the fake mis-parses three-argument `SetPoint`

`(point, relativeTo, relativePoint)` was parsed as `(point, x, y)`. This branch
is the first to use that overload — six times, in the geometry-absent fallback
— so the frame landed in `x` and the anchor string in `y`. Worse than the
parse: the regression test added to close this branch's most serious finding
asserts only anchor COUNT, so it passed on garbage. Ruled: disambiguate by
argument type (production uses both forms), and strengthen the test to assert
anchor targets. Fifth method found hiding in that fake, after `SetTexCoord`,
`SetFrameLevel`, `SetWordWrap` and `SetAllPoints`.

### Ruling on the deferred finding — fix it, one word

`docs/manual-test-checklist.md:147` says "the question plan 5 was waiting on".
This branch repointed that number: plan 5 is now the dash second design, while
the sentence is about the route strip's remaining 34 art parts (now plan 6),
and the paragraph below says "plan 4" meaning the dash. Two numbers in one
entry contradicting each other, in the document the user reads while standing
in the game. Deferring it was weaker than fixing it, since the branch is what
broke it. Cost if wrong: none; it is one word.

## The fix wave — landed

Three commits on `0db3921`, each green standing alone, explicit paths on
every one, `AGENTS.md` never staged, nothing pushed:

- `a4e9a5d` Fake frames: parse three-argument `SetPoint` by type, record
  regions and layers
- `c9de780` Dash unit fix round 2: no art on the device frame, text on the
  artist's lines
- `001a7b2` Docs: the checklist's dash section, and the plan number that moved

Gates reported: Lua 257 (was 251), Python 37 (was 36), check_art 47/0/0,
`make_art.py` regenerates with zero diff, luacheck 0/0 in 38 files, language
server clean. (The brief's "39 files" was my typo; the tree has 38.)

Both required fail-first tests were seen failing: I1's no-regions test with
`expected "0", actual "2"` — the two opaque textures `Widgets.Panel` laid on
the device frame, exactly the finding — and I3's anchor-target test with
`expected "table", actual "nil"`, the frame the fake's three-argument parse was
dropping. A third test failed on the way through and was rewritten to the new
ruling rather than the ruling bent to fit it.

### Ruling accepted against my own brief — `place()` stays one helper

My brief offered the fixer a choice between two `place()` behaviours (lines
versus areas) or a separate helper. It took neither and renamed the one helper
`placeLine`, arguing that a type-branching version would carry a branch no call
site and no test could reach — the same dead code the brief told it to delete
in Minor 2. That argument is better than mine: all six call sites are lines,
every genuine area is a texture filling its own frame and never touches the
helper, and the name now catches the misuse the branch would have caught.
Accepted as written.

### Concerns carried forward, not closed by this wave

- **288x360 is arithmetic, not observation.** Plan 5 has never run in the
  client. The checklist now names that number as the one to change.
- **The fake does not record the font object** passed to `CreateFontString` —
  not even on the accepted-and-ignored list, since it is a constructor
  argument. Important 2 was entirely an argument about font heights, and
  nothing in the suite can see which font any line uses. This is the sharpest
  remaining gap in the harness.
- **`SetJustifyH` is a no-op in the fake and just became load-bearing**: with
  centre-line anchoring, justification alone decides where words sit in each
  opening.
- **`SetHighlightTexture` is still a no-op**, so Minor 6's test proves the
  hover cap is cropped but not that it reached the button.

Ruling: none of these four blocks the merge, because none is a defect in the
addon — three are limits on what the desktop harness can see, and the fourth
is a number only the client can settle. They belong in the checklist and in
the next plan's brief, not in a second fix wave. Cost if wrong: a font or a
justification is visibly off on the first client run, which is exactly the
kind of fault the first design's two client runs caught in one look each.

Dispatched the single scoped re-review (`rereview-0db3921..HEAD.diff`), with
those three flagged items as explicit questions and instructions to verify
every gate itself rather than trust the report.

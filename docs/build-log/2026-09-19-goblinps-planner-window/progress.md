# SDD ledger — plan: docs/superpowers/plans/2026-09-19-goblinps-planner-window.md

Spec: docs/superpowers/specs/2026-09-19-goblinps-design.md. Branch: planner-window (from main e150930).

Ruling: plain branch, not a worktree — the game junction targets D:\goblinps\GoblinPS — if wrong: main is untouched, merge is a fast-forward.

## Pre-flight scan

All plan code was run together in a scratch copy before the plan was written: 103 Lua tests, luacheck 0 warnings. Cumulative counts checked: 70 -> 73 -> 79 -> 89 -> (Task 4 none) -> 103.

| Pair / task | Produces vs consumes | Found |
|---|---|---|
| T1 Graph | reads opts.to.kind / opts.to.map; Search places carry both | consistent; Core passes Search places straight through |
| T1 -> T5 | zero-step route means "already there" | Core.PlanRoute adds the note and skips the hint: consistent |
| T2 Search.Exact | data.Inns may be nil | nil-safe; fake world gets Inns in the same task |
| T2 -> T5 | TOC gains Data\Inns.lua in T2; T5 replaces the TOC | T5's TOC includes Data\Inns.lua: consistent |
| T2, T3 -> T5 | run.lua edited in T2 and T3, replaced in T5 | T5's run.lua is a superset of both edits |
| T3 Prefs -> T5 Core | Init, ToggleLayout, Remember, SavePosition, Position, minimap{angle,hide} | names and shapes match Core and MinimapButton |
| T4 icon -> T5 | path Interface\AddOns\GoblinPS\Media\icon | same string in TOC, MinimapButton, SelfTest |
| T5 internal | Planner/MinimapButton/SelfTest call ns.Core.* at call time only; Core loads last | load order in TOC satisfies every load-time capture (W = ns.Widgets) |
| T5 API | SetWaypoint/OnLogin/SelfCheck; test_ui stubs the same names | consistent |
| T6 docs | anchors in CLAUDE.md and the spec | exist; spec decision 7's sentence wraps across two lines (dispatch note) |
| each task, self | tests vs code | each ran green in scratch |

Plan-mandated items a reviewer may flag: Planner.Debug() exists only for the smoke test; test_ui.lua replaces the global print and restores it. Both deliberate.

Scan clean. No rulings needed beyond the above.

## Progress
Ruling: batch Tasks 1-4 into one implementer dispatch (one commit per task) and one review — small, verified, same shape; sonnet rather than haiku because Tasks 1-2 edit existing files in place — if wrong: one fix round covers a larger diff.
Task 1-4: reviewer "cannot verify" (version 2026.09.19.2) — resolved by controller: Task 5 replaces the TOC and its brief carries `## Version: 2026.09.19.2`.
Task 2: minor (deferred): Search.Exact follows inn.stop recursively with no cycle guard; no current row can loop, a bad future row would overflow the stack. Cheap fix: do not consult Inns on the recursive call.
Task 1: minor (deferred): no test for a START place with no `map` reaching a zone destination (nil == number is false; correct, untested).
Task 3: minor (deferred): Prefs hostile-input tests cover only a bad layout string, though Init guards every field.
Task 1: complete (commits e150930..50be1b5, review clean)
Task 2: complete (commits 50be1b5..6dd2970, review clean)
Task 3: complete (commits 6dd2970..decb867, review clean)
Task 4: complete (commits decb867..a5c2050, review clean)
Task 6: complete (commits 91ed29a..fedbe42, review clean)
Task 5: implemented at a5c2050..91ed29a, byte-identical to the verified copy; opus review in progress (focus: real frame API use)
Task 5: review (opus) — spec OK, quality "needs fixes": 4 Important (StartMoving handler, no OnEditFocusLost, saved position drops relativePoint, texture self-check unfalsifiable), 7 Minor. Every widget method, font, texture, event verified present in the 1.60.1 source.
Ruling: fix all 4 Important plus cheap minors 5-9, the deferred inn-recursion guard, and lint-config agreement in one round; make fake_frames strict (allowlist, unknown method errors) since the silent no-op is why these reached review — if wrong: a legitimate new widget method needs one allowlist entry.
Ruling: MinimapButton keeps UI_SCALE_CHANGED / DISPLAY_SIZE_CHANGED; the rule is reworded to "API.lua registers game-data events; UI files may register UI layout events" — moving two layout events into API.lua buys nothing — if wrong: a three-line move.
Ruling: Planner.Debug() and the smoke test's print swap stand (plan-mandated); harness.it catches failures, so print is restored even when a test fails.
Ruling: fresh sonnet implementer with a written fix brief instead of resuming the transcription implementer — this round is design work with rulings the brief carries in full.
Task 5: fix round 1/5 dispatched (brief task-5-fix-brief.md), FIX_BASE fedbe42
Task 5: fix round 1/5 (all addressed, 0 open; commits fedbe42..ccaf291). Two implementer deviations accepted by the re-reviewer: strict fake raises only for PascalCase (method-shaped) unknown keys; the selftest smoke test asserts "+1 failure and a FAIL line for that path" because the desktop fake has no font globals.
Task 5: minor (deferred): test_ui.lua shares one mutable planner across tests (order-dependent); fine today, easy to trip when adding tests.
Task 5: complete (commits a5c2050..ccaf291, review clean after 1 fix round). Lua 113/0.

## Final review (opus): "ready to merge with fixes" — 0 Critical, 3 Important, 9 Minor
Ruling: all notes go to the width-bound ui.notes (wrapping); ui.total shows only a real total and is anchored short of GO — a sentence in a one-anchor FontString draws over GO and past the frame — if wrong: two anchors to adjust.
Ruling: GO re-plans before acting (dismiss, replan, Core.Go) — makes "use your hearthstone, then press GO again" true and keeps the pin honest after the player moves — if wrong: GO costs one extra plan, a few ms.
Ruling: Prefs.Position type-guards its entry; a corrupt saved position must not leave the planner un-openable.
Ruling: minimap button answers left click only; direct writes to MinimapPrefs().angle/.hide stay (no setter) — YAGNI — if wrong: two three-line setters.
Ruling: wide layout's screen share 0.56 -> 0.42 until plan 3 draws the map, so step text truncates less.
Ruling: spec follows the code on the no-route wording and on re-plan triggers; TAXI_NODE_STATUS_CHANGED marked unused everywhere (stale event names are a hazard under the hard-error rule).
Ruling: /reload leaves the planner closed (by design); recorded as a checklist line.
Deferred minors triage: T2 inn recursion closed by the fix round; T1 no-map START left (no caller can produce it); T3 Prefs hostile tests folded into this wave; T5 shared-planner test order annotated in the file.
Final review: fix wave dispatched (brief final-fix-brief.md), FIX_BASE ccaf291
Final review: fix wave 7b7a8ca, 244175b — scoped re-review: all 15 rulings addressed, no new breakage. Lua 120/0, Python 18 OK, luacheck 0, lls clean.
Final review: minor (deferred to plan 3): ui.notes wraps with no height cap; several long notes could reach the "Flight paths known" line. Plan 3 redraws the screen panel anyway.
Final review: minor (deferred): docs/research findings still mention TAXI_NODE_STATUS_CHANGED as an event to watch (historical research record).

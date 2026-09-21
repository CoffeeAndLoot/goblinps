# Task 4 report: Documents

## Status

Done. All three files updated, gates verified against baseline, one commit
made on `trips-survive`. `AGENTS.md` was left untracked, not staged.

## What changed

### `docs/manual-test-checklist.md`

- Added the new section "## A trip survives everything except Stop (plan 7)"
  above "## Flight paths survive a reload", verbatim per the brief (built
  2026-09-21, not yet run in the client; nine checklist lines covering
  Escape, Alt+Z, `/reload`, logout, Stop, arrival, the player's own pin,
  `/gps` mid-trip showing the trip's destination, and a second character
  getting nothing back).
- Grepped the file for `Escape`, `UISpecialFrames`, `OnHide`. One hit:
  "`/gps` opens the window: ... Escape closes it" (planner window, plan 2
  section) — left alone, since it is still true (the planner stays on
  Escape; only the dash came off `UISpecialFrames`).
- Found a second stale claim by reading the whole file, not caught by the
  grep terms: in the "Dash unit (plans 4 and 5)" section, "Drag the dash;
  its position survives /reload. /reload mid-trip ends the trip, by design"
  directly contradicted the new plan-7 behaviour. Corrected it to point at
  the new section and say only Stop ends a trip now.

### `CLAUDE.md`

- Status line: "plans 1 to 6 are built" to "plans 1 to 7 are built".
- Status paragraph: added plan 7 (what changed — off `UISpecialFrames`,
  `OnHide` no longer ends the trip, destination saved by name in
  account-wide `GoblinPSDB.trips`), stated plainly **plan 7 has not been run
  in the client**, and pointed "Next" at plan 8 (the planner rebuilt to the
  mockup, route strip replacing From/To/step-list). Added a short mention
  that Codex has delivered plan 8's wide geometry and the desk art tooling
  (8 Python tests, 6 `check_art.py` checks) is red by design until plan 8
  adapts it, with the addon itself unaffected — kept to two sentences per
  the brief's "keep it short, don't try to fix it". Also pointed the design
  reference at the new
  `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`
  as the amendment to the 09-19 design doc.
- Added the "Only Stop ends a trip" entry to "Rules that are easy to break",
  verbatim per the brief.
- Grepped `CLAUDE.md` for `Escape`, `UISpecialFrames`, `OnHide`: no existing
  hits before this edit, so nothing stale to correct there.

### `docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`

- Added `Built 2026-09-21 -- not yet run in the client.` directly under the
  "## Plan 7 — a trip survives everything except Stop" heading, before
  "### Behaviour".

## Things noticed but not touched (out of scope for this task)

- `GoblinPS/Dash.lua` line 245 has a stale code comment above the stop
  button: "It ends the trip exactly as Escape does." That is backwards now
  — Escape no longer ends the trip, only Stop does (the function comment
  five lines below it, on `Dash.Stop` itself, already says this correctly:
  "Nothing else does -- not Escape, not hiding the interface..."). This is
  a one-line comment fix in code, which this task's brief scoped out
  (documentation only, "nothing that runs should change"). Flagging it for
  whoever picks up code cleanup next; did not fix it here.

## Gates

- Lua suite: `306 passed, 0 failed` — matches baseline.
- `python -m unittest discover -s test/tools`: 51 run, 6 failures + 2
  errors = 8 failing — matches baseline (unchanged, plan-8 geometry drift,
  not this task's concern).
- `python tools/check_art.py`: 47 pass, 6 problems — matches baseline
  exactly (same six keys: `known_line`, `notes_line`, `from_box`,
  `here_button`, `layout_button`, `side_panel`).
- luacheck (PowerShell, `GoblinPS test`): `0 warnings / 0 errors in 38
  files`.
- lua-language-server (PowerShell, `--check D:\goblinps
  --checklevel=Warning`): `Diagnosis completed, no problems found`.

All five gates ran clean and unchanged from baseline, confirming this was a
docs-only change.

## Commit

`01d5525` — "Docs: a trip survives everything except Stop" on branch
`trips-survive`, three files (`CLAUDE.md`,
`docs/manual-test-checklist.md`,
`docs/superpowers/specs/2026-09-21-goblinps-planner-redesign-design.md`),
staged by explicit path. `AGENTS.md` was not staged or committed. Not
pushed.

Co-Authored-By line used `Claude Sonnet 5 <noreply@anthropic.com>` per this
session's active attribution instruction, rather than the brief's example
text naming Opus 5 (that example predates and is superseded by the
session's own attribution rule, which states it replaces any earlier copy).

## Concerns

- The stale `Dash.lua` code comment noted above (not fixed, out of scope).
- None of the documentation changes were otherwise ambiguous against the
  brief; the two stale-claim greps and the one extra stale line found by
  reading the full checklist were the only corrections needed.

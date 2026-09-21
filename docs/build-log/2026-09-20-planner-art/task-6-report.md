# Task 6 report: Documents

## Status

Done. All three files updated per the brief plus the five branch-specific
lessons called out in the task; gates run and green.

## Files changed

- `docs/superpowers/specs/2026-09-19-goblinps-design.md`: status header now
  lists seven plans (6 the planner's art, built, not run in the client; 7
  the route strip, split off because it draws inside the `screen` rectangle
  plan 6 places and that placement has never been on screen). Decision 5
  gained a paragraph on `images/parts/planner-geometry.json` as the
  placement authority, `tools/check_art.py` verifying it, `tools/make_art.py`
  copying it into `ns.Data.ArtGeometry.planner`, and the `tools_button`
  alias ruling (byte-identical to `close_button`, dropped by the generator).
- `docs/manual-test-checklist.md`: new `## Planner window art (plan 6)`
  section before the dash section, explicitly flagged as not yet run in the
  client. Kept the brief's item list and strengthened three items with the
  faults they guard against: the Wide/Tall button's visibility on brass
  after its reparenting fix, the screen scenery reading as a generous view
  rather than a narrow crop, and a new item for GO's art-based
  `button-disabled` cue (not a colour tint).
- `CLAUDE.md`: status paragraph updated (plan 6 built, not run in client;
  next is plan 7); layout map now notes `Widgets.lua` owns the shared
  placement helpers and `Stretch3`, and that `Planner.lua` hand-types no
  coordinate; the lua-language-server command now says **from PowerShell**
  explicitly, with the Git-Bash mis-scoping failure mode spelled out so a
  future agent doesn't go "fix" phantom warnings; "Rules that are easy to
  break" gained three entries: the `cw`/`ch` canvas-vs-master-PNG rule (with
  the 15.33%-vs-6.66% crop bug as the worked example), the stacked-vs-insert
  art rule, and a tightened lint-suppression rule that names the five
  existing `.luacheckrc` per-file exemptions as an established, bounded
  convention rather than a blanket permission.

## Commits

- `dde84b4` — "Document plan 6: the planner's art, and the lessons it left
  behind" (3 files changed, staged explicitly; `AGENTS.md` left untracked
  and untouched). Not pushed.

## Gate summary

All green, nothing else touched:
- Lua suite: 278 passed, 0 failed
- `python -m unittest discover -s test/tools`: 42 tests, OK
- `python tools/check_art.py`: 47 pass, 0 with problems, 0 not drawn yet
- luacheck (PowerShell): 0 warnings / 0 errors in 38 files
- lua-language-server `--check` (PowerShell): "Diagnosis completed, no
  problems found"

## Concerns

- None on scope or gates. One judgment call: the brief's "no lint
  suppression" ask had no existing "no lint suppression" rule text inside
  CLAUDE.md's "Rules that are easy to break" to tighten (that phrase lives
  in the plan doc and build-log, and CLAUDE.md's Commands section only says
  "Keep lint and the language server at zero warnings"). I added a new rule
  bullet rather than editing text that wasn't there, covering the same
  ground: the `.luacheckrc` exemptions are fine as generated-file
  exceptions, not a precedent for silencing a real warning on hand-written
  code. Worth a look in review to confirm that's the right home for it.
- I did not touch `docs/art-parts-brief-planner.md`, `images/parts/QUESTIONS.md`,
  or the plan file itself — the brief named only the design spec, the
  checklist and CLAUDE.md, and I kept to that.

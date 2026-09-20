# Task 6 report: Documents

Docs-only task; the TDD rule does not apply (no code). Evidence is the final
Lua test run and luacheck run, both after all edits.

## What was done

1. Created `docs/art-specs.md` verbatim per the brief (Step 1).
2. `docs/manual-test-checklist.md` (Step 2):
   - Appended the new `## Planner window (plan 2): check every line in BOTH
     layouts` section verbatim at the end of the file.
   - In `## Routing core (plan 1)`, ticked the two items beginning
     `- [ ] Known wart for plan 2:` and `- [ ] Inns in towns with no flight
     master` (changed `[ ]` to `[x]`) and appended ` (done in plan 2)` to
     each item's last line.
3. `CLAUDE.md` (Step 3):
   - Replaced the `**Status:` paragraph with the new plans-1-and-2 wording.
   - In the "Intended layout" code block, replaced the
     `GoblinPS/...  # Trip (pure arrival rules), planner window, dash unit,
     schematic map, Core` line with the six replacement lines from the
     brief (Known.lua/Prefs.lua, Data/Inns.lua, Widgets.lua, Planner.lua,
     MinimapButton.lua/SelfTest.lua/Core.lua, test/fake_frames.lua).
   - Under "Rules that are easy to break", replaced the three-line bullet
     starting `- Every constructor that leans on a Blizzard template or
     atlas` with the new "no Blizzard frame templates" bullet.
4. `docs/superpowers/specs/2026-09-19-goblinps-design.md` (Step 4):
   - Replaced the top status paragraph with the four-plan version.
   - Decision 7: replaced the final sentence (`Falls back to stock Blizzard
     templates if a texture is missing.`) with the new sentence about no
     Blizzard frame templates at all, and re-wrapped the whole paragraph to
     roughly 78 columns, keeping the `   ` (3-space) list indentation.
   - Decision 10: replaced the final sentence (`Add hand-written name rows
     only for misses met in game.`) with the new Data/Inns.lua sentence, and
     re-wrapped the whole paragraph to roughly 78 columns, keeping the
     `    ` (4-space) list indentation for a two-digit item.
   - Appended the zone-destination sentence to the end of the `Graph`
     (pure) bullet under "Modules".

Every edit was made with a targeted `Edit` (old_string/new_string) against
files read in full first; nothing else in any of the four files was
touched, reflowed or reworded.

## Commands run and output

Lua tests:

```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```
Output:
```
0
103 passed, 0 failed
```
Matches the expected `103 passed, 0 failed` from the brief.

luacheck (PowerShell):
```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
$env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
```
Output:
```
Total: 0 warnings / 0 errors in 31 files
```
Matches the expected `0 warnings`.

## Commit

Staged only `docs` and `CLAUDE.md` (verified with `git status --short` before
committing — the four expected files only: `CLAUDE.md` (M), `docs/art-specs.md`
(A), `docs/manual-test-checklist.md` (M),
`docs/superpowers/specs/2026-09-19-goblinps-design.md` (M); nothing under
`.superpowers/` was staged).

```
git add docs CLAUDE.md
git commit -m "Docs: planner window checklist, art specs, four-plan roadmap" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

Result: commit `fedbe42` "Docs: planner window checklist, art specs,
four-plan roadmap" — 4 files changed, 101 insertions(+), 22 deletions(-).

## Self-review

Read `git show --stat HEAD` and the full diff of the three modified files
after committing (art-specs.md diff omitted from the check since it is a new
file whose content was written verbatim from the brief). Confirmed:
- `docs/art-specs.md` present, new file, content matches Step 1 verbatim.
- `docs/manual-test-checklist.md` diff shows exactly the two `[x]` ticks
  with the appended " (done in plan 2)" text and the new section appended
  at file end, nothing else changed.
- `CLAUDE.md` diff shows exactly the three intended hunks (status paragraph,
  layout block, rules bullet), nothing else changed.
- `docs/superpowers/spec's` diff shows exactly the four intended hunks
  (status paragraph, decision 7 rewrap, decision 10 rewrap, Graph bullet
  append), nothing else changed.

No unexpected diffs found. Both verification commands were run after all
edits, matching the brief's expected counts exactly, so no STOP condition
was triggered.

## Concerns

None. Everything matched the brief's expected text and counts.

## Hand-over (Step 6, reported here per dispatch instructions instead of as an action)

The desktop work (docs, Lua tests, luacheck) is verified only on the desktop
toolchain. Nothing in this plan — the planner window, minimap button,
addon compartment, hearthstone/inn behaviour, or any of the new
`## Planner window (plan 2)` checklist items — has been run or checked in
the actual WoW Forever client. The user must restart the game (the TOC
changed) and work through the `## Planner window (plan 2): check every line
in BOTH layouts` section of `docs/manual-test-checklist.md` in both the Wide
and Tall layouts before any of those checks can be claimed to pass.

# Task 3 report: Three shared placement helpers, and Dash moved onto them

## Status: DONE

## What was done

Followed the brief's steps in order, on branch `planner-art`, in `D:\goblinps`.

1. **Failing test first.** Added the "the shared placement helpers" `h.describe`
   block to `test/test_ui.lua`, verbatim from the brief, placed right after the
   existing `"Widgets.ChatColor"` block (the only pre-existing widget-only test
   group) and before `"the planner window"`. Added `local W = ns.Widgets` next
   to the existing `local Planner = ns.Planner` so the brief's `W.` calls
   resolve — no such alias existed in the file before.
   Ran the suite: **258 passed, 4 failed**, all four failures
   `attempt to call field 'PlaceX' (a nil value)`, exactly as predicted.

2. **Wrote the three helpers** in `GoblinPS/Widgets.lua`, right after
   `Widgets.Text`, verbatim from the brief: `PlaceRect`, `PlaceLine`,
   `PlaceCircle`, with the hard-earned comment block about never reading a
   size from a `SetAllPoints` frame carried over intact.
   Ran the suite: **262 passed, 0 failed**.

3. **Migrated `GoblinPS/Dash.lua`.** Deleted the private `placeLine` function
   and its comment block entirely, and replaced all four call sites with
   `W.PlaceLine(...)`, keeping `f` (the device with the explicit `SetSize`) as
   the second argument exactly as before. Also fixed a stale comment at the
   `centreOnDial` local ("See placeLine's note.") to say "See
   Widgets.PlaceLine's note." instead, since the function it pointed at moved
   out of this file — not in the brief's steps, but a plain accuracy fix while
   touching the surrounding code. `centreOnDial` itself was left untouched, as
   instructed.
   Ran the suite: **262 passed, 0 failed** — the same 262, unchanged.

4. **Proved the net still bites.** Copied the whole repo to a scratch
   directory outside `D:\goblinps`
   (`...\scratchpad\goblinps-scratch`), and there only, changed
   all four `W.PlaceLine(x, f, ...)` calls in `Dash.lua` to pass `content`
   (the `SetAllPoints` frame) instead of `f`. Ran the suite in the scratch
   copy: **260 passed, 2 failed**, and the two failures were exactly the two
   the brief names:
   - `the dash unit :: sits all three step lines on the centre of their third of the art's steps box`
   - `the dash unit :: sits the destination, distance and ETA on their own centre lines too`

   Deleted the scratch copy afterward. Nothing inside `D:\goblinps` was ever
   touched by this step; `git status` in the real repo showed only the three
   intended files modified throughout.

## Gates (all run before committing)

| Gate | Baseline | Result |
|---|---|---|
| Lua suite (`test/run.lua`) | 258 passed, 0 failed | **262 passed, 0 failed** |
| `python -m unittest discover -s test/tools` | 42 | **42, OK** |
| `python tools/check_art.py` | 47 pass, 0 with problems, 0 not drawn yet | **47 pass, 0 with problems, 0 not drawn yet** (unchanged — this task touched no art) |
| luacheck (`GoblinPS test`) | 0 warnings, 38 files | **0 warnings, 38 files** |
| lua-language-server `--check` | zero warnings | **"Diagnosis completed, no problems found"**, 38/38 files |

One wrinkle on the last gate, noted for the record: running the exact
`lua-language-server --check D:\goblinps ...` command through the Bash tool
(Git Bash / MSYS) silently mis-scoped the workspace root down to
`D:\goblinps\GoblinPS` alone (23 files, not 38) and reported 109 "undefined
global" warnings for things like `CreateFrame` and `UIParent` that
`.luarc.json` already lists — that's Git Bash's automatic Windows-path
argument mangling, not a real problem in the code or config. I confirmed this
by running the identical check against a disposable `git worktree` of `HEAD`
(clean, no problems) and then via the PowerShell tool with the same
literal command from the brief, which correctly scanned all 38 files and
reported zero warnings. Cleaned up the worktree and temp JSON output files
afterward. Lesson for next time: run the language-server check via
PowerShell, not Bash, on this box.

## Commit

```
bac3fdd Three shared placement helpers, and the dash moved onto them
```

Staged explicitly: `GoblinPS/Widgets.lua GoblinPS/Dash.lua test/test_ui.lua`.
`AGENTS.md` (untracked, belongs to Codex) was left alone and is still
untracked after the commit. Not pushed.

## Concerns

None outstanding. The only thing worth flagging is the Bash/PowerShell
path-mangling quirk above — purely a local tooling gotcha on this Windows box,
already worked around, and it left no trace in the repo (no files or worktrees
left behind).

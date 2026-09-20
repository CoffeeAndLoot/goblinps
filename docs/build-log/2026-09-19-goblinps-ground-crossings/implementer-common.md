# Implementer instructions (common to every task)

Project: GoblinPS, a World of Warcraft addon (route planner) in plain Lua 5.1, plus Python tools.
Work from `D:\goblinps` on branch `ground-crossings` (already checked out). Windows 11; the Bash tool is Git Bash, PowerShell is also available.

Your task brief contains the COMPLETE code for every new file and the exact edits for every changed file, already
verified to pass together. Your job is faithful transcription plus running the checks: copy each code block into
its file **byte-for-byte** (do not reformat, rename, "improve" or reorder anything), make each edit exactly where
the brief says, follow the steps in order, and run every command the steps name. Write files with LF line endings.
Read an existing file before you edit it.

## Global constraints (bind every task)

- Plain Lua 5.1 against the Blizzard API. No libraries. No secure code.
- Pure modules (Geo, Search, Graph, Route, Trip, Known, Prefs) touch no Blizzard global.
- `GoblinPS/API.lua` is the only file that calls Blizzard game APIs and registers game events.
- The window uses NO Blizzard frame templates.
- `GoblinPS/Data/Places.lua`, `Nodes.lua`, `Flights.lua` are GENERATED: never edit them. `Links.lua` and `Inns.lua` are hand-written.
- luacheck must stay at `Total: 0 warnings / 0 errors`.
- Commit at the end of the task with the exact command the brief gives (two `-m` flags). Do NOT push. Do NOT touch `main`.
  Stage only the files the brief names (never `git add -A`), except where the brief's own command says otherwise.

## Commands (run from D:\goblinps)

Lua tests (prints `N passed, M failed`, any failures, then `0` or `1`):

    python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"

Python tests:

    python -m unittest discover -s test/tools

luacheck (PowerShell):

    $env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
    $env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
    lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache

If an expected count or output in the brief does not match what you see, STOP and report it; do not edit code to force a match.

## Rules

- Follow TDD as the steps lay it out: add the test, run it and record the failure (RED), make the change, run it and record the pass (GREEN).
- Do all the work yourself. Never dispatch subagents, and never spawn a reviewer; review is the controller's job.
- If something is unclear or unexpected, stop and report BLOCKED or NEEDS_CONTEXT with specifics.
- Before reporting, read your own diff and confirm every file the brief lists is present and matches.
- If resumed later with review findings: fix them, re-run the covering tests, and append a fix report to the same report file.

## Report

Write the full report to the report file named in your dispatch: what you did; commands run and their output;
TDD evidence (RED output and why it was expected, GREEN output); files changed; self-review findings; concerns.

Then reply with ONLY (under 15 lines):
- **Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- Commits created (short SHA + subject)
- One-line test summary
- Concerns, if any
- The report file path

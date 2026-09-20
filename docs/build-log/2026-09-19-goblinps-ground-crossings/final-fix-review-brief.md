# Scoped re-review — final fix wave, GoblinPS ground crossings

Repo `D:\goblinps`, branch `ground-crossings` (checked out, do not switch branches, do not commit, do not push).

The final whole-branch review of plan 3 returned "ready to merge with fixes". A fix wave was dispatched with the brief
`final-fix-brief.md` (in this folder). Its three commits landed, but the implementer was interrupted before writing its
report, so **nothing has checked the fix wave**. That is your job.

This is a **scoped** re-review: judge the fix wave only. Do not re-review the rest of the branch, and do not re-open
findings the final review already settled.

## What to read

1. `final-fix-brief.md` in this folder — the instructions the implementer was given. Items F1 to F9.
2. `reviewer-constraints.md` in this folder — the rules that bind all of plan 3.
3. `review-051e935..ed9e8ba.diff` in this folder — the whole fix wave as one diff (images excluded).
4. The files themselves in the working tree, whenever the diff is not enough.

The three commits are `981e045`, `8399fe6`, `ed9e8ba`. `c3bc9a7` on top of them is a docs-only commit that is NOT part
of this wave: ignore it.

## What to judge

For each of F1 through F9, answer: was it done, done completely, and done without breaking something else?

Pay particular attention to these, where a plausible-looking change can still be wrong:

- **F1 (names read both ways).** Check the rename table row by row against `GoblinPS/Data/Crossings.lua`. Every row in
  the table must have its new name, spelled exactly. Rows NOT in the table must be unchanged. The new guard test must
  actually be able to fail — read it and say what input would trip it.
- **F2 (`cross` seconds).** The cost must be paid **once per traversal**, on every ride edge whose destination is that
  crossing stop. Verify by reading `Graph.Build`: is it added to edges in both directions? Is it added twice anywhere
  (for example, once on arrival and again on departure)? Is a crossing reached as a zone destination charged correctly?
- **F3 (`unverified` shown).** Confirm the flag reaches `Route.StepDetail` through `Graph.Build`, that the amber warn is
  returned, and that the pinning test lists exactly the seven rows named in the brief and no others.
- **F6 (hazard never truncated).** The rule is that a hazard OR an unverified note **replaces** the level clause, and
  that when a row has both, the hazard comes first and the unconfirmed note second. Check the ordering explicitly. The
  66-character test must run over the REAL crossings data in both directions, not over a fake world.
- **F8 (last step always visible).** Check the arithmetic in `Planner.Refresh` against `MAX_ROWS`: with exactly
  `MAX_ROWS` steps, with `MAX_ROWS + 1`, and with many. Does N count only the steps hidden between? Is any step shown
  twice, or skipped?
- **F9 (one source of mount speed).** Confirm `Graph.RIDE_YARDS_PER_SECOND` is gone and nothing else hard-codes a mount
  speed. The lookup must happen at call time, not at load time.

Also check the commit 3 documentation edits landed as specified, and that the `docs/manual-test-checklist.md` item for
Orgrimmar's west gate really is at the top of its section with the "FIRST:" wording.

## Verify, do not assume

Run all four gates yourself and report the actual output:

```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```
```
python -m unittest discover -s test/tools
```
luacheck (PowerShell):
```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"; $env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"; lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
```
```
lua-language-server --check D:\goblinps --checklevel=Warning --check_out_path=$env:TEMP\goblinps-lls-rereview.json
```

Then, for the behaviour the tests do not pin, **plan real routes** with a scratch Lua script that loads the real data
(copy the module-loading pattern from `test/run.lua`) and print the steps, details and total for at least:

- Tirisfal Glades to Mount Hyjal (the brief names this one)
- Orgrimmar to Undercity
- Ironforge to Gadgetzan
- a route through Blackrock Mountain and one through the Timbermaw tunnels, so the `cross` seconds show up
- a route long enough to overflow the planner's 8 rows

Read the printed details. Any detail line longer than 66 characters, any name that reads backwards for the direction
travelled, any missing or doubled passage time is a finding. Put your scratch script in the session scratchpad, not in
the repo. Do not stage or commit anything.

You cannot run the game client. Claim nothing about in-game behaviour.

## Report

Write `D:\goblinps\.superpowers\sdd\2026-09-19-goblinps-ground-crossings\final-fix-review.md`:

- A verdict line: `approved` / `approved with minors` / `needs fixes`.
- A table: F-item, verdict, evidence (file:line).
- Findings, each rated Critical / Important / Minor, each with the failing input or the exact wrong output. No finding
  without evidence; if you suspect something but cannot demonstrate it, say so and label it a suspicion.
- The four gates' real output.
- The printed routes.

Then reply with ONLY: the verdict, the count by severity, the one thing most worth my attention, and the report path.

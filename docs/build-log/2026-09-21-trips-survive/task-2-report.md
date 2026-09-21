# Task 2 report: Only Stop ends a trip

## Status
DONE

## Commit
- `3bdfbad` "Only Stop ends a trip" on branch `trips-survive`
  (`GoblinPS/Dash.lua`, `.luacheckrc`, `.luarc.json`, `test/test_ui.lua`; 4 files changed, 67 insertions, 23 deletions)

## What was done
Followed the brief's steps exactly:

1. Rewrote the `"the dash unit and Escape"` block in `test/test_ui.lua` to the
   four tests given verbatim, and changed the assertion message in
   `"still ends the trip when the button is clicked"` from
   "clicking Stop ends the trip, as Escape does" to "clicking Stop ends the
   trip".
2. Ran the Lua suite before touching `Dash.lua`: 296 passed, 4 failed, all
   four failures in the new Escape block, for the reasons the brief predicted
   (dash still on Escape's list; hiding still cleared `state.plan`; Stop left
   the saved trip and pin).
3. In `GoblinPS/Dash.lua`'s `build()`: removed the `OnHide` script (and its
   comment) and removed `ns.Core.CloseOnEscape(f, "GoblinPSDash")`.
4. Replaced `Dash.Stop` to clear `state`, call `ns.Core.ClearTrip()` and
   `ns.Core.ClearPin()`, then hide the frame if built.
5. In `finish()`, added `ns.Core.ClearPin()` right after `ui.arrow:Hide()`.
6. In `Dash.Tick`, widened the first guard to
   `not ui or not state.plan or not ui.frame:IsShown()`.
7. Removed `"GoblinPSDash"` from the globals lists in both `.luacheckrc` and
   `.luarc.json`.
8. Reran the Lua suite: 300 passed, 0 failed.
9. Ran luacheck and lua-language-server, both from PowerShell: 0
   warnings/errors in 38 files; language server "Diagnosis completed, no
   problems found".
10. Committed the four listed files only, with the message from the brief.
    Per this session's active attribution instruction (which supersedes the
    brief's own commit-message line), the trailer used is
    `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` rather than the
    "Claude Opus 5" line written into the brief's example command.

## Baseline check (not mine to fix, confirmed unchanged)
- `python -m unittest discover -s test/tools`: 51 run, 6 failures + 2 errors
  = 8 failing -- matches the stated baseline.
- `python tools/check_art.py`: 47 pass, 6 with problems -- matches the stated
  baseline.
- Did not run `tools/make_art.py`, as instructed.

## Test summary
Lua suite: 300 passed, 0 failed (from 297 baseline; the Escape block went
from 1 test to 4, net +3, matching the brief's expected "300 passed"). Zero
luacheck warnings, zero lua-language-server problems.

## Concerns
None. Every step in the brief applied cleanly, no other existing test's
assertion needed to change, and `AGENTS.md` was left untouched and unstaged.

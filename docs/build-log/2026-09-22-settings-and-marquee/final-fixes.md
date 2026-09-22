# Final review fix wave (plan 9)

## Must fix
I1. The results list draws over the settings panel. Both are DIALOG strata. The panel (Settings.lua ~103-105, created on UIParent) gets the planner's level; the list (Planner.lua ~719-721) is planner level + 3. The dropdown button (~558 px) and the search box's ends stick out past the panel (165-485 px), so the list can be reopened while the panel is up, and it then covers the panel and takes its clicks.
   Fix both:
   (a) In Settings.Open, raise the panel above the list, e.g. `ui.frame:SetFrameLevel(anchor:GetFrameLevel() + 10)`. Comment why.
   (b) `showResults` does nothing while the settings panel is shown. Opening the panel already dismisses the list.
   Tests: the panel's frame level is above ui.results'; clicking the dropdown with the panel open shows no list. Pin both. The fake models SetFrameLevel/GetFrameLevel.

## Sweep
M1. Planner.lua ~458-460: give the drop-down a couple of pixels of slack past the widest label, so a client rounding down doesn't put "..." on the longest name. Name the constant (e.g. SLACK = 4) and update the width test.
M3. docs/manual-test-checklist.md:
    - The About version check appears twice (~472 and ~492). Keep one.
    - The Escape line (~493): the client's CloseSpecialWindows hides every UISpecialFrames window at once, so one Escape closes the panel AND the planner. Say that, and make the line "- [ ] One Escape closes the settings panel and the planner together (that is how the client's Escape list works): say whether that is acceptable, or whether Escape should close only the panel".
M4. test_ui.lua ~2905: the label "is the panel's alone" is only true for a direct :Hide(). Reword it to say so.
M5. docs/later.md: add one line under the entries: "- **Shorter step text on the dash:** run step names through Search.Label/ShortName before scrolling, so a line only scrolls when it is genuinely long. (Left over from the marquee entry when plan 9 built the scrolling.)"
M6. CLAUDE.md ~90 and ~104: line the Marquee.lua and Settings.lua comment columns up with the rest of the layout block.

All five gates green (Lua at 388; expect +2 or so). Commit "Final review fixes: the settings panel above the drop-down, and a sweep" with "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>". Never stage AGENTS.md (it is gitignored anyway).

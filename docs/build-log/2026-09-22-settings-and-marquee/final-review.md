# Final whole-branch review, plan 9 (base b45d078, head 948fff5)

Verdict: merge after one fix. Tests 388/0, luacheck 0 at review time.

Verified sound: no size read from an inheriting frame (dash slots from geometry x explicit width; drop-down from GetUnboundedStringWidth); every new client method present on the forever branch (GetUnboundedStringWidth, HighlightText, SetMaxLetters, C_AddOns.GetAddOnMetadata); TOC load order (Trip, Marquee, Known, Prefs, Widgets, Planner, Settings, Dash, Core); bounded FontStrings; per-frame cost of Steer + Scroll small; no doc claims plan 9 ran in game.

Important (fixed in 452b59a): the results list (DIALOG, planner level + 3) drew over the settings panel (DIALOG, planner level) and could be reopened past the panel's edges. The panel is now raised 10 levels above its anchor, and the list refuses to open while the panel shows.

Minor: drop-down had zero slack (SLACK = 4 added); Marquee builds two strings per frame while scrolling (parked, YAGNI); checklist duplicate and the Escape line (fixed); a misleading test label (fixed); a later.md idea lost in the swap (restored); CLAUDE.md column alignment (fixed).

Re-review of the fix wave: all addressed. Two residuals parked (see progress.md): showResults uses the test-only Settings.Debug(); /gps settings does not dismiss an open results list.

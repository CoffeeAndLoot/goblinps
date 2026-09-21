# Final whole-branch review, plan 8 (base 08655fe, head 1d2d1c0)

Verdict: ready to merge after two Important fixes. Reviewer re-ran the gates: Lua 329, luacheck 0, Python 55, check_art 47.

Verified as sound: strip draw order (strip is a child of the opaque screen; lines BORDER, dots ARTWORK, badges child frames above; results list on DIALOG strata over it); every size read from ui.frame (explicit SetSize); every FontString bounded; REPEAT/CLAMP tiling matches SimpleTextureBaseAPIDocumentation.lua:600-614 on a 128x16 unpadded part; Strip.lua pure and to spec; plan 7 seeding intact; no doc claims plan 8 ran in game.

Important (fixed in 775df25):
1. Line and dot tests pinned only x, not anchor, relative frame or y (test_ui.lua ~925-942); solid leg's texcoord check read line-dashed's part.
2. stripMetrics read ArtGeometry.planner.strip unguarded (Planner.lua:39): a missing `strip` would throw on every /gps open.

Minor:
1. End badges' names get ~65 px; "You are here" or a long destination may truncate. Checklist line added.
2. A stop warning takes the one amber line, hiding "no flights" / "unknown inn" notes on hazardous routes. Kept per spec (ruling); raised to the owner.
3. At 11+ stops a badge's 58.5 px hover area overlaps its neighbour; at 13+ rings touch. SetHitRectInsets is IsProtectedFunction on this build, so not used (ruling); checklist line added.
4. No-art fallback is a square, not a circle (plan ruling).
5. Stale words: spec 327-330, checklist plan 3 section, CLAUDE.md "GO", coverCrop comment. Swept in 775df25.

Rulings judged sound: T1 unknown-kind tooltip in Strip; T2 count; T3 backdrop tests trimming height; T4 narrowing.

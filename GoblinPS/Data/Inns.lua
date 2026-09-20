-- HAND-WRITTEN. Hearthstone bind names that Search cannot find by itself.
-- GetBindLocation() returns the SUBZONE you bound in, not the town. Sometimes
-- that is the town ("The Crossroads"), but inside a town it is usually the
-- inn building itself: binding in Brill reports "Gallows' End Tavern"
-- (seen in game 2026-09-20). Most names match a flight stop or a zone once a
-- leading "The" is ignored. These do not:
--   stop = "<short flight stop name>"  the inn stands beside that flight stop
--   map, mx, my                        a town with an inn and no flight master;
--                                      map coords (0..1), APPROXIMATE until
--                                      checked from docs/manual-test-checklist.md
-- Add a row whenever the addon prints "Hearth: unknown inn (...)".
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Inns = {
    ["Grom'gol Base Camp"]     = { stop = "Grom'gol" },
    ["Theramore Isle"]         = { stop = "Theramore" },
    ["Feathermoon Stronghold"] = { stop = "Feathermoon" },

    ["Razor Hill"]        = { map = 1411, mx = 0.515, my = 0.416 }, -- Durotar
    ["Bloodhoof Village"] = { map = 1412, mx = 0.466, my = 0.611 }, -- Mulgore
    ["Brill"]             = { map = 1420, mx = 0.617, my = 0.520 }, -- Tirisfal Glades
    ["Goldshire"]         = { map = 1429, mx = 0.438, my = 0.658 }, -- Elwynn Forest
    ["Kharanos"]          = { map = 1426, mx = 0.474, my = 0.525 }, -- Dun Morogh
    ["Dolanaar"]          = { map = 1438, mx = 0.556, my = 0.598 }, -- Teldrassil
}

-- Inn buildings, whose own name is what GetBindLocation reports. Each shares
-- the row of the town it stands in rather than repeating its coordinates, so
-- correcting the town in game corrects the tavern with it. Add a line here
-- whenever the addon prints "Hearth: unknown inn (...)" for a name that is a
-- building inside a town already listed above.
ns.Data.Inns["Gallows' End Tavern"] = ns.Data.Inns["Brill"]

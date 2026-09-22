-- HAND-WRITTEN. Where you can walk from one zone into the next. Ground travel
-- happens inside one zone at a time; a crossing is a named point that belongs
-- to both of its zones, so the router chains zones through these rows. Cities
-- are zones too, and their gates are crossings. A zone with no row here (or
-- only a row to its own city) is an island: boats and flights only.
--
--   a, b    the two zones (UiMap IDs; names in the trailing comment)
--   name    what the step says: "Walk to <name>"; include "the" where it reads better. A name
--           must read correctly whichever way you are going ("the Ashenvale-Felwood road", not
--           "the road into Felwood"); the detail line ("into <zone>") gives the direction.
--   map, mx, my   the point, as map coords (0..1) on ONE of the two zones.
--           APPROXIMATE: written from memory of the classic world, corrected in
--           game from docs/manual-test-checklist.md, like the dock positions.
--   warn    optional, short: shown in amber on the step's detail line
--   cross   optional seconds: a tunnel, a lift or a mountain pass takes time to walk even
--           though the crossing is one point for both zones; added once per traversal, to
--           the leg that arrives at this crossing (see Graph.Build)
--   unverified = true   Forever's new zones: the crossing itself is a guess
--
-- Which zones border which, the place names and the level ranges are facts
-- about Blizzard's game; the Forever Atlas fan site's table was used as a
-- checklist of those facts. The rows, wording and coordinates here are our own. test/test_crossings.lua checks every row and that each continent's
-- zones all connect (bar the islands listed there).
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Crossings = {
    -- Kalimdor: cities
    { a = 1454, b = 1411, name = "Orgrimmar's front gate", map = 1411, mx = 0.455, my = 0.120 }, -- Orgrimmar, Durotar
    { a = 1454, b = 1413, name = "Orgrimmar's west gate", map = 1454, mx = 0.170, my = 0.630, unverified = true }, -- Orgrimmar, The Barrens
    { a = 1456, b = 1412, name = "the Thunder Bluff lifts", map = 1456, mx = 0.318, my = 0.661, cross = 30 }, -- Thunder Bluff, Mulgore; the west lifts, measured in game 2026-09-22 (the guess was ~314 yd off)
    { a = 1457, b = 1438, name = "the Darnassus gate", map = 1438, mx = 0.365, my = 0.540 },     -- Darnassus, Teldrassil
    -- Kalimdor: zones
    { a = 1411, b = 1413, name = "the Southfury bridge", map = 1411, mx = 0.345, my = 0.425 },   -- Durotar, The Barrens
    { a = 1413, b = 1412, name = "the Mulgore pass", map = 1413, mx = 0.418, my = 0.586 },  -- The Barrens, Mulgore; measured in game 2026-09-22 (the guess was ~160 yd off)
    { a = 1413, b = 1440, name = "the Mor'shan Rampart", map = 1413, mx = 0.485, my = 0.055 },   -- The Barrens, Ashenvale
    { a = 1413, b = 1442, name = "the Stonetalon pass", map = 1413, mx = 0.345, my = 0.280 },    -- The Barrens, Stonetalon Mountains
    { a = 1413, b = 1445, name = "the Dustwallow road", map = 1413, mx = 0.495, my = 0.785 }, -- The Barrens, Dustwallow Marsh
    { a = 1413, b = 1441, name = "the Great Lift", map = 1413, mx = 0.440, my = 0.910, cross = 45 }, -- The Barrens, Thousand Needles
    { a = 1441, b = 1444, name = "the Feralas-Thousand Needles road", map = 1441, mx = 0.085, my = 0.115 },  -- Thousand Needles, Feralas
    { a = 1441, b = 1446, name = "the Thousand Needles-Tanaris pass", map = 1446, mx = 0.510, my = 0.220 },  -- Thousand Needles, Tanaris
    { a = 1446, b = 1449, name = "the Un'Goro ramp from Tanaris", map = 1446, mx = 0.270, my = 0.520 },  -- Tanaris, Un'Goro Crater
    { a = 1449, b = 1451, name = "the Un'Goro-Silithus ramp", map = 1449, mx = 0.295, my = 0.220 }, -- Un'Goro Crater, Silithus
    { a = 1444, b = 1443, name = "the Feralas-Desolace road", map = 1444, mx = 0.450, my = 0.080 }, -- Feralas, Desolace
    { a = 1443, b = 1442, name = "the Charred Vale pass", map = 1443, mx = 0.535, my = 0.040 }, -- Desolace, Stonetalon Mountains
    { a = 1442, b = 1440, name = "the Talondeep Path", map = 1440, mx = 0.420, my = 0.710, cross = 45 },     -- Stonetalon Mountains, Ashenvale
    { a = 1440, b = 1439, name = "the Ashenvale-Darkshore road", map = 1440, mx = 0.285, my = 0.140 }, -- Ashenvale, Darkshore
    { a = 1440, b = 1448, name = "the Ashenvale-Felwood road", map = 1440, mx = 0.555, my = 0.280 },  -- Ashenvale, Felwood
    { a = 1440, b = 1447, name = "the Ashenvale-Azshara road", map = 1440, mx = 0.945, my = 0.470 },  -- Ashenvale, Azshara
    { a = 1448, b = 1452, name = "the Timbermaw Hold tunnels", map = 1448, mx = 0.650, my = 0.080, cross = 90, -- Felwood, Winterspring
      warn = "Timbermaw furbolgs attack without reputation" },
    { a = 1448, b = 1450, name = "the Timbermaw Hold tunnels", map = 1450, mx = 0.360, my = 0.720, cross = 90, -- Felwood, Moonglade
      warn = "Timbermaw furbolgs attack without reputation" },
    { a = 1452, b = 2482, name = "Darkwhisper Gorge", map = 1452, mx = 0.590, my = 0.840, cross = 60, unverified = true }, -- Winterspring, Mount Hyjal
    { a = 1452, b = 1450, name = "the Timbermaw Hold tunnels", map = 1452, mx = 0.270, my = 0.350, cross = 90, -- Winterspring, Moonglade
      warn = "Timbermaw furbolgs attack without reputation" },
    -- Blizzard has said Shen'dralas is entered from Desolace by the Valley of Bones; the point is a guess.
    { a = 1443, b = 2652, name = "the Valley of Bones", map = 1443, mx = 0.550, my = 0.850, unverified = true }, -- Desolace, Shen'dralas

    -- Eastern Kingdoms: cities
    { a = 1458, b = 1420, name = "the Ruins of Lordaeron", map = 1420, mx = 0.619, my = 0.648 }, -- Undercity, Tirisfal Glades
    { a = 1453, b = 1429, name = "the Stormwind gates", map = 1429, mx = 0.320, my = 0.490 },    -- Stormwind City, Elwynn Forest
    { a = 1455, b = 1426, name = "the gates of Ironforge", map = 1426, mx = 0.530, my = 0.350 }, -- Ironforge, Dun Morogh
    -- Eastern Kingdoms: zones
    { a = 1420, b = 1421, name = "the Tirisfal-Silverpine road", map = 1420, mx = 0.540, my = 0.740 }, -- Tirisfal Glades, Silverpine Forest
    { a = 1420, b = 1422, name = "the Bulwark", map = 1420, mx = 0.835, my = 0.690 },            -- Tirisfal Glades, Western Plaguelands
    { a = 1421, b = 1424, name = "the Silverpine-Hillsbrad road", map = 1421, mx = 0.655, my = 0.780 }, -- Silverpine Forest, Hillsbrad Foothills
    { a = 1424, b = 1416, name = "the Hillsbrad-Alterac road", map = 1424, mx = 0.550, my = 0.130 },  -- Hillsbrad Foothills, Alterac Mountains
    { a = 1424, b = 1417, name = "Thoradin's Wall", map = 1417, mx = 0.200, my = 0.290 },        -- Hillsbrad Foothills, Arathi Highlands
    { a = 1424, b = 1425, name = "the Hillsbrad-Hinterlands road", map = 1425, mx = 0.070, my = 0.470 }, -- Hillsbrad Foothills, The Hinterlands
    { a = 1416, b = 1422, name = "the Alterac-Plaguelands road", map = 1422, mx = 0.430, my = 0.850 }, -- Alterac Mountains, Western Plaguelands
    { a = 1422, b = 1423, name = "the Thondroril River bridge", map = 1423, mx = 0.070, my = 0.430 }, -- Western Plaguelands, Eastern Plaguelands
    { a = 1417, b = 1437, name = "the Thandol Span", map = 1417, mx = 0.445, my = 0.880 },       -- Arathi Highlands, Wetlands
    { a = 1437, b = 1432, name = "the Dun Algaz tunnels", map = 1432, mx = 0.250, my = 0.100, cross = 90 },  -- Wetlands, Loch Modan
    { a = 1432, b = 1426, name = "the Valley of Kings gates", map = 1432, mx = 0.200, my = 0.630 }, -- Loch Modan, Dun Morogh
    { a = 1432, b = 1418, name = "the Loch Modan-Badlands road", map = 1432, mx = 0.470, my = 0.780 }, -- Loch Modan, Badlands
    { a = 1418, b = 1427, name = "the Badlands-Searing Gorge pass", map = 1418, mx = 0.060, my = 0.610 }, -- Badlands, Searing Gorge
    { a = 1427, b = 1428, name = "Blackrock Mountain", map = 1427, mx = 0.350, my = 0.840, cross = 120, -- Searing Gorge, Burning Steppes
      warn = "through Blackrock Mountain" },
    { a = 1428, b = 1433, name = "the Burning Steppes-Redridge pass", map = 1428, mx = 0.780, my = 0.850 }, -- Burning Steppes, Redridge Mountains
    { a = 1433, b = 1429, name = "the Three Corners road", map = 1429, mx = 0.930, my = 0.720 }, -- Redridge Mountains, Elwynn Forest
    { a = 1433, b = 1431, name = "the Redridge-Duskwood bridge", map = 1431, mx = 0.940, my = 0.100 }, -- Redridge Mountains, Duskwood
    { a = 1429, b = 1436, name = "the Westfall bridge", map = 1429, mx = 0.210, my = 0.800 },    -- Elwynn Forest, Westfall
    { a = 1429, b = 1431, name = "the bridge south of Goldshire", map = 1431, mx = 0.445, my = 0.070 }, -- Elwynn Forest, Duskwood
    { a = 1436, b = 1431, name = "the Westfall-Duskwood bridge", map = 1431, mx = 0.080, my = 0.630 }, -- Westfall, Duskwood
    { a = 1431, b = 1434, name = "the Duskwood-Stranglethorn road", map = 1434, mx = 0.380, my = 0.030 }, -- Duskwood, Stranglethorn Vale
    { a = 1431, b = 1430, name = "the Duskwood-Deadwind road", map = 1430, mx = 0.170, my = 0.500 }, -- Duskwood, Deadwind Pass
    { a = 1430, b = 1435, name = "the Deadwind-Swamp road", map = 1435, mx = 0.030, my = 0.600 }, -- Deadwind Pass, Swamp of Sorrows
    { a = 1435, b = 1419, name = "the Swamp-Blasted Lands road", map = 1419, mx = 0.520, my = 0.080 }, -- Swamp of Sorrows, Blasted Lands
    -- Riverglades: a turnoff on the Redridge road to the Burning Steppes is reported. Blizzard has said it also
    -- borders the Burning Steppes, the Swamp of Sorrows and the Badlands; where you cross is not known yet.
    { a = 1433, b = 2548, name = "the Riverglades turnoff", map = 1433, mx = 0.550, my = 0.150, unverified = true }, -- Redridge Mountains, Riverglades
    { a = 1428, b = 2548, name = "the Riverglades-Burning Steppes border", map = 1428, mx = 0.950, my = 0.500, unverified = true }, -- Burning Steppes, Riverglades
    { a = 1435, b = 2548, name = "the Riverglades-Swamp border", map = 1435, mx = 0.500, my = 0.030, unverified = true }, -- Swamp of Sorrows, Riverglades
    { a = 1418, b = 2548, name = "the Riverglades-Badlands border", map = 1418, mx = 0.500, my = 0.950, unverified = true }, -- Badlands, Riverglades
}

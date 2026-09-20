-- HAND-WRITTEN. Boats, zeppelins and the tram: nothing in Blizzard's tables
-- describes them. Later, zone-to-zone ground crossings go here too, as more
-- rows, not a redesign.
--
-- Dock positions are map coords (0..1) on a zone map and are APPROXIMATE:
-- each one is checked in game from docs/manual-test-checklist.md.
-- minutes = the ride plus about half the loop, the average wait. Estimates
-- until timed in game.
-- Every link runs both ways. faction: "A", "H" or "N" (both).
--
-- Not listed until confirmed in game (see the spec): Stormwind Harbor to
-- Auberdine, Menethil to Southshore to Auberdine, Steamwheedle to Powderfuse.
--
-- Sardor Isle (Feathermoon Stronghold, map 1444) is treated as joined to the
-- mainland -- a short swim -- until ground crossings arrive, so its ferry
-- (Feathermoon <-> Forgotten Coast) is left out for now: it returns with them.
local _, ns = ...
ns.Data = ns.Data or {}

-- A ride edge never joins two different landmasses (see Graph.lua). Keyed by
-- UiMap; a map not listed here is the mainland.
ns.Data.Islands = { [1438] = "teldrassil", [1457] = "teldrassil" }

ns.Data.Docks = {
    org_zep      = { name = "Orgrimmar Zeppelin Tower", map = 1411, mx = 0.509, my = 0.140 }, -- measured in game
    uc_zep       = { name = "Undercity Zeppelin Tower", map = 1420, mx = 0.608, my = 0.587 }, -- measured in game
    gromgol_zep  = { name = "Grom'gol Zeppelin Tower",  map = 1434, mx = 0.315, my = 0.295 },
    menethil     = { name = "Menethil Harbor Docks",    map = 1437, mx = 0.050, my = 0.600 },
    auberdine    = { name = "Auberdine Docks",          map = 1439, mx = 0.328, my = 0.420 },
    theramore    = { name = "Theramore Docks",          map = 1445, mx = 0.715, my = 0.564 },
    rutheran     = { name = "Rut'theran Village Docks", map = 1438, mx = 0.549, my = 0.968 },
    bootybay     = { name = "Booty Bay Docks",          map = 1434, mx = 0.259, my = 0.731 },
    ratchet      = { name = "Ratchet Docks",            map = 1413, mx = 0.637, my = 0.386 },
    tram_sw      = { name = "Stormwind Tram Station",   map = 1453, mx = 0.640, my = 0.080 },
    tram_if      = { name = "Ironforge Tram Station",   map = 1455, mx = 0.768, my = 0.512 },
}

ns.Data.Links = {
    { from = "org_zep",     to = "uc_zep",      kind = "zeppelin", minutes = 4, faction = "H" },
    { from = "org_zep",     to = "gromgol_zep", kind = "zeppelin", minutes = 4, faction = "H" },
    { from = "uc_zep",      to = "gromgol_zep", kind = "zeppelin", minutes = 4, faction = "H" },
    { from = "menethil",    to = "auberdine",   kind = "boat",     minutes = 4, faction = "A" },
    { from = "menethil",    to = "theramore",   kind = "boat",     minutes = 4, faction = "A" },
    { from = "auberdine",   to = "rutheran",    kind = "boat",     minutes = 3, faction = "A" },
    { from = "bootybay",    to = "ratchet",     kind = "boat",     minutes = 4, faction = "N" },
    { from = "tram_sw",     to = "tram_if",     kind = "tram",     minutes = 2, faction = "A" },
}

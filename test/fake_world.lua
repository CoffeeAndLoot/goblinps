-- A tiny two-continent world. Both maps are 10000 x 10000 yards, so a map
-- coord converts as: world x = 10000 - my * 10000, world y = 10000 - mx * 10000.
local function world()
    return {
        Places = {
            [1] = { name = "Westland", c = 1, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.2, ay = 0.5 },
            [2] = { name = "Eastland", c = 0, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.8, ay = 0.5 },
            [3] = { name = "Isle", c = 1, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.5, ay = 0.1 },
            [4] = { name = "Northland", c = 1, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.2, ay = 0.2 },
            [5] = { name = "Lostland", c = 1, x0 = 0, y0 = 0, x1 = 10000, y1 = 10000, ax = 0.3, ay = 0.8 },
        },
        -- Ground travel is zone by zone. Westland (1) and Northland (4) are joined
        -- by one crossing. Isle (3) and Lostland (5) have none: Isle is an island
        -- (its two stops still ride to each other), Lostland is a hole in the table.
        Crossings = {
            { a = 1, b = 4, name = "the North Gate", map = 1, mx = 0.5, my = 0.02, warn = "trolls on the bridge" },
        },
        -- { low, high } level range per zone. Lostland (5) is listed here but
        -- the scripted client has no range for it, which is the fourth case
        -- /gps probe zones has to handle: we have a row and the client does not.
        Zones = { [1] = { 1, 10 }, [4] = { 30, 40 }, [5] = { 20, 25 } },
        Nodes = {
            [1] = { name = "Alpha, Westland", f = "H", c = 1, x = 1000, y = 1000, map = 1, mx = 0.9, my = 0.9 },
            [2] = { name = "Bravo, Westland", f = "H", c = 1, x = 1000, y = 9000, map = 1, mx = 0.1, my = 0.9 },
            [3] = { name = "Charlie, Westland", f = "N", c = 1, x = 5000, y = 9000, map = 1, mx = 0.1, my = 0.5 },
            [4] = { name = "Delta, Eastland", f = "H", c = 0, x = 5000, y = 5000, map = 2, mx = 0.5, my = 0.5 },
            [5] = { name = "Echo, Westland", f = "A", c = 1, x = 9000, y = 9000, map = 1, mx = 0.1, my = 0.1 },
            [6] = { name = "Foxtrot, Isle", f = "N", c = 1, x = 5000, y = 5000, map = 3, mx = 0.5, my = 0.5 },
            [7] = { name = "Golf, Isle", f = "N", c = 1, x = 5000, y = 5300, map = 3, mx = 0.5, my = 0.47 },
            [8] = { name = "Hotel, Northland", f = "N", c = 1, x = 9000, y = 5000, map = 4, mx = 0.5, my = 0.1 },
        },
        -- { from, to, copper, seconds }
        Flights = {
            { 1, 2, 100, 250 }, { 2, 1, 100, 250 },
            { 2, 3, 50, 125 }, { 3, 2, 50, 125 },
        },
        Docks = {
            west_dock = { name = "West Dock", map = 1, mx = 0.05, my = 0.9 }, -- world 1000, 9500
            east_dock = { name = "East Dock", map = 2, mx = 0.45, my = 0.5 }, -- world 5000, 5500
        },
        Inns = {
            ["Delta Harbour Inn"] = { stop = "Delta" },                 -- an inn beside a flight stop
            ["Quiet Hollow"] = { map = 1, mx = 0.25, my = 0.5 },        -- a town with no flight master
            ["Nowhere Inn"] = { map = 99, mx = 0.5, my = 0.5 },         -- a map we do not have
            ["Loop Inn"] = { stop = "Loop Inn" },                       -- names itself as its own stop
        },
        Links = {
            { from = "west_dock", to = "east_dock", kind = "zeppelin", minutes = 4, faction = "H" },
        },
    }
end

return world

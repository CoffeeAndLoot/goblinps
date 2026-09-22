return function(h, loaded)
    local Geo = loaded.ns.Geo
    local world = dofile("test/fake_world.lua")()

    h.describe("Geo.ToWorld", function()
        h.it("converts map coords to continent and world yards", function()
            local c, x, y = Geo.ToWorld(world.Places, 1, 0.25, 0.5)
            h.eq(c, 1)
            h.eq(x, 5000)
            h.eq(y, 7500)
        end)
        h.it("returns nil for a map it does not know", function()
            h.eq(Geo.ToWorld(world.Places, 99, 0.5, 0.5), nil)
        end)
        h.it("returns nil without coordinates", function()
            h.eq(Geo.ToWorld(world.Places, 1, nil, nil), nil)
        end)
    end)

    h.describe("Geo.Distance", function()
        h.it("measures yards on one continent", function()
            h.eq(Geo.Distance({ c = 1, x = 0, y = 0 }, { c = 1, x = 300, y = 400 }), 500)
        end)
        h.it("is infinite across continents", function()
            h.eq(Geo.Distance({ c = 1, x = 0, y = 0 }, { c = 0, x = 0, y = 0 }), math.huge)
        end)
        h.it("is infinite when a position is missing", function()
            h.eq(Geo.Distance(nil, { c = 0, x = 0, y = 0 }), math.huge)
        end)
    end)

    h.describe("Geo.Nearest", function()
        -- Player stands at world (5000, 5000) on Westland (continent 1). Two
        -- crossings straddle it (one near, one far) plus a dock in between,
        -- and a fourth candidate sits on Eastland (continent 0) and must be
        -- ignored outright, not merely ranked last.
        local data = {
            Places = world.Places,
            Crossings = {
                { name = "Near Crossing", map = 1, mx = 0.52, my = 0.52 }, -- world 4800, 4800
                { name = "Far Crossing", map = 1, mx = 0.9, my = 0.9 },    -- world 1000, 1000
            },
            Docks = {
                near_dock = { name = "Near Dock", map = 1, mx = 0.55, my = 0.55 },      -- world 4500, 4500
                other_continent = { name = "Elsewhere Dock", map = 2, mx = 0.5, my = 0.5 }, -- continent 0
            },
        }

        h.it("picks the closest of two crossings and a dock, ignoring other continents", function()
            local near = Geo.Nearest(data, 1, 5000, 5000)
            h.eq(near.name, "Near Crossing")
            h.truthy(math.abs(near.yards - 282.8427) < 0.01)
        end)

        h.it("returns nil when there is nothing on the continent", function()
            h.eq(Geo.Nearest({ Places = world.Places, Crossings = {}, Docks = {} }, 1, 0, 0), nil)
            h.eq(Geo.Nearest(data, 99, 0, 0), nil, "no candidate above is on continent 99")
        end)
    end)
end

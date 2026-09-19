return function(h, loaded)
    local Trip = loaded.ns.Trip
    local target = { name = "Bravo", c = 1, x = 1000, y = 9000 }
    local function at(x, y) return { c = 1, x = x, y = y } end

    h.describe("Trip.Check", function()
        h.it("pauses when the position is unknown", function()
            h.eq(Trip.Check({ kind = "ride", to = target }, { event = "tick" }), "pause")
        end)
        h.it("advances a ride inside the arrival radius", function()
            h.eq(Trip.Check({ kind = "ride", to = target }, { pos = at(1000, 8970), event = "tick" }), "advance")
        end)
        h.it("stays on a ride that is still closing in", function()
            local state = { pos = at(1000, 8000), best = 1100, event = "tick" }
            h.eq(Trip.Check({ kind = "ride", to = target }, state), "stay")
        end)
        h.it("recalculates a ride that strays", function()
            h.eq(Trip.Check({ kind = "ride", to = target }, { pos = at(1000, 8000), best = 500, event = "tick" }),
                 "recalculate")
        end)
        h.it("never advances while on a taxi", function()
            local state = { pos = at(1000, 9000), onTaxi = true, event = "tick" }
            h.eq(Trip.Check({ kind = "fly", to = target }, state), "stay")
        end)
        h.it("advances a flight that landed at its node", function()
            h.eq(Trip.Check({ kind = "fly", to = target }, { pos = at(1000, 8900), event = "landed" }), "advance")
        end)
        h.it("recalculates a flight that landed somewhere else", function()
            h.eq(Trip.Check({ kind = "fly", to = target }, { pos = at(5000, 5000), event = "landed" }), "recalculate")
        end)
        h.it("waits for a boat on the far continent", function()
            h.eq(Trip.Check({ kind = "boat", to = target }, { pos = { c = 0, x = 0, y = 0 }, event = "zone" }), "stay")
        end)
        h.it("advances a boat that docked", function()
            h.eq(Trip.Check({ kind = "boat", to = target }, { pos = at(1500, 9000), event = "zone" }), "advance")
        end)
    end)
end

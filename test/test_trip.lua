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

    h.describe("Trip.Bearing", function()
        local origin = { c = 1, x = 0, y = 0 }
        h.it("points along +x for due north", function()
            h.eq(Trip.Bearing(origin, { c = 1, x = 100, y = 0 }), 0)
        end)
        h.it("points a quarter turn for due west", function()
            local b = Trip.Bearing(origin, { c = 1, x = 0, y = 100 })
            h.truthy(math.abs(b - math.pi / 2) < 1e-9, "west is +pi/2, got " .. tostring(b))
        end)
        h.it("points a negative quarter turn for due east", function()
            local b = Trip.Bearing(origin, { c = 1, x = 0, y = -100 })
            h.truthy(math.abs(b + math.pi / 2) < 1e-9, "east is -pi/2, got " .. tostring(b))
        end)
        h.it("gives up across continents and on the same spot", function()
            h.eq(Trip.Bearing(origin, { c = 0, x = 100, y = 0 }), nil)
            h.eq(Trip.Bearing(origin, { c = 1, x = 0, y = 0 }), nil)
            h.eq(Trip.Bearing(nil, origin), nil)
            h.eq(Trip.Bearing(origin, nil), nil)
        end)
    end)

    h.describe("Trip.ArrowAngle", function()
        h.it("points straight up when the target is dead ahead", function()
            h.eq(Trip.ArrowAngle(1.2, 1.2), 0)
        end)
        h.it("turns by the difference between bearing and facing", function()
            h.eq(Trip.ArrowAngle(1.0, 0.25), Trip.ROTATION_SIGN * 0.75)
        end)
        h.it("gives up when the client will not say which way you face", function()
            h.eq(Trip.ArrowAngle(1.0, nil), nil)
            h.eq(Trip.ArrowAngle(nil, 1.0), nil)
        end)
    end)

    h.describe("Trip.CompassAngle", function()
        h.it("turns opposite our own facing", function()
            h.eq(Trip.CompassAngle(0.4), Trip.ROTATION_SIGN * -0.4)
        end)
        h.it("defaults to north when facing is unknown", function()
            h.eq(Trip.CompassAngle(nil), 0)
        end)
        h.it("flips together with ROTATION_SIGN instead of a sign hard-coded against it", function()
            -- The whole reason ROTATION_SIGN exists: the checklist tells a
            -- tester who sees the arrow turn the wrong way to flip this
            -- constant and nothing else. If the compass ever stopped
            -- consulting it, this would still pass while the in-game remedy
            -- quietly broke the compass -- which is exactly what shipped
            -- before this fix, since the old code read
            -- `-(facing or 0)` and never looked at ROTATION_SIGN at all.
            local saved = Trip.ROTATION_SIGN
            Trip.ROTATION_SIGN = -1
            h.eq(Trip.CompassAngle(0.4), 0.4)
            Trip.ROTATION_SIGN = saved
        end)
    end)

    h.describe("Trip.Ease", function()
        h.it("snaps to the target when there is no current angle", function()
            h.eq(Trip.Ease(nil, 1.5, 1), 1.5)
        end)
        h.it("does not move at all when no time has passed", function()
            h.eq(Trip.Ease(0.5, 2.0, 0), 0.5)
        end)
        h.it("lands within 1e-4 of the target after a full second", function()
            local eased = Trip.Ease(0, 1.5, 1)
            h.truthy(math.abs(eased - 1.5) < 1e-4, "expected close to 1.5, got " .. tostring(eased))
        end)
        h.it("takes the short way, up past pi, from 3.0 toward -3.0", function()
            -- target - current wraps to about +0.283, not -6.0: the short
            -- way is up through pi, never back down through 0.
            local eased = Trip.Ease(3.0, -3.0, 0.001)
            h.truthy(eased > 3.0, "expected the angle to move up, got " .. tostring(eased))
        end)
        h.it("takes the short way down, from -3.0 toward 3.0", function()
            local eased = Trip.Ease(-3.0, 3.0, 0.001)
            h.truthy(eased < -3.0, "expected the angle to move down, got " .. tostring(eased))
        end)
        h.it("covers half the difference on a half-step", function()
            local dt = Trip.EASE_SECONDS * math.log(2)
            local eased = Trip.Ease(0, 1.0, dt)
            h.truthy(math.abs(eased - 0.5) < 1e-9, "expected 0.5, got " .. tostring(eased))
        end)
    end)

    h.describe("Trip.DistanceTo", function()
        local step = { kind = "ride", seconds = 100, to = { c = 1, x = 100, y = 50 } }
        h.it("returns the distance for a valid position and step", function()
            local d = Trip.DistanceTo({ c = 1, x = 100, y = 50 }, step)
            h.eq(d, 0)
        end)
        h.it("returns nil when position is cross-continent", function()
            local d = Trip.DistanceTo({ c = 0, x = 100, y = 50 }, step)
            h.eq(d, nil)
        end)
        h.it("returns nil when position is nil", function()
            h.eq(Trip.DistanceTo(nil, step), nil)
        end)
        h.it("returns nil when step is nil", function()
            h.eq(Trip.DistanceTo({ c = 1, x = 0, y = 0 }, nil), nil)
        end)
        h.it("returns nil when step has no target", function()
            h.eq(Trip.DistanceTo({ c = 1, x = 0, y = 0 }, { kind = "ride" }), nil)
        end)
    end)

    h.describe("Trip.Remaining", function()
        local result = { steps = {
            { kind = "ride", seconds = 100, to = { c = 1, x = 0, y = 0 } },
            { kind = "zeppelin", seconds = 240, to = { c = 1, x = 0, y = 0 } },
            { kind = "ride", seconds = 50, to = { c = 1, x = 0, y = 0 } },
        } }
        h.it("adds the ground still to cover to every step after it", function()
            -- 70 yards from the first step's target at 7 yards a second is 10s,
            -- then 240 and 50 as planned.
            local left = Trip.Remaining(result, 1, { c = 1, x = 70, y = 0 }, 7)
            h.truthy(math.abs(left - 300) < 0.001, "expected 300, got " .. tostring(left))
        end)
        h.it("uses the planned seconds for a step you cannot walk", function()
            local left = Trip.Remaining(result, 2, { c = 1, x = 9999, y = 0 }, 7)
            h.eq(left, 290, "a zeppelin's time does not shrink as you stand nearer")
        end)
        h.it("is just the last step at the end", function()
            local left = Trip.Remaining(result, 3, { c = 1, x = 0, y = 0 }, 7)
            h.eq(left, 0)
        end)
        h.it("gives up on an index that is not there", function()
            h.eq(Trip.Remaining(result, 9, { c = 1, x = 0, y = 0 }, 7), nil)
            h.eq(Trip.Remaining(nil, 1, nil, 7), nil)
        end)
        h.it("falls back to the planned time when the client will not say where you are", function()
            -- ride with pos = nil should use planned time, not 0
            local left = Trip.Remaining(result, 1, nil, 7)
            h.eq(left, 390, "expected 390 (100 + 240 + 50), got " .. tostring(left))
        end)
    end)
end

local _, ns = ...

-- Pure arrival rules for an active trip. The dash unit feeds it the current
-- step and what the client reports; it answers what to do.
local Trip = {}
ns.Trip = Trip

-- Yards from a step's target that count as "arrived".
Trip.ARRIVE = { ride = 40, fly = 150, zeppelin = 800, boat = 800, tram = 800, hearth = 300 }
Trip.STRAY_YARDS = 400

-- state: pos = { c, x, y } or nil (instances); onTaxi = bool; event =
-- "tick" | "landed" | "zone"; best = closest the player has been to the
-- step's target so far, tracked by the caller.
-- Returns "advance", "recalculate", "stay" or "pause".
function Trip.Check(step, state)
    if not state.pos then
        return "pause"
    end
    if state.onTaxi then
        return "stay"
    end
    local d = ns.Geo.Distance(state.pos, step.to)
    if d <= Trip.ARRIVE[step.kind] then
        return "advance"
    end
    if step.kind == "ride" and state.best and d > state.best + Trip.STRAY_YARDS then
        return "recalculate"
    end
    if step.kind == "fly" and state.event == "landed" then
        return "recalculate"
    end
    return "stay"
end

-- Which way to turn the arrow. Geo puts world x north and world y west, and
-- GetPlayerFacing uses the same frame: 0 north, growing counter-clockwise. So
-- bearing minus facing is the turn, and SetRotation turns counter-clockwise.
-- The sign is NOT confirmed in game; if the arrow mirrors, flip this and
-- nothing else.
Trip.ROTATION_SIGN = 1

-- Radians from `from` to `to`, in the same frame as GetPlayerFacing. Nil when
-- the question has no answer: different continents, or the very same spot.
function Trip.Bearing(from, to)
    if not from or not to or from.c ~= to.c then
        return nil
    end
    local dx, dy = to.x - from.x, to.y - from.y
    if dx == 0 and dy == 0 then
        return nil
    end
    return math.atan2(dy, dx)
end

-- What to hand texture:SetRotation for an arrow drawn pointing up.
function Trip.ArrowAngle(bearing, facing)
    if not bearing or not facing then
        return nil
    end
    return Trip.ROTATION_SIGN * (bearing - facing)
end

-- Yards from a world position to a step's target, or nil.
function Trip.DistanceTo(pos, step)
    if not pos or not step or not step.to then
        return nil
    end
    local d = ns.Geo.Distance(pos, step.to)
    return d < math.huge and d or nil
end

-- Seconds left for the whole journey: the ground still to cover on the step
-- you are on, plus every step after it as planned. Only a ride shrinks as you
-- walk; a zeppelin takes as long whether you are beside it or not.
function Trip.Remaining(result, index, pos, speed)
    local step = result and result.steps and result.steps[index]
    if not step then
        return nil
    end
    local total = 0
    for i = index + 1, #result.steps do
        total = total + (result.steps[i].seconds or 0)
    end
    local d = step.kind == "ride" and speed and speed > 0 and Trip.DistanceTo(pos, step) or nil
    return total + (d and d / speed or (step.kind == "ride" and 0 or step.seconds or 0))
end

return Trip

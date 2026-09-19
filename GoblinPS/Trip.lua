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

return Trip

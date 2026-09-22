local _, ns = ...

-- Pure: shortest path by cost (seconds, plus Graph's penalty on a leg past an
-- enemy town), the "discover X" hint, and the plain text.
local Route = {}
ns.Route = Route

Route.MIN_RIDE_SECONDS = 5   -- shorter rides mean "you are already there"
Route.HINT_MIN_SECONDS = 120 -- only mention a saving worth having

-- What an edge costs the router. Graph.Build gives every edge a cost; a graph
-- built by hand may give only seconds.
local function costOf(edge)
    return edge.cost or edge.seconds
end

-- Dijkstra with a linear scan; the graph has about a hundred stops.
local function shortest(graph)
    local dist, prev, done = { START = 0 }, {}, {}
    while true do
        local best, bestKey = math.huge, nil
        for key, d in pairs(dist) do
            if not done[key] and (d < best or (d == best and bestKey and key < bestKey)) then
                best, bestKey = d, key
            end
        end
        if not bestKey or bestKey == "DEST" then
            break
        end
        done[bestKey] = true
        for _, e in ipairs(graph.edges[bestKey] or {}) do
            local nd = best + costOf(e)
            if nd < (dist[e.to] or math.huge) then
                dist[e.to] = nd
                prev[e.to] = { from = bestKey, edge = e }
            end
        end
    end
    return dist.DEST and prev or nil
end

-- One "Fly to X" per flight master visit; drop rides too short to mention,
-- but never the way through a tunnel (that step is the tunnel) and never a
-- step past an enemy town (its warning must reach the player).
local function tidy(raw)
    local steps = {}
    for _, s in ipairs(raw) do
        local last = steps[#steps]
        local tooShort = s.kind == "ride" and not s.through and not s.danger and s.seconds < Route.MIN_RIDE_SECONDS
        if last and last.kind == "fly" and s.kind == "fly" and last.to.key == s.from.key then
            last.to = s.to
            last.seconds = last.seconds + s.seconds
            last.copper = last.copper + s.copper
        elseif not tooShort then
            steps[#steps + 1] = { kind = s.kind, from = s.from, to = s.to, seconds = s.seconds,
                                  copper = s.copper, zone = s.zone, walk = s.walk, rough = s.rough,
                                  through = s.through, danger = s.danger }
        end
    end
    return steps
end

-- Returns { steps, raw, seconds, cost, copper } or nil when there is no
-- route: seconds is the real travel time, cost what the router minimised.
-- A step is { kind, from = stop, to = stop, seconds, copper }; a ground step
-- also carries zone, walk, rough, through (the passage of a two-ended
-- crossing) and danger ({ name, f }: the enemy town its straight line passes).
function Route.Find(graph)
    local prev = shortest(graph)
    if not prev then
        return nil
    end
    local raw, key, cost = {}, "DEST", 0
    while prev[key] do
        local p = prev[key]
        cost = cost + costOf(p.edge)
        table.insert(raw, 1, { kind = p.edge.kind, from = graph.stops[p.from], to = graph.stops[key],
                               seconds = p.edge.seconds, copper = p.edge.copper,
                               zone = p.edge.zone, walk = p.edge.walk, rough = p.edge.rough,
                               through = p.edge.through, danger = p.edge.danger })
        key = p.from
    end
    local seconds, copper = 0, 0
    for _, s in ipairs(raw) do
        seconds, copper = seconds + s.seconds, copper + s.copper
    end
    return { steps = tidy(raw), raw = raw, seconds = seconds, cost = cost, copper = copper }
end

-- Zone by zone through crossings. Only when no such route exists, once more
-- with the old straight lines, whose steps come back flagged rough: a hole in
-- the crossings table must never turn into "no route".
local function copy(opts, changes)
    local out = {}
    for k, v in pairs(opts) do
        out[k] = v
    end
    for k, v in pairs(changes) do
        out[k] = v
    end
    return out
end

-- The fastest route for these options, falling back to the labelled straight
-- line when no chain of crossings reaches the destination.
local function solve(data, opts)
    local result = Route.Find(ns.Graph.Build(data, opts))
    if result or opts.rough then
        return result
    end
    return Route.Find(ns.Graph.Build(data, copy(opts, { rough = true })))
end

-- The graph prices the hearthstone at Graph.HEARTH_SECONDS: the cast and the
-- loading screen. It cannot price the cooldown (an hour on this build, less with
-- a guild's Hasty Hearth perk; API.lua reads the live one), so on its own the
-- router will spend the stone to save twenty seconds. `opts.hearthSaving` is
-- the least it must save to be worth taking; plan both ways and keep the
-- hearthstone only when it earns its keep. Nil or 0 means take it whenever
-- it is no slower. Refusing it never costs the player a route: the plain plan
-- is returned instead, and it is the one the player would have had anyway.
-- The saving is real seconds, the unit the bar names ("must save N min"),
-- never cost: `best` is already the router's pick by cost, and comparing cost
-- would let an enemy town's penalty alone spend the stone, even on a slower
-- trip. A refused stone leaves the plain route with its danger step, so the
-- player still sees the warning.
function Route.Plan(data, opts)
    local best = solve(data, opts)
    local bar = opts.hearthSaving or 0
    if not opts.hearth or not best then
        return best
    end
    if not (best.steps[1] and best.steps[1].kind == "hearth") then
        return best
    end
    local plain = solve(data, copy(opts, { hearth = false }))
    if plain and plain.seconds - best.seconds < bar then
        return plain
    end
    return best
end

-- Would knowing every flight path help? Returns { names = { first two short
-- names }, more = count of further unknown stops beyond those two (0 if
-- none), seconds = saved or nil when there was no route at all }, or nil
-- when it would not. It must help both ways: better by cost, the router's
-- measure, and by real seconds, the only saving the hint may state. A route
-- that only goes round an enemy town, no faster, earns no "save" line.
function Route.Hint(data, opts, result)
    local all, o = {}, {}
    for id in pairs(data.Nodes) do
        all[id] = true
    end
    for k, v in pairs(opts) do
        o[k] = v
    end
    o.known = all
    local better = Route.Plan(data, o)
    if not better then
        return nil
    end
    if result and (result.cost - better.cost < Route.HINT_MIN_SECONDS
                   or result.seconds - better.seconds < Route.HINT_MIN_SECONDS) then
        return nil
    end
    local all_names, seen, known = {}, {}, opts.known or {}
    for _, s in ipairs(better.raw) do
        if s.kind == "fly" then
            for _, stop in ipairs({ s.from, s.to }) do
                if not known[stop.nodeID] and not seen[stop.nodeID] then
                    seen[stop.nodeID] = true
                    all_names[#all_names + 1] = ns.Search.ShortName(stop.name)
                end
            end
        end
    end
    if #all_names == 0 then
        return nil
    end
    local names = {}
    for i = 1, math.min(2, #all_names) do
        names[i] = all_names[i]
    end
    return { names = names, more = math.max(0, #all_names - 2),
             seconds = result and (result.seconds - better.seconds) or nil }
end

local VERB = {
    ride = "Ride to", fly = "Fly to", zeppelin = "Zeppelin to",
    boat = "Boat to", tram = "Tram to", hearth = "Hearthstone to",
}
local WAITS = { zeppelin = true, boat = true, tram = true }

function Route.FormatTime(seconds)
    return "~" .. math.max(1, math.floor(seconds / 60 + 0.5)) .. " min"
end

function Route.FormatMoney(copper)
    if copper <= 0 then
        return "free"
    end
    local parts = {}
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

-- Plain and glanceable. No jokes in the directions.
function Route.StepText(step)
    if step.kind == "ride" then
        local verb = step.walk and "Walk" or "Ride"
        if step.rough then
            return verb .. " toward " .. ns.Search.ShortName(step.to.name) .. " (no mapped path)"
        end
        if step.through then
            return verb .. " through " .. ns.Search.ShortName(step.to.name)
        end
        return verb .. " to " .. ns.Search.ShortName(step.to.name)
    end
    -- No time here: the planner prints it in its own column and chat prints it
    -- beside the step, so repeating it pushed the longest step names past the
    -- right edge and the client truncated them ("Zeppelin to Orgrimmar Zeppel...").
    -- That a boat or zeppelin's figure includes the wait is said on the detail line.
    return VERB[step.kind] .. " " .. ns.Search.ShortName(step.to.name)
end

local function levels(range)
    if not range then
        return ""
    end
    return " · level " .. (range[1] == range[2] and range[1] or (range[1] .. "-" .. range[2]))
end

-- The small line under a ground step: where it takes you and what to expect.
-- Returns text, warn. warn is true when the zone starts well above the
-- character's level, the crossing carries a hazard note, or it is
-- unconfirmed. Other step kinds have no detail ("", false). A hazard or an
-- unconfirmed note replaces the level range on the line (never both: the
-- line does not wrap, and the hazard is the part that must not be cut off).
function Route.StepDetail(data, step, level)
    if WAITS[step.kind] then
        return "includes the average wait", false
    end
    if step.kind ~= "ride" or not step.zone then
        return "", false
    end
    local places, zones = data.Places or {}, data.Zones or {}
    local gate = step.to.zones
    local zone = step.zone
    local text
    -- The zone being entered: where a step through a tunnel comes out, or a gate's other side.
    local entered = step.through and step.to.map or gate and (gate[1] == step.zone and gate[2] or gate[1])
    if entered then
        zone = entered
        text = "into " .. (places[zone] and places[zone].name or "the next zone")
    else
        text = "in " .. (places[zone] and places[zone].name or "this zone")
        -- Do not say the obvious: "Walk to Orgrimmar" already says where you land.
        if places[zone] and ns.Search.ShortName(step.to.name) == places[zone].name then
            return "", false
        end
    end
    local warn = ns.Travel.Dangerous(zones[zone], level)
    if step.to.warn or step.to.unverified then
        warn = true
    else
        text = text .. levels(zones[zone])
    end
    if step.to.warn then
        text = text .. " · " .. step.to.warn
    end
    if step.to.unverified then
        text = text .. " · crossing not confirmed"
    end
    return text, warn
end

function Route.HintText(hint)
    local more = hint.more or 0
    local who
    if #hint.names == 1 then
        who = hint.names[1]
    elseif more > 0 then
        who = hint.names[1] .. ", " .. hint.names[2] .. " and " .. more .. " more"
    else
        who = hint.names[1] .. " and " .. hint.names[2]
    end
    if hint.seconds then
        return "Discover " .. who .. " to save " .. Route.FormatTime(hint.seconds)
    end
    return "Discover " .. who .. " to open a route"
end

return Route

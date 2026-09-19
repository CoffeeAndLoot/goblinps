local _, ns = ...

-- Pure: shortest path by seconds, the "discover X" hint, and the plain text.
local Route = {}
ns.Route = Route

Route.MIN_RIDE_SECONDS = 5   -- shorter rides mean "you are already there"
Route.HINT_MIN_SECONDS = 120 -- only mention a saving worth having

-- Dijkstra with a linear scan; the graph has about a hundred stops.
local function shortest(graph)
    local dist, prev, done = { START = 0 }, {}, {}
    while true do
        local best, bestKey = math.huge, nil
        for key, d in pairs(dist) do
            if not done[key] and d < best then
                best, bestKey = d, key
            end
        end
        if not bestKey or bestKey == "DEST" then
            break
        end
        done[bestKey] = true
        for _, e in ipairs(graph.edges[bestKey] or {}) do
            local nd = best + e.seconds
            if nd < (dist[e.to] or math.huge) then
                dist[e.to] = nd
                prev[e.to] = { from = bestKey, edge = e }
            end
        end
    end
    return dist.DEST and prev or nil
end

-- One "Fly to X" per flight master visit; drop rides too short to mention.
local function tidy(raw)
    local steps = {}
    for _, s in ipairs(raw) do
        local last = steps[#steps]
        local tooShort = s.kind == "ride" and s.seconds < Route.MIN_RIDE_SECONDS
        if last and last.kind == "fly" and s.kind == "fly" and last.to.key == s.from.key then
            last.to = s.to
            last.seconds = last.seconds + s.seconds
            last.copper = last.copper + s.copper
        elseif not tooShort then
            steps[#steps + 1] = { kind = s.kind, from = s.from, to = s.to,
                                  seconds = s.seconds, copper = s.copper }
        end
    end
    return steps
end

-- Returns { steps, raw, seconds, copper } or nil when there is no route.
-- A step is { kind, from = stop, to = stop, seconds, copper }.
function Route.Find(graph)
    local prev = shortest(graph)
    if not prev then
        return nil
    end
    local raw, key = {}, "DEST"
    while prev[key] do
        local p = prev[key]
        table.insert(raw, 1, { kind = p.edge.kind, from = graph.stops[p.from], to = graph.stops[key],
                               seconds = p.edge.seconds, copper = p.edge.copper })
        key = p.from
    end
    local seconds, copper = 0, 0
    for _, s in ipairs(raw) do
        seconds, copper = seconds + s.seconds, copper + s.copper
    end
    return { steps = tidy(raw), raw = raw, seconds = seconds, copper = copper }
end

function Route.Plan(data, opts)
    return Route.Find(ns.Graph.Build(data, opts))
end

-- Would knowing every flight path help? Returns { names = {...}, seconds =
-- saved or nil when there was no route at all }, or nil when it would not.
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
    if result and result.seconds - better.seconds < Route.HINT_MIN_SECONDS then
        return nil
    end
    local names, seen, known = {}, {}, opts.known or {}
    for _, s in ipairs(better.raw) do
        if s.kind == "fly" then
            for _, stop in ipairs({ s.from, s.to }) do
                if not known[stop.nodeID] and not seen[stop.nodeID] and #names < 2 then
                    seen[stop.nodeID] = true
                    names[#names + 1] = ns.Search.ShortName(stop.name)
                end
            end
        end
    end
    if #names == 0 then
        return nil
    end
    return { names = names, seconds = result and (result.seconds - better.seconds) or nil }
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
    local text = VERB[step.kind] .. " " .. ns.Search.ShortName(step.to.name)
    if WAITS[step.kind] then
        text = text .. " (" .. Route.FormatTime(step.seconds) .. " incl. wait)"
    end
    return text
end

function Route.HintText(hint)
    local who = table.concat(hint.names, " and ")
    if hint.seconds then
        return "Discover " .. who .. " to save " .. Route.FormatTime(hint.seconds)
    end
    return "Discover " .. who .. " to open a route"
end

return Route

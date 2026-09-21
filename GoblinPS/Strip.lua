local _, ns = ...

-- The route strip as data: one stop per place the route passes through, the
-- badge each one wears, where it sits along the track, what its tooltip says,
-- and how the legs between them are drawn. Pure: no frames and no Blizzard
-- globals. Planner.lua draws what this returns and decides nothing.
local Strip = {}
ns.Strip = Strip

-- Names show under the badges while the space between two badge centres is
-- at least this many badge widths. Closer than that, every name is dropped
-- and lives only in the tooltips.
Strip.LABEL_ROOM = 2

local CREST = { H = "icon-horde", A = "icon-alliance" }
local BADGE = { fly = "icon-flight", zeppelin = "icon-zeppelin", boat = "icon-boat",
                tram = "icon-tram", hearth = "icon-hearth" }

-- How you got to a stop. Walk or ride is the same test Route.StepText uses,
-- so the badge and the words can never disagree. A kind this file does not
-- know wears the plain ring rather than raising.
local function badgeFor(step)
    if step.kind == "ride" then
        return step.walk and "icon-walk" or "icon-ride"
    end
    return BADGE[step.kind] or "node-ring"
end

local function tooltipFor(data, step, level)
    -- Unknown step kinds go straight to the planner; Strip.Layout handles them
    -- without error, just name and time in the tooltip.
    if step.kind == "ride" or BADGE[step.kind] then
        local lines = { { text = ns.Route.StepText(step) }, { text = ns.Route.FormatTime(step.seconds) } }
        local detail, warn = ns.Route.StepDetail(data, step, level)
        if detail ~= "" then
            lines[3] = { text = detail, amber = warn and true or false }
        end
        return lines
    end
    return { { text = ns.Search.ShortName(step.to.name) }, { text = ns.Route.FormatTime(step.seconds) } }
end

function Strip.Layout(data, steps, opts)
    local layout = { stops = {}, legs = {}, labels = false }
    if #steps == 0 then
        return layout
    end
    local gaps = #steps
    layout.spacing = opts.trackWidth / gaps
    layout.labels = layout.spacing >= Strip.LABEL_ROOM * opts.badgeWidth
    layout.stops[1] = { x = 0, badge = CREST[opts.faction] or "icon-neutral", label = "You are here",
                        tooltip = { { text = "You are here" } } }
    for i, step in ipairs(steps) do
        local name = ns.Search.ShortName(step.to.name)
        local tooltip = tooltipFor(data, step, opts.level)
        layout.stops[i + 1] = { x = i / gaps, badge = i == gaps and "node-destination" or badgeFor(step),
                                label = name, tooltip = tooltip }
        layout.legs[i] = { from = i, to = i + 1, style = i == 1 and "solid" or "dashed",
                           mid = (i - 0.5) / gaps }
        if not layout.warning and tooltip[3] and tooltip[3].amber then
            layout.warning = name .. ": " .. tooltip[3].text
        end
    end
    return layout
end

return Strip

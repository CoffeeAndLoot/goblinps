return function(h, loaded)
    local ns = loaded.ns
    local Strip = ns.Strip
    local data = dofile("test/fake_world.lua")()

    local function step(kind, name, extra)
        local s = { kind = kind, to = { name = name }, seconds = 240, copper = 0 }
        for k, v in pairs(extra or {}) do
            s[k] = v
        end
        return s
    end
    local OPTS = { faction = "H", level = 60, trackWidth = 400, badgeWidth = 40 }

    h.describe("Strip.Layout", function()
        h.it("draws nothing for a route with no steps", function()
            local layout = Strip.Layout(data, {}, OPTS)
            h.eq(#layout.stops, 0)
            h.eq(#layout.legs, 0)
            h.eq(layout.labels, false)
            h.eq(layout.spacing, nil)
        end)

        h.it("puts a one-step route's two stops at the two ends", function()
            local layout = Strip.Layout(data, { step("ride", "Alpha, Westland") }, OPTS)
            h.eq(#layout.stops, 2)
            h.eq(layout.stops[1].x, 0)
            h.eq(layout.stops[2].x, 1)
            h.eq(layout.stops[2].badge, "node-destination", "the last stop is the signpost")
            h.eq(#layout.legs, 1)
        end)

        h.it("spaces every stop evenly, however many there are", function()
            local steps = {}
            for i = 1, 4 do
                steps[i] = step("ride", "Stop " .. i)
            end
            local layout = Strip.Layout(data, steps, OPTS)
            h.eq(#layout.stops, 5, "one more stop than there are steps")
            for i = 1, 5 do
                h.truthy(math.abs(layout.stops[i].x - (i - 1) / 4) < 1e-9, "stop " .. i)
            end
            h.truthy(math.abs(layout.spacing - 100) < 1e-9, "400 px over four gaps")
        end)

        h.it("starts at the faction's crest", function()
            local steps = { step("ride", "Alpha") }
            for faction, badge in pairs({ H = "icon-horde", A = "icon-alliance", N = "icon-neutral" }) do
                local opts = { faction = faction, level = 60, trackWidth = 400, badgeWidth = 40 }
                h.eq(Strip.Layout(data, steps, opts).stops[1].badge, badge, faction)
            end
            local opts = { level = 60, trackWidth = 400, badgeWidth = 40 }
            h.eq(Strip.Layout(data, steps, opts).stops[1].badge, "icon-neutral", "no faction")
        end)

        h.it("shows at each stop how you got there", function()
            local steps = {
                step("ride", "A"), step("ride", "B", { walk = true }), step("fly", "C"),
                step("zeppelin", "D"), step("boat", "E"), step("tram", "F"),
                step("hearth", "G"), step("portal", "H"), step("fly", "End"),
            }
            local want = { "icon-ride", "icon-walk", "icon-flight", "icon-zeppelin", "icon-boat",
                           "icon-tram", "icon-hearth", "node-ring", "node-destination" }
            local layout = Strip.Layout(data, steps, OPTS)
            for i, badge in ipairs(want) do
                h.eq(layout.stops[i + 1].badge, badge, "stop " .. (i + 1))
            end
        end)

        h.it("names the start You are here and every other stop by its short name", function()
            local layout = Strip.Layout(data, { step("fly", "Crossroads, The Barrens") }, OPTS)
            h.eq(layout.stops[1].label, "You are here")
            h.eq(layout.stops[2].label, "Crossroads")
        end)

        h.it("keeps the names while two badge widths fit between stops, and drops them below", function()
            local opts = { faction = "H", level = 60, trackWidth = 100, badgeWidth = 50 }
            h.eq(Strip.Layout(data, { step("ride", "A") }, opts).labels, true, "100 px is exactly two badges")
            h.eq(Strip.Layout(data, { step("ride", "A"), step("ride", "B") }, opts).labels, false,
                 "50 px is one badge: too crowded to read")
        end)

        h.it("draws the leg you are about to start solid and every one after dashed", function()
            local layout = Strip.Layout(data, { step("ride", "A"), step("fly", "B"), step("ride", "C") }, OPTS)
            h.eq(layout.legs[1].style, "solid")
            h.eq(layout.legs[2].style, "dashed")
            h.eq(layout.legs[3].style, "dashed")
            for i, leg in ipairs(layout.legs) do
                h.eq(leg.from, i)
                h.eq(leg.to, i + 1)
                h.truthy(math.abs(leg.mid - (i - 0.5) / 3) < 1e-9, "leg " .. i .. " midpoint")
            end
        end)

        h.it("tells the start's tooltip where you are", function()
            local layout = Strip.Layout(data, { step("ride", "A") }, OPTS)
            h.eq(#layout.stops[1].tooltip, 1)
            h.eq(layout.stops[1].tooltip[1].text, "You are here")
        end)

        h.it("gives each stop the step, its time and its detail", function()
            local layout = Strip.Layout(data, { step("zeppelin", "East Dock") }, OPTS)
            local tip = layout.stops[2].tooltip
            h.eq(tip[1].text, "Zeppelin to East Dock")
            h.eq(tip[2].text, "~4 min")
            h.eq(tip[3].text, "includes the average wait")
            h.eq(tip[3].amber, false)
        end)

        h.it("leaves out a detail line the step does not have", function()
            local layout = Strip.Layout(data, { step("fly", "Bravo, Westland") }, OPTS)
            h.eq(#layout.stops[2].tooltip, 2)
        end)

        h.it("turns a hazard's detail amber and names it as the warning", function()
            local gate = step("ride", "the North Gate", { zone = 1 })
            gate.to.zones = { 1, 4 }
            gate.to.warn = "trolls on the bridge"
            local layout = Strip.Layout(data, { gate, step("ride", "Hotel, Northland", { zone = 4 }) }, OPTS)
            local detail = layout.stops[2].tooltip[3]
            h.eq(detail.text, "into Northland · trolls on the bridge")
            h.eq(detail.amber, true)
            h.eq(layout.warning, "the North Gate: into Northland · trolls on the bridge")
        end)

        h.it("turns the enemy town a leg passes amber and names it as the warning", function()
            local leg = step("ride", "Splintertree Post, Ashenvale",
                             { zone = 1, danger = { name = "Silverwind Refuge", f = "A" } })
            local layout = Strip.Layout(data, { leg }, OPTS)
            local detail = layout.stops[2].tooltip[3]
            h.eq(detail.text, "in Westland · passes Silverwind Refuge (Alliance)")
            h.eq(detail.amber, true)
            h.eq(layout.warning, "Splintertree Post: in Westland · passes Silverwind Refuge (Alliance)")
        end)
        h.it("wears the walk or ride badge through a tunnel, and says through in the tooltip", function()
            local function through(walk)
                local s = step("ride", "the Deep Tunnel", { zone = 4, through = true, walk = walk })
                s.to.map = 4
                return s
            end
            local steps = { through(false), step("ride", "Hotel, Northland", { zone = 4 }) }
            local layout = Strip.Layout(data, steps, OPTS)
            h.eq(layout.stops[2].badge, "icon-ride")
            h.eq(layout.stops[2].label, "Deep Tunnel")
            local tip = layout.stops[2].tooltip
            h.eq(tip[1].text, "Ride through the Deep Tunnel")
            h.eq(tip[2].text, "~4 min")
            h.eq(tip[3].text, "into Northland · level 30-40")
            steps[1] = through(true)
            layout = Strip.Layout(data, steps, OPTS)
            h.eq(layout.stops[2].badge, "icon-walk")
            h.eq(layout.stops[2].tooltip[1].text, "Walk through the Deep Tunnel")
        end)

        h.it("has no warning when nothing is amber", function()
            local layout = Strip.Layout(data, { step("ride", "Hotel, Northland", { zone = 4 }) }, OPTS)
            h.eq(layout.warning, nil)
        end)

        h.it("gives a step kind it does not know a plain tooltip, never an error", function()
            local layout = Strip.Layout(data, { step("portal", "Gate, Somewhere") }, OPTS)
            h.eq(#layout.stops[2].tooltip, 2)
            h.eq(layout.stops[2].tooltip[1].text, "Gate")
            h.eq(layout.stops[2].tooltip[2].text, "~4 min")
        end)

        h.it("labels the signpost with the destination, and keeps the step in its tooltip", function()
            local steps = { step("ride", "A"), step("ride", "the North Gate") }
            local opts = { faction = "H", level = 60, trackWidth = 400, badgeWidth = 40,
                           destination = "Northland" }
            local layout = Strip.Layout(data, steps, opts)
            h.eq(layout.stops[3].label, "Northland")
            h.eq(layout.stops[3].tooltip[1].text, "Ride to the North Gate")

            local without = Strip.Layout(data, steps, OPTS)
            h.eq(without.stops[3].label, "North Gate", "a plain crossing label drops its leading \"the\" too")
        end)

        h.it("drops a crossing's leading \"the\" from its label, but keeps it in the tooltip", function()
            local layout = Strip.Layout(data, { step("ride", "the North Gate") }, OPTS)
            h.eq(layout.stops[2].label, "North Gate")
            h.eq(layout.stops[2].tooltip[1].text, "Ride to the North Gate")
        end)
    end)
end

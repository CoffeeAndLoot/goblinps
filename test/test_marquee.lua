return function(h, loaded)
    local Marquee = loaded.ns.Marquee
    local HOLD, STEP, GAP = Marquee.HOLD, Marquee.STEP, Marquee.GAP

    h.describe("Marquee", function()
        h.it("holds a line that does not fit at its start for HOLD seconds", function()
            h.eq(GAP, "   ", "the wrap gap is three spaces")
            local m = Marquee.New("Ride to Far Crossing", false)
            h.eq(Marquee.Advance(m, 0), "Ride to Far Crossing")
            h.eq(Marquee.Advance(m, HOLD - 0.01), "Ride to Far Crossing", "still holding")
        end)

        h.it("then drops one character every STEP", function()
            local m = Marquee.New("Abcdef", false)
            h.eq(Marquee.Advance(m, HOLD + 0.01), "bcdef" .. GAP .. "Abcdef")
            h.eq(Marquee.Advance(m, STEP), "cdef" .. GAP .. "Abcdef")
            h.eq(Marquee.Advance(m, STEP / 2), "cdef" .. GAP .. "Abcdef", "half a step moves nothing")
            h.eq(Marquee.Advance(m, STEP / 2), "def" .. GAP .. "Abcdef")
        end)

        h.it("wraps round through the gap to the start, and holds again", function()
            local m = Marquee.New("Abc", false)
            h.eq(Marquee.Advance(m, HOLD + 0.01), "bc" .. GAP .. "Abc")
            h.eq(Marquee.Advance(m, STEP), "c" .. GAP .. "Abc")
            h.eq(Marquee.Advance(m, STEP), GAP .. "Abc", "the gap comes round")
            h.eq(Marquee.Advance(m, STEP), GAP:sub(2) .. "Abc")
            h.eq(Marquee.Advance(m, STEP), GAP:sub(3) .. "Abc")
            h.eq(Marquee.Advance(m, STEP), "Abc", "back at the start")
            h.eq(Marquee.Advance(m, HOLD - 0.05), "Abc", "and holding there again")
            h.eq(Marquee.Advance(m, 0.1), "bc" .. GAP .. "Abc")
        end)

        h.it("never moves text that fits", function()
            local m = Marquee.New("Delta", true)
            h.eq(Marquee.Advance(m, 0), "Delta")
            h.eq(Marquee.Advance(m, 60), "Delta")
        end)

        h.it("never moves an empty line", function()
            local m = Marquee.New("", false)
            h.eq(Marquee.Advance(m, 60), "")
            h.eq(Marquee.Advance(Marquee.New(nil, false), 60), "", "no text reads as empty")
        end)

        h.it("starts every new line fresh, at its start", function()
            local m = Marquee.New("Uvwxyz", false)
            h.eq(m.offset, 1)
            h.eq(m.clock, 0)
            h.eq(Marquee.Advance(m, STEP), "Uvwxyz", "a new line holds before it moves")
        end)

        h.it("never starts a line on half a character", function()
            -- "été": the first step would land on the second byte of the é.
            local ete = "\195\169t\195\169"
            local m = Marquee.New(ete, false)
            h.eq(Marquee.Advance(m, HOLD + 0.01), "t\195\169" .. GAP .. ete)
        end)

        h.it("honours a custom step, and defaults to STEP without one", function()
            h.eq(Marquee.New("Abcdef", false).step, STEP)
            local m = Marquee.New("Abcdef", false, 0.5)
            h.eq(m.step, 0.5)
            h.eq(Marquee.Advance(m, HOLD + 0.01), "bcdef" .. GAP .. "Abcdef")
            h.eq(Marquee.Advance(m, STEP), "bcdef" .. GAP .. "Abcdef", "the default step is not this one's")
            h.eq(Marquee.Advance(m, 0.5 - STEP), "cdef" .. GAP .. "Abcdef")
        end)
    end)
end

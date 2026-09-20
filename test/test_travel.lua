return function(h, loaded)
    local Travel = loaded.ns.Travel

    h.describe("Travel.For", function()
        h.it("walks below the first mount level", function()
            local t = Travel.For(1)
            h.eq(t.speed, Travel.WALK_YARDS_PER_SECOND)
            h.eq(t.walk, true)
        end)
        h.it("rides the first mount from its level", function()
            local first = Travel.MOUNTS[1]
            h.eq(Travel.For(first.level - 1).walk, true)
            h.eq(Travel.For(first.level).walk, false)
            h.eq(Travel.For(first.level).speed, first.yardsPerSecond)
        end)
        h.it("rides the fastest mount the level allows", function()
            local last = Travel.MOUNTS[#Travel.MOUNTS]
            h.eq(Travel.For(last.level).speed, last.yardsPerSecond)
            h.eq(Travel.For(last.level + 10).speed, last.yardsPerSecond)
        end)
        h.it("treats an unknown level as on foot", function()
            h.eq(Travel.For(nil).walk, true)
        end)
        h.it("follows the settings, so the definitive numbers are a two-line change", function()
            local saved = Travel.MOUNTS
            Travel.MOUNTS = { { level = 20, yardsPerSecond = 9 } }
            h.eq(Travel.For(20).speed, 9)
            h.eq(Travel.For(19).walk, true)
            Travel.MOUNTS = saved
        end)
    end)

    h.describe("Travel.Dangerous", function()
        h.it("warns when the zone starts well above the character", function()
            h.eq(Travel.Dangerous({ 48, 55 }, 1), true)
            h.eq(Travel.Dangerous({ 10, 25 }, 1), true)
        end)
        h.it("does not warn inside the margin", function()
            h.eq(Travel.Dangerous({ 10, 25 }, 10 - Travel.WARN_LEVELS_ABOVE), false)
            h.eq(Travel.Dangerous({ 1, 10 }, 1), false)
            h.eq(Travel.Dangerous({ 48, 55 }, 60), false)
        end)
        h.it("never warns without a range or a level", function()
            h.eq(Travel.Dangerous(nil, 5), false)
            h.eq(Travel.Dangerous({ 48, 55 }, nil), false)
        end)
    end)
end

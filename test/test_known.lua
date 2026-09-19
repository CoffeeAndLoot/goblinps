return function(h, loaded)
    local Known = loaded.ns.Known

    -- What API.OpenTaxiNodes hands over while a flight master's map is open.
    local function atThunderBluff()
        return {
            { nodeID = 22, name = "Thunder Bluff, Mulgore", flyable = true },
            { nodeID = 23, name = "Orgrimmar, Durotar", flyable = true },
            { nodeID = 29, name = "Sun Rock Retreat, Stonetalon Mountains", flyable = false },
        }
    end

    h.describe("Known.Learn", function()
        h.it("remembers the nodes the flight master can fly to", function()
            local store = {}
            h.eq(Known.Learn(store, atThunderBluff()), 2)
            h.truthy(store[22])
            h.truthy(store[23])
        end)
        h.it("never learns a node the flight master cannot reach", function()
            local store = {}
            Known.Learn(store, atThunderBluff())
            h.falsy(store[29])
        end)
        h.it("counts only what is new", function()
            local store = { [22] = true }
            h.eq(Known.Learn(store, atThunderBluff()), 1)
            h.eq(Known.Learn(store, atThunderBluff()), 0)
        end)
        h.it("never forgets: flight paths are not unlearned", function()
            local store = { [2] = true } -- Stormwind, learned on the other continent
            Known.Learn(store, atThunderBluff())
            h.truthy(store[2])
        end)
        h.it("copes with an empty list", function()
            h.eq(Known.Learn({}, {}), 0)
        end)
    end)

    h.describe("Known.Count", function()
        h.it("counts the remembered nodes", function()
            h.eq(Known.Count({}), 0)
            h.eq(Known.Count({ [22] = true, [23] = true }), 2)
        end)
    end)
end

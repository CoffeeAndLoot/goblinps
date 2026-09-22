return function(h, loaded)
    local Search = loaded.ns.Search
    local world = dofile("test/fake_world.lua")()

    h.describe("Search.ShortName", function()
        h.it("drops the zone after the comma", function()
            h.eq(Search.ShortName("Crossroads, The Barrens"), "Crossroads")
        end)
        h.it("leaves a plain name alone", function()
            h.eq(Search.ShortName("Moonglade"), "Moonglade")
        end)
    end)

    h.describe("Search.Label", function()
        h.it("drops a crossing's leading lowercase the", function()
            h.eq(Search.Label("the Mor'shan Rampart"), "Mor'shan Rampart")
        end)
        h.it("keeps a capital The: it is part of the name", function()
            h.eq(Search.Label("The Crossroads"), "The Crossroads")
        end)
        h.it("shortens first, so the zone after the comma is already gone", function()
            h.eq(Search.Label("Crossroads, The Barrens"), "Crossroads")
        end)
        h.it("leaves theramore alone: no space after the", function()
            h.eq(Search.Label("theramore"), "theramore")
        end)
    end)

    h.describe("Search.Find", function()
        h.it("matches without caring about case", function()
            local found = Search.Find(world, "ALP", "H")
            h.eq(#found, 1)
            h.eq(found[1].name, "Alpha")
            h.eq(found[1].nodeID, 1)
        end)
        h.it("ranks a name that starts with the text, then one that contains it, then its zone", function()
            local found = Search.Find(world, "e", "A", 20)
            local names, ranks = {}, {}
            for i, item in ipairs(found) do
                names[i], ranks[i] = item.name, item.rank
            end
            h.eq(table.concat(names, ","),
                 "Echo,Charlie,Delta,Gatehouse,Hotel,Juliet,Quiet Hollow,Alpha,Bravo,Foxtrot,Golf")
            h.eq(table.concat(ranks, ","), "1,2,2,2,2,2,2,3,3,3,3",
                 "Alpha and Bravo match only by Westland, Foxtrot and Golf by Isle")
        end)
        h.it("offers the other faction's flight stops, marked with their faction", function()
            local echo = Search.Find(world, "echo", "H")
            h.eq(#echo, 1)
            h.eq(echo[1].enemy, "A")
            h.eq(Search.Find(world, "echo", "A")[1].enemy, nil, "an Alliance stop is no enemy to the Alliance")
            h.eq(Search.Find(world, "charlie", "H")[1].enemy, nil, "nor is a neutral one to anyone")
        end)
        h.it("finds the places in a zone by the zone's name, not the zone that holds them", function()
            local names = {}
            for i, item in ipairs(Search.Find(world, "westland", "H")) do
                names[i] = item.name
                h.eq(item.rank, 3)
                h.eq(item.zone, "Westland")
                h.truthy(item.kind ~= "zone", item.name .. " is a zone")
            end
            h.eq(table.concat(names, ","), "Alpha,Bravo,Charlie,Echo,Juliet,Quiet Hollow",
                 "Delta is in Eastland")
        end)
        h.it("in a zone-name match, puts flight stops before towns, then alphabetical", function()
            local names = {}
            for i, item in ipairs(Search.Find(world, "northland", "H")) do
                names[i] = item.name
            end
            h.eq(table.concat(names, ","), "Hotel,Gatehouse",
                 "Hotel is the zone's flight stop; alphabetical order alone would put Gatehouse first")
        end)
        h.it("offers an inn town as a place of kind town, with its zone", function()
            local town = Search.Find(world, "quiet", "H")[1]
            h.eq(town.kind, "town")
            h.eq(town.name, "Quiet Hollow")
            h.eq(town.zone, "Westland")
            h.eq(town.map, 1)
            h.eq(town.c, 1)
            h.eq(town.x, 5000)
            h.eq(town.y, 7500)
        end)
        h.it("returns nothing for empty text", function()
            h.eq(#Search.Find(world, "", "H"), 0)
        end)
        h.it("respects the limit", function()
            h.eq(#Search.Find(world, "a", "H", 2), 2)
        end)
        h.it("returns every match when no limit is given", function()
            local all = Search.Find(world, "a", "H")
            h.eq(#all, 10, "more than the eight it used to stop at")
            h.eq(#all, #Search.Find(world, "a", "H", 100))
        end)
    end)

    h.describe("generated towns", function()
        -- The fake world with a towns table shaped as tools/build_graph.py
        -- emits Data/Towns.lua. Map coords and world coords are one point.
        local function withTowns()
            local w = dofile("test/fake_world.lua")()
            w.Towns = {
                [101] = { name = "Mike", map = 1, mx = 0.3, my = 0.3, c = 1, x = 7000, y = 7000 },
                [102] = { name = "November", map = 4, mx = 0.6, my = 0.6, c = 1, x = 4000, y = 4000, f = "A" },
                -- The game's own label for the hand-written inn town, 100 yards off it.
                [103] = { name = "Quiet Hollow", map = 1, mx = 0.26, my = 0.5, c = 1, x = 5000, y = 7400 },
                -- In Lostland, which held nothing until now.
                [104] = { name = "Oscar", map = 5, mx = 0.5, my = 0.5, c = 1, x = 5000, y = 5000, f = "H" },
            }
            return w
        end

        h.it("offers a town as a place of kind town, in its zone", function()
            local mike = Search.Find(withTowns(), "mike", "H")[1]
            h.eq(mike.kind, "town")
            h.eq(mike.townID, 101)
            h.eq(mike.name, "Mike")
            h.eq(mike.zone, "Westland")
            h.eq(mike.enemy, nil, "a town with no inferred faction is nobody's enemy")
            h.eq(mike.map, 1)
            h.eq(mike.x, 7000)
            h.eq(mike.y, 7000)
        end)
        h.it("marks a town with the other faction's inferred faction", function()
            local w = withTowns()
            h.eq(Search.Find(w, "november", "H")[1].enemy, "A")
            h.eq(Search.Find(w, "november", "A")[1].enemy, nil, "an Alliance town is no enemy to the Alliance")
            h.eq(Search.Find(w, "oscar", "A")[1].enemy, "H")
        end)
        h.it("lets the hand-written inn town win over the game's town of its name", function()
            local found = Search.Find(withTowns(), "quiet", "H")
            h.eq(#found, 1, "one Quiet Hollow, not two")
            h.eq(found[1].townID, nil, "the inn row's")
            h.eq(found[1].y, 7500, "at the inn row's own position")
        end)
        h.it("takes a zone off the list once a town stands in it", function()
            local w = withTowns()
            local count = { stop = 0, town = 0, zone = 0 }
            for _, item in ipairs(Search.Candidates(w, "H")) do
                count[item.kind] = count[item.kind] + 1
            end
            h.eq(count.stop, 8)
            h.eq(count.town, 6, "three inn towns and Mike, November and Oscar")
            h.eq(count.zone, 0, "Oscar stands in Lostland")
            h.eq(Search.Exact(w, "Lostland", "H"), nil)
            h.eq(Search.Exact(w, "Oscar", "H").map, 5)
        end)
    end)

    h.describe("two stops of one name", function()
        -- Booty Bay, Gadgetzan and Everlook each have one stop per faction, a
        -- few yards apart. Kilo is that town. The enemy's stop is on the LOWER
        -- ID, so a tie broken by ID alone would pick the one you cannot use.
        local function withTwins()
            local w = dofile("test/fake_world.lua")()
            w.Nodes[11] = { name = "Kilo, Westland", f = "A", c = 1, x = 3000, y = 3000, map = 1, mx = 0.7, my = 0.7 }
            w.Nodes[12] = { name = "Kilo, Westland", f = "H", c = 1, x = 3010, y = 3010,
                            map = 1, mx = 0.699, my = 0.699 }
            return w
        end

        h.it("offers only the stop this faction may use", function()
            local w = withTwins()
            local horde = Search.Find(w, "kilo", "H")
            h.eq(#horde, 1, "the Alliance's Kilo is not offered to the Horde")
            h.eq(horde[1].nodeID, 12)
            h.eq(horde[1].enemy, nil)
            local alliance = Search.Find(w, "kilo", "A")
            h.eq(#alliance, 1)
            h.eq(alliance[1].nodeID, 11)
        end)
        h.it("still offers an enemy stop that has no twin of your own", function()
            local echo = Search.Find(withTwins(), "echo", "H")
            h.eq(#echo, 1)
            h.eq(echo[1].enemy, "A")
        end)
        h.it("pins the tie: the stop you may use wins, though the enemy's ID is lower", function()
            local w = withTwins()
            h.eq(Search.Exact(w, "Kilo", "H").nodeID, 12)
            h.eq(Search.Exact(w, "Kilo", "A").nodeID, 11)
            local any = Search.Find(w, "kilo")
            h.eq(#any, 2, "with no faction, neither is an enemy, so both are offered")
            h.eq(any[1].nodeID, 11, "and the lower ID comes first")
            h.eq(Search.Exact(w, "Kilo").nodeID, 11)
        end)
        h.it("is counted once in the zone browser", function()
            for _, zone in ipairs(Search.Zones(withTwins(), "H")) do
                if zone.name == "Westland" then
                    h.eq(zone.count, 7, "six places and one Kilo, not two")
                end
            end
        end)
    end)

    h.describe("Search.Zones", function()
        h.it("lists every zone A to Z with how many places it holds", function()
            local out = {}
            for i, zone in ipairs(Search.Zones(world, "H")) do
                h.eq(zone.kind, "browse", zone.name .. " is a way in, not a destination")
                out[i] = zone.name .. " " .. zone.count
            end
            h.eq(table.concat(out, ", "), "Eastland 1, Isle 2, Lostland 1, Northland 2, Westland 6",
                 "Lostland holds only its own (zone) row")
        end)
    end)

    h.describe("Search.Candidates", function()
        h.it("offers every stop, every inn town, and a zone only when it holds neither", function()
            local count, names = { stop = 0, town = 0, zone = 0 }, {}
            for _, item in ipairs(Search.Candidates(world, "H")) do
                count[item.kind] = count[item.kind] + 1
                names[item.name] = item.kind
            end
            h.eq(count.stop, 8, "the Alliance's Echo too")
            h.eq(count.town, 3, "Quiet Hollow, Juliet and Gatehouse")
            h.eq(count.zone, 1)
            h.eq(names.Lostland, "zone", "Lostland holds no stop and no town")
            h.falsy(names.Westland, "a zone with places in it is only a search word")
            h.falsy(names["Nowhere Inn"], "an inn on a map we do not have is nowhere to go")
            h.falsy(names["Delta Harbour Inn"], "an inn beside a stop is that stop")
            h.falsy(names["Quiet Hollow Tavern"], "an inn building is its town")
        end)
        h.it("leaves no zone without a candidate", function()
            local reached = {}
            for _, item in ipairs(Search.Candidates(world, "H")) do
                reached[item.map] = true
            end
            for map, place in pairs(world.Places) do
                h.truthy(reached[map], place.name .. " cannot be picked at all")
            end
        end)
        h.it("gives every place its zone", function()
            for _, item in ipairs(Search.Candidates(world, "H")) do
                h.eq(item.zone, world.Places[item.map].name, item.name)
            end
        end)
    end)

    h.describe("Search.Exact", function()
        h.it("finds a bind name that matches a stop", function()
            h.eq(Search.Exact(world, "delta").nodeID, 4)
        end)
        h.it("ignores a leading The: the inn is The Crossroads, the stop is Crossroads", function()
            h.eq(Search.Exact(world, "The Delta").nodeID, 4)
            h.eq(Search.Exact(world, "the delta").nodeID, 4)
        end)
        h.it("does not match a zone that holds places: pick one of those", function()
            h.eq(Search.Exact(world, "Westland"), nil)
            h.eq(Search.Exact(world, "The Westland"), nil)
        end)
        h.it("matches a zone that holds no place", function()
            h.eq(Search.Exact(world, "Lostland").kind, "zone")
        end)
        h.it("does not match on a partial name", function()
            h.eq(Search.Exact(world, "Delt"), nil)
        end)
        h.it("follows an inn that stands beside a flight stop", function()
            h.eq(Search.Exact(world, "Delta Harbour Inn", "H").nodeID, 4)
        end)
        h.it("places an inn in a town with no flight master", function()
            local inn = Search.Exact(world, "quiet hollow", "H")
            h.eq(inn.kind, "town")
            h.eq(inn.name, "Quiet Hollow")
            h.eq(inn.zone, "Westland")
            h.eq(inn.c, 1)
            h.eq(inn.x, 5000)
            h.eq(inn.y, 7500)
        end)
        h.it("follows an inn building to the town it stands in", function()
            local town = Search.Exact(world, "Quiet Hollow Tavern", "H")
            h.eq(town.kind, "town")
            h.eq(town.name, "Quiet Hollow")
        end)
        h.it("returns nil for an inn on a map we do not have", function()
            h.eq(Search.Exact(world, "Nowhere Inn", "H"), nil)
        end)
        h.it("returns nil for an inn it does not know", function()
            h.eq(Search.Exact(world, "Some Backwater Inn"), nil)
        end)
        h.it("does not loop forever on an inn that names itself as its own stop", function()
            h.eq(Search.Exact(world, "Loop Inn", "H"), nil)
        end)
    end)
end

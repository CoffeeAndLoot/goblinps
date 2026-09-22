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

-- Run from the repository root through lupa (see CLAUDE.md).
local harness = dofile("test/harness.lua")

-- Same (addonName, ns) the client passes, loaded in TOC order into one ns.
-- API.lua and Core.lua touch Blizzard globals, so they are not loaded here.
local modules = {
    { "Geo",     "GoblinPS/Geo.lua" },
    { "Places",  "GoblinPS/Data/Places.lua" },
    { "Nodes",   "GoblinPS/Data/Nodes.lua" },
    { "Flights", "GoblinPS/Data/Flights.lua" },
    { "Links",   "GoblinPS/Data/Links.lua" },
    { "Inns",    "GoblinPS/Data/Inns.lua" },
    { "Crossings", "GoblinPS/Data/Crossings.lua" },
    { "Zones",   "GoblinPS/Data/Zones.lua" },
    { "Travel",  "GoblinPS/Travel.lua" },
    { "Search",  "GoblinPS/Search.lua" },
    { "Graph",   "GoblinPS/Graph.lua" },
    { "Route",   "GoblinPS/Route.lua" },
    { "Strip",   "GoblinPS/Strip.lua" },
    { "Trip",    "GoblinPS/Trip.lua" },
    { "Marquee", "GoblinPS/Marquee.lua" },
    { "Known",   "GoblinPS/Known.lua" },
    { "Prefs",   "GoblinPS/Prefs.lua" },
}

local ns = {}
local loaded = { ns = ns }
for i = 1, #modules do
    local name, path = modules[i][1], modules[i][2]
    local f = io.open(path, "r")
    if f then
        f:close()
        loaded[name] = assert(loadfile(path))("GoblinPS", ns)
    end
end

local suites = {
    "test/test_geo.lua",
    "test/test_search.lua",
    "test/test_graph.lua",
    "test/test_route.lua",
    "test/test_strip.lua",
    "test/test_marquee.lua",
    "test/test_trip.lua",
    "test/test_known.lua",
    "test/test_prefs.lua",
    "test/test_travel.lua",
    "test/test_crossings.lua",
    "test/test_ui.lua",
    "test/test_data.lua",
}

for i = 1, #suites do
    local f = io.open(suites[i], "r")
    if f then
        f:close()
        dofile(suites[i])(harness, loaded)
    end
end

os.exit(harness.run())

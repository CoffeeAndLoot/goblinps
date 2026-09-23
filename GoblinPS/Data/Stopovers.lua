-- HAND-WRITTEN. Named points inside one zone that a ride may pass through.
-- Inside a zone a ride leg is a straight line, and the router knows nothing
-- of roads, so a line between two points can run straight through an enemy
-- town (Graph.Hostile). A stopover gives it a way round: Graph.Build
-- joins it to every other point in its zone, like a tunnel's mouth, and the
-- router bends through it when that is quicker than the penalty.
--
--   { name = "...", map = <UiMap>, mx = 0.501, my = 0.662, unverified = true }
--     name   what the step says, "Ride to <name>": describe the way, and
--            include "the" ("the road south of Silverwind Refuge"). No comma:
--            everything after one is cut from the step.
--     map    the zone's UiMap ID (Data/Places.lua; /gps where prints it)
--     mx, my map coords (0..1). Stand on the spot and type /gps where: it
--            prints "Ashenvale (1440) 50.1, 66.2"; divide each by 100.
--     unverified = true   optional: placed from the map, not walked. The
--            step's detail line then says "stopover not confirmed".
--
-- test/test_data.lua checks every row sits on its zone's map.
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.Stopovers = {
}

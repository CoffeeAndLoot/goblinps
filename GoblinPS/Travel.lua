local _, ns = ...

-- Pure: how fast this character covers ground, and the settings behind it.
-- All three numbers are now settled, and none of them is a guess any more.
--   base 7 yards a second: MEASURED in game 2026-09-20, GetUnitSpeed("player")
--     unmounted returned 0, 7, 7, 4.7222 (current, run, flight, swim).
--   levels 40 and 60: READ OFF the riding trainer in game 2026-09-20,
--     Apprentice Riding requires 40, Journeyman requires 60.
--   speeds 11.2 and 14: the user states Forever uses vanilla riding, which is
--     +60% and +100%, so 7 x 1.6 and 7 x 2.0. Stated rather than measured, on
--     a base that was measured.
-- Level stands in for "has a mount" on purpose: the riding skill and mount
-- list APIs are unverified on this client.
local Travel = {}
ns.Travel = Travel

Travel.WALK_YARDS_PER_SECOND = 7
Travel.MOUNTS = {               -- lowest level first
    { level = 40, yardsPerSecond = 11.2 }, -- Apprentice Riding, +60% of 7
    { level = 60, yardsPerSecond = 14 },   -- Journeyman Riding, +100% of 7
}
Travel.WARN_LEVELS_ABOVE = 5    -- a zone that starts this far above you gets an amber warning

-- level nil (unknown) is treated as on foot: the safe, slower guess.
-- Returns { speed = yards per second, walk = true when on foot }.
function Travel.For(level)
    local speed, walk = Travel.WALK_YARDS_PER_SECOND, true
    for _, mount in ipairs(Travel.MOUNTS) do
        if level and level >= mount.level then
            speed, walk = mount.yardsPerSecond, false
        end
    end
    return { speed = speed, walk = walk }
end

-- Is a zone with this { low, high } range dangerous for this level?
function Travel.Dangerous(range, level)
    if not range or not level then
        return false
    end
    return range[1] > level + Travel.WARN_LEVELS_ABOVE
end

return Travel

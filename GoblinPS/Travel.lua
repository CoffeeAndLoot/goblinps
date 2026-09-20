local _, ns = ...

-- Pure: how fast this character covers ground, and the settings behind it.
-- THE NUMBERS ARE NOT CONFIRMED for WoW Forever: the mount levels come from
-- press coverage. They live here, in one place, so the definitive answer is a
-- two-line change. Level stands in for "has a mount" on purpose: the riding
-- skill and mount list APIs are unverified on this client.
local Travel = {}
ns.Travel = Travel

Travel.WALK_YARDS_PER_SECOND = 7
Travel.MOUNTS = {               -- lowest level first
    { level = 40, yardsPerSecond = 11.2 }, -- a 60% mount
    { level = 60, yardsPerSecond = 14 },   -- a 100% mount
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

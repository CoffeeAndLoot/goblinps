local _, ns = ...

-- /gps selftest: checks, in the real client, the few things the window leans
-- on that a beta patch could take away. The window uses no Blizzard frame
-- templates, so this is fonts, stock textures, our own art and the APIs
-- (API.SelfCheck lists those, since only API.lua touches game APIs).
local SelfTest = {}
ns.SelfTest = SelfTest

SelfTest.FONTS = {
    "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge", "GameFontNormalHuge",
    "GameFontHighlightSmall", "GameFontDisableSmall",
}
local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"

-- The parts tools/make_art.py builds, sorted for a stable report; never typed
-- by hand so this list cannot drift from what the tool produced. Data.Art
-- also carries a non-part "geometry" table (placement fractions for
-- Dash.lua), so only entries with a `.file` are textures to probe.
local function shippedArt()
    local names = {}
    for name, part in pairs(ns.Data.Art or {}) do
        if type(part) == "table" and part.file then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    local paths = {}
    for _, name in ipairs(names) do
        paths[#paths + 1] = MEDIA .. ns.Data.Art[name].file
    end
    return paths
end

SelfTest.TEXTURES = {
    "Interface\\AddOns\\GoblinPS\\Media\\icon",
    "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
}
for _, path in ipairs(shippedArt()) do
    SelfTest.TEXTURES[#SelfTest.TEXTURES + 1] = path
end
local COLOUR = { pass = "|cff6fe08aok|r  ", fail = "|cffe0501cFAIL|r" }

-- SetTexture returns whether the file was found and loaded.
local function textureLoads(probe, path)
    return probe:SetTexture(path) and true or false
end

function SelfTest.Run(say)
    local failed = 0
    local function report(ok, text)
        if not ok then
            failed = failed + 1
        end
        say(COLOUR[ok and "pass" or "fail"] .. " " .. text)
    end

    for _, name in ipairs(SelfTest.FONTS) do
        report(_G[name] ~= nil, "font " .. name)
    end
    local holder = CreateFrame("Frame")
    local probe = holder:CreateTexture()
    for _, path in ipairs(SelfTest.TEXTURES) do
        report(textureLoads(probe, path), "texture " .. path)
    end
    for _, check in ipairs(ns.API.SelfCheck()) do
        report(check.present, "api " .. check.name)
    end
    say("flight paths learned: " .. ns.Core.KnownCount())

    say(failed == 0 and "Self-test passed." or ("Self-test: " .. failed .. " failed."))
    return failed == 0
end

return SelfTest

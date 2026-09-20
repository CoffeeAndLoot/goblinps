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
SelfTest.TEXTURES = {
    "Interface\\AddOns\\GoblinPS\\Media\\icon",
    "Interface\\Minimap\\MiniMap-TrackingBorder",
    "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
}
local COLOUR = { pass = "|cff6fe08aok|r  ", fail = "|cffe0501cFAIL|r" }

-- A texture that failed to load reports no file; GetTexture is nil then.
local function textureLoads(probe, path)
    probe:SetTexture(nil)
    probe:SetTexture(path)
    return probe:GetTexture() ~= nil
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
    report(ns.Core.KnownCount() >= 0, "flight paths learned: " .. ns.Core.KnownCount())

    say(failed == 0 and "Self-test passed." or ("Self-test: " .. failed .. " failed."))
    return failed == 0
end

return SelfTest

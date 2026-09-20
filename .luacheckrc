std = "lua51"
max_line_length = 120
self = false
globals = {
    "SLASH_GOBLINPS1", "SlashCmdList", "GoblinPSDB", "GoblinPSCharDB",
    "GoblinPS_OnAddonCompartmentClick", "UISpecialFrames",
    "GoblinPSMinimapButton", "GoblinPSPlanner", "GoblinPSDash",
}
read_globals = {
    "print",
    "UnitFactionGroup", "GetBindLocation", "UnitLevel",
    "GetPlayerFacing", "UnitOnTaxi",
    "C_TaxiMap", "C_Map", "C_Item", "C_SuperTrack", "UiMapPoint",
    "CreateFrame", "Enum",
    "UIParent", "Minimap", "GameTooltip", "GetCursorPosition",
}
files["GoblinPS/Data/Places.lua"] = { max_line_length = false }
files["GoblinPS/Data/Nodes.lua"] = { max_line_length = false }
files["GoblinPS/Data/Flights.lua"] = { max_line_length = false }
-- Hand-written, one crossing per line with its zone names as a trailing comment.
files["GoblinPS/Data/Crossings.lua"] = { max_line_length = false }
-- The UI smoke test installs a fake frame API into the globals.
files["test/fake_frames.lua"] = { globals = { "print" } }
files["test/test_ui.lua"] = { globals = { "print" } }

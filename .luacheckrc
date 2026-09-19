std = "lua51"
max_line_length = 120
self = false
globals = {
    "SLASH_GOBLINPS1", "SlashCmdList", "GoblinPSCharDB",
}
read_globals = {
    "print",
    "UnitFactionGroup", "GetBindLocation",
    "C_TaxiMap", "C_Map", "C_Item",
    "CreateFrame", "Enum",
}
files["GoblinPS/Data/Places.lua"] = { max_line_length = false }
files["GoblinPS/Data/Nodes.lua"] = { max_line_length = false }
files["GoblinPS/Data/Flights.lua"] = { max_line_length = false }

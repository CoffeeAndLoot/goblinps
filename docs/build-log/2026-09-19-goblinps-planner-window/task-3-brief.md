### Task 3: `Prefs`

**Files:**
- Create: `GoblinPS/Prefs.lua`, `test/test_prefs.lua`
- Modify: `test/run.lua`

**Interfaces:**
- Produces: `ns.Prefs.Init(db) -> db` (fills `layout` = `"wide"`|`"tall"`, `recents` = list of names, `positions`, `minimap = { angle, hide }`); `Prefs.ToggleLayout(db) -> mode`; `Prefs.Remember(db, name)` (newest first, no duplicates, at most `Prefs.MAX_RECENTS` = 8); `Prefs.SavePosition(db, window, point, x, y)`; `Prefs.Position(db, window) -> { point, x, y } or nil`.

- [ ] **Step 1: Write the failing test `test/test_prefs.lua`**

```lua
return function(h, loaded)
    local Prefs = loaded.ns.Prefs

    h.describe("Prefs.Init", function()
        h.it("fills an empty table with the defaults", function()
            local db = Prefs.Init(nil)
            h.eq(db.layout, "wide")
            h.eq(#db.recents, 0)
            h.eq(db.minimap.angle, 215)
            h.eq(db.minimap.hide, false)
        end)
        h.it("keeps what the player already chose", function()
            local db = Prefs.Init({ layout = "tall", minimap = { angle = 10 } })
            h.eq(db.layout, "tall")
            h.eq(db.minimap.angle, 10)
            h.eq(db.minimap.hide, false)
        end)
        h.it("repairs a layout it does not know", function()
            h.eq(Prefs.Init({ layout = "sideways" }).layout, "wide")
        end)
        h.it("gives every table its own copy of the defaults", function()
            local a, b = Prefs.Init(nil), Prefs.Init(nil)
            a.recents[1] = "Orgrimmar"
            h.eq(#b.recents, 0)
        end)
    end)

    h.describe("Prefs.ToggleLayout", function()
        h.it("flips between wide and tall", function()
            local db = Prefs.Init(nil)
            h.eq(Prefs.ToggleLayout(db), "tall")
            h.eq(Prefs.ToggleLayout(db), "wide")
            h.eq(db.layout, "wide")
        end)
    end)

    h.describe("Prefs.Remember", function()
        h.it("puts the newest destination first", function()
            local db = Prefs.Init(nil)
            Prefs.Remember(db, "Orgrimmar")
            Prefs.Remember(db, "Undercity")
            h.eq(table.concat(db.recents, ","), "Undercity,Orgrimmar")
        end)
        h.it("moves a repeat to the front instead of listing it twice", function()
            local db = Prefs.Init(nil)
            Prefs.Remember(db, "Orgrimmar")
            Prefs.Remember(db, "Undercity")
            Prefs.Remember(db, "Orgrimmar")
            h.eq(table.concat(db.recents, ","), "Orgrimmar,Undercity")
        end)
        h.it("keeps only the newest eight", function()
            local db = Prefs.Init(nil)
            for i = 1, 10 do
                Prefs.Remember(db, "Place " .. i)
            end
            h.eq(#db.recents, Prefs.MAX_RECENTS)
            h.eq(db.recents[1], "Place 10")
            h.eq(db.recents[8], "Place 3")
        end)
        h.it("ignores an empty name", function()
            local db = Prefs.Init(nil)
            Prefs.Remember(db, "")
            Prefs.Remember(db, nil)
            h.eq(#db.recents, 0)
        end)
    end)

    h.describe("Prefs window positions", function()
        h.it("saves and returns a position per window", function()
            local db = Prefs.Init(nil)
            h.eq(Prefs.Position(db, "planner"), nil)
            Prefs.SavePosition(db, "planner", "CENTER", 12, -30)
            local p = Prefs.Position(db, "planner")
            h.eq(p.point, "CENTER")
            h.eq(p.x, 12)
            h.eq(p.y, -30)
        end)
    end)
end
```

In `test/run.lua` add the module line `    { "Prefs",   "GoblinPS/Prefs.lua" },` after the `Known` line, and the suite line `    "test/test_prefs.lua",` after `"test/test_known.lua",`.

- [ ] **Step 2: Run the Lua tests.** Expected: the ten new tests fail (`Prefs` is nil).

- [ ] **Step 3: Write `GoblinPS/Prefs.lua`**

```lua
local _, ns = ...

-- Pure: the account-wide preferences table (GoblinPSDB). Preferences, recent
-- destinations and window positions only. Known flight paths live per
-- character in GoblinPSCharDB and are owned by Known.lua.
local Prefs = {}
ns.Prefs = Prefs

Prefs.MAX_RECENTS = 8
local LAYOUTS = { wide = "tall", tall = "wide" } -- each layout's other one

-- Returns db (or a new table) with every missing preference filled in.
function Prefs.Init(db)
    db = type(db) == "table" and db or {}
    if not LAYOUTS[db.layout] then
        db.layout = "wide"
    end
    db.recents = type(db.recents) == "table" and db.recents or {}
    db.positions = type(db.positions) == "table" and db.positions or {}
    db.minimap = type(db.minimap) == "table" and db.minimap or {}
    if type(db.minimap.angle) ~= "number" then
        db.minimap.angle = 215
    end
    db.minimap.hide = db.minimap.hide == true
    return db
end

function Prefs.ToggleLayout(db)
    db.layout = LAYOUTS[db.layout] or "wide"
    return db.layout
end

-- Newest first, no duplicates, capped.
function Prefs.Remember(db, name)
    if not name or name == "" then
        return
    end
    for i = #db.recents, 1, -1 do
        if db.recents[i] == name then
            table.remove(db.recents, i)
        end
    end
    table.insert(db.recents, 1, name)
    while #db.recents > Prefs.MAX_RECENTS do
        table.remove(db.recents)
    end
end

function Prefs.SavePosition(db, window, point, x, y)
    db.positions[window] = { point = point, x = x, y = y }
end

function Prefs.Position(db, window)
    return db.positions[window]
end

return Prefs
```

- [ ] **Step 4: Run the Lua tests.** Expected: `89 passed, 0 failed`. luacheck clean.

- [ ] **Step 5: Commit** (the TOC gets `Prefs.lua` in Task 5, with the rest of the window)

```
git add GoblinPS/Prefs.lua test/test_prefs.lua test/run.lua
git commit -m "Add the preferences module" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---


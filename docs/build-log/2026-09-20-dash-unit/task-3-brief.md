### Task 3: What the client has to tell us

**Files:**
- Modify: `GoblinPS/API.lua`
- Modify: `GoblinPS/Core.lua` (expose `Core.Here`)
- Modify: `test/fake_frames.lua` (model `SetRotation`)
- Test: `test/test_ui.lua` (the fake API gains the new calls)

**Interfaces:**
- Produces, for task 5:
  - `API.PlayerFacing()` returns radians or nil.
  - `API.OnTaxi()` returns true or false, never nil.
  - `API.OnTripEvent(callback)` calls `callback(kind)` with `"zone"` or `"landed"`.
  - `Core.Here()` returns `{ name = "You", c, x, y, map, mx, my }` or nil, the same table the planner already plans from.

`API.lua` is the only file allowed to touch these. Every event below is confirmed present in `docs/research/2026-09-19-api-and-data-findings.md`; registering a name this client does not know is a hard error, so add none.

- [ ] **Step 1: Write the failing test**

In `test/test_ui.lua`, extend the scripted `ns.API` table with the three new calls, beside the existing ones:

```lua
        PlayerFacing = function() return facing end,
        OnTaxi = function() return onTaxi end,
        OnTripEvent = function(callback) tripCallbacks[#tripCallbacks + 1] = callback end,
```

and declare their state near `local level = 60`:

```lua
    local facing, onTaxi, tripCallbacks = 0, false, {}
```

Then add, beside the other describe blocks:

```lua
    h.describe("the fake frames model what the dash needs", function()
        h.it("a texture can be rotated", function()
            local f = CreateFrame("Frame")
            local t = f:CreateTexture(nil, "ARTWORK")
            t:SetRotation(1.25)
            h.eq(t.rotation, 1.25, "the fake must record the angle so tests can read it")
        end)
        h.it("a texture records its coordinates, tint and layer", function()
            local f = CreateFrame("Frame")
            local t = f:CreateTexture(nil, "ARTWORK")
            t:SetTexCoord(0, 0.75, 0, 0.5)
            h.eq(t.texCoord[2], 0.75, "SetTexCoord must record, not be swallowed")
            h.eq(t.texCoord[4], 0.5)
            t:SetVertexColor(1, 0, 0, 1)
            h.eq(t.vertexColor[1], 1)
            t:SetDrawLayer("OVERLAY")
            h.eq(t.drawLayer, "OVERLAY")
        end)
    end)
```

- [ ] **Step 2: Run to verify it fails**

Run the Lua suite. Expected: FAIL with the strict fake's `unknown widget method` error for `SetRotation`.

- [ ] **Step 3: Teach the fake to rotate**

In `test/fake_frames.lua`, beside the other texture methods, add:

```lua
    SetRotation = function(self, radians) self.rotation = radians end,
    SetVertexColor = function(self, r, g, b, a) self.vertexColor = { r, g, b, a } end,
    SetDrawLayer = function(self, layer) self.drawLayer = layer end,
```

and change `SetTexCoord` so it **records** instead of being swallowed. Today it
sits in the accepted-and-ignored list at the top of the file, which means
`texture.texCoord` is never set and task 6 could not check its own work:

```lua
    SetTexCoord = function(self, l, r, t, b) self.texCoord = { l, r, t, b } end,
```

Remove `SetTexCoord` from the ignored list when you add the recording version,
or the ignored entry will win.

Match the file's existing style for texture methods exactly; the fake is strict
on purpose, so an unmodelled PascalCase method raises rather than silently
passing. Tasks 4 and 6 call `SetVertexColor` and `SetDrawLayer`, so without
these three additions they would fail on the fake, not on their own behaviour.

- [ ] **Step 4: Add the client calls**

In `GoblinPS/API.lua`, beside `API.Level`:

```lua
-- Which way the player faces, in radians: 0 north, growing counter-clockwise.
-- Documented Nilable, and it has no answer in some places, so callers must
-- cope with nil by hiding the arrow rather than pointing it somewhere wrong.
function API.PlayerFacing()
    if not GetPlayerFacing then
        return nil
    end
    return GetPlayerFacing()
end

-- On a flight path, where the player steers nothing and straying is meaningless.
function API.OnTaxi()
    return UnitOnTaxi and UnitOnTaxi("player") and true or false
end
```

and beside `API.OnTaxiMapOpened`:

```lua
-- The moments worth re-checking an active trip, beyond the dash's own ticking:
-- crossing into a new zone, and a flight ending. Calls back with "zone" or
-- "landed". All four events are confirmed present on this build; do not add
-- others without checking the forever branch first.
function API.OnTripEvent(callback)
    local f = CreateFrame("Frame")
    f:RegisterEvent("ZONE_CHANGED")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("PLAYER_CONTROL_LOST")
    f:RegisterEvent("PLAYER_CONTROL_GAINED")
    f:SetScript("OnEvent", function(_, event)
        callback(event == "PLAYER_CONTROL_GAINED" and "landed" or "zone")
    end)
end
```

Add `GetPlayerFacing` and `UnitOnTaxi` to `API.SelfCheck`'s list, and to both `.luacheckrc` and `.luarc.json`.

In `GoblinPS/Core.lua`, make the existing local `here` reachable:

```lua
-- Where the player stands, as a place the router understands. Nil inside an
-- instance, where the client gives no useful position.
function Core.Here() return here() end
```

- [ ] **Step 5: Run the tests and the linters**

Run the Lua suite, luacheck and the language server. Expected: green, zero warnings. `PlayerFacing`, `OnTaxi` and `OnTripEvent` are not called by anything yet; that is task 5.

- [ ] **Step 6: Commit**

```bash
git add GoblinPS/API.lua GoblinPS/Core.lua test/fake_frames.lua test/test_ui.lua .luacheckrc .luarc.json
git commit -m "API: facing, taxi state and the arrival events" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---


### Task 6: The art over the colours

**Files:**
- Modify: `GoblinPS/Dash.lua`
- Modify: `GoblinPS/SelfTest.lua`
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `ns.Data.Art` from task 1, shaped `{ [name] = { file, l, r, t, b } }`.
- Produces: nothing new. The device looks like the mockup and still works without a single texture.

The stacking order, from Codex's handoff: **screen, compass, arrow, body**. The body has a transparent hole; the screen shows through it. Draw layers accordingly: screen `BACKGROUND`, compass `BORDER`, arrow `ARTWORK`, body `OVERLAY`.

`SetTexture` returns whether the file loaded. That return is the fallback test: if it is false, leave the flat colour showing and never hide it behind an invisible texture.

- [ ] **Step 1: Write the failing test**

Append to `test/test_ui.lua`:

```lua
    h.describe("the dash art", function()
        h.it("lays every part on with the coordinates the tool generated", function()
            Dash.Start(plan)
            local ui = Dash.Debug()
            for _, pair in ipairs({ { ui.bodyArt, "dash-body" }, { ui.screenArt, "dash-screen" },
                                    { ui.compass, "dash-compass" }, { ui.arrow, "arrow" } }) do
                local texture, name = pair[1], pair[2]
                local art = ns.Data.Art[name]
                h.truthy(art, name .. " is missing from the generated table")
                h.eq(texture:GetTexture(), "Interface\\AddOns\\GoblinPS\\Media\\" .. art.file)
                h.eq(texture.texCoord[1], art.l)
                h.eq(texture.texCoord[2], art.r)
            end
        end)
        h.it("keeps a working device when a texture will not load", function()
            Fake.missingTextures["Interface\\AddOns\\GoblinPS\\Media\\dash-body"] = true
            Dash.Stop()
            Dash.Start(plan)
            local ui = Dash.Debug()
            h.truthy(ui.frame:IsShown(), "a missing texture must not take the window with it")
            h.truthy(ui.step:GetText() ~= "", "the directions must still be readable")
            Fake.missingTextures["Interface\\AddOns\\GoblinPS\\Media\\dash-body"] = nil
        end)
    end)
```

`Fake.missingTextures` already exists in `test/fake_frames.lua`; it is how the planner's texture fallback is tested. If `texCoord` is not recorded by the fake's `SetTexCoord`, record it there the same way `SetRotation` was added in task 3.

- [ ] **Step 2: Run to verify it fails**

Run the Lua suite. Expected: FAIL, `ui.bodyArt` is nil.

- [ ] **Step 3: Lay the art on**

In `GoblinPS/Dash.lua`, add a helper and use it in `build()`:

```lua
local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"

-- Lay a generated part over a flat colour. Returns the texture, or nil when
-- the part is unknown or the file will not load, leaving the colour showing.
local function art(parent, name, layer)
    local part = ns.Data.Art and ns.Data.Art[name]
    if not part then
        return nil
    end
    local t = parent:CreateTexture(nil, layer)
    if not t:SetTexture(MEDIA .. part.file) then
        t:Hide()
        return nil
    end
    t:SetTexCoord(part.l, part.r, part.t, part.b)
    t:SetAllPoints(parent)
    return t
end
```

Then in `build()`, after the screen panel and before the arrow:

```lua
    local screenArt = art(screen, "dash-screen", "BACKGROUND")
    local compass = art(screen, "dash-compass", "BORDER")
```

and after the arrow is created, replace its placeholder texture:

```lua
    local arrowPart = ns.Data.Art and ns.Data.Art["arrow"]
    if arrowPart and arrow:SetTexture(MEDIA .. arrowPart.file) then
        arrow:SetTexCoord(arrowPart.l, arrowPart.r, arrowPart.t, arrowPart.b)
        arrow:SetVertexColor(1, 1, 1)
    end
```

and after everything else, the body on top:

```lua
    local bodyArt = art(f, "dash-body", "OVERLAY")
```

The ETA plate is its own part, sitting behind the time-left line rather than
over the device, so it is laid on its own small frame:

```lua
    local plate = CreateFrame("Frame", nil, f)
    plate:SetPoint("TOPLEFT", eta, "TOPLEFT", -6, 4)
    plate:SetPoint("BOTTOMRIGHT", eta, "BOTTOMRIGHT", 6, -4)
    local plateArt = art(plate, "dash-eta-plate", "BACKGROUND")
    eta:SetDrawLayer("OVERLAY")
```

Add `screenArt`, `compass`, `bodyArt` and `plateArt` to the `ui` table so the
test can reach them, and include `dash-eta-plate` in the loop in step 1's first
test. All five parts the tool builds must be used; a texture generated and never
drawn is weight in the addon for nothing.

The compass turns with the player, not with the arrow: in `aimArrow`, after setting the arrow's rotation, add

```lua
    if ui.compass then
        ui.compass:SetRotation(-(ns.API.PlayerFacing() or 0))
    end
```

so north on the ring stays north in the world.

In `GoblinPS/SelfTest.lua`, add the five shipped textures to `SelfTest.TEXTURES`, built from `ns.Data.Art` rather than typed by hand, so the list cannot drift from what the tool produced.

- [ ] **Step 4: Run to verify it passes**

Run the Lua suite. Expected: green.

- [ ] **Step 5: Lint**

Run luacheck and the language server. Expected: zero warnings.

- [ ] **Step 6: Commit**

```bash
git add GoblinPS/Dash.lua GoblinPS/SelfTest.lua test/
git commit -m "Dash unit: the art over the colours" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---


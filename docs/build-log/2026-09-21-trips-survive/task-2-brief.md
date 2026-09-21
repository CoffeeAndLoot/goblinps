### Task 2: Only Stop ends a trip

**Files:**
- Modify: `GoblinPS/Dash.lua`
- Modify: `.luacheckrc`, `.luarc.json`
- Test: `test/test_ui.lua`

**Interfaces:**
- Consumes: `Core.ClearPin()`, `Core.ClearTrip()` (Task 1).
- Produces, for Task 3: `Dash.Stop()` ends the trip and clears the saved trip
  and our pin; `Dash.Tick` does nothing while the dash is hidden.

**Why this task rewrites a test.** `test/test_ui.lua` has a block,
`"the dash unit and Escape"`, asserting that hiding the dash ends the trip --
"the trip must not outlive the window it belongs to". That was the right rule
while hiding was the only way a trip ended. It is the rule this plan reverses.
Its real concern survives: a hidden trip must never replan or move pins behind
the player's back. So the block is rewritten, not deleted, and that concern
keeps a test.

- [ ] **Step 1: Write the failing tests**

Replace the whole `h.describe("the dash unit and Escape", ...)` block in
`test/test_ui.lua` with:

```lua
        h.describe("the dash unit and Escape", function()
            h.it("stays off Escape's list, so Escape never ends a trip", function()
                -- Escape is pressed constantly: to close bags, clear a target,
                -- open the game menu. It used to close the dash and end the
                -- trip with it. The dash is a heads-up display, like the
                -- minimap, not a dialog.
                Dash.Start(plan)
                for _, name in ipairs(UISpecialFrames) do
                    h.truthy(name ~= "GoblinPSDash", "the dash must not be on Escape's list")
                end
                Dash.Stop()
            end)

            h.it("keeps the trip when the dash is hidden some other way", function()
                Dash.Start(plan)
                local ui, state = Dash.Debug()
                ui.frame:Hide()
                h.truthy(state.plan, "hiding is not stopping")
                -- But a hidden trip must not move on behind the player's back:
                -- standing on the first step's target would advance it.
                standAt(0, 0)
                Dash.Tick("tick")
                h.eq(state.index, 1, "nothing moves while the dash is hidden")
                ui.frame:Show()
                Dash.Tick("tick")
                h.eq(state.index, 2, "and it picks up again once shown")
                standAt(1000, 1100)
                Dash.Stop()
            end)

            h.it("ends the trip on Stop, clearing the saved trip and our pin", function()
                Dash.Start(plan)
                ns.Core.SaveTrip(plan.to)
                ns.Core.PinStep({ kind = "ride", to = { name = "Gate", map = 1, mx = 0.5, my = 0.5 } })
                Dash.Stop()
                local ui, state = Dash.Debug()
                h.falsy(state.plan)
                h.falsy(ui.frame:IsShown())
                h.eq(ns.Core.SavedTripName(), nil, "a stopped trip does not come back after a reload")
                h.eq(waypoint, nil, "our pin is cleared")
            end)

            h.it("clears our pin on arrival, and keeps saying Arrived", function()
                local oneStep = { level = 60, to = plan.to, result = { seconds = 60, steps = {
                    { kind = "ride", seconds = 60,
                      to = { name = "the North Gate", c = 1, x = 0, y = 0, map = 1, mx = 0.5, my = 0.5 } },
                } } }
                Dash.Start(oneStep)
                ns.Core.PinStep(oneStep.result.steps[1])
                standAt(0, 0)
                Dash.Tick("tick")
                local ui = Dash.Debug()
                h.eq(ui.steps[1]:GetText(), "Arrived.")
                h.truthy(ui.frame:IsShown(), "Arrived. stays up until Stop")
                h.eq(waypoint, nil, "the pin at the destination is cleared")
                standAt(1000, 1100)
                Dash.Stop()
            end)
        end)
```

Also, in the test `"still ends the trip when the button is clicked"`, change
only the assertion message `"clicking Stop ends the trip, as Escape does"` to
`"clicking Stop ends the trip"`. Escape no longer does.

Every new test ends with `Dash.Stop()`. The two that move the player end, just
before it, with `standAt(1000, 1100)` -- the position the file starts at,
beside Alpha -- so no later test inherits a player standing on a step's
target.

- [ ] **Step 2: Run to verify they fail**

Run the Lua suite. Expected: FAIL -- the dash is still on Escape's list,
hiding clears `state.plan`, and Stop leaves the saved trip and the pin.

- [ ] **Step 3: Take the dash off Escape, and stop ending the trip on hide**

In `GoblinPS/Dash.lua`'s `build()`:

- Delete the `f:SetScript("OnHide", ...)` script and the comment block above
  it. Nothing now ends a trip on hide.
- Delete `ns.Core.CloseOnEscape(f, "GoblinPSDash")`.

- [ ] **Step 4: Stop is the one end**

Replace `Dash.Stop` and the comment above it with:

```lua
-- Stop is the one action that ends a trip. Nothing else does -- not Escape,
-- not hiding the interface, not arriving, not a reload -- so it is also the
-- one place the saved trip and our map pin are cleared.
function Dash.Stop()
    state.plan, state.index, state.best, state.banner = nil, nil, nil, nil
    ns.Core.ClearTrip()
    ns.Core.ClearPin()
    if ui then
        ui.frame:Hide()
    end
end
```

- [ ] **Step 5: Arrival clears our pin**

In `finish()`, after `ui.arrow:Hide()`, add:

```lua
    -- There is nowhere left to point. The trip is not over -- only Stop ends
    -- it -- but a pin on the spot you are standing on says nothing.
    ns.Core.ClearPin()
```

- [ ] **Step 6: A hidden dash does not tick**

In `Dash.Tick`, change the first guard from

```lua
    if not ui or not state.plan then
```

to

```lua
    -- Hidden (only something other than Stop can do that now): hold still,
    -- so a trip never replans or moves the map pin where nobody can see.
    if not ui or not state.plan or not ui.frame:IsShown() then
```

- [ ] **Step 7: `GoblinPSDash` is no longer a global**

It only existed so Escape's list could name it. Remove `"GoblinPSDash"` from
the globals list in both `.luacheckrc` and `.luarc.json`.

- [ ] **Step 8: Run the tests to verify they pass**

Run the Lua suite. Expected: green, 300 passed -- the Escape block went from
one test to four. Every existing dash test must still pass; if one relied on
hiding ending the trip, its read may change and its assertion may not --
except the Escape block this task deliberately rewrote.

- [ ] **Step 9: Lint**

Run luacheck and the language server from PowerShell. Expected: zero warnings.

- [ ] **Step 10: Commit**

```bash
git add GoblinPS/Dash.lua .luacheckrc .luarc.json test/test_ui.lua
git commit -m "Only Stop ends a trip" -m "The dash comes off Escape's list and hiding it no longer ends the trip, so pressing Escape to close a bag cannot kill the route. Stop clears the saved trip and our map pin; arriving clears the pin and keeps Arrived showing. A hidden dash holds still rather than replanning where nobody can see." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---


### Task 1: `Marquee.lua`, the character window

**Files:**
- Create: `GoblinPS/Marquee.lua`
- Create: `test/test_marquee.lua`
- Modify: `GoblinPS/GoblinPS.toc` (add `Marquee.lua` after `Trip.lua`)
- Modify: `test/run.lua` (module list and suite list)

**Interfaces:**
- Consumes: nothing.
- Produces: `ns.Marquee` with `Marquee.HOLD = 1.5`, `Marquee.STEP = 0.2`,
  `Marquee.GAP = "   "` (three spaces), `Marquee.New(text, fits)` -> a state
  table `{ text, fits, offset, clock }`, and `Marquee.Advance(m, dt)` -> the
  string to show. Task 2 calls both.

- [ ] **Step 1: Write the failing tests**

Create `test/test_marquee.lua`:

```lua
return function(h, loaded)
    local Marquee = loaded.ns.Marquee
    local HOLD, STEP, GAP = Marquee.HOLD, Marquee.STEP, Marquee.GAP

    h.describe("Marquee", function()
        h.it("holds a line that does not fit at its start for HOLD seconds", function()
            h.eq(GAP, "   ", "the wrap gap is three spaces")
            local m = Marquee.New("Ride to Far Crossing", false)
            h.eq(Marquee.Advance(m, 0), "Ride to Far Crossing")
            h.eq(Marquee.Advance(m, HOLD - 0.01), "Ride to Far Crossing", "still holding")
        end)

        h.it("then drops one character every STEP", function()
            local m = Marquee.New("Abcdef", false)
            h.eq(Marquee.Advance(m, HOLD + 0.01), "bcdef" .. GAP .. "Abcdef")
            h.eq(Marquee.Advance(m, STEP), "cdef" .. GAP .. "Abcdef")
            h.eq(Marquee.Advance(m, STEP / 2), "cdef" .. GAP .. "Abcdef", "half a step moves nothing")
            h.eq(Marquee.Advance(m, STEP / 2), "def" .. GAP .. "Abcdef")
        end)

        h.it("wraps round through the gap to the start, and holds again", function()
            local m = Marquee.New("Abc", false)
            h.eq(Marquee.Advance(m, HOLD + 0.01), "bc" .. GAP .. "Abc")
            h.eq(Marquee.Advance(m, STEP), "c" .. GAP .. "Abc")
            h.eq(Marquee.Advance(m, STEP), GAP .. "Abc", "the gap comes round")
            h.eq(Marquee.Advance(m, STEP), GAP:sub(2) .. "Abc")
            h.eq(Marquee.Advance(m, STEP), GAP:sub(3) .. "Abc")
            h.eq(Marquee.Advance(m, STEP), "Abc", "back at the start")
            h.eq(Marquee.Advance(m, HOLD - 0.05), "Abc", "and holding there again")
            h.eq(Marquee.Advance(m, 0.1), "bc" .. GAP .. "Abc")
        end)

        h.it("never moves text that fits", function()
            local m = Marquee.New("Delta", true)
            h.eq(Marquee.Advance(m, 0), "Delta")
            h.eq(Marquee.Advance(m, 60), "Delta")
        end)

        h.it("never moves an empty line", function()
            local m = Marquee.New("", false)
            h.eq(Marquee.Advance(m, 60), "")
            h.eq(Marquee.Advance(Marquee.New(nil, false), 60), "", "no text reads as empty")
        end)

        h.it("starts every new line fresh, at its start", function()
            local m = Marquee.New("Uvwxyz", false)
            h.eq(m.offset, 1)
            h.eq(m.clock, 0)
            h.eq(Marquee.Advance(m, STEP), "Uvwxyz", "a new line holds before it moves")
        end)

        h.it("never starts a line on half a character", function()
            -- "été": the first step would land on the second byte of the é.
            local ete = "\195\169t\195\169"
            local m = Marquee.New(ete, false)
            h.eq(Marquee.Advance(m, HOLD + 0.01), "t\195\169" .. GAP .. ete)
        end)
    end)
end
```

- [ ] **Step 2: Load it in the runner**

In `test/run.lua`, add `{ "Marquee", "GoblinPS/Marquee.lua" },` to `modules`
directly after the `Trip` row, and `"test/test_marquee.lua",` to `suites`
directly after `"test/test_strip.lua",`.

- [ ] **Step 3: Run the Lua gate to see them fail**

Expected: the runner skips the missing `Marquee.lua` (it checks `io.open`), so
every test in `test_marquee.lua` fails on `Marquee` being nil: 351 passed,
7 failed.

- [ ] **Step 4: Write `GoblinPS/Marquee.lua`**

```lua
local _, ns = ...

-- Scrolling text for the dash, the way the LED radios in old cars did it: a
-- character window. A line too long for its opening holds still at its start
-- for HOLD seconds, then drops its first character every STEP seconds, runs
-- round through a GAP and back to its start, and holds again. The
-- FontString's own truncation cuts the right edge, so this needs no clipping,
-- no new frames and no new API. A line that fits never moves.
--
-- Pure: state in, text out, no frames. The dash decides whether a line fits
-- (from its geometry, never from the FontString) and calls Advance every
-- frame from the OnUpdate it already runs.
local Marquee = {}
ns.Marquee = Marquee

Marquee.HOLD = 1.5   -- seconds the start is shown before it moves, and again after each lap
Marquee.STEP = 0.2   -- seconds per character
Marquee.GAP = "   "  -- between the end of the text and its start coming round again

-- A fresh marquee for `text`, at its start. `fits` is the caller's verdict.
function Marquee.New(text, fits)
    return { text = text or "", fits = fits and true or false, offset = 1, clock = 0 }
end

-- A byte in the middle of a UTF-8 character: showing from one would draw
-- half a letter.
local function continues(byte)
    return byte ~= nil and byte >= 128 and byte < 192
end

-- Moves the window on by `dt` seconds and answers the text to show.
function Marquee.Advance(m, dt)
    if m.fits or m.text == "" then
        return m.text
    end
    local tape = m.text .. Marquee.GAP
    m.clock = m.clock + (dt or 0)
    while true do
        local wait = m.offset == 1 and Marquee.HOLD or Marquee.STEP
        if m.clock < wait then
            break
        end
        m.clock = m.clock - wait
        m.offset = m.offset + 1
        while continues(tape:byte(m.offset)) do
            m.offset = m.offset + 1
        end
        if m.offset > #tape then
            m.offset = 1
        end
    end
    if m.offset == 1 then
        return m.text
    end
    -- The start follows the gap in, so the lap reads as one continuous tape.
    return tape:sub(m.offset) .. m.text
end

return Marquee
```

In `GoblinPS/GoblinPS.toc`, add `Marquee.lua` on its own line directly after
`Trip.lua`.

- [ ] **Step 5: Run every gate**

Lua: expected `358 passed, 0 failed` (351 + 7). Python and art unchanged and
green. luacheck and the language server from PowerShell: zero warnings.

- [ ] **Step 6: Commit**

```
git add GoblinPS/Marquee.lua GoblinPS/GoblinPS.toc test/test_marquee.lua test/run.lua
git commit -m "Marquee.lua: scrolling text as a character window" -m "Holds a line that does not fit at its start, drops one character a step, wraps round through a three-space gap and holds again, never on half a UTF-8 character. A line that fits never moves. Pure, so the dash only feeds it time." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---


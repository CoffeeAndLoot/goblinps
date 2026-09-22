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

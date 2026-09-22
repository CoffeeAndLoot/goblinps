# GoblinPS: settings panel, scrolling dash text, a narrower drop-down (plan 9)

Status: **asked for by the owner at 23:33 on 2026-09-21, then they went to bed.** No section was approved one by one. Every decision below that the owner did not state is marked **Ruling** and gathered at the end, so it can be overturned in the morning. This spec amends `2026-09-19-goblinps-design.md` and `2026-09-21-goblinps-planner-redesign-design.md`.

Built 2026-09-22 by `docs/superpowers/plans/2026-09-22-goblinps-settings-and-marquee.md` -- not yet run in the client.

## What the owner asked for

1. **Scrolling text on the dash.** This is `docs/later.md`'s "LED/LCD radio" entry: a line too long for its opening creeps sideways instead of being cut off.
2. **A settings panel behind the gear.** It holds:
   - how much time the hearthstone must save before a route uses it;
   - how close counts as arriving at a step ("the zeppelin is 800 yards, I think that's too high");
   - an About box, with a place for feedback to a GitHub page that does not exist yet.
3. **A narrower drop-down.** The results list should be "only a little wider than the longest name", not the full width.

## 1. Scrolling dash text (the marquee)

- The dash's text lines scroll when their text does not fit: the destination and distance on the glass, the three step lines, and the ETA. A line that fits never moves.
- **It works like the old car radios: a character window.** The line holds still for `MARQUEE_HOLD` (1.5 s) showing its start. Then every `MARQUEE_STEP` (0.2 s) it drops its first character, `SetText(text:sub(i))`. At the end it wraps round through a three-space gap back to the start, and holds again.
  - The existing truncation still handles the right edge.
  - It needs no new API, no clipping and no new frames.
  - This is the design `docs/later.md` already argued for.
- **Whether a line fits** is decided by comparing `FontString:GetUnboundedStringWidth()` with the line's slot width.
  - `GetUnboundedStringWidth` is verified present on build 1.60.1.69913 in `SimpleFontStringAPIDocumentation.lua`.
  - **The slot width is worked out from the dash geometry and the dash frame's explicit size**, never read off the FontString, which only inherits its size (the rule this project learned twice).
- **Ruling:** the marquee rides the dash's existing `OnUpdate`. No new timer.
- **Ruling:** a line restarts from its beginning whenever its text changes, for example on a step advance, so the player never sees the middle of a new name first.
- Pure logic lives in a pure module so it is testable on the desktop. **Ruling:** that module is `GoblinPS/Marquee.lua`. It is state in, text out: `Marquee.New(text, fits)`, and `Marquee.Advance(m, dt)` returns the text to show.

## 2. The settings panel

Opened by the gear, which today says "Settings are not built yet." `/gps settings` opens it too.

- **Ruling on the look:** a plain panel in the gadget palette (`W.Panel`, body and brass), with **no new art** this round. The code for the panel belongs to this plan; the art is Codex's, and nothing has been asked of Codex. A dressed panel goes on `docs/later.md`.
- **Ruling on placement:** a separate window centred over the planner, one strata above it, closed by its own Close button and by Escape (it goes on `UISpecialFrames`). Closing the planner closes it too.
- **Ruling on controls:** no Blizzard templates, so there are no sliders. Each number gets a `–` / `+` pair of `W.Button`s and a value label. Every value is clamped to its range.

### Settings it holds

| Setting | What it does | Default | Range, step |
|---|---|---|---|
| Hearthstone | Use it only when it saves at least N minutes. 0 means "whenever it is faster". The same store as `/gps hearth`. | 5 min | 0–30, 1 |
| Ground arrival | Yards from a walk/ride step's target that count as arrived | 40 | 10–200, 10 |
| Flight arrival | The same, for a flight's landing | 150 | 50–500, 25 |
| Boat, zeppelin and tram arrival | The same, for the far dock | 800 | 100–1000, 50 |
| Hearthstone arrival | The same, after the hearth | 300 | 100–1000, 50 |

- **Ruling:** there is one "boat, zeppelin and tram" value, not three. They are the same kind of arrival (you step off at a dock), and three near-identical rows would crowd the panel.
- **Ruling on the ranges:** the owner thinks 800 is too high. The floor of 100 yards is there because a transport's arrival is judged when it lands you somewhere, and the dock coordinates are still estimates in places (the checklist lists docks not yet measured). A radius tighter than the error in the data would stop the trip from ever advancing. The panel says so in one dim line under that row.
- **Ruling on the default:** it stays at 800 until a dock is measured in game. Changing a default on a hunch is exactly the unverified promotion this project refuses.
- A **Reset to defaults** button resets all five.
- **Storage:**
  - Hearthstone keeps `GoblinPSDB.hearthSaving`.
  - Arrivals go in `GoblinPSDB.arrive = { ride, fly, transport, hearth }`. `Prefs.Init` repairs a missing or out-of-range value to its default.
  - `Trip.lua` stays pure. `Trip.Check(step, state)` reads `state.arrive[kind]` when given and falls back to `Trip.ARRIVE`. The dash hands it the player's radii, with `transport` fanned out to `zeppelin`, `boat` and `tram`.
- **One honest line on the panel:** "On this beta build, settings last until you reload: the client does not load saved data yet." CLAUDE.md's rule is to say plainly what does not work. The line comes out when a build loads saves again.

### About

- "GoblinPS", its version read from the TOC via `C_AddOns.GetAddOnMetadata(addonName, "Version")`. That function is present on this build (`AddOnsDocumentation.lua`, used by `Blizzard_AddOnList`). The call goes through `API.lua`.
- The tagline "Accuracy not guaranteed. No refunds."
- **Feedback: Ruling:** a line reading "Feedback: a GitHub page is coming soon." It is driven by one constant, `Settings.FEEDBACK_URL = nil`. When that is set, the line shows the address instead.
  - The owner said the page does not exist yet and did not want it made. So no URL is printed, not even the repository's, and nothing is created.
- **Ruling:** in-game text cannot be clicked open. When the URL exists, it will show in an EditBox the player can select and copy, the usual addon pattern. That is built now behind the nil constant, so it is tested.

## 3. A narrower drop-down

- The results list's width becomes the widest possible row label plus padding. It is measured once at build with `GetUnboundedStringWidth` over every destination label the search can offer: every zone name, and every flight stop's short name with "  (flight stop)".
- It is capped at the geometry's `results_list` width, and its left edge stays at the geometry's left.
- **Ruling:** only the drop-down narrows. The search box keeps its geometry width: it is Codex's three-slice art sitting in a socket of the frame, and the dropdown button sits against its right end.
- **Ruling:** measuring from the real font at build time, not a hand-typed pixel number, keeps "no coordinate hand-typed in Planner.lua" true. The widest name is data, and the font decides its width.

## Out of scope

The skull badge, dressed art for the settings panel, per-transport arrival values, and changing any default.

## Tests (desk)

- **Marquee:**
  - holds, then steps one character at a time;
  - wraps round through the gap;
  - restarts on new text;
  - never moves text that fits.
- **Dash:**
  - a long step line scrolls under `OnUpdate`, a short one does not;
  - fit is judged from the geometry width, not the FontString's.
- **Settings:**
  - the gear opens it; `/gps settings` opens it;
  - Escape and Close close it;
  - every `–` / `+` changes its value and clamps at both ends;
  - Reset restores all defaults;
  - the hearth row and `/gps hearth` share one value;
  - an arrival change reaches `Trip.Check`, for example a ride step 30 yards away advances at 40 and not at 20;
  - `Prefs.Init` repairs hostile values;
  - the About version comes from `API`;
  - the feedback line reads "coming soon" with no URL and shows the URL when the constant is set.
- **Drop-down:**
  - the list is no wider than the widest label plus padding, and no wider than the geometry;
  - its left edge is unchanged;
  - every row still fits it.

## In game (to the checklist)

- The gear opens the panel, and every row works.
- The panel looks decent without art, or the owner asks Codex for some.
- A long step line scrolls smoothly and a short one holds still.
- Lowering the transport arrival changes when a zeppelin trip advances.
- The drop-down hugs the longest name.

## Rulings (all of them, for the morning)

1. The marquee is a character window on the dash's existing OnUpdate, in a pure `Marquee.lua`.
2. The marquee restarts on new text.
3. The settings panel is plain, with no new art this round.
4. The panel is its own window over the planner, closed by Close and Escape.
5. Numbers use `–` / `+` buttons, not sliders.
6. One shared boat/zeppelin/tram arrival value.
7. Arrival floors, with the transport floor at 100 yards and the reason stated on the panel.
8. The 800-yard default stays until a dock is measured.
9. The panel says settings last one session on this build.
10. The feedback line is a placeholder driven by a nil constant, with no URL printed or created; a copyable EditBox is ready for when the URL exists.
11. Only the drop-down narrows, not the search box.
12. The drop-down's width is measured from the real font at build time.

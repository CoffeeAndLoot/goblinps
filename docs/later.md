# Later

Ideas worth doing that are not a plan yet. One line each, newest at the top.
A thing here is not a commitment -- it is a note so it stops living in a chat
log. When one graduates, it becomes a plan in `docs/superpowers/plans/` and
comes off this list.

- **Dress the settings panel with art.** Plan 9, 2026-09-22, built the panel
  plain: the gadget palette's body and brass, flat `-` / `+` buttons, no new
  parts, because the art is Codex's and nothing was asked of Codex. A dressed
  panel wants a frame, plate and button art like the planner's, and a
  geometry file for it, so its layout numbers come out of `Settings.lua` the
  way the planner's came out of `Planner.lua`.
- **The skull badge: mark the dangerous stop on the route strip.** Day 2,
  decided 2026-09-21 while designing plan 8. `icon-warning` (the skull) is
  drawn and waiting. The idea: at any stop in a zone above your level, the
  skull replaces that stop's travel icon, so the strip shows exactly where the
  risk is; the stop's tooltip still says how you get there, plus the level
  range. Until then the warning lives where it always has -- in amber, in the
  stop's tooltip and printed under the strip. It stays a warning, never a
  reroute.
- **Shorter step text on the dash:** run step names through
  Search.Label/ShortName before scrolling, so a line only scrolls when it is
  genuinely long. (Left over from the marquee entry when plan 9 built the
  scrolling.)

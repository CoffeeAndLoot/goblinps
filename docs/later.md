# Later

Ideas worth doing that are not a plan yet. One line each, newest at the top.
A thing here is not a commitment -- it is a note so it stops living in a chat
log. When one graduates, it becomes a plan in `docs/superpowers/plans/` and
comes off this list.

- **The skull badge: mark the dangerous stop on the route strip.** Day 2,
  decided 2026-09-21 while designing plan 8. `icon-warning` (the skull) is
  drawn and waiting. The idea: at any stop in a zone above your level, the
  skull replaces that stop's travel icon, so the strip shows exactly where the
  risk is; the stop's tooltip still says how you get there, plus the level
  range. Until then the warning lives where it always has -- in amber, in the
  stop's tooltip and printed under the strip. It stays a warning, never a
  reroute.
- **Scrolling text on the dash unit**, like the LED/LCD displays on early car
  radios: when a line is too long for its opening, creep it sideways instead
  of truncating. Asked for 2026-09-20 after the first good client run showed
  all four lines cut ("Walk to Orgrimmar's fro..."). Both APIs are verified
  present on build 1.60.1.69913: `SetClipsChildren` (Blizzard's own
  ObjectiveTracker uses it) and `GetStringWidth`. Two designs considered:
  pixel scroll inside a clipping frame (smooth, but whether
  `SetClipsChildren` clips a frame's own regions as well as its child frames
  is unverified -- put the FontString on a child frame and it cannot matter),
  or a character window advanced one step at a time, `SetText(text:sub(i))`,
  letting the existing truncation handle the right edge. The second needs no
  new API, no new frames and no clipping, is what those radios actually did,
  and is testable end to end on the desktop -- which matters here, since the
  fault that reached the client on 2026-09-20 was one the harness could not
  see. The dash already runs an `OnUpdate`, so a marquee costs no new timer.
  Running step text through `Search.ShortName` is the cheap complement: cut
  what is needlessly long, scroll only what is genuinely long.

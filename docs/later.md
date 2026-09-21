# Later

Ideas worth doing that are not a plan yet. One line each, newest at the top.
A thing here is not a commitment -- it is a note so it stops living in a chat
log. When one graduates, it becomes a plan in `docs/superpowers/plans/` and
comes off this list.

- **Clear the map pin on arrival and on Stop.** Asked for 2026-09-21. The dash
  moves Blizzard's single user waypoint forward at every step
  (`Core.PinStep` -> `C_Map.SetUserWaypoint`, which replaces rather than
  adds), but nothing ever removes it: after "Arrived." or the red stop
  button, the last pin and its on-screen arrow stay on the map. The calls
  exist on build 1.60.1.69913 -- `C_Map.ClearUserWaypoint` and
  `C_Map.HasUserWaypoint`, both in `MapDocumentation.lua`, and Blizzard's
  own `WaypointLocationDataProvider.lua` calls the clear -- and would go
  through `API.lua` like every other client call. The one catch: **clear
  only a pin that is still ours.** A player who drops their own waypoint
  mid-trip must not lose it when the dash finishes, so remember the last
  point `PinStep` set and compare it with `C_Map.GetUserWaypoint()` (also
  present, `MayReturnNothing`) before clearing. Hook it into `finish()` and
  into the stop path; Escape already routes through `OnHide`, which is the
  one place both end up. Unverified in game: whether the client clears the
  pin by itself when you reach it.
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

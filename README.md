# GoblinPS

A route planner for **WoW Forever**. Pick a destination and get the fastest
route from where you stand, using the flight paths this character has
discovered, boats, zeppelins, the tram and the hearthstone -- walking or
riding zone to zone through named crossings where nothing else reaches.
Forever has no flying, so travel is a real puzzle.

Accuracy not guaranteed. No refunds.

## Known limits on the current beta build

- **The beta client never loads saved data, for any addon.** Every session
  starts with no flight paths known, until you open a flight master's map --
  they are learned the moment you do. Settings changes and a trip in
  progress last only until you `/reload` or log out; they do not survive it.
  This is a client bug, not a GoblinPS choice, and GoblinPS will pick its
  saves back up by itself the moment a build fixes it.
- Many zone-crossing positions are still estimates, not yet walked and
  measured.
- A town only counts as enemy territory if it has the other faction's flight
  master, or has been marked by hand, so a route can still walk past a
  hostile camp that isn't marked.

## Using it

- `/gps` -- open the planner: a search box, the route drawn as a strip of
  badges (a tooltip on each), and Start Route.
- `/gps to <place>` -- print a route in chat.
- Start Route opens the dash: an arrow pointing at the current step, the
  distance and time left, advancing when you arrive and replanning when you
  stray. Only Stop ends a trip -- closing the window, arriving, or a reload
  never does.
- The gear (or `/gps settings`) opens the settings panel.
- Right-click the minimap button, or `/gps where`, for a copyable position
  line.
- `/gps minimap` -- show or hide the minimap button.
- `/gps hearth <minutes>` -- how much time the hearthstone must save before
  a route uses it.
- `/gps probe` / `/gps probe zones` -- check the flight path and zone-level
  data against the client.
- `/gps selftest` -- check textures and fonts.

## Install

Through the Wago app, or manually: unzip into
`World of Warcraft\_classic_beta_\Interface\AddOns\` -- the beta client
lives in `_classic_beta_`, not `_retail_`.

## Feedback

The comments on its Wago page.

## Licence

MIT.

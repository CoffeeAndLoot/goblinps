# GoblinPS

**The Goblin Positioning System, for WoW Forever.** Tell it where you want to
go and it works out the fastest way there from where you stand, then walks you
there step by step. No more alt-tabbing to a map site, no more riding the wrong
way out of the Barrens, no more running straight into an enemy town.

Forever has no flying, so getting across Azeroth is a real puzzle: which flight
paths does this character actually have, is the boat faster than the zeppelin,
is it worth burning the hearthstone? GoblinPS does that sum for you.

*Time is money, friend. Accuracy not guaranteed. No refunds.*

![GoblinPS: Less walkin'. More earnin'. A goblin trade prince presents the real planner, showing a route to Silverwind Refuge.](https://raw.githubusercontent.com/CoffeeAndLoot/goblinps/main/images/readme/goblinps-planner-demo.jpg)

[View the original planner capture](images/readme/planner.jpg).

## Why use it

- **Spend less time travelling.** Every route weighs the flight paths *this
  character* has learned, boats, zeppelins, the Deeprun Tram, your
  hearthstone, and walking or riding at your level's speed, and picks the
  quickest mix. It tells you how long the trip takes before you set off.
- **Never get lost.** Start Route turns the planner into a pocket navigator:
  an arrow that points at your next stop, the distance to it, and the time
  left. It moves on by itself when you arrive, sets the map pin for you, and
  plans again if you wander off course.
- **Stay alive on the way.** Zones above your level are flagged in amber, and
  routes go round known enemy towns instead of through the guards. Pick an
  enemy town on purpose and GoblinPS tells you what is waiting there.
- **Find shortcuts you did not know you were missing.** When a flight path you
  have not discovered yet would shorten the trip, the planner says which one
  and how much time it would save.

## See it in action

Plan the trip: search any town, flight stop or inn, or browse by zone. Each
badge on the strip is a leg of the journey, with a tooltip on each.

![An Alliance character in Northshire planning a route to Orgrimmar: eight legs by road and boat, about 30 minutes, with a warning that Orgrimmar's guards will attack](https://raw.githubusercontent.com/CoffeeAndLoot/goblinps/main/images/readme/in-game-planner.jpg)

Then follow the arrow. The dash shows where you are headed, how far, the next
steps, and how long is left.

![Follow the arrow. A goblin engineer presents the real GoblinPS dash: pick a place, get movin', and mind the red Stop button. Warranty void if eaten.](https://raw.githubusercontent.com/CoffeeAndLoot/goblinps/main/images/readme/goblinps-dash-demo.jpg)

<p>
  <img alt="The GoblinPS dash in the world: a green arrow toward the next stop, 945 yards to go, the next three steps and about 17 minutes left" src="https://raw.githubusercontent.com/CoffeeAndLoot/goblinps/main/images/readme/in-game-dash.jpg" width="560">
  <img alt="The dash up close: the arrow, the stop's name and distance, the next steps and the time left" src="https://raw.githubusercontent.com/CoffeeAndLoot/goblinps/main/images/readme/dash.png" width="280">
</p>

## Using it

- `/gps` opens the planner. Type a place, or use the ▼ button to browse your
  recent destinations and every zone. Start Route opens the dash.
- `/gps to <place>` prints the route in chat instead.
- Only the dash's Stop button ends a trip: closing windows or arriving never
  does.
- The gear opens the settings: how much time the hearthstone must save before
  a route uses it, how close counts as arriving, and how the dash's text
  scrolls.
- Right-click the minimap button, or `/gps where`, for a copyable position
  line.
- `/gps minimap` shows or hides the minimap button. `/gps help` lists the
  rest.

## Known limits on the current beta build

- **The beta client does not load saved data, for any addon.** Every session
  starts with no flight paths known until you open a flight master's map;
  they are learned the moment you do. Settings and a trip in progress last
  until you `/reload` or log out. This is Blizzard's bug, not a GoblinPS
  choice, and GoblinPS picks its saves back up by itself once a build fixes
  it.
- Many zone-crossing positions are still estimates, being walked and measured
  one by one.
- A town counts as enemy territory only if it has the other side's flight
  master or has been marked by hand, so a route can still pass a hostile
  camp nobody has marked yet.

## Coming later

Ideas on the workbench, not promises:

- **Quest routing:** pick a quest and get routed to it, the same way as to a
  town.
- **Saved routes for farming:** keep a loop you run often and start it with a
  click. This one waits on the client loading saved data again.
- **A skull on the strip** at the exact stop where a zone turns dangerous for
  your level.

## Install

Through the Wago app (search "GoblinPS"), or by hand: unzip into
`World of Warcraft\_classic_beta_\Interface\AddOns\`. The Forever beta
client lives in `_classic_beta_`, not `_retail_`.

## Feedback

Leave a comment on the Wago page: https://addons.wago.io/addons/goblinps

## Licence

MIT.

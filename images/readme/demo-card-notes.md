# Goblin README demo cards

Two promotional JPEGs combine generated character illustration with existing
product captures. `planner.jpg`, `dash.png`, and the in-game screenshots remain
unchanged. README keeps the in-game captures and links to the original planner.
No product UI, features, runtime textures, or routing behavior was changed.

- `goblinps-planner-demo.jpg`: Gallywix-inspired trade prince, coins, machinery,
  and a literal cowbell. “Less walkin'. More earnin'.”
- `goblinps-dash-demo.jpg`: Gazlowe-inspired goblin mechanic presenting the dash.
  “Save the scenic detour for somebody on salary.” “Warranty void if eaten.”

These are stylized character renditions, not official portraits or endorsements.
The new sales copy is original GoblinPS flavor, not attributed character dialogue.
The familiar “Time is money, friend” comes from the project's existing tagline.

## Production

Built-in image generation produced the two background paintings:

- Trade prince: `031fd9e8-cf36-4e7e-97c9-4efbe3f5c706`.
- Engineer: `db465799-aa8e-4148-b69d-de3d37c1298e`.

Prompt direction: landscape 3:2 Warcraft painterly promotional art, no lettering
or invented UI; dark green workshop negative space for real captures; worn
brass, green machinery glow and warm rim light. The trade prince is a corpulent
green goblin tycoon with purple coat, gold jewelry and a cigar at left. The
mechanic is a green goblin engineer with goggles, tools and a wrench at right.
The trade-prince prompt included a single brass cowbell as the owner's joke.

Reference for trade-prince characterization:
https://worldofwarcraft.blizzard.com/en-us/news/2299939

Authorized Pillow finishing removes only the edge-connected green backdrop
from copies of the captures, scales them uniformly, and adds crisp typography.
Product text is not regenerated or retouched. The screenshot truncation remains
as captured. Full-canvas paintings are saved as `trade-prince-background.jpg`
and `engineer-background.jpg` for reproducible composition.

Run `python images/readme/build_demo_cards.py` (Pillow and numpy required).
Outputs are 1536x1024 JPEGs; they are documentation graphics, not addon TGA/BLP
assets. Both cards were visually checked for framing, readable text, and intact
product screenshots. The original screenshots remain authoritative for the UI.

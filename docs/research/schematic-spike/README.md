# Schematic map spike (throwaway), 2026-09-19

Question: can the planner's schematic world map be **generated from game data**
instead of hand-drawn? Answer: yes, well enough to build on. `preview_green.png`
is the first output; `schematic_spike.py` made it (needs numpy and Pillow, and
the CSV cache from `python tools/build_graph.py`).

How it works: each zone is a blob around the centre of its `UiMapAssignment`
rectangle, sized by that rectangle (a weighted Voronoi split decides which zone
owns a pixel); the landmass is the smooth union of the blobs plus low-frequency
noise for the coast; a pad of land is grown under every flight node so no pin
stands in the sea. Each continent gets one uniform world-to-texture transform,
so flight nodes and docks land where they really are, with no hand placement.
Cities are left out of the zone split by name.

Findings for plan 2:

- Output is greyscale masks (land, border, coast, Horde zones, Alliance zones).
  Shipping five 1024x512 textures is about 10 MB uncompressed; bake land +
  border + coast into one texture and keep the two faction overlays at half
  size: about 3 MB.
- The same transform must be emitted into the Lua data so the addon can place
  pins and the route line: generate `sx, sy` per node, dock and zone centre.
- Labels collide in the south of the Eastern Kingdoms; in the addon they are
  FontStrings and need a few hand offsets.
- Zephras Isle and the Darkspear Islands are off the two continents and do not
  appear. Faction zone lists are hand-written in the script.
- Not decided: whether the user likes generated blobs or wants something closer
  to real coastlines.

This folder is a record, not shipped code. The real generator, if the approach
is accepted, is written fresh in plan 2.

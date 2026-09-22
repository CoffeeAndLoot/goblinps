# GoblinPS planner: move Close and the gear (brief for Codex, 2026-09-21)

The owner looked at the planner in the client and asked for two buttons to move. Nothing needs redrawing: this is placement only, in the `wide` section of `images/parts/planner-geometry.json`.

**Please make the change in `images/parts/build_planner_geometry.py`, then re-run it.** Do not hand-edit the JSON. The script writes the file, so a hand edit would be undone by its next run.

## The two moves

1. **Close (`close_button`) sits on the big rivet in the frame's upper-right corner.** The rivet is the domed bolt head to the right of where Close sits now.
   - Measured on `planner-frame-wide.png`: the rivet's centre is at about **(1502, 222) px**, which is cx 0.939, cy 0.217.
   - Please take its exact centre from the art. Centre Close on it, so the button reads as the bolt head.
   - Keep `r` as it is unless the art calls for otherwise. The button may cover the rivet completely; that is intended.
2. **The gear (`gear_button`) moves to the bottom-right corner plate**, the large flat brass plate at the frame's lower-right corner.
   - Measured: the clear flat brass sits at about **(1483, 880) px**, which is cx 0.927, cy 0.859.
   - It must not cover either of the plate's two small rivets (at about (1437, 930) and (1535, 817)).
   - It must not touch `tagline_plate` (left 0.7, right 0.9, top 0.8887, bottom 0.9668). At r 0.02375 (38 px) the gear spans about 1445 to 1521 px across and 842 to 918 px down, so check it clears the plate's top-right corner.
   - Please choose the exact spot on the art.

Both buttons stay circles in the file's own units: cx and cy as fractions of the canvas, r as a fraction of the canvas **width**.

## Leave alone

- The `tall` section, byte for byte.
- Every other `wide` key.
- `dropdown_button` stays beside the search box.

## Check before you finish

- [ ] Only `wide.close_button` and `wide.gear_button` changed. Everything else in the JSON is byte-identical.
- [ ] Close is concentric with the upper-right rivet, within 2 px.
- [ ] The gear sits wholly on the corner plate's brass, covers no rivet, and clears `tagline_plate`.
- [ ] Fresh wide previews from the script show both buttons in their new places.
- [ ] A note in `QUESTIONS.md` giving the final cx, cy and r for both.

Claude then regenerates `GoblinPS/Data/Art.lua` with `tools/make_art.py`, and the addon moves both buttons with no code change: `Planner.lua` places both from the geometry. Close still closes and the gear still says "Settings are not built yet."

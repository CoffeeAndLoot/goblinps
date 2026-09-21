# Current handoff: approved mockup layout (2026-09-21)

This section supersedes the historical decisions below. See
`docs/art-parts-brief-planner-mockup.md`. No source artwork was redrawn.

- Wide has exactly the fourteen requested regions plus canvas. From, Here,
  layout toggle, side panel and tools alias are removed from wide only.
- Tall is retained literally, including JSON whitespace, by the builder.
  Its source art and historical previews stay unchanged and unused.
- Title, tagline, gear and Close deliberately mount on brass. Every other
  region, including the dropdown square, clears the actual frame alpha.
- The backdrop remains an independent cover-scaled, center-cropped insert
  inside `screen`; it does not stack at the full canvas origin.
- `strip_track` left/right are endpoint badge CENTERS; its vertical center is
  the badge and connector center. The screen reserves 80 source pixels at each
  end for the full 144px sprite (96px visible ring). Do not inset twice.
- Eleven stops have 113px center spacing versus 96px visible rings. All remain
  visible. Names disappear when crowded; stops do not scroll. Larger counts
  eventually require smaller badges. Eleven is the checked long-route case.
- Marker sprites remain 1.5 times their visible ring diameter. Node diameter
  and label gap are unchanged. `line_thickness` is now 0.02 of canvas width and
  means FULL texture height, including glow margins. The previous 0.003 made
  the center stroke nearly invisible. Preserve texture aspect ratio, tile at
  that scale, and crop only the final tile. Never stretch to a leg's length.
- Solid and dashed edges match byte-for-byte. Three repeats were visually
  checked in `_planner-line-seams.png`: steady solid glow and evenly spaced
  dashes, including seams. No source texture repair is needed. First connector
  is solid, later ones dashed; glowing dots sit at leg midpoints.
- Total and warning have separate text-center slots below badges and names.
  Search results end above both, so the warning stays visible while searching.
  Start Route is centered below the screen, clear of the brass. Idle status
  lines replace the strip; they are never drawn over an active route.

Run `python images/parts/build_planner_geometry.py` to reproduce the geometry
and fresh wide previews: assembled, geometry overlay, search-open, idle,
eleven stops, and line seams. Checks cover exact wide keys, normalized values,
frame alpha, footer separation, badge spacing, line edges and tall preservation.

**Integration checker mismatch:** `tools/check_art.py` still uses the previous
shared wide/tall allow-list. Its 47 texture checks pass; geometry reports six
schema mismatches: new `notes_line`/`known_line` and removed `from_box`,
`here_button`, `layout_button`, `side_panel`. The implementation agent needs
to update that allow-list for the approved design. Do not restore the deleted
controls to silence it. No runtime Lua, shipped TGA or tools were changed in
this art handoff. The new layout has not been verified in game.

---

# Historical planner handoff: superseded decisions

For `docs/art-parts-brief-planner.md`. The existing art was already complete;
`planner-geometry.json` and the six `*-geometry-*` / `*-search-proof` previews
are new. No existing source PNG, TGA, or addon code was changed.

## Answers to the four layout questions

1. **Long routes:** keep the detailed step list visible for every route, with
   scrolling, step numbers, travel times and secondary detail lines. It sits
   beside the strip in wide mode and below it in tall mode. The strip is a
   horizontally scrollable overview of all nodes, initially showing the start;
   selecting a step should bring its node into view. Never hide required
   directions in tooltips. Preview rows and the scrollbar are illustrative;
   Claude still needs to implement scrolling and synchronized selection.
2. **Close and toggle:** the existing `close.png` is the crossed-wrench X seen
   in the old mockup. Use it for Close with `close-hover.png` and a Close tooltip.
   Keep the gear for settings. Put a clearly labeled Wide/Tall button at the
   upper left, using existing button states. No independent tools action is
   defined, so no new wrench art is needed. The requested `tools_button` key is
   retained as an explicit alias of `close_button` for schema compatibility;
   **do not instantiate a second button at that location.** A new
   `layout_button` rectangle is present in both layouts.
3. **Two searches:** both are always visible. From defaults to where you stand;
   Here restores that default. Wide mode uses one row, tall uses two. From and
   To placeholders/labels must remain visible enough to distinguish the fields.
   The shared results list overlays the screen while either field is active;
   it spans the search area rather than being restricted to the focused field.
4. **Hint and total:** both have dedicated footer slots. Total is left of GO.
   The amber hint sits below total in wide mode and above the footer in tall.
   Long warnings may wrap or use a tooltip, but must never cover GO. `_line`
   coordinates specify vertical centering slots, not hard clipping heights.

## Geometry contract

- Both layout objects have identical keys. Canvas dimensions are source pixels;
  all placement coordinates and strip lengths are normalized to 0–1.
  The brief's “every number” rule excludes its own canvas dimension arrays.
- X uses layout width; Y uses layout height. Radii and all three strip lengths
  use **layout width**, including in tall mode. Keep the canvas aspect ratio.
- `node_diameter` means the visible ring diameter. Existing markers have a
  128px visible ring on a 192px source canvas, so their complete sprite box is
  1.5 times that diameter. `label_gap` starts below the visible ring.
- Source frame art is placed at the full canvas origin. Title, tagline and
  controls are independent inserts, positioned by their complete sprite boxes.
  Input/button art needs fixed end caps; text needs interior padding, not an
  anchor on the decorative outside edge. Preview text is illustrative only.
- `screen-backdrop.png` is an **independent insert**, never a same-canvas layer.
  Uniformly scale it to cover `screen`, center-crop overflow, and clip exactly
  to that rectangle. This preserves its scenery proportions in both layouts.
  The loss of scenery at the sides is intentional: it is decorative wallpaper.
- Tile `planner-panel` within the interior opening only. The source frame has
  tiny transparent seams; an unconstrained flood fill can leak outside it.
  The preview builder uses a bounded interior polygon to avoid that.
- The list panel can use the existing panel texture plus a dark tint and thin
  border. It needs no newly drawn decorative housing.
- There is no map-navigation content implied by the backdrop. Route nodes and
  all functional text remain live addon elements.

## Verification and remaining integration

Run `python images/parts/build_planner_geometry.py` (Pillow required). It writes
the geometry and six proofs, checks both key sets and normalized ranges, and
checks all content rectangles against the actual source frame alpha. Existing
art remains untouched. The ordinary assembled previews show closed search;
the search proofs show the overlay open.

These are proposed placements verified against art pixels, not coordinates
measured from the old simplified mockups. Use the new geometry previews when
implementing this complete layout. Review at 650x416 and 384x600, retaining
readable runtime font sizes rather than blindly scaling source-preview fonts.
No in-game check has been performed. Scrolling, settings behavior, live text,
texture sizing, and frame-size timing remain Claude's integration work.

Existing TGA exports remain applicable because no source art changed. PNG
review composites are not runtime textures; do not bake their sample text into
the addon. No image-generation call or BLP conversion was needed for this task.

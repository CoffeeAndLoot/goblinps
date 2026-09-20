# GoblinPS artwork and texture-conversion handoff

Claude: the requested art set is complete. Please use the existing artwork and
respect the current repository's distinction between source art and shipped textures.
This handoff describes Codex's art work, not a completed UI implementation.

## What was made

The approved visual direction is worn brass, dark riveted iron, green glass and a
bright navigation arrow, with upper-left lighting and a Warcraft goblin aesthetic.

- `images/goblinps-app-mockup.png`: full app concept, including the left navigation
  dash and right planner with a settings gear.
- `images/goblinps-icon.png`: standalone arrow/compass project icon.
- `images/parts/`: all **39 parts** specified by `docs/art-parts-brief.md`:
  five dash layers/parts, sixteen planner/control parts, and eighteen route-strip
  markers/lines. Every part has a PNG source at the brief's dimensions.
- `_contact-sheet.png`: the complete named inventory.
- `_planner-wide-assembled.png`, `_planner-tall-assembled.png` and
  `_dash-assembled.png`: assembly examples. They are reference pictures, not
  textures to use as the whole window.

The mockup was used as a style reference, not cropped into UI pieces. The wide and
tall planner frames were generated independently. Title, tagline and compass
lettering are intentionally baked into their designated parts. Other labels,
destinations, distances and button text must be drawn by the addon.

## How the artwork was finished

The built-in image generator produced the detailed artwork. It did not reliably
honor exact canvas dimensions and sometimes painted a checkerboard instead of
producing transparency. The user explicitly authorized Python/Pillow finishing.

That finishing work removed painted backgrounds, supplied real alpha, normalized
canvas sizes, aligned the dash layers, and made the arrow silhouette symmetric.
Button hover/pressed/disabled states were derived from one base, preserving their
alpha outline. Route markers share the same outer brass ring. Simple periodic panel
grain, route lines, line dot and current-node glow were constructed deterministically.
The input field uses art from the separately generated button, with fixed end caps
and a uniform stretchable middle.

The final PNGs are the editable source of truth. `generation-sources.json` records
generator output IDs for the planner/marker batch; it is provenance, not a complete
rebuild pipeline for the image-generation and finishing steps.

## Requested TGA/BLP conversion

The user requested TGA **or** BLP. Codex supplied **TGA**; no BLP files were made.

`images/parts/export_tga.py` converts all 39 PNGs to:

- Uncompressed TGA image type 2.
- 32-bit BGRA storage with 8-bit straight alpha.
- Power-of-two canvases, chosen conservatively for client compatibility.
- Unchanged source pixels at the top-left, with transparent padding on the right
  and bottom. This authoring export does not resize or stretch artwork.

Run from the repository root, with Pillow installed:

```powershell
python images/parts/export_tga.py
```

The exporter validates PNG sizes/modes, checks the TGA header, reopens every output,
and compares its RGBA bytes exactly with the padded source. It also writes
`texture-manifest.json`, containing `art_size`, `texture_size`, and `tex_coords` in
**left, right, top, bottom** order.

Examples for these authoring exports:

| Part | PNG art | TGA canvas | Texture coordinates |
| --- | --- | --- | --- |
| Wide frame | 1600x1024 | 2048x1024 | 0, 0.78125, 0, 1 |
| Tall frame | 1024x1600 | 1024x2048 | 0, 1, 0, 0.78125 |
| Route marker | 192x192 | 256x256 | 0, 0.75, 0, 0.75 |
| Main button | 768x192 | 1024x256 | 0, 0.75, 0, 0.75 |
| Screen backdrop | 1600x640 | 2048x1024 | 0, 0.78125, 0, 0.625 |

For a padded route marker, the corresponding crop is
`texture:SetTexCoord(0, 0.75, 0, 0.75)`. The API exists in the pinned Forever UI
source. This is not an in-game loading test of the supplied textures.

## Important current repository policy

After the original art delivery, the repository was updated to treat
`images/parts/*.tga` as **ignored, regenerable authoring exports**. The complete
uncompressed set is approximately 49 MiB and is much larger than required at the
actual UI display sizes. **Do not copy that full-resolution set directly into the
addon or restore it to version control.**

Ship appropriately downscaled derivatives under `GoblinPS/Media/`, built from the
PNGs by a tool under `tools/`. Choose resolution per part and recompute padding/UVs
for those shipped files; the authoring manifest is not automatically their manifest.
Preserve shared alignment and button-state masks during resizing.

At this handoff, `tools/make_icon.py` already builds the separate 256x256 project
icon at `GoblinPS/Media/icon.tga`. That icon tool is existing repository work; it
is not a general exporter for the 39-part UI set. No complete production-size UI
texture builder was found in `tools/` during this handoff review. Recheck the tree
before implementing one, since another agent may be working in the repository.

## Assembly details worth preserving

- Dash stack: screen, compass, arrow, body. The three 1024px layers share centre
  (512,512). The glass radius is 312px, overlapping under the bezel. The compass
  is approximately 570px in diameter.
- Arrow: 512x512 source, up-facing, rotate about (256,256). It includes generous
  glow padding. The example renders the full arrow canvas at 461x461, so the
  visible solid arrow is roughly 245px wide. Do not confuse visible-art width
  with canvas width when choosing its UI size.
- ETA plate: separate blank 512x128 part.
- Markers: 128px artwork circle centred at (96,96) on each 192x192 PNG.
- Input field: 48px source end caps; uniform middle intended for stretching.
- Planner panel tiles in both axes; solid/dashed route lines tile horizontally.
- Use `screen-backdrop`, the current brief's name. The old `screen-map` mention in
  its final checklist is stale. This image is wallpaper, not navigable geography.
- Clip/tile the inner panel within the window silhouette. Preserve the transparent
  openings in the body and planner frames. Keep the functional plain-colour fallback.

## Validation and remaining work

Codex checked dimensions, RGBA modes, TGA headers and exact conversion round trips;
transparent frame apertures; matching state alpha; marker bounds; tile seams; and
the uniform input middle. Every part was visually reviewed against magenta and
white backgrounds, with assembled dash/planner and tiling previews.

During this handoff, the repository's existing checker was run again:

```powershell
python tools/check_art.py
# 39 pass, 0 with problems, 0 not drawn yet
```

Still required: production-size texture builds, UI wiring, and verification in
the actual Forever client. Check loading, alpha edges, small-size legibility,
UI scaling, arrow/compass rotation and clipping, button states, and missing-art
fallbacks. Neither the art previews nor the desktop checks establish in-game success.

Read `images/parts/README.md` for the full asset notes and prompt summaries, plus
the current project instructions and client research before touching runtime code.

## Original art commits

- `17a42be`: project icon.
- `94f7cd6`: full app mockup with arrow and gear.
- `3d18471`: first five dash parts and previews.
- `53edcbc`: complete art set, TGA exporter, manifest and reviews.

Later repository changes supersede the original commit's decision to track the
large TGA files. Follow the current PNG-source/derived-runtime policy above.

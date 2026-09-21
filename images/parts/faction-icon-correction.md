# Faction icon correction

The user flagged the original faction buttons as incorrect. The original brief
requested invented faction-inspired designs; this correction supersedes that
direction for `icon-horde.png` and `icon-alliance.png`.

Built-in image generation was used to replace the trident-like Horde crest
with a recognizable red Horde insignia, and the generic blue lion with a gold
Alliance lion on royal blue. These are generated renditions, not extracted
Blizzard texture files or guaranteed exact vector reproductions.

Prompt direction: preserve a front-facing worn brass button, upper-left light,
and transparent margins; change the center to the recognizable classic faction
emblem, with no text. Horde: red tribal silhouette with central diamond and
hooked sides, not a trident. Alliance: left-facing gold heraldic lion on blue,
not a generic mascot. Generation IDs are in `generation-sources.json`.

Authorized Pillow finishing inserted the generated centers into the original
brass rims. Both source PNGs remain 192x192; their alpha channels are byte-for-byte
unchanged. Authoring TGA exports were rebuilt and round-trip verified; current
planner geometry previews were refreshed. `_faction-icons-corrected.png` shows
the final pair. Older contact sheets and original concept mockups are historical
and may still show the previous symbols.

All 47 checks in `tools/check_art.py` pass. No addon runtime textures or Lua were
changed; regenerate the shipped textures during integration. No in-game check
was performed.

### Task 6: Documents

**Files:**
- Create: `docs/art-specs.md`
- Modify: `docs/manual-test-checklist.md`, `CLAUDE.md`, `docs/superpowers/specs/2026-09-19-goblinps-design.md`

- [ ] **Step 1: Write `docs/art-specs.md`**

```markdown
# GoblinPS art specs

The addon works with no art at all: every surface is a flat colour in the
Goblin Gadget palette. Art is laid over those colours, so any piece can arrive
at any time, from an artist or an image generator, without a code change
beyond dropping the file in. The schematic map is NOT art: it is generated
from game data (`docs/research/schematic-spike/`), so its pins stay exact.

Palette: brass `#B8873B`, body `#3B2E1C`, oily steel `#1C1A14`, screen green
`#081F0F` with `#70E08A` text, amber `#F0B54A`, hazard orange `#E0701C`.
Look: a dented brass goblin gadget, rivets, hazard-stripe trim, a green CRT
screen. Slightly battered, hand-built, not sleek.

## Wired today

| Piece | Drop the source at | Spec | Then run |
|---|---|---|---|
| Addon icon (TOC, minimap button) | `images/icon-source.png` | Square PNG, 1024x1024 or larger, subject centred with a margin: it is cropped to a circle. A brass gadget face or dial with a green screen and an amber route reads well at 20 pixels. No text. | `python tools/make_icon.py` |

## Wanted next (not wired yet; plan 3 and later hook them up)

| Piece | Spec |
|---|---|
| Window frame, wide | PNG with transparency, 1024x512 canvas holding a 660x400 frame: brass border about 12 px, rivets at corners and along edges, a hazard-stripe strip across the top, the middle fully transparent. |
| Window frame, tall | Same style, 512x1024 canvas holding a 390x600 frame. |
| Screen glass | 512x512 PNG, mostly transparent: faint scanlines, a soft corner glare, slight vignette. Tiled or stretched over the green screen. |
| Button face | 128x64 PNG, brass plate with a stamped edge, plus a pressed variant. |
| Dash unit body | 512x256 PNG with transparency, a small dashboard device with a suction-cup mount. |

WoW loads TGA or BLP with power-of-two sides. Source art stays PNG under
`images/`; a tool converts it into `GoblinPS/Media/`.
```

- [ ] **Step 2: Add this section to the end of `docs/manual-test-checklist.md`**

```markdown
## Planner window (plan 2): check every line in BOTH layouts

Restart the game first: the TOC changed.

- [ ] `/gps selftest` ends "Self-test passed."; record any FAIL line here
- [ ] A GoblinPS button is on the minimap ring with the dial icon; its tooltip
      has three lines and "May explode."; dragging moves it round the ring and
      the position survives `/reload`; `/gps minimap` hides and shows it
- [ ] The addon compartment (top right of the minimap) lists GoblinPS with the
      icon, and clicking it opens the planner
- [ ] `/gps` opens the window: brass border, orange strip, title and tagline,
      From and To boxes, a green screen, a step panel. Escape closes it
- [ ] The green screen says "Flight paths known: N" with the right N
- [ ] Click To and type "und": a list drops under the box with Undercity;
      click it; the steps, per-step time and fare, total and hint appear
- [ ] Press Enter with text in To: the first match is taken
- [ ] Empty the To box and click it: recent destinations are offered
- [ ] Type a start in From and pick it: the route re-plans from there;
      "Here" goes back to where you stand
- [ ] GO with a flight or ride first step: Blizzard's map pin and the
      on-screen arrow appear at the step's target, and chat says "Pin set"
- [ ] GO when step 1 is the hearthstone: chat says to use it; no pin
- [ ] The Tall/Wide button flips the layout; nothing overlaps, nothing is cut
      off, the steps stay; the choice survives `/reload`
- [ ] Drag the window; its position survives `/reload`
- [ ] Open a flight master's map with the planner open and a route showing:
      if paths were learned, the route and "Flight paths known" update
- [ ] `/gps to barrens` bound at the Crossroads inn: "Hearthstone to
      Crossroads" and no "Ride to The Barrens"
- [ ] Bound in Brill, Razor Hill, Goldshire, Kharanos, Dolanaar or Bloodhoof
      Village: no "unknown inn" line. Stand in the inn and compare
      `/run print(C_Map.GetBestMapForUnit("player"), C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit("player"),"player"):GetXY())`
      with the row in `GoblinPS/Data/Inns.lua`
- [ ] Any other "Hearth: unknown inn (...)" line seen: add the name to
      `GoblinPS/Data/Inns.lua`
```

Also, in the existing `## Routing core (plan 1)` section, tick the two items that begin `- [ ] Known wart for plan 2:` and `- [ ] Inns in towns with no flight master` by changing `[ ]` to `[x]` and appending ` (done in plan 2)` to each item's last line.

- [ ] **Step 3: Update `CLAUDE.md`.** Replace the paragraph that starts `**Status:` with:

```markdown
**Status: routing core and planner window built (plans 1 and 2).** `/gps`
opens the planner; `/gps to <place>` prints a route in chat. Next: plan 3,
the schematic map on the green screen (approach proven in
`docs/research/schematic-spike/`), then plan 4, the dash unit. The design is
`docs/superpowers/specs/2026-09-19-goblinps-design.md`. Write each plan after
the one before it has been used in game.
```

In the "Intended layout" code block, replace the line that lists `Trip (pure arrival rules), planner window, dash unit, schematic map, Core` with these lines:

```
GoblinPS/Known.lua, Prefs.lua  # pure: learned flight paths; account preferences
GoblinPS/Data/Inns.lua       # HAND-WRITTEN: hearthstone bind names Search cannot find alone
GoblinPS/Widgets.lua         # plain controls in the gadget palette; NO Blizzard frame templates
GoblinPS/Planner.lua         # the window; one set of widgets, ApplyLayout moves them
GoblinPS/MinimapButton.lua, SelfTest.lua, Core.lua
test/fake_frames.lua         # fake frame API: smoke-tests OUR window code, not Blizzard's
```

Under "Rules that are easy to break", replace the bullet that begins `- Every constructor that leans on a Blizzard template or atlas` with:

```markdown
- The window uses **no Blizzard frame templates**: plain frames and colour
  textures, so a template renamed by a beta patch cannot break it. Art is
  laid over the colours (`docs/art-specs.md`); a missing texture must leave a
  working window. `/gps selftest` checks fonts, stock textures and APIs.
```

- [ ] **Step 4: Update the spec.** In `docs/superpowers/specs/2026-09-19-goblinps-design.md`:

Replace the status paragraph at the top (from `Status:` to the blank line after it) with:

```markdown
Status: **approved by the user on 2026-09-19.** Implemented in four plans
under `docs/superpowers/plans/`: 1 routing core (done), 2 planner window,
3 schematic map, 4 dash unit. Each is written after the one before it has
been used in game. Update this file whenever behaviour changes.

```

In decision 7, replace the sentence `Falls back to stock Blizzard templates if a texture is missing.` with `The window uses no Blizzard frame templates at all: plain frames in the palette's flat colours, with art laid over them (docs/art-specs.md), so a missing texture or a renamed template cannot break it.`

In decision 10, replace `Add hand-written name rows only for misses met in game.` with `Hand-written rows in Data/Inns.lua cover inns beside a differently named flight stop and towns with an inn but no flight master; add a row whenever "unknown inn" is seen in game.`

In the "`Graph` (pure)" bullet, append: ` A zone destination is reached at any place on the zone's map: that ride to the destination costs nothing, so hearthing to Crossroads for "The Barrens" does not add a ride to the zone's centre.`

- [ ] **Step 5: Run the Lua tests and luacheck once more** (docs only, so: `103 passed, 0 failed`, `0 warnings`), then commit

```
git add docs CLAUDE.md
git commit -m "Docs: planner window checklist, art specs, four-plan roadmap" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 6: Hand over.** Report that the desktop work is verified and that nothing in this plan has run in the game client. The user must restart the game (the TOC changed) and work through `## Planner window (plan 2)` in both layouts. Do not claim any of those checks pass.

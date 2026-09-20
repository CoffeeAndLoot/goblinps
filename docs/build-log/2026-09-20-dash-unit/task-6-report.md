# Task 6 report: the art over the colours

Commit: `f597b4f` "Dash unit: the art over the colours"

## Two defects found in the brief

Before laying out the changes, two problems with the brief's Step 1 test
turned up. Both are fixed below; details under "If the brief is wrong".

1. **`ns.Data.Art` was never loaded into the `test/test_ui.lua` harness.**
   `Data/Art.lua` is generated (task 1), but nothing in `test/run.lua` or
   `test/test_ui.lua` ever `dofile`'d it — the "modules" list in
   `test_ui.lua` (Geo, Travel, Search, ... Core) does not include it, and
   `test/fake_world.lua` has no `Art` table either. As written, the brief's
   own test would error with "attempt to index a nil value" on
   `ns.Data.Art[name]` before ever reaching an assertion.
2. **The "keeps a working device" test, as given, did not exercise the
   fallback.** `Dash.lua`'s `build()` only ever runs once per module
   instance (`if not ui then build() end`), and the very first
   `Dash.Start(plan)` in the file (line ~520, well before this new test)
   already built the shared window while every texture loaded fine (no
   `Fake.missingTextures` set yet at that point). `Dash.Stop()` only hides
   the frame; it does not clear the module's `ui` upvalue. So setting
   `Fake.missingTextures[...dash-body] = true` and calling
   `Dash.Stop(); Dash.Start(plan)` afterward, exactly as the brief specifies,
   rebuilds nothing — `ui.bodyArt` would already be the successfully-loaded
   texture from the first build, and the test would pass for the wrong
   reason (proving nothing about the fallback).

## Fix for defect 1: load the generated data into the harness

`test/test_ui.lua` line 15 (new):
```lua
    -- Data/Art.lua is generated, real game data (like Places or Nodes), not a
    -- fixture to fake; load it the same way the client does, before the UI
    -- files that draw it.
    assert(loadfile("GoblinPS/Data/Art.lua"))("GoblinPS", ns)
```
placed right after the existing `local ns = { Data = dofile("test/fake_world.lua")() }`.
`Data/Art.lua` does `ns.Data = ns.Data or {}` then sets `.Art`, so this only
adds the `Art` field onto the existing fake `ns.Data` table — it does not
disturb the Places/Nodes/etc. fixtures the rest of the file depends on. This
mirrors the real TOC load order (`Data\Art.lua` loads before `Dash.lua`).

## Fix for defect 2: a genuinely independent fallback test

`test/test_ui.lua`, in the new `"keeps a working device when a texture will
not load"` test: instead of `Dash.Stop()`/`Dash.Start()` on the shared
module, it loads a **second, independent copy** of `Dash.lua` (same pattern
already used to load every module: `loadfile(...)("GoblinPS", ns)`), so its
own `ui`/`state` upvalues start fresh and `build()` genuinely runs with
`Fake.missingTextures["...dash-body"]` already set:
```lua
                Fake.missingTextures["Interface\\AddOns\\GoblinPS\\Media\\dash-body"] = true
                local FreshDash = assert(loadfile("GoblinPS/Dash.lua"))("GoblinPS", ns)
                FreshDash.Start(plan)
                local ui = FreshDash.Debug()
                h.truthy(ui.frame:IsShown(), "a missing texture must not take the window with it")
                h.truthy(ui.step:GetText() ~= "", "the directions must still be readable")
                h.falsy(ui.bodyArt, "a texture that would not load must not be laid over the colour")
                Fake.missingTextures["Interface\\AddOns\\GoblinPS\\Media\\dash-body"] = nil
```
This new module instance overwrites `ns.Dash`, but the local `Dash` variable
captured earlier in the file (`local Dash = ns.Dash` at line ~502) still
points at the *original* module object, so no other test in the file is
affected — this is the last describe block that touches Dash/Core, confirmed
by grep.

I also added the `h.falsy(ui.bodyArt, ...)` assertion beyond the brief's
literal text, because "frame shown and text non-empty" alone does not prove
the fallback: I verified this by temporarily breaking `art()` to ignore
`SetTexture`'s return value (drawing the texture regardless of load
success) — with only the brief's two original assertions, the test suite
still went green (a texture always "loads" successfully against the fake
unless you check the return, and a shown frame with readable text doesn't
care whether a stray texture sits on top of the colour). Adding the
`ui.bodyArt` check catches this: with the broken `art()`, that test failed
with "a texture that would not load must not be laid over the colour, got
{...texture=\"Interface\\AddOns\\GoblinPS\\Media\\dash-body\"...}"; reverting
`art()` to check `SetTexture`'s return value makes it pass again. That proves
the test now genuinely exercises the constraint the task cares about most.

## RED (Step 2)

Ran after adding just the test (before any `Dash.lua`/`SelfTest.lua` changes):
```
1
220 passed, 1 failed
FAIL: the dash art :: lays every part on with the coordinates the tool generated
    test/test_ui.lua:686: attempt to index local 'texture' (a nil value)
```
Matches the brief's expectation: `ui.bodyArt` (and the other new `ui` fields)
did not exist yet, so `pair[1]` was `nil` and indexing it errored.

## GREEN (Step 4)

```
0
221 passed, 0 failed
```
221 = the 219-test baseline + the two new tests in "the dash art".

## What changed, by file

### `GoblinPS/Dash.lua`
- Line 14: `local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"`.
- Lines 23-38: new `art(parent, name, layer)` helper — creates a texture,
  calls `SetTexture` and checks its return; on failure it `Hide()`s the
  texture and returns `nil` (leaving the colour panel under it showing);
  on success it sets `SetTexCoord`/`SetAllPoints` and returns the texture.
- Lines 75-76: `screenArt = art(screen, "dash-screen", "BACKGROUND")` and
  `compass = art(screen, "dash-compass", "BORDER")`, added right after the
  screen panel, before the arrow.
- Lines 84-88: after the arrow's placeholder texture/colour is set, tries to
  load the real `arrow` part and only overrides `SetTexCoord`/
  `SetVertexColor(1,1,1)` if `SetTexture` succeeds — on failure the arrow
  keeps its original green `WHITE8X8` placeholder.
- Lines 109-119: the ETA plate frame (`plate`, anchored around `eta`) with
  `plateArt = art(plate, "dash-eta-plate", "BACKGROUND")`, `eta:SetDrawLayer("OVERLAY")`,
  then `bodyArt = art(f, "dash-body", "OVERLAY")` drawn last, on top of
  everything (its transparent hole lets the screen show through).
- Lines 121-123: `ui` table gains `screenArt`, `compass`, `bodyArt`, `plateArt`.
- Lines 182-184: in `aimArrow`, after `ui.arrow:Show()`, added
  `if ui.compass then ui.compass:SetRotation(-(ns.API.PlayerFacing() or 0)) end`
  so the compass ring turns opposite the player's facing (keeping north
  pointed north in the world) while the arrow rotation (already existing)
  points at the destination — two independent rotations, both driven from
  the one function per the brief.

### `GoblinPS/SelfTest.lua`
- Line 14: `local MEDIA = "Interface\\AddOns\\GoblinPS\\Media\\"`.
- Lines 16-29: new `shippedArt()` — collects `ns.Data.Art`'s keys, sorts them
  (for a stable report; `pairs()` order is otherwise unspecified), and
  returns each as `MEDIA .. part.file`.
- Lines 34-36: after the existing two hand-typed `SelfTest.TEXTURES` entries
  (icon, minimap zoom highlight), appends every path `shippedArt()` returns,
  so the five generated dash textures (`dash-body`, `dash-screen`,
  `dash-compass`, `arrow`, `dash-eta-plate`) are added to the self-test list
  without ever being typed by hand — the list is built straight from the
  same table `tools/make_art.py` produces, so it cannot drift.

### `test/test_ui.lua`
- Lines 13-16: loads the real, generated `GoblinPS/Data/Art.lua` into the
  shared `ns` (fix for defect 1 above).
- Lines 675-708 (new `h.describe("the dash art", ...)` block, inside the
  existing `do ... local Dash = ns.Dash ... end` scope so it can see `Dash`
  and `plan`):
  - `"lays every part on with the coordinates the tool generated"` — per the
    brief, but the loop also checks `dash-eta-plate`/`ui.plateArt` as the
    brief's prose instructed ("include dash-eta-plate in the loop").
  - `"keeps a working device when a texture will not load"` — rewritten to
    use a fresh `Dash.lua` module load (fix for defect 2 above), with the
    added `ui.bodyArt` assertion.
- No changes were needed in `test/fake_frames.lua`: `SetTexCoord` already
  recorded into `self.texCoord` (added in an earlier task), so the brief's
  conditional instruction to add it did not apply.

## All five generated parts are used

Confirmed by grep in `GoblinPS/Dash.lua`:
```
75:    local screenArt = art(screen, "dash-screen", "BACKGROUND")
76:    local compass = art(screen, "dash-compass", "BORDER")
84:    local arrowPart = ns.Data.Art and ns.Data.Art["arrow"]
114:    local plateArt = art(plate, "dash-eta-plate", "BACKGROUND")
119:    local bodyArt = art(f, "dash-body", "OVERLAY")
```
`dash-body`, `dash-screen`, `dash-compass`, `arrow`, `dash-eta-plate` — all
five — are each drawn by exactly one call site; none is generated and left
unused.

## Final counts

- **Lua tests:** 221 passed, 0 failed (baseline 219 + 2 new).
- **luacheck** (`GoblinPS test tools`): `Total: 0 warnings / 0 errors in 39 files`.
- **lua-language-server** (`--check D:\goblinps --checklevel=Warning`):
  `Diagnosis completed, no problems found` (empty `[]` in the JSON output),
  reproduced on three separate runs. (One earlier run, taken immediately
  after an accidental `git stash`/`git stash pop` cycle on this same
  checkout, showed two warnings — one in `Planner.lua` I never touched, one
  in `test/test_ui.lua` on a pre-existing line I never touched. Re-running
  against a clean worktree at `HEAD` showed the same as a fresh check of the
  working tree: `no problems found`, both before and after. That single
  contrary run was almost certainly a stale-analysis artifact from the
  stash/pop timing, not a real regression — three separate reproductions all
  show clean.)

## Not touched

`GoblinPS/Data/Art.lua`, `tools/`, and `GoblinPS/Media/` were not edited.
`AGENTS.md` (Codex's untracked file) was left untracked, not staged, not
committed. Nothing was pushed; only one commit was made, on `dash-unit`.

---

## Fix round 1

Commit: `61583d0` "Dash unit: fix the art layering and pin it with a test"

Review upheld both brief-defect fixes above and raised one Critical (the
layering in `build()`) and one Important (no test on the compass's
rotation). Both are fixed. Files touched: `GoblinPS/Dash.lua`,
`test/fake_frames.lua`, `test/test_ui.lua` — the three named in scope; no
changes to `Data/Art.lua`, `tools/`, or `Media/`.

### Finding 1: the layering was wrong three ways

Root cause, as the reviewer stated: a child frame draws entirely above every
draw layer of its parent, and within one frame the later-created region wins
a layer tie. `build()` had `bodyArt` on `f` directly (same frame as the
FontStrings, so creation order decided it, and it lost — drawn after them,
on top), `screenArt`/`compass`/`arrow` on a child frame (`screen`) of `f`
while `bodyArt` sat directly on `f` (so `screen`'s children always drew
above `bodyArt`, backwards from the intended stack), and the ETA `plate` was
a child frame of `f` while `eta` was a direct region of `f` (so `plate`
always drew above `eta`, no matter what `eta:SetDrawLayer` said).

**Fix — every level now explicit, derived from `f:GetFrameLevel()`
(`GoblinPS/Dash.lua`):**

```
base    = f:GetFrameLevel()
screen  = base + 1   -- screenArt (BACKGROUND), compass (BORDER), arrow (ARTWORK)
bezel   = base + 2   -- bodyArt (OVERLAY) — new frame, child of f, SetAllPoints(f)
content = base + 3   -- new frame, child of f, SetAllPoints(f); carries plateArt
                         (BACKGROUND) and all four FontStrings (OVERLAY, as
                         Widgets.Text always creates them)
stop    = base + 4   -- explicit; see below
```

- `screen:SetFrameLevel(base + 1)` — line 93. (This happens to match the
  client's own default for an unleveled child, but is now stated, not
  assumed.)
- New `bezel` frame (`CreateFrame("Frame", nil, f)`, `SetAllPoints(f)`,
  `SetFrameLevel(base + 2)`) — lines 112-114. `bodyArt` moved onto it
  (`art(bezel, "dash-body", "OVERLAY")`, line 115) instead of onto `f`.
- New `content` frame (same shape, `SetFrameLevel(base + 3)`) — lines
  119-121. `distance`, `eta`, `step` and `following` all moved onto it
  (`W.Text(content, ...)` instead of `W.Text(f, ...)`) — their anchors are
  unchanged (to `screen` and to each other) and each still carries two
  horizontal anchors.
- The ETA plate: I did **not** keep it as a separate child frame (a `plate`
  frame parented under `content` would itself draw above all of `content`'s
  own FontStrings, reproducing the exact bug being fixed, one level up). Its
  art is now a `BACKGROUND` texture created directly on `content` and
  anchored to `eta`'s own bounds instead of filling the frame. `art()` grew
  an optional fourth parameter, `pad`, for exactly this: when given, the
  texture is positioned around `pad` (the padding logic that used to live on
  the standalone `plate` frame) instead of `SetAllPoints(parent)`. Called as
  `art(content, "dash-eta-plate", "BACKGROUND", eta)` (line 143). Same frame
  as the FontStrings, `BACKGROUND` under their `OVERLAY`, so the ordering is
  correct regardless of creation order.
- `eta:SetDrawLayer("OVERLAY")`: **removed**. It was already redundant even
  before this fix — `Widgets.Text` hardcodes `CreateFontString(nil,
  "OVERLAY", ...)`, so every FontString it makes is `OVERLAY` regardless of
  any later `SetDrawLayer` call. Now that the plate is `BACKGROUND` on the
  very same frame as `eta`, the ordering holds on the layer comparison alone
  and the (always-redundant) call serves no purpose either way.
- **Stop button**: it *did* land under something and needed a fix. `stop` is
  its own `Button` frame, child of `f`, and had no explicit level — which
  defaults to `base + 1`, tied with `screen`. Once `bezel` (`base + 2`) and
  `content` (`base + 3`) exist and both `SetAllPoints(f)` (i.e. their
  regions can cover the whole device, including the bottom-right corner
  where Stop sits — `bodyArt` in particular is a full-frame texture), an
  unleveled Stop would sit below both and its face/label could be covered.
  Fixed with an explicit `stop:SetFrameLevel(base + 4)` (line 150), above
  everything. Said plainly per the instructions: yes, it moved (from an
  implicit `base + 1` to an explicit `base + 4`); no other change to its
  position or size.
- `ui` table gained `bezel` and `content` so the new stacking test can read
  their levels (`GoblinPS/Dash.lua` lines 152-154).

**Fake fix (`test/fake_frames.lua`):** `SetFrameLevel` removed from
`ALLOWED_NOOP` (it was a silent no-op before, so nothing could ever pin a
level). Added, matching the file's existing `function Region:Name(...) ...
end` style:
```lua
function Region:SetFrameLevel(level) self.frameLevel = level end
function Region:GetFrameLevel()
    if self.frameLevel then
        return self.frameLevel
    end
    return self.parent and (self.parent:GetFrameLevel() + 1) or 0
end
```
`GetFrameLevel` defaults an unleveled frame to one above its `parent`
(already recorded by `new(kind, parent)`), matching the real client's
default, so a test can compare levels meaningfully even for a frame that
never calls `SetFrameLevel` itself (e.g. `UIParent`, which has no parent and
so defaults to level 0).

**New test (`test/test_ui.lua`), "the directions are never hidden behind the
device"** (in the `"the dash art"` describe block): asserts, in order,
`ui.screen:GetFrameLevel() > ui.frame:GetFrameLevel()`,
`ui.bezel:GetFrameLevel() > ui.screen:GetFrameLevel()`, and
`ui.content:GetFrameLevel() > ui.bezel:GetFrameLevel()`.

**RED**, captured by swapping in the pre-fix-round `Dash.lua` (from commit
`f597b4f`, before any of this round's changes) against the new test:
```
1
222 passed, 1 failed
FAIL: the dash art :: the directions are never hidden behind the device
    test/test_ui.lua:735: attempt to index field 'bezel' (a nil value)
```
(`ui.bezel` didn't exist at all yet, since the old `build()` never created
that frame — exactly the shape of failure expected before the fix.)

**GREEN**, with the fix restored:
```
0
223 passed, 0 failed
```

### Finding 2: nothing asserted the compass's rotation

Added `"turns the compass by our own facing, not by the arrow's bearing"`
in `"the dash unit drives the trip"`, right after the existing arrow-facing
test. Chose `standAt(0, -100)` with `facing = 0`, which makes
`Trip.Bearing(pos, step.to) == math.pi / 2` (not `0`), so:
- `ui.arrow.rotation` (which is `ROTATION_SIGN * (bearing - facing)`,
  `Trip.ArrowAngle`) works out to `math.pi / 2`;
- `ui.compass.rotation` (`-(facing)`) works out to `0`.

These two expected values are genuinely different, unlike the pre-existing
"due north, facing north" test (`standAt(-100, 0)`, `facing = 0`), where
`bearing == 0`, making `arrow rotation == compass rotation == -facing` in
that case regardless of which formula either texture actually used — that
case could never have caught a swap.

**Proved it catches a swap**: temporarily changed
`ui.compass:SetRotation(-(ns.API.PlayerFacing() or 0))` to
`ui.compass:SetRotation(angle)` (the arrow's own angle) in `aimArrow`. Result:
```
1
222 passed, 1 failed
FAIL: the dash unit drives the trip :: turns the compass by our own facing, not by the arrow's bearing
    test/test_ui.lua:642: the compass turns opposite our own facing
    expected: "0"
    actual:   "1.5707963267949"
```
Reverted the swap; suite returns to green (223 passed, confirmed again
below).

### Final counts (fix round 1)

- **Lua tests:** 223 passed, 0 failed (previous 221 + 2 new: the stacking
  test and the compass-rotation test).
- **luacheck** (`GoblinPS test tools`): `Total: 0 warnings / 0 errors in 39 files`.
- **lua-language-server** (`--check D:\goblinps --checklevel=Warning`):
  `Diagnosis completed, no problems found` — reproduced on two separate runs
  after this round's changes.

Not claiming anything about how this looks in game — only that the stacking
order is now stated explicitly (four frame levels instead of relying on
draw-layer/creation-order defaults) and pinned by a test that fails without
the fix and passes with it.

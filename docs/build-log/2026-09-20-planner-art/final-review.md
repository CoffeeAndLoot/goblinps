# Final whole-branch review — `planner-art` (1ccf8a8..dde84b4, 12 commits)

Reviewed 2026-09-20. Scope: the full branch diff, the plan, the ledger, and
`CLAUDE.md`. Everything below that says "verified" was verified by me on this
machine, at the source or by running the tool named. Nothing on this branch
has been in the game client, and nothing here claims otherwise.

---

## Verdict: **ready with fixes**

One Critical, two Important, five Minor. The Critical is provable at the desk
and defeats the headline visual of Task 5: the `screen-backdrop` scenery is
drawn under an opaque flat-colour panel and cannot be seen. The first Important
is the same class of defect the `Stretch3` helper was written to prevent. Both
are small edits. Everything else on the branch is in good shape — the art
pipeline, the geometry generation, the cover-crop arithmetic, the frame's bare
chassis and hideable fallback, and the documentation are all correct as far as
source can settle them.

Fix the Critical and Important 1, then take it into the client.

---

## Gates — run by me, from PowerShell, on the working tree at `dde84b4`

| Gate | Result | Matches owner's claim |
|---|---|---|
| Lua suite via `lupa` | **278 passed, 0 failed** | yes |
| `python -m unittest discover -s test/tools` | **Ran 42 tests — OK** | yes |
| `python tools/check_art.py` | **47 pass, 0 with problems, 0 not drawn yet** | yes |
| `python tools/make_art.py` then `git status --porcelain` | regenerates **29 textures, 8.07 MB**; tree clean except untracked `AGENTS.md` | yes |
| luacheck (PowerShell) | **0 warnings / 0 errors in 38 files** | yes |
| `lua-language-server --check` (PowerShell) | **"Diagnosis completed, no problems found"**, output JSON `[]` | yes |

All six independently reproduced. No gate was taken on trust.

---

## Findings

### CRITICAL 1 — the screen backdrop is drawn, cropped correctly, and invisible

`GoblinPS/Planner.lua:402` creates `backdrop` on `artLayer`; `:325` places it at
`g.screen`. `GoblinPS/Planner.lua:517` then builds

```lua
local screen = W.Panel(content, "screen", "steel", 2)
```

and `ApplyLayout` places `ui.screen` at **the same `g.screen` rect**.
`Widgets.Panel` (`GoblinPS/Widgets.lua:36`) lays two **fully opaque**
`SetColorTexture(..., 1)` regions across its whole frame — a steel fill on
BACKGROUND and the dark-green inner on BORDER.

Frame levels, measured (not reasoned) by probing the built UI in a scratch copy:

```
f=1  flat=1  artLayer=2  content=3  screen=4  side=4  results=4
BACKDROP wide  pts=60.9375,-160.875104
SCREEN   wide  pts=60.9375,-160.875104     <- identical anchor, identical rect
```

`screen` is a child of `content`, so it inherits level 3 + 1 = **4**. The
backdrop sits on `artLayer` at **2**. An opaque rectangle at level 4 sits
exactly on top of the scenery at level 2. In the client the screen will show
flat dark green, not mountains.

This is the same fault the branch correctly fixed one level up. For the window
frame, the flat colour was moved into its own `flat` frame precisely so it could
be hidden the moment the art loaded (`Planner.lua:366`, hidden and shown by
`ApplyLayout` at `:292` and `:295`). The screen's flat colour never got that
treatment. Ruling R18 in
the ledger diagnosed this exact geometry for `planner-panel` — "placed at
`g.screen` ... the scenery covers it and the part does nothing" — and moved
`panelArt` to the bounding box, but did not notice that the backdrop itself is
underneath an opaque panel.

Nothing catches it: the two backdrop tests check the texcoords' centredness and
magnitude, both of which are correct. No test asserts the backdrop is above
anything.

**Confidence:** high at the source level. Frame-level ordering in WoW is strict
and the fake models it the same way (`test/fake_frames.lua:180-184`, parent + 1),
which is how I could measure it. The *appearance* is a client question; the
ordering is not.

**Cheapest remedy:** create the backdrop on the `screen` frame itself at
`"ARTWORK"` rather than on `artLayer`. That puts it above `screen`'s own
BACKGROUND and BORDER colours (so the flat colour stays a true fallback
underneath) and below the OVERLAY text (`notes`, `known`, `device`), which is
exactly the intended stack. `W.PlaceRect(ui.backdrop, f, g.screen)` can then be
replaced by `backdrop:SetAllPoints(screen)`, and `coverCrop` still needs the
box's pixel size from the geometry as it does today. The alternative — making
`screen`'s two colour textures hideable like `flat` — works too but costs a new
`Widgets` shape.

`panelArt` is **not** affected and is placed correctly: at the bounding box of
every rect it shows through the gutters between the opaque widgets, which is
what R18 asked for.

---

### IMPORTANT 1 — three-slice end caps are sized at build time and never resized

`GoblinPS/Widgets.lua:138`:

```lua
local width = parent:GetHeight() * capAspect
```

`Stretch3` is called from `build()` (`Planner.lua:499, 510, 514, 515, 554`),
where every control still carries the *constructor's* height from
`W.Button`/`W.EditBox`. `ApplyLayout` then re-anchors each control corner to
corner from the geometry, which changes its real height — and nothing recomputes
the cap width. `Stretch3` is never re-run, and the two layouts have different
heights, so the caps cannot be right in both even in principle.

Measured cap widths (probe against the built UI) versus the widths the geometry
actually implies:

| control | cap width set | wide height → correct cap | tall height → correct cap |
|---|---|---|---|
| `go` | 24 | 32.5 → 32.5 (**−26%**) | 33.7 → 33.7 (**−29%**) |
| `here` | 20 | 30.1 → 30.1 (**−34%**) | 27.7 → 27.7 (**−28%**) |
| `layoutButton` | 18 | 22.3 → 22.3 (**−19%**) | 21.0 → 21.0 (−14%) |
| `fromBox` | 28.75 | 30.1 → 43.3 (**−34%**) | 27.7 → 39.8 (**−28%**) |
| `toBox` | 28.75 | 30.1 → 43.3 (**−34%**) | 27.8 → 40.0 (**−28%**) |

The probe printed `h=24 capW=24` for GO in *both* layouts, confirming the value
is baked once and reused.

This is precisely the fault `Stretch3` exists to prevent — "a squashed end cap"
— arriving by a different door. The decorative caps will draw a quarter to a
third narrower than the art was drawn at.

**Why no test sees it:** the fake's `GetHeight()` returns the explicit
`SetSize` value and does not resolve a size from two opposing anchors, so on the
desktop `c:GetHeight()` stays 20/24/18 after `ApplyLayout` and the stale cap
width *looks* correct. The client resolves the anchors. This is a new instance
of the branch's own lesson — the fake being more helpful than the client — and
worth adding to `CLAUDE.md`'s list beside the `SetAllPoints` note.

**Remedy:** give `Widgets` a `Widgets.Reslice3(slice, capAspect)` (or have
`Stretch3` record `capAspect` on the slice, as it already records `capFraction`
and `name`) and call it from `ApplyLayout` after each `W.PlaceRect`, so the cap
width tracks the placed height. Add a test that asserts
`slice.left:GetWidth() == controlHeight * capAspect` **after** `ApplyLayout`,
using `Fake.Layout()` so the resolved height is honest.

---

### IMPORTANT 2 — deferred finding 1: `check_art.py`'s allow-list is silent on new keys

`tools/check_art.py:271` — `PLANNER_INTERIOR_KEYS` names six keys; the loop at
`:288` skips anything not in it. `planner-geometry.json` carries **13**
rectangular keys per layout, so seven get neither a pass nor a failure.

**Verdict: fix before merge.** Reasoning below, under Triage.

---

### MINOR 1 — stale plan numbering survives in a live document

`docs/manual-test-checklist.md:147` still reads

> "it answered the question plan 6 (the route strip) was waiting on"

The route strip became plan 7 on this branch. The same file now heads a section
`## Planner window art (plan 6)` at `:362`, so the one document contradicts
itself. Everywhere else is correct: `CLAUDE.md:30-45`, the spec's status
paragraph and decision 5, and the new checklist section all say plan 6 is the
planner's art and plan 7 is the strip.

The other "plan 6 = route strip" hits are in `docs/build-log/` and in the *dash*
plan file — historical records of what was true when written. Leave those.

---

### MINOR 2 — two shipped textures nothing draws

`button-hover.tga` and `button-pressed.tga` ship (16 KB each) and no code reads
them: `grep '"button-hover"\|"button-pressed"' GoblinPS/*.lua` is empty. The
three buttons keep `Widgets.Button`'s flat white `HIGHLIGHT` overlay as their
hover cue and have no pressed state at all.

Task 1's own rationale for omitting the strip parts was "a texture nothing draws
is weight in the addon for no picture on screen". By that rule these two are
weight. Either wire them (`SetHighlightTexture` / `SetPushedTexture` are already
used for `close` and `gear`) or drop them until something draws them. Wiring is
probably right — the artist drew four button states and the window uses two.

---

### MINOR 3 — the results overlay's layering works by strata, not by the level it sets

`Planner.lua:558-559` sets `results` to strata `DIALOG` and level `base + 3` = 4.
But `screen` and `side`, being children of `content`, are *also* at level 4.
The plan's frame-level table treats `content`'s children as sitting at
`content`'s level; they sit one above it, so `base + 3` ties rather than wins.

The overlay is above them anyway because `DIALOG` outranks `HIGH` — but the test
that claims to prove it (`"stacks the art under the content"`) asserts only
`results:GetFrameLevel() > content:GetFrameLevel()` (4 > 3), which is true and
does not prove the thing it is named for. Nothing is broken; the comment and the
test are both about the wrong mechanism. Worth a line of comment saying the
strata is what does the work, and an off-by-one correction to the level table if
the build log keeps it.

---

### MINOR 4 — plan 6's ledger lives only in gitignored scratch

`.gitignore:5` ignores `.superpowers/`, and `docs/build-log/README.md` says
plainly that directory "is reused by later plans; this copy is the permanent
one". `docs/build-log/` currently covers plans 2 to 5 only. If plan 7 starts
before the copy is made, this branch's twenty-one rulings are gone. The
convention is the project's own; honour it as part of the merge.

---

### MINOR 5 — a client-only question worth putting on the checklist

The `input-box` three-slice is created on the EditBox at the `ARTWORK` layer
(`Widgets.lua:139`) and is opaque. Whether an EditBox's *typed* text draws above
ARTWORK is not something source can settle here. Evidence both ways from the
`forever` branch at `D:\wow-api\1.60.1.69913`: Blizzard's own three-slice input
border (`Blizzard_AuthChallengeUI`, `InputBoxVisualTemplate`) sits on
**BACKGROUND**, but `Blizzard_AchievementUI`'s search box puts
`BorderLeft/BorderCenter/BorderRight` on **ARTWORK** inside an EditBox. The
placeholder is safe (OVERLAY); the typed text is not under our control.

The checklist has "From, To and Here sit in their openings, and the end caps ...
are not squashed" but nothing about *reading* what you type. Add:
"Type into From and To — the text is legible over the new box art, not hidden
behind it." Same for the button labels, which are OVERLAY `steel` (0.11, 0.10,
0.08) chosen to read on the old flat brass; how they read on the artist's brass
is a pixels question.

---

## Things I checked because this project has shipped them broken, and which are RIGHT

- **The window frame carries no art of its own.** `Planner.lua:345` is a bare
  `CreateFrame`; the flat colour is `flat`, its own frame at `:366`, hidden at
  `:292` the moment `frameArt:SetTexture` succeeds and shown again at `:295`
  when it does not. Pinned by a test that counts `#ui.frame.regions == 0`.
  Correct, and the reason the transparent margins will not be boxed in.
- **`Planner.SIZE` matches the canvas exactly.** 650/416 = 1.5625 = 25:16;
  384/600 = 0.64 = 16:25. Not close — exact. Both frames also ship at their
  drawn size (`r = 650/1024`, `b = 416/512`), so they draw 1:1 at UI scale 1.
  No stretch anywhere.
- **Positions are pinned, not only sizes.** Every new placement test asserts a
  coordinate — `points[1][4]` against `rect.left * w`, `button.points[1][4]`
  against `circ.cx * w`. The helper tests pin all four edges. This is the plan-5
  lesson actually applied.
- **The cover-crop composes correctly.** `coverCrop` (`Planner.lua:209`) reads
  `part.cw`/`part.ch` and takes **no dimension parameters at all**, so no caller
  can supply the wrong domain — a better fix than correcting two numbers.
  Recomputed by hand from `Art.lua`'s row (`cw=512, ch=256, b=0.800781`):
  partAspect 2.4976, wide screen 309.6x143.0 → **6.66% trimmed per side**,
  exactly the intended figure; tall → 2.26%. The magnitude test that catches the
  15.33% regression is real and does the work the centredness test could not.
- **`tools_button` never reaches the addon.** Dropped in `make_art.py`'s
  `PLANNER_DROP`, asserted by a test, documented in the spec and on the
  checklist. Confirmed absent from the generated table.
- **`API.lua`'s monopoly holds.** The only Blizzard globals in `Planner.lua` are
  `CreateFrame` (7 sites) and `UIParent` (2). Nothing else.
- **The fallback is real.** Two tests: `ns.Data.Art` nilled wholesale, and a
  single named texture failed via `Fake.missingTextures` while the rest load —
  R14, honoured, and the stricter of the two.
- **GO's disabled state uses the shipped art**, not a tint the ARTWORK slice
  would cover (R17), with the restore-on-failure path tested.

---

## Triage of the two deferred findings

### 1. `check_art.py`'s `PLANNER_INTERIOR_KEYS` allow-list — **fix before merge**

Thirteen rectangular keys per layout, six checked, seven silent. Confirmed by
reading the file and listing the JSON's keys.

The ledger's R11 is right that the deviation itself was correct: the six kept
keys are the ones that draw live content with no sprite of their own, and a
brass-underneath check is meaningless for a control that ships an opaque plate.
The precedent (the dash's `geometry_holds()` uses the same inclusion shape) is
real. None of that is in dispute, and no key on this branch is wrong — the
ledger measured all thirteen by hand.

But `CLAUDE.md` names this shape of problem directly: *"never let silence read
as 'nothing disagrees'"*. The specified remedy — fail when a rectangular key
appears in **neither** the interior list nor a documented brass-backed list —
converts the silent gap into a loud one and costs three lines. The cost of not
doing it lands squarely on plan 7, which is the very next plan and which adds
strip keys to this file. That is too short a fuse to leave lit, and this branch
merges into `main` where plan 7 begins.

**One addition to the specified remedy:** also assert that every key in the
interior list is *present* in the JSON. As written the remedy closes the
"key added" hole but not the "key renamed away" hole — a rename would drop a
checked key out of the loop just as silently.

### 2. The dash's `SetAllPoints` protection rests on suite ordering — **do not fix before merge; fix better, later**

The analysis is correct and I confirmed the mechanism: `Dash.lua`'s `ui` is a
build-once singleton, so every `W.PlaceLine` runs at the first `Dash.Start()`,
before any test calls `Fake.Layout()`, and the offsets bake in. A refactor that
made `build()` re-run per `Start()` would leave both tests green while measuring
an already-laid-out frame.

Nothing is wrong today, and no test change would durably fix it — a test that
depends on suite ordering to prove something cannot be made to *notice* when
that ordering stops holding.

**A better remedy exists, and it is not a test.** Put the guard in the helper.
`Widgets.PlaceRect`, `PlaceLine` and `PlaceCircle` all begin by measuring
`device:GetWidth()`. A frame with no resolved size answers **0**, and 0
multiplies silently — that is the whole fault. Have the three helpers treat a
zero measurement as the error it is: record it on a module flag that
`/gps selftest` reports, or route it through `ns.Core.Say` behind a debug flag.
That converts a silent 0 into something loud **in the client**, where the fault
actually landed, and it does not care what order any test runs in or how
`Dash.build()` is structured. Do not raise a hard Lua error — an addon that
errors during `build()` is worse than one drawn in the wrong place.

Worth a line in the ledger and in `CLAUDE.md`, and a small task in plan 7. Not a
merge blocker: it protects against a refactor nobody has proposed.

---

## Codex's commit `dad6aba` — I agree the check was sufficient

The concern is right on its face: `GoblinPS/Media/dash2-housing.tga` is a
generated file and was committed directly, which the Global Constraints forbid.

The check you ran is the correct one, and I reproduced it rather than reading
about it: `python tools/make_art.py` regenerated all 29 textures and
`git status --porcelain` came back with nothing but the untracked `AGENTS.md`.
The shipped TGA is byte-identical to what the generator produces from the
corrected `images/parts/dash2-housing.png`. `check_art.py` also passes 47/0/0 on
the corrected source.

That is exactly the property the rule protects — source and shipped in sync, and
a regeneration is a no-op — and the generator is deterministic, so a clean tree
after a full regeneration is proof, not a sample. The rule exists to stop a
shipped file drifting from its source; it has not drifted. **R21 stands.**

The only residual is merge hygiene: the branch's diff now carries an unrelated
dash art fix and six preview PNGs. That is a preference, not a correctness
question, and reverting a good fix for tidiness would be the worse trade. The
whole-branch record should say what it is, which the ledger does.

---

## Is the documentation honest?

Yes, with the one stale line at Minor 1.

- **Nothing claims plan 6 ran in the client.** Three documents say the opposite
  in so many words. `CLAUDE.md:34` — "**Plan 6 has not been run in the client.**
  Do not write that it has" — with the reason attached. The spec's status
  paragraph: "not run in the client at all". `docs/manual-test-checklist.md:364`
  opens the new section with "Plan 6 has **not** been run in the client. This
  section is untested; the faults it lists are ones the branch fixed or narrowly
  avoided at the desk, not ones already seen on screen." That last sentence is
  the honest one — it says what the checklist items *are*, which is unusual and
  right.
- **Plan numbering.** Correct in `CLAUDE.md`, the spec and the new checklist
  section; stale at `docs/manual-test-checklist.md:147` (Minor 1).
- **The new `CLAUDE.md` rules are accurate.** I checked each against the code:
  `make_art.py` really emits `cw`/`ch` (`Art.lua:25-33` carry them);
  `coverCrop` really reads them and takes no dimension parameters; the
  15.33%/6.66% figures match my own recomputation; `.luacheckrc` really carries
  five per-file exemptions with four generated. The lint bullet is carefully
  worded — it sanctions the established generated-file exemption and explicitly
  refuses to be read as precedent, which is the right shape for R10.
- **One thing the documentation now asserts that the Critical falsifies:** the
  checklist item "The screen's scenery fills its opening without looking
  stretched" will fail in the client as the branch stands. That is the checklist
  doing its job, not a documentation defect — but it is the item to watch.

---

## The single thing most worth the owner's attention

**The screen backdrop is invisible, and the branch's own history explains why
nobody saw it.** The window frame's flat colour was correctly moved into a
hideable `flat` frame, tested, and written up as a lesson learned. One level
down, the screen's flat colour was left as an opaque `W.Panel` and the scenery
was parked beneath it. Ruling R18 even walked right past it — it noticed
`planner-panel` was being covered *by the backdrop* and moved the panel, without
asking what was covering the backdrop.

The pattern worth naming: **this project keeps fixing a fault at the outer layer
and reproducing it at the inner one.** The dash's oval, then the dash's compass.
The frame's unhideable rectangle, now the screen's. `Stretch3` exists to stop a
squashed end cap and hands one to every control it decorates. The rule that
would have caught all three is not "check the art" — it is *for every art part
you ship, name what is above it and what is below it, and prove the one you
meant is on top.* Two lines of test per part. Nothing on this branch asserts
that a single art texture is visible; every test asserts where it is and how big
it is. That is the gap, and it is the same gap plan 5's review named in a
different dialect: a test that checks how big a thing is cannot tell you it is
in the wrong place — and a test that checks where it is cannot tell you it is
behind something.

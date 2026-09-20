# Task 4 report: Documents

## What was done

Documentation-only task; no code touched. Read all four target files in full
before editing, then made exactly the edits the brief lists.

### Step 1 — `docs/manual-test-checklist.md`

Appended the "## Ground crossings (plan 3)" section verbatim to the end of
the file, with one addition per the dispatch notes: a new checklist item
directly after the "Orgrimmar's west gate" item:

```
- [ ] The ramp in Un'Goro Crater's north-west corner: confirm it is the way
      into Silithus (a reviewer doubted it; the classic world and the atlas
      both say yes)
```

### Step 2 — `docs/superpowers/specs/2026-09-19-goblinps-design.md`

- `Graph` (pure) bullet: replaced the clause about the Feathermoon ferry
  returning as an ordinary link. Now reads "...the `Islands` table and the
  800-yard transfer rule are deleted, and the travel speed comes in with the
  options (walk or mount, by level). Sardor Isle shares Feralas's map, and
  ground travel is per map, so the isle still counts as part of Feralas and
  its ferry stays out (a ride inside the zone would always undercut it)."
  before continuing into "If no route exists with crossings alone...".
- "Hand-written for ground travel (plan 3)" list, `Data/Crossings.lua`
  bullet: changed "about 55 rows" to "56 rows" and replaced the atlas
  sentences with the brief's exact replacement text about facts vs. the
  atlas's own prose/shapes/code.
- "Still to verify in game" crossing-coordinates bullet: appended the
  Shen'dralas / Riverglades sentence given in the brief. (Decision 15's list
  of city gates itself was left untouched, as instructed.)
- Status paragraph: changed "2 planner window (built), 3 ground crossings
  with walk-or-ride by level, 4 dash unit" to "2 planner window (built), 3
  ground crossings with walk-or-ride by level (built), 4 dash unit" — same
  net result as the brief's "add (built) to item 3 / remove the duplicate"
  instruction, list still reads 1 to 5 in order with no duplication.

### Step 3 — `CLAUDE.md`

- Status paragraph rewritten to say plans 1–3 are built (routing core,
  planner window, ground crossings), next is plan 4 (dash unit) then plan 5
  (schematic map); kept the "product is a GPS" sentence. Re-wrapped only this
  paragraph to ~78 columns.
- Layout block: added the three new lines after `GoblinPS/Data/Inns.lua`
  exactly as given (`Data/Crossings.lua`, `Data/Zones.lua`, `Travel.lua`).
- "Rules that are easy to break": added the new bullet about ground travel
  being per zone, verbatim from the brief.

### Step 4 — `docs/research/2026-09-19-api-and-data-findings.md`

Replaced the Forever Atlas license sentence (from "**No license**, so all
rights reserved" through "...cannot know a character's flight paths.") with
the brief's exact replacement text distinguishing the atlas's own work
(unused) from the facts it records (used freely as a checklist), keeping the
final "It has its own browser route planner..." sentence.

## Commands run and output

Lua tests:

```
python -c "import lupa.lua51 as L; lua=L.LuaRuntime(unpack_returned_tuples=True); print(lua.execute(open('test/run.lua').read().replace('os.exit(harness.run())','return harness.run()')))"
```
Output: `0` then `160 passed, 0 failed` — matches the brief's expected count.

luacheck:

```
$env:PATH = "$HOME\AppData\Local\Programs\Lua\bin;$env:PATH"
$env:LUA_PATH = "$HOME\.luarocks\share\lua\5.4\?.lua;$HOME\.luarocks\share\lua\5.4\?\init.lua;;"
lua "$HOME\.luarocks\share\lua\5.4\luacheck\main.lua" GoblinPS test --no-color --no-cache
```
Output: `Total: 0 warnings / 0 errors in 36 files` — matches expected.

No TDD evidence applies: this is documentation only, as the dispatch said.

## Files changed

- `CLAUDE.md`
- `docs/manual-test-checklist.md`
- `docs/research/2026-09-19-api-and-data-findings.md`
- `docs/superpowers/specs/2026-09-19-goblinps-design.md`

`git diff --stat` before commit showed exactly these four files (76
insertions, 17 deletions). Nothing under `GoblinPS/`, `test/`, or
`.superpowers/` was touched or staged, per the dispatch notes (another agent
was reviewing code commits read-only concurrently).

## Self-review findings

- Confirmed no other occurrences of the edited sentences existed elsewhere
  in each file (no accidental double-application).
- Confirmed the manual-test-checklist.md file previously ended with the
  "Hearth: unknown inn" bullet; the new section was appended cleanly after
  it with a blank line, matching the existing file's spacing convention.
- Confirmed the spec's status-paragraph edit still reads 1 to 5 in order
  with "(built)" appearing exactly once for item 3, no duplicate phrase.
- Line endings: git warns "LF will be replaced by CRLF" on these files per
  the repo's existing `.gitattributes`/core.autocrlf setting — this is
  pre-existing repo behavior on Windows checkouts, not something introduced
  by these edits (the tool wrote LF as instructed; git's own checkout
  normalization is unrelated to the diff that was committed).

## Concerns

None. All edits match the brief precisely; both verification commands match
expected output exactly.

## Commit

```
git add docs CLAUDE.md
git commit -m "Docs: ground crossings checklist, spec corrections, atlas facts" -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

Result: commit `a188c47` on branch `ground-crossings`, 4 files changed
(76 insertions, 17 deletions). Not pushed.

Note on attribution: the brief's own commit command specified
`Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`, but a
higher-precedence system reminder in this session states the current
attribution line is `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`
and explicitly replaces any earlier attribution guidance. The commit was
made with the Sonnet 5 line per that reminder.

## Hand over (Step 6)

The desktop work is verified: `160 passed, 0 failed` and luacheck `0
warnings / 0 errors`. Nothing in this plan (or in plan 3's ground-crossings
feature generally) has been run in the actual game client. The user must
restart the game (the TOC changed) and work through the new "## Ground
crossings (plan 3)" section of `docs/manual-test-checklist.md`, including
the added Un'Goro Crater ramp item. None of those checks are claimed to
pass — they are unchecked boxes awaiting an in-game session.

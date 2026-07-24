# `/memory-search` - Design Spec

**Date:** 2026-07-19
**Status:** Approved design, ready for plan
**Idea:** `memory-backlinks-search` (the search + backlink half; property-views stay deferred), `ideas.md`
**Relates to:** `scripts/memory_graph.py` (the graph engine this extends - search/backlinks are
operations over the graph it already derives), `skills/memory-lint/SKILL.md` (sibling skill - same
data-root prereq and read-only, no-commit posture), `conventions/memory.md` (frontmatter schema:
`name`/`description`/`type`), `conventions/data-root.md` (in-repo vs sidecar resolution)

---

## 1. Summary

A read-only recall tool over this repo's `docs/memory/` (or the sidecar `<data_root>/memory/`): find
a fact by keyword, and see what links to/from a fact. It closes the two gaps the idea names - no
**backlink view** and no **search** beyond grep - while keeping memory git-native and engine-derived.

Both features are operations over the knowledge graph `memory_graph.py` **already derives** from the
markdown (it scans every fact and builds the directed `wiki_edges` list). So the engine work is small
and additive: two new query modes on the existing script, plus a thin skill that dispatches to them.
No new store, no embeddings, no second thing that parses memory.

**Two scoping decisions taken in brainstorming (both narrowing):**
- Search matches a fact's **`name` + one-line `description` only**, not body text. This removes any
  need to read/grep file bodies - the whole feature runs off the graph the engine computes.
- **Property-views by type/tag are out** (the idea marks them "optional"). Deferred to a later slice.

## 2. Scope

**In:**
- `scripts/memory_graph.py` - two new modes: `--search QUERY` and `--backlinks NODE`. `--search`
  needs one new frontmatter parse (`description:`; `name:` is already parsed). Existing modes
  (`--check`, `--json`, `--mermaid`, default report) untouched.
- `skills/memory-search/SKILL.md` - new user-invocable skill: resolve the data root, dispatch to the
  right engine mode, print the result. Read-only; no edits, no commit.
- `tests/test-memory-graph.sh` - cases for both new modes against the existing fixtures.
- Docs + tracking close-out: `plugin.json` prose + version bump; `ideas.md` marks the search/backlink
  half of `memory-backlinks-search` shipped; `resolved.md` action record + `decisions-log.md` decision.

**Out (YAGNI / deferred):**
- **Body / full-text search.** Match is name + description only (brainstorming decision). Body search
  would reintroduce a file-grep data source; deferred.
- **Property-views by type/tag** (`--type domain`, tag filters). The idea's "optional" third capability;
  a separate future slice. `type` is therefore NOT parsed this slice.
- **Note-templates set** (the idea's other bundled item, e.g. the `stale-prior` flavor). Independent of
  search; not this slice.
- **Ranking/relevance scoring.** Deterministic substring match with a simple, documented sort order
  (see §4). No TF-IDF/fuzzy matching.
- **`/memory-search` as a model-invoked recall path.** Ships `disable-model-invocation: true` to match
  `memory-lint` - a deliberate user command (see §5, flagged as a one-line reversible choice).

## 3. Architecture

```
scripts/memory_graph.py   (the graph engine - already scans docs/memory + builds wiki_edges)
  ├─ NEW --search QUERY    substring match of QUERY vs each fact's name + description
  │                        (adds a `description:` frontmatter parse in scan())
  └─ NEW --backlinks NODE   from wiki_edges: LINKS OUT (source==NODE) + BACKLINKS (target==NODE)
skills/memory-search/SKILL.md   (thin dispatcher)
  ├─ resolve-data-root.sh  → in-repo (docs/memory) or sidecar (<data_root>/memory); announce mode
  ├─ args look like `--links <fact>` / `links <fact>`  → memory_graph.py --backlinks <fact>
  └─ anything else (a query)                            → memory_graph.py --search "<query>"
```

Search and backlinks are cohesive with the script's existing job (deriving + reporting over the memory
graph): `analyze()` already computes neighbour sets, and `wiki_edges` already holds directed, typed
edges. Reusing `scan()` avoids a second parser that could drift out of sync with the linter's view of
the graph - the copy-paste-drift failure mode to avoid.

## 4. Engine modes (`scripts/memory_graph.py`)

Both modes reuse `scan()` on the resolved root and honor the existing `--root` / `--tracking-root` /
`--link-root` flags. Both exit `0` on success **including an empty result** (finding nothing is a valid
answer, not an error); exit `2` stays reserved for "root not found" as today.

**`--search QUERY`**
- New parse: capture frontmatter `description:` per file in `scan()` (a `FRONTMATTER_DESC` regex over
  the same near-top frontmatter window `name:` uses), into a `{norm_stem: description}` map.
- Match: case-insensitive substring of `QUERY` against the fact's `name` (its frontmatter name / stem)
  **or** its `description`.
- Output: one line per hit - the fact name, then a short description snippet. Example:

  ```
  MATCHES (2)  for "output"
    forecasting-output-writers   - "the legacy blob CSV is the UOR scheduler's read; 1.0 floor..."
    scheduling-output-writeback  - "legacy schedule CSV, 3-phase sub-venue allocation, UKG export"
  ```
- Sort order (deterministic, documented): name-matches before description-only matches, alphabetical
  within each group. No relevance scoring.
- Empty query or no matches → `MATCHES (0) for "<query>"` + exit 0.

**`--backlinks NODE`**
- Normalize `NODE` (the script's `norm()`), then from `wiki_edges`:
  - **LINKS OUT** - edges where `source == NODE`: print `type -> target` (type omitted/`related` shown
    plainly), so typed edges (`[[part_of::…]]`) are visible.
  - **BACKLINKS** - edges where `target == NODE`: print `source (type)`.
- Example:

  ```
  scheduling-optimizer-solve
    LINKS OUT (2):
      part_of      -> scheduling-spine
      depends_on   -> scheduling-optimizer-inputs
    BACKLINKS (3):
      scheduling-demand-module (related)
      scheduling-output-writeback (related)
      scheduling-config (related)
  ```
- `NODE` not among scanned facts → a "no such fact: <node>" line plus up to a few near spellings
  (facts whose norm stem shares a prefix/substring), still exit 0 so the skill can interpret and the
  output stays pipe-friendly.

## 5. Skill (`skills/memory-search/SKILL.md`)

Mirrors `memory-lint`'s shape and posture.

- **Frontmatter:** `name: memory-search`; a trigger-friendly `description` ("search this repo's memory /
  find a fact by keyword / what links to a fact / show backlinks; use for recall over docs/memory");
  `user-invocable: true`; `disable-model-invocation: true`; `allowed-tools: Bash, Read` (pure read:
  it runs the engine and prints; no editing, and no body-grep since search is name+description only).
- **Prereq:** resolve the data root first via `bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh"`
  (conventions/data-root.md); memory lives at `<data_root>/memory/`; if missing, say so and stop.
  Announce the resolved mode (in-repo vs sidecar), exactly like `memory-lint`.
- **Dispatch:** if the argument is `--links <fact>` or `links <fact>`, run `memory_graph.py --backlinks
  <fact>`; otherwise treat the whole argument as a search query and run `memory_graph.py --search
  "<query>"`. Pass the resolved `--root`/`--tracking-root` (and, in sidecar mode, `--link-root` for the
  workspace tier, matching `memory-lint`).
- **Output:** print the engine's output verbatim; the model may add a one-line summary. **No edits, no
  commit** - read-only recall, same as `memory-lint`.

**Flagged choice (reversible in one line):** `disable-model-invocation: true` matches `memory-lint` and
keeps `/memory-search` a deliberate user command. If model-invoked recall is wanted later, drop that
line. Default this slice = match the sibling.

## 6. Testing (`tests/test-memory-graph.sh`)

Same plain-bash / substring-assertion style, against the existing `fixtures/memory-clean` tree:
- `--search` finds a fixture fact by a `description` keyword; assert the fact name appears.
- Case-insensitivity: same query in a different case returns the same hit.
- No-match query → `MATCHES (0)` and exit 0 (empty result is not a failure).
- `--backlinks <fact>` on a fixture fact with known edges: assert both a LINKS-OUT target and a
  BACKLINK source appear (the clean fixture already carries a `supersedes` typed edge to exercise type
  display).
- `--backlinks <unknown>` → "no such fact" text, exit 0 (no crash).
- Pre-req check: confirm the fixture facts have `description:` frontmatter; add one to a fixture fact if
  missing (a fixture-only edit, no production impact).

## 7. Changes by file

- **`scripts/memory_graph.py`** - add `--search` / `--backlinks` args; a `FRONTMATTER_DESC` parse +
  `descriptions` map in `scan()`; two small print functions; dispatch in `main()` before the default
  report. Existing modes and their output unchanged.
- **`skills/memory-search/SKILL.md`** - new skill (auto-discovered from `skills/`; no manifest wiring
  needed to load it).
- **`tests/test-memory-graph.sh`** - the §6 cases; possible one-line `description:` addition to a
  fixture fact.
- **`.claude-plugin/plugin.json`** - mention `memory-search` in the description prose; version bump
  `0.13.0 → 0.14.0`.
- **`docs/project-tracking/`** - on completion: `resolved.md` action record; `decisions-log.md`
  decision (search scope = name+description only; backlinks/search both off the derived graph, no new
  store; property-views deferred); update `memory-backlinks-search` in `ideas.md` to mark the
  search/backlink half shipped (property-views + note-templates remain).
- **`README.md` / `ARCHITECTURE.md`** - a short line on `/memory-search` if the memory section warrants
  it (match how `memory-lint` is documented there; skip if it adds noise).

## 8. Verification

- `scripts/validate-plugin.py` passes; `memory_graph.py` still valid, existing modes unchanged (run the
  full `tests/test-memory-graph.sh` - all prior cases plus the new ones green).
- **Live check (not just the harness):** from the repo root, `python3 scripts/memory_graph.py --search
  <known-keyword>` returns the expected fact(s); `--backlinks <known-fact>` lists the edges that fact's
  markdown actually has (spot-check against the file). Then invoke `/memory-search` end-to-end so the
  data-root resolution + dispatch path is exercised, not only the script.
- Sidecar smoke: run once with `--root`/`--link-root` pointing at a sidecar-style tree (or the real
  `Codebase/_meta` workspace tier) to confirm cross-tier resolution behaves like `memory-lint`.

## 9. Open questions

None blocking. Decisions resolved in brainstorming:
- search depth = **name + description only** (no body grep);
- v1 capability = **backlinks + search**, property-views + note-templates **deferred**;
- engine placement = **two modes on `memory_graph.py`** (reuse `scan()`/`wiki_edges`), not a new
  `memory_search.py` and not inline logic in the skill;
- invocation = **user-invocable, model-invocation disabled** (matches `memory-lint`; reversible).
